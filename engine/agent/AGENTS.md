# Agent Gateway

This module exposes a deliberately small MCP surface from a trusted management
host. It is an access plane, not a new source of desired state or execution
policy.

## Boundaries

- Delegate World operations to the root `device-os` command.
- Delegate DNS operations to reviewed commands under `engine/installer/management/`.
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
- Require a readable trusted Technitium CA file before permitting an apply call;
  the discoverable tool rejects execution without it.
- Delegated commands must keep tokens out of stdout and stderr. The gateway
  truncates at 64 KiB but does not content-redact, so tokens must never appear
  in command arguments, URLs, logs, or MCP results.
- The discoverable apply tool rejects execution unless the management-host administrator sets
  `DEVICE_OS_AGENT_ALLOW_APPLY=1`. It applies only a plan saved by `dns_plan`,
  named by its `plan_sha256` in a target-specific phrase, and `dnsctl` checks
  that plan again before writing.

## Verification

- Pin every Python dependency exactly in `requirements.lock`.
- Test the MCP tool inventory, command allowlist, environment allowlist,
  invalid-input rejection, default-disabled writes, and delegated apply gate.
- A passing simulation proves only the gateway contract. It does not prove
  Tailscale reachability, DNS API access, USB creation, or physical deployment.
