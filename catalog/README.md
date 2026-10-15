# Catalog Module

This module is the data-only registry of public operating-system and bootloader
metadata used by the sibling Installer. It publishes official HTTPS locations,
reviewed SHA-256 values, stable IDs, menu labels, and boot behavior. It never
downloads, executes, or writes the media it describes.

The Catalog shares the Gujo Homelab OS Playbook repository so metadata, its Installer
consumer, fixtures, and World selection can change atomically. It remains an
untrusted runtime input: the Installer validates the JSON again and records the
Catalog Git tree identity in every resolved plan.

## Layout

```text
catalog/
├── catalog/index.json
├── catalog/entries/*.json
├── catalog/bootloaders/*.json
├── schemas/
├── bin/verify-catalog
└── tests/catalog-contract.sh
```

Each product has one JSON file and appears exactly once in
`catalog/index.json`. Stable IDs do not contain release numbers. Public entries
remain interactive installers or live environments with
`profile_adapter: none`; guarded local profiles belong to the Installer and
selection belongs to the World.

For a release update, verify the authoritative vendor version, architecture,
filename, URL, and lowercase SHA-256 as one review unit. Update the entry and
index contracts together and rely on the root CI for validation. A passing
Catalog test proves metadata consistency only, not download provenance, boot,
firmware, or installation behavior.

See [contracts](docs/contracts.md), [security](docs/security.md), and
[engineering standards](docs/standards.md).

