# Engineering Standards

## Data layout

Keep one media entry or bootloader per JSON file. Register each file in the
index. Use stable, product-oriented IDs and versioned destinations. Format JSON
with two-space indentation and a final newline.

Do not put selection policy, local profiles, USB partitioning, download
execution, installer automation, or product-specific shell branches in the
Catalog.

## Contract consistency

The executable verifier is the CI enforcement surface. JSON Schemas are the
published representation. A contract change updates both, all fixtures, and
known Installer consumers in one coordinated pull request.

Preserve `schema_version: 1` meaning. New optional data is compatible only when
existing consumers safely ignore it. New required fields, changed accepted
values, or changed security semantics require a versioning decision.

## Validation behavior

Executable validation fails closed on unsupported strategy values, unsafe
paths, missing files, extra unregistered files, duplicate IDs or paths,
duplicate source filenames, non-HTTPS URLs, and malformed SHA-256 values. JSON
Schemas disallow additional properties, but CI does not yet enforce schema
parity; do not describe unknown keys as rejected by the executable gate.

Shell commands use `set -eu`, quote expansions, resolve repository paths from
the script location, create isolated temporary fixtures, and remove them with a
trap. Tests never download vendor media or touch a block device.

## Release updates

Confirm version, architecture, filename, URL, destination, and SHA-256 as one
review unit. Cite or retain authoritative provenance in the pull request.
Changing only a digest to satisfy a local file is unacceptable.

A stable ID does not contain a release number. Removing or renaming an ID needs
a compatibility note because downstream collections can break.

## Review and evidence

Every pull request passes shell syntax, ShellCheck, executable Catalog
validation, and success/rejection fixtures. A new validation rule includes a
counter-case that previously could have passed.

Passing CI proves metadata contracts only. Do not describe it as image download,
boot, installation, firmware, or hardware verification.
