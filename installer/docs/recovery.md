# Credentials, backup, and recovery

## Enrollment secrets

Each node creates unique `operator` and Technitium administrator passwords plus
a local static API token. Plaintext secrets exist on the node only until the
recovery archive is committed. The USB stores `recovery.tar.age` for secrets,
but also stores plaintext `public.json`, sanitized install logs, completion
markers, and generation pointers. `public.json` includes raw product, serial,
UUID, MAC, and disk identity, so retain and dispose of the USB as sensitive
operational inventory even though it contains no plaintext password or token.

Import all three completed records on the management machine:

```sh
management/import-enrollment \
  --enrollment /Volumes/DNS-ENROLL \
  --identity /secure/dns-recovery-age-key.txt \
  --output /secure/dns-bootstrap
```

Move the imported files into the principal secret store, rotate credentials
after cluster bootstrap, and remove the temporary directory using the secret
store's documented process.

## Routine backups

Each node creates a daily Technitium API backup, validates the plaintext ZIP,
then encrypts it before writing it under `/var/backups/dns-appliance`. The
temporary plaintext is removed after encryption. Collect those encrypted files:

```sh
management/collect-backups /secure/dns-backups
```

At least monthly, decrypt one recent backup on the management machine, run
`unzip -t`, restore it into an isolated disposable Technitium instance, and
query the canary zone. A file that has merely been copied is not a verified
backup.

## Restore

Restore is intentionally never automatic. Use a limited restore token if the
upstream permission model permits it; otherwise use a time-bounded human-admin
token. The command requires the exact target URL in its confirmation string:

```sh
management/restore-node \
  --url https://10.0.5.1:53443 \
  --token-file /secure/restore-token \
  --backup /secure/dns-backups/dns01/example.zip.age \
  --identity /secure/dns-recovery-age-key.txt \
  --confirm 'RESTORE https://10.0.5.1:53443'
```

After restore, verify UDP/TCP canaries on that node before touching another.

## Reinstall

A completed node cannot be erased by the installer until a token is written for
its current generation:

```sh
management/authorize-reinstall \
  --enrollment /Volumes/DNS-ENROLL \
  --role dns01 \
  --confirm 'ERASE dns01'
```

The token includes the current generation and system UUID hash. It becomes stale
as soon as the replacement installation writes a new `ACTIVE` generation.
