# DNS Management Module

This module runs from a trusted management host after appliance installation.

- Keep credentials in protected caller-selected files and directories outside
  the repository. Never print tokens or place them in URLs.
- Reader and planner operations are the default. Apply enforces literal
  confirmation, a caller-supplied commit equal to `HEAD`, and a clean zone
  file. Human review and plan comparison remain required because the command
  does not prove approval or consume a saved plan.
- Bootstrap all three nodes only from verified enrollment records. Encrypt the
  resulting access bundle before final placement.
- Tailscale OAuth credentials never leave the management host. Mint one
  non-reusable, pre-authorized, one-hour key per node, send only that key over
  existing SSH, delete its remote file, attempt API revocation, and verify
  restrictive preferences. Revocation is currently best-effort; investigate a
  failed or interrupted enrollment until the one-hour key has expired.
- Backup collection transfers only already-encrypted files. A collected file is
  not a verified restore.
- Restore requires an exact target URL confirmation and one-node-at-a-time
  canary verification.
- Reinstall authorization must bind the active generation and hardware UUID; an
  old token must not authorize a replacement generation.
- The status monitor is read-only and dependency-free. It must not become an
  apply surface.
- Router mutation is outside this module until a model-specific authenticated,
  reversible API and console recovery are proven.

