# Engineering Notes

## Catalog resolution

Symptom: a local Catalog checkout is accepted even though it does not match the
composition.

Cause: local development bypassed the exact revision check.

Response: leave `DEVICE_MEDIA_ALLOW_UNPINNED_CATALOG` unset for release work.
Use it only in isolated fixtures. Confirm the resolved plan records the pinned
revision.

Symptom: a new public entry is present in the Catalog but absent from the USB.

Cause: Catalog availability and Installer selection are separate. The entry was
not added to the collection, or the Installer still pins an older Catalog commit.

Response: update the exact revision, add the stable ID to the collection, then
resolve and inspect the plan before downloading.

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

