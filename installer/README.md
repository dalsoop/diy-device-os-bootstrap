# Installer Module

This module resolves the embedded data-only Catalog, verifies public downloads,
assembles the Korean-first multiboot media layout, and enforces destructive
target safety. The root [`device-os`](../device-os) command delegates here.

The default reference composition includes Proxmox VE, Proxmox Backup Server,
TrueNAS SCALE, Pop!_OS, Debian Live, and a guarded offline installer for three
HP DNS appliances.

> Source contracts and isolated simulations run in CI. Physical USB behavior,
> firmware, Secure Boot, installation, and post-install boot require separate
> evidence. A passing plan or simulation is not permission to erase a device.

## Read-only workflow

Run from the monorepo root:

```sh
./device-os available
./device-os plan
./device-os capacity --capacity 16GB
./device-os simulate
```

The resolver reads `../catalog/` from the same Git snapshot, validates its JSON
without executing Catalog code, and records both the monorepo commit and Catalog
tree identity in the resolved plan. `simulate` skips image downloads and disk
writes.

The current commands still use the reference selection in
`collections/device-os.json`. Resolving selection from `world/drafts/` and
publishing the append-only completed generation are explicitly unfinished.

## Destructive workflow

On a supported Linux builder, `prepare` downloads and verifies selected public
media. After separately building the DNS runtime artifact, `write` requires a
removable non-root target, a readable serial, sufficient capacity, and the exact
`ERASE <device> <serial>` confirmation.

macOS may write a previously prepared, exact-size MBR disk image through the
guarded `write-image-macos` path. Building that full image remains a Linux task.

Read [operations](docs/operations.md), [security](docs/security.md), and the
[physical verification gates](docs/verification.md) before any release or disk
write.

## Module map

| Path | Responsibility |
| --- | --- |
| `device-os` | Module command implementation |
| `usb-media/` | Catalog resolution, capacity, download, menu, and writers |
| `collections/` | Temporary reference media selection |
| `installer/` | Offline DNS appliance image and guarded install gate |
| `management/` | DNS cluster, Tailscale, desired state, backup, and recovery |
| `inventory/` | Public examples; real observations remain ignored |
| `tests/` | Isolated source and rejection simulations |

Adding an OS with an existing `locked-download` contract is a Catalog data
change. A new source kind or profile adapter changes Installer behavior and must
include success and rejection coverage.

