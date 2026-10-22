# Verification and release gates

No source review or unit simulation guarantees that an installer can safely
erase and rebuild physical hardware. Complete every gate in order and attach
logs, checksums, screenshots, and resulting `public.json` files to the release
evidence.

## Automated source gates

- `tests/install-gate-simulation.sh` passes every reviewed and guided case,
  including direct partition media, Ventoy's `/dev/mapper/Ventoy` ancestry,
  unresolved, ambiguous, multi-slave, cyclic, loop, and MD ancestry, fixed-bit
  USB targets, direct, mapper-backed, and `/dev/disk` alias mounts, active
  swap, sysfs holders, the synchronization step, and zero writes on every
  rejection.
- `tests/management-simulation.sh` passes all 18 cases, including explicit
  offline Internet state, saved immutable DNS plans, plan-bound apply with
  hash, endpoint, commit, zone, drift, and replay rejection, generated
  LAN/Tailscale recursion permissions, public-client rejection, and the
  firewall's Tailscale source-address guard.
- `tests/tailscale-enrollment-simulation.sh` passes without printing either
  OAuth or auth-key material.
- `tests/media-catalog-simulation.sh` rejects duplicate identities, unknown
  strategies/adapters, path traversal, and invalid digests, then proves that a
  new standard ISO reaches the Ventoy menu through catalog data alone.
- `tests/repository-contract.sh` passes.
- ShellCheck reports no errors.
- GitHub CI passes on the exact commit to be built.
- `build/verify-locks` passes and the fetched OCI manifest matches the amd64
  digest.

## Build gates

- Build on an amd64 Debian 13.7 host with Simple-CDD 0.6.9.
- Build twice from clean ignored directories and compare ISO, package closure,
  manifest, and SBOM.
- Verify the ISO checksum before and after USB writing.
- Inspect BIOS and UEFI boot files; verify signed Secure Boot components.
- Verify the embedded Tailscale archive SHA-256 and installed client version.

## Virtual-machine gates

- BIOS install with networking disconnected.
- UEFI and Secure Boot install with networking disconnected.
- Wrong DMI, wrong MAC, wrong disk serial, two matching disks, removable disk,
  missing `DNS-ENROLL`, completed role, stale reinstall token, and corrupt exFAT
  all stop before erase.
- Power loss after credential generation, during encrypted output, after final
  record rename, and before local completion converges without changing secrets.
- Reboot with the USB attached does not start another installation.
- Boot the DNS ISO from Ventoy and prove its mapper device and physical USB
  cannot become the selected internal target.
- After a successful install, inspect the removed USB and prove that its Ventoy
  partition map and checksums are unchanged.

## Physical dns01 pilot

- Photograph and record the HP product number, wired NIC, target disk, firmware
  mode, Secure Boot state, and boot order.
- Capture inventory from a trusted live system and enable only `dns01`.
- Confirm the erase target by serial immediately before selecting install.
- Verify internal-disk boot, SSH host fingerprint, SSH key login, sudo, Cockpit
  login, Technitium TLS fingerprint, DNS UDP/TCP, NTP, metrics, and encrypted
  enrollment.
- Decrypt recovery on the management machine and prove the Cockpit password.
- Run one encrypted backup and isolated restore drill.
- Enroll with a one-off tagged Tailscale key, verify `accept-dns=false`, no
  routes/exit-node/Serve/Funnel/SSH, management-port ACLs, `tailscale ping`, and
  keyless reconnection after reboot.

## Selected Device OS USB gates

- Verify Ventoy and every entry selected by the resolved World against the
  recorded SHA-256 before copying. Catalog availability alone does not place an
  entry on the USB.
- Verify `manifests/MEDIA-CATALOG.SHA256` and retain the exact catalog copied to
  the USB with release evidence.
- Verify every copied ISO using the USB's generated `manifests/SHA256SUMS`.
- Test BIOS (non-UEFI) and UEFI menus; treat Secure Boot as failed until the
  exact HP firmware and every selected image boot successfully.
- Prove all menu entries require deliberate selection. The current
  `inventory-capture` pass contains only Debian Live; the current `dns-install`
  pass contains only the guarded DNS image.
- If Proxmox VE, Proxmox Backup Server, TrueNAS SCALE, or Pop!_OS is selected in
  a future generation, qualify that exact release on disposable media and prove
  it remains interactive before production use.
- Run the bundled DNS appliance status monitor and confirm it reports DNS UDP,
  DNS TCP, Cockpit, Technitium, and metrics for all three nodes.
- On `dns-install`, verify `DNS-ENROLL` survives boot and accepts only the DNS
  appliance's encrypted enrollment output. `inventory-capture` reserves no DNS
  enrollment partition.

Only after dns01 passes should dns02 and dns03 be enabled one at a time. Cluster
and router DHCP cutover are separate final gates. Publishing or writing a new
physical USB always requires a fresh target check and explicit erase approval.
