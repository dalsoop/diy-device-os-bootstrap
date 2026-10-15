# 0007: Make the World Playbook the Only User-Created Repository

- Status: Accepted
- Date: 2026-10-15

## Context

Directing ordinary users to fork the Installer mixed user intent, hardware
bindings, and local profiles with shared execution code. It also made the
Catalog, Installer, and user configuration boundaries difficult to explain and
upgrade independently.

## Decision

The Gujo Homelab World Playbook is the only repository an ordinary user creates
and manages. GitHub Template creation is preferred over forking because each
Playbook is an independent project and may choose its own visibility.

The Gujo Homelab OS Installer remains a shared execution and safety engine. The
Gujo Homelab OS Catalog remains shared public data. Ordinary users do not fork
either repository. Installer and Catalog revisions are pinned by the Playbook.

The canonical template is:

```text
https://github.com/dalsoop/gujo-homelab-world-playbook
```

The current Installer-internal composition remains a reference implementation
until external World input is supported. Documentation must not imply that the
external consumer already exists.

## Consequences

Users have one source of truth. Shared engine and Catalog updates no longer
require merging upstream code into a user fork. The Installer needs an explicit
versioned World input contract before this model is operational. Until that
work lands, the template is a contract scaffold rather than a complete USB
workflow.
