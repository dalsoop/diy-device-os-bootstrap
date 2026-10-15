#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
verify=$repo_root/bin/verify-catalog
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

fail() {
    echo "catalog contract simulation: $*" >&2
    exit 1
}

expect_rejected() {
    fixture=$1
    if DEVICE_MEDIA_CATALOG_ROOT=$fixture "$verify" >/dev/null 2>&1; then
        fail "invalid fixture was accepted: $fixture"
    fi
}

"$verify" >/dev/null

cp -R "$repo_root/catalog" "$temporary/catalog"
jq '.source.sha256 = "not-a-digest"' \
    "$temporary/catalog/entries/proxmox-ve.json" > "$temporary/bad.json"
mv "$temporary/bad.json" "$temporary/catalog/entries/proxmox-ve.json"
expect_rejected "$temporary"

rm -rf "$temporary/catalog"
cp -R "$repo_root/catalog" "$temporary/catalog"
jq '.entries[1].id = .entries[0].id' \
    "$temporary/catalog/index.json" > "$temporary/bad.json"
mv "$temporary/bad.json" "$temporary/catalog/index.json"
expect_rejected "$temporary"

echo "catalog contract simulations: passed"

