# Build Lock Module

This module records immutable external identities used by the DNS image.

- Keep one reviewed source-of-truth value for each upstream release, snapshot,
  architecture, URL, digest, and tool version.
- Use authoritative vendor provenance for every digest update.
- Never store downloaded archives, packages, images, or generated media here.
- A lock update must also update every consumer and expected build evidence.
- Do not replace exact versions, dated snapshots, OCI digests, or SHA-256 values
  with branches, tags that can move, or `latest`.
- Verification failure stops the build; there is no warning-only mode.
- Verify a lock change by checking authoritative provenance, running the lock
  verifier, and recording the resolved artifact identity in release evidence.

