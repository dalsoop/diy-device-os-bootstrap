# 0002: World Drives Operator Media Selection

- Status: Accepted
- Date: 2026-10-16

## Context

The monorepo had a complete World example, but `device-os` still selected media
from an Installer-owned reference collection and always appended every local
profile. That made the documented user source of truth non-executable and could
retain DNS-specific capacity even when a user did not want the DNS installer.

## Decision

Ordinary operators use `device-os world ...`. A versioned World resolver
validates the selected draft, references, addresses, media IDs, language, and
fail-closed policies. The Installer consumes that resolved plan and selects
exactly the listed entry IDs from either the embedded public Catalog or the
reviewed local-profile registry.

`installer/collections/device-os.json` remains the menu-group definition and a
legacy contributor reference selection. It is not the ordinary user's source
of truth. When the World omits the DNS profile, the resolved USB plan sets the
DNS enrollment reserve to zero.

World intent never authorizes erasure. The existing writer must independently
prove a removable non-root device, readable serial, sufficient capacity, and an
exact target-specific confirmation. Publishing an immutable completed World
generation remains a separate future transaction after verified physical write
and readback.

## Consequences

Users customize one World draft and can review the exact resulting media plan.
Unknown, duplicate, or ambiguous IDs fail closed, and a local profile cannot
shadow a public Catalog ID. The resolved plan records both World selection and
Catalog identity, while execution behavior stays in the Installer.

The runtime now requires Ruby for World validation. Existing top-level
reference commands remain available for contributor compatibility but are not
the documented operator workflow.
