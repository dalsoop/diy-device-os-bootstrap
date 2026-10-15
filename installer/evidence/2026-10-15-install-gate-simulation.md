# Install-gate simulation — 2026-10-15

## Scope

This record covers the destructive target-selection script only. The test uses
an isolated temporary fake sysfs tree and never opens a real block device.

- Source commit tested: `ee407b3`
- Host: `m5m1`
- Host architecture: `arm64`
- Host OS version: macOS `27.0.1`
- Test command: `tests/install-gate-simulation.sh`

## Result

```text
PASS valid_exact_match
PASS wrong_dmi_is_blocked
PASS disabled_role_is_blocked
PASS duplicate_matching_disks_are_blocked
PASS extra_nonmatching_disk_is_ignored
PASS undersized_disk_is_blocked
PASS removable_target_is_blocked
PASS installer_media_is_never_targeted
PASS duplicate_matching_interfaces_are_blocked
RESULT 9/9 install-gate simulations passed
```

## Remaining evidence gap

No ISO was built or booted. QEMU installation on `m5m1` is currently blocked
because that host has not accepted the Xcode license. BIOS, UEFI, offline package
installation, reboot, SSH, Cockpit, DNS, USB enrollment, and physical `dns01`
behavior remain unverified.
