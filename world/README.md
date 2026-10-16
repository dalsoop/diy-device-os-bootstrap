# World

This module is the user-owned source of homelab intent inside DIY Device OS
Bootstrap. It describes physical assets, networks, logical nodes,
services, selected installation media, and safety policy.

The mutable draft is [`drafts/gujo-home/world.yaml`](drafts/gujo-home/world.yaml).
Editing it does not create a USB or authorize a destructive operation.

Validate and inspect the selected media from the repository root:

```sh
./device-os world validate
./device-os world plan
./device-os world simulate
```

When multiple drafts exist, select one with `DEVICE_OS_WORLD=<slug>`. A World
with multiple media definitions declares `defaultMedia`; override it with
`DEVICE_OS_MEDIA=<id>`. The Gujo Home inventory pass is:

```sh
DEVICE_OS_MEDIA=inventory-capture ./device-os world plan
```

## Accumulating physical USB generations

The World contract assigns every successfully verified physical USB creation a
new immutable generation:

```text
worlds/{YYYYMMDDHHmmss}-{world-slug}/
```

The timestamp will be captured in `Asia/Seoul` when the resolved World is sealed
immediately before the target-specific write. It is not draft creation time,
file modification time, or Git commit time. Once publication is implemented, a
generation becomes durable only after the physical write and required readback
verification succeed.

Another physical write creates another generation even when its desired content
is identical. Completed generations are never edited, overwritten, or silently
upgraded.

## Layout

```text
world/
├── world-playbook.yaml
├── drafts/gujo-home/world.yaml
├── worlds/README.md
├── local/README.md
└── docs/
```

`drafts/` is mutable desired state. `worlds/` is append-only completed history.
`local/` contains ignored machine-local observations and reviewed public inputs.
Generated images, caches, credentials, recovery material, private keys, and raw
hardware identifiers do not belong in Git.

The monorepo commit replaces the former cross-repository Installer and Catalog
pins. The resolved media plan records that commit, the embedded Catalog tree,
and the validated World plan. The physical generation-publication transaction
is not yet implemented; do not claim that a completed generation exists until
the write, readback, and generation evidence exist.
