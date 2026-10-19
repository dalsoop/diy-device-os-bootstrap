# Security Boundaries

Repository proximity is not runtime trust. The Catalog remains data-only, the
World remains declarative intent, and only the Installer may perform execution
after its own validation and target checks.

The Agent Gateway runs on the trusted management host and delegates to those
existing execution boundaries. It provides MCP over stdio only. Remote access
uses a dedicated ordinary-SSH forced command over the reviewed Tailscale
network; no router port, public HTTP listener, Tailscale Serve, or Funnel is
required. The gateway does not expose USB burn, installation, restore,
reinstall authorization, enrollment, arbitrary shell, path, or URL tools.

Never commit credentials, private keys, age identities, raw hardware serials,
real inventory, generated images, enrollment records, or recovery archives.
The writable USB data partition is transport rather than a secret store; any
secret written there must already be encrypted.

Planning and simulation never write disks. A USB writer must reject internal,
root, virtual, unresolved, ambiguous, non-removable, or size-incompatible
targets and require an exact `ERASE <device> <serial>` confirmation. A World
selection is not authorization to erase that target.

Catalog files are validated as untrusted JSON and never executed. Public media
is promoted only after its reviewed SHA-256 matches. General installers remain
interactive, and DNS unattended installation retains its separate hardware,
inventory, disk, and reinstall-authorization gates.

Agent credentials are separate reader, planner, and applier token files outside
Git. Token values never enter MCP arguments, URLs, command arguments, or output.
DNS apply is host-disabled by default and, when enabled, still requires a
target-specific phrase naming one saved plan's SHA-256, and the delegated
`dnsctl` gate, which rejects drift since that plan and replays. The Agent Gateway additionally requires a trusted
Technitium CA file for writes and will not use bootstrap-only insecure TLS for
an apply call.
