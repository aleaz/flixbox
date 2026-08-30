# Quick reference

Cheat sheet for operators. Defaults assume a local install with `./bin/flixbox init`.

> **After changing `.env`:** run `./bin/flixbox reload` (not plain `restart`) so containers pick up new variables.

## CLI

| Command | Purpose |
| --- | --- |
| `./bin/flixbox init [--non-interactive]` | Create `.env`, dirs, templates |
| `./bin/flixbox up [profiles...]` | Start stack (`plex`, `proxy`, `socket-proxy`, `recyclarr`) |
| `./bin/flixbox reload [profiles...]` | Recreate containers after `.env` / compose changes |
| `./bin/flixbox configure [--dry-run]` | Wire root folders, download clients, Byparr, Prowlarr apps, Bazarr |
| `./bin/flixbox status` | Container status + mode + download-client URL |
| `./bin/flixbox logs [service]` | Tail logs |
| `./bin/flixbox vpn-test` | VPN egress check (VPN mode only) |
| `./bin/flixbox down` | Stop stack (config volumes kept) |

**Recyclarr sync (optional profile):**

```bash
docker compose --profile recyclarr run --rm recyclarr sync
```

## Web UI (host)

Replace `localhost` with your LAN IP when browsing from another device.

| Service | URL | Notes |
| --- | --- | --- |
| Homepage | `http://localhost:3000` | Dashboard |
| Seerr | `http://localhost:5055` | Requests |
| Jellyfin | `http://localhost:8096` | Streaming |
| qBittorrent | `http://localhost:8080` | WebUI (host port = `QBITTORRENT_PORT`) |
| Prowlarr | `http://localhost:9696` | Indexers |
| Radarr | `http://localhost:7878` | Movies |
| Sonarr | `http://localhost:8989` | TV |
| Bazarr | `http://localhost:6767` | Subtitles |
| Maintainerr | `http://localhost:6246` | Library hygiene |
| Byparr | — | No WebUI; logs via `./bin/flixbox logs byparr` |
| Caddy | `http://localhost:80` | Profile `proxy` only |

## Internal hostname contract (automation)

Use **Compose service names** on `flixbox_net` — not `container_name` (`flixbox-radarr`, etc.). Scripts (`configure`, Decluttarr env, CI) assume this table.

| Logical role | Hostname | Port | Notes |
| --- | --- | --- | --- |
| Download client (qBit API) | `qbittorrent` | `8080` | **Same in VPN and Direct** (ADR 0014). VPN: alias on Gluetun. |
| Movies | `radarr` | `7878` | |
| TV | `sonarr` | `8989` | |
| Indexers | `prowlarr` | `9696` | |
| Subtitles | `bazarr` | `6767` | |
| CF bypass | `byparr` | `8191` | |
| Requests | `seerr` | `5055` | |
| Streaming | `jellyfin` | `8096` | Plex (`plex`) only with profile `plex` |
| Queue hygiene | `decluttarr` | — | Env only |
| Library hygiene | `maintainerr` | `6246` | |
| VPN engine | `gluetun` | — | VPN mode only; debug, not *arr download host |

**When to use network aliases:** only when topology breaks DNS (today: qBit in Gluetun netns). Do not alias every service — service names are already stable.

**Profiles:** `recyclarr`, `caddy`, `docker-socket-proxy`, `plex` exist only when their profile is enabled — no alias substitutes an offline service.

## Internal URLs (*arr UI wiring)

Use these **inside Docker** (download clients, Prowlarr apps, etc.):

| Target | URL (Direct and VPN) |
| --- | --- |
| qBittorrent WebUI/API | `http://qbittorrent:8080` |
| Prowlarr | `http://prowlarr:9696` |
| Byparr proxy | `http://byparr:8191` |
| Radarr | `http://radarr:7878` |
| Sonarr | `http://sonarr:8989` |
| Jellyfin | `http://jellyfin:8096` |

## Paths inside containers

| Path | Purpose |
| --- | --- |
| `/data/torrents/` | qBit downloads |
| `/data/torrents/incomplete/` | In-progress torrents |
| `/data/media/movies` | Radarr library root |
| `/data/media/tv` | Sonarr library root |

Host equivalent: `${DATA_DIR}/…` from `.env`.

## First-run order (~30–45 min with configure)

```
init → up → log into each app once → configure → indexers → Jellyfin → Seerr → reload (.env hygiene keys)
```

| Step | Time | Action |
| --- | --- | --- |
| 1 | ~15 min | [Install](04-install.md): `init`, edit `.env`, `up` |
| 2 | ~5 min | Open Radarr, Sonarr, Prowlarr, Bazarr, qBit — complete each wizard / change qBit password |
| 3 | ~5 min | `./bin/flixbox configure` |
| 4 | ~15 min | Indexers, Jellyfin libraries, Seerr, Decluttarr `.env` keys — [First-run](05-first-run.md) |

Preview configure without changes:

```bash
./bin/flixbox configure --dry-run
```

## Credentials quick map

| Credential | Used by | Where |
| --- | --- | --- |
| Radarr/Sonarr API key | Unpackerr, Decluttarr, Prowlarr, Seerr, Bazarr | App → Settings → General; `.env` for Compose services |
| qBit API key | Radarr, Sonarr download client | qBit → Options → Web UI → API access |
| qBit username/password | Decluttarr, configure script | WebUI login; `.env` `QBITTORRENT_*` |
| Jellyfin API key | Seerr, Maintainerr | Jellyfin → Dashboard → API Keys |

Full detail: [Configuration — Credentials](06-configuration.md#credentials-and-api-keys).

## Common fixes

| Symptom | Try |
| --- | --- |
| `.env` change ignored | `./bin/flixbox reload` |
| qBit WebUI shows plain `Unauthorized` | [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| `configure` fails VPN check | Wait for Gluetun healthy: `./bin/flixbox logs gluetun` |
| Hardlinks fail / double disk use | Same filesystem for `${DATA_DIR}` — [How it works](02-how-it-works.md) |
| Decluttarr idle | Set `QBITTORRENT_USERNAME` + `QBITTORRENT_PASSWORD` in `.env`, then `reload` |

More: [Troubleshooting](10-troubleshooting.md).

## Related docs

- [Install](04-install.md) · [First-run](05-first-run.md) · [Configuration](06-configuration.md)
- [VPN and Direct](07-vpn-and-direct.md) · [Operations](09-operations.md)
