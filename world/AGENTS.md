# World Module

This module is the user-owned source of homelab intent inside Gujo Homelab
Device Bootstrap. Installer implementation and public Catalog data remain in
sibling modules and are not duplicated here.

## Source-of-truth boundaries

- `world-playbook.yaml` identifies mutable drafts and the generation root.
- The monorepo commit and Catalog tree identify the executable and data inputs;
  completed generations record both identities.
- `drafts/<slug>/world.yaml` is mutable desired state.
- `worlds/<YYYYMMDDHHmmss>-<slug>/` contains completed immutable USB
  generations.
- `local/` is ignored machine-local input and observation data.
- The Installer owns execution and destructive safety gates.
- The Catalog owns reusable public OS URLs, versions, and checksums.
- The principal secret store owns long-lived credentials and private keys.

## Hard rules

- Never edit, rename, reformat, or overwrite a completed generation under
  `worlds/`. Create a new USB generation instead.
- The generation timestamp represents the USB creation event. Do not use draft
  creation, file modification, or Git commit time.
- Publish a generation only after the physical USB write and required readback
  verification succeed. Failed or cancelled writes are attempts, not worlds.
- A repeated physical write creates a new generation even when its desired
  content is identical.
- Never commit passwords, tokens, private SSH keys, age identities, recovery
  archives, raw hardware serials, generated media, packages, or disk images.
- Never weaken Installer target checks or treat a Playbook edit as permission to
  erase a device.
- Do not copy public Catalog metadata or Installer behavior into this module.
- Keep all configured paths relative and contained within their declared World.

## Change workflow

Documentation and examples are English. Record assumptions as unverified until
live evidence exists. Keep source validation, image assembly, physical USB
write, firmware boot, operating-system installation, and network cutover as
separate evidence states.

The module is currently a contract scaffold. Do not claim that the Installer
has validated, built, or written a World until the corresponding command and
evidence exist.
