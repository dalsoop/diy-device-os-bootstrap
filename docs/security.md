# Security

## Protected assets and trust boundaries

The protected assets are physical disks, removable media, the integrity of selected OS artifacts, DNS desired state, DNS administrative access, hardware identity, enrollment and recovery material, the operator's SSH and age private keys, Tailscale OAuth credentials, and the append-only evidence history.

World and Catalog input are not trusted execution authority. The Installer revalidates both before use and re-identifies a live target before any write. The writable USB data partition is transport, not a secret store: it is mounted `nodev,nosuid,noexec`, but it contains public hardware evidence and may carry only already-encrypted secrets, so it still requires controlled custody and disposal.

The management host is the control plane. DNS appliances serve DNS and narrowly scoped management traffic; they do not host the MCP gateway or long-lived orchestration state. The router remains DHCP authority and is changed manually under the current implementation.

## Authentication flows

### Human recovery access

1. The operator connects from an approved management source using the private key matching the public key embedded in the image.
2. SSH verifies the enrolled host-key fingerprint. A changed or unknown fingerprint stops access; it must not be bypassed with host-key checking disabled.
3. The `dns-operator` account may use passwordless sudo. Possession of its SSH private key is therefore equivalent to root and the key remains only on the management host.

Cockpit uses a per-node generated operator password recovered from the age-encrypted enrollment archive. Failure to recover or authenticate that password must not be worked around by enabling SSH password authentication.

### Technitium access

Bootstrap uses a unique per-node generated administrator password imported from encrypted enrollment. Cluster setup stops when any credential, certificate fingerprint, or API response is missing. Unverified TLS exists in cluster bootstrap and the current restore command; operators compare the enrolled fingerprint and install a trusted CA path before enabling agent writes. Because restore cannot yet accept that CA, it is not qualified for production use.

Routine DNS commands read a role-specific bearer token from a protected file and send it in a header. Tokens never appear in URLs, command arguments, Git, logs, or returned JSON. A missing, unreadable, rejected, or expired token fails the operation nonzero.

### Agent access

1. The remote client first authenticates to the reviewed Tailscale network.
2. Ordinary SSH authenticates a dedicated management-host account and restricts it with a forced command.
3. The forced command starts the MCP gateway over stdio; no HTTP listener, Tailscale Serve, Funnel, or router port is opened.
4. The gateway validates a fixed tool name and typed arguments, uses fixed credential-file paths and an explicit environment allowlist, and delegates to reviewed commands.
5. Any unknown tool, free-form command, arbitrary path or URL, invalid role, unavailable executable, or delegated command failure is rejected. Output above 64 KiB is truncated, not rejected, and the gateway does not scan delegated output for credentials.

The `dns_apply` tool is always discoverable but rejects every call unless the host administrator sets the explicit apply policy and provisions a separate applier-token file plus trusted CA file. An enabled call still requires a plan saved by `dns_plan`, a target-specific phrase naming that plan's SHA-256, and the delegated command's own checks, which reject target, commit, zone-file, and live-zone drift since that plan and replays.

### Tailscale appliance enrollment

Protected management-host OAuth files mint one distinct, pre-authorized, non-reusable key per node with a one-hour lifetime and `tag:dns-appliance`. Only that key is transferred over existing SSH; the remote temporary file is deleted. The command verifies hostname, tag, peer address, `accept-dns=false`, no advertised route, no exit-node behavior, and no Tailscale SSH. Deployment acceptance additionally requires a separate empty Serve/Funnel status check until that check is automated. The management command attempts immediate key revocation, but a failed revocation leaves a possible credential until its one-hour expiry and requires investigation.

## Authorization matrix

| Subject | Allowed | Required conditions | Explicitly forbidden |
| --- | --- | --- | --- |
| Human operator | Build, burn, install, enroll, restore, authorize reinstall, rotate credentials, change router | Live target review, exact command-specific confirmation, protected credentials, one-at-a-time physical procedure | Treating a plan/build as write permission; reusing stale target identity |
| `agent-dns-reader` | DNS health, zones, records, logs, statistics | Fixed node role and reader-token file | Planning writes, applying, identity administration, arbitrary API calls |
| `agent-dns-planner` | Reader actions and proposed DNS diff | Fixed role, planner-token file, Git-owned desired state | Applying a change or changing identities |
| `agent-dns-applier` | Apply an approved DNS zone change | Host apply policy enabled, applier token, trusted CA, exact commit, clean zone, exact confirmation | Bootstrap TLS, arbitrary records/URLs, user or token administration |
| `dns-backup` | Create and validate encrypted backups | Local protected token and configured age recipient | Plaintext export to removable media, restore, cluster administration |
| Status monitor | DNS UDP/TCP and fixed TCP reachability probes | Read-only fixed configuration; loopback listener by default | Authentication, repair, apply, shell execution |
| World/Catalog validators | Read and validate repository data | Safe contained paths and known schema versions | Network credentials, downloads from World code, block-device access |

The agent never receives physical media, OS installation, restore, reinstall authorization, enrollment, router mutation, arbitrary shell, arbitrary path, or arbitrary URL authority. Those absences are security boundaries, not missing convenience tools.

## Destructive authorization

A USB write accepts only a whole removable non-root device with a readable serial and sufficient capacity, followed by exact `ERASE <device> <serial>`. The target is inspected immediately before the write. A stale path or copied confirmation is invalid because device names may change after reconnect or reboot.

The DNS installer accepts only one enabled role matching HP product identity, system identity, NIC MAC, internal disk model and serial, and minimum size. It resolves mapper and partition ancestry to reject the installer USB. Removable, mounted, unresolved, installer-backed, zero-candidate, and multiple-candidate states fail before signature clearing or partitioning. A completed node also requires a token bound to its active generation and system UUID hash.

The isolated restore drill requires `RESTORE <exact-url>` and then canary verification. Production restore remains prohibited until the command authenticates TLS with a trusted CA or pinned fingerprint. DNS apply requires literal `APPLY` and the SHA-256 of one saved plan, and rejects target, commit, zone-file, and live-zone drift and replays. Confirmation never substitutes for target and state validation.

## Credential lifecycle

The repository contains only public SSH keys and public age recipients where explicitly required. Passwords, bearer tokens, OAuth secrets, SSH private keys, age identities, recovery plaintext, real inventory, generated enrollment, and signed/private URLs remain outside Git.

First boot creates operator and Technitium bootstrap passwords once and reuses them across retries until encrypted enrollment commits. The management host imports the archive with its age identity, transfers values into the principal secret store, rotates bootstrap credentials, and removes temporary plaintext. The age private identity never enters CI, an ISO, or a USB.

A root-only Technitium token exists locally for health and encrypted backup work. SSH host private-key escrow is disabled unless a new explicit decision authorizes it. A credential reaching Git, CI output, an image, logs, or plaintext USB content triggers stop, evidence preservation without value repetition, revocation or rotation, and repository-history and artifact audit.

Routine expiration is not imposed by this repository on externally owned long-lived credentials. The human administrator owns their lifecycle in the principal secret store and applies these event-driven rules:

| Credential or trust material | Creation and storage | Rotation or revocation trigger | Retirement proof |
| --- | --- | --- | --- |
| Operator SSH key | Generated outside the repository; private key remains on the management host, public key enters a reviewed image or host configuration | Suspected loss, operator change, or policy change | Remove the old public key from every node, verify old-key login fails, then destroy the private key copy |
| age identity | Generated and stored on the management host; only its recipient enters images | Suspected exposure or recipient-policy change | Use a new recipient for future generations; retain the old protected identity while any retained archive depends on it, then destroy it after those archives expire |
| Tailscale OAuth client | Created and revoked in the tailnet control plane; values live in protected management-host files | Suspected exposure, administrator change, or scope change | Revoke the old client in the provider, verify minting fails, replace protected files, and remove old copies |
| DNS reader, planner, and applier tokens | Created by cluster bootstrap and separated into protected files by role | Suspected exposure, role/permission change, node rebuild, or administrator change | Revoke the old Technitium token, verify its API call fails, distribute the replacement only to the matching role |
| Root-only health/backup token | Created on each appliance and readable only by root | Node rebuild, suspected host compromise, or backup-policy change | Revoke or replace locally and verify scheduled health/backup succeeds only with the replacement |
| Trusted Technitium CA | Public trust material stored at an administrator-fixed path | Certificate-authority rollover, certificate expiry, or compromise | Install and test the new chain before removing the old one; agent apply remains disabled if no trusted file is readable |
| Per-node bootstrap passwords | Generated once during first boot and transported only in age ciphertext | Immediately after successful import, and on any suspected exposure | Verify new login, disable or replace the bootstrap value, and remove temporary plaintext |
| One-off Tailscale node key | Minted per node with one-hour lifetime and non-reusable scope | Immediately after enrollment; expiry is the fallback when revocation fails | Delete the remote file, attempt provider revocation, and confirm no reusable key remains |

## Audit policy

Git commits, pull-request review, and required CI checks are the durable record for desired state, source locks, and configuration changes. World burn commands serialize physical attempts and record exact source identity, artifact digests, redacted target model and size, write/readback outcome, and timestamps without committing raw serials. Successful evidence is stored inside its immutable generation; failed and cancelled attempts use the separate append-only event tree under `burn-history/logs/usb/failed/`. The root writer never commits or pushes Git state.

`dnsctl` appends redacted JSONL for completed plan operations and apply API outcomes, with the saved plan's `plan_sha256`, and apply reads it to reject replays. Confirmation, hash, commit, dirty-zone, and transport failures can exit before an audit event; live-zone drift is recorded as `drifted`. The log does not prove that a plan was reviewed or a pull request approved.

Installation writes public enrollment evidence, sanitized install logs, `COMPLETE`, and the active generation pointer. Cluster bootstrap, Tailscale enrollment, backup collection, reinstall authorization, restore, and router work do not share a common audit ledger; operators capture protected session records when durable evidence is required.

## Network exposure

DNS UDP/TCP 53 is allowed from the approved LAN. SSH, Cockpit, metrics, and Technitium administration are limited to management sources; cluster traffic is limited to fixed peers. IPv6 follows an explicit reviewed policy, and an accidental wildcard listener is a failed verification.

Technitium recursion permits loopback, the configured LAN, and Tailscale IPv4 addresses (`100.64.0.0/10`). The firewall drops that source range outside `tailscale0` before established-connection or LAN rules; Tailscale authenticates peers, and the reviewed tailnet policy controls which peers may query UDP/TCP 53. This is a recursive resolver for those approved clients, not a public resolver. The Technitium web listener remains on loopback and the appliance LAN address; a tailnet firewall allowance alone does not make that listener available at a Tailscale address.

Tailscale appliances accept no DNS configuration, advertise no subnet route, provide no exit node, and expose no Tailscale SSH, Serve, or Funnel. The agent path uses a forced command on the management host rather than opening appliance or router ports.

If a wrong disk becomes writable, all media operations stop. The affected media is preserved, target-resolution logic and simulations are corrected, and disposable physical qualification repeats before any production node is enabled.

## Guided installation consent

Guided media embed disabled role network profiles, not enabled hardware inventories. The Debian Installer frontend captures identities locally and requires an exact role/disk/serial/byte-count erase phrase. No internal-disk write occurs in capture; partition preparation repeats exact identity and size checks and rejects additional eligible internal disks. Volatile confirmation is invalid after reboot or hardware replacement. Existing active-generation reinstall authorization remains mandatory. This consent is distinct from USB burn confirmation and does not authorize router or network cutover.

Mounted filesystem and swap checks resolve mapper/partition ancestry, and a source that does not resolve to exactly one physical parent (a `/dev/disk` alias, a multi-slave device, or a loop or MD device) fails closed; active block-device holders also block preparation. Image acceptance checks the generated BIOS and UEFI menus for disabled automatic timeouts. Simple-CDD numeric `BOOT_TIMEOUT=0` must not be used because it means immediate UEFI boot.
