# Device OS Catalog

This repository is the public, data-only source of bootloader and operating
system metadata consumed by Device OS Flasher forks. It publishes
versioned JSON contracts, official HTTPS locations, checksums, menu text, and
boot behavior. It never downloads, executes, or writes the media it describes.

## Project map

```text
device-os-catalog/
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── catalog/
│   ├── AGENTS.md
│   ├── index.json
│   ├── entries/*.json
│   └── bootloaders/*.json
├── schemas/
│   ├── AGENTS.md
│   ├── catalog-index.schema.json
│   ├── media-entry.schema.json
│   └── bootloader.schema.json
├── bin/
│   ├── AGENTS.md
│   └── verify-catalog
├── tests/
│   ├── AGENTS.md
│   └── catalog-contract.sh
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

- Never commit secrets, private locations, real inventory, generated media,
  caches, or vendor binaries.
- Every artifact uses an authoritative public HTTPS source and a reviewed
  lowercase SHA-256; Catalog validation alone does not prove provenance.
- Keep one item per JSON file, register every controlled file exactly once, and
  preserve stable IDs across release updates.
- Public entries remain interactive installers or live environments with
  `profile_adapter: none`; private and guarded profiles belong in Flasher forks.
- Do not add download execution, hooks, collection policy, USB layout, or
  disk-write behavior to this data-only repository.

## Read before changing

- Always read `docs/standards.md`, `docs/engineering-notes.md`, and the
  `AGENTS.md` in the directory being changed.
- Read `docs/contracts.md` before changing JSON fields or schema versions.
- Read `docs/security.md` before changing source trust or checksum policy.
- Record ownership, compatibility, or trust decisions under
  `docs/tracking/decisions/`.

## Change workflow

- Protect `main`; use pull requests for substantive changes.
- Verify release identity and checksum through an authoritative vendor channel
  before changing an entry.
- Keep JSON Schemas and the executable validator aligned. The current CI
  verifier does not reject every additional property described by the schemas;
  do not claim strict unknown-field enforcement until parity is implemented.
- Update data, index, schemas, validator, fixtures, and documentation together
  when a contract changes.
- A merged Catalog commit is metadata only. Flashers must deliberately pin it
  and perform download, media, firmware, and hardware verification separately.

