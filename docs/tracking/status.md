# Implementation Status

The current release state is a source-validated prototype, not a publicly distributable prebuilt installer or a physically qualified DNS installer. Built means the source path exists; verified names the highest evidence observed for this source. This repository carries no USB generations, failed-write records, or verification reports of its own: `burn-history/logs/` holds only its README files until a World created from this repository records its own physical writes. Evidence that a fork observed is recorded in that fork and is not evidence for this repository's `main`.

## Capability status

| Capability | Built | Highest verified state | Remaining work |
| --- | --- | --- | --- |
| One example `gujo-home` World with DNS assets, network, nodes, services, and two media passes | Yes | World contract simulation and plan resolution | Record a first verified physical generation in a World created from this repository |
| World-driven exact media selection | Yes | Isolated `inventory-capture` and `dns-install` resolution simulations | Physical HP boot and install from the `dns-install` USB |
| Public Catalog v2 for Proxmox VE, Proxmox Backup Server, TrueNAS SCALE, Pop!_OS, and Debian Live | Yes | Executable contracts, draft-2020-12 schema validation, and accepted/rejected source fixtures | Vendor-provenance archive and physical boot qualification per entry before use |
| Data-driven `locked-download` and `runtime-artifact` resolution | Yes | Isolated success and rejection simulations | A reviewed extension mechanism for any new source kind or profile adapter |
| HTTPS download with SHA-256 cache promotion | Yes | Source simulations | Clean online Linux preparation using the current pins |
| Nominal, offline, runtime-artifact, and read-only-device capacity calculation | Yes | Isolated tests | Exact result using the final rebuilt DNS ISO and target USB |
| Korean Ventoy presentation with no automatic timeout | Yes | Generated configuration checks | Physical BIOS and UEFI menu verification |
| Linux removable-device USB writer | Yes | Source simulation after target-resolution fix | Rebuilt disposable USB, readback, filesystem, BIOS, and UEFI evidence |
| Cross-platform exact-size raw-image builder and macOS MBR-last writer | Yes | Isolated builder and writer simulations | Physical write with full raw readback, then filesystem, payload, BIOS, and UEFI checks |
| Append-only World event and generation publication after verified write (USB records v2 and record validation) | Yes | Isolated recorder simulation, including failed-write records and schema validation | First physical generation published through the protected pull-request path |
| Offline Korean DNS appliance image with immutable locks | Yes | Source validation and ISO embedded-file readback logic; exactly-one-role build gate | Capture the three real inventories, then complete two clean amd64 Debian 13 builds and artifact comparison |
| Guided Debian Installer identity capture and target-specific consent | Yes | Guided and reviewed source simulations, including cancellation, incorrect consent, changed hardware or size, multiple disks, and USB, removable, mounted, or active-role targets | Guided VM BIOS and UEFI install, then a disposable physical `dns01` run |
| Personal-use, source-release, and prebuilt-release policy evaluation | Yes | Local allow/deny, DNS double-gate, obligation, checksum, schema, and writer-preflight simulations | Keep generated-artifact policy disabled; complete human exact-artifact review before any prebuilt proposal |
| Source-only release workflow | Yes | Source inspection and local repository contract prove a fixed non-executable evidence staging list with generated-media rejection | Verify the workflow on the designated builder without treating its evidence artifact as a public release |
| Protected prebuilt publication boundary | Policy only | Required Environment name and two-gate rule are encoded in policy and contracts | Human owner must create and verify `prebuilt-distribution` with a human-only required reviewer; no publishing job exists |
| Exact HP/NIC/internal-disk install gate with mapper ancestry resolution and swap, holder, and synchronization checks | Yes | Isolated source simulation of the current gate | Guided VM BIOS and UEFI install with the current gate, then disposable physical `dns01` run |
| Retry-safe encrypted first-boot enrollment | Yes | Source contract | Power-loss and real exFAT fault injection |
| Three-node Technitium cluster bootstrap | Yes | Fixture/source checks | Live three-node cluster and primary-loss drill |
| DNS health, saved immutable plan, and plan-bound apply | Yes | Isolated simulation of plan saving, immutability, hash, endpoint, commit, zone, drift, and replay rejection | Approved live canary apply and rollback; pull-request approval binding remains unbuilt |
| Encrypted backup collection and explicit restore | Yes | Source checks only | Add trusted-CA or pinned-fingerprint restore transport, then run isolated decrypt/import/canary drill; production restore is currently unqualified |
| One-off tagged Tailscale enrollment | Yes | Isolated tag/DNS/route/exit-node/SSH preference simulation | Tailnet policy review, explicit Serve/Funnel verification, three-node enrollment, reboot, and key-expiry/revocation observation |
| Dependency-free read-only status monitor | Yes | Python syntax and source inspection | Run from assembled USB against all three live nodes |
| Constrained MCP gateway over Tailscale-carried forced SSH | Yes | Isolated tool, input, and policy simulation | Add centralized credential-output filtering; then prove dedicated account, ACL, forced command, credential files, trusted CA, and live three-node reads |
| Router DHCP DNS cutover and rollback | Procedure only | No live evidence | Manual model-specific change after all node and recovery gates pass |

## Next dependency order

1. Obtain a successful GitHub `contracts` run and keep the release workflow evidence-only.
2. Build the fixed personal-use DNS ISO twice on amd64 Debian 13 and compare manifests and artifacts.
3. Pass disposable VM BIOS and UEFI installation with the mapper-backed installer-media fixtures represented.
4. Write and verify an `inventory-capture` USB, mount and inspect its filesystems and payload, then prove both firmware paths.
5. Enable only `dns01`, complete its physical install and enrollment, then repeat one at a time for `dns02` and `dns03`.
6. Prove cluster formation, trusted TLS, Tailscale restrictions, backup restore, and agent read access.
7. Perform router DHCP DNS cutover with a wired rollback client.
8. Publish each inspected physical USB event or generation through the protected pull-request path after the corresponding disposable write.

The GitHub check and protected Environment require repository-owner action. ISO, USB, firmware, installation, and network qualification require the supported Linux builder, disposable media, and physical HP access; source or documentation work cannot supply that evidence. None of those states grants public prebuilt redistribution approval.

## DNS installer image inputs

The DNS installer uses signed and checksummed amd64-only custom Debian Installer inputs instead of the Simple-CDD default installer selection, which requested a removed i386 installer for Debian 13. The image still needs a successful build and VM qualification for each source revision that changes its inputs.
