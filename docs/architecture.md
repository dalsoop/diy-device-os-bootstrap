# Architecture

## System boundary

DIY Device OS Bootstrap combines one user-owned infrastructure model with a reusable public operating-system catalog, a safety-critical media engine, and a constrained remote access plane. A single Git commit identifies all four source domains, but repository proximity does not collapse their trust boundaries.

```text
operator or remote agent
        |
        | root CLI, or MCP stdio through forced SSH over Tailscale
        v
burn-history/ desired state ----------------------+
        | validated media and policy               |
        v                                           |
engine/installer/ resolver and execution  <--- engine/catalog/ untrusted public metadata
        |                                           |
        +--> verified downloads and runtime image   |
        +--> target-checked physical USB            |
        +--> guarded DNS installation               |
        +--> management-host DNS operations         |
        |                                           |
        +--> burn-history/logs/usb/<generation>/ after verified write and readback

engine/agent/ delegates read, plan, and narrowly gated DNS operations to the same CLI surfaces;
it owns neither desired state nor destructive authority.
```

## Component map

| Component | Role | Receives | Produces | Must not own |
| --- | --- | --- | --- | --- |
| `burn-history/` | The home definition (desired state), private files never committed, and logs of what happened | Operator edits `home.yaml`, `dns-records.zone`, and `os-installs/<role>/os.conf`; private files never committed in `keys/`, `os-installs/<role>/hardware.conf`, and `.in-progress/` | Desired state for the World tools; records published by them | Executables, download behavior, target erasure, public vendor metadata, secrets |
| `engine/world/` | World resolver and USB event recorder | `burn-history/.paths.yaml` and registered paths | Validated media selection, safety policy, immutable generation records | Download behavior, target erasure, public vendor metadata, secrets |
| `engine/catalog/` | Data-only registry of public bootloaders and OS media | Reviewed vendor release facts | Indexed JSON metadata and schemas | Selection, executable hooks, downloads, private profiles, disk writes |
| `engine/installer/` | Resolver, image builder, media writer, DNS install gate, and management commands | Validated World, revalidated Catalog, local runtime artifacts, live device facts | Plans, verified cache, media, DNS appliance image, enrollment and operations | Long-lived secret storage or implicit destructive permission |
| `engine/agent/` | Management-host MCP access plane | Fixed tool arguments, fixed credential-file paths, delegated command output | Structured results clipped at 64 KiB without content redaction | Arbitrary execution, URL/path selection, media writes, installation, restore, enrollment |
| Principal secret store | External owner of long-lived credentials and private identities | Imported encrypted bootstrap output and rotated credentials | Protected files consumed by management operations | Repository source or removable-media history |
| Router and switch | Existing LAN transport and DHCP authority | Explicit human configuration | Reachability and client DNS advertisement | Repository-controlled mutation under the current implementation |
| GitHub and GitHub Actions | Source review, protected merge, source-level CI, and evidence-only candidate builds | Commits and pull requests | Required `contracts` result, source history, and non-executable verification evidence | Automatic prebuilt publication, secret storage, or hardware qualification |
| Build host (amd64 Debian 13) | Simple-CDD, Debian archive tooling, `xorriso`, `skopeo`, and Podman-compatible OCI inputs | Clean committed source, locks, public inputs, ignored real inventory | DNS ISO, manifest, package closure, checksums, and SBOM | Physical write authorization or long-lived credentials |
| Ventoy boot chain | Presents selected ISO entries on removable media | Verified bootloader archive, resolved menu, staged images | BIOS/UEFI boot menu | World selection, artifact trust, or unattended target authorization |
| Technitium and Tailscale | DNS runtime/cluster API and private management transport | Installed appliance state and management-host credentials | DNS service, cluster state, restricted overlay reachability | Repository policy or implicit agent authority |
| age | Encrypts enrollment, recovery, and access bundles to a public recipient | Public recipient in image; private identity on management host | Ciphertext safe for temporary USB transport | Long-lived key custody or plaintext persistence |
| Vendor and distribution endpoints | External artifact sources | Versioned HTTPS requests | Bootloader archives, OS images, packages, OCI image | Trust by availability alone; every consumed artifact remains digest-checked |

The root `device-os` command is the operator entry point. Ruby resolves World YAML; shell and `jq` resolve Catalog and media contracts; the guarded DNS image is assembled on amd64 Debian; Python provides the read-only status monitor and MCP gateway. These implementation choices sit behind versioned JSON and filesystem contracts rather than becoming cross-module imports.

## Media creation flow

1. The operator edits `burn-history/home.yaml` and selects a declared media definition.
2. `engine/world/bin/resolve-world` validates references, addresses, language, and fail-closed policy, then emits a versioned World plan.
3. The Installer independently validates that plan, revalidates every selected public or local entry, records the repository commit and Catalog tree, and calculates capacity.
4. `prepare` downloads only selected locked artifacts and promotes each cache file only after SHA-256 verification. The DNS image remains a separately built runtime artifact with its own manifest.
5. Immediately before `burn`, the writer inspects the live removable device, rejects root/internal/ambiguous/unresolved targets, binds confirmation to the current path and serial, stages the exact plan, writes the USB, and verifies the result.
6. The World event recorder serializes physical attempts, stores pending state under the ignored `burn-history/.in-progress/`, and atomically publishes a completed World generation only after write and readback succeed. Failed and cancelled attempts publish redacted event records but never generation directories.

No World field crosses the Installer boundary as erasure permission. No Catalog file crosses it as executable code. No successful plan or build crosses it as physical evidence.

## Distribution decision flow

1. The resolved media plan preserves the repository distribution policy and the exact redistribution status of the bootloader, public entries, local runtime artifact, DNS components, and final artifact.
2. Personal-use evaluation enumerates the complete selection, permits the operator's self-build, and reports unreviewed artifacts as warnings. It grants no redistribution authority.
3. Source-release evaluation permits only a clean tracked source snapshot. The candidate-build workflow stages a fixed list of non-executable manifests, checksums, package closure, component status, SBOM, and decision evidence; it never stages generated media or complete USB content.
4. Prebuilt evaluation is read-only and fails while generated-artifact policy is disabled. If policy is enabled in a future reviewed change, it still requires exact public-artifact reviews, complete DNS component review, a separate final DNS review, digest-bound SBOM and obligation files, and no `NOASSERTION`.
5. A future publishing job must receive both a successful prebuilt decision and approval from the protected GitHub Environment `prebuilt-distribution`, whose required reviewer is human-only. No source, build, CI, VM, USB, or installation state promotes itself into publication.

The current repository has no prebuilt publishing job. The policy evaluator cannot download, build, write media, upload, create reviewed records, or represent GitHub Environment approval.

## DNS deployment flow

The non-destructive `inventory-capture` media contains Debian Live and gathers exact identity for each HP computer. Reviewed local inventory enables one role at a time. The `dns-install` media then carries only the guarded offline DNS image; its install gate resolves the physical parent of mapper-backed installer media and accepts exactly one non-removable internal disk matching the enabled role.

First boot creates stable bootstrap credentials, installs the pinned Technitium runtime, records public evidence, encrypts recovery material to the operator's age recipient, and marks completion only after durable output succeeds. The management host imports and rotates that material, forms the three-node cluster, enrolls each node into Tailscale with a short-lived key, applies reviewed DNS state, collects encrypted backups, and performs explicit restore or reinstall operations. Router DHCP DNS changes occur only after all three nodes pass standalone and cluster checks.

## Remote agent flow

A remote MCP client reaches a dedicated management-host account through ordinary SSH carried over Tailscale. The account's forced command starts the gateway over stdio. The gateway validates a fixed typed tool call, constructs only an allowlisted command and environment, delegates to the root CLI or reviewed management command, clips output at 64 KiB, and returns structured data. It does not inspect delegated output for credentials, opens no network listener, and never runs on a DNS appliance.

## State locations

| State | Location and lifetime |
| --- | --- |
| Mutable desired state | `burn-history/home.yaml` |
| Private files never committed | ignored `burn-history/keys/` (except its README), `burn-history/os-installs/<role>/hardware.conf`, and `burn-history/.in-progress/` |
| Public metadata | reviewed `engine/catalog/data/` |
| Generated caches and workspaces | ignored `engine/installer/` paths (`artifacts/`, `cache/`, `work/`, Simple-CDD outputs); disposable |
| Release evidence | manifests, checksums, package closure, and SBOM outside committed media |
| Completed USB history | append-only `burn-history/logs/usb/<YYYYMMDDHHmmss>-gujo-home/` |
| Failed or cancelled USB writes | append-only `burn-history/logs/usb/failed/YYYY/` |
| Verification reports | `burn-history/logs/checks/` |
| Credentials and private identities | external principal secret store |
| Agent runtime policy | management-host files and environment outside Git |
