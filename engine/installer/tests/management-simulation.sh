#!/bin/bash
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/dns-management-test.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

pass_count=0
pass() {
    pass_count=$((pass_count + 1))
    echo "PASS $1"
}

mkdir -p "$temporary/bin"
cat > "$temporary/bin/curl" <<'EOF'
#!/bin/sh
case "$*" in
    */api/zones/import*)
        printf '%s\n' "$*" >> "${MOCK_IMPORT_LOG:-/dev/null}"
        printf '{"status":"ok","response":{}}\n'
        ;;
    *)
        [ -z "${MOCK_CURL_ARGS:-}" ] || printf '%s\n' "$@" > "$MOCK_CURL_ARGS"
        cat "$MOCK_CURRENT_ZONE"
        ;;
esac
EOF
cat > "$temporary/bin/ping" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$temporary/bin/curl" "$temporary/bin/ping"

printf '%s\n' token > "$temporary/token"
printf '%s\n' test-ca > "$temporary/technitium-ca.pem"
cat > "$temporary/current.zone" <<'EOF'
$ORIGIN home.arpa.
$TTL 300
@ IN SOA dns01.home.arpa. hostmaster.home.arpa. ( 1 3600 600 604800 300 )
@ IN NS dns01.home.arpa.
EOF
cat > "$temporary/desired.zone" <<'EOF'
$ORIGIN home.arpa.
$TTL 300
@ IN SOA dns01.home.arpa. hostmaster.home.arpa. ( 2 3600 600 604800 300 )
@ IN NS dns01.home.arpa.
canary IN A 10.0.9.9
EOF

PATH="$temporary/bin:$PATH" \
MOCK_CURRENT_ZONE="$temporary/current.zone" \
MOCK_CURL_ARGS="$temporary/curl.args" \
TECHNITIUM_TOKEN_FILE="$temporary/token" \
TECHNITIUM_CA_FILE="$temporary/technitium-ca.pem" \
DNSCTL_AUDIT_LOG="$temporary/audit.jsonl" \
    "$repo_root/management/dnsctl" plan "$temporary/desired.zone" \
    > "$temporary/plan.json" 2> "$temporary/plan.diff"
jq -e '.schema_version == 2 and .zone == "home.arpa" and .changed == true and .source_commit == null' \
    "$temporary/plan.json" >/dev/null
grep -q '^+' "$temporary/plan.diff"
jq -e '.action == "plan:home.arpa" and .result == "ok"' \
    "$temporary/audit.jsonl" >/dev/null
pass dnsctl_plan_is_machine_readable_and_audited

grep -Fx -- '--cacert' "$temporary/curl.args" >/dev/null
grep -Fx -- "$temporary/technitium-ca.pem" "$temporary/curl.args" >/dev/null
if grep -Fx -- '--insecure' "$temporary/curl.args" >/dev/null; then
    echo "FAIL dnsctl retained insecure TLS with a configured CA" >&2
    exit 1
fi
pass dnsctl_uses_configured_ca

zone_repo=$temporary/zone-repo
mkdir -p "$zone_repo/zones"
cp "$temporary/desired.zone" "$zone_repo/zones/home.arpa.zone"
git -C "$zone_repo" init -q
git -C "$zone_repo" add zones/home.arpa.zone
git -C "$zone_repo" -c user.name=test -c user.email=test@example.invalid \
    commit -q -m zone
dnsctl_in_repo() {
    (
        cd "$zone_repo"
        PATH="$temporary/bin:$PATH" \
        MOCK_CURRENT_ZONE="$temporary/current.zone" \
        MOCK_IMPORT_LOG="$temporary/import.log" \
        TECHNITIUM_URL="${DNSCTL_TEST_URL:-https://dns01:53443}" \
        TECHNITIUM_TOKEN_FILE="$temporary/token" \
        TECHNITIUM_CA_FILE="$temporary/technitium-ca.pem" \
        DNSCTL_AUDIT_LOG="$temporary/apply-audit.jsonl" \
            "$repo_root/management/dnsctl" "$@"
    )
}
expect_apply_rejected() {
    name=$1
    shift
    : > "$temporary/import.log"
    if dnsctl_in_repo apply "$@" > "$temporary/reject.out" 2> "$temporary/reject.err"; then
        echo "FAIL $name: dnsctl apply succeeded" >&2
        exit 1
    fi
    if [ -s "$temporary/import.log" ]; then
        echo "FAIL $name: dnsctl apply imported before rejecting" >&2
        exit 1
    fi
    pass "$name"
}
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

dnsctl_in_repo plan zones/home.arpa.zone --out "$temporary/reviewed.plan" \
    > /dev/null 2> "$temporary/reviewed.err"
plan_sha=$(sha256_of "$temporary/reviewed.plan")
grep -q "^dnsctl: plan_sha256=$plan_sha$" "$temporary/reviewed.err"
jq -e --arg commit "$(git -C "$zone_repo" rev-parse HEAD)" \
    '.schema_version == 2 and .source_commit == $commit
     and .zone_path == "zones/home.arpa.zone"
     and .target_url == "https://dns01:53443" and .changed == true' \
    "$temporary/reviewed.plan" >/dev/null
[ ! -w "$temporary/reviewed.plan" ] || [ "$(id -u)" -eq 0 ]
pass dnsctl_plan_saves_a_read_only_bound_plan

if dnsctl_in_repo plan zones/home.arpa.zone --out "$temporary/reviewed.plan" \
    >/dev/null 2>&1; then
    echo "FAIL dnsctl plan overwrote a saved plan" >&2
    exit 1
fi
[ "$(sha256_of "$temporary/reviewed.plan")" = "$plan_sha" ]
pass dnsctl_saved_plans_are_immutable

printf '%s\n' '; uncommitted' >> "$zone_repo/zones/home.arpa.zone"
if dnsctl_in_repo plan zones/home.arpa.zone --out "$temporary/dirty.plan" \
    >/dev/null 2>&1; then
    echo "FAIL dnsctl saved a plan for an uncommitted zone" >&2
    exit 1
fi
git -C "$zone_repo" checkout -q -- zones/home.arpa.zone
pass dnsctl_saved_plan_requires_committed_zone

expect_apply_rejected dnsctl_apply_requires_literal_confirmation \
    --plan "$temporary/reviewed.plan" --plan-sha256 "$plan_sha" --confirm NOT_APPLY
expect_apply_rejected dnsctl_apply_rejects_unreviewed_plan_hash \
    --plan "$temporary/reviewed.plan" --plan-sha256 "$(printf '%064d' 0)" --confirm APPLY
DNSCTL_TEST_URL=https://dns02:53443 expect_apply_rejected \
    dnsctl_apply_rejects_other_endpoint \
    --plan "$temporary/reviewed.plan" --plan-sha256 "$plan_sha" --confirm APPLY

printf '%s\n' '; uncommitted' >> "$zone_repo/zones/home.arpa.zone"
expect_apply_rejected dnsctl_apply_rejects_uncommitted_zone \
    --plan "$temporary/reviewed.plan" --plan-sha256 "$plan_sha" --confirm APPLY
git -C "$zone_repo" checkout -q -- zones/home.arpa.zone

cp "$temporary/current.zone" "$temporary/current.zone.reviewed"
printf '%s\n' 'drift IN A 10.0.9.8' >> "$temporary/current.zone"
expect_apply_rejected dnsctl_apply_rejects_live_zone_drift \
    --plan "$temporary/reviewed.plan" --plan-sha256 "$plan_sha" --confirm APPLY
jq -s -e 'map(select(.result == "drifted")) | length == 1' \
    "$temporary/apply-audit.jsonl" >/dev/null
cp "$temporary/current.zone.reviewed" "$temporary/current.zone"

: > "$temporary/import.log"
dnsctl_in_repo apply --plan "$temporary/reviewed.plan" --plan-sha256 "$plan_sha" \
    --confirm APPLY > "$temporary/apply.json"
jq -e --arg plan "$plan_sha" '.status == "ok" and .plan_sha256 == $plan' \
    "$temporary/apply.json" >/dev/null
grep -q 'zone=home.arpa&overwrite=true' "$temporary/import.log"
jq -s -e --arg plan "$plan_sha" \
    'map(select(.action == "apply:home.arpa" and .result == "ok" and .plan_sha256 == $plan)) | length == 1' \
    "$temporary/apply-audit.jsonl" >/dev/null
pass dnsctl_apply_consumes_the_reviewed_plan

expect_apply_rejected dnsctl_apply_rejects_replayed_plan \
    --plan "$temporary/reviewed.plan" --plan-sha256 "$plan_sha" --confirm APPLY

printf '%s\n' 'next IN A 10.0.9.10' >> "$zone_repo/zones/home.arpa.zone"
git -C "$zone_repo" -c user.name=test -c user.email=test@example.invalid \
    commit -q -am next
dnsctl_in_repo plan zones/home.arpa.zone --out "$temporary/stale.plan" \
    > /dev/null 2>&1
stale_sha=$(sha256_of "$temporary/stale.plan")
printf '%s\n' 'later IN A 10.0.9.11' >> "$zone_repo/zones/home.arpa.zone"
git -C "$zone_repo" -c user.name=test -c user.email=test@example.invalid \
    commit -q -am later
expect_apply_rejected dnsctl_apply_rejects_other_source_commit \
    --plan "$temporary/stale.plan" --plan-sha256 "$stale_sha" --confirm APPLY

enrollment=$temporary/DNS-ENROLL
generation=11111111-2222-3333-4444-555555555555
mkdir -p "$enrollment/records/dns01/$generation"
printf '%s\n' "$generation" > "$enrollment/records/dns01/ACTIVE"
cat > "$enrollment/records/dns01/$generation/public.json" <<'EOF'
{"hardware":{"system_uuid":"550E8400-E29B-41D4-A716-446655440000"}}
EOF
"$repo_root/management/authorize-reinstall" \
    --enrollment "$enrollment" --role dns01 --confirm 'ERASE dns01' >/dev/null
grep -q '^role=dns01$' "$enrollment/reinstall/dns01.allow"
grep -q "^previous_generation=$generation$" "$enrollment/reinstall/dns01.allow"
grep -q '^authorize_erase=true$' "$enrollment/reinstall/dns01.allow"
pass reinstall_authorization_is_generation_bound

if PATH="$temporary/bin:$PATH" \
    "$repo_root/management/network-preflight" 10.0.0.1/24 >/dev/null 2>&1; then
    echo "FAIL /24 unexpectedly contains the DNS node addresses" >&2
    exit 1
fi
PATH="$temporary/bin:$PATH" \
    "$repo_root/management/network-preflight" --offline 10.0.0.1/16 \
    > "$temporary/network.txt"
grep -q '10.0.0.0/16 contains router and all DNS nodes' "$temporary/network.txt"
pass network_preflight_rejects_24_and_accepts_16

PATH="$temporary/bin:$PATH" \
    "$repo_root/management/network-preflight" --json --offline 10.0.0.1/16 \
    > "$temporary/network.json"
jq -e '
  .schema_version == 1 and
  .operation == "network.preflight" and
  .topology.valid == true and
  (.topology.management_host_default_route.observed | type == "boolean") and
  .internet.checked == false and
  .internet.ready == null and
  .network_gates.offline_dns_install.ready == true and
  .network_gates.media_download.ready == null
' "$temporary/network.json" >/dev/null
pass network_preflight_offline_json_is_explicit

# Exercise the actual first-boot renderer without running appliance setup.
python3 - "$repo_root/dns-image/payload/dns-appliance-firstboot" "$temporary" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text()
function = re.search(r"^write_technitium_env\(\) \{\n.*?^\}", source, re.M | re.S)
assert function, "first-boot environment renderer is missing"
fixture = function.group().replace("/etc/dns-appliance", "${fixture_dir}")
pathlib.Path(sys.argv[2], "render-env").write_text(
    'set -eu\n' + fixture + '\nwrite_technitium_env "$1"\n'
)
PY
for include_password in true false; do
    fixture_dir="$temporary" ROLE=dns01 CLUSTER_DOMAIN=home.arpa \
        ADDRESS=10.0.5.1 LAN_CIDR=10.0.0.0/16 technitium_token="$temporary/token" \
        sh "$temporary/render-env" "$include_password"
    python3 - "$temporary/technitium.env" "$include_password" <<'PY'
import ipaddress
import pathlib
import stat
import sys

path = pathlib.Path(sys.argv[1])
config = dict(line.split("=", 1) for line in path.read_text().splitlines())
assert stat.S_IMODE(path.stat().st_mode) == 0o600
assert config["DNS_SERVER_RECURSION"] == "UseSpecifiedNetworkACL"
networks = [ipaddress.ip_network(value) for value in config["DNS_SERVER_RECURSION_NETWORK_ACL"].split(",")]
allowed = lambda address: any(ipaddress.ip_address(address) in network for network in networks)
for address in ("127.0.0.1", "10.0.5.1", "10.0.255.254", "100.64.0.0", "100.100.1.2", "100.127.255.255"):
    assert allowed(address), f"expected recursion for {address}"
for address in ("1.1.1.1", "10.1.0.1", "100.63.255.255", "100.128.0.0", "192.168.0.1", "::1"):
    assert not allowed(address), f"unexpected recursion for {address}"
assert ("DNS_SERVER_ADMIN_PASSWORD_FILE" in config) == (sys.argv[2] == "true")
assert config["DNS_SERVER_AUTH_STATIC_SESSIONS"] == "admin:token"
PY
done
pass firstboot_recursion_allows_lan_and_tailscale_but_not_public_clients

python3 - "$repo_root/dns-image/payload/nftables.conf" <<'PY'
import pathlib
import sys

rules = [line.strip() for line in pathlib.Path(sys.argv[1]).read_text().splitlines()
         if line.strip() and not line.strip().startswith("#")]
guard = rules.index('iifname != "tailscale0" ip saddr 100.64.0.0/10 drop')
assert rules.index('iifname "lo" accept') < guard
for index, rule in enumerate(rules):
    if "accept" in rule and rule != 'iifname "lo" accept' and not rule.startswith("type "):
        assert guard < index, "CGNAT guard must precede connection and LAN allowances"
assert 'iifname "tailscale0" udp dport 53 accept' in rules
assert 'iifname "tailscale0" tcp dport { 22, 53, 9090, 9100, 53443 } accept' in rules
assert 'type filter hook input priority 0; policy drop;' in rules
PY
pass tailscale_source_range_is_guarded_before_other_firewall_allowances

echo "RESULT $pass_count/18 management simulations passed"
