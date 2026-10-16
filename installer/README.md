# Installer Module

This module resolves the embedded data-only Catalog, verifies public downloads,
assembles the Korean-first multiboot media layout, and enforces destructive
target safety. The root [`device-os`](../device-os) command delegates here.

The embedded Catalog and local profile registry include Proxmox VE, Proxmox
Backup Server, TrueNAS SCALE, Pop!_OS, Debian Live, and a guarded offline
installer for three HP DNS appliances. The World chooses the actual USB subset.

> Source contracts and isolated simulations run in CI. Physical USB behavior,
> firmware, Secure Boot, installation, and post-install boot require separate
> evidence. A passing plan or simulation is not permission to erase a device.

## Read-only workflow

Run from the monorepo root:

```sh
./device-os world validate
./device-os world available
./device-os world plan
./device-os world capacity --capacity 16GB
./device-os world simulate
```

The resolver reads `../catalog/` from the same Git snapshot, validates its JSON
without executing Catalog code, and records both the monorepo commit and Catalog
tree identity in the resolved plan. `simulate` skips image downloads and disk
writes.

World commands resolve selection from `../world/drafts/`. The reference
selection in `collections/device-os.json` remains for contributors and defines
menu groups. Publishing the append-only completed generation is explicitly
unfinished.

## Destructive workflow

On a supported Linux builder, `prepare` downloads and verifies selected public
media. After separately building the DNS runtime artifact, the `burn` command
requires a removable non-root target, a readable serial, sufficient capacity,
and the exact `ERASE <device> <serial>` confirmation.

macOS may burn a previously prepared, exact-size MBR disk image through the
guarded `burn-image-macos` command. This repository does not yet provide the
Linux/QEMU builder for that image; complete USB assembly uses the Linux
`device-os burn` path. The burn commands delegate to the existing internal
writer implementations; the old write command spellings remain compatibility
aliases.

Read [operations](docs/operations.md), [security](docs/security.md), and the
[physical verification gates](docs/verification.md) before any release or disk
write. Ordinary operators should begin with the root
[Getting Started guide](../docs/getting-started.md).

## Module map

| Path | Responsibility |
| --- | --- |
| `device-os` | Module command implementation |
| `usb-media/` | Catalog resolution, capacity, download, menu, and writers |
| `collections/` | Reference selection and shared menu groups |
| `installer/` | Offline DNS appliance image and guarded install gate |
| `management/` | DNS cluster, Tailscale, desired state, backup, and recovery |
| `inventory/` | Public examples; real observations remain ignored |
| `tests/` | Isolated source and rejection simulations |

Adding an OS with an existing `locked-download` contract is a Catalog data
change. The DNS image remains a caller-supplied `runtime-artifact`. A new source
kind or profile adapter changes Installer behavior and must include success and
rejection coverage.

