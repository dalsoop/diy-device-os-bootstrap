# Security

## Trust boundaries

The public Catalog and vendor download endpoints are external inputs. The
Installer trusts only an exact Catalog commit after local structural validation,
and trusts media only after SHA-256 verification. It never executes Catalog
scripts.

The writable exFAT partition is transport, not a security boundary. It is
mounted `nodev,nosuid,noexec`, and every secret is encrypted before the first
byte is written there. It also contains plaintext public enrollment evidence,
including raw hardware identifiers and sanitized logs, so the USB still
requires controlled custody and secure disposal.

The management host is the control plane. DNS appliances expose only DNS and
restricted host-management services. The router remains the DHCP authority.

## Secret handling

- Never place passwords, API tokens, OAuth credentials, private SSH keys, age
  identities, recovery archives, real inventory, or generated enrollment in Git.
- The installer embeds only an operator public SSH key and an age public
  recipient.
- The age private identity stays on the management host and never enters CI, an
  ISO, or a USB.
- Tailscale OAuth credentials stay in protected management-host files. Each node
  receives a distinct one-hour, non-reusable, pre-authorized key tagged
  `tag:dns-appliance`. The remote temporary file is deleted. The management
  command attempts immediate API revocation but suppresses revocation failure,
  so an unreconciled key may remain valid until its one-hour expiry.
- Generated operator and Technitium bootstrap passwords remain stable across
  first-boot retries, are exported only inside an age archive, and are rotated
  after import into the long-lived secret store.
- A root-only Technitium token exists only for local health and encrypted backup
  jobs. SSH host private-key escrow is disabled unless a separate decision
  authorizes it.
- Tokens travel in headers, never URLs, and audit records must not include token
  values.

## Destructive operations

The USB writer accepts only a removable non-root device with a readable serial,
sufficient capacity, and the exact phrase `ERASE <device> <serial>`.

The DNS installer accepts only one enabled role whose HP product identity,
serial/UUID, NIC MAC, disk model, disk serial, and minimum size all match.
Installer media, removable disks, an unresolved device, or multiple candidates
must fail before partitioning. A completed role also needs a token bound to its
current generation and system UUID hash.

Restore requires the exact target URL in `RESTORE <url>`. DNS apply requires
literal `APPLY`, a caller-supplied commit equal to `HEAD`, and a clean zone
file. The command does not prove review approval or consume a saved plan; those
remain operator gates. Confirmations are not substitutes for target inspection.

## Identities and privilege

| Identity | Allowed operations |
| --- | --- |
| `agent-dns-reader` | Health, zones, records, logs, and statistics |
| `agent-dns-planner` | Read state and produce a proposed diff |
| `agent-dns-applier` | Apply approved zone changes; no identity administration |
| `dns-backup` | Create and validate backups |
| `human-admin` | Emergency administration and credential rotation |

The `operator` account has passwordless sudo so key-based recovery remains
possible after a failed media workflow. Possession of its private key is
therefore equivalent to root. Compensating controls are public-key-only SSH,
management-source firewall restrictions, no private key on media, and host-key
fingerprint verification.

## Authentication paths and failure behavior

| Path | Credential and verification | Failure behavior |
| --- | --- | --- |
| Operator SSH | Operator private key on the management host; enrolled host-key fingerprint | SSH fails closed; do not bypass a changed fingerprint |
| Cockpit | Per-node generated `operator` password recovered through age | Login fails; do not enable SSH password authentication as a workaround |
| Technitium bootstrap | Per-node generated admin password imported from enrollment | Cluster bootstrap stops when a credential or API response is missing |
| DNS read/plan/apply | Role-specific bearer token read from a protected file | API failure exits nonzero; tokens stay out of URLs and audit records |
| Enrollment and restore decryption | Dedicated age identity on the management host | Decryption or archive validation failure stops import or restore |
| Tailscale control plane | Protected OAuth client files mint one temporary node key | Enrollment failure revokes the current key when possible and stops that node |

Technitium commands currently use TLS while allowing an unverified certificate
during bootstrap and restore. Operators must compare the enrolled certificate
fingerprint and complete trusted TLS configuration before enabling agent writes.

## Audit coverage

- Git commits and pull requests are the durable review record for desired state,
  source locks, and configuration changes.
- `dnsctl` appends redacted JSONL for completed plan operations and apply API
  outcomes. Confirmation, commit, dirty-zone, and transport failures can exit
  before an audit event is written. The log does not prove that a saved plan was
  reviewed or a pull request was approved.
- DNS installation writes `public.json`, a sanitized install log, `COMPLETE`,
  and `ACTIVE` to the enrollment partition; the host also retains install facts.
- The Gujo Homelab OS USB carries the resolved Catalog and checksum manifests,
  which record media inputs but not operator identity.
- Cluster bootstrap, Tailscale enrollment, backup collection, reinstall
  authorization, and restore primarily emit console output plus their resulting
  files or remote state. Capture operator-session logs when durable audit
  evidence is required; the commands do not create a common audit ledger.

## Network exposure

- DNS UDP/TCP 53 is allowed from the approved LAN.
- SSH, Cockpit, and metrics are limited to management sources.
- The Technitium API is limited to management sources and fixed cluster peers,
  and must use TLS before agent write access is enabled.
- Tailscale permits only approved DNS and management traffic on `tailscale0`.
  Appliances use `accept-dns=false`, advertise no routes, and provide no exit
  node, Serve, Funnel, or Tailscale SSH.
- IPv6 follows an explicit policy. An accidental wildcard IPv6 listener is a
  verification failure.

## Incident boundary

If a secret reaches Git, CI output, an image, or USB in plaintext, stop release
work, preserve evidence without repeating the value, revoke or rotate it, and
audit history before resuming. If a wrong disk becomes writable, stop all media
operations and do not retry until device-resolution logic and physical evidence
are reviewed.

