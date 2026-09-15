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
| [0006](0006-mvp-service-inventory.md) | Core service inventory (historical “MVP” title) | Accepted |
| [0007](0007-platform-support-tiers.md) | Platform support tiers | Accepted |
| [0008](0008-maintenance-decluttarr-maintainerr.md) | Decluttarr + Maintainerr | Accepted |
| [0009](0009-byparr-default-cf-bypass.md) | Byparr default CF bypass | Accepted |
| [0010](0010-mit-and-image-tags.md) | MIT license + image tags | Accepted |
| [0011](0011-documentation-i18n.md) | Documentation i18n (EN/ES) | Accepted |
| [0012](0012-notifications-apprise-hub.md) | Notifications via Apprise hub | Accepted |
| [0013](0013-vpn-resilience-no-direct-fallback.md) | VPN resilience (no Direct fallback) | Accepted |
| [0014](0014-stable-qbit-download-hostname.md) | Stable `qbittorrent` download host | Accepted |
| [0015](0015-access-profiles.md) | Access profiles (`trusted` / `shared`) | Accepted |
| [0016](0016-configure-state-machine.md) | Configure readiness state machine | Accepted |
| [0017](0017-compose-health-and-start-order.md) | Compose healthchecks + Bazarr start order | Accepted |
| [0018](0018-runtime-secrets-and-lan-trust.md) | Runtime secrets + LAN trust | Accepted |
| [0019](0019-qbit-webui-runtime-contract.md) | qBit WebUI runtime security contract | Accepted |
| [0020](0020-operator-credentials-cli.md) | Operator credentials CLI (`show` / `set`) | Accepted |
| [0021](0021-cli-ux-contract.md) | CLI UX contract (professional Bash surface) | Accepted |
| [0022](0022-operator-footgun-remediations.md) | Operator footgun remediations | Accepted |

## Rules

1. During pre-public development, Accepted ADRs MAY be updated in place with an **Updated:** date and note (sole maintainer). Prefer that over proliferating ADRs for the same decision.
2. After a public tag, reversing an Accepted ADR requires a superseding ADR and marking the old one Superseded.
3. AI agents must follow Accepted ADRs over informal chat decisions.
