# DIY Device OS Bootstrap

This public monorepo is the single user-owned source for a homelab's device intent, public OS metadata, guarded installation media, and immutable physical USB history. Its first physical target is three HP DNS appliances, while the same `gujo-home` World is intended to accumulate future devices and media.

## Project map

The user works only in `burn-history/`. `engine/` is the machinery that reads it, and `docs/` describes both.

```text
diy-device-os-bootstrap/
├── AGENTS.md                         ← agent entry point
├── CLAUDE.md                         ← Claude entry point; identical to AGENTS.md
├── LICENSE                           ← GNU GPL version 3 for this repository
├── README.md                         ← project overview and quick start
├── CONTRIBUTING.md                   ← contribution workflow
├── device-os                         ← root command; runs engine/installer/device-os
├── burn-history/                     ← everything the user decides, keeps private, or looks back on
│   ├── README.md                     ← user guide
│   ├── .paths.yaml                   ← World playbook: registered data paths read by the World tools
│   ├── home.yaml                     ← home: networks, computers, services, media, policies (you edit)
│   ├── dns-records.zone              ← reviewed DNS zone
│   ├── os-installs/<role>/           ← os.conf guided profile (tracked); hardware.conf real capture (ignored)
│   ├── keys/                         ← operator SSH public key and age recipient (ignored except README.md)
│   ├── .in-progress/                 ← burn recorder state (ignored)
│   └── logs/                         ← what happened; never edited: usb/, usb/failed/, checks/
├── engine/
│   ├── installer/
│   │   ├── AGENTS.md                 ← execution, media assembly, and destructive gates
│   │   ├── dns-image/AGENTS.md       ← guarded offline DNS image and first boot
│   │   ├── usb-media/AGENTS.md       ← resolution, capacity, download, and USB writers
│   │   ├── management/
│   │   │   ├── AGENTS.md             ← post-install DNS, backup, restore, and Tailscale operations
│   │   │   └── dns-appliance-status-monitor/
│   │   │       └── AGENTS.md         ← dependency-free read-only status page
│   │   ├── build/AGENTS.md           ← immutable external build locks
│   │   ├── collections/AGENTS.md     ← reference menu grouping
│   │   ├── schemas/AGENTS.md         ← installation and enrollment records
│   │   ├── tests/AGENTS.md           ← non-destructive source simulations
│   │   └── docs/                     ← installer procedures, physical verification gates, examples/
│   ├── catalog/
│   │   ├── AGENTS.md                 ← data-only public OS catalog boundary
│   │   ├── bin/AGENTS.md             ← executable catalog validator
│   │   ├── data/AGENTS.md            ← indexed bootloader and media metadata
│   │   ├── schemas/AGENTS.md         ← published JSON Schema representations
│   │   └── tests/AGENTS.md           ← catalog acceptance and rejection fixtures
│   ├── agent/
│   │   └── AGENTS.md                 ← constrained management-host MCP gateway
│   └── world/
│       └── AGENTS.md                 ← World resolver and USB recorder: bin/, schemas/, tests/
└── docs/
    ├── licenses/                     ← license history, third-party notices, bundled upstream license texts
    ├── getting-started.md            ← first-run operator guide
    ├── architecture.md               ← components, trust boundaries, and end-to-end flows
    ├── business-rules.md             ← World, media, DNS, evidence, and generation rules
    ├── security.md                   ← identities, credentials, destructive authority, and audit policy
    ├── standards.md                  ← repository, module, contract, documentation, and verification gates
    ├── engineering-notes.md          ← observed traps and symptom-to-response guidance
    ├── operations.md                 ← setup, validation, build, burn, install, and recovery procedures
    ├── contracts.md                  ← CLI, World, Catalog, media, enrollment, and agent interfaces
    └── tracking/
        ├── status.md                 ← implemented, verified, remaining, and blocked capabilities
        ├── findings.md               ← unresolved defects and evidence gaps
        └── decisions/
            ├── index.md              ← decision history
            └── NNNN-*.md             ← individual trade-off decisions
```

Repository text follows the documentation rule in `docs/standards.md`: name roles, never specific machines or personal paths, and describe the present state only.

## Hard gates

1. World intent, a plan, or a successful build never authorizes erasure. Every USB or internal-disk write must re-identify the live target and require its exact target-specific confirmation.
2. Passwords, tokens, private keys, age identities, real hardware inventory, generated media, enrollment records, and recovery archives never enter Git. The USB may carry secrets only after encryption.
3. A completed directory under `burn-history/logs/usb/` is immutable. Every successful physical USB creation receives a new timestamped generation after write and readback verification.
4. `main` changes only through a pull request with the required `contracts` check passing. Do not push directly, force-push, delete protection, or merge around the gate.
   Agents may create a branch, push it, open a pull request, and monitor its checks, but stop after reporting the pull request and its check state. Merge, enable auto-merge, or use an administrator override only after the repository owner explicitly says to merge that pull request, given after it exists and its check state is known. Earlier general requests such as "proceed", "finish", or "build it" are not merge approval.
5. Source checks, image assembly, physical write, firmware boot, OS installation, and network cutover are separate evidence states. Never promote a lower state into a higher-state claim.

## Before changing anything

- Always read `docs/standards.md`, `docs/engineering-notes.md`, and the nearest module `AGENTS.md`.
- Before changing USB or internal-disk selection, unattended installation, restore, credentials, or network exposure, read the destructive-operation and identity policies in `docs/security.md` and the matching failure history in `docs/engineering-notes.md`.
- Before changing a schema, JSON field, CLI output, World vocabulary, or USB layout, read `docs/contracts.md`; update every producer, consumer, fixture, and rejection case together.
- Before preparing a release, burning media, installing hardware, changing router DHCP DNS, or restoring a node, follow `docs/operations.md` and verify the current evidence state in `docs/tracking/status.md` and `docs/tracking/findings.md`.
- Before changing Catalog URLs or hashes, verify the release and checksum through an authoritative vendor channel; a successful download from the same URL is not independent provenance.
- Before changing the agent gateway or DNS apply path, read the complete authorization and audit model in `docs/security.md`; the gateway must not acquire physical-media, install, restore, reinstall, enrollment, arbitrary-command, arbitrary-path, or arbitrary-URL authority.

## When something goes wrong

Tell the user immediately if a secret appears in Git, CI output, logs, an image, or plaintext USB content; a wrong disk becomes writable; a destructive check is bypassed; a completed World generation changes; `main` changes outside the protected pull-request path; a required CI gate is disabled; or a published URL/checksum cannot be reconciled with authoritative provenance.

For every other unresolved problem, record the reproducible condition, impact, reason it cannot be fixed now, and likely next step in `docs/tracking/findings.md`.
