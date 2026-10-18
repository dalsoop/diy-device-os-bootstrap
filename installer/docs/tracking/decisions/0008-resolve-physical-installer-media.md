# 0008: Resolve Physical Installer Media Before Preparing a DNS Target

- Status: Accepted
- Date: 2026-10-16

## Context

The first physical DNS pilot left the removed SanDisk installer USB with the
DNS target partition layout and an invalid EFI filesystem. The install gate saw
`/cdrom` as `/dev/mapper/Ventoy` but compared that literal mapper path with
whole-disk names. Its test fixture did not model Ventoy's device-mapper slave,
so the physical USB parent was never excluded by that check.

Some USB storage also reports `removable=0`; removability alone is therefore
not a sufficient internal-disk boundary. Existing disk signatures can
independently trigger Debian Installer EFI-formatting failures.

## Decision

The DNS install gate resolves `/cdrom` through device-mapper slaves and
partition ancestry to one physical parent disk. Missing, ambiguous, cyclic, or
unsupported ancestry fails closed. A candidate whose physical sysfs path is
USB-backed is rejected even when it reports `removable=0`.

After one role and one internal disk pass hardware identity, reinstall
authorization, installer-media exclusion, transport, ambiguity, size, and
activity checks, the gate clears the first and last 64 MiB of that exact disk
and refreshes its partition table. Activity checks resolve mounted filesystems
and active swap through partitions, `/dev/mapper`, `/dev/disk` aliases, and
multi-slave ancestry. They also reject a target or target partition with a
sysfs holder, even when that holder is not mounted. Debian Installer then owns
partition creation.
The preseed uses the documented
`partman-partitioning/confirm_write_new_label` key.

## Rejected alternatives

- Comparing `/dev/mapper/Ventoy` directly with whole-disk names was rejected
  because it does not identify the physical USB.
- Trusting only the removable bit was rejected because fixed-bit USB devices
  exist.
- Exposing a general disk-wipe utility was rejected because preparation must
  remain downstream of every target-specific gate.
- Treating CP850 fallback text as the formatting failure was rejected because
  `mkfs.fat` can continue with its internal conversion table.

## Consequences

An unresolvable installer path stops unattended installation. Accepted targets
lose disk-edge metadata before partitioning, which is intentional and covered
by the existing destructive authorization. The damaged pilot USB must be
rebuilt, and source tests do not replace a fresh BIOS, UEFI, Ventoy, and
physical-hardware qualification run.
