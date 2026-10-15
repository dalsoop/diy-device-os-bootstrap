# 0006: Use Verified USB Creation as the World Generation Axis

- Status: Accepted
- Date: 2026-10-15

## Context

The user-owned World Playbook needs a stable history that explains which intent
and locked inputs produced each physical USB. Using the first draft time, latest
edit time, Git commit time, or a mutable environment name would allow the
identity of an already-created USB to drift away from its recorded World.

## Decision

Mint one immutable World generation for every physical USB creation. Its ID is
`{YYYYMMDDHHmmss}-{world-slug}`. The timestamp uses `Asia/Seoul` and is captured
when the resolved World is sealed immediately before the target-specific write.
The same instant is stored in ISO 8601 form with an explicit offset.

Publish the generation under `worlds/` only after the write and required
readback verification succeed. Record physical completion separately as
`completed_at`. Failed or cancelled writes are attempts and never completed
generations.

Completed generations are append-only. Any change or new physical USB creates
a new generation, including a repeated write from identical desired state.
Existing generation files and dependency locks are never rewritten. A derived
`latest` view is not authoritative.

The history stores declarative snapshots, exact locks, digests, and redacted
verification evidence. It does not store operating-system images, raw disk
images, credentials, recovery material, or plaintext hardware identifiers.

## Rejected alternatives

- World draft creation time was rejected because a draft can change many times
  before it produces media.
- Git commit time was rejected because one commit can produce multiple physical
  USBs and a checkout can be built long after the commit.
- Last-modified time was rejected because it is mutable and filesystem-specific.
- Reusing one stable directory per World was rejected because it would erase
  the provenance of older USBs.
- Publishing before write verification was rejected because source or image
  success does not prove a completed physical device.
- Committing generated images with each generation was rejected because the
  immutable digest and external artifact are sufficient and repository growth
  would become operationally unsafe.

## Consequences

The World history grows monotonically and can correlate a USB with its exact
intent and inputs. Repeated writes intentionally produce repeated snapshots.
Storage growth in Git remains small because binary artifacts stay outside the
history. The Installer needs a pending-generation transaction and must refuse
ID collisions or attempts to overwrite a sealed generation.

This decision defines a contract only. It does not claim that the current
Installer already consumes or publishes World Playbook generations.
