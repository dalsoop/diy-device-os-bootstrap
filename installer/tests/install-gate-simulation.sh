#!/bin/sh
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
chmod 0755 "$test_root/bin/sha256sum" "$test_root/bin/debconf-set"

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
    mkdir -p "$root/sys/class/block/$disk/device"
    printf '%s\n' "$removable" > "$root/sys/class/block/$disk/removable"
    printf '%s\n' "$model" > "$root/sys/class/block/$disk/device/model"
    printf '%s\n' "$serial" > "$root/sys/class/block/$disk/device/serial"
    printf '%s\n' "$sectors" > "$root/sys/class/block/$disk/size"
}

make_fixture() {
    name=$1
    root=$test_root/$name
    mkdir -p "$root/media" "$root/run" "$root/enrollment" \
        "$root/sys/class/dmi/id" "$root/sys/class/net/en0"

    printf 'HP ProDesk Test\n' > "$root/sys/class/dmi/id/product_name"
    printf 'TEST-SKU\n' > "$root/sys/class/dmi/id/product_sku"
    printf 'TEST-SERIAL-01\n' > "$root/sys/class/dmi/id/product_serial"
    printf '11111111-2222-3333-4444-555555555555\n' > "$root/sys/class/dmi/id/product_uuid"
    printf '00:11:22:33:44:55\n' > "$root/sys/class/net/en0/address"

    make_disk "$root" sda 0 'TEST SSD' 'TEST-DISK-01' 2097152
    make_disk "$root" sdb 1 'TEST USB' 'TEST-USB-01' 4194304
    printf '/dev/sdb /cdrom iso9660 ro 0 0\n' > "$root/mounts"

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
    DNS_INSTALLER_DEBCONF_SET="$test_root/bin/debconf-set" \
    DNS_INSTALLER_ENROLLMENT_DIR="$root/enrollment" \
    DNS_TEST_DEBCONF_LOG="$root/debconf.log" \
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
        grep -q '^NIC_MAC=00:11:22:33:44:55$' "$root/run/install.env" &&
        grep -q '^partman-auto/disk /dev/sda$' "$root/debconf.log"; then
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

root=$(make_fixture installer-media)
printf '/dev/sda /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_failure installer_media_is_never_targeted "$root"

root=$(make_fixture ventoy-mapper-media)
printf '/dev/mapper/Ventoy /cdrom iso9660 ro 0 0\n' > "$root/mounts"
expect_success ventoy_mapper_media_keeps_exact_target_selection "$root"

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

printf 'RESULT 13/13 install-gate simulations passed\n'
