# 0004: Make the World Playbook the User Repository

- Status: Accepted
- Date: 2026-10-15

## Context

Directing ordinary users to fork the Installer mixed shared execution code with
user selection and policy. Directing them to fork the Catalog would also mix
private intent with reusable public metadata.

## Decision

The Gujo Homelab World Playbook is the only repository an ordinary user creates
from a GitHub template and manages. The Catalog remains shared public data. The
Installer remains a shared execution and safety engine. Catalog contributors
may still fork this repository for a normal pull-request workflow.

The World Playbook contract is currently a scaffold. Catalog documentation must
not claim that the Installer already consumes external World input.

## Consequences

Catalog entries stay independent of user hardware, private profiles, and USB
generation history. Ordinary users pin this Catalog through their World
Playbook rather than maintaining a Catalog or Installer fork.
