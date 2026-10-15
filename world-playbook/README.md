# Gujo Homelab World Playbook

This is the one repository a Gujo Homelab operator owns and edits. It records
the desired environment used to build installation media while the public
[Gujo Homelab OS Installer](https://github.com/dalsoop/gujo-homelab-os-installer)
owns execution and the public
[Gujo Homelab OS Catalog](https://github.com/dalsoop/gujo-homelab-os-catalog)
owns reusable operating-system metadata.

> Current maturity: contract scaffold. The World format and append-only USB
> generation rules are documented, but the Installer does not yet consume this
> repository directly. Do not treat this source scaffold as a physically
> qualified USB workflow.

## Start here

Use GitHub's **Use this template** action to create your own World Playbook.
Do not fork the Installer or Catalog for ordinary use.

The initial draft is [`drafts/gujo-home/world.yaml`](drafts/gujo-home/world.yaml).
Edit the draft as intent changes. A draft has no generation timestamp because
draft creation and editing do not create a USB.

## One World, accumulating USB generations

The World describes one homelab as a connected whole: physical assets,
networks, logical nodes, services, selected installation media, and safety
policy. DNS, Proxmox, TrueNAS, and workstations are parts of that World, not
separate Worlds.

Every successful physical USB creation publishes a new immutable generation:

```text
worlds/{YYYYMMDDHHmmss}-{world-slug}/
```

The timestamp is captured when the resolved World is sealed immediately before
the target-specific USB write. It is not the draft creation time, file edit
time, or Git commit time. A generation becomes durable only after the physical
write and required readback verification succeed.

```text
mutable draft
    |
    | resolve and seal for one USB creation
    v
pending generation
    |
    | physical write and readback verification
    v
append-only completed generation under worlds/
```

Making another USB creates another generation even when the desired content is
identical. Completed generations are never edited, overwritten, or silently
upgraded.

## Repository layout

```text
gujo-homelab-world-playbook/
├── AGENTS.md
├── world-playbook.yaml
├── world-playbook.lock.json
├── drafts/
│   └── gujo-home/
│       └── world.yaml
├── worlds/
│   └── README.md
├── local/
│   └── README.md
└── docs/
    ├── architecture.md
    ├── contracts.md
    ├── security.md
    └── tracking/status.md
```

`drafts/` is mutable user intent. `worlds/` is append-only completed history.
`local/` contains ignored machine-local observations and public input files.
Generated images, caches, credentials, recovery material, and private keys do
not belong in Git.

## Planned operator surface

The intended Installer interface is:

```sh
device-os world validate /path/to/gujo-homelab-world-playbook
device-os world plan /path/to/gujo-homelab-world-playbook --draft gujo-home
device-os world write /path/to/gujo-homelab-world-playbook \
  --draft gujo-home \
  --media dns-bootstrap \
  --device /dev/diskN
```

These commands are a target contract, not an implemented claim. The write must
retain the Installer's live target checks and exact erase confirmation.

## Known network assumption

The example draft records the intended router at `10.0.0.1` and DNS nodes at
`10.0.5.1` through `10.0.5.3`. It currently models a `/16` LAN so those
addresses share one subnet. The actual router prefix or an explicit route must
be verified before installation or DNS cutover.
