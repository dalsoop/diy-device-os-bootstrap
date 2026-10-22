# 0003: Adopt the DIY Device OS Bootstrap Name

- Status: Accepted
- Date: 2026-10-16

## Context

The previous `gujo-homelab-device-bootstrap` name described a broad device
bootstrap domain but omitted the repository's defining operating-system role.
It also tied a reusable tool to one homelab name. The product actually lets an
operator compose, verify, and burn selected operating systems for devices while
recording the intent and evidence that produced each USB generation.

## Decision

The canonical repository is `dalsoop/diy-device-os-bootstrap` and the display
name is **DIY Device OS Bootstrap**. `DIY` communicates that the operator owns
and reviews the World composition; it does not imply bypassing safety gates.

The naming layers are:

- repository and product: **DIY Device OS Bootstrap**;
- operator CLI: `device-os`;
- destructive USB surface: **Device OS Burner**, invoked with `burn`;
- generated removable media: **DIY Device OS USB**;
- internal intent model: World.

`world burn`, `burn`, and `burn-image-macos` are the preferred command
spellings. The prior `world write`, `write`, and `write-image-macos` spellings
remain compatibility aliases. Internal writer filenames stay unchanged so this
naming change does not disturb their reviewed safety implementation.

## Alternatives

- `gujo-homelab-device-bootstrap` was rejected because it omitted the defining OS role and tied reusable tooling to one homelab brand.
- A USB-only name was rejected because the repository also owns World intent, Catalog resolution, image construction, and installation evidence.
- A playbook-only name was rejected because it hid the physical burner and guarded Installer responsibility.

## Consequences

Repository URLs, badges, schema identifiers, composition metadata, SBOM
namespaces, documentation, and contract checks use the new canonical name.
GitHub redirects the previous repository URL after the rename, but local remotes
and clones should migrate to the new URL and directory name.

The burner terminology changes the human interface only. Every destructive
path retains live removable-device checks, root-disk exclusion, readable serial,
capacity validation, and the exact target-specific `ERASE` confirmation.

The old command aliases are removed. The `device-os` command, `burn`
terminology, and safety model are the only operator surface.
