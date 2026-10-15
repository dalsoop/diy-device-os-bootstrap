#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"
require "yaml"

ROOT = Pathname(__dir__).join("..").expand_path
RESOLVER = ROOT.join("bin/resolve-world")

def fail_test(message)
  warn "world-contract-simulation: #{message}"
  exit 1
end

def run_resolver(playbook, *arguments)
  Open3.capture3(RbConfig.ruby, RESOLVER.to_s, "--playbook", playbook.to_s, *arguments)
end

def load_yaml(path)
  YAML.safe_load_file(path, permitted_classes: [], aliases: false)
end

def write_yaml(path, value)
  File.write(path, YAML.dump(value))
end

stdout, stderr, status = run_resolver(ROOT.join("world-playbook.yaml"))
fail_test("default World was rejected: #{stderr}") unless status.success?
resolved = JSON.parse(stdout)
fail_test("default media selection changed") unless resolved.dig("media", "entries") == ["dns-appliance", "truenas-scale"]
fail_test("default World identity changed") unless resolved.dig("world", "slug") == "gujo-home"

mutations = {
  "duplicate node ID" => lambda { |world| world["spec"]["nodes"][1]["id"] = "dns01" },
  "unknown asset reference" => lambda { |world| world["spec"]["nodes"][0]["assetRef"] = "missing-asset" },
  "address outside network" => lambda { |world| world["spec"]["nodes"][0]["ipv4"] = "192.168.50.10" },
  "unknown service member" => lambda { |world| world["spec"]["services"][0]["members"] << "missing-node" },
  "duplicate media entry" => lambda { |world| world["spec"]["media"][0]["entries"] << "dns-appliance" },
  "unsafe inventory path" => lambda { |world| world["spec"]["assets"][2]["inventoryRef"] = "../private.yaml" },
  "weakened hardware policy" => lambda { |world| world["spec"]["policies"]["requireExactHardwareMatch"] = false },
  "automatic boot timeout" => lambda { |world| world["spec"]["policies"]["automaticBootTimeout"] = 10 }
}

mutations.each do |label, mutation|
  Dir.mktmpdir("world-contract-") do |directory|
    root = Pathname(directory)
    FileUtils.cp(ROOT.join("world-playbook.yaml"), root.join("world-playbook.yaml"))
    FileUtils.mkdir_p(root.join("drafts/gujo-home"))
    fixture = load_yaml(ROOT.join("drafts/gujo-home/world.yaml"))
    mutation.call(fixture)
    write_yaml(root.join("drafts/gujo-home/world.yaml"), fixture)
    _out, _err, fixture_status = run_resolver(root.join("world-playbook.yaml"))
    fail_test("invalid fixture was accepted: #{label}") if fixture_status.success?
  end
end

puts "World contract simulations: passed"
