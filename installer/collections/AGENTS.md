# Collection Module

This module records which public Catalog entries a Installer fork includes and
how they are grouped on the USB.

- Store stable entry IDs only; do not copy vendor URLs, versions, or checksums
  from the Catalog.
- Group IDs and paths are unique, safe relative paths.
- Adding or removing an entry changes user-visible media composition and must be
  reviewed with the resolved plan.
- Selection does not change an entry's boot behavior or grant unattended
  installation.
- Keep fork-specific choices here instead of editing shared resolver code.
- Verify every selection change with a resolved plan and confirm that omitted
  entries, menu groups, DNS reserve, and capacity still match intent.

