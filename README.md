# Gujo Homelab OS Playbook

[![CI](https://github.com/dalsoop/gujo-homelab-os-playbook/actions/workflows/ci.yml/badge.svg)](https://github.com/dalsoop/gujo-homelab-os-playbook/actions/workflows/ci.yml)

This user-owned playbook holds the complete source for a homelab World: operator intent,
public operating-system metadata, guarded installation-media tooling, and the
append-only record of verified physical USB generations.

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
git clone https://github.com/dalsoop/gujo-homelab-os-playbook.git
cd gujo-homelab-os-playbook
```

Edit [`world/drafts/gujo-home/world.yaml`](world/drafts/gujo-home/world.yaml) to
describe the intended devices, network, services, and selected media. Local
hardware observations belong under the ignored `world/local/` directory;
passwords, tokens, private keys, generated images, and raw hardware identifiers
never belong in Git.

Use the root command for read-only media operations:

```sh
./device-os available
./device-os plan
./device-os capacity --capacity 16GB
./device-os simulate
```

`simulate` does not download images or write a disk. Destructive USB commands
retain live target checks and require an exact device-specific confirmation.

## One World, accumulating USB generations

One World covers the connected environment: router, switch, computers,
networks, logical nodes, services, and selected media. DNS, Proxmox, TrueNAS,
and workstations are members of the World rather than separate Worlds.

Each successful physical USB creation publishes a distinct immutable directory:

```text
world/worlds/{YYYYMMDDHHmmss}-{world-slug}/
```

The timestamp is captured in `Asia/Seoul` when the resolved World is sealed
immediately before a target-specific write. A generation is published only
after the physical write and required readback verification succeed. Rewriting
the same intent to another USB creates another generation; completed
generations are never edited or replaced.

## Repository map

```text
gujo-homelab-os-playbook/
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

## Current default media

The current reference composition includes Proxmox VE, Proxmox Backup Server,
TrueNAS SCALE, Pop!_OS, Debian Live, and a guarded offline installer for the
three HP DNS appliances. General operating-system installers remain interactive.
Only the DNS profile has guarded unattended behavior.

## Documentation

- [Monorepo architecture](docs/architecture.md)
- [Security boundaries](docs/security.md)
- [Migration decision](docs/tracking/decisions/0001-consolidate-into-one-monorepo.md)
- [World contract](world/docs/contracts.md)
- [Installer operations](installer/docs/operations.md)
- [Physical verification gates](installer/docs/verification.md)
- [Catalog contracts](catalog/docs/contracts.md)
One repository for homelab World intent, OS catalog metadata, and guarded installation media tooling.
