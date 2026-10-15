# Contracts

## Command surface

`device-os` supports:

| Command | State change |
| --- | --- |
| `available` | Reads/resolves Catalog and prints selection state |
| `include <id>` | Adds a valid public ID to the collection |
| `exclude <id>` | Removes an ID from the collection |
| `plan` | Resolves and prints the intended media |
| `capacity [options]` | Calculates selected media, reserve, overhead, and target fit without writing |
| `simulate` | Runs resolution and reports skipped download/write phases |
| `prepare` | Downloads and verifies locked public artifacts |
| `write ...` | Destructively assembles the confirmed removable USB |
| `write-image-macos ...` | Destructively writes a confirmed, size-matched removable disk from an MBR raw image |

Usage errors exit nonzero. A rejected contract, digest, device, or confirmation
exits nonzero. Success output is human-facing; JSON files are the automation
surface.

`write-image-macos` requires an MBR image larger than 1 MiB whose byte size
equals the target. It rejects GPT, internal, virtual, non-removable, and
non-writable targets before the first write. After exact confirmation, it
invalidates the old first MiB, writes and reads back the remaining bytes, then
writes and reads back the first MiB. This ordering prevents macOS from mounting
the new filesystems before their image bytes have been verified.

`capacity` accepts decimal sizes such as `16GB`, binary sizes such as
`16GiB`, or a read-only device query. A local locked download is exact only
after its Catalog SHA-256 passes. A runtime artifact is exact only when its
supplied manifest digest matches. Remote header/one-byte sizes are estimates,
never final fit evidence. `--offline` disables network probes. Unknown or
unverified artifacts make `required_bytes` and `fits` null instead of
assuming they fit. The only early `fits: false` result is when verified files
plus fixed reserve and overhead already meet or exceed the target. `--json`
emits schema version 1 with per-entry size source, separate verified and
estimated totals, fixed reserve, overhead, unknown and unverified entry IDs,
and target results.

## Composition contract

`usb-media/composition.json` has `schema_version: 1` and owns:

- product name and repository;
- Catalog HTTPS Git URL, exact 40-character revision, index, and bootloader ID;
- one collection path;
- zero or more safe relative local-entry paths;
- USB data/enrollment labels and capacity reserves;
- safe relative repository-file or repository-tree bundles.

Paths must be relative, normalized, non-empty, and free of `.` and `..`
segments. Catalog code is never part of the contract.

## Collection and resolved plan

The collection has a stable ID, display name, unique groups, and unique selected
entry IDs. Group paths and IDs are unique.

The resolver emits a versioned plan containing product, pinned Catalog identity,
USB properties, one bootloader, groups, selected public plus local entries, and
bundles. Entry IDs and destinations are unique. Every entry destination belongs
to its declared group.

The current entry contract accepts:

| Field | Constraint |
| --- | --- |
| `id` | lowercase letters, digits, and hyphens; stable across releases |
| `group` | an existing collection group |
| `destination` | safe relative `images/...iso` path |
| `menu_alias` | non-empty human label |
| descriptions | non-empty Korean and English strings |
| `boot_behavior` | guarded unattended, interactive installer, or live environment |
| `profile_adapter` | `none` or `dns-appliance` |
| `source.kind` | `locked-download` or `runtime-artifact` |

Only one DNS adapter may exist. It must use `runtime-artifact`. Unknown
behaviors, adapters, source kinds, duplicate filenames, duplicate destinations,
path traversal, and malformed digests are rejected.

Bundles use `repository-file` or `repository-tree` and safe relative source
and destination paths.

## Source strategies

A `locked-download` contains one basename-only filename, an HTTPS URL, and a
lowercase 64-character SHA-256.

A `runtime-artifact` is supplied as `<entry-id>=<absolute-path>` together with
a manifest. The configured manifest field provides the expected artifact
digest, and the manifest is copied to its declared USB destination.

Repository bundles are staged only from reviewed paths inside this checkout.
They are not accepted from the external Catalog.

## USB result

The data partition label is `DEVICE-INST` by default. The 11-character label is
portable across Ventoy's bundled exFAT formatter and macOS. It contains staged
images, bundles, Ventoy configuration, the resolved Catalog, its SHA-256, image
checksums, and human readme files. When the DNS adapter is present, a separate
`DNS-ENROLL` partition stores installer metadata, generations, and reinstall
authorizations.

The exact USB layout is an output contract. Configured source and destination
strings under `images/`, `manifests/`, `ventoy/`, `guides/`, and
`tools/` must pass relative-path validation. The current bundle staging code
follows repository symlinks and does not prove their resolved targets remain in
the checkout; tracked bundles therefore must not contain symlinks.

## Enrollment record

`public.json` uses schema version 1. It records generation UUID, hostname,
role, fixed address, hardware identity, installer build and image digest,
public SSH and certificate fingerprints, service health, and completion time.
It never contains a password, token, or private key.

A generation is complete only when `public.json`, `recovery.tar.age`,
sanitized install log, and `COMPLETE` exist and the role's `ACTIVE` pointer
names that generation. Reinstall authorization names the same active generation
and matching system UUID hash.

## DNS desired state and apply

The zone file is Git-owned desired state. `dnsctl plan` reports current and
desired hashes plus a human diff. `dnsctl apply` requires literal `APPLY`, a
caller-supplied commit equal to current `HEAD`, and a clean zone file. It does
not consume a saved plan, prove pull-request approval, or require every file in
the checkout to be clean. It emits redacted JSONL audit events and does not
expose credentials in arguments, URLs, or logs.

## Compatibility

Adding optional data without changing meaning is compatible. Changing required
fields, accepted behavior, filesystem meaning, or security semantics is
incompatible and requires a schema-version decision plus coordinated updates to
all producers, consumers, fixtures, and rejection tests.

