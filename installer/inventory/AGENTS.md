# Hardware Inventory Module

This module contains public examples. Actual hardware captures live only under
ignored `inventory/local/`.

- Never commit raw serials, UUIDs, MAC addresses, disk serials, or enabled
  destructive inventory for real machines.
- Capture inventory from a trusted live environment on the exact target device.
- Review product, NIC, disk, role, address, and minimum size before changing
  `destructive_install_enabled` to true.
- Enable only the current pilot role; expand one machine at a time after physical
  verification.
- Do not edit hashes merely to satisfy the installer. Recapture only after an
  intentional hardware change.
- Fixed addresses are `dns01=10.0.5.1`, `dns02=10.0.5.2`, and
  `dns03=10.0.5.3` unless a coordinated contract decision changes the design.
- Verify examples with isolated install-gate fixtures; verify real captures only
  on the named machine before enabling its one-at-a-time physical pilot.

