# Getting Started

This is the operator guide for the currently implemented workflow. Run every
command from the monorepo root unless a section explicitly says otherwise.

## Current implementation boundary

The repository contains a World model, Catalog data, and Installer tooling, but
the three surfaces are not fully connected yet:

- `./device-os` currently selects public media through
  `installer/collections/device-os.json`.
- `world/drafts/<slug>/world.yaml` documents desired state but is not yet an
  input to `device-os`.
- A successful write does not yet publish an immutable directory under
  `world/worlds/` automatically.
- Linux can assemble the complete multiboot USB. macOS can plan and simulate,
  and can write an existing exact-size MBR raw image, but this repository does
  not yet build that raw image.

Do not treat a World edit, plan, capacity result, or simulation as evidence that
a USB was written or a machine was installed.

## 1. Fork and clone

Create a GitHub fork for your homelab, then clone that fork:

```sh
git clone https://github.com/<your-account>/gujo-homelab-device-bootstrap.git
cd gujo-homelab-device-bootstrap
git remote add upstream https://github.com/dalsoop/gujo-homelab-device-bootstrap.git
```

Keep personal intent in your fork. Before adopting an upstream change, review
the Catalog, Installer, and safety-policy diff rather than merging it blindly.

## 2. Install planning prerequisites

Read-only planning needs Git and jq. Capacity probes and downloads also need
curl and a SHA-256 implementation.

On Debian or Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y git jq curl coreutils age
```

On macOS with Homebrew:

```sh
brew install git jq age
```

## 3. Inspect and select media

List the Catalog and inspect the current reference selection:

```sh
./device-os available
./device-os plan
./device-os simulate
```

`available`, `plan`, and `simulate` do not download images or write a disk.

Until World consumption is implemented, change the public-media selection with
the root command:

```sh
./device-os include truenas-scale
./device-os exclude proxmox-ve
git diff -- installer/collections/device-os.json
```

`include` and `exclude` modify a tracked file. Review and commit that change in
your fork. The guarded DNS appliance is an Installer-owned local profile and is
included by the current reference composition independently of these public
entry commands.

The example World remains useful for documenting the intended router, switch,
nodes, addresses, services, and policy:

```text
world/drafts/gujo-home/world.yaml
```

Changing that file alone does not change the resolved media plan.

## 4. Check USB capacity

An initial estimate may contact vendor HTTPS endpoints for content lengths but
does not download the ISO files:

```sh
./device-os capacity --capacity 16GB
```

The default composition reports `PENDING` until the DNS runtime ISO and matching
build manifest are supplied. `PENDING` is not a fit decision. After the public
images are prepared and the DNS artifact is built, request an exact result:

```sh
./device-os capacity --capacity 16GB \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json
```

Use `--offline` when remote size probes are not allowed. Unknown or unverified
sizes remain pending.

## 5. Build the guarded DNS image

Skip this section only if the DNS profile is not part of a future custom
composition. The current reference composition requires this runtime artifact.

The build must run on an amd64 Debian 13 host. Boot each HP machine into a
trusted Debian live environment, identify its wired interface and single
internal target disk, and capture one ignored inventory file at a time:

```sh
mkdir -p installer/inventory/local
sudo installer/installer/capture-inventory \
  dns01 10.0.5.1 enp1s0 /dev/sda \
  > installer/inventory/local/dns01.conf
```

Repeat for `dns02` and `dns03`. Review every value. For the first physical
pilot, change `destructive_install_enabled` to `true` only in `dns01.conf`.
Disabled example files may be used for the other two roles:

```sh
cp installer/inventory/nodes/dns02.conf.example \
  installer/inventory/local/dns02.conf
cp installer/inventory/nodes/dns03.conf.example \
  installer/inventory/local/dns03.conf
```

Copy only the operator public SSH key and the public age recipient into the
ignored input paths:

```sh
cp /path/to/id_ed25519.pub \
  installer/installer/inputs/operator-authorized-keys
age-keygen -o /secure/dns-recovery-age-key.txt
age-keygen -y /secure/dns-recovery-age-key.txt \
  > installer/installer/inputs/age-recipient
```

Install the builder dependencies and build:

```sh
sudo apt-get install -y simple-cdd debian-cd debian-archive-keyring \
  reprepro rsync xorriso isolinux syslinux-common skopeo jq curl
installer/installer/fetch-locked-sources
installer/installer/build-image
```

The ISO is created under `installer/installer/simple-cdd/images/`; its matching
manifest is `installer/artifacts/build-manifest.json`. Both remain ignored by
Git. A successful build is not permission to erase a USB or internal disk.

## 6. Prepare public images on Linux

Download the selected public images and Ventoy archive, then verify every
Catalog SHA-256:

```sh
./device-os prepare
```

The verified cache is ignored by Git. Do not commit downloaded media.

## 7. Identify and write the USB on Linux

The complete multiboot assembly requires Linux, root access, and the utilities
checked by the writer. On Debian or Ubuntu, install the additional runtime
packages:

```sh
sudo apt-get install -y python3 util-linux exfatprogs
```

Connect one disposable USB and identify the whole removable disk. Record the
current device path and serial instead of reusing a previous command:

```sh
lsblk -d -o NAME,MODEL,SERIAL,SIZE,TRAN,RM
```

Run an exact capacity check with the built DNS artifact before writing. Then
write the selected public media and guarded DNS image:

```sh
sudo ./device-os write \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

This command destroys all existing data on the selected USB. The writer rejects
a non-removable target, the root disk, a missing serial, insufficient capacity,
unverified artifacts, and an inexact confirmation phrase.

## 8. Verify, boot, and install

After writing:

1. From the mounted `DEVICE-INST` root, verify the resolved Catalog and every
   staged image:

   ```sh
   sha256sum -c manifests/MEDIA-CATALOG.SHA256
   sha256sum -c manifests/SHA256SUMS
   ```

2. Safely unmount and eject the USB.
3. Prove the Ventoy menu boots on disposable hardware before installing.
4. Install `dns01` first and verify its internal-disk boot, SSH host key, DNS
   over UDP and TCP, Cockpit, Technitium TLS fingerprint, NTP, metrics, and
   encrypted enrollment record.
5. Enable and install `dns02`, then `dns03`, one at a time only after the prior
   node passes its gates.

Use the detailed checklists in
[`installer/docs/verification.md`](../installer/docs/verification.md) and
[`installer/docs/os-install.md`](../installer/docs/os-install.md).

## 9. Import enrollment and bootstrap the cluster

After all three `ACTIVE` enrollment records exist:

```sh
installer/management/import-enrollment \
  --enrollment /media/DNS-ENROLL \
  --identity /secure/dns-recovery-age-key.txt \
  --output /secure/dns-bootstrap

DNS_CLUSTER_CREDENTIALS_DIR=/secure/dns-bootstrap \
DNS_CLUSTER_ACCESS_OUTPUT=/secure/cluster-access.json.age \
  installer/management/cluster-bootstrap
```

Move imported secrets into the principal secret store and rotate bootstrap
credentials. Apply the router DHCP DNS change only after all node and rollback
gates in [`installer/docs/network-cutover.md`](../installer/docs/network-cutover.md)
pass.

## macOS boundary

macOS supports `available`, `plan`, `capacity`, and `simulate`. The command
below writes and verifies an already prepared exact-size MBR full-disk image:

```sh
sudo ./device-os write-image-macos \
  --image /absolute/path/device-os.raw \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME EXACT_BYTES'
```

This repository does not currently provide the Linux/QEMU builder that creates
`device-os.raw`. Use the Linux `./device-os write` workflow for complete USB
assembly until such a builder is implemented and verified.

## World generation boundary

The intended history key is the physical USB creation time:

```text
world/worlds/{YYYYMMDDHHmmss}-{world-slug}/
```

The publication transaction is not implemented. Do not create a completed
generation merely because a plan, simulation, build, or write command started.
A generation is valid only after physical write and required readback evidence
succeed, and the future publication command records that evidence atomically.
