# DNS Installer Module

This module builds the guarded, offline DNS-appliance image and performs
first-boot enrollment.

- Build only from reviewed immutable locks on the supported amd64 Debian host.
- Never embed an SSH private key, age identity, OAuth secret, plaintext password,
  real inventory outside ignored paths, or cluster join credential.
- Partitioning must be unreachable until exactly one enabled role and one
  non-removable internal disk match all expected identities.
- Never select installer media, a Ventoy mapper, a removable device, zero
  candidates, or multiple candidates.
- A completed role requires a reinstall token bound to its active generation and
  system UUID hash.
- Keep the boot menu free of automatic destructive timeouts.
- First boot generates credentials once and reuses them across retries until
  enrollment commits. Do not rotate or regenerate on every retry.
- Write secrets to USB only inside an age-encrypted archive. Validate public
  output, write temporary files, atomically rename, synchronize, and only then
  mark completion.
- Tailscale is installed offline but remains unenrolled until the management
  host supplies a one-off key.
- A build is not installation proof. Keep VM, physical hardware, power-loss, and
  firmware verification as separate evidence.

