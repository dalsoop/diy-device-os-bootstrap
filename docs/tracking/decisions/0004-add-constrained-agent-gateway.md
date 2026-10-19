# 0004: Add a constrained management-host agent gateway

- Status: Accepted
- Date: 2026-10-16

## Context

External operators and coding agents need one consistent way to inspect the
World and operate the three DNS nodes. Publishing management HTTP ports or
giving an agent unrestricted SSH would collapse the repository's existing
execution and credential boundaries.

## Decision

Add a root `agent/` access plane that exposes a small MCP tool allowlist. The
gateway runs only on a trusted management host and uses MCP stdio. Remote
clients reach that stdio process through a forced ordinary-SSH command carried
over the reviewed Tailscale network.

The gateway delegates to the root `device-os` command and reviewed
`installer/management/` commands. It owns no desired state and reimplements no
Installer behavior. USB burn, operating-system installation, restore,
reinstall authorization, enrollment, arbitrary shell, arbitrary path, and
arbitrary URL capabilities are not exposed.

DNS writes are disabled by default. Enabling them requires management-host
policy, a separate applier-token file, a plan saved by `dns_plan`, a
target-specific phrase naming that plan's SHA-256, and the `dnsctl` apply
gate. (Amended: apply first named a commit; it now consumes a saved plan.)

## Consequences

- No new public listener or router port is required.
- Tailscale identity and SSH forced-command policy authenticate and constrain
  the remote transport.
- Role-specific secrets remain on the management host and are represented to
  the gateway only by fixed file paths.
- The MCP dependency set becomes reviewed repository input and is pinned
  exactly.
- Physical media and appliance qualification remain separate evidence gates.
