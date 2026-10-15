# Business Rules

## Public catalog policy

The Catalog contains reusable public metadata only. An entry is eligible when
its artifact is publicly obtainable from an authoritative vendor endpoint, has
a verifiable SHA-256, fits an existing public contract, and does not require
credentials or organization-specific policy.

Private mirrors, licensed media, signed URLs, credentials, real inventory,
custom unattended intent, and local support bundles belong in a user-owned
World Playbook. Executable adapter behavior belongs in the Installer.

## Identity and release updates

An entry ID identifies the product role across releases. It remains stable when
the version changes. A release update changes the version, source filename, URL,
digest, and destination together where applicable.

The index registers each ID and path exactly once. Renaming or removing an ID is
a compatibility event because World Playbook selections may reference it.

## Boot behavior

Public installation media is explicitly interactive. Diagnostic media is a live
environment. The Catalog does not publish `guarded-unattended` entries and
cannot authorize disk erasure.

Korean and English descriptions are required because Installer menus and user
guidance are bilingual. The descriptions explain intended use and destructive
expectations but do not replace installer safeguards.

## Source quality

Downloads use HTTPS. Each SHA-256 is checked against an authoritative vendor
channel during review; computing a hash from the same untrusted download is not
independent provenance.

Moving aliases, branch names, and `latest` endpoints are rejected as release
identity when a versioned immutable URL is available.

## Consumer model

A World Playbook chooses which entries to include and pins an exact Catalog
commit. Catalog merge does not add an item to every USB. Installer resolution,
download verification, media assembly, and physical qualification remain
separate.

A Catalog fork may be used for contribution or deliberate testing, but the
Playbook owner assumes trust for the selected repository and exact commit.
