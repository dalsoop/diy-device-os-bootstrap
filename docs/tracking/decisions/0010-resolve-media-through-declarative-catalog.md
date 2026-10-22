# 0010: Resolve Media Through a Pinned Declarative Catalog

- Status: Accepted
- Date: 2026-10-15

## Context

Embedding product versions, URLs, checksums, destinations, and menu labels in
shell branches allowed fetch, verification, capacity, menu, and staging behavior
to drift. Declarative metadata is useful only if it cannot inject executable
behavior or change silently between resolution and writing.

## Decision

Public bootloader and OS metadata use one indexed JSON file per item. The World
selects stable IDs, and the Installer validates the data and emits one resolved
plan consumed by every downstream stage. The repository commit identifies the
source snapshot and the Catalog tree identity allows independent comparison of
that data within the monorepo.

Executable behavior is limited to implemented `source.kind` and
`profile_adapter` strategies. Unknown values fail closed. Each assembled USB
records and hashes the exact resolved metadata it consumed.

## Alternatives

- Product-specific shell branches were rejected because independent fetch,
  verification, menu, capacity, and staging edits drifted.
- Moving branches, tags, and `latest` references were rejected because the same
  source could resolve to unreviewed inputs later.
- Executable Catalog helpers were rejected because metadata review would become
  remote code review for every consumer.
- A dynamic third-party plug-in loader was deferred because its code-trust,
  capability, and compatibility boundaries are not defined.

## Consequences

Adding a public image that uses an existing strategy is a data change. Adding a
source kind or adapter is executable work with explicit success and rejection
coverage. Stable IDs survive release updates, while exact versions and digests
remain visible in the resolved plan.
