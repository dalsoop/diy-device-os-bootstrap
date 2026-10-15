# Architecture

## Repository role

The World Playbook is the user-owned source of desired homelab state. It is the
only repository an ordinary operator creates from a template and edits.

```text
Gujo Homelab OS Catalog
  reusable public OS metadata
             |
             v
Gujo Homelab OS Installer <--- Gujo Homelab World Playbook
  execution and safety          user intent and immutable generations
             |
             v
      verified physical USB
```

The World Playbook does not execute Catalog code, implement a USB writer, or
hold secret values. The Installer must consume a specific Playbook revision and
produce explicit plans and evidence without modifying a completed generation.

## World model

One World represents one connected environment. Its initial vocabulary is
limited to physical assets, networks, logical nodes, services, media selection,
and safety policy. DNS, Proxmox, TrueNAS, and workstations are members of a
World, not independent Worlds.

Physical assets and logical nodes are distinct. Replacing an HP computer should
change the asset binding without changing the logical `dns01` identity, address,
or service membership.

## State planes

| Plane | Mutability | Location |
| --- | --- | --- |
| Desired draft | Mutable | `drafts/<slug>/world.yaml` |
| Local observation | Mutable and ignored | `local/` or generated workspace |
| Generated plan | Ephemeral and ignored | Installer workspace |
| Completed USB generation | Immutable and append-only | `worlds/<generation-id>/` |
| Secret value | External | Principal secret store |

The Installer compares desired state with live observation before destructive
work. A committed desired value is not proof that the target still matches.

## Implementation status

The repository currently defines the contract and example intent only. The
Installer still keeps composition inside its own checkout and does not yet
accept this Playbook as an external input.
