# Getting Started

This is the operator guide for the currently implemented workflow. Run every
command from the repository root unless a section explicitly says otherwise.

## Current implementation boundary

The repository connects the World model, Catalog data, and Installer tooling:

- `./device-os world ...` validates the draft registered in
  `burn-history/.paths.yaml` (`burn-history/home.yaml`) and uses
  its selected media entries.
- the Installer independently validates the resulting World plan, Catalog
  entries, local profiles, and live target before destructive work.
- A physical write that passes readback publishes one immutable directory
  under `burn-history/logs/usb/`; a failed or cancelled write publishes a
  redacted record under `burn-history/logs/usb/failed/`.
- Linux assembles the complete multiboot USB directly. macOS builds an
  exact-size MBR raw image in a Linux container and writes it with verified
  readback.

Do not treat a World edit, plan, capacity result, or simulation as evidence that
a USB was written or a machine was installed.

## 1. Clone or fork the repository

Clone the repository, or fork it and clone your fork:

```sh
git clone https://github.com/dalsoop/diy-device-os-bootstrap.git
cd diy-device-os-bootstrap
```

Keep your own intent in `burn-history/` of your fork. Before merging a change
from this repository into a fork, review the Catalog, Installer, and
safety-policy diff rather than merging it blindly.

## 2. Install planning prerequisites

Read-only World planning needs Git, jq, and Ruby. Capacity probes and downloads
also need curl and a SHA-256 implementation.

On Debian or Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y git jq ruby curl coreutils age
```

On macOS with Homebrew:

```sh
brew install git jq ruby age
```

## 3. Inspect and select media

Validate the World, list the Catalog, and inspect the World selection:

```sh
./device-os world validate
./device-os world available
./device-os world plan
./device-os world simulate
```

These commands do not download images or write a disk.

Check the management host's live network path separately:

```sh
engine/installer/management/network-preflight --json 10.0.0.1/16 | jq
```

The report distinguishes LAN topology and reachability from outbound IP, DNS,
and HTTPS connectivity. Internet is needed to prepare public images and enroll
Tailscale; it is not needed to boot the already-built offline DNS installer.
An Internet pass does not imply that any DNS node is installed or healthy.

Change the media selection in the mutable World draft:

```yaml
spec:
  media:
    - id: dns-install
      entries:
        - dns-appliance
      language: ko-KR
```

The full file is:

```text
burn-history/home.yaml
```

Entry IDs may name public Catalog entries or reviewed Installer-local profiles.
An unknown or duplicate ID is rejected. The contributor-only top-level `include` and
`exclude` commands edit only the contributor reference collection; ordinary
operators should manage their World instead.

## 4. Check USB capacity

An initial estimate may contact vendor HTTPS endpoints for content lengths but
does not download the ISO files:

```sh
./device-os world capacity --capacity 16GB
```

The default composition reports `PENDING` until the DNS runtime ISO and matching
build manifest are supplied. `PENDING` is not a fit decision. After the public
images are prepared and the DNS artifact is built, request an exact result:

```sh
./device-os world capacity --capacity 16GB \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json
```

Use `--offline` when remote size probes are not allowed. Unknown or unverified
sizes remain pending.

## 5. Build the guarded DNS image

Skip this section when `dns-appliance` is not selected by the World. The example
World requires this runtime artifact.

### First pass: capture the three HP inventories

The guarded image cannot be built safely before the target machines are known.
Prepare the non-destructive inventory selection first:

```sh
DEVICE_OS_MEDIA=inventory-capture ./device-os world plan
DEVICE_OS_MEDIA=inventory-capture ./device-os world prepare
```

Burn that selection on Linux using the normal exact removable-device gate. It
contains Debian Live, the inventory capture command, and its guide, but
deliberately contains no DNS installer or unrelated OS image:

```sh
sudo DEVICE_OS_MEDIA=inventory-capture ./device-os world burn \
  --device /dev/sdX \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

Boot each HP into Debian Live and follow `guides/DNS_INVENTORY.md` on the USB.
Copy each resulting `inventory-<role>.conf` file (`dns01` through `dns03`) to
the ignored `burn-history/os-installs/<role>/hardware.conf` on the management host.
This first pass never authorizes internal-disk erasure.

### Second pass: build the production image

The build must run on an amd64 Debian 13 host. Boot each HP machine into a
trusted Debian live environment, identify its wired interface and single
internal target disk, and capture one ignored inventory file at a time:

```sh
sudo engine/installer/dns-image/capture-inventory \
  dns01 10.0.5.1 enp1s0 /dev/sda \
  > burn-history/os-installs/dns01/hardware.conf
```

Repeat for `dns02` and `dns03`. Review every value. For the first physical
pilot, change `destructive_install_enabled` to `true` only in
`os-installs/dns01/hardware.conf`. The disabled guided profiles may be used for
the other two roles:

```sh
cp burn-history/os-installs/dns02/os.conf \
  burn-history/os-installs/dns02/hardware.conf
cp burn-history/os-installs/dns03/os.conf \
  burn-history/os-installs/dns03/hardware.conf
```

Copy only the operator public SSH key and the public age recipient into the
ignored input paths:

```sh
cp /path/to/id_ed25519.pub \
  burn-history/keys/operator-authorized-keys
age-keygen -o /secure/dns-recovery-age-key.txt
age-keygen -y /secure/dns-recovery-age-key.txt \
  > burn-history/keys/age-recipient
```

Install the builder dependencies and build:

```sh
sudo apt-get install -y simple-cdd debian-cd debian-archive-keyring \
  reprepro rsync xorriso isolinux syslinux-common skopeo jq curl
engine/installer/dns-image/fetch-locked-sources
engine/installer/dns-image/build-image
```

The ISO is created under `engine/installer/dns-image/simple-cdd/images/`; its matching
manifest is `engine/installer/artifacts/build-manifest.json`. Both remain ignored by
Git. A successful build is not permission to erase a USB or internal disk.

The default `dns-install` selection contains only the guarded DNS image. The
separate `inventory-capture` selection contains only Debian Live. Re-run exact
capacity and burn the USB a second time with the production DNS ISO and matching
manifest. A superseded or test-only DNS image is never a substitute.

## 6. Prepare public images on Linux

Download the selected public images and Ventoy archive, then verify every
Catalog SHA-256:

```sh
./device-os world prepare
```

The verified cache is ignored by Git. Do not commit downloaded media.

## 7. Identify and burn the USB on Linux

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

Run an exact capacity check with the built DNS artifact before burning. Then
burn the selected public media and guarded DNS image:

```sh
sudo ./device-os world burn \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

This command destroys all existing data on the selected USB. The writer rejects
a non-removable target, the root disk, a missing serial, insufficient capacity,
unverified artifacts, and an inexact confirmation phrase.

## 8. Verify, boot, and install

After burning:

1. From the mounted `DEVICE-OS` root, verify the resolved Catalog and every
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
[`engine/installer/docs/verification.md`](../engine/installer/docs/verification.md) and
[`engine/installer/docs/os-install.md`](../engine/installer/docs/os-install.md).

## 9. Import enrollment and bootstrap the cluster

After all three `ACTIVE` enrollment records exist:

```sh
engine/installer/management/import-enrollment \
  --enrollment /media/DNS-ENROLL \
  --identity /secure/dns-recovery-age-key.txt \
  --output /secure/dns-bootstrap

DNS_CLUSTER_CREDENTIALS_DIR=/secure/dns-bootstrap \
DNS_CLUSTER_ACCESS_OUTPUT=/secure/cluster-access.json.age \
  engine/installer/management/cluster-bootstrap
```

Move imported secrets into the principal secret store and rotate bootstrap
credentials. Apply the router DHCP DNS change only after all node and rollback
gates in [`engine/installer/docs/network-cutover.md`](../engine/installer/docs/network-cutover.md)
pass.

## 10. Connect an external agent without opening a router port

Install the pinned Agent Gateway dependencies on the trusted management host,
keep role-specific DNS token files outside Git, and expose `engine/agent/run` only as a
dedicated SSH forced command. The SSH service must be reachable only through
the reviewed Tailscale policy and host firewall.

The gateway's default tools are read-only validation, planning, capacity,
network, tunnel, and DNS inspection. `network_preflight` checks Internet
connectivity by default; set `check_internet` to `false` for an explicitly
offline report. DNS apply is disabled by default and still
delegates to `dnsctl` when explicitly enabled. USB burn, OS installation,
restore, reinstall authorization, enrollment, arbitrary commands, arbitrary
paths, and arbitrary URLs are never MCP tools.

See [`engine/agent/README.md`](../engine/agent/README.md) for installation, credential paths,
the forced-command example, and MCP client configuration.

## macOS boundary

macOS supports the complete prepare, raw-image assembly, and physical-write
sequence. Podman or Docker supplies the isolated Linux loop-device builder;
the container does not receive a macOS block device:

```sh
./device-os targets
DEVICE_OS_MEDIA=inventory-capture ./device-os world prepare
DEVICE_OS_MEDIA=inventory-capture ./device-os world build-image \
  --output "$PWD/engine/installer/artifacts/inventory-capture.raw" \
  --size EXACT_BYTES
sudo DEVICE_OS_MEDIA=inventory-capture ./device-os world burn-image-macos \
  --image "$PWD/engine/installer/artifacts/inventory-capture.raw" \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME USB_SERIAL EXACT_BYTES'
```

Image creation is non-destructive to physical media. The later writer resolves
the live USB serial again and refuses a stale phrase, an image-manifest mismatch,
a size mismatch, a GPT image, an internal or virtual device, or failed raw
readback. Keep the generated `.raw`, `.raw.sha256`, and `.raw.manifest.json`
together.

## World generation boundary

The intended history key is the physical USB creation time:

```text
burn-history/logs/usb/{YYYYMMDDHHmmss}-{world-slug}/
```

Do not create a completed generation merely because a plan, simulation, build,
or write command started. `world burn` and `world burn-image-macos` publish a
generation atomically only after physical write and required readback evidence
succeed. Failed and cancelled physical attempts are recorded under
`burn-history/logs/usb/failed/YYYY/` without becoming generations.
