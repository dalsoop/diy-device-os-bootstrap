# Agent management plane

The management plane is separate from the DNS appliances.
Run command examples from the monorepo root.

Implemented bootstrap and operating surfaces:

- `import-enrollment` decrypts completed USB records into a caller-selected
  protected directory; it never writes credentials into the repository.
- `cluster-bootstrap` initializes dns01, joins dns02/dns03, imports the catalog
  backed `home.arpa` zone, and emits an age-encrypted agent token bundle.
- `dnsctl health` uses the reader token.
- `dnsctl plan <zone> [--out <plan-file>]` emits a schema version 2 plan with
  the target URL, source commit, zone path, and current and desired hashes,
  plus a human diff. `--out` requires a committed, unmodified zone, writes the
  plan once as a read-only file, refuses an existing path, and prints
  `plan_sha256` on stderr.
- `dnsctl apply --plan <plan-file> --plan-sha256 <sha256> --confirm APPLY`
  applies only that reviewed plan. It refuses a hash mismatch, another target
  URL, a different `HEAD`, a modified zone file, a live zone that drifted from
  the plan's current hash, and a plan that the audit log already records as
  applied. It does not prove pull-request approval. Audit output is JSONL,
  carries `plan_sha256`, and contains no token.
- `collect-backups` retrieves only already-encrypted backup files over SSH.
- `restore-node` requires an explicit target URL, local age identity, and exact
  restore confirmation.
- `authorize-reinstall` creates a one-generation erase authorization after an
  explicit role confirmation.
- `network-preflight` verifies that the configured router prefix contains all
  three DNS addresses, reports router and node reachability, and separately
  records the management host's default gateway. It also checks fixed outbound
  IP, DNS-resolution, and HTTPS probes. `--json` provides the versioned agent
  contract; `--offline` makes the skipped Internet check explicit rather than
  treating it as success.
- `tailscale-enroll` uses a management-host OAuth credential to mint a distinct
  one-off key for each selected node, sends the key over existing LAN SSH,
  deletes the remote temporary key file, attempts best-effort API revocation,
  and verifies hostname, `tag:dns-appliance`, address, and peer reachability.
  Failed revocation can leave the non-reusable key valid until its one-hour
  expiry. It never sends the OAuth secret to an appliance.
- `dns-appliance-status-monitor/start` launches a dependency-free Korean status
  page on `127.0.0.1:8080` and checks DNS over UDP/TCP plus Cockpit,
  Technitium, and node-exporter connectivity for all three nodes. It is
  read-only and is also copied onto the DIY Device OS USB.

Before enrollment, merge the relevant parts of
`tailscale-policy.example.hujson` into the reviewed tailnet policy and create an
OAuth client with the `auth_keys` scope restricted to `tag:dns-appliance`.
Store the ID and secret outside this repository, one line per protected file:

```sh
TAILSCALE_OAUTH_CLIENT_ID_FILE=/secure/tailscale/client-id \
TAILSCALE_OAUTH_CLIENT_SECRET_FILE=/secure/tailscale/client-secret \
  installer/management/tailscale-enroll --all
```

The nodes must already be reachable at `10.0.5.1` through `10.0.5.3` by the
operator SSH key. Enrollment requires Internet access to the Tailscale control
plane but does not change the appliances' local DNS resolver or routing role.

The reviewed MCP gateway now lives under [`../../agent`](../../agent). It runs
on a management host, reaches this module only through a fixed command
allowlist, and uses stdio through a Tailscale-constrained SSH forced command.
`dnsctl` remains the delegated apply and audit boundary; the gateway cannot
bypass its commit, clean-tree, confirmation, token, or TLS requirements. Set
`TECHNITIUM_CA_FILE` to make `dnsctl` verify a reviewed CA; the Agent Gateway
requires that mode for apply.
