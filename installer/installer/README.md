# Installer source

This directory contains the first implementation of the Debian OS installer:

- `fetch-locked-sources` verifies and caches the pinned Technitium OCI image and
  Tailscale static archive.
- `build-image` builds an offline amd64 image and release evidence on Debian 13.
- `write-usb-linux` writes the verified ISO and appends `DNS-ENROLL` after an
  exact destructive confirmation.
- `capture-inventory` hashes the exact identity of one HP PC, NIC, and disk.
- `simple-cdd/` holds the unattended Debian Installer profile.
- `scripts/install-gate` refuses partitioning unless one inventory entry and one
  internal disk match exactly.
- `payload/` holds the Technitium container service, first-boot enrollment,
  health, backup, firewall, NTP, SSH, and Cockpit integration.

The generated image installs Debian, OpenSSH, Cockpit, nftables, Podman, a
digest-pinned Technitium image, a checksum-pinned Tailscale client, and
operational utilities without Internet access. First boot generates credentials
once, verifies services, and writes age-encrypted recovery secrets plus plaintext
`public.json`, sanitized logs, completion markers, and generation pointers to
`DNS-ENROLL`. Tailscale remains logged out until the management machine supplies
a one-off key after Internet connectivity is available.

See [`docs/os-install.md`](../docs/os-install.md) before building or booting it.
