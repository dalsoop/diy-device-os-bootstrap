# Contracts

## Common conventions

The repository exposes command-line, JSON, filesystem, and MCP interfaces. Usage errors, invalid input, rejected safety checks, failed downloads, and incomplete operations exit nonzero or return a tool error. Human prose is informational; automation consumes versioned JSON or documented files.

Stable IDs use lowercase ASCII letters, digits, and hyphens. Configured repository paths are relative, normalized, non-empty, contain no empty, `.` or `..` segment, and remain inside their declared root. Unknown enum values, duplicate identities, duplicate destinations, and ambiguous target state are errors rather than fallback cases.

## Operator CLI

`./device-os` is the public command entry point.

| Interface | Input | Output | Error cases and side effects |
| --- | --- | --- | --- |
| `world validate` | Optional `DEVICE_OS_WORLD` and `DEVICE_OS_MEDIA` | Human confirmation naming resolved World and media | Nonzero for invalid YAML, references, address topology, language, media, or policy; no network or write |
| `world available` | Selected World and optional media override | Human list of available and selected public/local entries | Nonzero for invalid World or Catalog; no download or write |
| `world plan` | Selected World and optional media override | Human summary; generated versioned World and media plans in the work area | Nonzero for dirty/unresolvable identities, contract mismatch, unsafe path, or unknown entry; no download or write |
| `world capacity` | `--capacity <decimal-or-binary-size>` or read-only target query; optional runtime artifact/manifest pairs and `--offline` | Human or schema-version-1 JSON totals, sources, unknown/unverified IDs, `required_bytes`, and `fits` | Nonzero for malformed arguments; unknown/unverified data yields null final fit, not assumed success; never writes |
| `world simulate` | Selected World and optional media override | Plan plus explicit skipped download/write phases | Same validation errors as plan; no download or write |
| `world prepare` | Selected World; network and cache access | Verified selected public artifacts in ignored cache | Nonzero on HTTPS, digest, path, or promotion failure; never writes a block device |
| `world readiness` | Ignored inventory, public key inputs, locked caches, and generated DNS artifacts | Schema-version-1 JSON with redacted passed checks and blockers | Nonzero while any required DNS build or artifact input is absent; never prints raw hardware identity or secret material |
| `world build-image` | Exact byte size, new output path inside the checkout, verified selected artifacts and manifests | Exact-size MBR raw image, SHA-256 sidecar, and image manifest binding the raw bytes to the resolved Catalog and World media | Linux requires root; macOS requires Podman or Docker and builds only through a loop device inside the Linux VM; never opens a host physical disk |
| `world burn` | Whole Linux device, exact `ERASE <device> <serial>`, selected artifacts and manifests | Assembled and readback-verified removable media plus one World event or generation record | Destructive after live removable/root/serial/capacity/artifact checks; any unresolved or mismatched state fails before write |
| `world burn-image-macos` | Absolute exact-size MBR image with adjacent manifest, whole `/dev/diskN`, exact target phrase | Two-phase raw readback plus one World event or generation record | Rejects a raw-image hash, Catalog digest, revision, tree, World slug, or media ID mismatch before inspecting or writing the target; physical events are serialized |
| `available`, `plan`, `capacity`, `simulate`, `prepare`, `burn` | Installer reference collection rather than the user World | Same shapes as corresponding World commands | Contributor surface; must not be represented as the user's desired state |
| `include <id>`, `exclude <id>` | Public Catalog ID | Updated reference collection and human confirmation | Nonzero for absent/invalid ID; changes contributor reference selection only |
| `burn-image-macos` | Absolute MBR raw-image path with adjacent manifest, resolved reference Catalog, whole `/dev/diskN`, exact target phrase | Two-phase write and readback result | Destructive only when image bytes and provenance match the resolved selection, image and device sizes match, and the target is external, writable, non-root, non-virtual, and MBR-compatible |
| `license check --mode personal-use --json` | Current resolved media and versioned distribution policy | Schema-version-1 allow/deny decision with every selected artifact and unreviewed warnings | Nonzero only for malformed or denied policy input; performs no network, build, write, or publication |
| `license check --mode source-release --json` | Clean tracked source snapshot and enabled source-release policy | Allows only the source snapshot; non-executable CI evidence is outside public release output | Nonzero for dirty tracked source or disabled source-release policy; accepts no generated-media attachment |
| `license check --mode prebuilt-release ... --json` | Absolute resolved Catalog, exact artifact/manifest/review bindings, and absolute release staging root | Read-only license, policy, digest, component, final-review, SBOM, and obligation decision | Nonzero for disabled policy, missing or unreviewed artifacts, digest mismatch, `NOASSERTION`, unsupported inspection, or unfulfilled obligations; GitHub Environment approval is separate and cannot be supplied to the CLI |

`targets` lists only live removable physical media and prints the current exact
confirmation. The macOS phrase is `ERASE <device> <media-name> <USB-serial>
<exact-bytes>`. The writer re-resolves every field, invalidates the first MiB,
writes and verifies the remaining bytes, then writes and verifies the first
MiB. It rejects GPT images and images at or below 1 MiB.

## World Playbook

`burn-history/.paths.yaml` uses API version `homelab.gujo.dev/v1alpha1` and kind `WorldPlaybook`. It lives in the user folder, and every path it registers is relative to that folder and must stay inside it. It declares `Asia/Seoul`, the draft `gujo-home` at `home.yaml`, the completed-generation root `logs/usb`, and generation format `{YYYYMMDDHHmmss}-{world-slug}`.

A draft World contains unique assets, networks, nodes, services, media definitions, one valid `defaultMedia`, and fail-closed policies. References resolve exactly once; static addresses are unique and belong to the referenced network; the gateway is directly reachable or has an explicit route. Supported presentation languages are `ko-KR` and `en-US`.

The resolver emits versioned JSON containing source paths, World identity, selected media ID, ordered entry IDs, language, and policy. When the Installer resolves media, the World order must exactly match the final entry order. A caller may choose another declared media ID but may not invent one.

The current `gujo-home` contract declares `inventory-capture=[debian-live]` and default `dns-install=[dns-appliance]`. A DNS media definition requires guarded unattended policy; every World requires exact hardware matching, one internal target disk, target-specific erase confirmation, and no automatic boot timeout.

## Catalog interfaces

`engine/catalog/data/index.json` uses `schema_version: 1` and is the closed-world registry. Every referenced JSON file exists, every controlled JSON file is registered, and IDs and paths are unique. `engine/catalog/bin/verify-catalog` exits zero only when the complete registry and semantic contract pass; it emits no media and changes no repository state.

A public media entry uses schema version 2 and provides stable ID, group, release version, optional architecture, safe `images/*.iso` destination, menu alias, non-empty Korean and English descriptions, interactive/live boot behavior, `profile_adapter: none`, a `locked-download` source, and mandatory redistribution metadata. The source contains a basename-only filename, HTTPS URL, and lowercase 64-character SHA-256. A bootloader also uses schema version 2 and provides stable identity, implementation, version, safe archive root, locked source, and redistribution metadata.

`personal-use-only` contains only its status. `redistribution-reviewed` binds the review to the record's exact version, source URL, and source SHA-256 and requires a reviewer, review date, all four evidence kinds, and exactly one disposition for each license-text, notices, corresponding-source, and trademark obligation. Changing the version, URL, or digest invalidates the review. Current records are personal-use-only.

Published schemas reject extra properties. CI validates every tracked Catalog record and explicit valid and invalid fixtures against the schemas. The executable jq validator and Installer consumer remain independent implementations, so schema coverage does not prove complete semantic parity for documents outside the tracked and simulated cases.

## Installer composition and resolved media plan

`engine/installer/usb-media/composition.json` uses `schema_version: 1` and names product/repository identity, Catalog path and index, bootloader ID, reference collection, local-entry registry, USB labels and reserves, and safe repository bundles.

The resolved media plan records the repository commit, Catalog tree, product, USB properties, one bootloader, groups, ordered public/local entries, and bundles. A World-driven plan embeds the validated World plan. Public and local registries may not expose the same ID; entry IDs, source filenames, and destinations are unique.

Supported entry behaviors are `interactive-installer`, `live-environment`, and local `guarded-unattended`. Supported source kinds are `locked-download` and caller-supplied `runtime-artifact`; supported adapters are `none` and `dns-appliance`. A runtime artifact uses an absolute caller path and matching manifest whose digest names that exact artifact. Unknown kinds or adapters fail.

Repository bundles use `repository-file` or `repository-tree` with contained source and destination paths. Because current staging can follow symlinks without resolved-target containment, a tracked bundle containing any symlink is outside the accepted contract.

## Capacity JSON

Schema version 1 reports each selected entry's size and source, verified total, estimated total, fixed reserve, layout overhead, unknown IDs, unverified IDs, target capacity, `required_bytes`, and `fits`. Decimal units such as `16GB` and binary units such as `16GiB` are accepted. Remote header or one-byte probes are estimates. Exact final fit exists only when every selected artifact is locally verified.

## USB filesystem result

The data partition label is `DEVICE-OS`. It contains staged images, bundles, Ventoy configuration, resolved media metadata and digest, image checksums, guides, tools, project license, license history, third-party notices, source revision/archive information, and `manifests/LICENSES.SHA256`.

When the DNS adapter is selected, a separate FAT32 `DNS-ENROLL` partition stores public enrollment evidence, encrypted recovery generations, active pointers, and reinstall authorizations. FAT32 is readable by the signed Debian Installer kernel's FAT modules; exFAT is unsupported at this stage. Files must remain below FAT32's 4 GiB per-file limit. It is transport, not the long-lived secret store. The Ventoy `DEVICE-OS` data partition remains exFAT.

A completed personal World generation contains immutable `world.yaml`, `world.lock.json`, `media-manifest.json`, `verification.json`, and `event.json`. The event recorder seals `{YYYYMMDDHHmmss}-{world-slug}` before invoking the target-specific writer, requires the writer's schema-version-1 redacted write evidence with passed readback and a device that equals the requested target, publishes `event.json` and `verification.json` at schema version 2 without the device path, then atomically renames the staged directory into `burn-history/logs/usb/`. It excludes images, caches, credentials, private keys, raw serials, MAC addresses, UUIDs, and recovery material.

The recorder holds one checkout-local lock across each physical write. Failed, cancelled, and recovered interrupted attempts never create a generation; they publish schema-version-2 records without the device path under `burn-history/logs/usb/failed/YYYY/{event-id}.json`. The required check validates every published record against `engine/world/schemas/usb-event.schema.json` and `usb-verification.schema.json`. A successful event lives inside its generation. Simulations, plans, builds, and capacity checks create no event. Git commits and pushes remain an explicit pull-request workflow rather than a side effect of the root writer.

## DNS enrollment record

Appliance SSH and Cockpit use the `dns-operator` account. The encrypted
`secrets/operator-password` filename remains the recovery credential key.

`public.json` uses schema version 1 and records generation UUID, hostname, role, fixed address, hardware identity, installer build and image digest, public SSH and certificate fingerprints, service health, and completion time. It never contains a password, token, or private key.

A generation is complete only when `public.json`, `recovery.tar.age`, the sanitized install log, and `COMPLETE` exist and the role's `ACTIVE` pointer names that generation. Reinstall authorization names the same active generation and matching system UUID hash; an authorization for an older generation is invalid.

## DNS management commands

`engine/installer/management/network-preflight --json <router-cidr>` returns schema-version-1 topology, LAN reachability, optional outbound IP/DNS/HTTPS probes, phase gates, and blockers. `--offline` reports Internet readiness as unknown. It does not establish DNS health or installation evidence.

`dnsctl health` reads a fixed node. `dnsctl plan <zone-file> [--out <plan-file>]` prints a plan and a human diff. The plan is a JSON object with `schema_version` 2, `created_at`, `zone`, `target_url`, `source_commit`, `zone_path` (relative to the Git work tree), `current_sha256`, `desired_sha256`, and `changed`; `source_commit` and `zone_path` are null when the zone file is untracked or modified. `--out` requires a committed, unmodified zone, saves the object once with mode 0444 through a hard link that never replaces an existing name, and prints `dnsctl: plan_sha256=<sha256>` on stderr.

`dnsctl apply --plan <plan-file> --plan-sha256 <sha256> --confirm APPLY` hashes one private copy of the plan and writes only when all of these hold: the hash matches; the plan is a saved schema-version-2 plan; `TECHNITIUM_URL` equals `target_url`; `HEAD` equals `source_commit`; the zone file is tracked, unmodified, and hashes to `desired_sha256`; the live zone still hashes to `current_sha256`; and the audit log has no successful apply of the same `plan_sha256`. A plan with `changed` false returns `{"status":"unchanged"}` without writing. Success prints `{status, plan_sha256, response}`. The command returns nonzero for authentication, TLS, state, drift, replay, or API failure and appends redacted audit JSONL, carrying `plan_sha256` for saved plans, for completed plan/apply outcomes and live-zone drift. It does not prove pull-request approval or require unrelated checkout files to be clean.

Restore requires an explicit target URL and `RESTORE <exact-url>`, decrypts and validates the archive locally, then currently sends the token and backup with TLS certificate verification disabled. That interface is limited to isolated recovery drills and is not a production-qualified restore path. Backup collection accepts only encrypted outputs. Tailscale enrollment accepts protected OAuth credential-file paths, not credential values, and creates one short-lived node key at a time.

## Image and inventory commands

| Interface | Input | Output and side effects | Error cases |
| --- | --- | --- | --- |
| `engine/installer/build/verify-locks` | Reviewed `engine/installer/build/locks/sources.env` | Prints `source locks: valid`; changes nothing | Nonzero for moving or malformed Debian/Tailscale URLs, malformed versions, timestamps, hashes, or OCI digests |
| `engine/installer/dns-image/fetch-locked-sources` | Network access and optional ignored cache path | Downloads Technitium OCI, Tailscale archive, and dependency-license report to temporary files; atomically promotes only verified content; prints checksums | Nonzero for missing tools, network/TLS failure, remote or cached digest mismatch, or license-report mismatch; partial files are removed |
| `sh engine/installer/dns-image/refresh-guided-iso <base.iso> <output.iso>` | Existing guided ISO and current checkout's guided preseed/scripts/templates; Linux with xorriso | Disposable iteration ISO with five guided files refreshed; verifies embedded bytes, BIOS/UEFI menus and disabled automatic boot; prints SHA-256; no release manifest | Nonzero for non-guided base, missing tools/files, output collision, failed ISO replay, stale embedded file, or enabled boot timeout; candidate cannot satisfy World runtime-artifact manifest checks |
| `engine/installer/dns-image/capture-inventory <role> <address> <interface> <whole-disk>` | One fixed DNS role, address, existing NIC, and whole block device on the target HP | Writes a shell-format inventory record to stdout with hashed hardware identities and `destructive_install_enabled=false`; does not modify the disk | Exit 2 for wrong arguments/role; nonzero for absent NIC/disk, a partition instead of whole disk, unreadable/empty identity, or missing SHA-256 tool |
| `engine/installer/dns-image/build-image` | Clean committed source; amd64 Debian 13; exact Simple-CDD version; verified caches; reviewed mode: three inventories and exactly one enabled role; guided mode: three disabled network profiles; operator public keys; age recipient | Builds ISO under `engine/installer/dns-image/simple-cdd/images/`; verifies critical embedded files; writes checksums, build manifest, package lists, package hashes, and SPDX SBOM under the configured artifact directory | Nonzero for unsupported host, dirty source, missing/malformed public input, anything other than one enabled role, lock/cache mismatch, build failure, stale embedded content, or missing artifact |

`DNS_APPLIANCE_INSTALL_MODE=reviewed` is the default and requires exactly one enabled embedded inventory, read from `burn-history/os-installs/<role>/hardware.conf`. `guided` uses the disabled network profiles `burn-history/os-installs/<role>/os.conf`. `DNS_APPLIANCE_INVENTORY_DIR` replaces `burn-history/os-installs` as the directory that holds the per-role folders in both modes. Both modes install Debian OS and the offline DNS payload together. The embedded `install-mode` and manifest `install_mode` name the selected mode; a missing mode means `reviewed`, and unknown modes fail.

In guided mode, Debian Installer's debconf frontend asks for role and wired physical NIC, captures local DMI/NIC/disk hashes into `/run/dns-appliance/inventory`, and displays the address, gateway, disk model, serial and exact byte count. It requires `ERASE <role> /dev/<disk> <serial> <bytes>`. Capture never writes the internal disk. The `select-disk` phase rechecks the captured hardware, disk path and exact size, single eligible internal disk, installer ancestry, mounted state, confirmation and active-generation reinstall authorization before signature clearing. An additional internal disk blocks guided installation even when its identity differs. Runtime inventory and confirmation are volatile and are never embedded or committed.

A build does not authorize media or internal-disk writing. Its manifest is paired with the DNS runtime artifact during capacity and burn. `check-readiness` uses the same mode environment and rejects a mismatched ISO manifest. Guided mode removes the separate capture/rebuild round trip; it does not establish VM or physical installation proof.

Capture, the inventory wizard and the install gate use the same read-only `disk-identity` adapter, bundled beside the capture tools and the ISO gate. Kernel model/serial attributes are preferred; SATA serials may come from `ata_id --export` on the exact candidate block device. Failed, empty or ambiguous identity evidence is rejected, and the serial is re-read before disk preparation.

## DNS redistribution records

The DNS component registry is schema version 1 and contains exactly the Debian package closure, Technitium OCI archive, Tailscale archive, Tailscale dependency report, and repository source snapshot. Each component binds a stable ID and immutable version to the SHA-256 of the exact bytes or closure manifest used by the build. Technitium additionally binds its OCI manifest digest. Current component redistribution states are personal-use-only.

A reviewed component record binds reviewer evidence and obligation dispositions to the exact component ID, version, digest, and, for Technitium, OCI source identity. The build manifest preserves the final ISO digest, component registry digest, policy digest, component statuses, SBOM digest, exact source locks, and repository source identity. Build tooling records evidence but cannot create reviewed status.

A DNS final review record is separate from component review. It binds the final ISO SHA-256 to the exact component registry and build manifest digests and records all four evidence and obligation classes. Prebuilt evaluation requires both fully reviewed components and this final record, verifies the bound SBOM and staged obligation files, and rejects `NOASSERTION`. Missing or mismatched evidence fails closed.

The repository-wide distribution policy enables source release and disables generated-artifact and prebuilt release. Even after a future successful CLI decision, publication must independently pass the protected GitHub Environment `prebuilt-distribution` with a human-only required reviewer. The CLI has no Environment-approval input and performs no upload.

## Post-install management interfaces

| Interface | Input | Output and side effects | Error cases |
| --- | --- | --- | --- |
| `network-preflight [--json] [--offline] [ROUTER_CIDR]` | One IPv4 router interface, default `10.0.0.1/16` | Human text or schema-version-1 JSON for topology, route observation, router/node reachability, optional fixed Internet probes, phase gates, and blockers; no state change | Exit 2 for bad options/multiple CIDRs; nonzero for invalid IPv4 or a prefix that excludes fixed DNS nodes |
| `import-enrollment --enrollment <mount> --identity <age-key> --output <dir>` | Complete `ACTIVE` records for all roles and readable age identity | Validates public health, decrypts each recovery archive into temporary storage, installs role credentials with restrictive permissions, and removes plaintext temporary data | Nonzero for incomplete/malformed records, failed health assertions, decryption/archive failure, or missing secret files |
| `cluster-bootstrap` | Protected credentials directory and output path; optional age recipient, cluster domain, and zone | Creates or joins the three-node cluster, creates least-privilege DNS identities, applies `home.arpa`, proves canary resolution, and atomically emits one encrypted access bundle | Nonzero for missing credentials, existing output, invalid recipient, API/TLS/cluster/permission/zone/canary failure; bootstrap currently uses unverified TLS |
| `tailscale-enroll (--all|--role <role>)` | Protected OAuth files, optional fixed tag and SSH user | Mints one non-reusable one-hour key, transfers it over existing SSH, enrolls one node, deletes the remote file, attempts revocation, and verifies implemented tag/address/DNS/route/exit-node/SSH preferences | Exit 2 for bad role/options; nonzero for credential format, API, SSH, enrollment, preference, or reachability failure; revocation failure is best-effort and Serve/Funnel require separate inspection |
| `collect-backups <protected-dir>` | Destination directory and key-based operator SSH | Copies only `*.zip.age` from all three nodes without overwriting existing files; creates mode-0700 role directories | Exit 2 without destination; nonzero for SSH/rsync failure or any zero-byte encrypted file |
| `restore-node --url <origin> --token-file <file> --backup <age-file> --identity <age-key> --confirm 'RESTORE <origin>'` | Exact endpoint, protected token and identity, encrypted backup, exact confirmation | Decrypts to a mode-protected temporary ZIP, validates it, submits restore, removes plaintext, and reports API acceptance | Exit 2 for missing input; nonzero for confirmation, decryption, ZIP, transport, or API failure; TLS verification is disabled, so this is isolated-drill-only |
| `authorize-reinstall --enrollment <mount> --role <role> --confirm 'ERASE <role>'` | One completed active record and exact role confirmation | Hashes the active system UUID and atomically writes `<role>.allow` bound to the previous generation | Exit 2 for bad input/role; nonzero for missing active/public record, wrong confirmation, or hashing failure |

## Read-only status monitor

`engine/installer/management/dns-appliance-status-monitor/start` accepts server arguments after requiring Python 3. `--config <json>` is required by the Python entry point; the wrapper supplies its bundled config. `--listen` defaults to `127.0.0.1`, `--port` to `8080`, and `--check-once` prints a JSON array instead of listening.

The configuration contains at least one node with `name`, IPv4 `address`, and DNS `query`. Invalid JSON, an empty node set, a missing field, invalid address, invalid DNS label, unavailable bind address, or occupied port terminates nonzero. Probe failures are returned as `ok:false` status data and do not trigger mutation.

In server mode, `GET /` and `GET /index.html` return UTF-8 HTML with `Cache-Control: no-store`; every other path returns 404. Each refresh probes DNS UDP/TCP 53 and TCP reachability for Cockpit 9090, Technitium 53443, and metrics 9100. There is no authentication or write endpoint, so a non-loopback `--listen` requires separately managed access control.

## Agent Gateway

The gateway is accessed through MCP stdio locally or a management-host forced SSH command over Tailscale. Every tool returns structured output or a tool error. Output is clipped at 64 KiB but is not content-redacted, so delegated commands must keep credentials out of stdout and stderr.

| Tool | Input | Output | Error and authority boundary |
| --- | --- | --- | --- |
| `repository_status` | None | Revision, branch, dirty-file list | Local read only |
| `world_validate` | Optional `dns-install` or `inventory-capture` | Delegated validation result | Rejects other media; no download/write |
| `world_plan` | Optional media | Delegated selected plan | No download/write |
| `world_simulate` | Optional media | Delegated skipped-phase simulation | No download/write |
| `world_capacity` | Capacity string, network-probe boolean, optional media | Delegated capacity JSON | Network probes default off; no write |
| `network_preflight` | Router CIDR and Internet-check boolean | Topology/reachability JSON | Fixed probes only; no repair |
| `tunnel_status` | None | Management host and `dns01`–`dns03` Tailscale state | Uses only administrator-fixed executable path |
| `dns_health` | `dns01`, `dns02`, or `dns03` | Delegated health JSON | Reader credential only; fixed node URLs |
| `dns_plan` | One fixed role | Delegated plan plus `plan_sha256`; the plan is saved read-only as `$DEVICE_OS_AGENT_STATE_DIR/dns-plans/<plan_sha256>.json` | Planner credential only; no apply |
| `dns_apply` | Fixed role, lowercase 64-character `plan_sha256` of a plan saved by `dns_plan`, exact `APPLY home.arpa TO <role> PLAN <plan_sha256>` | Delegated apply result | Always discoverable but rejects calls unless host policy is enabled; rejects an unknown plan; requires applier token and trusted CA plus all `dnsctl` gates |

There is no gateway interface for USB burn, OS installation, restore, reinstall authorization, enrollment, router mutation, arbitrary shell, arbitrary path, arbitrary URL, or raw credential input.

`install-gate validate-profile <file> <role>` validates unique fields, required values, IPv4 ranges, prefix/netmask agreement, LAN membership, gateway reachability, management subnet containment and safe domain fields without reading hardware or writing disks. Image build, readiness and guided capture share this validator.

`fetch-debian-installer` fetches the locked Debian snapshot Release/signature and installer checksums, verifies Debian archive signatures and the entire digest chain, then atomically promotes the six required amd64 text/graphical installer files into the ignored cache. Existing mismatched components fail rather than being silently replaced. Temporary verification/download files are removed after success or failure. This is an input preparation operation, never disk-write authority.
