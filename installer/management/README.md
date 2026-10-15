# Agent management plane

The management plane is separate from the DNS appliances.

Implemented bootstrap and operating surfaces:

- `import-enrollment` decrypts completed USB records into a caller-selected
  protected directory; it never writes credentials into the repository.
- `cluster-bootstrap` initializes dns01, joins dns02/dns03, imports the catalog
  backed `home.arpa` zone, and emits an age-encrypted agent token bundle.
- `dnsctl health` uses the reader token.
- `dnsctl plan` emits current and desired hashes plus a human diff.
- `dnsctl apply` requires literal `--confirm APPLY`, a caller-supplied commit
  equal to current `HEAD`, and a clean zone file; it does not consume a saved
  plan or prove pull-request approval. Audit output is JSONL and contains no token.
- `collect-backups` retrieves only already-encrypted backup files over SSH.
- `restore-node` requires an explicit target URL, local age identity, and exact
  restore confirmation.
- `authorize-reinstall` creates a one-generation erase authorization after an
  explicit role confirmation.
- `network-preflight` verifies that the configured router prefix contains all
  three DNS addresses and reports current reachability.
- `tailscale-enroll` uses a management-host OAuth credential to mint a distinct
  one-off key for each selected node, sends the key over existing LAN SSH,
  deletes the remote temporary key file, attempts best-effort API revocation,
  and verifies hostname, `tag:dns-appliance`, address, and peer reachability.
  Failed revocation can leave the non-reusable key valid until its one-hour
  expiry. It never sends the OAuth secret to an appliance.
- `dns-appliance-status-monitor/start` launches a dependency-free Korean status
  page on `127.0.0.1:8080` and checks DNS over UDP/TCP plus Cockpit,
  Technitium, and node-exporter connectivity for all three nodes. It is
  read-only and is also copied onto the Gujo Homelab OS USB.

Before enrollment, merge the relevant parts of
`tailscale-policy.example.hujson` into the reviewed tailnet policy and create an
OAuth client with the `auth_keys` scope restricted to `tag:dns-appliance`.
Store the ID and secret outside this repository, one line per protected file:

```sh
TAILSCALE_OAUTH_CLIENT_ID_FILE=/secure/tailscale/client-id \
TAILSCALE_OAUTH_CLIENT_SECRET_FILE=/secure/tailscale/client-secret \
  management/tailscale-enroll --all
```

The nodes must already be reachable at `10.0.5.1` through `10.0.5.3` by the
operator SSH key. Enrollment requires Internet access to the Tailscale control
plane but does not change the appliances' local DNS resolver or routing role.

The MCP gateway source or deployment remains intentionally unvendored until its
dependencies, authentication boundaries, audit behavior, and destructive tool
gates are reviewed and pinned. It belongs on a management host, never on the DNS
appliances. Until then, `dnsctl` is the auditable apply boundary.
