# Installer Module

This module resolves the embedded data-only Catalog, verifies public downloads,
assembles the Korean-first multiboot media layout, and enforces destructive
target safety. The root [`device-os`](../../device-os) command delegates to
[`device-os`](device-os) here.

The embedded Catalog and local profile registry include Proxmox VE, Proxmox
Backup Server, TrueNAS SCALE, Pop!_OS, Debian Live, and a guarded offline
installer for three HP DNS appliances. The World chooses the actual USB subset.

> Source contracts and isolated simulations run in CI. Physical USB behavior,
> firmware, Secure Boot, installation, and post-install boot require separate
> evidence. A passing plan or simulation is not permission to erase a device.

## Read-only workflow

Run from the repository root:

```sh
./device-os world validate
./device-os world available
./device-os world plan
./device-os world capacity --capacity 16GB
./device-os world simulate
```

The resolver reads `engine/catalog/data/` from the same Git snapshot, validates its JSON
without executing Catalog code, and records both the monorepo commit and Catalog
tree identity in the resolved plan. `simulate` skips image downloads and disk
writes.

World commands resolve selection from the draft registered in
`burn-history/.paths.yaml` (`burn-history/home.yaml`). The reference
selection in `collections/device-os.json` remains for contributors and defines
menu groups. World burn commands delegate through the event recorder so a
successful readback atomically publishes an append-only completed generation.

## Destructive workflow

On a supported Linux builder, `prepare` downloads and verifies selected public
media. After separately building the DNS runtime artifact, the `burn` command
requires a removable non-root target, a readable serial, sufficient capacity,
and the exact `ERASE <device> <serial>` confirmation.

macOS builds an exact-size MBR disk image through the guarded Debian 13
Podman/Docker loop-device builder, then burns it through the separately guarded
`world burn-image-macos` command. `device-os targets` prints the current
device/name/serial/size confirmation tuple. The burn commands delegate to the
internal writer implementations. The command exposes only the documented
`burn` spellings; there are no write-command aliases.

Read [operations](../../docs/operations.md), [security](../../docs/security.md), and the
[physical verification gates](docs/verification.md) before any release or disk
write. Ordinary operators should begin with the root
[Getting Started guide](../../docs/getting-started.md).

## Module map

| Path | Responsibility |
| --- | --- |
| `device-os` | Module command implementation |
| `usb-media/` | Catalog resolution, capacity, download, menu, and writers |
| `collections/` | Reference selection and shared menu groups |
| `dns-image/` | Offline DNS appliance image and guarded install gate |
| `management/` | DNS cluster, Tailscale, desired-state apply, backup, and recovery |
| `build/` | Immutable external input locks and distribution contracts |
| `schemas/` | Installation, enrollment, and distribution record shapes |
| `tests/` | Isolated source and rejection simulations |
| `docs/` | Installer procedures and physical verification gates |

The per-role guided profiles (`burn-history/os-installs/<role>/os.conf`) and the
DNS zone (`burn-history/dns-records.zone`) the Installer consumes are tracked; real
hardware captures (`burn-history/os-installs/<role>/hardware.conf`) and operator
public keys (`burn-history/keys/`) are ignored. Format examples live in
[`docs/examples/`](docs/examples/).

Adding an OS with an existing `locked-download` contract is a Catalog data
change. The DNS image remains a caller-supplied `runtime-artifact`. A new source
kind or profile adapter changes Installer behavior and must include success and
rejection coverage.

