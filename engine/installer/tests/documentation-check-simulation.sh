#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
contract=$script_dir/repository-contract.sh
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
fixture_count=0

# Failing words are assembled from fragments so this file never contains them.
host_label=$(printf '%s%s' 'q7' 'z9')
host_label_high=$(printf '%s%s' 'g12' 'a3')
generation_token=$(printf '%s%s' 'M' '7')
users_path=$(printf '/%s/%s/' 'Users' 'alice')
home_path=$(printf '/%s/%s/' 'home' 'alice')
home_near_operator=$(printf '/%s/%s/' 'home' 'dns-operatorx')
home_near_builder=$(printf '/%s/%s/' 'home' 'builders')

fail() {
    echo "documentation-check-simulation: $*" >&2
    exit 1
}

new_fixture() {
    fixture_count=$((fixture_count + 1))
    fixture_root=$temporary/fixture-$fixture_count
    mkdir -p "$fixture_root"
    git -C "$fixture_root" init -q
}

track() {
    git -C "$fixture_root" add -- "$1"
}

run_check() {
    "$contract" --documentation-only "$fixture_root" >"$temporary/output" 2>&1
}

expect_failure() {
    name=$1
    content=$2
    new_fixture
    printf '%s\n' "$content" >"$fixture_root/notes.txt"
    track notes.txt
    if run_check; then
        cat "$temporary/output" >&2
        fail "$name was accepted"
    fi
    grep -q 'notes.txt:1:' "$temporary/output" || {
        cat "$temporary/output" >&2
        fail "$name was rejected without naming the file and line"
    }
}

expect_failure "host label" "Deploy the agent to $host_label before noon."
expect_failure "host label with a high first letter" "Run on $host_label_high."
expect_failure "host label after a device name" "enp1s0 is wired on $host_label:/srv"
expect_failure "host label next to non-ASCII text" "${host_label}에서 확인"
expect_failure "machine generation token" "Built on an $generation_token laptop."
expect_failure "personal /Users/ path" "Open ${users_path}work/notes."
expect_failure "personal /home/ path" "Copy to ${home_path}.ssh/."
expect_failure "near-allowlist operator path" "Copy to ${home_near_operator}keys/."
expect_failure "near-allowlist builder path" "Copy to ${home_near_builder}work/."
expect_failure "personal /home/ path after an allowed one" \
    "/home/dns-operator/.ssh and ${home_path}.ssh"

new_fixture
cat >"$fixture_root/passing.md" <<'EOF'
# Passing fixture

- Commit hashes: `0f0664e2bc1d2821bde6a5055c8c2ff1951b355c`, `ea5a0a2`, `a1b2`, `e5f6`.
- Event IDs: `20261017041011-gujo-home-b3f14937`, `20261022024140-gujo-home-570e8e43`.
- Roles and devices: `dns01`, `dns02`, `enp1s0`, `nvme0n1`, `sda1`.
- API version: `homelab.gujo.dev/v1alpha1`.
- Role accounts: `/home/dns-operator/.ssh/authorized_keys`, `/home/builder/work`.
- Placeholders: `/Users/<name>/`, `/home/<name>/`, `/home/$USER/`.
- Lowercase generation words: m7 macro, Mx, MB.
EOF
track passing.md
printf 'binary\000%s\000\n' "$host_label" >"$fixture_root/binary.bin"
track binary.bin
cp "$contract" "$fixture_root/repository-contract.sh"
cp "$0" "$fixture_root/documentation-check-simulation.sh"
track repository-contract.sh
track documentation-check-simulation.sh
run_check || {
    cat "$temporary/output" >&2
    fail "passing fixtures, binary files or the check's own sources were rejected"
}

mkdir -p "$temporary/not-a-repository"
if "$contract" --documentation-only "$temporary/not-a-repository" >"$temporary/output" 2>&1; then
    fail "a directory outside Git passed the documentation check"
fi

echo "documentation check simulations: passed"
