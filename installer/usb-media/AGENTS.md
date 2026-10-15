# USB Media Module

This module resolves the sibling data-only Catalog with the reference choices
and writes the resulting multiboot USB.

- Treat external Catalog files as untrusted data. Never execute fetched code.
- Record the exact monorepo commit and Catalog tree. Accept an external
  unpinned Catalog only when an isolated test explicitly opts in.
- Keep entry handling driven by the resolved plan. Do not add product-name
  branches for entries that fit an existing source kind.
- Reject unknown source kinds, profile adapters, duplicate IDs or destinations,
  unsafe configured paths, malformed digests, and inconsistent DNS reserves.
- Do not add symlinks to repository bundles. The current staging path follows
  symlinks and does not prove that their resolved targets stay in the checkout.
- `plan` and `simulate` must not download images or write block devices.
- `calculate-capacity` may inspect files, device size, or remote headers but
  must never write a device or download a complete image. Unknown artifacts
  produce an indeterminate result, not an assumed size.
- Promote a download only after its SHA-256 passes; remove partial files on error.
- The writer may target only a removable, non-root device with a readable serial,
  enough capacity, and the exact `ERASE <device> <serial>` confirmation.
- Runtime artifacts require an absolute caller path and a matching build
  manifest. Repository bundles must stay inside the checkout.
- Preserve the resolved plan and complete image checksum manifest on the USB.
- Add success and rejection simulations whenever a source kind, adapter, path
  rule, partition rule, or destructive gate changes.

