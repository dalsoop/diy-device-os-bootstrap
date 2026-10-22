#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"
require "yaml"

MODULE_ROOT = Pathname(__dir__).join("..").expand_path
ROOT = MODULE_ROOT.join("../../burn-history").expand_path
RESOLVER = MODULE_ROOT.join("bin/resolve-world")

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

stdout, stderr, status = run_resolver(ROOT.join(".paths.yaml"))
fail_test("default World was rejected: #{stderr}") unless status.success?
resolved = JSON.parse(stdout)
fail_test("default media selection changed") unless resolved.dig("media", "entries") == ["dns-appliance"]
fail_test("default World identity changed") unless resolved.dig("world", "slug") == "gujo-home"
fail_test("default World source changed") unless resolved.dig("source", "world") == "burn-history/home.yaml"
fail_test("default playbook source changed") unless resolved.dig("source", "playbook") == "burn-history/.paths.yaml"

inventory_stdout, inventory_stderr, inventory_status = run_resolver(
  ROOT.join(".paths.yaml"), "--media", "inventory-capture"
)
fail_test("inventory media was rejected: #{inventory_stderr}") unless inventory_status.success?
inventory = JSON.parse(inventory_stdout)
fail_test("inventory media selection changed") unless inventory.dig("media", "entries") == ["debian-live"]

mutations = {
  "duplicate node ID" => lambda { |world| world["spec"]["nodes"][1]["id"] = "dns01" },
  "unknown asset reference" => lambda { |world| world["spec"]["nodes"][0]["assetRef"] = "missing-asset" },
  "address outside network" => lambda { |world| world["spec"]["nodes"][0]["ipv4"] = "192.168.50.10" },
  "unknown service member" => lambda { |world| world["spec"]["services"][0]["members"] << "missing-node" },
  "duplicate media entry" => lambda { |world| world["spec"]["media"][0]["entries"] << "dns-appliance" },
  "unknown default media" => lambda { |world| world["spec"]["defaultMedia"] = "missing-media" },
  "unsafe inventory path" => lambda { |world| world["spec"]["assets"][2]["inventoryRef"] = "../private.yaml" },
  "weakened hardware policy" => lambda { |world| world["spec"]["policies"]["requireExactHardwareMatch"] = false },
  "automatic boot timeout" => lambda { |world| world["spec"]["policies"]["automaticBootTimeout"] = 10 }
}

mutations.each do |label, mutation|
  Dir.mktmpdir("world-contract-") do |directory|
    root = Pathname(directory)
    FileUtils.cp(ROOT.join(".paths.yaml"), root.join(".paths.yaml"))
    fixture = load_yaml(ROOT.join("home.yaml"))
    mutation.call(fixture)
    write_yaml(root.join("home.yaml"), fixture)
    _out, _err, fixture_status = run_resolver(root.join(".paths.yaml"))
    fail_test("invalid fixture was accepted: #{label}") if fixture_status.success?
  end
end

puts "World contract simulations: passed"
