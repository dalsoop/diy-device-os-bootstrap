#!/bin/bash
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/dns-tailscale-test.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

mkdir -p "$temporary/bin"
printf '%s\n' client-id > "$temporary/client-id"
printf '%s\n' tskey-client-test-secret > "$temporary/client-secret"
printf '%s\n' 0 > "$temporary/ssh-count"

cat > "$temporary/bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
config=$(cat)
case "$*" in
    *oauth/token*)
        grep -q 'tskey-client-test-secret' <<<"$config"
        printf '%s\n' '{"access_token":"test-access-token"}'
        ;;
    *'/keys/key-id'*)
        grep -q 'test-access-token' <<<"$config"
        ;;
    *'/keys'*)
        grep -q 'test-access-token' <<<"$config"
        printf '%s\n' '{"id":"key-id","key":"tskey-auth-test-one-off"}'
        ;;
    *) exit 1 ;;
esac
EOF

cat > "$temporary/bin/ssh" <<'EOF'
#!/bin/bash
set -euo pipefail
count=$(cat "$MOCK_SSH_COUNT")
count=$((count + 1))
printf '%s\n' "$count" > "$MOCK_SSH_COUNT"
case "$count" in
    1) printf '%s\n' '{"BackendState":"NeedsLogin"}' ;;
    2)
        key=$(cat)
        [ "$key" = tskey-auth-test-one-off ]
        [[ "$*" == *'--accept-dns=false'* ]]
        [[ "$*" == *'--advertise-tags=tag:dns-appliance'* ]]
        [[ "$*" != *'tskey-auth-test-one-off'* ]]
        ;;
    3)
        printf '%s\n' '{"BackendState":"Running","Self":{"HostName":"dns01","TailscaleIPs":["100.64.0.1"],"Tags":["tag:dns-appliance"]}}'
        ;;
    4)
        printf '%s\n' '{"WantRunning":true,"CorpDNS":false,"RouteAll":false,"RunSSH":false,"AdvertiseRoutes":null,"ExitNodeID":"","ExitNodeIP":""}'
        ;;
    *) exit 1 ;;
esac
EOF

cat > "$temporary/bin/tailscale" <<'EOF'
#!/bin/sh
[ "$1" = ping ]
[ "$3" = 100.64.0.1 ]
EOF
chmod +x "$temporary/bin/curl" "$temporary/bin/ssh" "$temporary/bin/tailscale"

output=$(
    PATH="$temporary/bin:$PATH" \
    MOCK_SSH_COUNT="$temporary/ssh-count" \
    TAILSCALE_OAUTH_CLIENT_ID_FILE="$temporary/client-id" \
    TAILSCALE_OAUTH_CLIENT_SECRET_FILE="$temporary/client-secret" \
        "$repo_root/management/tailscale-enroll" --role dns01
)

grep -q 'enrolled and verified dns01 at 100.64.0.1' <<<"$output"
if grep -Eq 'tskey-(client|auth)' <<<"$output"; then
    echo "FAIL Tailscale secret appeared in output" >&2
    exit 1
fi
[ "$(cat "$temporary/ssh-count")" -eq 4 ]

echo "RESULT Tailscale one-off enrollment simulation passed"
