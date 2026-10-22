# Contributing

Contributions are welcome through pull requests. Keep changes within the module
boundaries and safety rules in `AGENTS.md`, and update every affected producer,
consumer, fixture, and document together.

User-owned data lives in `burn-history/`: what you edit (`home.yaml`,
`dns-records.zone`, `os-installs/<role>/os.conf`), private files never committed
(`keys/`, `os-installs/<role>/hardware.conf`, `.in-progress/`), and what happened
(never edited) in `logs/`.
Code, schemas, and tests live in `engine/`. Never hand-edit
`burn-history/logs/`.

## Contribution license

Except where an upstream or file-specific notice says otherwise, every
repository-authored contribution is submitted under the GNU General Public
License version 3 only (`GPL-3.0-only`). By submitting a contribution, you
represent that you have the right to provide it under those terms.

Do not submit third-party code, media, metadata, or documentation unless its
license is compatible with the repository, its provenance is recorded, and all
required notices are preserved. Never commit generated operating-system media,
vendor binaries, credentials, private inventory, or recovery material.

## Sign-off

Sign off each commit to record the
[Developer Certificate of Origin](https://developercertificate.org/) using:

```sh
git commit -s
```

The sign-off certifies that you created the contribution or otherwise have the
right to submit it under the project's license. A sign-off does not replace any
separate permission required from another copyright holder.

## Review and release status

- Land substantive changes through a pull request; do not push directly to
  `main`.
- Keep documentation and examples in English.
- Follow the documentation rule in `docs/standards.md`: name roles such as the
  build host, the VM host, the operator workstation, and the management host,
  never specific machines or personal paths, and describe only the present
  layout and behavior. The required `contracts` check enforces it.
- Report source, image assembly, physical USB write, firmware boot,
  installation, and network cutover as separate evidence states.
- Do not describe a source tag or CI result as physical qualification.

See `docs/licenses/LICENSE_HISTORY.md` for the MIT-to-GPL transition boundary.
