#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
monorepo_root=$(CDPATH='' cd -- "$repo_root/../.." && pwd)

# Documentation rule: repository text names roles, never specific machines or
# personal environments. The patterns are generic; the role accounts below are
# the only allowed /home/ entries.
allowed_home_accounts='dns-operator builder'

documentation_scan() {
    scan_label=$1
    shift
    set +e
    LC_ALL=C git -C "$checked_root" grep -I -n "$@" -- .
    scan_status=$?
    set -e
    case $scan_status in
        0)
            echo "repository-contract: repository text names $scan_label" >&2
            documentation_failed=1
            ;;
        1) ;;
        *)
            echo "repository-contract: documentation scan failed in $checked_root" >&2
            exit 1
            ;;
    esac
}

documentation_check() {
    checked_root=$1
    documentation_failed=0
    git -C "$checked_root" rev-parse --is-inside-work-tree >/dev/null || {
        echo "repository-contract: documentation check needs a Git work tree" >&2
        exit 1
    }
    # Host label: a whole word of one lowercase letter, digits, one lowercase
    # letter, digits, with at least one letter outside a-f. Hex-only words are
    # commit hashes and event IDs.
    documentation_scan "a host label" -w -E '[g-z][0-9]+[a-z][0-9]+|[a-z][0-9]+[g-z][0-9]+'
    documentation_scan "a machine generation" -w -E 'M[0-9]+'
    documentation_scan "a personal /Users/ path" -E '/Users/[A-Za-z0-9._-]'
    set +e
    home_matches=$(LC_ALL=C git -C "$checked_root" grep -I -n -o -E '/home/[A-Za-z0-9._-]+' -- .)
    scan_status=$?
    set -e
    [ "$scan_status" -le 1 ] || {
        echo "repository-contract: documentation scan failed in $checked_root" >&2
        exit 1
    }
    home_paths=$(printf '%s\n' "$home_matches" | awk -v allowed="$allowed_home_accounts" '
        BEGIN { count = split(allowed, names, " "); for (i = 1; i <= count; i++) role[names[i]] = 1 }
        $0 != "" { name = $0; sub(/.*\/home\//, "", name); if (!(name in role)) print }
    ')
    if [ -n "$home_paths" ]; then
        printf '%s\n' "$home_paths"
        echo "repository-contract: repository text names a personal /home/ path" >&2
        documentation_failed=1
    fi
    return "$documentation_failed"
}

if [ "${1:-}" = "--documentation-only" ]; then
    documentation_check "${2:-$monorepo_root}" || exit 1
    echo "documentation check: passed"
    exit 0
fi

"$repo_root/build/verify-locks" >/dev/null

for file in \
    engine/installer/dns-image/payload/dns-appliance-firstboot \
    engine/installer/dns-image/payload/dns-appliance-health \
    engine/installer/dns-image/payload/dns-appliance-backup \
    engine/installer/dns-image/payload/dns-appliance-technitium-run \
    engine/installer/dns-image/fetch-locked-sources \
    engine/installer/dns-image/disk-identity \
    engine/installer/dns-image/write-usb-linux \
    engine/installer/management/cluster-bootstrap \
    engine/installer/management/dnsctl \
    engine/installer/management/restore-node \
    engine/installer/management/authorize-reinstall \
    engine/installer/management/network-preflight \
    engine/installer/management/import-enrollment \
    engine/installer/management/collect-backups \
    engine/installer/management/tailscale-enroll \
    engine/agent/run \
    engine/agent/server.py \
    engine/agent/tests/gateway_simulation.py \
    engine/installer/device-os \
    engine/installer/usb-media/fetch-images \
    engine/installer/usb-media/resolve-catalog \
    engine/installer/usb-media/verify-catalog \
    engine/installer/usb-media/render-ventoy-config \
    engine/installer/usb-media/calculate-capacity \
    engine/installer/usb-media/check-license-policy \
    engine/installer/usb-media/build-image \
    engine/installer/usb-media/build-image-linux \
    engine/installer/usb-media/build-image-container \
    engine/installer/usb-media/inspect-targets \
    engine/installer/usb-media/write-usb-linux \
    engine/installer/usb-media/write-image-macos \
    engine/installer/usb-media/render-distribution-record \
    engine/installer/build/verify-distribution-contracts \
    engine/installer/management/dns-appliance-status-monitor/start \
    engine/installer/tests/dns-license-simulation.sh \
    engine/installer/tests/license-policy-simulation.sh \
    engine/installer/tests/media-catalog-simulation.sh \
    engine/installer/tests/image-builder-simulation.sh \
    engine/installer/tests/macos-writer-simulation.sh \
    engine/installer/tests/management-simulation.sh \
    engine/installer/tests/documentation-check-simulation.sh \
    engine/world/bin/resolve-world \
    engine/world/bin/record-usb-event \
    engine/world/tests/usb-event-simulation.rb \
    engine/world/tests/world-contract-simulation.rb; do
    [ -x "$monorepo_root/$file" ] || {
        echo "repository-contract: $file must be executable" >&2
        exit 1
    }
done

for required in \
    engine/installer/docs/examples/age-recipient.example \
    engine/installer/docs/examples/operator-authorized-keys.example \
    engine/installer/docs/examples/nodes.example.yml \
    engine/installer/docs/examples/home.arpa.example.yml \
    engine/installer/build/locks/sources.env \
    engine/installer/build/distribution-policy.json \
    engine/installer/schemas/component-redistribution-registry.schema.json \
    engine/installer/schemas/component-review-record.schema.json \
    engine/installer/schemas/dns-build-manifest.schema.json \
    engine/installer/schemas/dns-final-review-record.schema.json \
    engine/installer/schemas/enrollment-record.schema.json \
    engine/installer/schemas/license-check.schema.json \
    engine/installer/schemas/raw-image-manifest.schema.json \
    burn-history/dns-records.zone \
    burn-history/os-installs/dns01/os.conf \
    burn-history/os-installs/dns02/os.conf \
    burn-history/os-installs/dns03/os.conf \
    burn-history/keys/README.md \
    engine/installer/management/tailscale-policy.example.hujson \
    engine/installer/usb-media/composition.json \
    engine/installer/usb-media/distribution-policy.json \
    engine/installer/usb-media/local-entries/dns-appliance.json \
    engine/installer/collections/device-os.json \
    engine/installer/usb-media/guides/dns-inventory.md \
    engine/installer/dns-image/inventory-wizard \
    docs/tracking/decisions/0010-resolve-media-through-declarative-catalog.md \
    docs/tracking/decisions/0012-default-to-source-only-releases.md \
    engine/installer/management/dns-appliance-status-monitor/config.json \
    engine/installer/management/dns-appliance-status-monitor/server.py \
    engine/agent/AGENTS.md \
    engine/agent/README.md \
    engine/agent/requirements.lock \
    engine/agent/tailscale-policy.example.hujson \
    burn-history/.paths.yaml \
    burn-history/home.yaml \
    burn-history/logs/usb/README.md \
    burn-history/logs/usb/failed/README.md \
    engine/world/schemas/usb-event.schema.json \
    engine/world/schemas/usb-verification.schema.json \
    .github/workflows/ci.yml \
    .github/workflows/release.yml \
    LICENSE \
    docs/licenses/LICENSE_HISTORY.md \
    docs/licenses/THIRD_PARTY_NOTICES.md \
    docs/licenses/Tailscale-BSD-3-Clause.txt; do
    [ -r "$monorepo_root/$required" ] || {
        echo "repository-contract: missing $required" >&2
        exit 1
    }
done

grep -q '@@LAN_CIDR@@' "$repo_root/dns-image/payload/nftables.conf"
grep -q '@@MANAGEMENT_CIDR@@' "$repo_root/dns-image/payload/nftables.conf"
grep -q 'ConditionPathExists=!/var/lib/dns-appliance/COMPLETE' \
    "$repo_root/dns-image/payload/dns-appliance-firstboot.service"
grep -q 'DNS-ENROLL' "$repo_root/dns-image/payload/dns-appliance-firstboot"
grep -q 'previous_generation' "$repo_root/dns-image/scripts/install-gate"
grep -q 'Authorization: Bearer' "$repo_root/dns-image/payload/dns-appliance-health"
grep -q 'unzip -t' "$repo_root/dns-image/payload/dns-appliance-backup"
grep -q 'iifname "tailscale0"' "$repo_root/dns-image/payload/nftables.conf"
grep -q 'preauthorized:true' "$repo_root/management/tailscale-enroll"
grep -q 'TAILSCALE_LICENSES_SHA256' "$repo_root/build/locks/sources.env"
grep -q 'tailscale-dependency-licenses.md' "$repo_root/dns-image/build-image"
grep -q 'licenseDeclared:"NOASSERTION"' "$repo_root/dns-image/build-image"
grep -q 'licenseDeclared:"GPL-3.0-only"' "$repo_root/dns-image/build-image"
grep -q '/usr/share/doc/diy-device-os-bootstrap/SOURCE.md' \
    "$repo_root/dns-image/scripts/dns-finish-install"
grep -q 'preseed/late_command string /bin/sh /cdrom/simple-cdd/dns-finish-install' \
    "$repo_root/dns-image/simple-cdd/profiles/default.preseed"
[ ! -e "$repo_root/dns-image/simple-cdd/profiles/dns.postinst" ]
grep -q 'debian-installer/locale string ko_KR.UTF-8' \
    "$repo_root/dns-image/simple-cdd/profiles/default.preseed"
grep -q 'built ISO is missing /simple-cdd/' "$repo_root/dns-image/build-image"
grep -q 'exactly one role must have destructive_install_enabled=true' \
    "$repo_root/dns-image/build-image"
grep -q 'repository bundle tree may not contain symlinks' \
    "$repo_root/usb-media/write-usb-linux"
grep -q 'manifests/LICENSES.SHA256' "$repo_root/usb-media/write-usb-linux"
grep -q 'Source revision:' "$repo_root/usb-media/write-usb-linux"
grep -q 'resolved catalog revision does not match the checkout' \
    "$repo_root/usb-media/write-usb-linux"

python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/schemas/enrollment-record.schema.json"
for schema in \
    component-redistribution-registry.schema.json \
    component-review-record.schema.json \
    dns-build-manifest.schema.json \
    dns-final-review-record.schema.json \
    license-check.schema.json; do
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
        "$repo_root/schemas/$schema"
done
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/schemas/raw-image-manifest.schema.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/management/dns-appliance-status-monitor/config.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/usb-media/composition.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/collections/device-os.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$repo_root/usb-media/local-entries/dns-appliance.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$monorepo_root/engine/world/schemas/usb-event.schema.json"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$monorepo_root/engine/world/schemas/usb-verification.schema.json"
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' \
    "$repo_root/management/dns-appliance-status-monitor/server.py"
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' \
    "$monorepo_root/engine/agent/server.py"
"$repo_root/usb-media/resolve-catalog" >/dev/null
"$repo_root/usb-media/verify-catalog" >/dev/null
"$repo_root/device-os" world plan >/dev/null

grep -q 'runtime-artifact' "$repo_root/README.md"
grep -q 'locked-download' "$repo_root/usb-media/README.md"
grep -q '"kind": "workspace"' "$repo_root/usb-media/composition.json"
grep -q '"path": "engine/catalog"' "$repo_root/usb-media/composition.json"
grep -q 'https://github.com/dalsoop/diy-device-os-bootstrap' \
    "$repo_root/usb-media/composition.json"
grep -q '^    burn)$' "$repo_root/device-os"
grep -q '^    burn-image-macos)$' "$repo_root/device-os"
grep -q '^    build-image)$' "$repo_root/device-os"
grep -q '^            burn)$' "$repo_root/device-os"
grep -q '^            burn-image-macos)$' "$repo_root/device-os"
grep -q '^            build-image)$' "$repo_root/device-os"
grep -q './device-os world burn' "$monorepo_root/README.md"

ci_workflow=$monorepo_root/.github/workflows/ci.yml
release_workflow=$monorepo_root/.github/workflows/release.yml
grep -q '^  contracts:$' "$ci_workflow"
grep -q 'python3-jsonschema' "$ci_workflow"
grep -q 'Validate JSON Schema contracts' "$ci_workflow"
for contract in \
    engine/catalog/schemas/media-entry.schema.json \
    engine/catalog/schemas/bootloader.schema.json \
    engine/installer/schemas/component-redistribution-registry.schema.json \
    engine/installer/schemas/component-review-record.schema.json \
    engine/installer/schemas/dns-build-manifest.schema.json \
    engine/installer/schemas/dns-final-review-record.schema.json \
    engine/installer/schemas/license-check.schema.json \
    engine/installer/schemas/raw-image-manifest.schema.json \
    tests/dns-license-simulation.sh \
    tests/license-policy-simulation.sh \
    tests/documentation-check-simulation.sh \
    engine/world/schemas/usb-event.schema.json \
    engine/world/schemas/usb-verification.schema.json \
    burn-history/logs/usb/failed; do
    grep -q "$contract" "$ci_workflow" || {
        echo "repository-contract: CI does not enforce $contract" >&2
        exit 1
    }
done

grep -q 'license check --mode source-release --json' "$release_workflow"
# GitHub evaluates this expression; the repository check matches it literally.
# shellcheck disable=SC2016
grep -Fq 'path: ${{ runner.temp }}/dns-release-evidence/' "$release_workflow"
grep -q 'prebuilt-distribution' "$release_workflow"
grep -q 'human-only' "$release_workflow"
grep -q 'source-only evidence contains generated media' "$release_workflow"
grep -q 'This workflow does not publish a release' "$release_workflow"
jq -e '
  .source_release.enabled == true and
  .generated_artifacts.enabled == false and
  .prebuilt_release.enabled == false and
  .prebuilt_release.required_github_environment == "prebuilt-distribution"
' "$repo_root/usb-media/distribution-policy.json" >/dev/null
if grep -q -E 'contents:[[:space:]]*write|gh release|create-release|action-gh-release' \
    "$release_workflow"; then
    echo "repository-contract: source-only workflow gained release publication authority" >&2
    exit 1
fi

if grep -q -E 'legacy_dns|--dns-iso|--dns-manifest|burn\|write|burn-image-macos\|write-image-macos' \
    "$repo_root/device-os" "$repo_root/usb-media/write-usb-linux"; then
    echo "repository-contract: removed compatibility alias remains" >&2
    exit 1
fi

if git -C "$monorepo_root" grep -I -n -i -E \
    'dns-appliance-provisioning|device-install-media|device-os-flasher|device-os-catalog|superusb|homelab-usb|homelab-bootstrap-media|Homelab Bootstrap|homelab-provisioning|Homelab Install & Recovery' \
    -- . ':!engine/installer/tests/repository-contract.sh'; then
    echo "repository-contract: obsolete project name remains" >&2
    exit 1
fi

# Logs are records: every file under burn-history/logs/ is tracked, and no
# ignore rule (including a global one) matches any of them.
logs_untracked=$(git -C "$monorepo_root" ls-files --others -- burn-history/logs)
if [ -n "$logs_untracked" ]; then
    printf '%s\n' "$logs_untracked" >&2
    echo "repository-contract: burn-history/logs/ holds untracked files" >&2
    exit 1
fi
logs_tracked=$(git -C "$monorepo_root" ls-files -- burn-history/logs)
[ -n "$logs_tracked" ] || {
    echo "repository-contract: burn-history/logs/ has no tracked records" >&2
    exit 1
}
set +e
logs_ignored=$(git -C "$monorepo_root" ls-files -- burn-history/logs |
    git -C "$monorepo_root" check-ignore --no-index --stdin)
ignore_status=$?
set -e
case $ignore_status in
    0)
        printf '%s\n' "$logs_ignored" >&2
        echo "repository-contract: an ignore rule matches files under burn-history/logs/" >&2
        exit 1
        ;;
    1) ;;
    *)
        echo "repository-contract: cannot check ignore rules for burn-history/logs/" >&2
        exit 1
        ;;
esac

documentation_check "$monorepo_root" || exit 1

echo "repository contracts: passed"
