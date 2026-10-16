# DIY Device OS Bootstrap

[![CI](https://github.com/dalsoop/diy-device-os-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/dalsoop/diy-device-os-bootstrap/actions/workflows/ci.yml)

This user-owned device bootstrap holds the complete source for a homelab World:
operator intent, public operating-system metadata, guarded installation-media
tooling, and the append-only record of verified physical USB generations.

The repository and product are **DIY Device OS Bootstrap**. The operator
command remains `device-os`; its destructive USB surface is the **Device OS
Burner** exposed through `burn`, and the generated removable-media product is
**DIY Device OS USB**.

This monorepo replaces the former World Playbook, OS Installer, and OS Catalog
repository split. The boundaries still exist as modules, but users clone or
fork only this repository and agents can change a contract and all of its
consumers in one pull request.

> Current assurance: source contracts and isolated simulations run in CI.
> Physical USB behavior, firmware compatibility, destructive installation, and
> post-install boot remain separate qualification gates. A passing CI run is
> not permission to erase a device.

## Start here

Clone one repository:

```sh
git clone https://github.com/dalsoop/diy-device-os-bootstrap.git
cd diy-device-os-bootstrap
```

Follow the [Getting Started guide](docs/getting-started.md) for the implemented
fork, selection, capacity, DNS build, Linux USB burn, verification, and
enrollment workflow.

The example [`world/drafts/gujo-home/world.yaml`](world/drafts/gujo-home/world.yaml)
describes intended devices, networks, services, media, and fail-closed policy.
`device-os world ...` validates that draft and uses its media entries as the
USB selection. Local hardware observations belong in ignored directories, and
passwords, tokens, private keys, generated images, and raw hardware identifiers
never belong in Git.

Use the root command for read-only media operations:

```sh
./device-os world validate
./device-os world available
./device-os world plan
./device-os world capacity --capacity 16GB
./device-os world simulate
```

`simulate` does not download images or write a disk. A capacity check may make
small HTTPS size probes unless `--offline` is supplied. Destructive USB commands
retain live target checks and require an exact device-specific confirmation.
On a supported Linux builder, the preferred destructive surface is:

```sh
sudo ./device-os world burn \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

Resolve the current removable target and serial immediately before every burn;
never reuse this placeholder or a previous confirmation.

## One World, accumulating USB generations

One World covers the connected environment: router, switch, computers,
networks, logical nodes, services, and selected media. DNS, Proxmox, TrueNAS,
and workstations are members of the World rather than separate Worlds.

The intended contract publishes each successfully verified physical USB as a
distinct immutable directory:

```text
world/worlds/{YYYYMMDDHHmmss}-{world-slug}/
```

The timestamp is captured in `Asia/Seoul` when the resolved World is sealed
immediately before a target-specific write. The automatic publication
transaction is not implemented yet. A future generation may be published only
after the physical write and required readback verification succeed. Rewriting
the same intent to another USB creates another generation; completed
generations are never edited or replaced.

## Repository map

```text
diy-device-os-bootstrap/
├── device-os              root operator command
├── world/                 user intent and immutable USB generations
│   ├── drafts/            mutable desired state
│   ├── local/             ignored machine-local observations
│   └── worlds/            append-only completed generations
├── catalog/               data-only public OS and bootloader metadata
├── installer/             resolution, verification, builders, and safety gates
├── docs/                  monorepo architecture and decisions
└── .github/workflows/     one CI and release surface
```

The module boundaries are security boundaries, not repository boundaries:

- `world/` owns user choices and policy but never authorizes erasure by itself.
- `catalog/` owns public metadata and never downloads, executes, or writes it.
- `installer/` owns execution and independently validates Catalog and live
  targets before any destructive operation.

The embedded Catalog is locked by the monorepo commit and Catalog tree identity
recorded in each resolved plan and completed World generation. Generated media,
caches, credentials, and recovery material remain outside Git.

## Current World media

The example World selects TrueNAS SCALE and a guarded offline installer for the
three HP DNS appliances. The embedded Catalog also offers Proxmox VE, Proxmox
Backup Server, Pop!_OS, and Debian Live; add or remove their stable IDs in the
World's `spec.media[].entries`. General operating-system installers remain
interactive. Only the DNS profile has guarded unattended behavior.

## Documentation

- [Getting started](docs/getting-started.md)
- [Monorepo architecture](docs/architecture.md)
- [Security boundaries](docs/security.md)
- [Migration decision](docs/tracking/decisions/0001-consolidate-into-one-monorepo.md)
- [World selection decision](docs/tracking/decisions/0002-world-drives-operator-media-selection.md)
- [Product naming decision](docs/tracking/decisions/0003-adopt-diy-device-os-bootstrap-name.md)
- [World contract](world/docs/contracts.md)
- [Installer operations](installer/docs/operations.md)
- [Physical verification gates](installer/docs/verification.md)
- [Catalog contracts](catalog/docs/contracts.md)
