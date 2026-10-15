# Architecture

## Scope

The Catalog is a public metadata package. It describes available bootloaders and
x86_64 installation or live media. It does not select a user's collection,
resolve private profiles, download artifacts, build images, render a boot menu,
or write a disk.

Installer forks consume the Catalog as untrusted, pinned data. This keeps reusable
vendor metadata separate from local policy and destructive behavior.

## Components

```text
catalog/index.json
  |-- catalog/bootloaders/*.json
  |-- catalog/entries/*.json
  |
  +--> bin/verify-catalog
          |-- structural and semantic checks
          |-- closed-world file registration
          |-- duplicate detection
          +-- success/rejection fixtures

schemas/*.json
  published contract representation

exact Git commit
  consumed by Gujo Homelab OS Installer
```

The index is the sole registry. Each referenced file owns one stable ID. The
executable verifier checks both directions: every index reference exists, and
every JSON file in the controlled directories is registered.

## Entry model

Public media entries share one shape: stable identity, group, release version,
architecture, destination, Korean and English descriptions, boot behavior,
profile adapter, and source.

The current public source strategy is `locked-download`: a basename-only
filename, official HTTPS URL, and lowercase SHA-256. Public entries use
`profile_adapter: none` and are either interactive installers or live
environments. Guarded unattended profiles remain local to a Installer fork.

Bootloaders have their own contract because archive root and implementation are
different from ISO menu metadata.

## Dependency direction

Vendor release information flows into Catalog data. Catalog data flows by exact
Git commit into Installer resolution. No Installer configuration flows back into
the Catalog, and no Catalog file can supply executable code.

Schemas describe the intended public shape, while `bin/verify-catalog` is the
CI enforcement surface. Contract changes must keep both representations and
Installer consumers aligned.

## Assurance boundary

Validation establishes JSON shape, safe paths, uniqueness, HTTPS use, and digest
format. It does not prove vendor authenticity, checksum provenance, successful
download, image integrity beyond the recorded digest, firmware boot, installer
behavior, or hardware compatibility. Those claims require review and Installer or
physical evidence outside this repository.
