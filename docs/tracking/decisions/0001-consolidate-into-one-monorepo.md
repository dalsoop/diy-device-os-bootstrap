# 0001: Consolidate World, Installer, and Catalog into One Monorepo

- Status: Accepted
- Date: 2026-10-16

## Context

The World Playbook, OS Installer, and OS Catalog were split into three public
repositories. In practice one operator and cooperating agents had to coordinate
three pull requests, exact cross-repository pins, and documentation that pointed
users between repositories. The Installer did not yet consume the external
World Playbook, so the split increased coordination cost before it delivered an
independent release benefit.

## Decision

`dalsoop/diy-device-os-bootstrap` is the canonical repository. It contains three explicit
modules:

- World: operator intent and immutable USB records in `burn-history/`, read and
  published by the World tools in `engine/world/`;
- Catalog: data-only public OS metadata in `engine/catalog/`;
- Installer: executable behavior and destructive safety gates in
  `engine/installer/`.

Users clone or fork only this repository. The root `device-os` command is the
operator entry point. Catalog and Installer are no longer separately pinned by
the draft World; a resolved plan and completed generation record the monorepo
commit and Catalog tree identity instead.

The three former repositories remain available during consolidation and are not
deleted. They may be archived with a pointer to this monorepo only after the
monorepo CI passes and its `main` branch is verified.

## Alternatives

- Keeping three repositories was rejected because one operator had to coordinate three pull requests and exact cross-repository pins before the modules had independent release value.
- Copying everything into one undifferentiated module was rejected because Catalog data, personal intent, and destructive execution retain different trust and review boundaries.
- Deleting the former repositories immediately was rejected because users and links needed a verifiable transition after the monorepo passed CI.

## Consequences

Contract changes and consumers can land atomically in one pull request. Users
have one source of truth and agents need one checkout. Trust boundaries remain
enforced by directory ownership, validators, tests, and destructive runtime
gates rather than by Git repository boundaries.

The monorepo is larger, and path-scoped documentation must prevent Catalog data
from acquiring executable behavior or World intent from bypassing Installer
safety. Completed World generations and secret exclusions remain unchanged.
