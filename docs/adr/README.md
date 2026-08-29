# Architecture Decision Records

ADRs capture decisions that should not be silently reversed.

## Format

Each ADR uses:

- **Status:** Proposed | Accepted | Superseded
- **Context:** problem and constraints
- **Decision:** what we chose
- **Consequences:** trade-offs

## Index

| ADR | Title | Status |
| --- | --- | --- |
| [0001](0001-storage-hardlink-contract.md) | Storage hardlink contract | Accepted |
| [0002](0002-vpn-gluetun-dual-mode.md) | Gluetun VPN dual-mode | Accepted |
| [0003](0003-compose-modularity.md) | Compose modularity | Accepted |
| [0004](0004-jellyfin-first.md) | Jellyfin-first + Seerr | Accepted |
| [0005](0005-cli-bash-first.md) | Bash CLI first | Accepted |
| [0006](0006-mvp-service-inventory.md) | MVP service inventory | Accepted |
| [0007](0007-platform-support-tiers.md) | Platform support tiers | Accepted |
| [0008](0008-maintenance-decluttarr-maintainerr.md) | Decluttarr + Maintainerr | Accepted |
| [0009](0009-byparr-default-cf-bypass.md) | Byparr default CF bypass | Accepted |
| [0010](0010-mit-and-image-tags.md) | MIT license + image tags | Accepted |
| [0011](0011-documentation-i18n.md) | Documentation i18n (EN/ES) | Accepted |

## Rules

1. New architectural choices get a new ADR (do not silently edit Accepted decisions into something else without an Updated note).
2. To reverse an Accepted ADR: write a superseding ADR and mark the old one Superseded.
3. AI agents must follow Accepted ADRs over informal chat decisions.
