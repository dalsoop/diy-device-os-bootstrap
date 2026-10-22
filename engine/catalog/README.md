# Catalog Module

This module is the data-only registry of public operating-system and bootloader
metadata used by the Installer in `engine/installer/`. It publishes official HTTPS locations,
locked SHA-256 values, stable IDs, menu labels, boot behavior, and an explicit
redistribution-review status. It never
downloads, executes, or writes the media it describes.

The Catalog shares the DIY Device OS Bootstrap repository so metadata, its Installer
consumer, fixtures, and World selection can change atomically. It remains an
untrusted runtime input: the Installer validates the JSON again and records the
Catalog Git tree identity in every resolved plan.

## Layout

```text
engine/catalog/
├── data/index.json
├── data/entries/*.json
├── data/bootloaders/*.json
├── schemas/
├── bin/verify-catalog
└── tests/catalog-contract.sh
```

Each product has one JSON file and appears exactly once in
`data/index.json`. Stable IDs do not contain release numbers. Public entries
remain interactive installers or live environments with
`profile_adapter: none`; guarded local profiles belong to the Installer and
selection belongs to the World.

Media and bootloader records use `schema_version: 2` and require a
`redistribution` object. Current records are exactly
`{"status":"personal-use-only"}`: a pinned URL and digest are not a
redistribution review.

A future `redistribution-reviewed` record must bind the review to the exact
parent version, source URL, and SHA-256. It also records a date and reviewer,
HTTPS evidence for license, notices, corresponding source, and trademark, and
exactly one disposition for each required obligation. Embedded and release
bundle files use safe relative paths and exact SHA-256 values. The validator
rejects incomplete records, identity mismatches, unknown fields, unsafe paths,
and invalid disposition/location combinations. This metadata records a review;
it does not itself authorize or perform a public release.

Because standard JSON Schema cannot compare arbitrary sibling values, each
schema closes reviewed records over an explicit list of exact artifact
ID/version/URL/SHA-256 tuples. A new or updated artifact may remain
`personal-use-only` without changing that list; promoting it to
`redistribution-reviewed` requires adding its exact tuple in the same change.
The Catalog simulation checks that tuple branches cover every current record
and are internally consistent. The integration contracts task must also run a
standards-compliant JSON Schema 2020-12 validator against accepted and rejected
reviewed fixtures; executable jq validation is not a substitute for that gate.

For a release update, verify the authoritative vendor version, architecture,
filename, URL, and lowercase SHA-256 as one review unit. Update the entry and
its redistribution status together and rely on the root CI for validation. A passing
Catalog test proves metadata consistency only, not download provenance, boot,
firmware, or installation behavior.

See the repository [contracts](../../docs/contracts.md),
[security policy](../../docs/security.md), and
[engineering standards](../../docs/standards.md).

