# Findings

## Schema and executable validation are duplicated

The JSON Schemas and jq-based executable validator express overlapping
contracts independently. They already differ: schemas reject additional
properties and constrain optional `architecture`, while the executable gate
does not enforce those rules. This has not been replaced with code generation
because the executable gate also performs filesystem and uniqueness checks that
plain schemas do not cover. CI success must not be described as full schema
validation until parity is implemented.

## Checksum provenance is review evidence, not repository data

Entries store the resulting SHA-256 but not a structured, signed provenance
record. A syntactically valid digest can still be wrong. Each update therefore
depends on pull-request evidence from an authoritative vendor source. A future
provenance field needs a cross-consumer contract decision.

## Flasher compatibility is not tested in this repository

Catalog CI validates its own contract but does not resolve entries through every
Flasher version. Exact-commit pinning prevents silent changes, but a schema
change can still break a Flasher that deliberately repins. A future
cross-repository fixture should be added before expanding schema semantics.

## Vendor URLs may not be immutable

Some vendors publish version-looking URLs while retaining the ability to replace
content. The digest protects consumers from unnoticed byte changes, but a
replaced artifact becomes unavailable rather than transparently updated. Mirror
and archival policy remains outside the current public Catalog scope.
