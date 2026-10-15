# 0002: Use Stable IDs and Exact-Commit Consumer Pinning

- Status: Accepted
- Date: 2026-10-15

## Context

Collections need product identities that survive release updates. Consumers also
need reproducible metadata and must not receive unreviewed Catalog changes.

## Decision

Entry IDs identify products and remain stable across versions. Release identity
lives in entry fields. Installer consumers pin a full 40-character Catalog commit
rather than a branch, tag, or `latest` reference.

## Rejected alternatives

- Versioned IDs were rejected because every release would force all Installer
  collections to change selection keys.
- Branch and tag pins were rejected because they can move without a Installer
  source change.
- Automatically following Catalog `main` was rejected because a merge would
  silently alter every consumer's supply-chain input.

## Consequences

Release updates do not force collection edits. Catalog merges do not
automatically alter existing Installers. Removing or renaming an ID is a
compatibility event, and consumers must deliberately review and repin.
