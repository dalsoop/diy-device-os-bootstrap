# Engineering Notes

## Guided answers must preserve the shared installer frontend

**Symptom:** the guided confirmation disappears into a blank screen, or Debian asks again for the role's preselected network values.

**Cause:** the preseed hook shares the enclosing cdebconf frontend. Sending `STOP` disconnects main-menu, while setting an answer without its `seen` flag leaves ordinary questions interactive.

**Response:** return without stopping the shared frontend and mark programmatically supplied network answers seen. Role, wired interface, and exact erase consent remain deliberate questions. Qualify this through the actual main-menu flow, not only mocked debconf functions.

## Debian reserves the operator account name

**Symptom:** user-setup rejects the preseeded `operator` username as reserved.

**Cause:** Debian's base system already reserves that name. A syntactically valid preseed does not prove account creation will succeed.

**Response:** use `dns-operator` consistently for installation, SSH allowlisting, home ownership, sudo, first-boot password assignment and management SSH. The encrypted `operator-password` filename remains unchanged. Verify actual account creation and key-based login after internal boot.

## Installer media can masquerade as the internal target

**Symptom:** the installer reports EFI formatting trouble, or the USB later contains a 1 GiB EFI partition, Linux partition, and swap instead of the expected Ventoy layout.

**Cause:** Ventoy boots through `/dev/mapper/Ventoy`. Treating that mapper name as a complete device identity misses its sysfs slave and partition ancestry, so the physical installer USB can remain in the candidate set. CP850 conversion text from `mkfs.fat` is incidental; it does not explain target selection and does not prove a filesystem was created.

**Response:** stop immediately and preserve the media for inspection. Do not retry formatting. Rebuild from a revision that resolves mapper-to-partition-to-physical-parent ancestry, rejects unresolved ancestry and all USB-backed candidates, and clears stale signatures only after every identity check passes. Verify in VM BIOS/UEFI and on disposable physical `dns01` before enabling another node.

## macOS changes mounted exFAT metadata

**Symptom:** a full-disk `dd` appears successful, but a later whole-device `cmp` differs inside an exFAT partition.

**Cause:** Disk Arbitration mounts a newly visible filesystem and ordinary mount activity changes metadata before raw readback.

**Response:** use the MBR-last writer. It hides the first MiB, writes and verifies the image body, then writes and verifies the first MiB so filesystems cannot mount before their source bytes are checked. Afterward verify filesystem health and staged image checksums separately; a post-mount raw difference is neither proof of corruption nor proof of success.

## A valid raw image can be recorded under the wrong World media

**Symptom:** raw readback succeeds, but the generated World record names
`dns-install` while the physical USB contains the `inventory-capture` image.

**Cause:** the destructive command resolved the World's default media again and
did not bind that selection to the previously built raw image. Omitting
`DEVICE_OS_MEDIA=inventory-capture` therefore changed only the evidence inputs,
not the image bytes passed to the writer.

**Response:** reject the generation and retain a redacted failed event. Every
raw-image build emits an adjacent manifest containing the image hash, resolved
Catalog digest and identity, World slug, and media ID. The macOS writer rehashes
and compares all of them before live target inspection or any write.

## Capacity can remain indeterminate

**Symptom:** `world capacity` reports `PENDING` or null `fits` for a 16 GB target.

**Cause:** the DNS runtime artifact or matching manifest is absent, a selected public image is not present in the verified cache during offline calculation, or only a remote size estimate is available.

**Response:** run `world prepare` for selected public artifacts, then pass the exact DNS ISO and matching build manifest. Verify that no entry remains unknown or unverified before treating the result as a fit decision.

## Catalog availability is not World selection

**Symptom:** a valid Catalog entry does not appear in the generated USB.

**Cause:** the Catalog only makes the entry available. The selected World media definition controls the ordered payload; the Installer reference collection only supplies menu grouping and contributor fallback.

**Response:** change the World draft, rerun validate and plan, and inspect the selected entry list, DNS reserve, and capacity. Do not branch shared writer code or copy the Catalog item into local profiles.

## Declarative support has finite strategies

**Symptom:** adding an OS appears to require a product-specific branch in fetch or staging code.

**Cause:** the media introduces behavior outside the implemented `locked-download` or `runtime-artifact` source strategies, or outside `none` and `dns-appliance` profile adapters. The system is data-driven within those strategies, not a runtime plug-in loader.

**Response:** treat the change as a new behavior contract. Define accepted fields, failure behavior, cleanup, and security boundary; implement it once in the shared resolver; reject unknown values; and add success plus rejection fixtures. Do not disguise executable behavior as a Catalog-only edit.

## Catalog schema and executable validation can still drift

**Symptom:** a future Catalog document passes one validation path but fails another despite the tracked records and current valid and invalid fixtures passing CI.

**Cause:** CI now runs draft-2020-12 schema validation for tracked Catalog v2 records and explicit fixtures, but the schemas, jq verifier, and Installer consumer remain separate implementations. Cases not represented by current records or fixtures can still diverge.

**Response:** change schema, verifier, Installer consumer, and positive and rejection fixtures together. Treat CI schema validation as evidence for the exercised contract, not proof that independently maintained validators are equivalent for every possible document.

## A successful personal build is not redistribution approval

**Symptom:** a candidate has matching checksums, a complete SBOM, passing CI, or successful USB readback and is described as ready for public download.

**Cause:** build integrity and physical verification answer different questions from exact-artifact license, notice, corresponding-source, and trademark review. DNS images also combine multiple components whose reviews do not replace a review of the final ISO.

**Response:** keep the artifact personal-use-only. Public prebuilt distribution requires every exact artifact review, both DNS component and final gates, fulfilled digest-bound obligations, enabled repository policy, a successful prebuilt check, and protected `prebuilt-distribution` Environment approval by a human-only required reviewer. No lower evidence state promotes automatically.

## DNS installation intentionally fails before partitioning

**Symptom:** the unattended install stops without creating partitions.

**Cause:** disabled inventory, wrong DMI identity, NIC or disk mismatch, removable or mounted media, unresolved ancestry, zero or multiple internal disks, an active completed generation, or stale reinstall authorization is expected to fail closed.

**Response:** inspect from a trusted live environment and compare the observed machine with the captured local inventory. Recapture only after an intentional hardware change. Never edit a serial, UUID, MAC, or hash merely to make the gate pass.

## The expected target is rejected as active

**Symptom:** the install gate rejects the expected target as mounted, active swap, or held, or reports an unsupported device source, although `/dev/sda` is not listed directly in `/proc/mounts`.

**Cause:** a target partition can be mounted or used as swap through a device-mapper node, or retained by an unmounted holder. A mount or swap source that the gate cannot resolve to exactly one physical parent, such as a `/dev/disk` alias, a multi-slave device, or a loop or MD device, fails closed even when it is not on the target.

**Response:** inspect `/proc/mounts`, `/proc/swaps`, and the sysfs `holders` directories of the target and its partitions. Deactivate the legitimate consumer; never bypass the ancestry, swap, or holder check.

## First boot reuses bootstrap credentials on retry

**Symptom:** a repeated first boot appears to reuse generated credentials.

**Cause:** credentials are generated once and retained until encrypted enrollment commits; regenerating them on every power-loss retry would leave the operator unable to know which credential reached the appliance.

**Response:** let first boot converge, verify the encrypted generation and public completion record, import it into the principal secret store, and rotate bootstrap credentials afterward.

## Tailscale connectivity can still violate appliance policy

**Symptom:** a node appears online but changes DNS behavior or routing.

**Cause:** a broad tailnet policy or enrollment preference can enable accepted DNS, advertised routes, exit-node behavior, or Tailscale SSH even though transport connectivity succeeds.

**Response:** treat enrollment as failed unless the expected hostname and `tag:dns-appliance` are present, `accept-dns=false`, no routes or exit node are advertised, and Tailscale SSH/Serve/Funnel are absent. A key revocation failure remains relevant until the one-hour key expires.

## A collected backup is not a recovery proof

**Symptom:** encrypted backup files exist, but recovery readiness is unknown.

**Cause:** collection proves transport and storage only; it does not prove age decryption, archive integrity, application import, or DNS behavior.

**Response:** periodically decrypt in an isolated environment, validate the archive, restore to an isolated Technitium instance, and query the canary over UDP and TCP. Keep this result separate from production restore authority.

## Network reachability depends on the router prefix

**Symptom:** the management host can reach `10.0.0.1` but not `10.0.5.1` through `10.0.5.3`.

**Cause:** the router may still treat the LAN as `10.0.0.0/24`; sharing the first octet does not make `10.0.5.0/24` directly reachable.

**Response:** preserve a wired recovery client and old router values, then configure a `10.0.0.0/16` LAN or an explicit route. Prove node reachability before changing DHCP DNS advertisement.

## Simple-CDD requests a removed trixie i386 installer

**Symptom:** an amd64 Debian 13 build fails with HTTP 404 while fetching `installer-i386/current/images/SHA256SUMS`.

**Cause:** Simple-CDD 0.6.9 unconditionally requests i386 installer boot files for an amd64 build, although trixie removed the i386 installer.

**Response:** `fetch-debian-installer` verifies the dated snapshot Release using Debian archive signatures, verifies its referenced SHA-256 list, and verifies the six required amd64 text/graphical installer components. The builder passes this verified cache through Simple-CDD custom-installer support and disables only 32-bit UEFI support. BIOS and 64-bit UEFI remain qualification requirements. Never bypass signature or digest checks, use an unverified daily installer, or weaken a required source gate to make the build proceed.

## Zero timeout has different BIOS and UEFI meanings

**Symptom:** an ISO configured with Simple-CDD `BOOT_TIMEOUT=0` boots its UEFI default immediately.

**Cause:** BIOS ISOLINUX zero means wait, while Simple-CDD also emits GRUB `set timeout=0`, which means immediate boot.

**Response:** leave the Simple-CDD timeout override empty. Debian's included speech submenu also sets a 30-second BIOS timeout, so the required `disable-boot-timeouts` disc-finish hook disables every BIOS timer and any GRUB timer in the build tree before filesystem checksums are created. Image acceptance independently extracts both boot menus and rejects automatic timeouts. VM BIOS and UEFI menu waiting must still be observed before installation qualification.

## An offline package profile needs real package names and enough space

**Symptom:** Simple-CDD cannot find `dnsutils`, or its single-image package check fails after building a CD-sized tree.

**Cause:** Debian 13 provides `dnsutils` through the real `bind9-dnsutils` package, while Simple-CDD checks package filenames rather than virtual provides. Its default CD size is also too small for the appliance's offline package closure and application payload.

**Response:** request `bind9-dnsutils` explicitly and select one DVD-sized ISO. Keep Simple-CDD's required-package check enabled; a populated download mirror alone does not prove that the ISO contains the packages needed for an offline installation.

## SATA disks do not expose the NVMe serial attribute

**Symptom:** Debian Installer sees a SATA SSD but the install gate reports an unreadable disk identity.

**Cause:** the real Debian 13 kernel exposes SATA SCSI VPD pages rather than `/sys/class/block/sda/device/serial`. This was reproduced with the signed installer kernel and a disposable QEMU SATA disk.

**Response:** inventory and installation share `disk-identity`. It reads kernel serial attributes where present, then uses Debian Installer's read-only `ata_id --export` probe on the exact SATA block device. Missing, duplicated, failed or changed serial evidence still blocks installation; a model, device name or generic WWID never substitutes for a serial.

## debian-cd needs task metadata for a headless image

**Symptom:** `update_tasks` cannot find `task-desktop` or `tasksel-data`, then fails to open `debian-tasks.desc`.

**Cause:** these packages are absent from the minimal appliance mirror, but Debian 13's debian-cd reads their metadata unconditionally while generating image task lists.

**Response:** include both through the required `dns-build` build-only profile. Only `dns` is automatically selected on the target, so this metadata does not request a desktop installation. Keep the required package and mirror-completeness checks enabled.

## Early guided prompts precede the network drivers

**Symptom:** the real installer rejects a valid network profile with `Math support is not compiled in`, or finds only the loopback interface.

**Cause:** Debian Installer's BusyBox awk omits exponentiation, and file-preseed executes before the normal offline component and network hardware detection stages. Host-side simulations do not reproduce either property.

**Response:** network arithmetic uses repeated multiplication. `prepare-installer` initializes the CD retriever, loads the offline components, and configures `ethdetect` before identity collection. Each failure stops before the identity prompt or partitioning. Qualify these steps with the signed installer's BusyBox and actual BIOS/UEFI boots; desktop awk and fake NIC fixtures are insufficient evidence.

## Debian Installer cannot read exFAT enrollment media

**Symptom:** the role gate locates `DNS-ENROLL` but its read-only mount fails with `Invalid argument`; `modprobe exfat` reports no module.

**Cause:** the signed Debian 13 installer kernel's available udebs include FAT/VFAT, not exFAT. An installed Debian system's exFAT support does not establish installer support.

**Response:** both USB builders format only the enrollment partition as FAT32 with the corresponding partition type. Preparation explicitly requests `fat-modules` and loads `vfat` before the gate mounts enrollment read-only. Ventoy's main data partition remains exFAT. Existing completed media generations are immutable and are never rewritten to claim this layout.

## The offline DVD must carry installer-time target packages

**Symptom:** both BIOS and UEFI installs stop in base system installation with "zstd 패키지를 설치할 수 없습니다"; VT4 shows `in-target` failing on `zstd` and `base-installer/kernel/failed-package-install`.

**Cause:** Debian 13's base-installer and grub-installer install packages into the target that are neither in debootstrap's base set nor dependencies of the appliance package list: `zstd` for the initramfs, `efibootmgr` for UEFI NVRAM entries, and `shim-signed`, `grub-efi-amd64-signed` and `mokutil` for Secure Boot. A mirror-only debian-cd image omits them, and the installer has no network fallback.

**Response:** list firmware-neutral ones in `dns.packages` and firmware-specific ones (`grub-pc`, `grub-efi-amd64`, the Secure Boot chain, `dosfstools`) in `dns.downloads`; `engine/installer/dns-image/installer-target-packages` records the full set and `build-image` fails when any is missing from the DVD. A package change needs a full `build-image`; `refresh-guided-iso` only replaces guided files.

## The Secure Boot chain must not be preinstalled on BIOS targets

**Symptom:** the BIOS install fails at "GRUB 부트로더 설치"; VT4 shows `dpkg: error processing package grub-efi-amd64-signed (--purge): this is a protected package`.

**Cause:** simple-cdd installs `dns.packages` on every target. On BIOS, grub-installer purges the grub-efi packages before installing grub-pc, and the protected signed image cannot be purged.

**Response:** carry `shim-signed`, `grub-efi-amd64-signed` and `mokutil` in `dns.downloads` only; grub-installer installs them on UEFI targets.

## simple-cdd postinst scripts run inside the target chroot

**Symptom:** the install finishes, but the system has no operator SSH key, no Technitium and no first-boot enrollment. The installer syslog shows `finish-install: warning: /usr/lib/finish-install.d/14simple-cdd returned error code 1`.

**Cause:** simple-cdd 0.6.9 runs `<profile>.postinst` through `in-target`, where `/cdrom` and `/target` do not exist, and treats its failure as a warning.

**Response:** appliance setup is `scripts/dns-finish-install`, run as `preseed/late_command` in the installer environment, which stops the install on failure. `build-image` rejects any `*.postinst` on the ISO.

## GRUB asks for the BIOS boot device when the USB is attached

**Symptom:** a BIOS install stops at "grub-pc 설정 중입니다 … 부트로더를 설치할 장치".

**Cause:** the installer USB is a second disk, so grub-installer cannot choose the boot device.

**Response:** `install-gate select-disk` sets `grub-installer/bootdev` to the same confirmed disk it gives partman.

## Mock license checkers hid a denied raw build

**Symptom:** `world build-image` prints the `check-license-policy` usage text, then "personal-use license policy denied raw image creation".

**Cause:** the image builders and writers pass their resolved catalog to the checker in `USB_MEDIA_CATALOG`. The checker treated any catalog outside `prebuilt-release` as a usage error. The writer and builder simulations replace the checker with mocks, so the real call was never exercised.

**Response:** only an explicit `--catalog` is prebuilt-only. `license-policy-simulation.sh` now runs the real checker with the environment catalog. After a policy change, build one real raw image before a VM run.

## The text installer font holds only its translations' glyphs

**Symptom:** guided Korean screens render some syllables as boxes, for example `각`, `께`, `량`, `삭` and `함`.

**Cause:** the signed installer's `/usr/lib/unifont.bgf` is reduced to the characters used by Debian Installer translations (3,428 glyphs, 473 Hangul syllables in 13.7). Glyphs used only by our templates are absent.

**Response:** write `guided.templates` Korean text with glyphs present in that font, for example "지워집니다" instead of "삭제합니다" and "크기" instead of "용량". When changing Korean text, extract `install.amd/initrd.gz` from the built ISO and check every non-ASCII template character against the BGF index before a VM run.
