# Licenses

This repository is licensed under the GNU GPL version 3 in the root
[`LICENSE`](../../LICENSE). Everything else license-related lives here.

| File | Purpose |
| --- | --- |
| [`LICENSE_HISTORY.md`](LICENSE_HISTORY.md) | The MIT-to-GPL transition boundary and what each earlier revision may be used under |
| [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) | Upstream components, their licenses, and how generated media carry their notices |
| [`Tailscale-BSD-3-Clause.txt`](Tailscale-BSD-3-Clause.txt) | The Tailscale client license text shipped with every DNS image and USB |

The DNS image build and both USB writers copy these files into generated media
and fail when one is missing. They install them under the same file names on
the USB (`licenses/`) and on the target (`/usr/share/doc/diy-device-os-bootstrap/`).
When adding or renaming a file here, update `engine/installer/dns-image/build-image`,
`engine/installer/usb-media/write-usb-linux`, the `contracts` workflow and
`engine/installer/tests/repository-contract.sh` together.
