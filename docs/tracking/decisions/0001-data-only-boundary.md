# 0001: Keep the Catalog Public, Data-Only, and Separate from Installers

- Status: Accepted
- Date: 2026-10-15

## Context

Reusable vendor metadata benefits from shared review, while selection, private
profiles, downloads, USB writes, and unattended installation carry local policy
and destructive risk.

## Decision

The Catalog stores only public bootloader and media metadata. It contains no
credentials, private media, executable behavior, collection choice, local
profile, download execution, or disk-write logic. Installers consume an exact
commit as untrusted data and enforce their own contracts.

## Rejected alternatives

- Combining Catalog and Installer was rejected because shared public metadata
  would inherit local selection, secret, and destructive-write concerns.
- Allowing executable entry hooks was rejected because a metadata pull request
  would become code execution in every consuming Installer.
- Accepting private or signed download URLs was rejected because the public
  repository cannot protect or reliably reproduce them.

## Consequences

The Catalog can remain public and broadly reusable. World Playbooks keep
user-owned policy while secret values remain in the principal secret store.
Adding behavior requires an Installer change rather than a Catalog field that
silently becomes executable.
