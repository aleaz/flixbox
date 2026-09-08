# Development guide

**Status:** Working Draft  
Implement Flixbox in this order. Do not skip ahead to CLI polish or post-MVP services before the Compose contracts work.

## Prerequisites for contributors

- Docker Engine 24+ and Compose plugin ≥ 2.20
- Bash 4+ (Linux reference)
- Read: [01-scope.md](01-scope.md), [03-architecture.md](03-architecture.md), [05-standards.md](05-standards.md), [adr/](adr/)

## Phase 0 — Repository scaffold

1. Root `README.md`, `AGENTS.md`, `.gitignore`, `.editorconfig`, `.gitattributes`, `LICENSE` (MIT)
2. `.env.example` (`DATA_DIR`, `CONFIG_DIR`, `PUID`, `PGID`, `UMASK`, `TZ`, `VPN_ENABLED`, Gluetun vars)
3. Document target dirs: `compose/`, `bin/`, `scripts/`
4. Image tags: `:latest` OK for early phases (ADR 0010); pin before v0.1

**Exit criteria:** Clone is understandable; no secrets; docs link correctly; MIT `LICENSE` present.

**Status:** Done (docs + `.env.example` + `compose.yaml` include scaffold + `scripts/bootstrap-dirs.sh`).

## Phase 1 — Network + dual-mode downloaders

1. `compose/network-base.yml` → `flixbox_net`
2. `compose/downloaders-vpn.yml` → Gluetun + qBittorrent (ports on Gluetun, healthcheck gate, optional port-forward UP/DOWN commands)
3. `compose/downloaders-direct.yml` → qBittorrent on bridge
4. Document client URL: `http://qbittorrent:8080` in both modes (ADR 0014 alias in VPN).
5. Explicit doc warning: never attach *arr/Seerr/Jellyfin to Gluetun netns

**Exit criteria:** VPN and Direct modes start separately; manual `vpn-test` via `docker exec` works.

**Status:** Done (Direct + VPN via `FLIXBOX_MODE`).

## Phase 2 — Storage tree + Servarr core

1. Create `/data/torrents/{incomplete,movies,tv}` and `/data/media/{movies,tv}`
2. `compose/servarr.yml` → Prowlarr, Radarr, Sonarr, Bazarr, Byparr
3. Single `${DATA_DIR}:/data` mount on all relevant services
4. `${CONFIG_DIR}/<app>:/config` on local disk

**Exit criteria:** Manual hardlink inode check passes on Linux single filesystem.

**Status:** Compose + bootstrap dirs done. Hardlink verification is an operator check after first import.

## Phase 3 — Optimization + hygiene

1. `compose/optimization.yml` → Unpackerr, Recyclarr, Decluttarr, Maintainerr
2. Decluttarr templates use stable qBit URL `http://qbittorrent:8080` (ADR 0014)
3. Maintainerr defaults to Jellyfin; example rules documented as opt-in (non-destructive defaults)
4. Recyclarr config template pinned; sync is explicit (later CLI `sync-profiles`)
5. Unpackerr free-space threshold documented/configured

**Exit criteria:** Sample stalled-download and unwatched-cleanup flows documented; Recyclarr dry-run path documented.

**Status:** Done (`templates/`, Decluttarr URL via init, Recyclarr profile `recyclarr`).

## Phase 4 — Media, requests, dashboard, proxy

1. `compose/media-servers.yml` → Jellyfin (+ optional Plex profile)
2. Transcode volume → `/dev/shm`
3. `compose/requests.yml` → Seerr (`init: true`)
4. `compose/dashboard.yml` → Homepage + always-on docker-socket-proxy
5. `compose/proxy.yml` → Caddy

**Exit criteria:** Jellyfin serves `/data/media`; Seerr points at Radarr/Sonarr/Jellyfin; Homepage loads.

**Status:** Compose modules done; first-run wiring via `flixbox configure` (ADR 0005). Indexers remain operator UI.

## Phase 5 — Bash CLI

1. `bin/flixbox` with `init|up|down|restart|status|logs|vpn-test`
2. `init` writes `.env`, creates dirs, applies SGID/`chown`
3. `up` selects VPN vs Direct compose set from env
4. Warn on unsafe paths (NFS config, `/mnt/c`, exFAT)

**Exit criteria:** Matches FR-9 MVP command set on Linux.

**Status:** Done.

## Phase 6 — Host hardening helpers

1. `scripts/host-tuning.sh` (inotify, optional socket buffers)
2. `scripts/backup.sh` (SQLite-safe config backup) — can be minimal
3. Confirm `stop_grace_period` on stateful services

**Exit criteria:** Ops risks checklist items either enforced or clearly documented.

**Status:** Done.

## Phase 7 — Release hygiene (before public v0.1)

1. Pin image tags
2. CI phase 1 done — see [10-ci-plan.md](10-ci-plan.md); phase 2 (Trivy) before public tag
3. Honest quickstart in README
4. `LICENSE` is MIT (already in repo)
5. Pin image tags (leave `:latest` only for pre-release experimentation)
6. Tag/release only when Definition of Done in scope doc is met

## Manual wiring still expected (document, don’t fake)

Even after `init` + `configure`, users typically must:

- Add indexer credentials in Prowlarr (+ `cf` tag where Byparr is needed)
- Enable Maintainerr rules deliberately (cleanup is destructive by nature)
- Optionally run Recyclarr sync and enable the Caddy profile

Deterministic wiring (root folders, download clients, Byparr, Bazarr, Jellyfin libraries, Seerr, secret loop) is handled by `./bin/flixbox configure` (ADR 0005).

## Verification checklist

Operator smoke test: [docs/user/11-smoke-test.md](user/11-smoke-test.md) and `./scripts/smoke-test.sh`.

- [x] `docker compose` config validates (direct + vpn includes)
- [ ] Hardlink inodes match for a test import
- [ ] VPN mode: public IP differs from host; qBit UI via Gluetun published port
- [x] Direct mode: qBittorrent reachable by service name (compose config)
- [x] Decluttarr qBit URL always `http://qbittorrent:8080` via `DECLUTTARR_QBIT_URL` / `flixbox init` (ADR 0014)
- [ ] Maintainerr connects to Jellyfin (operator UI)
- [x] `git status` shows no `.env` or secrets (`.env` gitignored)
