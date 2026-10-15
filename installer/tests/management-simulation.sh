#!/bin/bash
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
cat "$MOCK_CURRENT_ZONE"
EOF
cat > "$temporary/bin/ping" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$temporary/bin/curl" "$temporary/bin/ping"

printf '%s\n' token > "$temporary/token"
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
TECHNITIUM_TOKEN_FILE="$temporary/token" \
DNSCTL_AUDIT_LOG="$temporary/audit.jsonl" \
    "$repo_root/management/dnsctl" plan "$temporary/desired.zone" \
    > "$temporary/plan.json" 2> "$temporary/plan.diff"
jq -e '.schema_version == 1 and .zone == "home.arpa" and .changed == true' \
    "$temporary/plan.json" >/dev/null
grep -q '^+' "$temporary/plan.diff"
jq -e '.action == "plan:home.arpa" and .result == "ok"' \
    "$temporary/audit.jsonl" >/dev/null
pass dnsctl_plan_is_machine_readable_and_audited

if PATH="$temporary/bin:$PATH" \
    MOCK_CURRENT_ZONE="$temporary/current.zone" \
    TECHNITIUM_TOKEN_FILE="$temporary/token" \
    DNSCTL_AUDIT_LOG="$temporary/audit.jsonl" \
        "$repo_root/management/dnsctl" apply "$temporary/desired.zone" \
        --approved-commit deadbeef --confirm NOT_APPLY >/dev/null 2>&1; then
    echo "FAIL dnsctl apply accepted an invalid confirmation" >&2
    exit 1
fi
pass dnsctl_apply_requires_literal_confirmation

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
    "$repo_root/management/network-preflight" 10.0.0.1/16 \
    > "$temporary/network.txt"
grep -q '10.0.0.0/16 contains router and all DNS nodes' "$temporary/network.txt"
pass network_preflight_rejects_24_and_accepts_16

echo "RESULT $pass_count/4 management simulations passed"
