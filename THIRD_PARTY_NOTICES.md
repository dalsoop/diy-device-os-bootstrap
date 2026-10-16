# Third-Party Notices

DIY Device OS Bootstrap describes, downloads, assembles, or installs software
owned by other projects. The repository's `GPL-3.0-only` license applies only
to original project content; it does not replace any upstream license,
copyright, trademark, source-availability requirement, or end-user agreement.

This inventory is a navigation aid, not a substitute for the notices shipped
inside an exact artifact. Versions and digests remain authoritative in the
Catalog, source locks, resolved media plan, and build manifest.

## Reviewed upstream projects

| Component | Upstream licensing evidence | Source and notices |
| --- | --- | --- |
| Ventoy | Ventoy-developed modules are described upstream as GPLv3+; the archive also contains separately licensed components | <https://github.com/ventoy/Ventoy/tree/master/License> and <https://github.com/ventoy/Ventoy> |
| Debian installation and live media | Debian media contains packages under many DFSG-compatible licenses; no single SPDX expression describes the complete image | <https://www.debian.org/CD/vendors/info> and <https://sources.debian.org/> |
| Technitium DNS Server | The upstream DNS Server repository publishes the GNU GPL version 3 | <https://github.com/TechnitiumSoftware/DnsServer/blob/master/LICENSE> and <https://github.com/TechnitiumSoftware/DnsServer> |
| Tailscale client and daemon | The upstream client repository publishes BSD-3-Clause and a separate dependency-license inventory | <https://github.com/tailscale/tailscale/blob/main/LICENSE> and <https://github.com/tailscale/tailscale/tree/main/licenses> |
| Proxmox VE and Backup Server | Proxmox states that the majority of its code is AGPLv3 or another FLOSS license; an installer contains separately licensed components | <https://www.proxmox.com/en/about/open-source> and <https://git.proxmox.com/> |
| Pop!_OS | The ISO is a distribution of independently licensed Ubuntu, System76, firmware, and other components | <https://github.com/pop-os/pop/blob/master/LICENSING.md> and <https://github.com/pop-os> |
| TrueNAS SCALE | The image contains independently licensed open-source components and may present edition- or component-specific terms | <https://github.com/truenas> and the notices delivered with the exact image |

The complete Tailscale BSD-3-Clause text reviewed for the pinned client source
is stored at `third_party/licenses/Tailscale-BSD-3-Clause.txt`. The DNS builder
also fetches and verifies the dependency-license report from the exact pinned
Tailscale tag, includes it in the ISO, and installs it beside the project
notices. GNU GPL version 3 text used by this project and the GPL-licensed
upstream components is stored at `LICENSE`.

## Generated media and systems

The USB writer copies this file, the project license, the licensing history,
and an exact source-revision pointer into `licenses/`. The DNS image builder
also places them in the installer and installs them under
`/usr/share/doc/diy-device-os-bootstrap/`.

Opaque upstream ISOs remain unmodified and retain their embedded notices. This
project does not extract enough information from every ISO to prove that a
redistributed multiboot USB satisfies every upstream term. Do not distribute a
generated USB, ISO, appliance image, or installed-system image until the exact
selected artifacts have passed a separate license review and every required
notice and corresponding-source obligation has been fulfilled. Personal use
does not turn this inventory into redistribution approval.

The generated SPDX SBOM uses `NOASSERTION` when the build cannot establish one
license expression for an artifact or Debian package. `NOASSERTION` means the
operator must inspect the upstream package notices; it does not mean that the
artifact has no license requirements.
