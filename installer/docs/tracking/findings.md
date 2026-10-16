# Findings

## The first DNS pilot selected and damaged its installer USB

On 2026-10-16, read-only inspection of the removed 30.8 GB SanDisk installer
USB showed the DNS target layout: a 1 GB EFI partition, a Linux partition, and
swap. The EFI partition could not be mounted, and `diskutil verifyVolume`
reported a zero FAT sector size. This is physical evidence that the installer
USB became writable as an installation target; CP850 fallback messages were not
the root failure.

The source defect was that `/dev/mapper/Ventoy` was not resolved through its
sysfs slave and partition ancestry. The prior simulation used the mapper name
without modeling that ancestry and therefore could not detect the defect. The
gate now resolves the physical parent, rejects unresolved mapper ancestry and
all USB-backed candidates, rejects mounted targets, and clears stale disk-edge
signatures only after every target check passes.

The affected USB is not recoverable as installation media without a complete
rebuild. Source simulation cannot close this finding: a newly built ISO and USB
must pass VM BIOS/UEFI tests and a disposable physical `dns01` pilot before the
installer is considered safe for the remaining nodes.

## Physical qualification is incomplete

The repository has simulations and source contracts, but no recorded end-to-end
physical DIY Device OS USB qualification on the target HP hardware. This
cannot be closed in source alone because firmware, removable-media behavior,
disk identity, Secure Boot, and power-loss behavior require disposable media
and controlled physical access.

## Revised macOS readback needs a physical rerun

Two physical writes copied every selected ISO correctly and both exFAT
filesystems passed read-only checks. The original whole-device comparison then
failed because macOS had automatically mounted both exFAT partitions and
updated filesystem metadata. The writer now uses a two-phase MBR-last sequence
with isolated success and failure simulations, but that revised sequence has
not yet been rerun on disposable physical media. Do not claim the new writer is
physically qualified until that rerun and a BIOS/UEFI boot test pass.

## Repository bundle symlinks are not contained

Configured bundle paths are validated as safe relative strings, but the current
writer uses ordinary file and directory checks followed by copy operations.
Those operations can follow a symlink whose resolved target is outside the
checkout. Tracked bundles must not contain symlinks until the writer validates
resolved containment and adds escape fixtures.

## DNS apply does not prove review or bind a saved plan

`dnsctl apply` verifies literal confirmation, a caller-supplied commit equal
to current `HEAD`, and a clean zone file. It does not consume the output of
`dnsctl plan`, verify a pull-request approval, or require unrelated checkout
files to be clean. Operators must enforce those review steps outside the
command until an immutable plan artifact and approval source are designed.

## Catalog schema files and executable validation can drift

The Catalog module publishes JSON Schemas, while its executable verifier is
the actual CI gate. The Installer reimplements the consumed subset. Coordinated
contract checks reduce but do not eliminate drift between those three surfaces.
A future change should either generate one representation from another or add
cross-module contract fixtures before expanding schema versions.

## Vendor checksums need provenance evidence

Catalog values are syntactically validated, but the monorepo does not retain
signed vendor checksum provenance for every release. Reviewers must verify each
digest against an authoritative vendor channel when updating entries. This
cannot be solved by trusting a successful download of the same URL.


