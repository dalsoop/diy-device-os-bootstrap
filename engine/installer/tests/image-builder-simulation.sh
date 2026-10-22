#!/bin/bash
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
builder=$repo_root/usb-media/build-image-linux
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
mock_bin=$temporary/bin
log=$temporary/commands.log
catalog=$temporary/catalog.json
output=$temporary/device-os.raw
mkdir -p "$mock_bin"
cat > "$catalog" <<EOF
{
  "schema_version": 2,
  "distribution_policy": {
    "schema_version": 1,
    "source_release": {"enabled": true},
    "generated_artifacts": {"enabled": false},
    "prebuilt_release": {"enabled": false, "required_github_environment": "prebuilt-distribution"}
  },
  "bootloader": {"id": "ventoy", "redistribution": {"status": "personal-use-only"}},
  "entries": [{"id": "debian-live", "source": {"kind": "locked-download", "sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}, "redistribution": {"status": "personal-use-only"}}],
  "catalog": {
    "revision": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "tree": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }
}
EOF

checker=$temporary/checker
cat > "$checker" <<'EOF'
#!/bin/sh
[ "${DEVICE_OS_DISTRIBUTION_POLICY:-}" = "${EXPECTED_POLICY:?}" ] || exit 88
if [ "${TEST_POLICY_DENY:-0}" = 1 ]; then
  exit 1
fi
cat <<'JSON'
{"schema_version":1,"mode":"personal-use","decision":"allow","selected_artifacts":[{"id":"ventoy","kind":"bootloader","sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","status":"personal-use-only"},{"id":"debian-live","kind":"catalog-entry","sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","status":"personal-use-only"}],"blockers":[],"warnings":[{"code":"artifact-unreviewed","artifact_id":"ventoy","message":"Public redistribution is not approved."}]}
JSON
EOF
chmod +x "$checker"

make_mock() {
    name=$1
    shift
    printf '%s\n' '#!/bin/sh' "$@" > "$mock_bin/$name"
    chmod +x "$mock_bin/$name"
}

make_mock uname 'echo Linux'
make_mock id 'echo 0'
# shellcheck disable=SC2016
make_mock losetup '
if [ "$1" = --find ]; then
  echo /dev/loop9
else
  printf "losetup %s\n" "$*" >> "$TEST_LOG"
fi'
make_mock lsblk 'echo loop'
# shellcheck disable=SC2016
make_mock blockdev '
case "$1" in
  --getsize64) echo 4294967296 ;;
  --flushbufs) printf "blockdev %s\n" "$*" >> "$TEST_LOG" ;;
  *) exit 1 ;;
esac'
make_mock stat 'echo 4294967296'
# shellcheck disable=SC2016
make_mock sha256sum 'printf "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  %s\n" "$1"'

writer=$temporary/writer
cat > "$writer" <<'EOF'
#!/bin/sh
[ "${DEVICE_OS_INTERNAL_IMAGE_BUILD:-0}" = 1 ]
[ -n "${DEVICE_OS_LICENSE_DECISION_OUTPUT:-}" ]
jq '.selected_artifacts += [
  {id:"runtime-component",kind:"component",sha256:("e"*64),status:"redistribution-reviewed"},
  {id:"media-final",kind:"final-artifact",sha256:("f"*64),status:"redistribution-reviewed"}
]' "$DEVICE_OS_LICENSE_DECISION_OUTPUT" > "$DEVICE_OS_LICENSE_DECISION_OUTPUT.next"
mv "$DEVICE_OS_LICENSE_DECISION_OUTPUT.next" "$DEVICE_OS_LICENSE_DECISION_OUTPUT"
printf 'writer %s\n' "$*" >> "$TEST_LOG"
EOF
chmod +x "$writer"

PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" \
EXPECTED_POLICY="$repo_root/usb-media/distribution-policy.json" \
DEVICE_OS_DISTRIBUTION_POLICY="$temporary/ambient-policy.json" \
DEVICE_OS_SKIP_LOOP_NODE_SETUP=1 \
DEVICE_OS_IMAGE_WRITER="$writer" \
DEVICE_OS_LICENSE_CHECKER="$checker" \
    "$builder" --output "$output" --size 4294967296 --catalog "$catalog" >/dev/null

[ -f "$output" ]
[ -f "$output.sha256" ]
[ -f "$output.manifest.json" ]
grep -q '  device-os.raw$' "$output.sha256"
jq -e '
  .schema_version == 2 and
  .kind == "device-os-raw-image" and
  .image.filename == "device-os.raw" and
  .image.bytes == 4294967296 and
  .image.sha256 == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and
  .catalog.sha256 == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and
  .catalog.revision == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and
  .catalog.tree == "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" and
  .license.mode == "personal-use" and
  .license.decision == "allow" and
  .license.distribution_policy_sha256 == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and
  [.license.selected_artifacts[].id] == ["ventoy", "debian-live", "runtime-component", "media-final"] and
  .license.selected_artifacts[2].sha256 == ("e"*64) and
  .license.selected_artifacts[2].status == "redistribution-reviewed" and
  .license.selected_artifacts[3].sha256 == ("f"*64) and
  .world == null
' "$output.manifest.json" >/dev/null
grep -q '^writer --device /dev/loop9 --catalog .* --image-build$' "$log"
grep -q '^blockdev --flushbufs /dev/loop9$' "$log"
grep -q '^losetup -d /dev/loop9$' "$log"

if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" \
    DEVICE_OS_SKIP_LOOP_NODE_SETUP=1 \
    DEVICE_OS_IMAGE_WRITER="$writer" \
    "$builder" --output "$output" --size 4294967296 --catalog "$catalog" \
    >/dev/null 2>&1; then
    echo "image-builder-simulation: existing output was overwritten" >&2
    exit 1
fi

: > "$log"
policy_refusal=$temporary/policy-refusal.raw
if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" TEST_POLICY_DENY=1 \
    EXPECTED_POLICY="$repo_root/usb-media/distribution-policy.json" \
    DEVICE_OS_DISTRIBUTION_POLICY="$temporary/ambient-policy.json" \
    DEVICE_OS_SKIP_LOOP_NODE_SETUP=1 \
    DEVICE_OS_IMAGE_WRITER="$writer" \
    DEVICE_OS_LICENSE_CHECKER="$checker" \
    "$builder" --output "$policy_refusal" --size 4294967296 --catalog "$catalog" \
    >/dev/null 2>&1; then
    echo "image-builder-simulation: denied license policy was accepted" >&2
    exit 1
fi
[ ! -e "$policy_refusal" ]
if grep -q '^writer ' "$log"; then
    echo "image-builder-simulation: policy refusal reached the image writer" >&2
    exit 1
fi

sidecar_only=$temporary/sidecar-only.raw
: > "$sidecar_only.sha256"
if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" \
    DEVICE_OS_SKIP_LOOP_NODE_SETUP=1 \
    DEVICE_OS_IMAGE_WRITER="$writer" \
    "$builder" --output "$sidecar_only" --size 4294967296 --catalog "$catalog" \
    >/dev/null 2>&1; then
    echo "image-builder-simulation: existing checksum was overwritten" >&2
    exit 1
fi
[ ! -e "$sidecar_only" ]

manifest_only=$temporary/manifest-only.raw
: > "$manifest_only.manifest.json"
if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" \
    DEVICE_OS_SKIP_LOOP_NODE_SETUP=1 \
    DEVICE_OS_IMAGE_WRITER="$writer" \
    "$builder" --output "$manifest_only" --size 4294967296 --catalog "$catalog" \
    >/dev/null 2>&1; then
    echo "image-builder-simulation: existing image manifest was overwritten" >&2
    exit 1
fi
[ ! -e "$manifest_only" ]

if PATH="$mock_bin:/usr/bin:/bin" TEST_LOG="$log" \
    DEVICE_OS_SKIP_LOOP_NODE_SETUP=1 \
    DEVICE_OS_IMAGE_WRITER="$writer" \
    "$builder" --output "$temporary/small.raw" --size 1073741824 --catalog "$catalog" \
    >/dev/null 2>&1; then
    echo "image-builder-simulation: undersized image was accepted" >&2
    exit 1
fi

installer_fixture=$temporary/debian-installer-fixture
installer_bin=$temporary/installer-bin
mkdir -p "$installer_fixture" "$installer_bin"
printf 'test component\n' > "$installer_fixture/component"
component_digest=$(sha256sum "$installer_fixture/component" | awk '{print $1}')
for file in cdrom/initrd.gz cdrom/vmlinuz cdrom/debian-cd_info.tar.gz \
    cdrom/gtk/initrd.gz cdrom/gtk/vmlinuz cdrom/gtk/debian-cd_info.tar.gz; do
    printf '%s  ./%s\n' "$component_digest" "$file"
done > "$installer_fixture/SHA256SUMS"
list_digest=$(sha256sum "$installer_fixture/SHA256SUMS" | awk '{print $1}')
printf 'SHA256:\n %s 1 main/installer-amd64/current/images/SHA256SUMS\n' \
    "$list_digest" > "$installer_fixture/Release"
printf 'test signature\n' > "$installer_fixture/Release.gpg"
cat > "$installer_bin/curl" <<'EOF'
#!/bin/sh
set -eu
output=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --output) output=$2; shift 2 ;;
        --proto|--tlsv1.2) if [ "$1" = --proto ]; then shift 2; else shift; fi ;;
        --fail|--location) shift ;;
        *) url=$1; shift ;;
    esac
done
case "$url" in
    */Release) source=Release ;;
    */Release.gpg) source=Release.gpg ;;
    */SHA256SUMS) source=SHA256SUMS ;;
    *) source=component ;;
esac
cp "$DNS_TEST_INSTALLER_FIXTURE/$source" "$output"
if [ "$source" = component ] && [ "${DNS_TEST_TAMPER_COMPONENT:-false}" = true ]; then
    printf 'tampered\n' >> "$output"
fi
EOF
cat > "$installer_bin/gpgv" <<'EOF'
#!/bin/sh
[ "${DNS_TEST_BAD_SIGNATURE:-false}" = false ]
EOF
chmod 0755 "$installer_bin/curl" "$installer_bin/gpgv"
fetch_installer() {
    PATH="$installer_bin:$PATH" DNS_TEST_INSTALLER_FIXTURE="$installer_fixture" \
        DNS_APPLIANCE_CACHE_DIR="$1" "$repo_root/dns-image/fetch-debian-installer"
}
fetch_installer "$temporary/verified-installer" > "$temporary/installer-fetch.log" 2>&1
fetch_installer "$temporary/verified-installer" >> "$temporary/installer-fetch.log" 2>&1
cached_component=$(find "$temporary/verified-installer" -name vmlinuz -print -quit)
printf 'tampered\n' >> "$cached_component"
if fetch_installer "$temporary/verified-installer" >> "$temporary/installer-fetch.log" 2>&1; then
    echo 'image-builder-simulation: tampered installer cache accepted' >&2; exit 1
fi
if DNS_TEST_BAD_SIGNATURE=true fetch_installer "$temporary/bad-signature" >> "$temporary/installer-fetch.log" 2>&1; then
    echo 'image-builder-simulation: unsigned installer metadata accepted' >&2; exit 1
fi
if DNS_TEST_TAMPER_COMPONENT=true fetch_installer "$temporary/bad-component" >> "$temporary/installer-fetch.log" 2>&1; then
    echo 'image-builder-simulation: tampered installer download accepted' >&2; exit 1
fi
printf 'tampered metadata\n' >> "$installer_fixture/SHA256SUMS"
if fetch_installer "$temporary/bad-checksums" >> "$temporary/installer-fetch.log" 2>&1; then
    echo 'image-builder-simulation: unbound installer checksum list accepted' >&2; exit 1
fi
[ -z "$(find "$temporary/verified-installer" "$temporary/bad-signature" \
    "$temporary/bad-component" "$temporary/bad-checksums" -name '.verify.*' -print)" ]

boot_tree=$temporary/boot-tree
mkdir -p "$boot_tree/boot1/isolinux" "$boot_tree/CD1/boot/grub"
printf 'timeout 0\ninclude spkgtk.cfg\n' > "$boot_tree/boot1/isolinux/isolinux.cfg"
printf 'label installspk\nTIMEOUT 300\nmenu timeoutrow 16\n' > "$boot_tree/boot1/isolinux/spkgtk.cfg"
printf 'set timeout=0\nmenuentry install\n' > "$boot_tree/CD1/boot/grub/grub.cfg"
"$repo_root/dns-image/disable-boot-timeouts" "$temporary" "$temporary" 1 "$boot_tree/CD1" amd64
grep -q '^TIMEOUT 0$' "$boot_tree/boot1/isolinux/spkgtk.cfg"
grep -q '^menu timeoutrow 16$' "$boot_tree/boot1/isolinux/spkgtk.cfg"
grep -q '^set timeout=-1$' "$boot_tree/CD1/boot/grub/grub.cfg"
if "$repo_root/dns-image/disable-boot-timeouts" "$temporary" "$temporary" 2 "$boot_tree/CD1" amd64; then
    echo 'image-builder-simulation: unexpected disc accepted' >&2; exit 1
fi
if "$repo_root/dns-image/disable-boot-timeouts" "$temporary" "$temporary" 1 "$temporary/missing" amd64; then
    echo 'image-builder-simulation: missing boot tree accepted' >&2; exit 1
fi

prepare_fixture=$temporary/prepare
mkdir -p "$prepare_fixture/bin"
cp "$repo_root/dns-image/scripts/prepare-installer" "$prepare_fixture/prepare-installer"
cat > "$prepare_fixture/install-gate" <<'EOF'
#!/bin/sh
printf 'gate %s\n' "$*" >> "$DNS_TEST_PREPARE_LOG"
EOF
cat > "$prepare_fixture/confmodule" <<'EOF'
db_set() { printf 'debconf %s\n' "$*" >> "$DNS_TEST_PREPARE_LOG"; }
anna() {
    printf 'components %s\n' "$*" >> "$DNS_TEST_PREPARE_LOG"
    [ "${DNS_TEST_PREPARE_FAILURE:-}" != components ]
}
udpkg() {
    printf 'hardware %s\n' "$*" >> "$DNS_TEST_PREPARE_LOG"
    [ "${DNS_TEST_PREPARE_FAILURE:-}" != hardware ]
}
modprobe() {
    printf 'filesystem %s\n' "$*" >> "$DNS_TEST_PREPARE_LOG"
    [ "${DNS_TEST_PREPARE_FAILURE:-}" != filesystem ]
}
EOF
cat > "$prepare_fixture/bin/anna-install" <<'EOF'
#!/bin/sh
printf 'queue %s\n' "$*" >> "$DNS_TEST_PREPARE_LOG"
EOF
chmod 0755 "$prepare_fixture/bin/anna-install"
PATH="$prepare_fixture/bin:$PATH"
export PATH
export DNS_INSTALLER_DEBCONF_MODULE=$prepare_fixture/confmodule
export DNS_TEST_PREPARE_LOG=$prepare_fixture/log
/bin/sh "$prepare_fixture/prepare-installer"
printf '%s\n' 'debconf debconf/language ko' 'queue simple-cdd-profiles fat-modules' \
    'components cdrom-retriever default' 'filesystem vfat' 'hardware --configure ethdetect' \
    'gate identify' > "$prepare_fixture/expected"
cmp "$prepare_fixture/expected" "$prepare_fixture/log"
for prepare_failure in components filesystem hardware; do
    : > "$prepare_fixture/log"
    if DNS_TEST_PREPARE_FAILURE=$prepare_failure /bin/sh "$prepare_fixture/prepare-installer"; then
        echo 'image-builder-simulation: failed preparation accepted' >&2; exit 1
    fi
    if grep -q '^gate ' "$prepare_fixture/log"; then
        echo 'image-builder-simulation: identity prompt reached after preparation failure' >&2; exit 1
    fi
done

installer_dir=$repo_root/dns-image
simulation_fail() {
    echo "image-builder-simulation: $*" >&2
    exit 1
}

# Installer target-package closure: every package from dns.packages and
# installer-target-packages must be in the offline DVD package list.
closure=$temporary/closure
mkdir -p "$closure"
awk '{ sub(/#.*/, "") } { for (i = 1; i <= NF; i++) print $i "=1.0-1" }' \
    "$installer_dir/simple-cdd/profiles/dns.packages" \
    "$installer_dir/installer-target-packages" | LC_ALL=C sort -u > "$closure/complete.txt"
printf 'unrelated-package=2.0\n' >> "$closure/complete.txt"
"$installer_dir/check-installer-closure" "$closure/complete.txt" > "$closure/pass.log" 2>&1 ||
    simulation_fail "complete offline package list rejected: $(cat "$closure/pass.log")"
"$installer_dir/check-installer-closure" "$closure/complete.txt" \
    "$installer_dir/simple-cdd/profiles/dns.packages" \
    "$installer_dir/installer-target-packages" > "$closure/pass.log" 2>&1 ||
    simulation_fail "explicit closure inputs rejected"
reject_closure() {
    expected=$1
    shift
    if "$installer_dir/check-installer-closure" "$@" > "$closure/reject.log" 2>&1; then
        simulation_fail "installer closure accepted a list that should fail: $expected"
    fi
    grep -q -F -- "$expected" "$closure/reject.log" ||
        simulation_fail "installer closure diagnostic lacks '$expected': $(cat "$closure/reject.log")"
}
grep -v '^zstd=' "$closure/complete.txt" > "$closure/no-zstd.txt"
reject_closure 'missing from the offline DVD: zstd (dns.packages, installer-target-packages)' \
    "$closure/no-zstd.txt"
grep -v '^tasksel=' "$closure/complete.txt" > "$closure/no-tasksel.txt"
reject_closure 'missing from the offline DVD: tasksel (installer-target-packages)' \
    "$closure/no-tasksel.txt"
grep -v '^grub-pc=' "$closure/complete.txt" > "$closure/no-grub-pc.txt"
reject_closure 'missing from the offline DVD: grub-pc' "$closure/no-grub-pc.txt"
grep -v '^podman=' "$closure/complete.txt" > "$closure/no-podman.txt"
reject_closure 'missing from the offline DVD: podman (dns.packages)' "$closure/no-podman.txt"
: > "$closure/empty.txt"
reject_closure 'offline DVD package list is empty' "$closure/empty.txt"
printf 'zstd 1.5\n' > "$closure/malformed.txt"
reject_closure 'malformed offline DVD package list line 1' "$closure/malformed.txt"
reject_closure 'cannot read' "$closure/absent.txt"
printf '# only a comment\n' > "$closure/comment-only.list"
reject_closure 'comment-only.list lists no packages' "$closure/complete.txt" \
    "$installer_dir/simple-cdd/profiles/dns.packages" "$closure/comment-only.list"
printf 'zstd\nBad_Name\n' > "$closure/bad-name.list"
reject_closure 'bad-name.list:2: invalid package name: Bad_Name' "$closure/complete.txt" \
    "$installer_dir/simple-cdd/profiles/dns.packages" "$closure/bad-name.list"
reject_closure 'usage:' "$closure/complete.txt" a b c

# Installer-screen glyphs: synthetic BOGL fonts and initrds only; no real
# font is ever committed or downloaded by this simulation.
glyphs=$temporary/glyphs
mkdir -p "$glyphs/bin"
cat > "$glyphs/make-fixture.py" <<'EOF'
import gzip, struct, sys

def bgf(codepoints, mask=0xFF):
    buckets = [[] for _ in range(mask + 1)]
    for codepoint in sorted(codepoints):
        buckets[codepoint & mask].append(codepoint)
    header = 4 + 8 + 4 + 4 + 8 + 8 + 8
    name = b"fixture\0\0\0\0\0"
    offset_ptr = header + len(name)
    index_ptr = offset_ptr + 4 * (mask + 1)
    offsets, index = [], []
    for bucket in buckets:
        offsets.append(len(index))
        for codepoint in bucket:
            index += [(codepoint & ~mask) | 8, 0]
        index.append(0)
    content_ptr = index_ptr + 4 * len(index)
    return (b"BGF1" + struct.pack("<QiiQQQ", header, 16, mask, offset_ptr, index_ptr, content_ptr)
            + name + struct.pack("<%di" % len(offsets), *offsets)
            + struct.pack("<%di" % len(index), *index) + b"\0" * 16)

def newc(entries):
    out = b""
    for inode, (name, mode, data) in enumerate(entries + [("TRAILER!!!", 0, b"")], 1):
        raw = name.encode() + b"\0"
        fields = [inode, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(raw), 0]
        out += b"070701" + b"".join(b"%08X" % f for f in fields) + raw
        out += b"\0" * (-len(out) % 4) + data
        out += b"\0" * (-len(out) % 4)
    return out

kind, output = sys.argv[1], sys.argv[2]
chars = set()
for path in sys.argv[3:]:
    if path.startswith("drop:"):
        chars.discard(ord(path[5:]))
    else:
        chars |= {ord(c) for c in open(path, encoding="utf-8").read() if ord(c) > 127}
font = bgf(chars | {ord("A")})
if kind == "bad-magic":
    font = b"XXXX" + font[4:]
if kind == "truncated":
    font = font[:200]
members = [(".", 0o040755, b""), ("usr", 0o040755, b""), ("usr/lib", 0o040755, b"")]
if kind != "no-font":
    members.append(("usr/lib/unifont.bgf", 0o100644, font))
archive = newc(members)
if kind == "not-gzip":
    open(output, "wb").write(archive)
else:
    open(output, "wb").write(gzip.compress(newc([("early", 0o100644, b"x")])) + gzip.compress(archive))
EOF
templates=$installer_dir/scripts/guided.templates
make_initrd() {
    python3 -I "$glyphs/make-fixture.py" "$@"
}
make_initrd ok "$glyphs/ok.gz" "$templates"
make_initrd ok "$glyphs/no-yeok.gz" "$templates" "drop:역"
make_initrd bad-magic "$glyphs/bad-magic.gz" "$templates"
make_initrd truncated "$glyphs/truncated.gz" "$templates"
make_initrd no-font "$glyphs/no-font.gz" "$templates"
make_initrd not-gzip "$glyphs/not-gzip.gz" "$templates"
"$installer_dir/check-installer-glyphs" --initrd "$glyphs/ok.gz" > "$glyphs/pass.log" 2>&1 ||
    simulation_fail "guided templates rejected by a font that has every glyph: $(cat "$glyphs/pass.log")"
"$installer_dir/check-installer-glyphs" --initrd "$glyphs/ok.gz" "$templates" > "$glyphs/pass.log" 2>&1 ||
    simulation_fail "explicit guided templates rejected"
cp "$templates" "$glyphs/guided.templates"
printf ' 디스크를 삭제합니다.\n' >> "$glyphs/guided.templates"
sak_line=$(awk 'END { print NR }' "$glyphs/guided.templates")
reject_glyphs() {
    expected=$1
    shift
    if "$installer_dir/check-installer-glyphs" "$@" > "$glyphs/reject.log" 2>&1; then
        simulation_fail "glyph check accepted input that should fail: $expected"
    fi
    grep -q -F -- "$expected" "$glyphs/reject.log" ||
        simulation_fail "glyph diagnostic lacks '$expected': $(cat "$glyphs/reject.log")"
}
reject_glyphs "guided.templates:$sak_line: U+C0AD '삭' is not in the installer font" \
    --initrd "$glyphs/ok.gz" "$glyphs/guided.templates"
yeok_line=$(grep -n '역' "$templates" | awk -F: 'NR == 1 { print $1 }')
reject_glyphs "guided.templates:$yeok_line: U+C5ED '역' is not in the installer font" \
    --initrd "$glyphs/no-yeok.gz"
reject_glyphs 'is not a BGF1 font' --initrd "$glyphs/bad-magic.gz"
reject_glyphs 'font is truncated' --initrd "$glyphs/truncated.gz"
reject_glyphs 'initrd has no usr/lib/unifont.bgf' --initrd "$glyphs/no-font.gz"
reject_glyphs 'initrd is not gzip-compressed' --initrd "$glyphs/not-gzip.gz"
printf '\377\376 invalid\n' > "$glyphs/not-utf8.templates"
reject_glyphs 'not-utf8.templates is not UTF-8' --initrd "$glyphs/ok.gz" "$glyphs/not-utf8.templates"
reject_glyphs 'cannot read' --initrd "$glyphs/absent.gz"
reject_glyphs 'usage:' --font "$glyphs/ok.gz"

# A file-backed xorriso stand-in: an "ISO" is a directory tree next to the
# image file. Only the operations used by refresh-guided-iso and the glyph
# check are emulated; /install.amd/initrd.gz is served from DNS_TEST_INITRD.
cat > "$glyphs/bin/xorriso" <<'EOF'
#!/bin/sh
set -eu
[ "${DNS_TEST_XORRISO_FAIL:-false}" = false ] || exit 5
indev= outdev= maps= extract_from= extract_to=
while [ "$#" -gt 0 ]; do
    case "$1" in
        -indev) indev=$2; shift 2 ;;
        -outdev) outdev=$2; shift 2 ;;
        -map) maps="$maps$2|$3
"; shift 3 ;;
        -extract) extract_from=$2; extract_to=$3; shift 3 ;;
        -osirrox|-boot_image) shift 2 ;;
        replay) shift ;;
        *) shift ;;
    esac
done
if [ -n "$outdev" ]; then
    rm -rf "$outdev.tree"
    cp -R "$indev.tree" "$outdev.tree"
    printf '%s' "$maps" | while IFS='|' read -r source target; do
        [ -n "$source" ] || continue
        mkdir -p "$(dirname "$outdev.tree$target")"
        cp "$source" "$outdev.tree$target"
    done
    : > "$outdev"
    exit 0
fi
[ -n "$extract_from" ]
if [ "$extract_from" = /install.amd/initrd.gz ]; then
    cp "$DNS_TEST_INITRD" "$extract_to"
else
    [ -e "$indev.tree$extract_from" ]
    cp -R "$indev.tree$extract_from" "$extract_to"
fi
EOF
chmod 0755 "$glyphs/bin/xorriso"
iso_glyphs() {
    PATH="$glyphs/bin:$PATH" DNS_TEST_INITRD=$1 "$installer_dir/check-installer-glyphs" --iso "$2"
}
: > "$glyphs/plain.iso"
iso_glyphs "$glyphs/ok.gz" "$glyphs/plain.iso" > "$glyphs/pass.log" 2>&1 ||
    simulation_fail "ISO glyph check rejected a font that has every glyph"
if iso_glyphs "$glyphs/no-yeok.gz" "$glyphs/plain.iso" > "$glyphs/reject.log" 2>&1; then
    simulation_fail "ISO glyph check accepted a font without a template glyph"
fi
if PATH="$glyphs/bin:$PATH" DNS_TEST_XORRISO_FAIL=true DNS_TEST_INITRD="$glyphs/ok.gz" \
    "$installer_dir/check-installer-glyphs" --iso "$glyphs/plain.iso" > "$glyphs/reject.log" 2>&1; then
    simulation_fail "ISO glyph check accepted an ISO without an installer initrd"
fi
grep -q -F 'ISO has no /install.amd/initrd.gz' "$glyphs/reject.log" ||
    simulation_fail "missing initrd diagnostic: $(cat "$glyphs/reject.log")"

# gate-built-iso: a failed check deletes the Simple-CDD ISO and leaves no
# build manifest, SBOM or checksum list that could be paired with it.
gate=$temporary/gate
run_gate() {
    rm -rf "$gate"
    mkdir -p "$gate/images" "$gate/artifacts"
    printf 'iso\n' > "$gate/images/debian.iso"
    for stale in build-manifest.json sbom.spdx.json SHA256SUMS; do
        printf 'stale\n' > "$gate/artifacts/$stale"
    done
    PATH="$glyphs/bin:$PATH" DNS_TEST_INITRD=$1 \
        "$installer_dir/gate-built-iso" "$gate/images/debian.iso" "$2" "$gate/artifacts" \
        > "$gate.log" 2>&1
}
run_gate "$glyphs/ok.gz" "$closure/complete.txt" ||
    simulation_fail "gate rejected a complete build: $(cat "$gate.log")"
[ -f "$gate/images/debian.iso" ] || simulation_fail "gate removed an accepted ISO"
reject_gate() {
    expected=$1
    shift
    if run_gate "$@"; then
        simulation_fail "gate accepted a build that should fail: $expected"
    fi
    grep -q -F -- "$expected" "$gate.log" ||
        simulation_fail "gate diagnostic lacks '$expected': $(cat "$gate.log")"
    [ ! -e "$gate/images/debian.iso" ] || simulation_fail "gate kept a rejected ISO ($expected)"
    for stale in build-manifest.json sbom.spdx.json SHA256SUMS; do
        [ ! -e "$gate/artifacts/$stale" ] ||
            simulation_fail "gate kept $stale beside a rejected ISO ($expected)"
    done
}
reject_gate 'missing from the offline DVD: zstd' "$glyphs/ok.gz" "$closure/no-zstd.txt"
reject_gate "U+C5ED '역' is not in the installer font" "$glyphs/no-yeok.gz" "$closure/complete.txt"
reject_gate 'offline DVD package list is empty' "$glyphs/ok.gz" "$closure/empty.txt"

# build-image must gate before it writes the manifest, and refresh-guided-iso
# must gate before it promotes the candidate.
awk '
    /gate-built-iso/ && !gate { gate = NR }
    /build-manifest\.json/ && /^[[:space:]]*>/ && !manifest { manifest = NR }
    /debian-packages\.txt/ && !packages { packages = NR }
    END { exit !(packages && gate && manifest && packages < gate && gate < manifest) }
' "$installer_dir/build-image" ||
    simulation_fail "build-image does not gate the ISO between the package list and the manifest"

refresh=$temporary/refresh
mkdir -p "$refresh/base.iso.tree/simple-cdd" "$refresh/base.iso.tree/boot/grub" \
    "$refresh/base.iso.tree/isolinux"
: > "$refresh/base.iso"
printf 'guided\n' > "$refresh/base.iso.tree/simple-cdd/install-mode"
printf 'set timeout=-1\n' > "$refresh/base.iso.tree/boot/grub/grub.cfg"
printf 'timeout 0\n' > "$refresh/base.iso.tree/isolinux/isolinux.cfg"
run_refresh() {
    PATH="$glyphs/bin:$PATH" DNS_TEST_INITRD=$1 TMPDIR=$refresh \
        "$installer_dir/refresh-guided-iso" "$refresh/base.iso" "$2" > "$refresh.log" 2>&1
}
run_refresh "$glyphs/ok.gz" "$refresh/out/ok.iso" ||
    simulation_fail "refresh rejected guided files the font can draw: $(cat "$refresh.log")"
[ -e "$refresh/out/ok.iso" ] || simulation_fail "refresh did not promote the candidate"
if run_refresh "$glyphs/no-yeok.gz" "$refresh/out/missing-glyph.iso"; then
    simulation_fail "refresh promoted a candidate whose prompts the font cannot draw"
fi
grep -q -F "U+C5ED '역' is not in the installer font" "$refresh.log" ||
    simulation_fail "refresh glyph diagnostic missing: $(cat "$refresh.log")"
[ ! -e "$refresh/out/missing-glyph.iso" ] ||
    simulation_fail "refresh left a rejected candidate at the output path"

echo "image builder, offline preparation, boot menus, signed Debian installer fetch, installer package closure and installer glyph simulations: passed"
