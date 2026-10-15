# World Playbook

## Purpose

The Gujo Homelab World Playbook is the user-owned source of intent consumed by
the Installer. The Catalog answers what operating systems are available, the
Installer owns how media is resolved and written safely, and the World Playbook
records what one homelab intended to place on one USB generation.

A World is not a continuously edited digital twin. It is an immutable snapshot
of the user intent and resolved inputs that produced a verified USB. Drafts,
live observations, generated plans, secrets, and completed World generations
have different trust and lifecycle boundaries.

## USB creation is the generation axis

Every physical USB creation starts a new World generation, even when its
desired configuration is identical to an earlier generation. The generation
timestamp is captured when the resolved World is sealed immediately before the
target-specific USB write. It is not the time when the World was first drafted,
when a source file was last edited, or when a Git commit was created.

A generation becomes durable under `worlds/` only after the physical write and
required readback verification succeed. A failed or cancelled write is an
attempt, not a completed World generation, and must not be published as one.
The completion evidence records a separate `completed_at` value.

Generation directories use this format:

```text
{YYYYMMDDHHmmss}-{world-slug}
```

The filename timestamp uses `Asia/Seoul`. The manifest stores the same instant
as an ISO 8601 value with its explicit `+09:00` offset. Four-digit years are
required. The slug uses lowercase ASCII kebab-case.

Example:

```text
worlds/20261015143022-gujo-home/
```

The full generation ID is immutable. A tool must fail rather than overwrite an
existing ID. The human display name may change in a later generation, but a
sealed directory, its slug, and its timestamps never change.

## Append-only history

Completed generations accumulate in chronological order:

```text
worlds/
├── 20261015143022-gujo-home/
├── 20261018110543-gujo-home/
└── 20261103091408-gujo-home/
```

Changing an address, selected operating system, safety policy, hardware
binding, or Catalog revision creates a new generation. Rebuilding or writing a
new physical USB from otherwise identical intent also creates a new generation.
Old generations are not edited in place, rebased onto a new schema, or silently
repointed to newer dependencies.

`latest` may be presented as a derived convenience view, but it is never an
authority and must not be used as an immutable input. A generation may name a
`previous_generation` to make lineage explicit; that reference does not grant
permission to mutate or delete its predecessor.

## Generation contents

Each completed directory records only the small, reviewable material needed to
explain and reproduce the USB generation:

```text
worlds/20261015143022-gujo-home/
├── world.yaml
├── world.lock.json
├── media-manifest.json
└── verification.json
```

The records include:

- generation ID, World slug, `created_at`, and `completed_at`;
- optional previous-generation ID;
- canonical World-content digest;
- exact Installer version or commit;
- exact Catalog commit and selected entry IDs;
- every staged artifact digest and resulting media-manifest digest;
- redacted target-identity evidence and the verification outcome.

Operating-system images, raw disk images, caches, plaintext hardware serials,
credentials, recovery material, and secret values are not stored in the World
history. Large artifacts remain in release or local artifact storage and are
addressed by digest. Secrets remain in the principal secret store and appear
only as non-sensitive references.

## Lifecycle

```text
mutable draft
    |
    | validate and resolve exact inputs
    v
sealed pending generation
    |
    | target-specific approval, write, readback verification
    v
append-only completed generation under worlds/
```

The Installer must keep these states distinguishable. Planning never creates a
completed generation. Image assembly never proves a physical USB write. A USB
write without required readback never becomes a completed generation. Firmware
boot and operating-system installation remain later, separate evidence states.

## Initial implementation boundary

This document defines the intended external contract; the current Installer
still owns its composition and collection files internally. Migration requires
an explicit World input, schema validation, canonical digest generation,
pending-to-completed publication, and rejection tests for overwrite, timestamp,
path-escape, failed-write, and incomplete-verification cases.
