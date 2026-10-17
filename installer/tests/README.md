# Tests

`install-gate-simulation.sh` runs the destructive-selection gate against an
isolated fake sysfs tree. It never opens a real block device.

The 26-case simulation covers:

- one exact HP/NIC/disk match selecting `/dev/sda`;
- wrong DMI identity stopping before selection;
- an erase-disabled role stopping before selection;
- two matching internal disks stopping as ambiguous;
- an additional non-matching disk being ignored;
- an undersized, removable, or USB-transport target being rejected;
- direct and Ventoy-mapped installer media resolving to their physical parent;
- the Ventoy backing disk never being selected as the target;
- unresolved, ambiguous, multi-slave, cyclic, loop, and MD installer ancestry
  failing closed;
- direct, mapper-backed, and `/dev/disk/by-uuid` mounted targets being rejected;
- active swap and unmounted sysfs holders on the target being rejected;
- leading and trailing signature clearing occurring only after acceptance;
- two interfaces with the expected MAC stopping as ambiguous;
- a completed role being blocked without a reinstall token;
- a matching generation-bound reinstall token being accepted;
- a stale reinstall token being rejected.

`repository-contract.sh` validates immutable source lock shapes, required
artifacts, executable modes, the enrollment schema, and the presence of the
first-boot safety contracts. GitHub Actions runs the installer, management,
Tailscale enrollment, media-catalog, and repository-contract simulations plus
ShellCheck and Python syntax validation.

`management-simulation.sh` covers machine-readable and audited DNS planning,
the literal apply confirmation, generation-bound reinstall authorization, and
the `/16` network prerequisite. It stubs network calls and never contacts a DNS
server.

`media-catalog-simulation.sh` also checks capacity planning with
checksum-matched sparse cache files, a runtime artifact with a matching
manifest, an unknown runtime artifact, and a target smaller than the configured
reserve plus overhead. It also proves that an oversized unverified estimate
cannot produce a final too-small verdict when the verified subtotal still fits.
It never opens a block device.

`macos-writer-simulation.sh` replaces every macOS and block-device command with
an isolated fixture. It proves that the writer verifies the image body before
exposing the partition map, verifies the first MiB last, and does not commit or
eject after a failed body readback. It never opens a real device.

This simulation is necessary but not sufficient. It does not replace building
the ISO, booting Debian Installer under BIOS and UEFI, or the physical `dns01`
pilot.
