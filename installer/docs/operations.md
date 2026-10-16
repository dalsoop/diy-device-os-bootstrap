# Operations

Run every command in this document from the monorepo root.

## Supported environments

World and Catalog planning need Git, jq, and Ruby. Image download additionally
needs curl and a SHA-256 implementation. Physical USB assembly runs on Linux with root access,
Ventoy tooling, block-device utilities, and exFAT support. The DNS ISO builds on
amd64 Debian 13 with Simple-CDD and the packages named by the build command.

macOS may inspect, select, simulate, query device capacity, and write a prepared
size-matched MBR full-disk image with `diskutil`, `plutil`, `dd`, and `cmp`.
This repository does not yet provide the builder for that raw image. Linux
device-capacity queries use `blockdev`; complete USB assembly and the DNS ISO
build remain Linux-only.

## Safe planning workflow

```sh
./device-os world validate
./device-os world available
./device-os world plan
./device-os world capacity --capacity 16GB
./device-os world simulate
```

These commands read and validate the sibling Catalog but do not download ISO
images or write a block device. Review entry behavior, the monorepo commit,
Catalog tree, USB labels, and whether the DNS profile is present.

For an exact DNS-inclusive result, supply the built runtime artifact:

```sh
./device-os world capacity --capacity 16GB \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json
```

A pending or estimate result means one or more artifact sizes are unknown or
not checksum-verified. It is not permission to write. After `prepare`, public
image sizes come from the verified local cache and can be calculated offline.

Change selection by editing `world/drafts/<slug>/world.yaml`, then rerun
`world validate` and `world plan`. The top-level `include <id>` and
`exclude <id>` commands modify only the Installer reference collection for
contributors.

## Prepare public images

On the Linux builder:

```sh
./device-os world prepare
```

Preparation resolves the exact monorepo and Catalog tree, downloads only
`locked-download` sources, verifies SHA-256 before finalizing cache files, and
rechecks cached files. A failed or partial download is not promoted.

## Build the DNS runtime artifact

Create ignored local inventory for each intended machine, copy only an operator
public key and age recipient into the named input paths, and enable destructive
installation for the current pilot role only.

```sh
sudo apt-get install simple-cdd debian-cd debian-archive-keyring \
  reprepro rsync xorriso isolinux syslinux-common skopeo jq curl
installer/installer/fetch-locked-sources
installer/installer/build-image
```

The build must run on amd64 Debian 13. Retain the ISO, build manifest, package
closure, checksums, and SBOM outside Git. A successful build is not permission
to write media.

## Burn a DIY Device OS USB

Immediately before burning, inspect the attached devices and identify the
removable target by path and serial. Unplug ambiguous devices. Use absolute
paths for runtime artifacts.

```sh
sudo ./device-os world burn \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

The operation destroys the selected USB. Never reuse a prior command without
resolving the target again. After writing, verify the copied resolved catalog,
its digest, and every entry in `manifests/SHA256SUMS`, then safely unmount and
eject.

## Install and enroll DNS appliances

Install one machine at a time. Start with `dns01`; keep `dns02` and `dns03`
disabled until the prior node passes its physical gates. Boot the DNS menu entry
deliberately and confirm the target disk serial at the machine.

After each internal-disk boot, verify SSH host fingerprint and key login, DNS
UDP/TCP, Cockpit, Technitium TLS fingerprint, NTP status, metrics, and the
encrypted enrollment generation. Do not call the installation complete before
all checks pass.

When all three records are complete:

```sh
installer/management/import-enrollment \
  --enrollment /Volumes/DNS-ENROLL \
  --identity /secure/dns-recovery-age-key.txt \
  --output /secure/dns-bootstrap

DNS_CLUSTER_CREDENTIALS_DIR=/secure/dns-bootstrap \
DNS_CLUSTER_ACCESS_OUTPUT=/secure/cluster-access.json.age \
  installer/management/cluster-bootstrap
```

Move imported material into the long-lived secret store and rotate bootstrap
credentials. Do not keep a temporary plaintext directory longer than required.

## Tailscale enrollment

Apply a reviewed policy that constrains `tag:dns-appliance`, then provide the
management command with protected OAuth credential files:

```sh
TAILSCALE_OAUTH_CLIENT_ID_FILE=/secure/tailscale/client-id \
TAILSCALE_OAUTH_CLIENT_SECRET_FILE=/secure/tailscale/client-secret \
  installer/management/tailscale-enroll --all
```

Enrollment is complete only after hostname, tag, address, peer reachability, and
the absence of DNS, route, exit-node, and SSH authority are verified.

## DNS changes and rollback

Use `installer/management/dnsctl health`, then create and review a machine-readable
plan. Apply with a caller-supplied commit equal to current `HEAD`, a clean zone
file, and explicit confirmation. Because the command does not consume the saved
plan or prove pull-request approval, the operator must compare the reviewed
plan and verify approval immediately before apply. Change one logical zone
operation at a time and query the canary over UDP and TCP.

Router DHCP DNS changes occur last. Record old values, retain a wired recovery
client, advertise all three resolvers, renew one test lease, and observe a full
lease cycle. On failure, restore previous DHCP DNS values first.

## Backup, restore, and reinstall

Collect only encrypted backups with `installer/management/collect-backups`. Periodically
prove one backup by decrypting and restoring it in an isolated environment.

A production restore requires an explicit target URL and
`RESTORE <exact-url>`. Verify canaries before touching another node.

A completed node can be reinstalled only after
`installer/management/authorize-reinstall` writes a token for its active generation.
That authorization expires logically when a replacement generation becomes
active.

## Release evidence

Release evidence records the exact Git commit, Catalog tree identity, source
locks, build environment, commands, checksums, package closure, SBOM, and
observed gate results. Publish checksums and manifests, not ignored media or
credentials. If any physical or network gate remains incomplete, label the
candidate accordingly.

