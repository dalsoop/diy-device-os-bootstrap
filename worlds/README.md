# Completed World Generations

This directory is intentionally empty in the template. A completed generation
appears only after one physical USB has been written and the required readback
verification has succeeded.

Generation names use:

```text
{YYYYMMDDHHmmss}-{world-slug}
```

For example:

```text
20261015143022-gujo-home/
├── world.yaml
├── world.lock.json
├── media-manifest.json
└── verification.json
```

The timestamp is the generation seal time for that USB creation in
`Asia/Seoul`, not the draft creation or edit time. Every later physical USB
write creates another directory, even when the desired content is unchanged.

Completed directories are append-only. Never edit, rename, overwrite, or
silently migrate them. A convenience `latest` view may be derived, but it is
not an authority.
