# Standards

## Repository workflow

- `main` MUST change through a pull request. The required `contracts` check MUST pass before merge; direct push, force-push, protection removal, and bypass merge are violations.
- Substantive work MUST occur on a branch. A change is not complete merely because it exists locally or CI started.
- Generated media, caches, work directories, local inventories, credentials, enrollment output, and recovery archives MUST remain untracked. A tracked sensitive or generated file fails review even when CI passes.
- The project license is GPL-3.0-only unless a file-specific notice says otherwise. Executable files MUST retain the repository SPDX copyright and license headers checked by CI.
- Repository documentation, examples, identifiers, and contributor-facing messages MUST remain in English. Korean is reserved for the current World's end-user menu and installer presentation unless an explicit product decision changes the documentation language.

## Documentation

These rules apply to every tracked text file: documentation, decision records, verification reports, USB records, comments, tests, and CI definitions.

- **Abstraction.** Repository text MUST name roles, never specific machines or people's environments. The roles are the build host (the designated amd64 Debian 13 builder), the VM host, the operator workstation, and the management host. Host names or labels of particular machines, machine model generations, personal home-directory paths, and machine-local tool installations MUST NOT appear. Example paths use placeholders or the project's own role accounts (`dns-operator`, `builder`).
- **Present state only.** Text MUST describe the current layout and behavior. It MUST NOT name previous locations, narrate what a path or behavior used to be, or carry compatibility notes or migration steps. Git history is the record of change.
- **Enforcement.** The documentation check in `engine/installer/tests/repository-contract.sh` runs in the required `contracts` job and scans every tracked text file. It rejects a whole word shaped like a machine host label (one lowercase letter, digits, one lowercase letter, digits, with at least one letter outside the hexadecimal range, so commit hashes and event IDs pass), a whole word shaped like a machine generation (capital `M` followed only by digits), any `/Users/` path followed by a name, and any `/home/` path whose account is not one of the two role accounts declared in the check. When legitimate text matches, rewrite the text; never widen the patterns or extend the allowlist.

## Module boundaries

- `burn-history/` is the only folder the user edits. Its `home.yaml`, `dns-records.zone`, and `os-installs/<role>/os.conf` are the desired state you edit; its `keys/`, `os-installs/<role>/hardware.conf`, and `.in-progress/` are private files never committed; its `logs/` records what happened, every file in it is tracked, tools publish it, and nobody edits it. It MUST NOT contain executables, schemas, or tests.
- `engine/world/` MAY resolve desired state and record evidence identity but MUST NOT implement downloads, execute Catalog code, or authorize a write.
- `engine/catalog/` MAY contain public declarative metadata and schemas but MUST NOT contain hooks, credentials, private profiles, collection policy, download execution, or disk behavior.
- `engine/installer/` MUST revalidate World and Catalog input before use and is the only module that MAY download, assemble, or write media. It MUST NOT become the long-lived secret store.
- `engine/agent/` MUST delegate to reviewed CLI surfaces and MUST NOT reimplement World, Catalog, Installer, or DNS policy. Its tool set MUST exclude physical write, install, restore, reinstall authorization, enrollment, arbitrary command, arbitrary path, and arbitrary URL operations.
- Router mutation MUST remain outside automated command and agent surfaces until a separately reviewed authenticated, reversible, model-specific mechanism and console recovery path exist.

## Contracts and inputs

- Machine-facing output MUST use versioned JSON or a documented filesystem record. Downstream automation MUST NOT parse human prose when a structured surface exists.
- IDs and configured relative paths MUST be validated before filesystem use. Absolute paths, empty segments, `.`, `..`, duplicate IDs, duplicate destinations, and unknown enum values MUST fail rather than normalize into acceptance.
- A contract change MUST update its producer, every repository consumer, schema representation, success fixture, rejection fixtures, and operator-facing contract in one pull request. Incompatible meaning requires a schema-version decision.
- Public media IDs MUST remain stable across releases. Version, filename, URL, digest, and destination MUST be reviewed as one update; moving tags, branches, or `latest` MUST NOT replace immutable release identity.
- Every resolved repository-bundle source MUST remain inside the checkout at staging time. A textual relative path is insufficient when its resolved target escapes the checkout.

## Source and dependency management

- External executable inputs MUST be pinned by exact release, dated snapshot, digest, or SHA-256 as appropriate. A warning-only verification mode is forbidden.
- Public downloads MUST use HTTPS and MUST be promoted from a temporary file only after the reviewed digest passes. Partial or failed downloads MUST be removed.
- Python dependencies for the agent gateway MUST remain exactly pinned in `engine/agent/requirements.lock`. The status monitor MUST remain Python-standard-library-only so it can run from assembled media without Internet access.
- Catalog checksum updates MUST include authoritative vendor provenance in pull-request evidence. Re-hashing the same downloaded file is not independent verification.

## Redistribution and release gates

- Personal self-build and media writing MAY be used for the operator's own devices, but `personal-use-only` MUST NOT be represented as redistribution approval.
- Public releases are source-only by default. Release automation MAY retain non-executable verification evidence, but MUST NOT upload ISO, RAW, IMG, disk-image, or complete USB content.
- Every reviewed public artifact MUST bind the review to its exact version, URL, and SHA-256 and record license, notice, corresponding-source, and trademark evidence plus obligation dispositions. A version, URL, or digest change invalidates the prior review.
- A DNS ISO requires both reviewed component closure and a separate final-artifact review bound to the ISO digest, component registry, build manifest, SBOM, and fulfilled obligation files. Neither review substitutes for the other, and `NOASSERTION` blocks public prebuilt distribution.
- No validator, build, CI, or release command MAY create or promote `redistribution-reviewed` status. A successful lower evidence state MUST NOT be promoted automatically.
- Future prebuilt publication MUST require both a successful `prebuilt-release` check and the protected GitHub Environment `prebuilt-distribution`, configured with a human-only required reviewer. The repository policy enabling generated-artifact distribution MUST change through a separate reviewed pull request.

## Destructive execution

- Planning, validation, simulation, capacity calculation, and Catalog verification MUST NOT write block devices or internal disks.
- A USB writer MUST inspect the current live device and accept only a removable, non-root, non-virtual target with a readable serial and sufficient capacity. Confirmation MUST equal `ERASE <device> <serial>` for that current inspection.
- World physical writes MUST be serialized. A successful write MUST publish exactly one immutable generation only after readback passes; a failed or cancelled write MUST publish only a redacted event record. Neither record may contain a raw serial, MAC address, UUID, credential, image, or recovery material.
- The DNS installer MUST resolve mapper and partition ancestry to a physical parent and MUST reject installer media, USB-backed targets, mounted targets, removable disks, unresolved devices, and zero or multiple candidates before any signature clearing or partitioning.
- General OS entries MUST remain interactive. Automatic boot timeout MUST remain disabled. Guarded unattended behavior MAY exist only in the DNS-local adapter behind exact hardware and reinstall gates.
- Restore MUST bind confirmation to the exact target URL. DNS apply MUST bind confirmation to `APPLY` and the SHA-256 of one saved plan whose source commit is the current commit, whose target is the current endpoint, and whose zone file is tracked and clean; these checks MUST NOT be replaced by agent-side assumptions.

## Change shape

- Shell entry points MUST fail nonzero on rejected or incomplete operations, quote expansions, resolve repository paths from their own location, and use temporary files plus atomic promotion for durable output.
- Known `source.kind` and `profile_adapter` values MUST drive shared media behavior. Adding a product-specific branch for an entry that fits an existing strategy is a structural violation.
- A new source kind or profile adapter MUST include fetch, verify, stage, success, unknown-value, unsafe-path, digest-failure, and cleanup coverage before it is accepted.
- Secrets MUST travel through protected files or headers, never command arguments, URLs, repository values, logs, or MCP results. Child processes receive only an explicit environment allowlist.

## Verification gates

Before merge, run the repository's `contracts` job surface: SPDX/license checks, the documentation check, shell syntax, ShellCheck, Python and Ruby syntax, World contract simulation with v2 USB record validation, Catalog verification and fixtures, draft-2020-12 JSON Schema validation with valid and rejected fixtures, DNS license simulation, license-policy simulation, all other Installer simulations, and Agent Gateway simulation. A failure in any required command blocks merge; removing or weakening a check is itself a security-sensitive change.

Before an image candidate, additionally verify immutable build locks, build twice on the designated amd64 Debian 13 builder when reproducibility is being claimed, and retain manifests, package closure, checksums, and SBOM.

Before physical rollout, pass disposable VM BIOS and UEFI installation, then one physical `dns01` pilot, then one-at-a-time `dns02` and `dns03`. CI or source inspection MUST NOT substitute for firmware, real disk identity, Secure Boot, power-loss, network, or restore evidence.
