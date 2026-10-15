# Implementation Status

| Capability | Implemented | Verified | Remaining evidence |
| --- | --- | --- | --- |
| Closed-world index for entries and bootloaders | Yes | CI fixture | Larger malformed-file fixture set |
| One JSON file per public item | Yes | CI | Ongoing review discipline |
| Stable public media-entry contract | Yes | CI success/rejection cases | Cross-repository compatibility matrix |
| Public JSON Schemas | Yes | Source inspection | Automated parity with executable verifier |
| Executable rejection of all additional properties | No | No | Invoke schemas or add explicit allowed-key checks and fixtures |
| HTTPS and lowercase SHA-256 enforcement | Yes | CI fixture | Per-release provenance review |
| Duplicate ID, path, and filename rejection | Yes | CI fixture | More direct duplicate-path cases |
| Unsafe relative path rejection | Yes | Executable rule | Dedicated traversal fixtures |
| Public guarded unattended profiles | Intentionally absent | Boundary verified by contract | None; local Flasher responsibility |
| Media download or boot verification | Intentionally absent | No | Flasher and physical verification |
| Automated vendor release discovery | No | No | Trust and provenance design required |

Current release state: usable public metadata catalog with contract validation.
It does not certify the media it describes on physical hardware.
