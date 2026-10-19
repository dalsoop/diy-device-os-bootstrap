#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
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
    ../agent/run \
    ../agent/server.py \
    ../agent/tests/gateway_simulation.py \
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
    tests/management-simulation.sh \
    ../world/bin/resolve-world \
    ../world/tests/world-contract-simulation.rb; do
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
    usb-media/guides/dns-inventory.md \
    docs/tracking/decisions/0002-pinned-declarative-catalog.md \
    management/dns-appliance-status-monitor/config.json \
    management/dns-appliance-status-monitor/server.py \
    ../agent/AGENTS.md \
    ../agent/README.md \
    ../agent/requirements.lock \
    ../agent/tailscale-policy.example.hujson \
    ../world/world-playbook.yaml \
    ../world/drafts/gujo-home/world.yaml \
    ../.github/workflows/ci.yml \
    ../LICENSE \
    ../LICENSE_HISTORY.md \
    ../THIRD_PARTY_NOTICES.md \
    ../third_party/licenses/Tailscale-BSD-3-Clause.txt; do
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
grep -q 'TAILSCALE_LICENSES_SHA256' "$repo_root/build/locks/sources.env"
grep -q 'SIMPLE_CDD_PACKAGE_SHA256' "$repo_root/build/locks/sources.env"
grep -q 'PYTHON3_SIMPLE_CDD_PACKAGE_SHA256' "$repo_root/build/locks/sources.env"
grep -q 'SIMPLE_CDD_PACKAGE_URL' "$repo_root/installer/fetch-locked-sources"
grep -q 'simple_cdd_package_sha256' "$repo_root/installer/build-image"
grep -q 'tailscale-dependency-licenses.md' "$repo_root/installer/build-image"
grep -q 'licenseDeclared:"NOASSERTION"' "$repo_root/installer/build-image"
grep -q 'licenseDeclared:"GPL-3.0-only"' "$repo_root/installer/build-image"
grep -qx 'bind9-dnsutils' "$repo_root/installer/simple-cdd/profiles/dns.packages"
if grep -qx 'dnsutils' "$repo_root/installer/simple-cdd/profiles/dns.packages"; then
    echo "repository-contract: use the concrete bind9-dnsutils package, not its virtual dnsutils name" >&2
    exit 1
fi
grep -q '/usr/share/doc/diy-device-os-bootstrap/SOURCE.md' \
    "$repo_root/installer/simple-cdd/profiles/dns.postinst"
grep -q 'manifests/LICENSES.SHA256' "$repo_root/usb-media/write-usb-linux"
grep -q 'Source revision:' "$repo_root/usb-media/write-usb-linux"
grep -q 'resolved catalog revision does not match the checkout' \
    "$repo_root/usb-media/write-usb-linux"

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
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' \
    "$repo_root/../agent/server.py"
"$repo_root/usb-media/resolve-catalog" >/dev/null
"$repo_root/usb-media/verify-catalog" >/dev/null
"$repo_root/device-os" world plan >/dev/null

grep -q 'runtime-artifact' "$repo_root/README.md"
grep -q 'locked-download' "$repo_root/usb-media/README.md"
grep -q '"kind": "workspace"' "$repo_root/usb-media/composition.json"
grep -q '"path": "catalog"' "$repo_root/usb-media/composition.json"
grep -q 'https://github.com/dalsoop/diy-device-os-bootstrap' "$repo_root/usb-media/composition.json"
grep -q 'burn|write)' "$repo_root/device-os"
grep -q 'burn-image-macos|write-image-macos)' "$repo_root/device-os"
grep -q './device-os world burn' "$repo_root/../README.md"

if git -C "$repo_root" grep -I -n -i -E \
    'dns-appliance-provisioning|device-install-media|device-os-flasher|device-os-catalog|superusb|homelab-usb|homelab-bootstrap-media|Homelab Bootstrap|homelab-provisioning|Homelab Install & Recovery' \
    -- . ':!tests/repository-contract.sh'; then
    echo "repository-contract: obsolete project name remains" >&2
    exit 1
fi

echo "repository contracts: passed"
