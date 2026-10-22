# Operations

Run repository commands from the checkout root unless a procedure explicitly changes directories. Do not run a destructive example until its placeholder device, serial, artifact, and credential paths have been replaced from current live inspection.

## Prerequisites and checkout

Planning and simulation require Git, `jq`, and Ruby. Capacity probes and downloads also require `curl` and a SHA-256 implementation. Clone the repository or your fork of it:

```sh
git clone https://github.com/dalsoop/diy-device-os-bootstrap.git
cd diy-device-os-bootstrap
```

On Debian or Ubuntu, install the read-only tool set:

```sh
sudo apt-get update
sudo apt-get install -y git jq ruby curl coreutils age
```

On macOS, install the command tools and one supported Linux container runtime:

```sh
brew install git jq ruby age podman
podman machine init --cpus 4 --memory 4096 --disk-size 100
```

The first `build-image` starts the Podman machine and builds the pinned Debian
13 media-builder container. Docker may be selected with
`--runtime docker`. Ventoy assembly runs against a loop device inside the Linux
VM; only `burn-image-macos` opens the separately confirmed macOS USB. The DNS
installer ISO itself still requires an amd64 Debian 13 build. Windows is
intentionally unsupported and is not a planned preparation or write platform.

## Validate the source checkout

Install the CI tools on Ubuntu, create an isolated Python environment, and run the same non-destructive surfaces used by the required `contracts` job:

```sh
sudo apt-get update
sudo apt-get install -y jq python3-jsonschema ruby shellcheck python3-venv
python3 -m venv /tmp/device-os-agent-check
/tmp/device-os-agent-check/bin/python -m pip install --requirement engine/agent/requirements.lock

engine/catalog/bin/verify-catalog
engine/catalog/tests/catalog-contract.sh
for record in engine/catalog/data/entries/*.json; do
  /usr/bin/python3 -m jsonschema \
    -i "$record" engine/catalog/schemas/media-entry.schema.json
done
for record in engine/catalog/data/bootloaders/*.json; do
  /usr/bin/python3 -m jsonschema \
    -i "$record" engine/catalog/schemas/bootloader.schema.json
done
engine/world/tests/world-contract-simulation.rb
engine/world/tests/usb-event-simulation.rb
(cd engine/installer && tests/install-gate-simulation.sh)
(cd engine/installer && tests/management-simulation.sh)
(cd engine/installer && tests/tailscale-enrollment-simulation.sh)
(cd engine/installer && tests/dns-license-simulation.sh)
(cd engine/installer && tests/license-policy-simulation.sh)
(cd engine/installer && tests/media-catalog-simulation.sh)
(cd engine/installer && tests/image-builder-simulation.sh)
(cd engine/installer && tests/macos-writer-simulation.sh)
(cd engine/installer && tests/inventory-wizard-simulation.sh)
(cd engine/installer && tests/documentation-check-simulation.sh)
(cd engine/installer && tests/repository-contract.sh)
/tmp/device-os-agent-check/bin/python engine/agent/tests/gateway_simulation.py
```

The required CI job additionally validates every published USB record under `burn-history/logs/usb/` and `burn-history/logs/usb/failed/` against the v2 World schemas, and the DNS component registry, component review, build manifest, final review, license decision, and raw-image manifest schemas with both accepted and rejected fixtures. ShellCheck, shell syntax, Python syntax, Ruby syntax, and SPDX checks remain part of CI even when an operator runs only the focused simulations above. A source pass proves no physical media or appliance state.

## Check distribution mode

Personal self-build is allowed for the operator's own devices, but it is not
redistribution approval. Inspect the current decisions without downloading,
building, writing, or uploading anything:

```sh
./device-os license check --mode personal-use --json | jq
./device-os license check --mode source-release --json | jq
```

The first command currently allows the selected media with
`artifact-unreviewed` warnings. The second allows only the clean tracked source
snapshot. The release workflow may retain non-executable checksums, manifests,
package closure, component status, SBOM, and decision evidence for review, but
it never uploads an ISO, RAW, IMG, disk image, or complete USB content and does
not publish a GitHub Release.

Do not attempt prebuilt publication under the current policy. A future public
prebuilt procedure must complete these independent gates:

1. Review each selected bootloader and OS image against its exact version, URL,
   and SHA-256, including license, notices, corresponding source, trademark,
   and all required fulfillment files.
2. Review every DNS component, eliminate `NOASSERTION`, and separately review
   the final DNS ISO against the exact component registry, build manifest,
   SBOM, and obligation-file digests.
3. Enable generated-artifact distribution through a separately reviewed policy
   change and obtain a successful `prebuilt-release` CLI decision.
4. Run publication only behind the protected GitHub Environment
   `prebuilt-distribution`, configured with a human-only required reviewer.

No build, source release, CI result, physical write, or installation promotes
an artifact into the next state automatically. The protected Environment and
its human reviewer remain external configuration and must be verified by the
repository owner before any prebuilt workflow is added.

## Inspect the current World

```sh
./device-os world validate
./device-os world available
./device-os world plan
./device-os world capacity --capacity 16GB
./device-os world simulate
```

These commands do not download an image or write a device. Select the non-default inventory pass by setting the media ID for one invocation:

```sh
DEVICE_OS_MEDIA=inventory-capture ./device-os world plan
DEVICE_OS_MEDIA=inventory-capture ./device-os world simulate
```

Inspect redacted DNS-build blockers and live removable targets separately:

```sh
./device-os world readiness | jq
./device-os targets
```

Edit `burn-history/home.yaml` to change desired devices or media. Keep real hardware captures in the ignored `burn-history/os-installs/<role>/hardware.conf` and keys in the ignored `burn-history/keys/` (private files never committed), never in `home.yaml`.

## Check network readiness

From the management host, inspect the expected `/16` topology, node reachability, and Internet readiness separately:

```sh
engine/installer/management/network-preflight --json 10.0.0.1/16 | jq
engine/installer/management/network-preflight --offline --json 10.0.0.1/16 | jq
```

The offline form marks outbound DNS and HTTPS readiness unknown. Internet is required to fetch public artifacts and enroll Tailscale, but the already-built DNS installer boots and installs offline. A passing Internet probe does not establish LAN routing, node health, or DNS readiness.

## One USB: guided Debian OS and DNS installation

The guided image is a candidate until BIOS and UEFI installation and a disposable `dns01` pilot pass. Build and validate on the build host (amd64 Debian 13):

```sh
DNS_APPLIANCE_INSTALL_MODE=guided engine/installer/dns-image/build-image
DNS_APPLIANCE_INSTALL_MODE=guided engine/installer/dns-image/check-readiness
```

Only operator SSH public keys and the public age recipient enter the image. Keep the corresponding private keys outside the checkout on the management host. The default network profiles retain the planned `10.0.0.0/16` LAN and `10.0.5.1` through `.3`; do not deploy them on a `192.168.0.0/24` LAN without a coordinated network/profile change.

For changes limited to the guided Debian Installer flow (`install-gate`,
`prepare-installer`, `disk-identity`, guided templates, or the shared preseed),
reuse a previously built guided ISO as a disposable VM base. On the build host,
refresh only those files and boot the result directly in the disposable VM:

```sh
sh engine/installer/dns-image/refresh-guided-iso \
  engine/installer/dns-image/simple-cdd/images/BASE_GUIDED.iso \
  engine/installer/artifacts/guided-iteration.iso
```

This replays the base ISO's BIOS/UEFI boot metadata, replaces the five installer
files, checks the embedded bytes and boot-menu timeouts, and prints the new
candidate hash. It skips Simple-CDD package resolution, image assembly, and the
30 GB USB image build. The result deliberately has no production build manifest
and cannot be used for a World USB burn; it is only for disposable VM checks.
Changes to Debian packages, generated payload, network profiles, credentials,
or any other ISO content still require `build-image` to create a release
candidate. After the guided flow passes, run the full build and its manifest
checks once for the exact committed source before preparing production media.

Use the resulting ISO and matching build manifest with the existing `dns-install` World media assembly. Boot the USB deliberately, select the role and connected wired NIC, review the network and internal disk, and type the exact erase phrase shown. Debian and DNS install in that pass; the USB need not return to the management host for an inventory rebuild. An ambiguous, mounted, removable, USB-backed or unreadable internal target blocks installation. Never bypass a rejection by editing a hardware hash.

Keep the USB connected through first boot until encrypted enrollment completes. Qualify and recover `dns01` before repeating for `dns02` and `dns03`. Tailscale enrollment and cluster bootstrap still run from the management host after OS installation. An active role needs its existing generation-bound reinstall token plus a fresh on-target erase confirmation.

The reviewed-inventory path below uses the default `reviewed` mode.

## First pass: capture hardware inventory

Prepare only the `inventory-capture` selection. On Linux, burn it directly:

```sh
DEVICE_OS_MEDIA=inventory-capture ./device-os world prepare
lsblk -d -o NAME,MODEL,SERIAL,SIZE,TRAN,RM
sudo DEVICE_OS_MEDIA=inventory-capture ./device-os world burn \
  --device /dev/sdX \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

On macOS, use the exact byte count printed by `targets` to build first and then
perform a separately confirmed write:

```sh
./device-os targets
DEVICE_OS_MEDIA=inventory-capture ./device-os world prepare
DEVICE_OS_MEDIA=inventory-capture ./device-os world build-image \
  --output "$PWD/engine/installer/artifacts/inventory-capture.raw" \
  --size EXACT_TARGET_BYTES
sudo DEVICE_OS_MEDIA=inventory-capture ./device-os world burn-image-macos \
  --image "$PWD/engine/installer/artifacts/inventory-capture.raw" \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME USB_SERIAL EXACT_TARGET_BYTES'
```

Keep the generated `.raw`, `.raw.sha256`, and `.raw.manifest.json` together.
The manifest binds the image hash to the exact Catalog revision, tree, World
slug, and media ID. The writer rehashes and compares that binding before it
inspects or writes the live target.

The resulting media contains Debian Live only. Boot each HP computer deliberately and follow the inventory guide on the USB. Capture one role at a time from the trusted live environment:

```sh
sudo engine/installer/dns-image/capture-inventory \
  dns01 10.0.5.1 enp1s0 /dev/sda \
  > burn-history/os-installs/dns01/hardware.conf
```

Repeat for `dns02` and `dns03` with their actual interface and disk. Review product, UUID, NIC MAC, disk model, disk serial, size, role, and address. Keep `destructive_install_enabled=false` except for the single current physical pilot.

## Build the offline DNS image

Use an amd64 Debian 13 builder. Copy only the operator's public SSH key and public age recipient into ignored input files:

```sh
cp /path/to/id_ed25519.pub \
  burn-history/keys/operator-authorized-keys
age-keygen -o /secure/dns-recovery-age-key.txt
age-keygen -y /secure/dns-recovery-age-key.txt \
  > burn-history/keys/age-recipient
```

Install build dependencies, verify locked external inputs, fetch the digest-pinned Technitium source, and build:

```sh
sudo apt-get install -y simple-cdd debian-cd debian-archive-keyring \
  reprepro rsync xorriso isolinux syslinux-common skopeo jq curl
engine/installer/build/verify-locks
engine/installer/dns-image/fetch-locked-sources
engine/installer/dns-image/build-image
```

For the guided one-USB path, prefix the build with
`DNS_APPLIANCE_INSTALL_MODE=guided`; the default `reviewed` mode needs the
captured inventories. The first build on an empty cache downloads the whole
offline package set (about 2,100 packages, 1.8 GB) from `snapshot.debian.org`
and takes about 70 minutes on the build host; later builds reuse the mirror and take
minutes.

`build-image` refuses zero or multiple erase-enabled roles. Run
`./device-os world readiness` before the build and keep only the current pilot
set to `destructive_install_enabled=true`.

The ISO appears under `engine/installer/dns-image/simple-cdd/images/`; its matching manifest is `engine/installer/artifacts/build-manifest.json`. Retain the package closure, checksums, SBOM, and build manifest outside Git. A successful build does not authorize a USB write.

## Calculate exact fit and burn production media

Use the exact runtime artifact and matching manifest. A `PENDING` result is not a fit decision:

```sh
./device-os world capacity --capacity 16GB \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json
```

On Linux, install `python3`, block-device tools, and exFAT support. Reconnect one disposable USB, resolve its current whole-disk path and serial, then burn:

```sh
sudo apt-get install -y python3 util-linux exfatprogs
lsblk -d -o NAME,MODEL,SERIAL,SIZE,TRAN,RM
sudo ./device-os world burn \
  --device /dev/sdX \
  --runtime-artifact dns-appliance=/absolute/path/dns-appliance.iso \
  --runtime-manifest dns-appliance=/absolute/path/build-manifest.json \
  --confirm 'ERASE /dev/sdX USB_SERIAL'
```

The command destroys the selected USB. Never reuse a previous device path, serial, or confirmation after a reconnect. The production `dns-install` selection contains only the DNS appliance image.

On macOS, build a raw image from the exact DNS artifact and manifest, then write
it. All paths passed into the container must stay inside this checkout:

An ISO built on the build host goes into
`engine/installer/dns-image/simple-cdd/images/`. Its `build-manifest.json`,
`component-redistribution-registry.json` and `sbom.spdx.json` go together into
`engine/installer/artifacts/`. `world prepare` fetches and verifies the locked Ventoy
release that every World image needs:

```sh
./device-os targets
./device-os world prepare
./device-os world build-image \
  --output "$PWD/engine/installer/artifacts/dns-install.raw" \
  --size EXACT_TARGET_BYTES \
  --runtime-artifact dns-appliance="$PWD/engine/installer/dns-image/simple-cdd/images/DNS_ISO" \
  --runtime-manifest dns-appliance="$PWD/engine/installer/artifacts/build-manifest.json"
sudo ./device-os world burn-image-macos \
  --image "$PWD/engine/installer/artifacts/dns-install.raw" \
  --device /dev/diskN \
  --confirm 'ERASE /dev/diskN MEDIA_NAME USB_SERIAL EXACT_TARGET_BYTES'
```

The image byte size must equal the target and the target must be removable, writable, MBR-compatible, and non-root. World burn commands process one device at a time. Passed readback creates a new tracked generation directory under `burn-history/logs/usb/`; failed or cancelled physical attempts create a tracked redacted event file under `burn-history/logs/usb/failed/`. Review those new files and publish them through the normal pull-request path—the root writer never commits or pushes.

## Verify and install one appliance at a time

From the mounted `DEVICE-OS` partition, verify the resolved input and staged files before boot:

```sh
sha256sum -c manifests/MEDIA-CATALOG.SHA256
sha256sum -c manifests/SHA256SUMS
sha256sum -c manifests/LICENSES.SHA256
```

Boot both BIOS and UEFI paths on disposable media before a production pilot. At the HP machine, choose the DNS entry deliberately and confirm that the reported internal disk serial matches the reviewed inventory. If the USB itself becomes a target or the physical parent is unresolved, stop rather than retry.

After the internal-disk boot, verify host-key fingerprint and key-only SSH, DNS over UDP and TCP, Cockpit, Technitium certificate fingerprint, NTP, metrics, encrypted enrollment output, and the active generation. Keep `dns02` and `dns03` disabled until the preceding role passes every gate.

## Import enrollment and form the DNS cluster

After all three standalone nodes have complete enrollment records:

```sh
engine/installer/management/import-enrollment \
  --enrollment /Volumes/DNS-ENROLL \
  --identity /secure/dns-recovery-age-key.txt \
  --output /secure/dns-bootstrap

DNS_CLUSTER_CREDENTIALS_DIR=/secure/dns-bootstrap \
DNS_CLUSTER_ACCESS_OUTPUT=/secure/cluster-access.json.age \
  engine/installer/management/cluster-bootstrap
```

Move imported values into the principal secret store, rotate bootstrap credentials, and delete temporary plaintext. Verify cluster peers and a DNS canary before enabling another management step.

## Enroll Tailscale

Apply the reviewed tailnet policy first. Then provide protected OAuth file paths:

```sh
TAILSCALE_OAUTH_CLIENT_ID_FILE=/secure/tailscale/client-id \
TAILSCALE_OAUTH_CLIENT_SECRET_FILE=/secure/tailscale/client-secret \
  engine/installer/management/tailscale-enroll --all
```

Confirm each node's hostname, `tag:dns-appliance`, Tailscale address, peer reachability, `accept-dns=false`, and absence of routes, exit-node behavior, Tailscale SSH, Serve, and Funnel.

For remote DNS, use the three enrolled nodes' Tailscale IPv4 addresses as tailnet nameservers, not their `10.0.5.x` LAN addresses. No subnet routing is required. First allow the intended client identities to reach `tag:dns-appliance` on both UDP and TCP 53 in the tailnet policy. The appliance recursion ACL includes `100.64.0.0/10`; nftables accepts DNS on `tailscale0` and rejects that source range on other network interfaces.

Before changing tailnet DNS, run `dig @<node-tailscale-ip> home.arpa SOA` and `dig @<node-tailscale-ip> example.com A` from an approved remote client for each node, then repeat both with `+tcp`. Check that an unauthorized peer cannot query them. These live checks require installed, enrolled appliances and are separate from source simulations.

Choose restricted nameservers for `home.arpa` when only internal names should use the appliances. To send public lookups through them as well, configure global nameservers and enable the tailnet DNS override on clients. Keep all three appliances on `--accept-dns=false` to avoid making their own resolver depend on this client configuration. All three nameservers must serve the same intended data; listing them does not establish strict primary/secondary query order. Technitium web administration still uses the LAN listener or a verified SSH tunnel to loopback.

## DNS change and router cutover

Check health, create a plan, compare it with the reviewed zone change, then apply from the exact approved clean commit using the command's literal confirmation:

```sh
export TECHNITIUM_URL=https://10.0.5.1:53443
export TECHNITIUM_TOKEN_FILE=/secure/dns/reader-token
export TECHNITIUM_CA_FILE=/secure/dns/technitium-ca.pem
engine/installer/management/dnsctl health

export TECHNITIUM_TOKEN_FILE=/secure/dns/planner-token
engine/installer/management/dnsctl plan burn-history/dns-records.zone \
  --out /secure/dns/plans/<new-plan>.json

export TECHNITIUM_TOKEN_FILE=/secure/dns/applier-token
engine/installer/management/dnsctl apply \
  --plan /secure/dns/plans/<new-plan>.json \
  --plan-sha256 <plan_sha256> \
  --confirm APPLY
```

Save the plan from a clean checkout of the reviewed commit and review it; `plan --out` prints its `plan_sha256` on stderr. Apply rejects a different hash, endpoint, `HEAD`, or zone file, a live zone that changed since the plan, and a plan already applied; in each case make and review a new plan. Verify pull-request approval before apply; the command does not prove it. Change one logical zone operation at a time and query the canary over UDP and TCP before continuing.

Router DHCP DNS changes are last. Record old values, retain a wired recovery client, advertise all three resolver addresses, renew one test lease, and observe a full lease cycle. If client resolution fails, restore the old DHCP DNS values before investigating the nodes.

## Backup, restore, and reinstall

Collect only already-encrypted backups:

```sh
engine/installer/management/collect-backups /secure/dns-backups
```

Periodically decrypt and restore one in an isolated Technitium environment; file presence alone is not recovery proof. The current restore command always disables TLS certificate verification. Use it only for an isolated restore drill; it is not qualified for a production node until trusted-CA or pinned-fingerprint verification is implemented. The drill still binds confirmation to the exact target URL:

```sh
engine/installer/management/restore-node \
  --url https://restore-lab.local:53443 \
  --token-file /secure/dns/restore-token \
  --backup /secure/dns-backups/dns01/backup.zip.age \
  --identity /secure/dns-recovery-age-key.txt \
  --confirm 'RESTORE https://restore-lab.local:53443'
```

Verify the restored canary and remove the isolated lab plaintext afterward; do not target a production node with this command. A completed appliance can be reinstalled only after a generation-bound authorization is written:

```sh
engine/installer/management/authorize-reinstall \
  --enrollment /Volumes/DNS-ENROLL \
  --role dns01 \
  --confirm 'ERASE dns01'
```

## Deploy the Agent Gateway

Use a dedicated non-sudo management-host account and a checkout at `/srv/diy-device-os-bootstrap`. Create a Python 3.10-or-newer environment outside the checkout and install only the locked dependencies:

```sh
sudo useradd --create-home --shell /bin/sh device-agent
sudo install -d -o device-agent -g device-agent /opt/device-os-agent
sudo -u device-agent python3 -m venv /opt/device-os-agent/venv
sudo -u device-agent /opt/device-os-agent/venv/bin/python -m pip install \
  --requirement /srv/diy-device-os-bootstrap/engine/agent/requirements.lock
```

Provision mode-0600 reader, planner, and optional applier token files readable by only `device-agent`; provision the trusted Technitium CA separately. Set the fixed gateway variables in the account's reviewed host-side environment and never accept them from the SSH client:

```sh
DEVICE_OS_AGENT_PYTHON=/opt/device-os-agent/venv/bin/python
DEVICE_OS_AGENT_DNS_READER_TOKEN_FILE=/secure/dns/reader.token
DEVICE_OS_AGENT_DNS_PLANNER_TOKEN_FILE=/secure/dns/planner.token
DEVICE_OS_AGENT_DNS_APPLIER_TOKEN_FILE=/secure/dns/applier.token
DEVICE_OS_AGENT_TECHNITIUM_CA_FILE=/secure/dns/technitium-ca.pem
DEVICE_OS_AGENT_DNS01_URL=https://dns01:53443
DEVICE_OS_AGENT_DNS02_URL=https://dns02:53443
DEVICE_OS_AGENT_DNS03_URL=https://dns03:53443
```

Omit the applier token and `DEVICE_OS_AGENT_ALLOW_APPLY` for the initial read-only deployment. Add the client's public key to the dedicated account with a forced command:

```text
restrict,command="/srv/diy-device-os-bootstrap/engine/agent/run" ssh-ed25519 AAAA... operator-agent
```

The SSH server must not use `AcceptEnv` for gateway variables. Tailnet ACL and the host firewall permit only the reviewed client identity to reach this account's SSH port; no router port is forwarded. Configure the remote MCP client to invoke ordinary SSH:

```json
{
  "mcpServers": {
    "device-os": {
      "command": "ssh",
      "args": ["-T", "device-agent@management-host"]
    }
  }
}
```

Verify the isolated tool boundary and then the live forced-command path:

```sh
/opt/device-os-agent/venv/bin/python \
  /srv/diy-device-os-bootstrap/engine/agent/tests/gateway_simulation.py
ssh -T device-agent@management-host
```

Prove repository, World, capacity, network, tunnel, DNS health, and DNS plan calls first. Confirm physical-media, installation, restore, enrollment, arbitrary command, path, and URL tools are absent. Only after trusted TLS and rollback are proven may the host administrator add the applier token, set `DEVICE_OS_AGENT_ALLOW_APPLY=1`, and run one separately approved canary apply.

## Runtime configuration

| Name | Role and allowed scope |
| --- | --- |
| `DEVICE_OS_MEDIA` | Selects one declared World media ID for the current invocation; current values are `dns-install` and `inventory-capture` |
| `DEVICE_OS_WORLD` | Selects an explicit draft when more than one exists; path must remain within `burn-history/` as registered in `burn-history/.paths.yaml` |
| `DEVICE_OS_WORLD_PLAN` | Installer working path for a resolved World plan; generated, not committed |
| `USB_MEDIA_CATALOG` | Installer working path for the resolved media plan; generated, not committed |
| `USB_MEDIA_CACHE_DIR` | Ignored cache for verified bootloader and public OS downloads; changing it does not bypass digest checks |
| `DNS_APPLIANCE_INVENTORY_DIR` | Directory that holds the per-role folders (`dns01/`, `dns02/`, `dns03/`) used by the DNS image build and readiness check; defaults to `burn-history/os-installs`. Reviewed mode reads `<dir>/<role>/hardware.conf` (ignored real captures); guided mode reads `<dir>/<role>/os.conf` |
| `DNS_APPLIANCE_AUTHORIZED_KEYS` | File containing only the operator's public SSH key material for the image; defaults to `burn-history/keys/operator-authorized-keys` |
| `DNS_APPLIANCE_AGE_RECIPIENT` | File containing only the public age recipient used to encrypt enrollment output; defaults to `burn-history/keys/age-recipient` |
| `DNS_APPLIANCE_CACHE_DIR` | Ignored cache for digest-pinned DNS runtime inputs; defaults to `engine/installer/cache/` |
| `DNS_APPLIANCE_ARTIFACT_DIR` | Ignored destination for build manifests, checksums, package closure, and SBOM; defaults to `engine/installer/artifacts/` |
| `DNS_CLUSTER_CREDENTIALS_DIR` | Protected management-host directory containing imported node credentials |
| `DNS_CLUSTER_ACCESS_OUTPUT` | Protected destination for the encrypted cluster access bundle |
| `DNS_CLUSTER_AGE_RECIPIENT` | Public age-recipient file used for the encrypted cluster access bundle; defaults to `burn-history/keys/age-recipient` |
| `DNS_CLUSTER_DOMAIN` | Cluster domain override; defaults to `dns-cluster.home.arpa` and must match reviewed DNS intent |
| `DNS_CLUSTER_ZONE_FILE` | Reviewed zone-file override; defaults to the tracked `burn-history/dns-records.zone` |
| `DNSCTL_AUDIT_LOG` | Protected append-only destination for redacted DNS plan/apply events |
| `TECHNITIUM_URL` | Direct management-command target URL; callers use reviewed fixed node endpoints, not arbitrary agent input |
| `TECHNITIUM_TOKEN_FILE` | Protected role-specific token file for direct management commands |
| `TAILSCALE_OAUTH_CLIENT_ID_FILE` | Protected file containing the OAuth client ID; value must not be passed directly |
| `TAILSCALE_OAUTH_CLIENT_SECRET_FILE` | Protected file containing the OAuth secret; value must not be passed directly |
| `TECHNITIUM_CA_FILE` | Trusted CA bundle required for DNS apply through the agent path |
| `DEVICE_OS_AGENT_STATE_DIR` | Protected management-host runtime state directory for the gateway |
| `DEVICE_OS_AGENT_DNS_READER_TOKEN_FILE`, `DEVICE_OS_AGENT_DNS_PLANNER_TOKEN_FILE`, `DEVICE_OS_AGENT_DNS_APPLIER_TOKEN_FILE` | Fixed protected files for separate DNS authorities; token values are never environment variables |
| `DEVICE_OS_AGENT_DNS01_URL`, `DEVICE_OS_AGENT_DNS02_URL`, `DEVICE_OS_AGENT_DNS03_URL` | Administrator-fixed appliance URLs; callers cannot supply URLs through tools |
| `DEVICE_OS_AGENT_TECHNITIUM_CA_FILE` | Administrator-fixed trusted CA path forwarded as `TECHNITIUM_CA_FILE` for apply |
| `DEVICE_OS_AGENT_ALLOW_APPLY` | Management-host policy switch; the tool remains discoverable, but only literal `1` permits execution and all delegated gates still run |
| `DEVICE_OS_AGENT_TAILSCALE_COMMAND` | Administrator-fixed absolute executable path for read-only tunnel status; never a tool argument |

The principal secret store remains intentionally implementation-neutral. All concrete paths in examples are operator-selected protected locations outside the checkout.
