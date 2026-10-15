# Engineering Standards

## Change shape

Keep public media metadata in the Catalog, shared execution behavior in the
Installer, and user-owned selection and policy in the World Playbook. The
current Installer-local composition remains a reference surface until external
World input is implemented. Avoid product-name branches in shared media paths.
A new entry using an existing contract changes data; a new source strategy or
profile adapter changes code and must have explicit success and rejection
coverage.

Shell entry points use `set -eu` or `set -euo pipefail` as appropriate,
resolve paths from their own location, quote expansions, use temporary files for
atomic replacement, and leave partial downloads or secret files removed by a
trap. Commands return nonzero on a rejected contract or incomplete operation.

JSON is the machine interface. Human output may be friendly, but downstream
automation must consume versioned fields rather than parse prose. IDs and
relative paths are validated before they become filesystem paths.

## Repository layout

- `collections/` contains the current reference selection, not vendor metadata;
  the final user choice belongs in the World Playbook.
- `usb-media/` owns the resolved media plan and physical USB assembly.
- `installer/` owns only the DNS Day-0 image and first-boot behavior.
- `management/` owns post-install orchestration from a trusted host.
- `build/locks/` records reviewed immutable external inputs.
- `inventory/local/`, generated media, caches, enrollment, and secrets remain
  ignored.
- `tests/` must not open a real block device or contact production services.

Do not put long-lived host configuration or an MCP gateway on the appliances.
Do not duplicate public Catalog entries under local entries merely to customize
selection.

## Contract changes

A contract change updates the producer, every repository consumer, fixtures,
rejection cases, and documentation in one pull request. Preserve existing
`schema_version` semantics; incompatible meaning requires a new version.

Stable entry IDs do not include the release version. Update `version`, URL,
filename, digest, and destination together. Never weaken path validation to
accept absolute paths, parent traversal, or duplicate destinations. Repository
bundles must not contain symlinks until resolved-target containment is enforced.

## Verification strategy

Use the smallest layer that proves the claim:

1. syntax and static contract checks;
2. isolated success and rejection simulations;
3. clean image build on the designated amd64 Debian builder;
4. disposable VM BIOS and UEFI installation;
5. one physical `dns01` pilot;
6. one-at-a-time expansion to `dns02` and `dns03`;
7. cluster, backup/restore, Tailscale, and router rollback drills.

A lower layer cannot mark a higher layer verified. Evidence records the exact
commit, source locks, commands, checksums, environment, and observed result.
Tests that require production credentials or real disks are never added to
ordinary CI.

## Review rules

Changes to destructive selection, secret handling, firewall policy, enrollment,
restore, or apply gates require focused human review. Pull requests describe
the failure mode being prevented and include a counter-case that must remain
rejected.

Generated artifacts are not committed. Release workflows upload verification
evidence only. Physical writes and router mutations remain manual,
target-specific operations.

