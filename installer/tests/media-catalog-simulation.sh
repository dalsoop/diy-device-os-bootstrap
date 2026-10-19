#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
monorepo_root=$(CDPATH='' cd -- "$repo_root/.." && pwd)
catalog=$repo_root/work/device-os/catalog.json
verify=$repo_root/usb-media/verify-catalog
render=$repo_root/usb-media/render-ventoy-config
capacity=$repo_root/usb-media/calculate-capacity
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fail() {
    echo "media-catalog-simulation: $*" >&2
    exit 1
}

expect_rejected() {
    fixture=$1
    if "$verify" "$fixture" >/dev/null 2>&1; then
        fail "invalid fixture was accepted: $fixture"
    fi
}

expect_resolution_rejected() {
    world_fixture=$1
    if DEVICE_MEDIA_WORLD_PLAN=$world_fixture USB_MEDIA_CATALOG=$temporary/rejected.json \
        "$repo_root/usb-media/resolve-catalog" >/dev/null 2>&1; then
        fail "invalid World selection was accepted: $world_fixture"
    fi
}

"$repo_root/usb-media/resolve-catalog" >/dev/null
"$verify" "$catalog" >/dev/null
"$render" "$catalog" > "$temporary/ventoy.json"
jq -e '
  (.control | map(has("VTOY_MENU_TIMEOUT")) | any | not) and
  ([.control[] | select(.VTOY_MENU_LANGUAGE == "ko_KR")] | length == 1) and
  (.menu_alias | length == 11)
' "$temporary/ventoy.json" >/dev/null || fail "rendered Ventoy contract is invalid"

ruby "$monorepo_root/world/bin/resolve-world" --output "$temporary/world.json"
DEVICE_MEDIA_WORLD_PLAN=$temporary/world.json USB_MEDIA_CATALOG=$temporary/world-catalog.json \
    "$repo_root/usb-media/resolve-catalog" >/dev/null
"$verify" "$temporary/world-catalog.json" >/dev/null
jq -e '
  [.entries[].id] == ["dns-appliance", "truenas-scale", "debian-live"] and
  .world.world.slug == "gujo-home" and
  .world.media.id == "dns-bootstrap" and
  .usb.default_language == "ko_KR" and
  .usb.enrollment_reserve_mib == 2048
' "$temporary/world-catalog.json" >/dev/null ||
    fail "World media selection did not become the resolved USB plan"

ruby "$monorepo_root/world/bin/resolve-world" --media inventory-capture \
    --output "$temporary/inventory-world.json"
DEVICE_MEDIA_WORLD_PLAN=$temporary/inventory-world.json \
USB_MEDIA_CATALOG=$temporary/inventory-catalog.json \
    "$repo_root/usb-media/resolve-catalog" >/dev/null
"$verify" "$temporary/inventory-catalog.json" >/dev/null
jq -e '
  [.entries[].id] == ["debian-live", "truenas-scale"] and
  .world.media.id == "inventory-capture" and
  .usb.enrollment_reserve_mib == 0 and
  ([.bundles[].id] | index("dns-inventory-capture")) != null and
  ([.bundles[].id] | index("dns-inventory-guide")) != null
' "$temporary/inventory-catalog.json" >/dev/null ||
    fail "inventory media did not resolve as a non-destructive USB plan"

jq '.media.entries = ["missing-entry"]' "$temporary/world.json" > "$temporary/unknown-world-entry.json"
expect_resolution_rejected "$temporary/unknown-world-entry.json"

jq '.media.entries = ["truenas-scale"]' "$temporary/world.json" > "$temporary/no-dns-world.json"
DEVICE_MEDIA_WORLD_PLAN=$temporary/no-dns-world.json USB_MEDIA_CATALOG=$temporary/no-dns-catalog.json \
    "$repo_root/usb-media/resolve-catalog" >/dev/null
"$verify" "$temporary/no-dns-catalog.json" >/dev/null
jq -e '
  [.entries[].id] == ["truenas-scale"] and
  .usb.enrollment_reserve_mib == 0
' "$temporary/no-dns-catalog.json" >/dev/null ||
    fail "non-DNS World selection retained DNS media or its enrollment reserve"

jq '.policies.requireTargetSpecificEraseConfirmation = false' \
    "$temporary/world.json" > "$temporary/weakened-world.json"
expect_resolution_rejected "$temporary/weakened-world.json"

jq '.entries[1].id = .entries[0].id' "$catalog" > "$temporary/duplicate-id.json"
expect_rejected "$temporary/duplicate-id.json"

jq '.entries[1].source.kind = "unknown-source"' "$catalog" > "$temporary/unknown-source.json"
expect_rejected "$temporary/unknown-source.json"

jq '.entries[1].destination = "../escape.iso"' "$catalog" > "$temporary/path-traversal.json"
expect_rejected "$temporary/path-traversal.json"

jq '.entries[1].source.sha256 = "not-a-digest"' "$catalog" > "$temporary/bad-digest.json"
expect_rejected "$temporary/bad-digest.json"

jq '.entries[1].profile_adapter = "shared-dangerous-default"' "$catalog" > "$temporary/unknown-adapter.json"
expect_rejected "$temporary/unknown-adapter.json"

jq '.usb.enrollment_label = "TOO-LONG-FAT32"' "$catalog" > "$temporary/long-enrollment-label.json"
expect_rejected "$temporary/long-enrollment-label.json"

jq '.entries += [{
  id: "example-live",
  group: "tools",
  version: "1.0",
  destination: "images/90-tools/example-live-1.0.iso",
  menu_alias: "Example Live 1.0",
  description_ko: "확장 계약 시험용 라이브 환경이다.",
  description_en: "Live environment used to test the extension contract.",
  boot_behavior: "live-environment",
  profile_adapter: "none",
  source: {
    kind: "locked-download",
    filename: "example-live-1.0.iso",
    url: "https://downloads.example.test/example-live-1.0.iso",
    sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}]' "$catalog" > "$temporary/extended.json"
"$verify" "$temporary/extended.json" >/dev/null
"$render" "$temporary/extended.json" |
    jq -e '.menu_alias[] | select(.image == "/images/90-tools/example-live-1.0.iso")' >/dev/null ||
    fail "declarative entry did not reach the rendered menu"

capacity_cache=$temporary/capacity-cache
mkdir -p "$capacity_cache"
cp "$catalog" "$temporary/capacity-catalog.json"
jq -r '.entries[].source | select(.kind == "locked-download") | .filename' "$catalog" |
while IFS= read -r filename; do
    truncate -s 100 "$capacity_cache/$filename"
    digest=$(sha256sum "$capacity_cache/$filename" | awk '{print $1}')
    jq --arg filename "$filename" --arg digest "$digest" '
      .entries |= map(
        if .source.kind == "locked-download" and .source.filename == $filename
        then .source.sha256 = $digest
        else .
        end
      )
    ' "$temporary/capacity-catalog.json" > "$temporary/capacity-catalog.next"
    mv "$temporary/capacity-catalog.next" "$temporary/capacity-catalog.json"
done
truncate -s 200 "$temporary/dns-appliance.iso"
dns_digest=$(sha256sum "$temporary/dns-appliance.iso" | awk '{print $1}')
jq -n --arg iso_sha256 "$dns_digest" '{iso_sha256:$iso_sha256}' \
    > "$temporary/dns-build-manifest.json"

capacity_result=$(
    USB_MEDIA_CATALOG=$temporary/capacity-catalog.json \
    USB_MEDIA_CACHE_DIR=$capacity_cache \
        "$capacity" --offline --capacity 4GB \
        --runtime-artifact "dns-appliance=$temporary/dns-appliance.iso" \
        --runtime-manifest "dns-appliance=$temporary/dns-build-manifest.json" \
        --json
)
printf '%s\n' "$capacity_result" | jq -e '
  .verified_entry_bytes == 700 and
  .estimated_entry_bytes == 0 and
  .unknown_entries == [] and
  .unverified_entries == [] and
  .required_bytes == 2952790716 and
  .targets[0].fits == true
' >/dev/null ||
    fail "capacity calculator did not include entries, reserve, and overhead"

unknown_result=$(
    USB_MEDIA_CATALOG=$temporary/capacity-catalog.json \
    USB_MEDIA_CACHE_DIR=$capacity_cache \
        "$capacity" --offline --capacity 4GB --json
)
printf '%s\n' "$unknown_result" | jq -e '
  .verified_entry_bytes == 500 and
  .estimated_entry_bytes == 0 and
  .unknown_entries == ["dns-appliance"] and
  .unverified_entries == [] and
  .required_bytes == null and
  .targets[0].fits == null
' >/dev/null ||
    fail "capacity calculator did not preserve an unknown runtime artifact"

too_small=$(
    USB_MEDIA_CATALOG=$temporary/capacity-catalog.json \
    USB_MEDIA_CACHE_DIR=$capacity_cache \
        "$capacity" --offline --capacity 2GB \
        --runtime-artifact "dns-appliance=$temporary/dns-appliance.iso" \
        --runtime-manifest "dns-appliance=$temporary/dns-build-manifest.json" \
        --json
)
printf '%s\n' "$too_small" | jq -e '.targets[0].fits == false' >/dev/null ||
    fail "capacity calculator accepted a target below the configured fixed reserve"

truncate -s 2000000000 "$temporary/unverified-dns.iso"
unverified_result=$(
    USB_MEDIA_CATALOG=$temporary/capacity-catalog.json \
    USB_MEDIA_CACHE_DIR=$capacity_cache \
        "$capacity" --offline --capacity 4GB \
        --runtime-artifact "dns-appliance=$temporary/unverified-dns.iso" \
        --json
)
printf '%s\n' "$unverified_result" | jq -e '
  .verified_entry_bytes == 500 and
  .estimated_entry_bytes == 2000000000 and
  .unknown_entries == [] and
  .unverified_entries == ["dns-appliance"] and
  .required_bytes == null and
  .targets[0].fits == null and
  .targets[0].remaining_after_verified_bytes > 0 and
  .targets[0].remaining_after_estimated_bytes < 0
' >/dev/null ||
    fail "unverified size incorrectly produced a final capacity decision"

echo "media catalog simulations: passed"
