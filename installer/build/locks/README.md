# Source locks

Generated media and downloaded binaries are not stored in Git. Immutable inputs
are recorded in `sources.env`. A successful build additionally emits:

- `artifacts/build-manifest.json`
- `artifacts/SHA256SUMS`
- `artifacts/debian-packages.txt`
- `artifacts/debian-package-sha256s.txt`
- `artifacts/sbom.spdx.json`

The build fails if the OCI digest, Simple-CDD version, public SSH input, native
age recipient, or enabled machine inventory is absent or malformed. Debian
package selection is frozen by the dated snapshot; emitted package hashes are
the release-time closure that must match any rebuild.
