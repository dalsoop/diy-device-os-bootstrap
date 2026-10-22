# Source locks

Generated media and downloaded binaries are not stored in Git. Immutable inputs
are recorded in `sources.env`. A successful build additionally emits, under the configured artifact
directory:

- `engine/installer/artifacts/build-manifest.json`
- `engine/installer/artifacts/SHA256SUMS`
- `engine/installer/artifacts/debian-packages.txt`
- `engine/installer/artifacts/debian-package-sha256s.txt`
- `engine/installer/artifacts/sbom.spdx.json`

The build fails if the OCI digest, Simple-CDD version, public SSH input, native
age recipient, or enabled machine inventory is absent or malformed. Debian
package selection is frozen by the dated snapshot; emitted package hashes are
the release-time closure that must match any rebuild.
