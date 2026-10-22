# DIY Device OS Bootstrap

[![CI](https://github.com/dalsoop/diy-device-os-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/dalsoop/diy-device-os-bootstrap/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

This user-owned device bootstrap holds the complete source for a homelab World:
device intent, public operating-system metadata, guarded installation-media
tooling, and the append-only record of verified physical USB generations. The
example `gujo-home` World describes a three-node home DNS cluster as its first
deployment. Fork this repository and make `burn-history/` your own World.

The repository and product are **DIY Device OS Bootstrap**. The operator
command is `device-os`, and the generated removable-media product is
**DIY Device OS USB**.

The default `dns-install` media contains only the guarded DNS appliance image.
The separate `inventory-capture` media contains only Debian Live for collecting
hardware identity before any unattended installation is enabled. Proxmox,
TrueNAS, and desktop images remain available as Catalog metadata for upstream
compatibility, but the current media selections do not download or stage them.

> Current assurance: contracts and isolated simulations run in CI. A successful
> CI run does not prove a physical USB, firmware boot, internal-disk install, or
> network cutover. Each remains a separate verification gate.

## Distribution policy

This public repository currently supports personal self-build and source-only
releases. Personal use permits the operator to prepare, build, and write media
for the operator's own devices; it is not approval to redistribute any ISO,
RAW, IMG, complete USB content, or installed-system image. A matching checksum,
successful build, SBOM, CI run, USB readback, or installation does not change
that boundary.

The release workflow uploads only non-executable verification evidence such as
checksums, manifests, package closure, component status, and the SBOM. It does
not publish a GitHub Release or upload generated media. Public prebuilt
distribution remains disabled. Enabling it in the future requires all of the
following, with no automatic promotion from an earlier evidence state:

1. Exact-artifact review of every selected bootloader and OS image, bound to its
   version, URL, and SHA-256, with license, notice, corresponding-source, and
   trademark evidence and fulfilled obligations.
2. For the composite DNS ISO, redistribution review of every build component
   and a separate final review bound to the ISO, component registry, build
   manifest, SBOM, and staged obligation files. Neither review replaces the
   other.
3. A successful `./device-os license check --mode prebuilt-release ...` after a
   separately reviewed policy change enables generated-artifact distribution.
4. Approval through the protected GitHub Environment
   `prebuilt-distribution`, configured with a human-only required reviewer.

The repository does not currently publish prebuilt media, and the protected
Environment configuration has not been verified.

## Start here

```sh
git clone https://github.com/dalsoop/diy-device-os-bootstrap.git
cd diy-device-os-bootstrap
./device-os world validate
./device-os world plan
./device-os world capacity --capacity 16GB
./device-os world simulate
```

The user only needs [`burn-history/`](burn-history/README.md). You edit
`home.yaml`, `dns-records.zone`, and the per-role `os-installs/<role>/os.conf`;
`keys/` and each `os-installs/<role>/hardware.conf` hold private files never
committed; `logs/` records what happened and is never edited. Everything in
`engine/` is machinery that reads `burn-history/`; you do not need to open it.

The home definition is
[`burn-history/home.yaml`](burn-history/home.yaml).
It defines `dns01`, `dns02`, and `dns03` at `10.0.5.1` through `10.0.5.3`, with
the router at `10.0.0.1`. Hardware captures (`burn-history/os-installs/<role>/hardware.conf`) and keys
(`burn-history/keys/`) stay ignored; generated media, credentials, and recovery material stay
outside Git in the documented ignored locations or the principal secret store.

## Build and burn flow

1. Boot `inventory-capture` and collect each HP machine's exact hardware data.
2. Review the private captures in `burn-history/os-installs/<role>/hardware.conf` and enable one machine at a time.
3. On an amd64 Debian 13 builder, build the offline Korean DNS installer ISO.
4. Check capacity with the exact ISO and its build manifest.
5. On Linux, burn directly, or on macOS build an exact-size raw image in the
   bundled Debian 13 container and write it with verified readback.
6. Verify the USB, boot one machine, and complete all physical gates before
   enabling the next machine.

The destructive command is intentionally explicit:

```sh
sudo ./device-os world burn \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

Resolve the current device path and serial immediately before every burn. The
writer rejects a non-removable device, the root disk, a missing serial,
insufficient capacity, an unverified artifact, or an inexact confirmation.

On macOS, inspect the live target first, then build an image whose size exactly
matches it. `build-image` runs the Linux-only Ventoy assembler inside a
privileged Podman or Docker container; the container cannot see macOS block
devices. The later write remains a separate target-specific action:

```sh
./device-os targets
DEVICE_OS_MEDIA=inventory-capture ./device-os world prepare
DEVICE_OS_MEDIA=inventory-capture ./device-os world build-image \
  --output "$PWD/engine/installer/artifacts/inventory-capture.raw" \
  --size EXACT_TARGET_BYTES
sudo DEVICE_OS_MEDIA=inventory-capture ./device-os world burn-image-macos \
  --image "$PWD/engine/installer/artifacts/inventory-capture.raw" \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME USB_SERIAL EXACT_TARGET_BYTES'
```

The offline DNS installer ISO still requires three real HP inventory captures,
exactly one erase-enabled role, public operator key material, and an amd64
Debian 13 build. `./device-os world readiness` reports every missing input
without printing hardware identities or credentials.

## Repository map

```text
diy-device-os-bootstrap/
├── device-os              operator command
├── burn-history/          the user's folder
│   ├── home.yaml          home intent: networks, computers, services, media, policies
│   ├── dns-records.zone   the DNS zone
│   ├── os-installs/       per-role folders: os.conf guided profile, hardware.conf real capture (ignored)
│   ├── keys/              operator public keys, never committed
│   └── logs/              what happened, never edited: USB generations, failed writes, verification reports
├── engine/                machinery
│   ├── installer/         builders, media assembly, management, and destructive gates
│   ├── catalog/           data-only public OS and bootloader metadata
│   ├── agent/             constrained management-host MCP access plane
│   └── world/             World resolver and USB recorder
└── docs/                  architecture, workflow, and decisions
```

- `burn-history/` owns operator intent and history, not erasure authority.
- `engine/world/` resolves that intent and publishes records after verified writes.
- `engine/catalog/` owns public metadata and executes nothing.
- `engine/installer/` validates all inputs and live targets before writing.
- `engine/agent/` exposes planning and reviewed DNS operations, never USB burn or
  OS installation.

Each verified physical USB creation publishes an immutable World generation
under `burn-history/logs/usb/` named `{YYYYMMDDHHmmss}-{world-slug}`. The
timestamp is the USB creation event in `Asia/Seoul`, not draft or commit time.
Failed or cancelled physical attempts are recorded separately under
`burn-history/logs/usb/failed/`; simulations do not create physical
evidence.

## Documentation

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Business rules](docs/business-rules.md)
- [Security](docs/security.md)
- [Engineering standards](docs/standards.md)
- [Engineering notes](docs/engineering-notes.md)
- [Operations](docs/operations.md)
- [External contracts](docs/contracts.md)
- [Implementation status](docs/tracking/status.md)
- [Open findings](docs/tracking/findings.md)
- [Decision history](docs/tracking/decisions/index.md)
- [DNS install usability audit](engine/installer/docs/dns-install-usability-audit.md)
- [Physical verification gates](engine/installer/docs/verification.md)
- [Agent Gateway](engine/agent/README.md)

## Forks

A fork keeps one World in `burn-history/` and extends it with new devices and
media instead of creating a repository per device role. Review changes from
this repository to Catalog data, installation gates, media writers, and safety
policy before merging them into a fork; never weaken target checks.

## License

Except where a file-specific or upstream notice states otherwise, original
content is licensed under GPL-3.0-only. Third-party operating systems,
bootloaders, packages, and container images retain their upstream terms. See
[LICENSE_HISTORY.md](docs/licenses/LICENSE_HISTORY.md) and
[THIRD_PARTY_NOTICES.md](docs/licenses/THIRD_PARTY_NOTICES.md).
