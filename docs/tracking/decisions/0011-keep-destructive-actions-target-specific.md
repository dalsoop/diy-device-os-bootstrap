# 0011: Keep Destructive Actions Behind Target-Specific Gates

- Status: Accepted
- Date: 2026-10-15

## Context

USB assembly and unattended installation can erase the wrong disk when device
names change, inventory becomes stale, mapper ancestry hides physical media, or
a previous approval is reused. CI cannot identify the device currently attached
to an operator's machine.

## Decision

Planning, validation, capacity calculation, and simulation remain
non-destructive. USB writing requires current live removable-device identity,
root-disk exclusion, serial and capacity checks, verified artifacts, and exact
`ERASE <device> <serial>` confirmation.

DNS installation additionally requires one enabled role, one exact hardware
match, one non-removable internal disk after physical ancestry resolution, and
generation-bound authorization before reinstalling a completed node. Publishing
or building an image never authorizes either physical operation.

## Alternatives

- Device-path-only confirmation was rejected because Linux names can change
  after reconnect or reboot.
- Selecting the first non-removable disk was rejected because multi-disk,
  fixed-bit USB, and mapper configurations make ordering unsafe.
- A permanent reinstall flag was rejected because stale approval could erase a
  later successful generation.
- Treating release publication as write permission was rejected because source
  and CI evidence cannot identify the live target.

## Consequences

Operators perform explicit checks at every destructive boundary and ambiguity
stops rather than selects a likely target. Unattended installation remains
limited to enrolled hardware. Agent convenience cannot bypass these gates, and
physical evidence remains separate from source release evidence.
