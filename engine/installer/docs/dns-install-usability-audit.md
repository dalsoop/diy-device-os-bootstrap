# DNS Install Usability Audit

Date: 2026-10-16

This audit separates source behavior from physical qualification. A fixed or
passing source check does not claim that a USB boots or that an internal disk
was installed successfully.

| Priority | Finding | State | Resolution or next gate |
| --- | --- | --- | --- |
| P0 | The DNS installer could resolve `/cdrom` to a Ventoy device-mapper node without reaching the physical USB parent, allowing the installer media to appear eligible as an internal target. | Fixed in source | Mapper, partition, and slave ancestry now resolve to physical disks; unresolved, ambiguous, cyclic, removable, USB-backed, mounted, and installer-media candidates fail closed. Repeat disposable-USB and HP hardware tests. |
| P0 | The damaged USB showed the intended internal-disk layout and an invalid EFI filesystem after target misselection. Retrying formatting could destroy more evidence. | Operationally contained | Rebuild the USB from the fixed revision. Never repair or reuse that media as proof of installer correctness. |
| P1 | `language: ko-KR` changed only the Ventoy menu while the Debian preseed remained `en_US.UTF-8`. | Fixed in source | The current DNS installer profile now uses `ko_KR.UTF-8`, includes `locales`, retains the US keyboard map, and requires a physical UI check. |
| P1 | A successful Simple-CDD exit did not prove that current inventory, keys, locks, provenance, and install gate were embedded in the ISO. | Fixed in source | `build-image` extracts critical files from the finished ISO with `xorriso` and byte-compares them before publishing the manifest. |
| P1 | macOS could write but not assemble an exact-size Ventoy raw image. | Fixed in source | `world build-image` now uses a Debian 13 Podman/Docker loop device without host block access. Qualify image assembly, MBR-last write, filesystems, and BIOS/UEFI on disposable media. |
| P1 | Installer failures can still surface as generic Debian installer errors instead of a concise Korean reason at the console. | Open | Preserve the fail-closed behavior, then add a reviewed error handoff that cannot bypass the installation gate. |
| P2 | The generic World exposed unrelated operating systems in the DNS production path. | Fixed in source | `dns-install` contains only the DNS appliance; `inventory-capture` contains only Debian Live. |
| P2 | Old `write`, `--dns-iso`, and `--dns-manifest` aliases made the destructive surface harder to document and test. | Fixed in source | The command exposes one spelling: `burn` with keyed runtime artifact and manifest arguments. |

## Required qualification sequence

1. Run source contracts and simulations on an approved build host.
2. Build the ISO on clean amd64 Debian 13 and retain the manifest and SBOM.
3. Boot a disposable VM in both BIOS (non-UEFI) and UEFI modes.
4. Burn a disposable USB and verify manifests from the mounted media.
5. Confirm the installer rejects the USB, removable disks, mapper ambiguity,
   zero matching disks, and multiple matching disks.
6. Install `dns01` on one HP machine and verify the internal disk identity at
   the console before partitioning.
7. Verify first boot, SSH fingerprint, DNS UDP/TCP, Cockpit, Technitium,
   encrypted enrollment, backup, restore, and rollback.
8. Only then enable and install `dns02`, followed by `dns03`.
