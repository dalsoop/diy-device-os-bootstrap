# Security

## Trust model

Catalog data is public and non-secret. It is still supply-chain input: a changed
URL or digest can redirect Flasher users to a different artifact. Pull-request
review, exact commit pinning, HTTPS, authoritative checksum provenance, and
consumer-side digest verification are independent controls.

The repository never executes described artifacts or fetched code. It stores no
authentication material and has no reason to receive write access to a user's
disk.

## Forbidden content

Never commit credentials, tokens, private keys, cookies, signed URLs, private
mirror locations, real hardware inventory, recovery records, generated media,
or vendor binaries. Do not place sensitive values in examples, issue output, CI
logs, or commit messages.

## Path and input safety

IDs and paths use restricted character sets. Paths are relative, normalized,
inside the expected catalog directory, and free of empty, current, or parent
segments. Entry destinations stay under `images/` and end in `.iso`.
Download filenames are basenames, not paths.

The index is closed-world: unregistered JSON and references to absent files are
both rejected. Duplicate IDs, paths, and source filenames are rejected.

Published schemas use `additionalProperties: false`, but the current
executable CI verifier does not invoke those schemas or reject every extra key.
Consumers must interpret only documented fields. Strict executable
unknown-field rejection remains an open contract-parity finding.

## Source updates

A reviewer verifies the release version, URL, architecture, and SHA-256 from an
authoritative vendor source. A successful HTTP response does not establish
authenticity. If provenance is missing or contradictory, do not merge the
update.

Compromised or withdrawn media is handled by removing or correcting the entry in
a reviewed commit and notifying consumers to repin. Existing Flasher pins remain
historical and are not silently mutated.

## Incident response

If a secret or private URL is committed, stop work, avoid reproducing the value,
revoke or rotate it, inspect history and CI logs, and remove it through the
repository's approved history-remediation process.

If an incorrect digest or malicious source is published, preserve evidence,
block the affected entry, identify every released Catalog commit containing it,
and communicate the exact safe replacement commit. Do not merely update
`main` and assume pinned consumers are repaired.
