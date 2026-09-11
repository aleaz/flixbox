# Scope

**Status:** Implemented — MVP inventory frozen; Definition of Done met on Linux operator verification (expand only with explicit scope change)  
**Related ADRs:** [0004](adr/0004-jellyfin-first.md), [0005](adr/0005-cli-bash-first.md), [0006](adr/0006-mvp-service-inventory.md), [0007](adr/0007-platform-support-tiers.md), [0008](adr/0008-maintenance-decluttarr-maintainerr.md), [0014](adr/0014-stable-qbit-download-hostname.md), [0015](adr/0015-access-profiles.md)

## In scope (MVP)

### Services

| Service | Role |
| --- | --- |
| Gluetun | Multi-provider VPN (WireGuard / OpenVPN / custom) |
| qBittorrent | BitTorrent client (VPN netns or Direct bridge) |
| Prowlarr | Central indexer manager |
| Byparr | Cloudflare / anti-bot bypass (FlareSolverr-compatible API) |
| Radarr | Movies automation |
| Sonarr | TV automation |
| Bazarr | Subtitles |
| Unpackerr | Archive extraction without breaking seeding |
| Recyclarr | TRaSH Guides quality / custom format sync |
| Decluttarr | Queue hygiene (stalled/failed downloads → remove/blocklist/research) |
| Maintainerr | Library hygiene (unwatched / rule-based cleanup via Jellyfin + *arr) |
| Seerr | Request portal (successor to Jellyseerr/Overseerr) |
| Jellyfin | Primary media server |
| Homepage | Dashboard with live widgets |
| Caddy | Reverse proxy / HTTPS ingress |
| docker-socket-proxy | Read-limited Docker API for Homepage (always on — [ADR 0022](adr/0022-operator-footgun-remediations.md)) |

### Tooling

- Bash CLI `bin/flixbox` with at least: `init`, `up`, `down`, `restart`, `reload`, `status`, `logs`, `vpn-test`, `configure`
- Host helpers: `scripts/host-tuning.sh`, `scripts/backup.sh` (as needed by phases)
- Modular Compose under `compose/`
- `.env.example` with no real secrets
- English docs in `docs/`
### Platforms (MVP)

- **First-class:** Linux x86_64 and ARM64 (Docker Engine + Compose v2 plugin)
- **Best-effort:** Windows Docker Desktop + WSL2 (ext4 paths only), macOS Docker Desktop

## Out of scope (MVP)

Do **not** implement these until the roadmap phase says so:

- Lidarr, Readarr, Audiobookshelf
- SABnzbd / Usenet
- Whisper AI subtitles
- Overseerr / Jellyseerr as separate products (use **Seerr** only)
- FlareSolverr as the default image (Byparr is default; FlareSolverr remains a documented alternative)
- PowerShell CLI (`bin/flixbox.ps1`)
- Vagrant / lab VM packaging
- Telegram or other bots as first-class Flixbox features (use Seerr/Maintainerr notifications instead; post-MVP Apprise hub — [ADR 0012](adr/0012-notifications-apprise-hub.md))
- Automatic Direct fallback when VPN fails (privacy fail-closed — [ADR 0013](adr/0013-vpn-resilience-no-direct-fallback.md))
- Authelia / Authentik / SSO in front of Caddy
- Autobrr, cross-seed
- Profilarr (Recyclarr remains the TRaSH sync tool)
- Streamystats (optional Maintainerr companion — not required for MVP)
- Kubernetes / Ansible / Terraform packaging
- Claiming “fully zero-touch” when indexers still need user credentials (API-assisted first-run is in scope; indexers stay manual)

## Later (post-MVP)

See [08-roadmap.md](08-roadmap.md) and planning note [11-future-notifications-and-vpn-resilience.md](11-future-notifications-and-vpn-resilience.md).

## Definition of done (MVP)

MVP is done when all of the following are true:

1. Modular Compose starts the MVP inventory with `FLIXBOX_MODE` selecting VPN vs Direct downloaders, plus optional profiles (`plex` / `proxy` / `recyclarr`) as designed. `docker-socket-proxy` always runs with Homepage ([ADR 0022](adr/0022-operator-footgun-remediations.md)).
2. All download/media containers mount the same `${DATA_DIR}:/data` parent; hardlinks work on a single local filesystem (including `torrents/incomplete`).
3. VPN mode: qBittorrent shares Gluetun netns; ports published on Gluetun; healthcheck gates start; killswitch drops egress if tunnel is down; port-forward hook documented/wired when provider supports it; `vpn-test` reports masked IP.
4. Direct mode: qBittorrent on `flixbox_net` without Gluetun.
5. Decluttarr reaches Radarr/Sonarr and qBittorrent at `http://qbittorrent:8080` in both VPN and Direct ([ADR 0014](adr/0014-stable-qbit-download-hostname.md)).
6. Maintainerr is configured against Jellyfin + Radarr/Sonarr (Plex only if Plex profile enabled).
7. `bin/flixbox` supports the minimum command set (`init`, `up`, `down`, `restart`, `reload`, `status`, `logs`, `vpn-test`, `configure`) and creates the directory tree with the frozen permissions model.
8. README describes real setup steps: `init` → `up` → `configure` covers deterministic wiring; remaining manual steps (indexers, optional Maintainerr rules) are listed honestly — no false “fully zero-touch” claims.
9. No secrets in git-tracked files; `.gitignore` covers `.env` and local config/data paths.
10. Operational footguns from [07-operations-risks.md](07-operations-risks.md) are documented and, where feasible, enforced by CLI validation.

## Explicit non-migration

Flixbox is a greenfield public project. There is **no** migration path from any prior personal HTPC compose stack. Do not add migration guides or legacy compatibility layers.
