#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only

require "fileutils"
require "json"
require "open3"
require "tmpdir"
require "yaml"

runner = File.realpath(File.join(__dir__, "../bin/record-usb-event"))
playbook_path = File.realpath(File.join(__dir__, "../../../burn-history/.paths.yaml"))
playbook = YAML.safe_load_file(playbook_path, permitted_classes: [], aliases: false)
playbook_generations_root = playbook.dig("spec", "generations", "root")
failed_records_root = "logs/usb/failed"

EVENT_KEYS = %w[
  schema_version event_id generation_candidate generation_id world_slug media_id writer
  repository_revision catalog_tree status started_at finished_at exit_code failure_code target readback
].freeze
VERIFICATION_KEYS = %w[
  schema_version writer target preflight_at completed_at readback
  event_id generation_id repository_revision catalog_tree
].freeze

def assert(condition, message)
  raise message unless condition
end

# The failed-write folder lives inside the generations root and is never a generation.
def generation_paths(root)
  Dir.glob(File.join(root, "logs/usb/*")).reject { |path| File.basename(path) == "failed" }.sort
end

Dir.mktmpdir("usb-event-simulation") do |temporary|
  repo = File.join(temporary, "repo")
  output = File.join(repo, "burn-history")
  FileUtils.mkdir_p(output)
  File.write(File.join(output, "home.yaml"), "kind: World\n")

  plan = {
    "schema_version" => 1,
    "source" => {
      "playbook" => "burn-history/.paths.yaml",
      "world" => "burn-history/home.yaml"
    },
    "world" => {
      "name" => "Test Home",
      "slug" => "test-home",
      "lifecycle" => "draft",
      "timezone" => "Asia/Seoul"
    },
    "media" => {
      "id" => "dns-install",
      "language" => "ko-KR",
      "entries" => ["dns-appliance"]
    },
    "policies" => {}
  }
  catalog = {
    "schema_version" => 1,
    "catalog" => {
      "revision" => "a" * 40,
      "tree" => "b" * 40
    },
    "world" => plan,
    "entries" => []
  }
  plan_path = File.join(temporary, "world.json")
  catalog_path = File.join(temporary, "catalog.json")
  File.write(plan_path, JSON.generate(plan))
  File.write(catalog_path, JSON.generate(catalog))

  writer = File.join(temporary, "fake-writer")
  File.write(writer, <<~'RUBY')
    #!/usr/bin/env ruby
    require "json"
    device = ARGV[ARGV.index("--device") + 1]
    status = ENV.fetch("FAKE_WRITER_STATUS", "passed")
    evidence = {
      schema_version: 1,
      writer: ENV.fetch("FAKE_WRITER_MODE"),
      device_path: ENV.fetch("FAKE_WRITER_EVIDENCE_DEVICE", device),
      target: {
        display_name: ENV.fetch("FAKE_WRITER_NAME"),
        bytes: Integer(ENV.fetch("FAKE_WRITER_BYTES"), 10)
      },
      preflight_at: "2026-10-17T02:00:00+09:00",
      completed_at: status == "passed" ? "2026-10-17T02:00:01+09:00" : nil,
      readback: {
        method: "simulated-readback",
        status: status
      }
    }
    File.write(ENV.fetch("DEVICE_OS_WRITE_EVIDENCE"), JSON.pretty_generate(evidence))
    exit(status == "passed" ? 0 : 9)
  RUBY
  FileUtils.chmod(0o755, writer)

  common = {
    "DEVICE_OS_TEST_MODE" => "1",
    "DEVICE_OS_EVENT_REPO_ROOT" => repo,
    "DEVICE_OS_EVENT_OUTPUT_ROOT" => output,
    "FAKE_WRITER_MODE" => "linux-ventoy"
  }

  [
    ["/dev/test-a", "Test USB A", "15833497600", "2026-10-17T02:00:00+09:00"],
    ["/dev/test-b", "Test USB B", "30784094208", "2026-10-17T02:00:01+09:00"]
  ].each do |device, name, bytes, time|
    environment = common.merge(
      "DEVICE_OS_EVENT_TIME" => time,
      "FAKE_WRITER_NAME" => name,
      "FAKE_WRITER_BYTES" => bytes
    )
    stdout, stderr, status = Open3.capture3(
      environment,
      runner,
      "--world-plan", plan_path,
      "--catalog", catalog_path,
      "--writer", "linux-ventoy",
      "--device", device,
      "--", writer, "--device", device
    )
    assert(status.success?, "successful simulated write failed: #{stdout} #{stderr}")
  end

  generations = generation_paths(output)
  assert(generations.map { |path| File.basename(path) } == [
    "20261017020000-test-home",
    "20261017020001-test-home"
  ], "two devices did not create two generations")
  generations.each do |generation|
    %w[world.yaml world.lock.json media-manifest.json verification.json event.json].each do |name|
      assert(File.file?(File.join(generation, name)), "generation is missing #{name}")
    end
    event = JSON.parse(File.read(File.join(generation, "event.json")))
    assert(event["status"] == "succeeded", "successful event was not recorded")
    assert(event.keys == EVENT_KEYS, "published event does not have the v2 shape: #{event.keys}")
    assert(event["schema_version"] == 2, "published event is not schema version 2")
    verification = JSON.parse(File.read(File.join(generation, "verification.json")))
    assert(verification.keys.sort == VERIFICATION_KEYS.sort,
           "published verification does not have the v2 shape: #{verification.keys}")
    assert(verification["schema_version"] == 2, "published verification is not schema version 2")
    assert(verification["readback"]["status"] == "passed", "published verification readback is wrong")
  end

  collision_environment = common.merge(
    "DEVICE_OS_EVENT_TIME" => "2026-10-17T02:00:00+09:00",
    "FAKE_WRITER_NAME" => "Collision USB",
    "FAKE_WRITER_BYTES" => "15833497600"
  )
  _stdout, stderr, status = Open3.capture3(
    collision_environment,
    runner,
    "--world-plan", plan_path,
    "--catalog", catalog_path,
    "--writer", "linux-ventoy",
    "--device", "/dev/test-collision",
    "--", writer, "--device", "/dev/test-collision"
  )
  assert(!status.success? && stderr.include?("generation ID collision"), "generation collision was accepted")
  assert(generation_paths(output).length == 2, "collision overwrote or added a generation")

  _stdout, stderr, status = Open3.capture3(
    common.merge(
      "DEVICE_OS_EVENT_TIME" => "2026-10-17T02:00:03+09:00",
      "FAKE_WRITER_NAME" => "Ambiguous USB",
      "FAKE_WRITER_BYTES" => "15833497600"
    ),
    runner,
    "--world-plan", plan_path,
    "--catalog", catalog_path,
    "--writer", "linux-ventoy",
    "--device", "/dev/test-a",
    "--", writer, "--device", "/dev/test-a", "--device", "/dev/test-b"
  )
  assert(!status.success? && stderr.include?("exactly one --device"), "ambiguous writer target was accepted")

  failure_environment = common.merge(
    "DEVICE_OS_EVENT_TIME" => "2026-10-17T02:00:02+09:00",
    "FAKE_WRITER_NAME" => "Test USB C",
    "FAKE_WRITER_BYTES" => "64000000000",
    "FAKE_WRITER_STATUS" => "pending"
  )
  _stdout, _stderr, status = Open3.capture3(
    failure_environment,
    runner,
    "--world-plan", plan_path,
    "--catalog", catalog_path,
    "--writer", "linux-ventoy",
    "--device", "/dev/test-c",
    "--", writer, "--device", "/dev/test-c"
  )
  assert(status.exitstatus == 9, "failed writer status was not preserved")
  assert(!File.exist?(File.join(output, "logs/usb/20261017020002-test-home")), "failed write published a generation")
  failed_events = Dir.glob(File.join(output, "logs/usb/failed/2026/*.json"))
  assert(failed_events.length == 1, "failed write did not create exactly one event")
  failed = JSON.parse(File.read(failed_events.first))
  assert(failed["status"] == "failed", "failed event status is wrong")
  assert(failed["failure_code"] == "writer-exit-nonzero", "failed event reason is wrong")
  assert(failed.keys == EVENT_KEYS, "failed event does not have the v2 shape: #{failed.keys}")
  assert(failed["schema_version"] == 2, "failed event is not schema version 2")

  _stdout, _stderr, status = Open3.capture3(
    common.merge(
      "DEVICE_OS_EVENT_TIME" => "2026-10-17T02:00:04+09:00",
      "FAKE_WRITER_NAME" => "Mismatched USB",
      "FAKE_WRITER_BYTES" => "15833497600",
      "FAKE_WRITER_EVIDENCE_DEVICE" => "/dev/test-other"
    ),
    runner,
    "--world-plan", plan_path,
    "--catalog", catalog_path,
    "--writer", "linux-ventoy",
    "--device", "/dev/test-d",
    "--", writer, "--device", "/dev/test-d"
  )
  assert(!status.success?, "evidence for another device was accepted")
  assert(!File.exist?(File.join(output, "logs/usb/20261017020004-test-home")),
         "evidence for another device published a generation")
  mismatched = Dir.glob(File.join(output, "logs/usb/failed/2026/20261017020004-*.json"))
  assert(mismatched.length == 1, "evidence for another device did not create exactly one failed event")
  mismatched_event = JSON.parse(File.read(mismatched.first))
  assert(mismatched_event["failure_code"] == "invalid-write-evidence",
         "evidence for another device was not rejected as invalid")
  assert(mismatched_event.keys == EVENT_KEYS, "rejected event does not have the v2 shape")

  tracked_json = Dir.glob(File.join(output, "logs/usb/**/*.json"))
  assert(tracked_json.none? { |path| File.read(path).match?(/serial/i) }, "event output contains a serial field")
  assert(tracked_json.none? { |path| File.read(path).include?("device_path") || File.read(path).include?("/dev/test") },
         "published records contain the device node")

  assert(playbook_generations_root == "logs/usb", "playbook generations.root is not logs/usb")
  assert(File.directory?(File.join(File.dirname(playbook_path), failed_records_root)),
         "failed-write records folder is missing from the World record")
  builtin_repo = File.join(temporary, "builtin-repo")
  FileUtils.mkdir_p(File.join(builtin_repo, "burn-history"))
  File.write(File.join(builtin_repo, "burn-history/home.yaml"), "kind: World\n")
  builtin_environment = {
    "DEVICE_OS_TEST_MODE" => "1",
    "DEVICE_OS_EVENT_REPO_ROOT" => builtin_repo,
    "FAKE_WRITER_MODE" => "linux-ventoy",
    "FAKE_WRITER_BYTES" => "15833497600"
  }
  stdout, stderr, status = Open3.capture3(
    builtin_environment.merge("DEVICE_OS_EVENT_TIME" => "2026-10-17T03:00:00+09:00", "FAKE_WRITER_NAME" => "Root USB"),
    runner,
    "--world-plan", plan_path,
    "--catalog", catalog_path,
    "--writer", "linux-ventoy",
    "--device", "/dev/test-root",
    "--", writer, "--device", "/dev/test-root"
  )
  assert(status.success?, "built-in location write failed: #{stdout} #{stderr}")
  expected_generation = File.join(File.realpath(builtin_repo), "burn-history", playbook_generations_root, "20261017030000-test-home")
  assert(stdout.lines.include?("Generation path: #{expected_generation}\n"),
         "recorder generation root does not equal the playbook generations.root: #{stdout}")
  assert(File.file?(File.join(expected_generation, "event.json")), "built-in generation is missing event.json")

  _stdout, _stderr, status = Open3.capture3(
    builtin_environment.merge(
      "DEVICE_OS_EVENT_TIME" => "2026-10-17T03:00:01+09:00",
      "FAKE_WRITER_NAME" => "Root USB",
      "FAKE_WRITER_STATUS" => "pending"
    ),
    runner,
    "--world-plan", plan_path,
    "--catalog", catalog_path,
    "--writer", "linux-ventoy",
    "--device", "/dev/test-root",
    "--", writer, "--device", "/dev/test-root"
  )
  assert(!status.success?, "built-in location failed write succeeded")
  builtin_failed = Dir.glob(File.join(builtin_repo, "burn-history", failed_records_root, "2026/20261017030001-*.json"))
  assert(builtin_failed.length == 1, "recorder failed-write root does not equal #{failed_records_root}")
  published_roots = Dir.children(File.join(builtin_repo, "burn-history/logs")).sort
  assert(published_roots == %w[usb], "recorder published outside its record folders: #{published_roots}")
  builtin_generations = Dir.children(File.join(builtin_repo, "burn-history/logs/usb")).sort
  assert(builtin_generations == %w[20261017030000-test-home failed],
         "recorder published outside its generation and failed-write folders: #{builtin_generations}")
  state_roots = Dir.children(File.join(builtin_repo, "burn-history")).sort
  assert(state_roots == %w[.in-progress home.yaml logs], "recorder kept state outside .in-progress: #{state_roots}")

  puts "USB event simulations: passed"
end
