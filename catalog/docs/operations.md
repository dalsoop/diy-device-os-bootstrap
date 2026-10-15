# Operations

## Prerequisites

Use a Unix-like checkout with Git, POSIX shell, jq, and ShellCheck. On
Debian/Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y git jq shellcheck
git clone https://github.com/dalsoop/gujo-homelab-os-playbook.git
cd gujo-homelab-os-playbook/catalog
```

Catalog operations do not require root after package installation and must not
download ISO images or access block devices.

## Add a public entry

1. Identify an authoritative, public, versioned vendor release.
2. Verify architecture, official HTTPS URL, filename, and SHA-256 independently.
3. Choose a stable ID without a release number.
4. Add one `catalog/entries/<id>.json` file using an existing group and public
   contract.
5. Register the same ID and path in `catalog/index.json`.
6. Run the repository contract gate and review the exact diff.
7. Open a pull request with checksum provenance and intended Installer use.

Do not download large media into the repository. Do not add private or guarded
profiles.

## Update a release

Keep the ID stable. Update version, filename, URL, SHA-256, and destination as a
single change. Confirm that descriptions and architecture still apply. Record
authoritative provenance in the pull request.

A vendor URL returning successfully is not enough. If an official checksum
cannot be confirmed, leave the existing entry unchanged and record the block.

## Update a bootloader

Treat a bootloader update as supply-chain critical because every assembled USB
depends on it. Update version, archive root, source filename, URL, and digest
together. Ensure the implementation remains supported by Installer consumers
before merge.

## Validate

```sh
bin/verify-catalog
tests/catalog-contract.sh
```

CI also checks shell syntax and ShellCheck. These operations are local,
data-only, and must not download images or access block devices.

## Publish and consume

Merging to `main` publishes a new Catalog commit. There is no mutable Catalog
release that automatically changes Installers. A Installer operator reviews the
commit range, pins the exact new commit, resolves the plan, and performs
download and physical verification separately.

## Correct a bad entry

Create a reviewed correction or removal immediately. Identify affected commit
IDs and notify known Installer consumers to repin. Do not rewrite public history
merely to make `main` look correct; pinned consumers need an explicit safe
replacement.

## Rollback

Catalog rollback means a Installer pins a previously reviewed safe commit or a
new correction commit. It does not mean deleting the Installer's recorded input.
Keep enough Git history and pull-request evidence to explain why a digest or
source changed.
