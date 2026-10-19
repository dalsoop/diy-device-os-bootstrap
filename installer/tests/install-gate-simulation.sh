#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
gate=$repo_root/installer/scripts/install-gate
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dns-install-gate.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

mkdir -p "$test_root/bin"
cat > "$test_root/bin/sha256sum" <<'EOF'
#!/bin/sh
if [ -x /usr/bin/sha256sum ]; then
    exec /usr/bin/sha256sum "$@"
fi
exec shasum -a 256 "$@"
EOF
cat > "$test_root/bin/debconf-set" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${DNS_TEST_DEBCONF_LOG:?}"
EOF
cat > "$test_root/bin/dns-test-dd" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${DNS_TEST_DISK_LOG:?}"
EOF
cat > "$test_root/bin/dns-test-blockdev" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${DNS_TEST_BLOCKDEV_LOG:?}"
EOF
cat > "$test_root/bin/dns-test-sync" <<'EOF'
#!/bin/sh
printf 'sync\n' >> "${DNS_TEST_SYNC_LOG:?}"
EOF
cat > "$test_root/bin/dns-test-udpkg" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "${DNS_TEST_NETWORK_LOG:?}"
EOF
cat > "$test_root/bin/dns-test-hw-detect" <<'EOF'
#!/bin/sh
printf 'hw-detect\n' >> "${DNS_TEST_NETWORK_LOG:?}"
mkdir -p "${DNS_TEST_SYS_ROOT:?}/class/net/en0"
printf '00:11:22:33:44:55\n' > "${DNS_TEST_SYS_ROOT:?}/class/net/en0/address"
EOF
cat > "$test_root/bin/dns-test-uname" <<'EOF'
#!/bin/sh
[ "${1:-}" = -r ] || exit 1
printf 'test-kernel\n'
EOF
cat > "$test_root/bin/tr" <<'EOF'
#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
if [ "${1:-}" = '[:lower:]' ] && [ "${2:-}" = '[:upper:]' ]; then
    exec /usr/bin/tr o p
fi
exec /usr/bin/tr "$@"
EOF
chmod 0755 "$test_root/bin/sha256sum" "$test_root/bin/debconf-set" \
    "$test_root/bin/dns-test-dd" "$test_root/bin/dns-test-blockdev" \
    "$test_root/bin/dns-test-sync" "$test_root/bin/dns-test-udpkg" \
    "$test_root/bin/dns-test-hw-detect" "$test_root/bin/dns-test-uname" \
    "$test_root/bin/tr"

normalize() {
    LC_ALL=C tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' |
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

hash_value() {
    if command -v shasum >/dev/null 2>&1; then
        printf '%s' "$1" | normalize | shasum -a 256 | awk '{print $1}'
    else
        printf '%s' "$1" | normalize | /usr/bin/sha256sum | awk '{print $1}'
    fi
}

make_disk() {
    root=$1
    disk=$2
    removable=$3
    model=$4
    serial=$5
    sectors=$6
    transport=${7:-internal}
    case "$transport" in
        internal) device_path=$root/sys/devices/pci0000:00/ata1/block/$disk ;;
        usb) device_path=$root/sys/devices/pci0000:00/usb1/1-1/block/$disk ;;
        *) echo "unknown test transport: $transport" >&2; exit 1 ;;
    esac
    mkdir -p "$root/sys/class/block" "$device_path/device"
    rm -f "$root/sys/class/block/$disk"
    ln -s "$device_path" "$root/sys/class/block/$disk"
    printf '%s\n' "$removable" > "$root/sys/class/block/$disk/removable"
    printf '%s\n' "$model" > "$root/sys/class/block/$disk/device/model"
    printf '%s\n' "$serial" > "$root/sys/class/block/$disk/device/serial"
    printf '%s\n' "$sectors" > "$root/sys/class/block/$disk/size"
}

make_partition() {
    root=$1
    disk=$2
    partition=$3
    disk_path=$(CDPATH='' cd -P "$root/sys/class/block/$disk" && pwd)
    mkdir -p "$disk_path/$partition"
    printf '1\n' > "$disk_path/$partition/partition"
    ln -s "$disk_path/$partition" "$root/sys/class/block/$partition"
}

make_mapper() {
    root=$1
    mapper=$2
    mapper_name=$3
    slave=$4
    mkdir -p "$root/sys/class/block/$mapper/dm" \
        "$root/sys/class/block/$mapper/slaves"
    printf '%s\n' "$mapper_name" > "$root/sys/class/block/$mapper/dm/name"
    ln -s "$root/sys/class/block/$slave" \
        "$root/sys/class/block/$mapper/slaves/$slave"
}

make_fixture() {
    name=$1
    root=$test_root/$name
    mkdir -p "$root/media" "$root/run" "$root/enrollment" "$root/dev" \
        "$root/sys/class/dmi/id" "$root/sys/class/net/en0"

    printf 'HP ProDesk Test\n' > "$root/sys/class/dmi/id/product_name"
    printf 'TEST-SKU\n' > "$root/sys/class/dmi/id/product_sku"
    printf 'TEST-SERIAL-01\n' > "$root/sys/class/dmi/id/product_serial"
    printf '11111111-2222-3333-4444-555555555555\n' > "$root/sys/class/dmi/id/product_uuid"
    printf '00:11:22:33:44:55\n' > "$root/sys/class/net/en0/address"

    make_disk "$root" sda 0 'TEST SSD' 'TEST-DISK-01' 2097152 internal
    make_disk "$root" sdb 1 'TEST USB' 'TEST-USB-01' 4194304 usb
    make_partition "$root" sdb sdb1
    printf '/dev/sdb1 /cdrom iso9660 ro 0 0\n' > "$root/mounts"
    printf 'Filename Type Size Used Priority\n' > "$root/swaps"

    cat > "$root/media/dns01.conf" <<EOF
role=dns01
address=10.0.5.1
prefix_length=16
netmask=255.255.0.0
gateway=10.0.0.1
dns_servers=10.0.0.1
domain=home.arpa
lan_cidr=10.0.0.0/16
management_cidr=10.0.0.0/16
cluster_domain=dns-cluster.home.arpa
expected_product_name_sha256=$(hash_value 'HP ProDesk Test')
expected_product_sku_sha256=$(hash_value 'TEST-SKU')
expected_system_serial_sha256=$(hash_value 'TEST-SERIAL-01')
expected_system_uuid_sha256=$(hash_value '11111111-2222-3333-4444-555555555555')
expected_mac_sha256=$(hash_value '00:11:22:33:44:55')
expected_disk_model_sha256=$(hash_value 'TEST SSD')
expected_disk_serial_sha256=$(hash_value 'TEST-DISK-01')
expected_disk_min_bytes=1073741824
destructive_install_enabled=true
EOF
    printf 'role=dns02\ndestructive_install_enabled=false\n' > "$root/media/dns02.conf"
    printf 'role=dns03\ndestructive_install_enabled=false\n' > "$root/media/dns03.conf"
    printf '%s\n' "$root"
}

run_gate() {
    root=$1
    phase=$2
    DNS_INSTALLER_MEDIA_DIR="$root/media" \
    DNS_INSTALLER_STATE_DIR="$root/run" \
    DNS_INSTALLER_SYS_ROOT="$root/sys" \
    DNS_INSTALLER_MOUNTS_FILE="$root/mounts" \
    DNS_INSTALLER_SWAPS_FILE="$root/swaps" \
    DNS_INSTALLER_DEBCONF_SET="$test_root/bin/debconf-set" \
    DNS_INSTALLER_ENROLLMENT_DIR="$root/enrollment" \
    DNS_INSTALLER_DEVICE_ROOT="$root/dev" \
    DNS_INSTALLER_ZERO_COMMAND="$test_root/bin/dns-test-dd" \
    DNS_INSTALLER_BLOCKDEV_COMMAND="$test_root/bin/dns-test-blockdev" \
    DNS_INSTALLER_SYNC_COMMAND="$test_root/bin/dns-test-sync" \
    DNS_INSTALLER_PACKAGE_POOL="$root/package-pool" \
    DNS_INSTALLER_UDPKG_COMMAND="$test_root/bin/dns-test-udpkg" \
    DNS_INSTALLER_NETWORK_DETECT_COMMAND="$test_root/bin/dns-test-hw-detect" \
    DNS_INSTALLER_UNAME_COMMAND="$test_root/bin/dns-test-uname" \
    DNS_TEST_DEBCONF_LOG="$root/debconf.log" \
    DNS_TEST_DISK_LOG="$root/disk.log" \
    DNS_TEST_BLOCKDEV_LOG="$root/blockdev.log" \
    DNS_TEST_SYNC_LOG="$root/sync.log" \
    DNS_TEST_NETWORK_LOG="$root/network.log" \
    DNS_TEST_SYS_ROOT="$root/sys" \
    PATH="$test_root/bin:$PATH" \
        /bin/sh "$gate" "$phase"
}

expect_success() {
    name=$1
    root=$2
    if run_gate "$root" select-disk > "$root/output.log" 2>&1 &&
        grep -q '^TARGET_DISK=/dev/sda$' "$root/run/install.env" &&
        grep -q '^TARGET_DISK_MODEL=TEST SSD$' "$root/run/install.env" &&
        grep -q '^TARGET_DISK_SERIAL=TEST-DISK-01$' "$root/run/install.env" &&
        grep -q '^TARGET_DISK_PREPARED=true$' "$root/run/install.env" &&
        grep -q '^NIC_MAC=00:11:22:33:44:55$' "$root/run/install.env" &&
        grep -q '^partman-auto/disk /dev/sda$' "$root/debconf.log" &&
        [ "$(wc -l < "$root/disk.log" | tr -d ' ')" -eq 2 ] &&
        grep -q "of=$root/dev/sda bs=512 count=131072" "$root/disk.log" &&
        grep -q "of=$root/dev/sda bs=512 seek=1966080 count=131072" "$root/disk.log" &&
        grep -q '^sync$' "$root/sync.log" &&
        grep -q "^--rereadpt $root/dev/sda$" "$root/blockdev.log"; then
        printf 'PASS %s\n' "$name"
    else
        printf 'FAIL %s\n' "$name" >&2
        sed -n '1,160p' "$root/output.log" >&2
        exit 1
    fi
}

expect_failure() {
    name=$1
    root=$2
    if run_gate "$root" select-disk > "$root/output.log" 2>&1; then
        printf 'FAIL %s unexpectedly succeeded\n' "$name" >&2
        exit 1
    fi
    if [ -s "$root/disk.log" ]; then
        printf 'FAIL %s wrote target bytes before rejection\n' "$name" >&2
        exit 1
    fi
    printf 'PASS %s\n' "$name"
}

root=$(make_fixture valid)
expect_success valid_exact_match "$root"

root=$(make_fixture missing-network-driver)
rm -rf "$root/sys/class/net/en0"
mkdir -p "$root/package-pool/main/l/linux-signed-amd64"
: > "$root/package-pool/main/l/linux-signed-amd64/nic-modules-test-kernel-di_1.udeb"
expect_success missing_network_driver_is_loaded "$root"
grep -q '^--unpack .*nic-modules-test-kernel-di_1.udeb$' "$root/network.log"
grep -q '^hw-detect$' "$root/network.log"

root=$(make_fixture missing-network-package)
rm -rf "$root/sys/class/net/en0"
expect_failure missing_network_module_package_is_blocked "$root"

root=$(make_fixture ambiguous-network-packages)
rm -rf "$root/sys/class/net/en0"
mkdir -p "$root/package-pool/main/l/linux-signed-amd64"
: > "$root/package-pool/main/l/linux-signed-amd64/nic-modules-test-kernel-di_1.udeb"
: > "$root/package-pool/main/l/linux-signed-amd64/nic-modules-test-kernel-di_2.udeb"
expect_failure ambiguous_network_module_packages_are_blocked "$root"

root=$(make_fixture wrong-dmi)
printf 'OTHER-SERIAL\n' > "$root/sys/class/dmi/id/product_serial"
expect_failure wrong_dmi_is_blocked "$root"

root=$(make_fixture disabled-role)
sed 's/destructive_install_enabled=true/destructive_install_enabled=false/' \
    "$root/media/dns01.conf" > "$root/media/dns01.conf.new"
mv "$root/media/dns01.conf.new" "$root/media/dns01.conf"
expect_failure disabled_role_is_blocked "$root"

root=$(make_fixture duplicate-disk)
make_disk "$root" sdc 0 'TEST SSD' 'TEST-DISK-01' 2097152
expect_failure duplicate_matching_disks_are_blocked "$root"

root=$(make_fixture extra-nonmatching-disk)
make_disk "$root" sdc 0 'OTHER SSD' 'OTHER-DISK-02' 4194304
expect_success extra_nonmatching_disk_is_ignored "$root"

root=$(make_fixture undersized-disk)
printf '1024\n' > "$root/sys/class/block/sda/size"
expect_failure undersized_disk_is_blocked "$root"

root=$(make_fixture removable-target)
printf '1\n' > "$root/sys/class/block/sda/removable"
expect_failure removable_target_is_blocked "$root"

root=$(make_fixture fixed-usb-target)
make_disk "$root" sda 0 'TEST SSD' 'TEST-DISK-01' 2097152 usb
expect_failure usb_transport_target_is_blocked "$root"

root=$(make_fixture installer-media)
make_partition "$root" sda sda1
printf '/dev/sda1 /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure installer_media_is_never_targeted "$root"

root=$(make_fixture ventoy-mapper-media)
make_mapper "$root" dm-0 Ventoy sdb1
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_success ventoy_mapper_media_keeps_exact_target_selection "$root"

root=$(make_fixture ventoy-mapper-on-target)
make_partition "$root" sda sda1
make_mapper "$root" dm-0 Ventoy sda1
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure ventoy_mapper_backing_disk_is_never_targeted "$root"

root=$(make_fixture unresolved-ventoy-mapper)
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure unresolved_ventoy_mapper_fails_closed "$root"

root=$(make_fixture ambiguous-ventoy-mapper)
make_mapper "$root" dm-0 Ventoy sdb1
make_mapper "$root" dm-1 Ventoy sdb1
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure ambiguous_ventoy_mapper_fails_closed "$root"

root=$(make_fixture multi-slave-ventoy-mapper)
make_partition "$root" sda sda1
make_mapper "$root" dm-0 Ventoy sdb1
ln -s "$root/sys/class/block/sda1" \
    "$root/sys/class/block/dm-0/slaves/sda1"
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure multi_slave_installer_media_fails_closed "$root"

root=$(make_fixture loop-installer-media)
mkdir -p "$root/sys/class/block/loop0"
printf '/dev/loop0 /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure loop_installer_media_fails_closed "$root"

root=$(make_fixture md-installer-media)
mkdir -p "$root/sys/class/block/md0"
printf '/dev/md0 /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure md_installer_media_fails_closed "$root"

root=$(make_fixture cyclic-installer-mapper)
make_mapper "$root" dm-0 Ventoy dm-1
make_mapper "$root" dm-1 Other dm-0
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure cyclic_installer_ancestry_fails_closed "$root"

root=$(make_fixture mounted-target)
make_partition "$root" sda sda2
printf '/dev/sdb1 /cdrom iso9660 ro 0 0\n/dev/sda2 /target ext4 rw 0 0\n' > "$root/mounts"
expect_failure mounted_target_is_blocked "$root"

root=$(make_fixture mapper-mounted-target)
make_partition "$root" sda sda2
make_mapper "$root" dm-1 crypt-root sda2
printf '/dev/sdb1 /cdrom iso9660 ro 0 0\n/dev/mapper/crypt-root /target ext4 rw 0 0\n' > "$root/mounts"
expect_failure mapper_mounted_target_is_blocked "$root"

root=$(make_fixture by-uuid-mounted-target)
make_partition "$root" sda sda2
mkdir -p "$root/dev/disk/by-uuid"
ln -s "$root/sys/class/block/sda2" "$root/dev/sda2"
ln -s ../../sda2 "$root/dev/disk/by-uuid/test-root"
printf '/dev/sdb1 /cdrom iso9660 ro 0 0\n/dev/disk/by-uuid/test-root /target ext4 rw 0 0\n' > "$root/mounts"
expect_failure by_uuid_mounted_target_is_blocked "$root"

root=$(make_fixture active-swap-target)
make_partition "$root" sda sda3
printf '/dev/sda3 partition 1048572 0 -2\n' >> "$root/swaps"
expect_failure active_swap_target_is_blocked "$root"

root=$(make_fixture held-target)
make_partition "$root" sda sda2
make_mapper "$root" dm-1 crypt-root sda2
mkdir -p "$root/sys/class/block/sda2/holders"
ln -s "$root/sys/class/block/dm-1" \
    "$root/sys/class/block/sda2/holders/dm-1"
expect_failure held_target_is_blocked "$root"

root=$(make_fixture duplicate-mac)
mkdir -p "$root/sys/class/net/en1"
printf '00:11:22:33:44:55\n' > "$root/sys/class/net/en1/address"
expect_failure duplicate_matching_interfaces_are_blocked "$root"

root=$(make_fixture completed-role)
mkdir -p "$root/enrollment/records/dns01"
printf 'generation-old\n' > "$root/enrollment/records/dns01/ACTIVE"
expect_failure completed_role_without_token_is_blocked "$root"

root=$(make_fixture valid-reinstall-token)
mkdir -p "$root/enrollment/records/dns01" "$root/enrollment/reinstall"
printf 'generation-old\n' > "$root/enrollment/records/dns01/ACTIVE"
cat > "$root/enrollment/reinstall/dns01.allow" <<EOF
role=dns01
system_uuid_sha256=$(hash_value '11111111-2222-3333-4444-555555555555')
previous_generation=generation-old
authorize_erase=true
EOF
expect_success matching_reinstall_token_is_allowed "$root"

root=$(make_fixture stale-reinstall-token)
mkdir -p "$root/enrollment/records/dns01" "$root/enrollment/reinstall"
printf 'generation-new\n' > "$root/enrollment/records/dns01/ACTIVE"
cat > "$root/enrollment/reinstall/dns01.allow" <<EOF
role=dns01
system_uuid_sha256=$(hash_value '11111111-2222-3333-4444-555555555555')
previous_generation=generation-old
authorize_erase=true
EOF
expect_failure stale_reinstall_token_is_blocked "$root"

printf 'RESULT 29/29 install-gate simulations passed\n'
