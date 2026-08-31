# Flixbox

**Your home media pipeline — request, download, organize, stream.**

Ask for a movie or show in Seerr. Flixbox finds a release, downloads it (optionally through VPN), hardlinks it into your library, and serves it on Jellyfin. One CLI, one `/data` tree, [TRaSH Guides](https://trash-guides.info/)–aligned defaults.

Also available in [Spanish](README.es.md).

## How it works

**The flow:** someone requests a title → it downloads → it appears in Jellyfin.

```text
Request:  Seerr → Radarr / Sonarr → Prowlarr (+ Byparr)
Download: qBittorrent  (Direct, or via Gluetun in VPN mode)
Watch:    Jellyfin
Maintain: Decluttarr (queues) · Maintainerr (library rules)
```

No Pi-hole or reverse proxy required to get started.

## Why Flixbox?

- **Start simple** — Direct mode in ~15 minutes; flip to VPN when you are ready for production torrents
- **One CLI** — `bin/flixbox` for `init`, `up`, `configure`, `reload`, `status`, `vpn-test`
- **Built-in hygiene** — Decluttarr and Maintainerr with conservative defaults (no surprise deletes)
- **Modular Compose** — small YAML modules and optional profiles (`plex`, `proxy`, `recyclarr`), not a monolith
- **Explicit contracts** — single `/data` hardlink tree, download host always `qbittorrent` (VPN and Direct), documented in [ADRs](docs/adr/)

## Choose your setup

| Setup | When | Start here |
| --- | --- | --- |
| **Core (Direct)** | First try, LAN only | [Install](docs/user/04-install.md) |
| **Shared Wi‑Fi** | Roommates on same LAN | `FLIXBOX_ACCESS_PROFILE=shared` then `init`/`up` — [Access profiles](docs/user/13-access-profiles.md) |
| **+ VPN** | Production torrents | [VPN and Direct](docs/user/07-vpn-and-direct.md) |
| **+ HTTPS** | Reverse proxy | Caddy profile in [Configuration](docs/user/06-configuration.md) |
| **+ Plex** | Alongside or instead of Jellyfin | `./bin/flixbox up plex` |

## Quick start

**Requirements:** Docker Compose v2, ~4 GB RAM, Linux x86_64/ARM64 (macOS best-effort). See [Requirements](docs/user/03-requirements.md).

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Edit .env: DATA_DIR, CONFIG_DIR (writable paths), FLIXBOX_MODE, TZ
# Optional: FLIXBOX_ACCESS_PROFILE=shared if roommates share Wi‑Fi (default: trusted)
./bin/flixbox init --non-interactive
./bin/flixbox up
./bin/flixbox status
./bin/flixbox configure
```

Linux: default paths use `/srv/flixbox/…` — create and `chown` them first, or set paths like `/data/flixbox/data` in `.env`. See [Install — storage paths](docs/user/04-install.md#storage-paths-and-permissions).

**Then (~10–15 min):** add Prowlarr indexers — [First-run guide](docs/user/05-first-run.md).

| Service | Default URL |
| --- | --- |
| Homepage | http://localhost:3000 |
| Seerr | http://localhost:5055 |
| Jellyfin | http://localhost:8096 |
| qBittorrent | http://localhost:8080 |

Full port list: [Quick reference](docs/user/REFERENCE.md).

## Documentation

| Doc | Purpose |
| --- | --- |
| [User guide](docs/user/INDEX.md) | Operator docs hub |
| [Install](docs/user/04-install.md) | Clone → `init` → `up` (~15 min) |
| [First-run](docs/user/05-first-run.md) | `configure` + remaining UI wiring |
| [Quick reference](docs/user/REFERENCE.md) | URLs, ports, CLI cheat sheet |
| [How it works](docs/user/02-how-it-works.md) | Pipeline, `/data`, VPN vs Direct |
| [Troubleshooting](docs/user/10-troubleshooting.md) | Common failures |

**Contributors:** [Docs map](docs/INDEX.md) · [ADRs](docs/adr/) · [AGENTS.md](AGENTS.md)

**Español:** [README.es.md](README.es.md) · [Guía (ES)](docs/es/user/INDEX.md)

## Status

MVP stack runs with `./bin/flixbox up`. After boot, you wire indexers and API keys in the UI (~30–45 min with `configure`). Not zero-touch — and we do not claim it is. See [first-run](docs/user/05-first-run.md).

<details>
<summary><strong>Full stack (MVP)</strong></summary>

Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy (optional), docker-socket-proxy (optional).

</details>

## Platforms

- **First-class:** Linux (x86_64 / ARM64)
- **Best-effort:** Windows (Docker Desktop + WSL2 ext4), macOS

## License

[MIT](LICENSE) © 2026 Alejandro Azario

## Disclaimer

You are responsible for complying with applicable laws and terms of service for any content, indexers, or VPN providers you use with this software.
