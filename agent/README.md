# Agent Gateway

The Agent Gateway exposes a constrained MCP tool set from a trusted management
host. It does not run on a DNS appliance and does not open an Internet-facing
HTTP endpoint. A remote MCP client launches the stdio server through ordinary
SSH carried by the Tailscale network.

## What the agent can do

- inspect the repository revision and dirty state;
- validate, plan, simulate, and calculate capacity for the selected World;
- check the configured LAN prefix, node reachability, and fixed outbound IP,
  DNS-resolution, and HTTPS probes;
- report the Tailscale state of only `dns01`, `dns02`, and `dns03`;
- read DNS health and produce a `home.arpa` plan with role-specific tokens;
- optionally apply the tracked zone through the existing `dnsctl` gates.

It cannot burn a USB, install an operating system, authorize a reinstall,
restore a node, mint enrollment credentials, execute arbitrary commands, read
arbitrary paths, or call arbitrary URLs.

## Install on the management host

Use Python 3.10 or newer and a dedicated virtual environment outside the
repository:

```sh
python3 -m venv /opt/device-os-agent/venv
/opt/device-os-agent/venv/bin/python -m pip install \
  --requirement /srv/diy-device-os-bootstrap/agent/requirements.lock
```

Configure only credential file paths. Keep the files readable by the dedicated
gateway account, inaccessible to group and other users, and outside Git:

```sh
export DEVICE_OS_AGENT_PYTHON=/opt/device-os-agent/venv/bin/python
export DEVICE_OS_AGENT_DNS_READER_TOKEN_FILE=/secure/dns/reader.token
export DEVICE_OS_AGENT_DNS_PLANNER_TOKEN_FILE=/secure/dns/planner.token
export DEVICE_OS_AGENT_DNS_APPLIER_TOKEN_FILE=/secure/dns/applier.token
export DEVICE_OS_AGENT_TECHNITIUM_CA_FILE=/secure/dns/technitium-ca.pem
export DEVICE_OS_AGENT_DNS01_URL=https://dns01:53443
export DEVICE_OS_AGENT_DNS02_URL=https://dns02:53443
export DEVICE_OS_AGENT_DNS03_URL=https://dns03:53443
```

When the Tailscale CLI is not installed on `PATH`, set its fixed absolute
executable path on the management host. This is useful for the macOS GUI app,
whose bundle executable must be invoked by its real path rather than through a
renamed symbolic link:

```sh
export DEVICE_OS_AGENT_TAILSCALE_COMMAND=/Applications/Tailscale.app/Contents/MacOS/Tailscale
```

The gateway supplies the minimal `SHLVL` compatibility value required by that
bundle executable while continuing to withhold the rest of the parent
environment from child commands.

Omit the applier token unless agent writes are intentionally enabled. Agent
apply rejects an absent or unreadable trusted CA file; it never permits
`dnsctl`'s bootstrap-only insecure TLS mode for writes. Apply is also disabled
until the host administrator sets:

```sh
export DEVICE_OS_AGENT_ALLOW_APPLY=1
```

Even then, a call must name the exact checked-out commit and supply this exact
target-specific phrase:

```text
APPLY home.arpa TO dns01 AT <full-commit-id>
```

The delegated `dnsctl` command independently requires its literal `APPLY`
confirmation, matching `HEAD`, and a clean tracked zone file.

## Local MCP connection

Point an MCP host at the following stdio command:

```text
/srv/diy-device-os-bootstrap/agent/run
```

The wrapper uses `DEVICE_OS_AGENT_PYTHON` when set and otherwise uses
`python3`.

## Remote connection through Tailscale

Do not forward a router port. Join the management host and the external MCP
client to the reviewed tailnet, permit only the client identity to reach the
management host's SSH port, and keep the appliance policy unchanged.
Merge the reviewed parts of
[`tailscale-policy.example.hujson`](tailscale-policy.example.hujson) into the
tailnet policy, then narrow its `src` from `autogroup:admin` if a dedicated
agent identity or group is available.

For a dedicated `device-agent` account, constrain its SSH public key to the
gateway command in `authorized_keys`:

```text
restrict,command="/srv/diy-device-os-bootstrap/agent/run" ssh-ed25519 AAAA... operator-agent
```

Then configure the remote MCP host to launch:

```json
{
  "mcpServers": {
    "device-os": {
      "command": "ssh",
      "args": ["-T", "device-agent@management-host"]
    }
  }
}
```

The SSH account environment must set the fixed Python, optional Tailscale
executable, and credential-file paths. Do not accept those values from the
remote client with `AcceptEnv`.
Use the Tailscale ACL and host firewall to reject non-tailnet SSH traffic.

This is ordinary OpenSSH transported over Tailscale. Tailscale SSH, Serve,
Funnel, advertised routes, and an exit node remain disabled on the DNS
appliances.

## Verification boundary

Run the isolated simulation after installing the locked dependencies:

```sh
/opt/device-os-agent/venv/bin/python agent/tests/gateway_simulation.py
```

The simulation verifies tool exposure and safety delegation. A live rollout
still requires a management-host Tailscale test, SSH forced-command test, DNS
reader/planner test, and a separately approved canary apply.
