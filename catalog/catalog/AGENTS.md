# Catalog Data Module

This module is the complete public registry of bootloaders and media entries.

- Keep one item per JSON file and register every file exactly once in the index.
- Use stable IDs without release numbers. Update versioned fields together.
- Public entries use `locked-download`, HTTPS, lowercase SHA-256,
  `profile_adapter: none`, and interactive or live boot behavior.
- Never add credentials, private locations, generated media, local profiles, or
  unattended disk-erasure policy.
- Paths remain safe, relative, and inside their declared controlled directories.
- Verify checksum provenance from an authoritative vendor source before review.
- A new field or accepted value is a contract change, not an entry-local
  convenience.
- Verify each change with the executable Catalog gate, inspect index/file
  equality, and retain vendor release and checksum provenance in the pull request.
