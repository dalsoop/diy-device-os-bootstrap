# 0003: Keep Destructive Actions Behind Target-Specific Gates

- Status: Accepted
- Date: 2026-10-15

## Context

USB assembly and unattended installation can erase the wrong disk when device
names change, inventory is stale, or a previous approval is reused. CI success
cannot identify a currently attached physical device.

## Decision

Planning and simulation remain non-destructive. USB writing requires a live
removable-device check, root-disk exclusion, serial identity, capacity check,
and exact target-specific erase phrase. DNS installation additionally requires
one exact hardware and internal-disk match, an enabled role, and a
generation-bound authorization for reinstalling completed machines.

Publishing an image never authorizes a physical write or installation.

## Rejected alternatives

- Confirming only by device path was rejected because Linux device names can
  change after reconnect or reboot.
- Selecting the first non-removable disk was rejected because multi-disk and
  mapper configurations make ordering unsafe.
- Reusing a permanent reinstall flag was rejected because stale approval could
  erase a later successful generation.
- Treating release publication as write approval was rejected because CI cannot
  identify the device currently attached to an operator's machine.

## Consequences

Operators must perform more explicit checks, and unattended installation is
limited to enrolled hardware. Ambiguity stops the workflow instead of selecting
a likely target. Physical evidence remains a separate release gate.

