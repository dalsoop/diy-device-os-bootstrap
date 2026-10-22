#!/bin/sh
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
gate=$repo_root/dns-image/scripts/install-gate
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dns-install-gate.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

mkdir -p "$test_root/bin"
cat > "$test_root/bin/confmodule" <<'EOF'
db_set() { :; }
db_fset() { printf 'FLAG %s\n' "$*" >> "$DNS_TEST_DEBCONF_LOG"; }
db_input() { :; }
db_go() { [ "${DNS_TEST_CANCEL:-false}" = false ]; }
db_stop() { echo 'shared installer frontend must remain connected' >&2; return 1; }
db_x_loadtemplatefile() { :; }
db_subst() {
    if [ "$2" = confirmation ]; then printf '%s\n' "$3" > "$DNS_TEST_CONFIRMATION"; fi
}
db_get() {
    case "$1" in
        dns-appliance/role) RET=${DNS_TEST_ROLE:-dns01} ;;
        dns-appliance/interface) RET=${DNS_TEST_INTERFACE:-en0} ;;
        dns-appliance/erase)
            RET=$(cat "$DNS_TEST_CONFIRMATION")
            [ "${DNS_TEST_WRONG_CONFIRMATION:-false}" = false ] || RET=ERASE
            ;;
        *) return 1 ;;
    esac
}
EOF
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
cat > "$test_root/bin/ata-id" <<'EOF'
#!/bin/sh
[ "$1" = --export ] || exit 1
case "$2" in */dev/sda) root=${2%/dev/sda} ;; *) exit 1 ;; esac
cat "$root/ata.properties"
EOF
chmod 0755 "$test_root/bin/sha256sum" "$test_root/bin/debconf-set" \
    "$test_root/bin/dns-test-dd" "$test_root/bin/dns-test-blockdev" "$test_root/bin/ata-id" \
    "$test_root/bin/dns-test-sync"

normalize() {
    LC_ALL=C tr '[:lower:]' '[:upper:]' |
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
    DNS_DISK_ATA_ID_COMMAND="$test_root/bin/ata-id" \
    DNS_INSTALLER_ZERO_COMMAND="$test_root/bin/dns-test-dd" \
    DNS_INSTALLER_BLOCKDEV_COMMAND="$test_root/bin/dns-test-blockdev" \
    DNS_INSTALLER_SYNC_COMMAND="$test_root/bin/dns-test-sync" \
    DNS_INSTALLER_DEBCONF_MODULE="$test_root/bin/confmodule" \
    DNS_TEST_CONFIRMATION="$root/confirmation" \
    DNS_TEST_DEBCONF_LOG="$root/debconf.log" \
    DNS_TEST_DISK_LOG="$root/disk.log" \
    DNS_TEST_BLOCKDEV_LOG="$root/blockdev.log" \
    DNS_TEST_SYNC_LOG="$root/sync.log" \
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
        grep -q '^grub-installer/bootdev /dev/sda$' "$root/debconf.log" &&
        [ "$(wc -l < "$root/disk.log" | tr -d ' ')" -eq 2 ] &&
        grep -q "of=$root/dev/sda bs=512 count=131072" "$root/disk.log" &&
        grep -q "of=$root/dev/sda bs=512 seek=1966080 count=131072" "$root/disk.log" &&
        grep -qx sync "$root/sync.log" &&
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

make_guided_fixture() {
    root=$(make_fixture "$1")
    printf 'guided\n' > "$root/media/install-mode"
    cp "$repo_root/dns-image/scripts/guided.templates" "$root/media/guided.templates"
    sed 's/destructive_install_enabled=true/destructive_install_enabled=false/' \
        "$root/media/dns01.conf" > "$root/media/dns01.conf.new"
    mv "$root/media/dns01.conf.new" "$root/media/dns01.conf"
    mkdir -p "$root/sys/class/net/en0/device"
    printf '%s\n' "$root"
}

identify_guided() {
    root=$1
    run_gate "$root" identify > "$root/identify.log" 2>&1 || {
        cat "$root/identify.log" >&2
        exit 1
    }
    [ ! -s "$root/disk.log" ] || { echo 'guided capture wrote a disk' >&2; exit 1; }
    [ -s "$root/run/erase-confirmation" ] || exit 1
}

expect_identify_failure() {
    name=$1
    root=$2
    if run_gate "$root" identify > "$root/identify.log" 2>&1; then
        printf 'FAIL %s unexpectedly identified\n' "$name" >&2
        exit 1
    fi
    [ ! -s "$root/disk.log" ] && [ ! -s "$root/run/erase-confirmation" ] || exit 1
    printf 'PASS %s\n' "$name"
}

root=$(make_guided_fixture guided-valid)
identify_guided "$root"
for question in choose_interface get_hostname get_domain get_ipaddress get_netmask get_gateway get_nameservers confirm_static; do
    grep -qx "FLAG netcfg/$question seen true" "$root/debconf.log"
done
expect_success guided_capture_then_install_exact_target "$root"

make_sata_fixture() {
    root=$(make_guided_fixture "$1")
    rm "$root/sys/class/block/sda/device/serial"
    printf 'ID_ATA=1\nID_TYPE=disk\nID_SERIAL_SHORT=TEST-DISK-01\n' > "$root/ata.properties"
    printf '%s\n' "$root"
}

root=$(make_sata_fixture guided-sata)
identify_guided "$root"
expect_success guided_sata_identity_is_rechecked_before_install "$root"
DNS_INVENTORY_SYS_ROOT="$root/sys" DNS_INVENTORY_DEVICE_ROOT="$root/dev" \
    DNS_DISK_ATA_ID_COMMAND="$test_root/bin/ata-id" \
    /bin/sh "$repo_root/dns-image/capture-inventory" dns01 10.0.5.1 en0 /dev/sda \
    > "$root/captured.conf"
grep -qx "expected_disk_serial_sha256=$(hash_value TEST-DISK-01)" "$root/captured.conf"
printf 'PASS capture_and_install_share_sata_serial_identity\n'

root=$(make_sata_fixture guided-sata-changed)
identify_guided "$root"
printf 'ID_ATA=1\nID_TYPE=disk\nID_SERIAL_SHORT=REPLACED\n' > "$root/ata.properties"
expect_failure guided_rejects_changed_sata_serial "$root"

root=$(make_sata_fixture guided-sata-missing)
printf 'ID_ATA=1\nID_TYPE=disk\n' > "$root/ata.properties"
expect_identify_failure guided_rejects_missing_sata_serial "$root"

root=$(make_sata_fixture guided-sata-duplicate)
printf 'ID_SERIAL_SHORT=OTHER\n' >> "$root/ata.properties"
expect_identify_failure guided_rejects_ambiguous_sata_serial "$root"

root=$(make_sata_fixture guided-sata-probe-failure)
rm "$root/ata.properties"
expect_identify_failure guided_rejects_failed_sata_identity_probe "$root"

root=$(make_sata_fixture guided-sata-not-ata)
printf 'ID_ATA=0\nID_TYPE=disk\nID_SERIAL_SHORT=TEST-DISK-01\n' > "$root/ata.properties"
expect_identify_failure guided_rejects_unverified_ata_identity "$root"

root=$(make_guided_fixture guided-block-serial)
mv "$root/sys/class/block/sda/device/serial" "$root/sys/class/block/sda/serial"
identify_guided "$root"
expect_success guided_supports_kernel_block_serial_attribute "$root"

root=$(make_guided_fixture guided-padded-identity)
printf '  TEST SSD   \n' > "$root/sys/class/block/sda/device/model"
printf 'TEST-DISK-01         \n' > "$root/sys/class/block/sda/device/serial"
identify_guided "$root"
grep -qx 'ERASE dns01 /dev/sda TEST-DISK-01 1073741824' "$root/run/erase-confirmation"
expect_success guided_padding_does_not_enter_erase_confirmation "$root"

root=$(make_guided_fixture guided-second-unreadable)
make_disk "$root" sdc 0 'OTHER SSD' 'OTHER-DISK-02' 4194304
rm "$root/sys/class/block/sdc/device/serial"
expect_identify_failure guided_never_ignores_unreadable_second_disk "$root"

root=$(make_guided_fixture guided-unconfirmed)
expect_failure guided_cannot_skip_capture_and_confirmation "$root"

root=$(make_guided_fixture guided-wrong-confirmation)
DNS_TEST_WRONG_CONFIRMATION=true
export DNS_TEST_WRONG_CONFIRMATION
expect_identify_failure guided_rejects_inexact_erase_phrase "$root"
unset DNS_TEST_WRONG_CONFIRMATION

root=$(make_guided_fixture guided-cancel)
DNS_TEST_CANCEL=true
export DNS_TEST_CANCEL
expect_identify_failure guided_cancel_never_enables_install "$root"
unset DNS_TEST_CANCEL

root=$(make_guided_fixture guided-second-disk)
make_disk "$root" sdc 0 'OTHER SSD' 'OTHER-DISK-02' 4194304
expect_identify_failure guided_rejects_multiple_internal_disks "$root"

root=$(make_guided_fixture guided-usb)
make_disk "$root" sda 0 'TEST SSD' 'TEST-DISK-01' 2097152 usb
expect_identify_failure guided_rejects_usb_backed_target "$root"

root=$(make_guided_fixture guided-removable)
printf '1\n' > "$root/sys/class/block/sda/removable"
expect_identify_failure guided_rejects_removable_target "$root"

root=$(make_guided_fixture guided-mounted)
printf '/dev/sda1 /target ext4 rw 0 0\n' >> "$root/mounts"
expect_identify_failure guided_rejects_mounted_target "$root"

root=$(make_guided_fixture guided-completed)
mkdir -p "$root/enrollment/records/dns01"
printf 'old-generation\n' > "$root/enrollment/records/dns01/ACTIVE"
expect_identify_failure guided_rejects_active_role_without_token "$root"

root=$(make_guided_fixture guided-hardware-changed)
identify_guided "$root"
printf 'REPLACED-SERIAL\n' > "$root/sys/class/dmi/id/product_serial"
expect_failure guided_rechecks_system_identity_before_partitioning "$root"

root=$(make_guided_fixture guided-disk-size-changed)
identify_guided "$root"
printf '4194304\n' > "$root/sys/class/block/sda/size"
expect_failure guided_requires_exact_confirmed_disk_size "$root"

root=$(make_guided_fixture guided-extra-disk-after-confirm)
identify_guided "$root"
make_disk "$root" sdc 0 'OTHER SSD' 'OTHER-DISK-02' 4194304
expect_failure guided_rechecks_single_target_before_partitioning "$root"

root=$(make_guided_fixture guided-missing-confirmation)
identify_guided "$root"
rm "$root/run/erase-confirmation"
expect_failure guided_requires_confirmation_at_partition_time "$root"

root=$(make_guided_fixture guided-invalid-role)
DNS_TEST_ROLE=../../other
export DNS_TEST_ROLE
expect_identify_failure guided_rejects_invalid_role "$root"
unset DNS_TEST_ROLE

root=$(make_guided_fixture guided-invalid-interface)
DNS_TEST_INTERFACE=missing0
export DNS_TEST_INTERFACE
expect_identify_failure guided_rejects_unoffered_interface "$root"
unset DNS_TEST_INTERFACE

root=$(make_guided_fixture guided-unknown-mode)
printf 'unknown\n' > "$root/media/install-mode"
expect_failure unknown_install_mode_is_blocked "$root"

root=$(make_guided_fixture guided-invalid-network)
sed 's/gateway=10.0.0.1/gateway=192.168.0.1/' "$root/media/dns01.conf" > "$root/media/dns01.new"
mv "$root/media/dns01.new" "$root/media/dns01.conf"
expect_identify_failure guided_rejects_unreachable_gateway "$root"

root=$(make_guided_fixture guided-duplicate-profile-field)
printf 'address=10.0.5.9\n' >> "$root/media/dns01.conf"
expect_identify_failure guided_rejects_duplicate_profile_fields "$root"

root=$(make_guided_fixture guided-unsafe-network)
printf 'domain=home.arpa;false\n' >> "$root/media/dns01.conf"
expect_identify_failure guided_rejects_unsafe_network_values "$root"

root=$(make_guided_fixture guided-disk-serial-changed)
identify_guided "$root"
printf 'NEW-DISK\n' > "$root/sys/class/block/sda/device/serial"
expect_failure guided_rechecks_disk_serial_before_partitioning "$root"

root=$(make_guided_fixture guided-target-is-now-installer)
identify_guided "$root"
make_partition "$root" sda sda1
printf '/dev/sda1 /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure guided_rechecks_installer_parent_before_partitioning "$root"

root=$(make_guided_fixture guided-mounted-mapper)
make_partition "$root" sda sda1
make_mapper "$root" dm-0 target-root sda1
printf '/dev/mapper/target-root /target ext4 rw 0 0\n' >> "$root/mounts"
expect_identify_failure guided_rejects_mounted_mapper_backing_disk "$root"

root=$(make_guided_fixture guided-active-swap)
make_partition "$root" sda sda1
printf '/dev/sda1 partition 1024 0 -2\n' >> "$root/swaps"
expect_identify_failure guided_rejects_active_swap_backing_disk "$root"

root=$(make_guided_fixture guided-active-holder)
mkdir -p "$root/sys/class/block/sda/holders/dm-0"
expect_identify_failure guided_rejects_active_block_holder "$root"

printf 'RESULT reviewed and guided install-gate simulations passed\n'
