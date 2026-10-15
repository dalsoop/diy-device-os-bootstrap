# 0003: Name the Product Around Operating Systems and Flashing

Status: Accepted

## Decision

Use **Device OS Catalog** for the public operating-system metadata repository
and **Device OS Flasher** for the tool that selects, prepares, and flashes those
systems to a USB device. Use `media` only for concrete ISO files, disk images,
and removable-media implementation details.

The repository names are `device-os-catalog` and `device-os-flasher`. The
human-facing Flasher command is `device-os`.

## Consequences

The names describe what users choose and the action the tool performs. Existing
GitHub repository URLs redirect after the repositories are renamed, but forks,
local remotes, badges, schema IDs, and automation should migrate to the new
canonical URLs.
