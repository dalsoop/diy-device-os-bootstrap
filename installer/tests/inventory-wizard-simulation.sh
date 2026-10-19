#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/dns-inventory-wizard.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

pass_count=0
pass() {
    pass_count=$((pass_count + 1))
    echo "PASS $1"
}

failure() {
    echo "FAIL $1" >&2
    exit 1
}

sha256_text() {
    printf '%s' "$1" | LC_ALL=C tr '[:lower:]' '[:upper:]' | sha256sum | awk '{print $1}'
}

sys=$temporary/sys
devices=$sys/devices/pci0000:00
mkdir -p "$sys/class/dmi/id" "$sys/class/net" "$sys/class/block"
printf 'HP ProDesk 400 G7\n' > "$sys/class/dmi/id/product_name"
printf 'SKU-1\n' > "$sys/class/dmi/id/product_sku"
printf 'CZC0000001\n' > "$sys/class/dmi/id/product_serial"
printf '11111111-2222-3333-4444-555555555555\n' > "$sys/class/dmi/id/product_uuid"

interface() {
    name=$1
    mkdir -p "$sys/class/net/$name"
    [ -z "$2" ] || printf '%s\n' "$2" > "$sys/class/net/$name/address"
    [ -z "$3" ] || printf '%s\n' "$3" > "$sys/class/net/$name/carrier"
    if [ "$4" != virtual ]; then
        mkdir -p "$devices/net-$name"
        ln -s "$devices/net-$name" "$sys/class/net/$name/device"
    fi
    [ "$4" != wireless ] || mkdir "$sys/class/net/$name/wireless"
}
interface lo 00:00:00:00:00:00 1 virtual
interface docker0 02:42:ac:11:00:01 0 virtual
interface enp1s0 52:54:00:12:34:56 1 wired
interface enp2s0 52:54:00:12:34:57 0 wired
interface wlp3s0 52:54:00:12:34:58 1 wireless

# disk <name> <device path below devices> <removable> <model> <serial>
disk() {
    node=$devices/$2/block/$1
    mkdir -p "$node" "$devices/$2"
    printf '%s\n' "$3" > "$node/removable"
    printf '%s\n' 1000215216 > "$node/size"
    printf '%s\n' "$4" > "$devices/$2/model"
    printf '%s\n' "$5" > "$devices/$2/serial"
    ln -s "$devices/$2" "$node/device"
    ln -s "$node" "$sys/class/block/$1"
}
disk nvme0n1 nvme/nvme0 0 'Samsung SSD 980   ' S64ANS0T000001
disk sda ata1/host0/0:0:0:0 0 'TEST_SSD' TEST-DISK-01
disk sdb usb1/1-1/host6/6:0:0:0 1 'Ventoy USB' USB-MEDIA-01
disk sdc usb2/2-1/host7/7:0:0:0 0 'USB SSD' USB-SSD-01
mkdir -p "$devices/usb1/1-1/host6/6:0:0:0/block/sdb/sdb1"
: > "$devices/usb1/1-1/host6/6:0:0:0/block/sdb/sdb1/partition"
ln -s "$devices/usb1/1-1/host6/6:0:0:0/block/sdb/sdb1" "$sys/class/block/sdb1"
mkdir -p "$sys/class/block/loop0"
printf '0\n' > "$sys/class/block/loop0/removable"

medium=$temporary/medium
mkdir -p "$medium/tools"
cp "$repo_root/installer/inventory-wizard" "$medium/tools/dns-inventory"
cp "$repo_root/installer/capture-inventory" "$medium/tools/capture-inventory"
printf '/dev/sdb1 %s exfat rw,relatime 0 0\n' "$medium" > "$temporary/mounts"

mkdir -p "$temporary/bin"
cat > "$temporary/bin/root-id" <<'EOF'
#!/bin/sh
echo 0
EOF
cat > "$temporary/bin/user-id" <<'EOF'
#!/bin/sh
echo 1000
EOF
cat > "$temporary/bin/test-sync" <<'EOF'
#!/bin/sh
printf 'sync\n' >> "${DNS_TEST_SYNC_LOG:?}"
EOF
chmod 0755 "$temporary/bin/root-id" "$temporary/bin/user-id" "$temporary/bin/test-sync"

# wizard <answers> [arguments...]; output goes to $temporary/out.
wizard() {
    answers=$1
    shift
    printf '%b' "$answers" |
        TERM=${TEST_TERM:-xterm-256color} \
        DNS_INVENTORY_SYS_ROOT="${TEST_SYS:-$sys}" \
        DNS_INVENTORY_MOUNTS_FILE="${TEST_MOUNTS:-$temporary/mounts}" \
        DNS_INVENTORY_ID_COMMAND="${TEST_ID:-$temporary/bin/root-id}" \
        DNS_INVENTORY_SYNC_COMMAND="$temporary/bin/test-sync" \
        DNS_TEST_SYNC_LOG="$temporary/sync.log" \
        sh "$medium/tools/dns-inventory" "$@" > "$temporary/out" 2>&1
}

expect_refused() {
    name=$1
    shift
    if wizard "$@"; then
        failure "$name: the wizard succeeded"
    fi
    for leftover in "$medium"/.inventory-*; do
        [ ! -e "$leftover" ] || failure "$name: left a staging file"
    done
}

wizard '1\n1\n2\ndns01\n' || { cat "$temporary/out" >&2; failure korean_capture; }
saved=$medium/inventory-dns01.conf
grep -q '1단계' "$temporary/out"
grep -qx 'role=dns01' "$saved"
grep -qx 'address=10.0.5.1' "$saved"
grep -qx 'destructive_install_enabled=false' "$saved"
grep -qx "expected_mac_sha256=$(sha256_text 52:54:00:12:34:56)" "$saved"
grep -qx "expected_disk_serial_sha256=$(sha256_text TEST-DISK-01)" "$saved"
grep -qx "expected_system_serial_sha256=$(sha256_text CZC0000001)" "$saved"
grep -qx 'expected_disk_min_bytes=512110190592' "$saved"
! grep -q -e 'TEST-DISK-01' -e 'CZC0000001' -e '52:54:00:12:34:56' "$saved" ||
    failure "raw identity reached the inventory file"
[ "$(find "$medium" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort | tr '\n' ' ')" = 'inventory-dns01.conf tools ' ] ||
    failure "the wizard wrote outside its one inventory file"
grep -q 'sync' "$temporary/sync.log"
pass wizard_captures_one_machine_in_korean

grep -q 'enp1s0' "$temporary/out" && grep -q 'enp2s0' "$temporary/out"
! grep -q -e ' lo ' -e 'docker0' -e 'wlp3s0' "$temporary/out" ||
    failure "loopback, virtual, or wireless interfaces were offered"
grep -q '케이블 연결됨' "$temporary/out"
pass wizard_offers_only_wired_interfaces

grep -q 'nvme0n1 .*Samsung SSD 980 .* 512 GB' "$temporary/out" && grep -q ' sda ' "$temporary/out"
! grep -q -e ' sdb' -e ' sdc ' -e 'loop0' "$temporary/out" ||
    failure "installer media, USB, or loop disks were offered"
pass wizard_offers_only_internal_disks

TEST_TERM=linux wizard '2\n1\n1\ndns02\n'
grep -q 'Step 1' "$temporary/out" && ! grep -q '단계' "$temporary/out"
grep -qx 'role=dns02' "$medium/inventory-dns02.conf"
grep -qx "expected_disk_serial_sha256=$(sha256_text S64ANS0T000001)" "$medium/inventory-dns02.conf"
TEST_TERM=linux wizard '3\n' --lang ko || true
grep -q '1단계' "$temporary/out"
pass wizard_uses_english_on_the_text_console

expect_refused wrong_confirmation '3\n1\n1\ndns01\n'
[ ! -e "$medium/inventory-dns03.conf" ] || failure "saved after a wrong confirmation"
pass wizard_requires_the_role_as_confirmation

before=$(sha256sum "$saved" | awk '{print $1}')
expect_refused keep_existing '1\n2\n1\nno\n'
[ "$(sha256sum "$saved" | awk '{print $1}')" = "$before" ] || failure "replaced without overwrite"
wizard '1\n2\n1\noverwrite\ndns01\n'
[ "$(sha256sum "$saved" | awk '{print $1}')" != "$before" ] || failure "overwrite did not replace"
grep -qx "expected_mac_sha256=$(sha256_text 52:54:00:12:34:57)" "$saved"
pass wizard_replaces_an_inventory_only_on_overwrite

wizard '9\nx\n3\n1\n1\ndns03\n'
grep -qx 'role=dns03' "$medium/inventory-dns03.conf"
grep -q 'Captured roles: dns01 dns02 dns03\|수집된 역할: dns01 dns02 dns03' "$temporary/out"
expect_refused three_invalid_answers '0\n4\nnone\n'
pass wizard_retries_then_stops_on_invalid_numbers

expect_refused input_ended '1\n'
pass wizard_stops_when_input_ends

TEST_ID=$temporary/bin/user-id expect_refused not_root '1\n1\n1\ndns01\n'
pass wizard_requires_root

: > "$temporary/no-mounts"
TEST_MOUNTS=$temporary/no-mounts expect_refused unmounted '1\n1\n1\ndns01\n'
printf '/dev/sdb1 %s exfat ro,relatime 0 0\n' "$medium" > "$temporary/ro-mounts"
TEST_MOUNTS=$temporary/ro-mounts expect_refused read_only '1\n1\n1\ndns01\n'
pass wizard_requires_the_writable_inventory_medium

cp -R "$sys" "$temporary/sys-no-disk"
rm "$temporary/sys-no-disk/class/block/sda" "$temporary/sys-no-disk/class/block/nvme0n1"
TEST_SYS=$temporary/sys-no-disk expect_refused no_internal_disk '1\n1\n'
grep -q '내부 디스크를 찾지 못했습니다' "$temporary/out"
pass wizard_refuses_when_no_internal_disk_exists

echo "RESULT $pass_count/11 inventory wizard simulations passed"
