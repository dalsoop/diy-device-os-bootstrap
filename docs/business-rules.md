# Business Rules

## World and ownership

`gujo-home` is the single mutable example World for one home's infrastructure. DNS is its first deployed service, not a repository or World boundary. Adding Proxmox, TrueNAS, desktops, storage, switches, or later services extends this World; it must not create a product-specific repository merely because a new device role appears.

A World draft expresses desired assets, networks, nodes, services, media, and policy. It may select only declared Catalog entries or reviewed Installer-local profiles. An unknown ID, duplicate ID, unresolved reference, duplicate static address, unreachable gateway, or policy weaker than the resolver accepts makes the World invalid; the system must not guess or silently drop the item.

World intent is declarative. Selecting media or enabling a role does not authorize a USB or internal disk write; live target inspection and exact confirmation remain separate decisions at execution time.

## Catalog and media selection

Public Catalog entries are reusable metadata. Their stable IDs survive release updates; a version update changes the release version, filename, URL, checksum, and destination together. Catalog inclusion makes an entry available but does not place it on a USB. The selected World media definition determines the exact ordered set.

Public entries are either interactive installers or live environments. Guarded unattended installation belongs only to an Installer-local profile with a separate target gate. A public Catalog entry must not gain unattended erasure semantics through menu selection or World policy.

The current World defines two media passes:

- `inventory-capture` selects only `debian-live` and must not contain the DNS installer or authorize internal-disk erasure.
- `dns-install` selects only `dns-appliance` and reserves the DNS enrollment partition required by that profile.

If no selected entry uses the DNS adapter, the DNS enrollment reserve is zero. If the DNS adapter is selected, the reserve is positive. A composition violating either side is invalid rather than automatically corrected.

Korean is the current World presentation language. It maps to the Korean Ventoy menu and the DNS installer's `ko_KR.UTF-8` locale while retaining the US keyboard map. General public installers remain interactive and may still present their own language choices.

## Capacity and artifact certainty

Capacity is calculated as the sum of verified selected artifact bytes, fixed partition reserves, and layout overhead. A runtime artifact contributes an exact size only when its supplied build manifest names the matching digest. A downloaded public artifact contributes an exact size only after its Catalog digest passes. Remote content-length probes are estimates.

If any selected artifact is unknown or unverified, final `required_bytes` and `fits` are indeterminate. The system must not turn an estimate into permission to write. It may report `fits: false` early only when already verified bytes plus fixed reserve and overhead meet or exceed the target.

## Physical USB generations

Every successful physical USB creation has identity `{YYYYMMDDHHmmss}-{world-slug}`. The timestamp is captured in `Asia/Seoul` when the resolved World and exact inputs are sealed immediately before the target-specific write. Draft creation time, file modification time, commit time, or a previous burn time must not be reused.

A generation becomes complete only when physical write and required readback verification succeed. A failed or cancelled write is an attempt, not a generation. Rewriting identical source intent creates a new generation because it represents a different physical event. An existing generation ID is a collision and must not be overwritten.

Completed generations are append-only evidence. They may be read and copied, but must not be edited, renamed, reformatted, or migrated in place. A corrected schema or changed fact creates another generation and leaves prior evidence intact.

Failed, cancelled, and recovered interrupted physical attempts receive separate append-only event records. Capacity queries, plans, and simulations are not physical attempts and create neither event nor generation records. Physical event execution is serialized so two connected devices cannot share a generation candidate or be written concurrently from one checkout.

## DNS appliance rules

The home DNS topology uses router `10.0.0.1` and nodes `dns01=10.0.5.1`, `dns02=10.0.5.2`, and `dns03=10.0.5.3` on one routed `10.0.0.0/16` LAN. A router still limited to `10.0.0.0/24` satisfies neither address reachability nor deployment readiness unless an explicit route reaches `10.0.5.0/24`.

Real inventory must be captured on each target and remains outside Git. An example inventory cannot authorize a write. For the first physical rollout, exactly one role is enabled; the next role remains disabled until the prior node passes firmware, internal-disk boot, identity, DNS UDP/TCP, host-management, certificate, time, and enrollment checks.

An installation may proceed only when exactly one enabled role matches the current HP identity, NIC, and internal disk. Zero matches, multiple matches, a removable disk, installer media, unresolved mapper ancestry, a mounted candidate, or identity mismatch stops before partitioning. A role with an active completed generation additionally requires reinstall authorization bound to that generation and system UUID hash.

Cluster formation follows three healthy standalone nodes. DNS desired-state changes apply one logical zone operation at a time and require a passing UDP and TCP canary before the next operation. Router DHCP advertises all three resolvers only after cluster and rollback checks; on cutover failure, previous DHCP DNS values are restored before appliance investigation.

## Evidence and release state

Source validation, image build, VM boot, physical USB write, firmware boot, OS installation, Tailscale enrollment, cluster formation, backup restore, and router cutover are distinct states. Evidence for one state never completes a later state.

A release candidate consists of exact source identities, source locks, manifests, checksums, package closure, SBOM, and observed gate results. Building it does not authorize publication, burning, or installation. If physical, network, or license evidence is incomplete, the candidate remains explicitly unqualified and generated images must not be represented as a finished release.

## Use and redistribution policy

The operator may prepare, build, and write personal media for the operator's own devices. Every current bootloader, public image, DNS component, and generated final artifact remains `personal-use-only`. Personal use, digest verification, successful CI, a completed build, SBOM generation, physical readback, or installation does not grant redistribution approval.

The current public release mode is source-only. Public release output is the tracked source snapshot and platform-generated source archives. The build workflow may upload non-executable verification evidence for review, but that Actions artifact is not a public media release and cannot contain generated ISO, RAW, IMG, disk-image, or complete USB content.

Review is exact-artifact work. A public bootloader or OS review is bound to its version, URL, and SHA-256 and records all license, notice, corresponding-source, and trademark evidence and obligations. The composite DNS ISO has two independent gates: every component must be reviewed, and the final ISO must have a separate review bound to the component registry and build manifest. Missing evidence, changed digests, unfulfilled files, or `NOASSERTION` deny a prebuilt release.

Generated-artifact distribution is disabled. Future publication requires a separately reviewed policy change, a successful `prebuilt-release` decision, and approval through the protected GitHub Environment `prebuilt-distribution` with a human-only required reviewer. There is no automatic promotion from personal build, source release, CI, or physical verification into public prebuilt publication.

## Agent authority

The agent may inspect repository state, validate and simulate the World, calculate capacity, inspect network and tunnel status, read DNS health, create a DNS plan, and perform a separately enabled DNS apply. It must not burn media, install an OS, authorize reinstall, enroll nodes, restore data, select arbitrary commands, select arbitrary filesystem paths, or call arbitrary URLs. A human remains the authority for physical erasure, installation, recovery, enrollment, and router changes.
