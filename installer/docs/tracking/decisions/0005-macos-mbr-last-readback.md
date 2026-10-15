# 0005: Verify macOS Raw Images Before Exposing Their MBR

- Status: Accepted
- Date: 2026-10-15

## Context

macOS Disk Arbitration can automatically mount exFAT partitions as soon as a
new partition map becomes visible. A normal mount updates filesystem metadata,
so a whole-device comparison after a conventional `dd` can report differences
even when every staged file was copied correctly. It can also expose a
filesystem before readback has completed.

## Decision

The macOS writer supports size-matched MBR images only. After target validation
and exact confirmation, it invalidates the first MiB, writes and verifies the
remaining image body, then writes and verifies the first MiB last. It unmounts
again before ejecting. A body verification failure leaves the partition map
hidden and does not report success or eject the target.

GPT images are rejected because their backup partition table can remain
discoverable when only the leading partition map is hidden.

## Consequences

Every source byte is read back before or while its partition map becomes
visible, without globally stopping Disk Arbitration or changing macOS system
configuration. A successful source simulation is still not physical
qualification; disposable-media rerun and firmware boot evidence remain
required.
