# World

This module is the user-owned source of homelab intent inside the Gujo Homelab
OS Playbook monorepo. It describes physical assets, networks, logical nodes, services,
selected installation media, and safety policy.

The mutable draft is [`drafts/gujo-home/world.yaml`](drafts/gujo-home/world.yaml).
Editing it does not create a USB or authorize a destructive operation.

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
pins. A resolved plan and completed generation must record that commit and the
embedded Catalog tree identity. The physical publication transaction is not yet
implemented; do not claim that a World was written until the command, readback,
and generation evidence exist.
