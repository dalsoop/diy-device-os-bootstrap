# Complete source validation — 2026-10-15

Commit: recorded by CI and pull request after this evidence file is committed.

## Passed locally

- Shell syntax for every executable under `installer/`, `management/`, `build/`,
  and `tests/`.
- ShellCheck with sourced-file following enabled.
- `tests/install-gate-simulation.sh`: 12/12 passed.
- `tests/management-simulation.sh`: 4/4 passed.
- `tests/repository-contract.sh`: passed.
- `build/verify-locks`: passed.
- JSON parsing of `schemas/enrollment-record.schema.json`: passed.
- YAML parsing of both GitHub Actions workflows: passed.
- `git diff --check`: passed.
- Repository secret-pattern scan: no private-key or literal secret finding.

## Not proved by this run

- No ISO was built because this machine is not the required amd64 Debian 13
  builder.
- No systemd unit was executed or verified by `systemd-analyze` on this macOS
  host.
- No physical USB was written.
- No BIOS, UEFI, Secure Boot, power-loss, HP hardware, Cockpit login,
  Technitium cluster, backup/restore, or router DHCP test was performed.

The release and physical pilot gates in `docs/verification.md` remain open.
