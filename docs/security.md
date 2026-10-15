# Security Boundaries

Repository proximity is not runtime trust. The Catalog remains data-only, the
World remains declarative intent, and only the Installer may perform execution
after its own validation and target checks.

Never commit credentials, private keys, age identities, raw hardware serials,
real inventory, generated images, enrollment records, or recovery archives.
The writable USB data partition is transport rather than a secret store; any
secret written there must already be encrypted.

Planning and simulation never write disks. A USB writer must reject internal,
root, virtual, unresolved, ambiguous, non-removable, or size-incompatible
targets and require an exact `ERASE <device> <serial>` confirmation. A World
selection is not authorization to erase that target.

Catalog files are validated as untrusted JSON and never executed. Public media
is promoted only after its reviewed SHA-256 matches. General installers remain
interactive, and DNS unattended installation retains its separate hardware,
inventory, disk, and reinstall-authorization gates.
