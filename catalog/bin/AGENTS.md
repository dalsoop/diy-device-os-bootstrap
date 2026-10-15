# Catalog Validation Module

This module is the executable CI enforcement surface for Catalog data.

- Validate both JSON semantics and the closed-world relationship between the
  index and controlled directories.
- Fail on absent files, extra unregistered files, duplicate IDs or paths,
  duplicate source filenames, unknown values, unsafe paths, non-HTTPS URLs, and
  malformed digests.
- Never download media, execute described artifacts, contact a block device, or
  depend on credentials.
- Keep temporary files isolated and removed by traps.
- A new contract rule requires a rejection fixture; a newly allowed shape
  requires a success fixture.
- Keep diagnostics useful without printing sensitive input if the verifier is
  ever reused against a private fork.
