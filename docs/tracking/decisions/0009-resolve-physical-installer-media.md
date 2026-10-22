# 0009: Resolve Physical Installer Media Before Preparing a DNS Target

- Status: Accepted
- Date: 2026-10-16

## Context

The first physical DNS pilot left its installer USB with the DNS target
partition layout. The install gate compared `/dev/mapper/Ventoy` with whole-disk
names without following the mapper's slave and partition ancestry. Some USB
storage also reports `removable=0`, so the removable bit alone cannot establish
an internal-disk boundary.

## Decision

The install gate resolves `/cdrom` through device-mapper slaves and partition
ancestry to exactly one physical parent. Missing, ambiguous, cyclic, or
unsupported ancestry fails closed. A candidate on a USB-backed sysfs path is
rejected even when its removable bit is false.

Only after role, hardware identity, reinstall authorization, installer-media
exclusion, transport, ambiguity, size, and mount checks pass may the gate clear
the first and last 64 MiB of that exact disk and let Debian Installer create
partitions.

## Alternatives

- Literal mapper-name comparison was rejected because it does not identify the
  physical USB.
- Trusting only the removable bit was rejected because fixed-bit USB devices
  exist.
- A general pre-install wipe command was rejected because disk preparation must
  remain downstream of every target-specific check.
- Treating CP850 fallback text as the root cause was rejected because the
  formatter can continue with its internal conversion table.

## Consequences

An unresolved installer path stops installation. Accepted targets intentionally
lose disk-edge metadata only after destructive authorization. The source fix
does not close the physical incident; rebuilt media must pass BIOS, UEFI,
Ventoy, and disposable HP qualification.
