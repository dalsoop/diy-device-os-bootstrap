# Catalog Schema Module

This module publishes the JSON Schema representation of Catalog contracts.

- Keep schemas aligned with the executable verifier and current schema version.
- Reject unexpected fields with `additionalProperties: false`.
- Use stable definitions for IDs, HTTPS sources, lowercase SHA-256, and safe
  relative destinations.
- Do not describe Installer-only runtime artifacts, profile adapters, selection,
  or disk behavior.
- Incompatible required fields or changed meanings require a schema-version
  decision and coordinated consumer updates.
- Every schema change includes accepted and rejected fixtures in the same pull
  request.
