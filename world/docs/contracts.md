# Contracts

## Playbook root

`world-playbook.yaml` declares schema version `homelab.gujo.dev/v1alpha1`, the
`WorldPlaybook` kind, the canonical timezone, explicit draft paths, the
generation root, and the generation ID format. Draft and generation paths must
be safe relative paths contained within this checkout.

The monorepo commit is the exact source identity for the World, Installer, and
Catalog modules. A resolved plan and completed generation additionally record
the Catalog Git tree identity. Branch names and `latest` are not reproducible
inputs.

## Draft World

A draft has a stable slug but no generation timestamp. It may change until an
operator requests one physical USB creation. The initial World vocabulary is:

- `assets`: physical router, switch, computer, storage, and removable media;
- `networks`: layer-three address and gateway intent;
- `nodes`: logical identities bound to physical assets;
- `services`: capabilities assigned to logical nodes;
- `media`: selected install entries and presentation defaults;
- `policies`: fail-closed installation and write requirements.

IDs are lowercase ASCII kebab-case and unique within their kind. Every
reference must resolve exactly once. Static addresses must be unique and belong
to the referenced network. A gateway must be directly reachable or have an
explicit route. These semantic checks are required before implementation can
claim validation.

## USB generation identity

Every physical USB creation mints a distinct generation ID:

```text
{YYYYMMDDHHmmss}-{world-slug}
```

The timestamp is captured in `Asia/Seoul` when the resolved draft and exact
inputs are sealed immediately before the target-specific write. The manifest
stores the same value in ISO 8601 form with an explicit `+09:00` offset and
records a separate completion time.

A generation is published only after the write and required readback succeed.
An existing generation ID is a hard collision; tools fail rather than replace
it. New physical media always creates a new generation, including repeated
writes from identical source intent.

## Completed generation

A completed generation contains:

- immutable resolved `world.yaml`;
- exact `world.lock.json` dependency and input locks;
- media and artifact digest manifest;
- redacted physical write and readback evidence.

It does not contain generated ISO or raw images, caches, plaintext hardware
serials, credentials, private keys, or recovery material. Completed files are
never reformatted or migrated in place. A new schema or correction produces a
new generation.

`world.lock.json` records the monorepo commit, Catalog tree identity, selected
entry IDs, and exact artifact digests captured by the sealing transaction. It is
generation output and does not exist in the mutable draft.

## Evidence boundary

Draft validation, plan generation, image assembly, physical USB write, firmware
boot, operating-system installation, and network cutover are separate states.
Evidence from one state does not imply completion of a later state.
