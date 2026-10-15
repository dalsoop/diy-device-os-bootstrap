# Gujo Homelab OS Installer

This engine repository assembles verified public installation media into one
multiboot USB. Ordinary users create a Gujo Homelab World Playbook from its
GitHub template rather than forking this repository. General media composition
is the primary product. The guarded
offline installer for three HP DNS appliances is a bundled local reference
profile, not the identity of the whole repository.

## Project map

```text
gujo-homelab-os-installer/
├── AGENTS.md
├── CLAUDE.md
├── device-os
├── collections/
│   ├── AGENTS.md
│   └── device-os.json
├── usb-media/
│   ├── AGENTS.md
│   ├── composition.json
│   ├── local-entries/
│   ├── resolve-catalog
│   ├── verify-catalog
│   ├── fetch-images
│   ├── calculate-capacity
│   ├── write-usb-linux
│   └── write-image-macos
├── installer/
│   ├── AGENTS.md
│   ├── build-image
│   ├── scripts/install-gate
│   └── payload/
├── management/
│   ├── AGENTS.md
│   ├── dnsctl
│   ├── cluster-bootstrap
│   ├── tailscale-enroll
│   └── dns-appliance-status-monitor/
│       └── AGENTS.md
├── build/AGENTS.md
├── inventory/AGENTS.md
├── schemas/AGENTS.md
├── tests/AGENTS.md
├── zones/AGENTS.md
└── docs/
    ├── architecture.md
    ├── business-rules.md
    ├── security.md
    ├── standards.md
    ├── engineering-notes.md
    ├── operations.md
    ├── contracts.md
    └── tracking/
        ├── status.md
        ├── findings.md
        └── decisions/
            ├── index.md
            └── NNNN-*.md
```

## Hard rules

- Never commit secrets, recovery archives, real hardware inventory, enrollment
  output, generated media, packages, or disk images. Only explicitly public
  inputs such as SSH public keys and age recipients may be tracked.
- Planning and simulation never write disks. USB and DNS installation writes
  require live target identity checks and exact target-specific confirmation;
  zero, removable, installer-media, or ambiguous internal candidates fail closed.
- Treat the public Catalog as untrusted data: pin one exact commit, execute none
  of its code, and validate its JSON again in the Installer.
- General installers remain interactive. DNS unattended installation is limited
  to its local guarded adapter and generation-bound reinstall authorization.
- Report source, VM, physical-media, firmware, installation, and network
  verification as separate states; one never implies the next.

## Read before changing

- Always read `docs/standards.md`, `docs/engineering-notes.md`, and the
  `AGENTS.md` in the directory being changed.
- Read all of `docs/security.md` before changing disk erasure, credentials,
  privilege, or network exposure.
- Read `docs/contracts.md` before changing JSON, CLI, USB, or enrollment formats.
- Read `docs/operations.md` before release, USB writing, installation, or restore work.
- Record ownership or safety decisions under `docs/tracking/decisions/`.

## Change and verification workflow

- Protect `main`; land substantive changes through pull requests.
- User-owned selection and environment intent belong in the World Playbook.
  Do not direct ordinary users to fork this Installer or the Catalog.
- Change public OS metadata in the Catalog. The existing
  `usb-media/local-entries/` content is an Installer-owned reference profile;
  new user-specific selection, hardware binding, and policy belong in the World
  Playbook once the external consumer is implemented.
- Existing source kinds are data-driven. A new source kind or profile adapter
  requires fetch, verify, stage, success, and rejection coverage.
- `dnsctl apply` currently enforces literal `APPLY`, a caller-supplied commit
  equal to `HEAD`, and a clean zone file. Human review and plan comparison are
  operational requirements, not fully machine-enforced approval proofs.
- Releasing an image and writing a physical USB are separate approvals.

