# Agent Gateway

This module exposes a deliberately small MCP surface from a trusted management
host. It is an access plane, not a new source of desired state or execution
policy.

## Boundaries

- Delegate World operations to the root `device-os` command.
- Delegate DNS operations to reviewed commands under `installer/management/`.
- Never reproduce Installer logic, Catalog metadata, or World state here.
- Never expose USB burn, internal-disk installation, restore, reinstall
  authorization, enrollment, arbitrary shell, arbitrary path, or arbitrary URL
  tools.
- Keep stdio as the only transport. Remote access is ordinary SSH constrained
  to a Tailscale interface and a forced command on the management host.
- Do not run an MCP listener or long-lived gateway on a DNS appliance.

## Credentials and output

- Accept only paths to role-specific token files. Never accept token values as
  tool arguments or environment values.
- Forward an explicit environment allowlist to child processes.
- Accept a management-host Tailscale executable override only as an absolute,
  executable path fixed by the host administrator; never as a tool argument.
- Keep DNS reader, planner, and applier credentials separate.
- Require a readable trusted Technitium CA file before exposing an apply call;
  insecure bootstrap TLS is limited to read and plan compatibility.
- Redact or reject output that could expose credentials. Tokens must never
  appear in command arguments, URLs, logs, or MCP results.
- The apply tool is disabled unless the management-host administrator sets
  `DEVICE_OS_AGENT_ALLOW_APPLY=1`. It still requires a target-specific phrase,
  the exact checked-out commit, a clean tracked zone file, and `dnsctl`'s own
  confirmation gate.

## Verification

- Pin every Python dependency exactly in `requirements.lock`.
- Test the MCP tool inventory, command allowlist, environment allowlist,
  invalid-input rejection, default-disabled writes, and delegated apply gate.
- A passing simulation proves only the gateway contract. It does not prove
  Tailscale reachability, DNS API access, USB creation, or physical deployment.
