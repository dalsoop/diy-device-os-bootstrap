# DIY Device OS USB

This module combines public Catalog entries with Installer-local entries into a
verified Korean-first Ventoy USB.

## Human workflow

```sh
./device-os world validate
./device-os world available
./device-os world capacity --capacity 16GB
./device-os world simulate
./device-os targets
./device-os world prepare
./device-os world build-image --output /absolute/path/device-os.raw --size EXACT_BYTES
sudo ./device-os world burn --device /dev/sdX ...
```

`available`, `plan`, `capacity`, and `simulate` do not write a block device.
`prepare` downloads into an ignored cache and verifies SHA-256. Only `burn`
partitions and overwrites the confirmed removable target. The command delegates
to the internal writer after all safety checks pass.

On macOS, `build-image` starts a privileged Debian 13 Podman or Docker
container, assembles Ventoy through a loop device inside that VM, and returns an
exact-size MBR raw image. The container receives only the checkout bind and
cannot open a macOS block device. Inspect the live target immediately before
building and writing:

```sh
./device-os targets
./device-os world build-image \
  --output "$PWD/engine/installer/artifacts/device-os.raw" \
  --size EXACT_BYTES
sudo ./device-os world burn-image-macos \
  --image "$PWD/engine/installer/artifacts/device-os.raw" \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME USB_SERIAL EXACT_BYTES'
```

The macOS writer accepts only a physical, writable, removable whole disk whose
size exactly matches an MBR image. It invalidates the old partition map, writes
and verifies the image body while automatic mounting is impossible, commits and
verifies the first MiB last, then unmounts and ejects. GPT images are rejected.
Image assembly and physical writing remain separate operations: building an
image never authorizes erasure.

`capacity` sums selected image sizes, the enrollment reserve, and configured
overhead. Cached files and runtime artifacts with matching manifests provide
verified exact sizes. Missing public files use a header/one-byte HTTPS estimate
unless `--offline` is set. An unknown or unverified artifact produces a
pending result rather than a false fit claim, unless verified files plus the
fixed reserve and overhead already prove the target is too small.

## Input layers

| Input | Ownership |
| --- | --- |
| `burn-history/home.yaml` (registered in `burn-history/.paths.yaml`) | User-selected entry IDs, language, and safety policy |
| `composition.json` | Catalog location, USB properties, local entries, bundles |
| `../collections/device-os.json` | Menu groups and contributor reference selection |
| `local-entries/*.json` | Installer-owned profiles such as the DNS installer |
| `engine/catalog/data/` | Public bootloader and OS metadata |

The resolver reads `engine/catalog/data/` from the same clean Git snapshot but does
not execute its scripts. It validates paths and contracts again, records the
monorepo commit and Catalog tree, then writes the shared resolved plan to
`engine/installer/work/device-os/catalog.json`.

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
- The current `dns-install` media does not select Proxmox, TrueNAS, or desktop images.
- Only the DNS local profile uses guarded unattended installation.
- The writer requires a removable non-root device, readable serial, sufficient
  capacity, and exact `ERASE <device> <serial>` confirmation.
- The macOS writer additionally binds confirmation to media name and exact byte
  size: `ERASE <device> <media-name> <serial> <bytes>`.
- Repository-file and repository-tree bundles reject every symlink before
  staging so a checkout path cannot escape into host files.
- Generated media and caches remain outside Git.
- Removing the DNS profile requires setting `enrollment_reserve_mib` to zero.

## Resulting layout

```text
DEVICE-OS/                     exFAT label used by Ventoy's bundled formatter
├── images/
├── tools/dns-appliance-status-monitor/
├── manifests/
│   ├── media-catalog.json
│   ├── MEDIA-CATALOG.SHA256
│   ├── LICENSES.SHA256
│   ├── dns-build-manifest.json
│   └── SHA256SUMS
├── licenses/
│   ├── DIY-DEVICE-OS-BOOTSTRAP-GPL-3.0.txt
│   ├── LICENSE_HISTORY.md
│   ├── THIRD_PARTY_NOTICES.md
│   ├── Tailscale-BSD-3-Clause.txt
│   └── SOURCE.md
├── ventoy/ventoy.json
├── README_KO.txt
└── README_EN.txt

DNS-ENROLL/                 FAT32, present only with the DNS profile
├── installer.json
├── records/
└── reinstall/
```

After writing, verify the resolved Catalog digest, every image checksum, and
`manifests/LICENSES.SHA256` from the USB itself. Physical boot, installation,
and exact-artifact redistribution review remain separate verification gates.

