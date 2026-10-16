# DIY Device OS Bootstrap

This user-owned device-OS bootstrap monorepo is the single source of truth for one
homelab World, public OS metadata, guarded installation-media tooling, and
append-only physical USB generation evidence.

## Source-of-truth boundaries

- `world/` owns mutable operator intent and immutable completed generations.
- `catalog/` owns reusable data-only OS and bootloader metadata.
- `installer/` owns execution, download verification, builders, and destructive
  safety gates.
- `agent/` owns the constrained management-host MCP access plane and delegates
  execution to reviewed root and Installer commands.
- The principal secret store owns long-lived credentials and private keys.
- Generated media, caches, real inventory, enrollment output, and recovery
  material remain ignored and outside Git.

Repository consolidation does not weaken these boundaries. Catalog data is
never executable, World intent is never erasure authorization, and Installer
target checks remain independent of both.

The Agent Gateway does not add authority: it cannot expose arbitrary execution
or any media, installation, restore, reinstall, or enrollment operation.

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
- Agents may create a branch, push it, open a pull request, and monitor required
  checks, but they must stop after reporting the green pull request. An agent
  must not merge, enable auto-merge, bypass protection, or use an administrator
  override unless the repository owner gives an explicit merge instruction
  after that pull request exists and its check state is known. Earlier general
  requests such as "proceed", "finish", or "build it" are not merge approval.
- Read the nearest module `AGENTS.md` and its referenced standards before
  changing that module.
- Change shared contracts together with every producer, consumer, fixture, and
  document in one pull request.
- Keep documentation and examples in English.
- Do not claim physical qualification from source inspection or CI simulation.
