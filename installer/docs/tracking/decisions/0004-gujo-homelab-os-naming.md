# 0004: Adopt Gujo Homelab OS Repository Names

Status: Amended by 0007

## Decision

Use **Gujo Homelab OS Installer** for this shared engine and `device-os`
for its human-facing command. Use **Gujo Homelab OS Catalog** for the separate
public metadata repository and **Gujo Homelab OS USB** for the resulting
multiboot device.

Decision 0007 adds **Gujo Homelab World Playbook** as the only ordinary
user-created repository and removes the Installer's fork-oriented role.

Keep `media` only where it identifies an implementation concept such as an ISO,
disk image, removable medium, or the internal `usb-media/` module.

## Consequences

The product vocabulary now reflects the user's task: choose operating systems
and flash a USB. Repository URLs, documentation, schemas, composition metadata,
tests, work paths, and command examples use the new canonical names. The rename
does not weaken any destructive-write confirmation or device-identity gate.
