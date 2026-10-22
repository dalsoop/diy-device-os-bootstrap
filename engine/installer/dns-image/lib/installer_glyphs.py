# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
"""Check that the debian-installer screen font can draw installer text.

Usage: python3 -I installer_glyphs.py --initrd INITRD.gz -- TEXT...

The font is /usr/lib/unifont.bgf inside the gzip-compressed newc cpio initrd
of the installer (install.amd/initrd.gz). It is a BOGL BGF1 font; a character
it lacks cannot be drawn on the installer screen. Every non-ASCII character of
each TEXT file must be in the font. Invoked by check-installer-glyphs;
standard library only.
"""

import gzip
import struct
import sys
import zlib

PROG = "check-installer-glyphs"
FONT_PATH = "usr/lib/unifont.bgf"


class CheckError(Exception):
    pass


def read_file(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except OSError as error:
        raise CheckError("cannot read %s: %s" % (path, error.strerror))


def decompress(path):
    raw = read_file(path)
    try:
        return gzip.decompress(raw)
    except (OSError, EOFError, zlib.error):
        raise CheckError("initrd is not gzip-compressed: %s" % path)


def find_member(archive, wanted):
    """Return the regular file WANTED from concatenated newc cpio archives."""
    position = 0
    length = len(archive)
    while position < length:
        if archive[position] == 0:
            position += 1
            continue
        if position + 110 > length:
            raise CheckError("initrd cpio archive is truncated")
        if archive[position:position + 6] not in (b"070701", b"070702"):
            raise CheckError("initrd is not a newc cpio archive at byte %d" % position)
        try:
            fields = [int(archive[position + 6 + 8 * i:position + 14 + 8 * i], 16)
                      for i in range(13)]
        except ValueError:
            raise CheckError("initrd cpio header is malformed at byte %d" % position)
        mode, file_size, name_size = fields[1], fields[6], fields[11]
        name_start = position + 110
        name_end = name_start + name_size
        if name_size < 1 or name_end > length:
            raise CheckError("initrd cpio archive is truncated")
        name = archive[name_start:name_end - 1].decode("utf-8", "replace")
        data_start = name_end + (-name_end % 4)
        data_end = data_start + file_size
        if data_end > length:
            raise CheckError("initrd cpio archive is truncated")
        position = data_end + (-data_end % 4)
        normalized = name[2:] if name.startswith("./") else name.lstrip("/")
        if normalized == wanted and (mode & 0o170000) == 0o100000:
            return archive[data_start:data_end]
    raise CheckError("initrd has no %s" % wanted)


def font_glyphs(font):
    """Return the code points of a BGF1 font, as BOGL bogl_font_glyph sees them.

    Header: magic, u64 name, i32 height, i32 index_mask, u64 offset, u64
    index, u64 content (pointers are file offsets). offset[] holds
    index_mask + 1 starting positions in the i32 index[] array; each bucket
    is a list of (value, content offset) pairs ended by 0, and a glyph for
    code point wc lives in bucket wc & mask with (value & ~mask) == (wc & ~mask).
    """
    if len(font) < 44 or font[:4] != b"BGF1":
        raise CheckError("%s is not a BGF1 font" % FONT_PATH)
    _, height, mask, offset_ptr, index_ptr, _ = struct.unpack_from("<QiiQQQ", font, 4)
    if height <= 0 or mask < 0 or mask > 0xFFFF or mask & (mask + 1):
        raise CheckError("%s has an invalid header" % FONT_PATH)
    if offset_ptr + 4 * (mask + 1) > len(font) or index_ptr > len(font):
        raise CheckError("font is truncated")
    offsets = struct.unpack_from("<%di" % (mask + 1), font, offset_ptr)
    index_count = (len(font) - index_ptr) // 4
    glyphs = set()
    for bucket, cursor in enumerate(offsets):
        while True:
            if cursor < 0 or cursor >= index_count:
                raise CheckError("font is truncated")
            (value,) = struct.unpack_from("<i", font, index_ptr + 4 * cursor)
            if value == 0:
                break
            if cursor + 1 >= index_count:
                raise CheckError("font is truncated")
            glyphs.add((value & ~mask) | bucket)
            cursor += 2
    return glyphs


def main(argv):
    if len(argv) < 4 or argv[0] != "--initrd" or argv[2] != "--":
        raise CheckError("usage: installer_glyphs.py --initrd INITRD.gz -- TEXT...")
    initrd, texts = argv[1], argv[3:]
    glyphs = font_glyphs(find_member(decompress(initrd), FONT_PATH))
    missing = []
    checked = 0
    for path in texts:
        raw = read_file(path)
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as error:
            raise CheckError("%s is not UTF-8 (byte %d)" % (path, error.start))
        for number, line in enumerate(text.split("\n"), 1):
            for char in line:
                if ord(char) < 128:
                    continue
                checked += 1
                if ord(char) not in glyphs:
                    missing.append((path, number, ord(char), char))
    for path, number, codepoint, char in missing:
        print("%s: %s:%d: U+%04X '%s' is not in the installer font"
              % (PROG, path, number, codepoint, char), file=sys.stderr)
    if missing:
        print("%s: %d non-ASCII characters cannot be drawn by the installer font"
              % (PROG, len(missing)), file=sys.stderr)
        return 1
    print("installer glyphs: %d non-ASCII characters in %d file(s); font has %d glyphs; none missing"
          % (checked, len(texts), len(glyphs)))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except CheckError as error:
        print("%s: %s" % (PROG, error), file=sys.stderr)
        sys.exit(1)
