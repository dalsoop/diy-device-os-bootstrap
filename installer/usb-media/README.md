# Gujo Homelab OS USB

This module combines public Catalog entries with fork-local entries into a
verified Korean-first Ventoy USB.

## Human workflow

```sh
./device-os available
./device-os include pop-os
./device-os exclude pop-os
./device-os capacity --capacity 16GB
./device-os simulate
./device-os prepare
sudo ./device-os write --device /dev/sdX ...
```

`available`, `plan`, `capacity`, and `simulate` do not write a block device.
`prepare` downloads into an ignored cache and verifies SHA-256. Only `write`
partitions and overwrites the confirmed removable target.

On macOS, a prepared full-disk image can be written and read back with:

```sh
sudo ./device-os write-image-macos \
  --image /absolute/path/device-os.raw \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME EXACT_BYTES'
```

The macOS writer accepts only a physical, writable, removable whole disk whose
size exactly matches an MBR image. It invalidates the old partition map, writes
and verifies the image body while automatic mounting is impossible, commits and
verifies the first MiB last, then unmounts and ejects. GPT images are rejected.
Creating the full-disk image remains a separate build step; the current macOS
backend uses the pinned Linux Ventoy installer in an isolated QEMU guest because
Ventoy does not provide a native macOS installer.

`capacity` sums selected image sizes, the enrollment reserve, and configured
overhead. Cached files and runtime artifacts with matching manifests provide
verified exact sizes. Missing public files use a header/one-byte HTTPS estimate
unless `--offline` is set. An unknown or unverified artifact produces a
pending result rather than a false fit claim, unless verified files plus the
fixed reserve and overhead already prove the target is too small.

## Input layers

| Input | Ownership |
| --- | --- |
| `composition.json` | Catalog URL and commit, USB properties, local entries, bundles |
| `../collections/device-os.json` | Selected public IDs and menu groups |
| `local-entries/*.json` | Fork-local profiles such as the DNS installer |
| External Catalog | Public bootloader and OS metadata |

The resolver fetches one exact Catalog commit but does not execute its scripts.
It validates paths and contracts again, then writes the shared resolved plan to
`work/device-os/catalog.json`.

## Supported strategies

| Kind | Fetch | Verification | Staging |
| --- | --- | --- | --- |
| `locked-download` | HTTPS URL | Catalog SHA-256 | Verified cache file |
| `runtime-artifact` | Caller-supplied file | Build-manifest digest | Verified artifact |
| `repository-file` | None | Installer path contract | Single support file |
| `repository-tree` | None | Installer path contract | Support directory |

A new public image using `locked-download` needs Catalog data and collection
selection only. A new strategy or profile adapter requires implementation and
tests in the Installer.

## Safety boundary

- The menu has no automatic selection timer.
- Proxmox VE, Proxmox Backup Server, TrueNAS, and Pop!_OS remain interactive.
- Only the DNS local profile uses guarded unattended installation.
- The writer requires a removable non-root device, readable serial, sufficient
  capacity, and exact `ERASE <device> <serial>` confirmation.
- Generated media and caches remain outside Git.
- Removing the DNS profile requires setting `enrollment_reserve_mib` to zero.

## Resulting layout

```text
DEVICE-INST/                   11-character exFAT label used by Ventoy's bundled formatter
├── images/
├── guides/POP_OS_KO.md
├── tools/dns-appliance-status-monitor/
├── manifests/
│   ├── media-catalog.json
│   ├── MEDIA-CATALOG.SHA256
│   ├── dns-build-manifest.json
│   └── SHA256SUMS
├── ventoy/ventoy.json
├── README_KO.txt
└── README_EN.txt

DNS-ENROLL/                 present only with the DNS profile
├── installer.json
├── records/
└── reinstall/
```

After writing, verify the resolved Catalog digest and every image checksum from
the USB itself. Physical boot and installation remain separate verification
gates.

