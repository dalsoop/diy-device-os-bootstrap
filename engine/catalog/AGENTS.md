# Catalog Module

This module owns reusable public bootloader and operating-system metadata. It is data-only and untrusted at runtime; it does not select personal media, execute downloads, build images, hold credentials, or write disks.

## Boundaries

- `data/index.json` is the closed-world registry. Every controlled JSON file appears exactly once, and every reference resolves to one controlled file.
- `data/entries/` owns public media metadata. Private images, signed URLs, hardware bindings, guarded profiles, and personal selection do not belong here.
- `data/bootloaders/` owns bootloader release metadata, not extraction or installation behavior.
- `schemas/` publishes the JSON shape; `bin/verify-catalog` is the executable CI gate; `tests/` owns isolated acceptance and rejection fixtures.
- Installer source strategies and World policy are outside this module. Never add hooks or command fragments to a Catalog entry.

## Invariants

- One stable lowercase-hyphen ID identifies a product across releases; release numbers stay in version fields, not IDs.
- A release update changes version, architecture where applicable, source filename, HTTPS URL, lowercase SHA-256, and destination as one reviewed unit.
- Public entries use `profile_adapter: none` and only `interactive-installer` or `live-environment` behavior.
- Paths are relative and contained; download filenames are basenames; entry destinations stay under `images/` and end in `.iso`.
- Catalog data never contains credentials, private locations, real inventory, generated media, local profiles, or erasure policy.
- A valid digest format is not provenance. Review must verify the checksum through an authoritative vendor channel independent of the downloaded artifact.

## Change pattern

An ordinary release update changes one entry while preserving its ID and contract. A new field, accepted enum value, source kind, or behavior is a cross-module contract change: update schema, executable validator, Installer consumer, success fixtures, and rejection fixtures together.

The schemas currently reject all additional properties, while the jq validator does not reject every unknown field. Do not claim strict runtime schema parity or use an unknown property as a hidden extension point.

## Verification

Run `engine/catalog/bin/verify-catalog` and `engine/catalog/tests/catalog-contract.sh`. Cover absent and unregistered files, duplicate IDs/paths/filenames, unsafe paths, malformed digests, non-HTTPS URLs, unsupported behavior, and any newly introduced field. A pass proves metadata consistency only; it does not prove vendor authenticity, successful download, firmware boot, or installation.
