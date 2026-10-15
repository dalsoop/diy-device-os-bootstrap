# Implementation Status

Status is split into source implementation and observed verification. A source
check mark does not imply successful physical installation.

| Capability | Implemented | Verified | Remaining evidence |
| --- | --- | --- | --- |
| Exact Catalog commit resolution without executing Catalog code | Yes | Isolated simulation | Pin update tested against upstream commit |
| Append-only World generation per verified physical USB creation | Documentation only | No | External Playbook schema, pending transaction, publication, and rejection tests |
| Data-only addition for existing locked-download entries | Yes | Isolated simulation | Broader entry compatibility set |
| New source kinds or profile adapters without core changes | No | No | Requires an explicit plug-in design |
| HTTPS download and SHA-256 cache verification | Yes | Source tests | Clean Linux download run for current pins |
| Capacity planning for nominal sizes or read-only device queries | Yes | Read-only 16GB macOS run | CI fixture, runtime-artifact result, and live device query |
| Korean-first Ventoy menu with no timer | Yes | Source tests | Physical legacy BIOS and UEFI menu |
| Serial-bound removable USB writer | Yes | Two physical macOS writes; payload SHA-256 and exFAT checks passed | Physical rerun of the two-phase writer and BIOS/UEFI boot |
| Proxmox VE interactive entry | Yes | Metadata only | Boot and install on disposable disk |
| Proxmox Backup Server interactive entry | Yes | Metadata only | Boot and install on disposable disk |
| TrueNAS SCALE interactive entry | Yes | Metadata only | Boot and install on disposable disk |
| Pop!_OS entry and Korean guide | Yes | Metadata/source only | Korean installation and Secure Boot |
| Debian Live diagnostic entry | Yes | Metadata only | Boot and inventory capture |
| Offline DNS ISO source and immutable locks | Yes | Source validation | Two clean amd64 Debian builds and comparison |
| Fail-closed HP/NIC/disk install gate | Yes | Isolated rejection simulation | BIOS, UEFI, Ventoy mapper, physical dns01 |
| Retry-safe encrypted first-boot enrollment | Yes | Source contract | Power-loss and real exFAT fault injection |
| Three-node Technitium cluster bootstrap | Yes | Source/fixture checks | Live three-node cluster and primary-loss drill |
| Read/plan/apply DNS command boundary | Yes | Isolated simulation | Approved live canary change and rollback |
| Encrypted backup collection and explicit restore | Yes | Source checks | Isolated restore drill from collected backup |
| One-off tagged Tailscale enrollment | Yes | Isolated simulation | Tailnet policy review and three-node reboot drill |
| Portable read-only status monitor | Yes | Python syntax/source inspection | Run from the assembled USB against all nodes |
| Router DHCP cutover and rollback | Procedure only | No | Live router change after all node gates |

Current release state: source prototype. It is not yet a physically qualified
installer or USB release.

