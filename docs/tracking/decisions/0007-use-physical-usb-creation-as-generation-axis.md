# 0007: Use Verified Physical USB Creation as the Generation Axis

- Status: Accepted
- Date: 2026-10-15

## Context

The personal World needs history that identifies which intent and locked inputs
produced each physical USB. Draft creation, file modification, and Git commit
times can all precede or outlive several separate physical writes, so none can
identify the physical event without ambiguity.

## Decision

Every successful physical USB creation mints
`{YYYYMMDDHHmmss}-{world-slug}`. The `Asia/Seoul` timestamp is captured when
the resolved World and exact inputs are sealed immediately before the
target-specific write. Publication occurs only after required readback passes;
failed or cancelled attempts do not publish.

Completed generations are immutable and append-only. An identical rewrite
creates another generation. History stores resolved intent, exact locks,
artifact digests, and redacted evidence, but not images, credentials, recovery
material, or plaintext hardware identifiers.

## Alternatives

- Draft creation and last-modified times were rejected because mutable intent
  can change many times before writing media.
- Git commit time was rejected because one commit can create several USBs at
  different times.
- One mutable directory per World was rejected because correcting it would
  erase the provenance of already-created media.
- Publishing before readback was rejected because source and write initiation
  do not prove a completed physical device.

## Consequences

World history grows monotonically and can correlate each physical USB with its
exact inputs. The World event recorder uses ignored pending state, serializes
writes, rejects collisions, records failed or interrupted attempts separately,
and atomically publishes a generation after writer readback passes. Git commit
and push remain explicit pull-request actions outside the root writer.
