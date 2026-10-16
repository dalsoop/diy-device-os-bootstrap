# 0003: Adopt Gujo Homelab OS Repository Names

Status: Superseded by root decisions 0001 and 0003

## Decision

Use **Gujo Homelab OS Catalog** for the public operating-system metadata
repository and **Gujo Homelab OS Installer** for the tool that selects,
prepares, and flashes those systems to a USB device. Use `media` only for
concrete ISO files, disk images, and removable-media implementation details.

The repository names are `gujo-homelab-os-catalog` and
`gujo-homelab-os-installer`. The human-facing Installer command is `device-os`.

## Consequences

The names describe what users choose and the action the tool performs. Existing
GitHub repository URLs redirect after the repositories are renamed, but forks,
local remotes, badges, schema IDs, and automation should migrate to the new
canonical URLs.
