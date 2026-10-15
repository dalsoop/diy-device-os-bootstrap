# 0001: Separate Media Bootstrap, Host State, and Secrets

- Status: Accepted
- Date: 2026-10-15

## Context

Installer media, continuously reconciled host configuration, and long-lived
secrets have different release cycles and failure modes. Combining them would
put generated artifacts and credentials near destructive installation code and
make the appliance depend on a management service.

## Decision

This repository owns media selection, Day-0 installation, first boot,
enrollment, and portable verification tools. Ongoing host configuration belongs
to the host-infrastructure system. Long-lived secrets belong to the principal
secret store. Agent gateways run on a management host, never on DNS appliances.

## Rejected alternatives

- One repository for installer, ongoing host state, and secrets was rejected
  because generated media and destructive code would share history and review
  scope with long-lived credentials.
- Running the agent gateway on every DNS appliance was rejected because DNS
  availability would depend on a larger management runtime and attack surface.
- Storing recovery material in the Installer was rejected because a public fork
  must remain safe to clone and review without secret-handling authority.

## Consequences

A complete workflow spans multiple systems, but each trust boundary is explicit.
The Installer can be public without publishing actual inventory or secrets.
Appliances continue to answer DNS if the management plane is unavailable.

