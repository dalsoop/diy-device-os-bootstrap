# Contracts

## Catalog index

`catalog/index.json` uses `schema_version: 1`, the canonical repository name
and URL, and non-empty arrays of bootloader and entry references.

Each reference has a stable lowercase-hyphen ID and a safe relative path under
the expected controlled directory. IDs and paths are unique. The registered
file set must equal the actual JSON file set.

## Media entry

A public media entry contains:

| Field | Constraint |
| --- | --- |
| `schema_version` | exactly 1 |
| `id` | stable lowercase letters, digits, and hyphens |
| `group` | lowercase-hyphen menu group expected by Flashers |
| `version` | non-empty vendor release identity |
| `architecture` | optional non-empty architecture label |
| `destination` | safe relative `images/...iso` path |
| `menu_alias` | non-empty human-facing label |
| `description_ko` | non-empty Korean description |
| `description_en` | non-empty English description |
| `boot_behavior` | `interactive-installer` or `live-environment` |
| `profile_adapter` | exactly `none` |
| `source.kind` | exactly `locked-download` |
| `source.filename` | unique basename-only filename |
| `source.url` | HTTPS URL |
| `source.sha256` | lowercase 64-character SHA-256 |

Published JSON Schemas reject additional properties. The current jq-based CI
verifier validates required values but does not reject every extra key, so
strict unknown-field rejection is not yet an enforced repository guarantee.
The Catalog does not define guarded unattended behavior or runtime artifacts.

## Bootloader

A bootloader contains schema version, stable ID, implementation, version,
archive root, and a locked-download source. Its URL and digest rules match media
entries. The archive root is a safe relative value used by the Flasher after
verified extraction.

## Path rules

A safe relative path starts with an alphanumeric character, contains only the
allowed portable character set, is not absolute, and has no empty, `.`, or
`..` segment. Entry destinations remain under `images/`. Download filenames
contain no slash.

## Compatibility

Stable IDs are consumer-facing. A normal release update preserves the ID.
Removing or renaming an ID, changing required fields, expanding behavior, or
altering field meaning is a compatibility change.

Compatible contract evolution requires existing consumers to remain secure and
correct. Incompatible evolution requires a new schema version and coordinated
Flasher updates before publishing entries that depend on it.

## Verification result

`bin/verify-catalog` exits zero only when the index, controlled files,
entry/bootloader contracts, and uniqueness rules all pass. Any rejection exits
nonzero and prints a diagnostic. The command emits no media and changes no
repository state.
