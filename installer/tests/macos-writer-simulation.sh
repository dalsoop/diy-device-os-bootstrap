#!/bin/bash
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
writer=$repo_root/usb-media/write-image-macos
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
mock_bin=$temporary/bin
log=$temporary/commands.log
image=$temporary/device-os.raw
mkdir -p "$mock_bin"
truncate -s 2097152 "$image"

make_mock() {
    name=$1
    shift
    printf '%s\n' '#!/bin/sh' "$@" > "$mock_bin/$name"
    chmod +x "$mock_bin/$name"
}

make_mock uname 'echo Darwin'
make_mock id 'echo 0'
make_mock stat 'echo 2097152'
# shellcheck disable=SC2016
make_mock plutil '
case "$2" in
  WholeDisk) echo true ;;
  Internal) echo false ;;
  Removable) echo true ;;
  WritableMedia) echo true ;;
  VirtualOrPhysical) echo Physical ;;
  MediaName) echo "Test USB" ;;
  TotalSize) echo 2097152 ;;
  *) exit 1 ;;
esac'
# shellcheck disable=SC2016
make_mock od '
case " $* " in
  *" -j 450 "*) echo " ${TEST_MBR_TYPE:-7}" ;;
  *" -j 510 "*) echo " 55 aa" ;;
  *) exit 1 ;;
esac'
# shellcheck disable=SC2016
make_mock diskutil '
printf "diskutil %s\n" "$*" >> "$TEST_LOG"
case "$1" in
  info) echo plist ;;
  unmountDisk|eject) : ;;
  *) exit 1 ;;
esac'
# shellcheck disable=SC2016
make_mock dd '
printf "dd %s\n" "$*" >> "$TEST_LOG"'
# shellcheck disable=SC2016
make_mock sync '
echo sync >> "$TEST_LOG"'
# shellcheck disable=SC2016
make_mock cmp '
printf "cmp %s\n" "$*" >> "$TEST_LOG"
if [ "${TEST_FAIL_BODY_COMPARE:-0}" = 1 ] && [ "$1" = -i ]; then
  exit 1
fi'

run_writer() {
    PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" "$writer" \
        --image "$image" \
        --device /dev/disk9 \
        --confirm 'ERASE /dev/disk9 Test USB 2097152'
}

run_writer >/dev/null
cat > "$temporary/expected.log" <<EOF
diskutil info -plist /dev/disk9
diskutil unmountDisk /dev/disk9
dd if=/dev/zero of=/dev/rdisk9 bs=1m count=1 conv=notrunc
sync
dd if=$image of=/dev/rdisk9 bs=1m skip=1 seek=1 conv=notrunc
sync
cmp -i 1048576:1048576 -n 1048576 $image /dev/rdisk9
dd if=$image of=/dev/rdisk9 bs=1m count=1 conv=notrunc
sync
cmp -n 1048576 $image /dev/rdisk9
diskutil unmountDisk /dev/disk9
diskutil eject /dev/disk9
EOF
diff -u "$temporary/expected.log" "$log"

: > "$log"
if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" TEST_FAIL_BODY_COMPARE=1 \
    "$writer" --image "$image" --device /dev/disk9 \
    --confirm 'ERASE /dev/disk9 Test USB 2097152' >/dev/null 2>&1; then
    echo "macos-writer-simulation: body readback failure was accepted" >&2
    exit 1
fi
if grep -q 'count=1 conv=notrunc$' "$log" &&
    [ "$(grep -c 'count=1 conv=notrunc$' "$log")" -gt 1 ]; then
    echo "macos-writer-simulation: partition map was exposed after body failure" >&2
    exit 1
fi
if grep -q '^diskutil eject ' "$log"; then
    echo "macos-writer-simulation: failed media was ejected as successful" >&2
    exit 1
fi

: > "$log"
if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" TEST_MBR_TYPE=238 \
    "$writer" --image "$image" --device /dev/disk9 \
    --confirm 'ERASE /dev/disk9 Test USB 2097152' >/dev/null 2>&1; then
    echo "macos-writer-simulation: GPT image was accepted" >&2
    exit 1
fi
if grep -qE '^(dd |diskutil unmountDisk |diskutil eject )' "$log"; then
    echo "macos-writer-simulation: GPT rejection reached a destructive command" >&2
    exit 1
fi

echo "macOS writer simulations: passed"
