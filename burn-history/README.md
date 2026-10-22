# Burn History

This folder is everything you need as the user of this repository. It holds
what you decide about your home, what you keep private on your own
machine, and what has happened so far. Everything else in the repository is
machinery in `engine/` that reads this folder; you do not need to open it.

Editing anything here never creates a USB and never authorizes a destructive
operation. Writes happen only through `./device-os` with a target-specific
confirmation.

```text
burn-history/
├── README.md               this guide
├── .paths.yaml             where the World tools find things (tools only)
├── .in-progress/           burn recorder state (ignored)
├── home.yaml               the home: networks, computers, services, media, policies
├── dns-records.zone        the DNS zone served by the cluster
├── os-installs/
│   └── dns01/ dns02/ dns03/
│       ├── os.conf         guided-install profile of the role (tracked)
│       └── hardware.conf   real hardware capture of the machine (ignored)
├── keys/                   operator SSH public key and age recipient (ignored except README.md)
└── logs/                   what happened; never edited (tracked)
    ├── usb/                successful USB generations
    │   └── failed/         failed or cancelled writes
    └── checks/             verification reports
```

## What to edit

| To change | Edit |
| --- | --- |
| Networks, computers, services, media selections, or policies of the home | [`home.yaml`](home.yaml) |
| The guided-install profile of one DNS role (`dns01`..`dns03`) | `os-installs/<role>/os.conf`, for example [`os-installs/dns01/os.conf`](os-installs/dns01/os.conf) |
| DNS records served by the cluster | [`dns-records.zone`](dns-records.zone) |

Check every change before anything is built:

```sh
./device-os world validate
./device-os world plan
./device-os world simulate
DEVICE_OS_MEDIA=inventory-capture ./device-os world plan
```

The default `dns-install` media selects only `dns-appliance`. The separate
`inventory-capture` media selects only `debian-live`. Both use Korean menu
presentation; the DNS installer itself is also configured for `ko_KR.UTF-8`.

Format examples for the node inventory, the YAML zone description, and the key
files live in [`engine/installer/docs/examples/`](../engine/installer/docs/examples/).
The rules for role profiles and hardware captures are in
[`engine/installer/dns-image/AGENTS.md`](../engine/installer/dns-image/AGENTS.md);
the rules for the zone are in
[`engine/installer/management/AGENTS.md`](../engine/installer/management/AGENTS.md).

## os-installs/ — one folder per DNS role

- `os.conf` is the guided-install network profile of the role. It is tracked,
  keeps installation disabled, and is what a guided build
  (`DNS_APPLIANCE_INSTALL_MODE=guided`) embeds.
- `hardware.conf` is the real hardware capture of the machine, produced by the
  inventory tool on the target device. Git ignores it. A reviewed build (the
  default mode) embeds it, and the Installer rejects a missing, ambiguous,
  stale, or non-matching capture before any destructive operation.

`DNS_APPLIANCE_INVENTORY_DIR` can point a build at another directory that holds
the same per-role folders.

## keys/ — private, never committed

Operator public keys and the age recipient. See [`keys/README.md`](keys/README.md).
Passwords, tokens, private SSH keys, age identities, and recovery archives do
not belong here either; they stay in the principal secret store.

## logs/ — what happened; never edited

`logs/` is written by the tools and is never edited by hand. Every file in it
is tracked; the required check fails if any file here is untracked or matched
by an ignore rule.

- `logs/usb/` holds one immutable generation per successfully verified
  physical USB creation, named `{YYYYMMDDHHmmss}-{world-slug}/`. The timestamp
  is captured in `Asia/Seoul` when the resolved World is sealed immediately
  before the target-specific write. Rewriting identical intent to another USB
  still creates a new generation. See [`logs/usb/README.md`](logs/usb/README.md).
- `logs/usb/failed/` holds redacted records of physical writes that failed
  or were cancelled. It is not a generation, and its records never become
  generations. See [`logs/usb/failed/README.md`](logs/usb/failed/README.md).
- `logs/checks/` holds verification reports for source checks, simulations,
  and VM qualification runs.

`world burn` and `world burn-image-macos` serialize physical attempts. They
stage their working state under the ignored `.in-progress/`, publish a
completed generation only after writer readback passes, and retain redacted
records of unsuccessful attempts. A plan or successful simulation is not
evidence that a physical USB was written.

## .paths.yaml

[`.paths.yaml`](.paths.yaml) tells the World tools where the home definition
(`home.yaml`) and the generation root (`logs/usb`) live, the timezone, and the
generation ID format. Registered paths must stay inside this folder. You do
not need to edit it.
