# Schema Module

This module defines machine-readable records exchanged across installation and
management.

- Treat `schema_version` as a compatibility boundary. Incompatible required
  fields or changed meanings require a new version.
- Keep `additionalProperties: false` where unexpected security-relevant fields
  must be rejected.
- Enrollment records contain plaintext operational evidence only: raw hardware
  identities, fingerprints, image/build IDs, service health, and timestamps.
- Never add passwords, tokens, private keys, recovery plaintext, or OAuth data.
- A schema change must update producers, consumers, fixtures, and rejection
  cases in the same pull request.

