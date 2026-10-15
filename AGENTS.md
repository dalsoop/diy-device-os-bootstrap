# Device Install Media Catalog

This repository is the public, data-only catalog consumed by Device Install
Media Builder.

## Safety invariants

- Never commit credentials, private keys, tokens, generated media, or vendor
  images.
- Every downloadable artifact must use HTTPS and include a lowercase SHA-256
  digest obtained from an authoritative vendor source.
- Keep one bootloader or media entry per JSON file. Do not hide product-specific
  behavior in validation scripts.
- Entry identifiers are stable. A version update changes the entry contents,
  not its identifier.
- Pull requests must pass the catalog contract before merge.

## Repository boundary

- This repository describes available bootloaders and installation media.
- Selection, local profiles, downloads, USB layout, and disk writes belong in
  `dalsoop/device-install-media-builder`.

