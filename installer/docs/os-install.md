# OS installation

The installer uses Debian Installer preseeding through Simple-CDD. Simple-CDD
places the selected packages and dependencies on the image, so installation does
not require a working Internet connection.

Upstream references:

- [Debian 13 automated installation appendix](https://www.debian.org/releases/trixie/amd64/apb.en.html)
- [Simple-CDD manual](https://manpages.debian.org/trixie/simple-cdd/simple-cdd.1.en.html)

## Safety model

The sample inventory cannot erase a disk. Before partitioning, `install-gate`
requires all of the following:

1. Product name, product SKU, system serial, system UUID, and one NIC MAC hash
   match exactly one of `dns01`, `dns02`, or `dns03`.
2. Exactly one non-removable, non-USB disk matches the expected model hash,
   serial hash, and minimum byte size.
3. The matched disk is not the physical parent of the device that supplied
   `/cdrom`, including a Ventoy device-mapper path.
4. The target and its partitions are not mounted directly or through a block
   mapping or `/dev/disk` alias, are not active swap, and have no sysfs holders.
5. `destructive_install_enabled=true` is present in that node's local inventory.

Only after all five checks pass does the gate clear the first and last 64 MiB
of the target, refresh the kernel partition table, and hand that exact device
to Debian Installer. Mount and swap sources are traced through sysfs ancestry,
including device-mapper and multi-slave devices. This removes stale GPT, RAID,
and EFI signatures without making a standalone unrestricted disk-wipe command
available on the media.

The image stores SHA-256 hashes of hardware identifiers, not their raw values.
The role, address, and network settings are not secret.

## Capture each machine

Boot a trusted Debian live environment and identify the wired interface and the
single internal target disk. From a checkout of this repository, run:

```sh
mkdir -p installer/inventory/local
sudo installer/installer/capture-inventory dns01 10.0.5.1 enp1s0 /dev/sda \
  > installer/inventory/local/dns01.conf
```

Repeat for `dns02` and `dns03`. Review every generated file. Only after confirming
the machine and disk should its final line be changed from `false` to `true`.
For the first physical pilot, enable only `dns01`; disabled role files may remain
as copies of their examples:

```sh
cp installer/inventory/nodes/dns02.conf.example installer/inventory/local/dns02.conf
cp installer/inventory/nodes/dns03.conf.example installer/inventory/local/dns03.conf
```

The builder requires at least one enabled role.

Copy the operator's public SSH key, never the private key:

```sh
cp /path/to/id_ed25519.pub installer/installer/inputs/operator-authorized-keys
```

Create a dedicated age identity on the management machine and copy only its
public recipient into the installer input:

```sh
age-keygen -o /secure/dns-recovery-age-key.txt
age-keygen -y /secure/dns-recovery-age-key.txt \
  > installer/installer/inputs/age-recipient
```

## Build

Build on an amd64 Debian 13 machine with `simple-cdd` installed:

```sh
sudo apt-get install simple-cdd debian-cd debian-archive-keyring \
  reprepro rsync xorriso isolinux syslinux-common skopeo jq curl
installer/installer/fetch-locked-sources
installer/installer/build-image
```

The builder refuses macOS, non-amd64 hosts, missing SSH keys, incomplete
inventory, placeholders in enabled roles, malformed hashes, and a completely
disabled inventory. Build output is written under
`installer/installer/simple-cdd/images/` and remains ignored by Git.

The source lock currently selects Debian 13.7, the `20261011T000000Z` Debian
snapshot, Simple-CDD 0.6.9, and the Technitium 15.6.1 linux/amd64 manifest
digest, plus Tailscale 1.104.1 for linux/amd64 by SHA-256. Build evidence is
emitted under ignored `installer/artifacts/`.

## Add the DNS image to the multiboot USB

Use the root multiboot writer on Linux. It stages the verified DNS image beside
the selected public media and creates `DNS-ENROLL`. It refuses a non-removable
target, the root disk, a missing serial, a checksum mismatch, insufficient
capacity, or an inexact device-and-serial confirmation:

```sh
sudo ./device-os world burn \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

The result contains the selected multiboot media plus `DNS-ENROLL`. Re-identify
the device and serial every time; never copy a previous command without checking
`lsblk`.

## Install behavior

Boot the generated image and deliberately select the installer entry. There is
no automatic boot timeout. After that selection, hardware identity chooses the
role and the remaining Debian installation is unattended. A mismatch stops the
installer before partitioning.

The resulting host has:

- the role hostname and static address;
- a first-boot-generated `operator` password plus the supplied SSH public key;
- root SSH login and SSH password authentication disabled;
- Cockpit on TCP 9090;
- digest-pinned Technitium DNS in a Podman systemd service;
- checksum-pinned Tailscale installed and running but not enrolled;
- nftables allowing DNS and cluster TLS from the LAN while SSH, Cockpit, and
  metrics are restricted to `management_cidr`;
- the installation facts in `/etc/dns-appliance/install.env`.

First boot generates credentials, starts and probes DNS/Cockpit, switches the
host resolver to `127.0.0.1`, validates `public.json`, and atomically writes the
age-encrypted recovery archive. If USB writeback fails, credentials are reused
on retry. Cluster joining intentionally happens later from the management
machine so no shared join secret is embedded in the public installer.

After all three `ACTIVE` records exist, import and cluster them:

```sh
installer/management/import-enrollment \
  --enrollment /Volumes/DNS-ENROLL \
  --identity /secure/dns-recovery-age-key.txt \
  --output /secure/dns-bootstrap

DNS_CLUSTER_CREDENTIALS_DIR=/secure/dns-bootstrap \
DNS_CLUSTER_ACCESS_OUTPUT=/secure/cluster-access.json.age \
  installer/management/cluster-bootstrap
```

Cockpit is then available as `operator` at `https://10.0.5.1:9090` through
`https://10.0.5.3:9090`; retrieve each generated password from the imported
recovery directory and verify the recorded certificate fingerprint first.
