# Monorepo Architecture

## One repository, three trust domains

Gujo Homelab Device Bootstrap is intentionally one repository so a World change, Catalog change,
Installer consumer change, fixtures, and documentation can land atomically.
The former repository boundaries remain explicit module and runtime trust
boundaries.

```text
world/ desired state
       .
       . planned input; not consumed yet
       v
installer/ resolver and safety engine <--- catalog/ public data only
       |
       v
verified image -> confirmed physical USB -> immutable World generation
```

`world/` is user-controlled declarative input. `catalog/` is untrusted data even
though it shares a checkout. The Installer currently validates Catalog and
Installer-local input before use and alone owns download, assembly, or
disk-write behavior; it will also validate World input once that edge exists.

The final World-to-Installer edge and immutable-generation publication are not
implemented. The current resolver reads `installer/collections/device-os.json`
and Installer-local profiles. This transitional collection is the executable
selection until `device-os world validate/plan/write` exists.

## Identity and reproducibility

The repository commit identifies the complete source snapshot. A resolved media
plan additionally records the Catalog Git tree identity so Catalog content can
be compared independently. A completed generation records the repository
commit, Catalog tree, resolved World, artifact digests, and redacted write
evidence.

The working Catalog must be clean before a release plan is considered
reproducible. Local fixtures may opt into an explicitly unpinned test mode;
release and physical-write paths may not.

## State planes

| Plane | Mutability | Location |
| --- | --- | --- |
| Desired World draft | Mutable | `world/drafts/<slug>/world.yaml` |
| Local observation | Mutable and ignored | `world/local/` |
| Public OS metadata | Reviewed | `catalog/catalog/` |
| Execution engine | Reviewed | `installer/` |
| Generated workspace | Ephemeral and ignored | `installer/work/` and caches |
| Completed USB generation | Immutable, append-only | `world/worlds/<generation-id>/` |
| Secret values | External | Principal secret store |

## User surface

Ordinary users manage this one repository and invoke `./device-os` from its
root. Module-local commands remain available for contributors, but root
documentation does not require separate clones, cross-repository pull requests,
or revision-pin updates.
