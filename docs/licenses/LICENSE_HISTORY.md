# License History

This file records the license boundary of the published `main` branch. It does
not rewrite Git history or withdraw permissions that accompanied an earlier
copy.

## Transition boundary

| Published `main` snapshot | Project license |
| --- | --- |
| Through `0cbf199c7073e4aa18ddd597cca843771aeff08a` | MIT License |
| From `2b3f542629a5976cfc3bdfcfeb0d6eb31e90bf2b` | GNU General Public License version 3 only (`GPL-3.0-only`) |

The second commit is the merge of pull request
[#15](https://github.com/dalsoop/diy-device-os-bootstrap/pull/15), which
replaced the root MIT license with the canonical GPL version 3 text. There were
no version tags or GitHub Releases before this transition.

Copies obtained from an earlier MIT-licensed snapshot remain governed by the
license supplied with that copy. The project does not offer changes first
published after the transition under the former MIT license.

## Copyright authority

The transition assumes that the project owner has the copyright authority or
permission required to license every repository-authored contribution in the
GPL snapshot. A contribution whose copyright holder has not granted that
authority must not be represented as relicensed; resolve its ownership before
including it in a release.

## Release policy

- Do not rewrite or remove pre-transition history to imply that earlier copies
  were never MIT-licensed.
- Every version tag created after the transition identifies a
  `GPL-3.0-only` source snapshot and must retain the root `LICENSE` file.
- Release notes must identify the exact source commit and state whether the
  release is source-only, an assembled image, a physically verified USB
  generation, or an installed-system qualification.
- A source release or passing CI run must not be described as physical USB or
  installation qualification.
- Third-party operating systems, bootloaders, packages, container images, and
  installation media retain their upstream licenses and notices.
- Personal self-build for the operator's own devices is allowed by repository
  policy, but it is not approval to redistribute generated media.
- The current public policy is source-only. Release automation may retain
  non-executable checksums, manifests, package closure, component status, and
  SBOM evidence, but it must not upload ISO, RAW, IMG, disk-image, or complete
  USB content.
- Future prebuilt publication requires both a successful exact-artifact
  `prebuilt-release` check and approval through the protected GitHub Environment
  `prebuilt-distribution` with a human-only required reviewer. Neither CI nor a
  successful personal build promotes an artifact automatically.

The first post-transition release is intentionally source-only. It establishes
the GPL boundary and does not certify generated media or hardware behavior.
