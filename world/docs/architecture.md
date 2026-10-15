# Architecture

## Module role

The World module is the user-owned source of desired homelab state inside the
single Gujo Homelab OS Playbook repository.

```text
catalog/
  reusable public OS metadata
             |
             v
installer/ <--- world/
  execution and safety          user intent and immutable generations
             |
             v
      verified physical USB
```

The World module does not execute Catalog code, implement a USB writer, or hold
secret values. The Installer consumes the same monorepo snapshot and produces
explicit plans and evidence without modifying a completed generation.

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

The module currently defines the contract and example intent only. The
Installer still keeps its reference composition under `installer/` and does not
yet resolve media selection from this World draft.
