# 0012: Default to Source-Only Releases and Require Independent Prebuilt Gates

- Status: Accepted
- Date: 2026-10-17

## Context

The repository must remain public and useful for the operator's personal
self-builds without implying that a verified download, successful build, SBOM,
CI result, physical write, or installation grants permission to redistribute
third-party bootloaders, operating-system images, packages, or a composite DNS
ISO. The DNS image has both third-party component obligations and final-image
obligations. Repository automation also cannot serve as the human approval
boundary for public prebuilt distribution.

## Decision

Public releases default to source-only. The candidate-build workflow may retain
a fixed set of non-executable verification evidence, but it does not publish a
GitHub Release and never uploads an ISO, RAW, IMG, disk image, or complete USB
content. Personal self-build and media writing remain allowed for the
operator's own devices and remain marked `personal-use-only`.

Exact public artifact review binds version, URL, and SHA-256 to license,
notices, corresponding-source, trademark, and obligation evidence. The DNS ISO
requires both complete component review and a separate final review bound to
the ISO, component registry, build manifest, SBOM, and fulfilled obligation
files. Neither gate replaces the other, and no command creates reviewed status.

Future prebuilt publication requires both a successful `prebuilt-release`
policy check and the protected GitHub Environment `prebuilt-distribution`,
configured with a human-only required reviewer. Generated-artifact distribution
also remains disabled until a separate reviewed policy change. No earlier
evidence state promotes automatically.

## Alternatives

- Publishing build outputs after checksum and CI success was rejected because
  integrity evidence does not establish redistribution permission or fulfilled
  obligations.
- Treating component review as sufficient for the DNS ISO was rejected because
  composition can create final-artifact notice, source, and trademark duties.
- Treating only the final ISO review as sufficient was rejected because it can
  hide an unreviewed component or `NOASSERTION` in the closure.
- Using pull-request approval as the only human gate was rejected because the
  same credentials and automation may participate in repository changes.
- Permanently removing a future prebuilt path was rejected because exact review
  and independently protected approval can support a safe later decision.

## Consequences

Current public distribution is limited to source. Verification evidence can be
reviewed without exposing executable media. Prebuilt publication requires more
work and external owner configuration, but failures remain explicit and no
build, validation, physical operation, or agent can silently promote an
artifact into public distribution.
