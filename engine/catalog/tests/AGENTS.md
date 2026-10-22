# Catalog Test Module

These tests exercise acceptance and fail-closed behavior using temporary data.

- Never download vendor media, use live credentials, mutate Catalog source
  files, or access block devices.
- Copy fixtures into a temporary root and remove them with a trap.
- Test the executable contract, not only JSON parsing.
- Cover malformed digests, duplicate identities, index/file mismatch, unsafe
  paths, duplicate filenames, and unsupported behavior. Add unknown-field
  fixtures when executable schema parity is implemented.
- A passing test proves metadata validation only; do not claim download, boot,
  installation, firmware, or hardware coverage.
