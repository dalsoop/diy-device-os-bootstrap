# Device OS Catalog

[![CI](https://github.com/dalsoop/device-os-catalog/actions/workflows/ci.yml/badge.svg)](https://github.com/dalsoop/device-os-catalog/actions/workflows/ci.yml)

A public, data-only catalog of bootloaders, operating-system installers, and live
environments for device installation media. It stores official HTTPS download
locations, release versions, SHA-256 values, menu descriptions, and boot
behavior. It does not store or download ISO images.

[Device OS Flasher](https://github.com/dalsoop/device-os-flasher)
pins an exact Catalog commit, selects entries, verifies downloads, and assembles
the physical USB.

## Layout

```text
catalog/
├── index.json
├── bootloaders/
│   └── ventoy.json
└── entries/
    ├── debian-live.json
    ├── pop-os.json
    ├── proxmox-backup-server.json
    ├── proxmox-ve.json
    └── truenas-scale.json
```

Each product has an independent file. `catalog/index.json` is the closed-world
registry: every JSON item is listed exactly once, and unregistered files fail
validation.

## Contribute an entry

1. Fork this repository.
2. Add `catalog/entries/<stable-id>.json`.
3. Register the same ID and path in `catalog/index.json`.
4. Verify the URL and SHA-256 against an authoritative vendor source.
5. Run `bin/verify-catalog` and open a pull request.

Private images, organization-only URLs, credentials, hardware inventory, and
automatic-install profiles do not belong here. Keep them in a Flasher fork.

## Contract summary

- IDs use lowercase letters, digits, and hyphens and do not include a release.
- Downloads use HTTPS and a lowercase 64-character SHA-256.
- Destinations are safe relative `images/...iso` paths.
- Public media is either `interactive-installer` or `live-environment`.
- Public entries use `profile_adapter: none` and `locked-download`.
- Duplicate identities, paths, filenames, traversal, unsupported values, and
  malformed values are rejected. Published schemas disallow additional
  properties, but the current executable CI verifier does not yet enforce that
  rule.

```sh
sudo apt-get install jq shellcheck
bin/verify-catalog
```

Run the full local contract gate with:

```sh
tests/catalog-contract.sh
```

A valid Catalog proves metadata shape and internal consistency. Flasher and
physical-device verification are separate.

## Documentation

- [Architecture](docs/architecture.md)
- [Business rules](docs/business-rules.md)
- [Security](docs/security.md)
- [Engineering standards](docs/standards.md)
- [Operations](docs/operations.md)
- [Data contracts](docs/contracts.md)
- [Implementation status](docs/tracking/status.md)
- [Open findings](docs/tracking/findings.md)
- [Decision index](docs/tracking/decisions/index.md)

