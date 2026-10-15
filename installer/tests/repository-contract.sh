#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)

"$repo_root/build/verify-locks" >/dev/null

for file in \
    installer/payload/dns-appliance-firstboot \
    installer/payload/dns-appliance-health \
    installer/payload/dns-appliance-backup \
    installer/payload/dns-appliance-technitium-run \
    installer/fetch-locked-sources \
    installer/write-usb-linux \
    management/cluster-bootstrap \
    management/dnsctl \
    management/restore-node \
    management/authorize-reinstall \
    management/network-preflight \
    management/import-enrollment \
    management/collect-backups \
    management/tailscale-enroll \
    device-os \
    usb-media/fetch-images \
    usb-media/resolve-catalog \
    usb-media/verify-catalog \
    usb-media/render-ventoy-config \
    usb-media/calculate-capacity \
    usb-media/write-usb-linux \
    usb-media/write-image-macos \
    management/dns-appliance-status-monitor/start \
    tests/media-catalog-simulation.sh \
    tests/macos-writer-simulation.sh \
    tests/management-simulation.sh; do
    [ -x "$repo_root/$file" ] || {
        echo "repository-contract: $file must be executable" >&2
        exit 1
    }
done

for required in \
    installer/inputs/age-recipient.example \
    build/locks/sources.env \
    schemas/enrollment-record.schema.json \
    zones/home.arpa.zone \
    management/tailscale-policy.example.hujson \
    usb-media/composition.json \
    usb-media/local-entries/dns-appliance.json \
    collections/device-os.json \
    usb-media/guides/pop-os-ko.md \
    docs/tracking/decisions/0002-pinned-declarative-catalog.md \
    management/dns-appliance-status-monitor/config.json \
    management/dns-appliance-status-monitor/server.py \
    .github/workflows/ci.yml; do
    [ -r "$repo_root/$required" ] || {
        echo "repository-contract: missing $required" >&2
        exit 1
    }
done

grep -q '@@LAN_CIDR@@' "$repo_root/installer/payload/nftables.conf"
grep -q '@@MANAGEMENT_CIDR@@' "$repo_root/installer/payload/nftables.conf"
grep -q 'ConditionPathExists=!/var/lib/dns-appliance/COMPLETE' \
    "$repo_root/installer/payload/dns-appliance-firstboot.service"
grep -q 'DNS-ENROLL' "$repo_root/installer/payload/dns-appliance-firstboot"
grep -q 'previous_generation' "$repo_root/installer/scripts/install-gate"
grep -q 'Authorization: Bearer' "$repo_root/installer/payload/dns-appliance-health"
grep -q 'unzip -t' "$repo_root/installer/payload/dns-appliance-backup"
grep -q 'iifname "tailscale0"' "$repo_root/installer/payload/nftables.conf"
grep -q 'preauthorized:true' "$repo_root/management/tailscale-enroll"

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/schemas/enrollment-record.schema.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/management/dns-appliance-status-monitor/config.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/usb-media/composition.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/collections/device-os.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/usb-media/local-entries/dns-appliance.json"
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' \
    "$repo_root/management/dns-appliance-status-monitor/server.py"
"$repo_root/usb-media/resolve-catalog" >/dev/null
"$repo_root/usb-media/verify-catalog" >/dev/null

grep -q 'runtime-artifact' "$repo_root/README.md"
grep -q 'locked-download' "$repo_root/usb-media/README.md"
grep -q 'gujo-homelab-os-catalog' "$repo_root/usb-media/composition.json"

if git -C "$repo_root" grep -I -n -i -E \
    'dns-appliance-provisioning|device-install-media|device-os-flasher|device-os-catalog|superusb|homelab-usb|homelab-bootstrap-media|Homelab Bootstrap|homelab-provisioning|Homelab Install & Recovery' \
    -- . ':!tests/repository-contract.sh'; then
    echo "repository-contract: obsolete project name remains" >&2
    exit 1
fi

echo "repository contracts: passed"
