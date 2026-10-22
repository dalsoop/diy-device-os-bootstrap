# Unsuccessful USB Events

This tree stores append-only, redacted records for physical USB write attempts
that failed or were cancelled after a World generation candidate was sealed.
Successful events live with their immutable evidence under `burn-history/logs/usb/`.

Paths use `burn-history/logs/usb/failed/YYYY/{event-id}.json`. Event IDs include the generation
candidate plus a random suffix so separate attempts never overwrite one
another. Records contain no raw serial, UUID, MAC address, credential, image,
or recovery material.

A plan, capacity query, or simulation is not a physical write attempt and does
not create an event record.
