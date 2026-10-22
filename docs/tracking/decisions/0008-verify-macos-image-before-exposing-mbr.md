# 0008: Verify macOS Raw Images Before Exposing Their MBR

- Status: Accepted
- Date: 2026-10-15

## Context

macOS Disk Arbitration can mount exFAT partitions as soon as a new partition
map becomes visible. A normal mount changes filesystem metadata, so a later
whole-device comparison can differ even when payload files copied correctly;
it also exposes filesystems before source-byte readback finishes.

## Decision

The macOS writer accepts only size-matched MBR images. After target validation
and exact confirmation, it invalidates the first MiB, writes and verifies the
remaining body, then writes and verifies the first MiB last. A body failure
leaves the partition map hidden and reports failure without ejecting success.

GPT images are rejected because a backup partition table can remain
discoverable even when the leading map is hidden.

## Alternatives

- Conventional whole-image `dd` followed by `cmp` was rejected because mounted
  filesystem metadata can change before comparison.
- Globally stopping Disk Arbitration was rejected because it changes host-wide
  behavior beyond the selected device.
- Accepting GPT was rejected because hiding only the leading map does not hide
  its backup table.

## Consequences

Every source byte is read back before or while its partition map becomes
visible without changing macOS system configuration. This sequence still
requires a disposable physical rerun and a separate builder for the exact-size
raw image before macOS is a complete workflow.
