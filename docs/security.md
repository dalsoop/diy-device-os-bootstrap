# Security

## Trust boundaries

The World Playbook is declarative input, not authorization to execute a
destructive action. The Installer must independently resolve and inspect the
live target, reject ambiguity, and require exact target-specific confirmation.

The public Catalog is untrusted external data even when pinned. The Installer
must validate consumed metadata and execute no Catalog code. A Playbook path is
also untrusted until normalized and proven to remain inside its declared World.

## Sensitive material

Never commit:

- passwords, API tokens, OAuth credentials, or private SSH keys;
- age private identities or decrypted recovery archives;
- plaintext machine serials, UUIDs, disk serials, or enrollment records;
- generated ISO, raw disk, package, or cache artifacts.

Public SSH keys and age recipients may be supplied as reviewed local inputs,
but private counterparts remain in the principal secret store. Secret
references must identify a provider and key without exposing the value.

## Immutable history

Completed generations are evidence. Rewriting one would break the association
between a physical USB and the intent and locks that produced it. Corrections,
dependency updates, and repeated writes therefore create new generations.

Redacted target identity may be recorded as a digest. A digest does not replace
the Installer's live serial and removability checks and must not be accepted as
permission to erase a device.
