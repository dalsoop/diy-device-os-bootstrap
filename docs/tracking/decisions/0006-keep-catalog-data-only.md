# 0006: Keep the Catalog Public and Data-Only

- Status: Accepted
- Date: 2026-10-15

## Context

Reusable vendor metadata benefits from shared review, while private selection,
downloads, unattended installation, credentials, and disk writes carry local
policy and destructive risk. Placing executable hooks next to public metadata
would turn an apparently declarative update into code execution for every
consumer.

## Decision

The Catalog contains only public bootloader and operating-system metadata,
stable identities, official HTTPS locations, checksums, menu text, and boot
behavior. The Installer treats it as untrusted data, validates it again, and
records its Git tree identity. World owns selection; Installer owns execution;
the principal secret store owns credentials.

## Alternatives

- Combining metadata and Installer behavior was rejected because public updates
  would inherit local destructive and secret-handling authority.
- Executable entry hooks were rejected because Catalog review could no longer
  establish the behavior a consumer runs.
- Private or signed URLs were rejected because a public repository cannot
  protect them or reproduce their availability.

## Consequences

Catalog changes cannot download, execute, or write media by themselves. A new
behavior requires an explicit Installer contract and tests rather than a field
that silently becomes executable. Public metadata remains reusable, while
selection and policy stay personal.
