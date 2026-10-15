# Business Rules

## Product model

The Installer is the execution module inside the single Gujo Homelab Device Bootstrap repository.
The sibling World owns selected media, local profiles, hardware bindings, USB
labels, safety policy, and append-only USB generations. Public media
metadata is contributed to the Catalog rather than copied into either the
Installer or a Playbook.

The Installer reference collection includes Proxmox VE, Proxmox Backup Server,
TrueNAS SCALE, Pop!_OS, and Debian Live. The user World selects from those
public entries and reviewed Installer-local profiles such as the DNS-appliance
installer. Inclusion in one USB does not grant the same automation level to
every entry.

## Media rules

- Every public artifact is selected by stable entry ID.
- Every remote artifact uses HTTPS and a lowercase SHA-256.
- A branch, tag, or `latest` label is not a reproducible identity; resolved
  plans record the exact monorepo commit and Catalog tree.
- Public Catalog content is untrusted input until Installer validation succeeds.
- General OS installers use `interactive-installer`; diagnostic systems use
  `live-environment`.
- `guarded-unattended` is reserved for a local profile with an independent
  destructive-install gate.
- The Ventoy menu has no automatic selection timer.
- Removing the DNS profile also requires setting the enrollment reserve to zero;
  otherwise the composition is inconsistent.
- The generated USB contains the resolved catalog and checksums for every staged
  image so its inputs can be reconstructed.

## World Playbook customization

A user adds or removes public entries in the World. A private or
organization-specific image belongs in World-local intent. The Catalog remains
the reviewed public metadata source in this monorepo.

`collections/` remains an Installer-owned reference and menu-group surface;
`usb-media/local-entries/` registers reviewed local profiles. Neither is the
ordinary user's selection boundary. `device-os world ...` consumes selection
and policy from the World and rejects IDs absent from both registries.

An entry that uses an implemented source kind and `profile_adapter: none` must
flow through resolution, fetch, verification, staging, and menu generation
without a product-specific branch. New behavior is not data-only: a new source
kind or adapter requires implementation and tests.

## DNS reference profile

The default network assumes one routed `10.0.0.0/16` LAN:

| Role | Address | Responsibility |
| --- | --- | --- |
| Router | `10.0.0.1` | Gateway and DHCP authority |
| `dns01` | `10.0.5.1` | Primary cluster node |
| `dns02` | `10.0.5.2` | Secondary cluster node |
| `dns03` | `10.0.5.3` | Secondary cluster node |

A router still configured only for `10.0.0.0/24` does not satisfy this model
unless it has an explicit route to `10.0.5.0/24`.

The sample inventory cannot erase a disk. A local operator must capture each
machine, review it, and enable destructive installation per role. Only one role
is enabled for the first physical pilot. Completed roles require a
generation-bound reinstall authorization.

Cluster formation and router DHCP DNS cutover occur after all three standalone
installs are healthy. Nodes are changed one at a time, and a canary query must
pass before proceeding. On failure, restore previous DHCP DNS values before
investigating the appliances.

## Evidence and release rules

Repository tests prove contract behavior in controlled fixtures. They do not
prove firmware boot, Secure Boot, physical disk selection, power-loss recovery,
or real network reachability.

A release candidate consists of immutable source identities, manifests,
package closure, SBOM, and checksums. Building a candidate, publishing evidence,
writing a USB, and installing a machine are separate approvals. No workflow may
silently turn one approval into the next.

