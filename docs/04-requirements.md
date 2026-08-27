# Requirements (MVP)

**Status:** Working Draft  
**Scope:** Only MVP capabilities from [01-scope.md](01-scope.md).

## 1. Functional requirements

### FR-1 Request portal

- **FR-1.1** MUST provide **Seerr** for discovering and requesting movies and TV.
- **FR-1.2** MUST support admin vs standard user roles and approval rules offered by Seerr.
- **FR-1.3** MUST dispatch approved requests to Radarr (movies) and Sonarr (TV).
- **FR-1.4** MUST integrate with Jellyfin as the primary media-server backend (Plex only when Plex profile is enabled).
- **FR-1.5** Compose MUST set `init: true` for Seerr and align config ownership to UID/GID 1000.

### FR-2 Indexing

- **FR-2.1** MUST centralize indexers in Prowlarr.
- **FR-2.2** MUST sync indexers to Radarr and Sonarr (MVP apps only).
- **FR-2.3** MUST include **Byparr** (FlareSolverr-compatible) for Cloudflare-protected indexers.
- **FR-2.4** Docs MAY document FlareSolverr as an alternate image speaking the same API.

### FR-3 Download / VPN

- **FR-3.1** MUST use qBittorrent for BitTorrent.
- **FR-3.2** When `VPN_ENABLED=true`, qBittorrent MUST run in Gluetun’s network namespace; WebUI ports MUST be published on Gluetun.
- **FR-3.3** VPN MUST support Gluetun native providers and custom WireGuard/OpenVPN configs.
- **FR-3.4** When `VPN_ENABLED=false`, qBittorrent MUST run on `flixbox_net` without Gluetun.
- **FR-3.5** When the VPN provider supports forwarding, Gluetun MUST be configurable with `VPN_PORT_FORWARDING=on` and UP/DOWN commands that update qBittorrent’s listen port.
- **FR-3.6** Radarr/Sonarr/Prowlarr/Seerr/Jellyfin/Bazarr MUST NOT use `network_mode: service:gluetun`.

### FR-4 Post-process

- **FR-4.1** MUST deploy Unpackerr watching `/data/torrents/`.
- **FR-4.2** MUST extract archives and allow *arr import without deleting originals required for seeding.

### FR-5 Subtitles

- **FR-5.1** MUST deploy Bazarr for movies and TV.
- **FR-5.2** MUST allow language priority configuration (defaults documented for Spanish Castellano / Latino / English).

### FR-6 Quality profiles

- **FR-6.1** MUST integrate Recyclarr for TRaSH Guides sync into Radarr/Sonarr.
- **FR-6.2** Default templates SHOULD prioritize high-tier audio, Spanish + original audio scoring, and reject CAM/TS-class releases.

### FR-7 Media server

- **FR-7.1** MUST use Jellyfin as the primary media server.
- **FR-7.2** SHOULD support GPU passthrough when hardware is present (Intel QSV, Nvidia, AMD VAAPI); otherwise CPU-only.
- **FR-7.3** MUST mount transcode scratch to host `/dev/shm` (or documented sized RAM disk).
- **FR-7.4** MAY provide an optional Compose profile for Plex.

### FR-8 Dashboard

- **FR-8.1** MUST provide Homepage as the central dashboard.
- **FR-8.2** SHOULD expose widgets for downloads, *arr, Jellyfin, VPN/IP status, and host metrics where APIs allow.

### FR-9 CLI (Bash MVP)

- **FR-9.1** MUST ship `bin/flixbox` with `set -euo pipefail`, signal traps, and TTY-aware output (`NO_COLOR` respected).
- **FR-9.2** MUST implement `init`, `up`, `down`, `restart`, `status`, `logs`, `vpn-test`.
- **FR-9.3** `init` MUST create directory trees (including `torrents/incomplete`), write local env (untracked), and select VPN or Direct mode.

### FR-10 Queue hygiene (Decluttarr)

- **FR-10.1** MUST deploy Decluttarr against Radarr, Sonarr, and qBittorrent.
- **FR-10.2** MUST use `http://gluetun:8080` or `http://qbittorrent:8080` according to VPN mode.
- **FR-10.3** MUST follow Decluttarr defaults in [09-hygiene-defaults.md](09-hygiene-defaults.md) (including `flixbox-keep` protect tag).

### FR-11 Library hygiene (Maintainerr)

- **FR-11.1** MUST deploy Maintainerr.
- **FR-11.2** MUST target **Jellyfin** as the media-server connection by default (one server at a time).
- **FR-11.3** MUST integrate with Radarr/Sonarr for delete/unmonitor actions driven by rules.
- **FR-11.4** MUST implement the standard rule pack in [09-hygiene-defaults.md](09-hygiene-defaults.md) (unwatched movies 90/14, unwatched TV 180/21, skip &lt;30d, Keep exclusions).
- **FR-11.5** Watched-movie reclaim (Rule C) MUST remain **off** unless the operator enables it.

### Deferred (not MVP MUSTs)

- Usenet/SABnzbd, Lidarr/Readarr, Whisper, PowerShell CLI, Authelia, Autobrr/cross-seed, Profilarr, Streamystats, full `backup`/`restore`/`update`/`sync-profiles` CLI surface.

## 2. Non-functional requirements

| ID | Category | Requirement |
| --- | --- | --- |
| **NFR-1** | Performance | On a single local filesystem, media import MUST use hardlinks (`link()`), not cross-mount copies. |
| **NFR-2** | Portability | Stack MUST work on Linux x86_64/ARM64. WSL2 and macOS are best-effort with documented limitations. |
| **NFR-3** | Reliability | Stateful services MUST set `stop_grace_period: 60s`. |
| **NFR-4** | Security | No secrets in git. In VPN mode, qBit MUST not egress outside the Gluetun path when the tunnel is down. |
| **NFR-5** | Maintainability | Compose MUST use `include:` modules; no single compose YAML > 150 lines. |
| **NFR-6** | Usability | `flixbox init` MUST bootstrap paths and env with interactive defaults; remaining UI steps MUST be documented. |

## 3. Compose module contract (MVP)

```
compose/
├── network-base.yml
├── downloaders-vpn.yml
├── downloaders-direct.yml
├── servarr.yml              # Prowlarr, Radarr, Sonarr, Bazarr, Byparr
├── optimization.yml         # Unpackerr, Recyclarr, Decluttarr, Maintainerr
├── media-servers.yml
├── requests.yml             # Seerr
├── dashboard.yml
└── proxy.yml
```

## 4. Default ports (reference)

| Service | Port |
| --- | --- |
| Homepage | 3000 |
| Seerr | 5055 |
| Jellyfin | 8096 |
| qBittorrent | 8080 |
| Prowlarr | 9696 |
| Radarr | 7878 |
| Sonarr | 8989 |
| Bazarr | 6767 |
| Maintainerr | 6246 |
| Byparr | 8191 |
| Caddy | 80 / 443 |
