# 0002: Resolve Media Through a Pinned Declarative Catalog

- Status: Accepted
- Date: 2026-10-15

## Context

Embedding each product, version, URL, checksum, destination, and menu label in
shell branches caused the fetcher, writer, menu, capacity estimate, and
documentation to drift. A shared public catalog is useful only if it cannot
inject executable behavior into Installer consumers.

## Decision

Public bootloader and OS metadata live as one JSON file per item in the Gujo
Homelab OS Catalog. A World Playbook pins an exact Catalog commit, selects
public IDs, and keeps private or profile-specific entries locally. The Installer
resolver fetches data only, validates it with Installer-owned rules, and emits
one resolved plan for downstream stages.

Source behavior is selected by an explicitly implemented `source.kind`.
Product-specific behavior is selected independently by
`profile_adapter`. Unknown values fail closed.

## Rejected alternatives

- Hard-coding every product in shell branches was rejected because fetch,
  verification, menu, capacity, and staging rules drifted independently.
- Tracking a Catalog branch or `latest` was rejected because an unchanged
  Installer commit could resolve to new, unreviewed inputs.
- Executing helper code from the Catalog was rejected because a metadata update
  would become remote code execution in every consuming Playbook.
- A dynamic third-party plug-in loader was deferred because its code trust,
  capability, and compatibility boundaries are not defined.

## Consequences

Adding a public image with an existing source kind is data-only. Adding a new
kind or adapter requires Installer code and tests; the system is not a dynamic
plug-in loader. Each USB records and hashes the exact resolved Catalog used to
assemble it.

