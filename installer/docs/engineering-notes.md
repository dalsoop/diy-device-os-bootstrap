# Engineering Notes

## Catalog resolution

Symptom: an external Catalog fixture is accepted during normal operation.

Cause: isolated-test opt-in leaked into a normal invocation.

Response: leave `DEVICE_MEDIA_ALLOW_UNPINNED_CATALOG` unset for release work.
Use it only with an explicit external fixture. Confirm the resolved plan records
the monorepo commit and Catalog tree.

Symptom: a new public entry is present in the Catalog but absent from the USB.

Cause: Catalog availability and Installer selection are separate. The entry was
not added to the collection used by the reference composition.

Response: add the stable ID to the collection, then resolve and inspect the plan
before downloading.

## Polymorphism limits

Symptom: adding a new entry requires a branch in the writer.

Cause: the entry introduces behavior not represented by an implemented
`source.kind` or `profile_adapter`.

Response: do not label the change data-only. Define the new contract, implement
fetch/verify/stage behavior, reject unknown values, and add negative fixtures.
The current implementation is declarative within known strategies, not a
runtime plug-in loader.

## USB targeting

Symptom: a device path looks correct but the writer refuses it.

Cause: removability, root-disk exclusion, serial identity, or capacity failed.

Response: inspect live block-device metadata and fix the target or invocation.
Never bypass the check or copy an old confirmation string. Device names can
change after reconnect or reboot.

Symptom: a macOS full-disk write completes but a naive whole-device `cmp`
reports differences inside an exFAT partition.

Cause: Disk Arbitration mounted the newly visible volume after `dd` and the
filesystem updated ordinary mount metadata before readback.

Response: use `write-image-macos`, which keeps the MBR hidden while writing and
verifying the image body, then writes and verifies the first MiB last. Do not
interpret a post-mount raw difference as either payload corruption or proof of
a correct write; verify the staged image checksums and filesystems separately.

Symptom: the DNS profile was removed but composition validation fails.

Cause: `DNS-ENROLL` space is still reserved without a DNS adapter.

Response: set `enrollment_reserve_mib` to zero when no DNS profile is present.

Symptom: capacity reports `PENDING` for a target.

Cause: a runtime artifact or matching manifest was not supplied, a public image
is absent from the cache while offline, or only an unverified remote size
estimate is available.

Response: run `prepare` for exact cached public sizes and pass each local
runtime artifact with its matching build manifest to `capacity`. Do not
interpret an estimate or known subtotal as the final required size.

## DNS installation

Symptom: installation stops before partitioning.

Cause: this is the expected fail-closed result for disabled inventory, wrong
DMI, MAC or disk identity, removable media, zero or multiple matching disks,
an existing completed generation, or stale reinstall authorization.

Response: inspect the reported mismatch from a trusted live environment.
Recapture inventory only when hardware was intentionally changed. Never edit a
hash merely to make the gate pass.

Symptom: mixed-case DMI values visibly match inventory, but the installer gate
reports that no inventory entry matched.

Cause: the Debian Installer BusyBox `tr` treats `[:lower:]` and `[:upper:]` as
literal character lists, unlike GNU `tr`, so normalization can change letters
without uppercasing them.

Response: normalize with explicit ASCII lowercase and uppercase alphabets. Keep
the simulation's `tr` compatibility shim so GNU-hosted tests reject the
non-portable character-class form, and repeat a disposable BIOS boot.

Symptom: the early installer gate finds `DNS-ENROLL` but mounting it fails with
`Invalid argument`.

Cause: Debian Installer does not ship an exFAT kernel module, and its available
FAT32 modules are not automatically loaded before the preseed early command.

Response: format `DNS-ENROLL` as FAT32 and explicitly load `vfat` before the
gate mounts it. Keep the 11-character label limit and test both module-load
success and failure before any target write.

Symptom: the expected target is rejected as active even though `/dev/sda` is
not listed directly in `/proc/mounts`.

Cause: a target partition can be mounted or used as swap through a
device-mapper node or `/dev/disk` alias, or retained by an unmounted holder.

Response: inspect `/proc/mounts`, `/proc/swaps`, and the target's sysfs holder
directories. Deactivate the legitimate consumer; never bypass the ancestry or
holder check.

Symptom: `mkfs.fat` prints CP850 conversion messages during EFI formatting.

Cause: a minimal installer environment can lack optional iconv conversion
modules. `mkfs.fat` then reports that it is using its internal CP850 table; that
message alone is non-fatal. It does not prove that a FAT filesystem was written.

Response: inspect the command exit status and the EFI filesystem separately.
If the installer USB itself now has the DNS target layout, stop immediately:
the USB was selected as the target, and formatting retries are unsafe. Preserve
the media for inspection, rebuild from a fixed revision, and repeat the
disposable-media and physical gates.

Symptom: first boot retries and appears to reuse credentials.

Cause: credentials are intentionally generated once and retained until
encrypted enrollment commits, so power loss does not create unknown passwords.

Response: allow retry to converge. Rotate credentials only after successful
import into the principal secret store.

## Network and management

Symptom: `10.0.5.1` through `10.0.5.3` are unreachable from a router at
`10.0.0.1`.

Cause: the LAN is still `/24` and no explicit route exists.

Response: secure a wired recovery path, record prior router settings, and change
or route the network before DHCP DNS cutover.

Symptom: Tailscale is connected but changes DNS or routing.

Cause: enrollment preferences or tailnet policy are broader than the appliance
contract.

Response: treat enrollment as failed unless `accept-dns=false`, no advertised
routes, no exit node, no Tailscale SSH, and the expected tag and hostname are
verified.

Symptom: a backup file exists but recovery is unproven.

Cause: collection verifies transport, not decryptability or application restore.

Response: periodically decrypt, run ZIP integrity checks, restore to an isolated
Technitium instance, and query the canary zone.

