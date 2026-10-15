# Gujo Homelab OS Playbook

This user-owned monorepo playbook is the single source of truth for one homelab World, public OS
metadata, guarded installation-media tooling, and append-only physical USB
generation evidence.

## Source-of-truth boundaries

- `world/` owns mutable operator intent and immutable completed generations.
- `catalog/` owns reusable data-only OS and bootloader metadata.
- `installer/` owns execution, download verification, builders, and destructive
  safety gates.
- The principal secret store owns long-lived credentials and private keys.
- Generated media, caches, real inventory, enrollment output, and recovery
  material remain ignored and outside Git.

Repository consolidation does not weaken these boundaries. Catalog data is
never executable, World intent is never erasure authorization, and Installer
target checks remain independent of both.

## Hard rules

- Never edit, rename, reformat, or overwrite a completed directory under
  `world/worlds/`; create a new physical USB generation.
- Capture the generation timestamp when the resolved World is sealed immediately
  before a target-specific physical write. Publish only after write and readback
  verification succeed.
- Never commit passwords, tokens, private keys, age identities, raw hardware
  identifiers, generated media, vendor binaries, or recovery archives.
- Never write a disk from planning, validation, simulation, or Catalog code.
- A destructive command must independently inspect the live target and require
  the exact target-specific confirmation.
- General OS installers remain interactive. Guarded unattended behavior is
  isolated to the DNS appliance profile.
- Report source, image assembly, physical write, firmware boot, installation,
  and network cutover as separate evidence states.

## Change workflow

- Protect `main` and land substantive work through pull requests.
- Read the nearest module `AGENTS.md` and its referenced standards before
  changing that module.
- Change shared contracts together with every producer, consumer, fixture, and
  document in one pull request.
- Keep documentation and examples in English.
- Do not claim physical qualification from source inspection or CI simulation.
