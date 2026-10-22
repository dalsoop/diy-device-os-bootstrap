# Installer Module

This module is the repository's execution and safety boundary. It resolves World-selected entries, revalidates the data-only Catalog, verifies downloads and runtime artifacts, assembles removable media, builds the guarded DNS image, and runs management-host operations.

## Boundaries

- `usb-media/` owns resolution, capacity, download, staging, Ventoy rendering, and physical USB writers.
- `collections/` owns contributor reference grouping, not the personal selection used by ordinary World commands.
- `dns-image/` owns the offline DNS image, install gate, and first-boot enrollment; it does not own general public OS behavior.
- Per-role folders live in `burn-history/os-installs/<role>/`: the tracked guided profile `os.conf` and the ignored real hardware capture `hardware.conf`. Operator public keys live in the ignored `burn-history/keys/`. Public format examples live in `docs/examples/`.
- `management/` owns post-install DNS, Tailscale, backup, restore, reinstall authorization, and read-only monitoring from a trusted host.
- `build/` owns immutable external input locks; `schemas/` owns exchanged record shapes; `tests/` owns non-destructive simulations; `docs/` owns installer procedures and physical verification gates. Reviewed DNS desired state lives in `burn-history/dns-records.zone`.
- Long-lived credentials belong outside the checkout. Router mutation and arbitrary remote administration are outside this module.

## Invariants

- World and Catalog input are revalidated before execution. Catalog files are never executed.
- `validate`, `plan`, `capacity`, and `simulate` never download full images or write a device; `prepare` may download but never writes a block device.
- A USB write accepts only the currently inspected removable non-root device with readable serial, sufficient capacity, verified artifacts, and exact `ERASE <device> <serial>`.
- General OS entries remain interactive. Guarded unattended behavior is isolated to the local DNS adapter with exact hardware, internal-disk, installer-media, and reinstall checks.
- Mapper and partition ancestry resolve to one physical parent before target preparation. Unresolved, ambiguous, USB-backed, removable, mounted, zero-candidate, or multiple-candidate states fail before disk signatures are cleared.
- Secrets never enter arguments, URLs, logs, generated public JSON, or Git. Any removable-media secret is age-encrypted before its first write.
- Source, image, VM, physical USB, firmware, installation, network, and recovery evidence remain separate claims.

## Change pattern

Existing source kinds and profile adapters drive shared code paths. Do not add a product-name conditional for an entry that fits an existing strategy. A new strategy requires a versioned contract, implementation, cleanup behavior, and success plus rejection coverage.

CLI and record changes update every producer, consumer, schema, fixture, and operator surface together. Preserve nonzero failure for rejected and incomplete operations. Use temporary files and atomic promotion for downloads, enrollment, and other durable output.

## Verification

Run shell syntax and ShellCheck for executable shell files, Python syntax for the status monitor, and all scripts under `engine/installer/tests/`. Destructive fixtures use temporary fake device trees and must never open a real block device, mounted USB, live DNS node, or production credential.

An image build requires the build host (amd64 Debian 13) and immutable locks. Physical qualification then advances through disposable VM BIOS/UEFI, one `dns01` pilot, and one-at-a-time expansion. Passing source simulations must not be reported as physical qualification.
