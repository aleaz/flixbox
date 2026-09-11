# Quick reference

Cheat sheet for operators. Defaults assume a local install with `./bin/flixbox init`.

> **After changing `.env`:** run `./bin/flixbox reload` (not plain `restart`) so containers pick up new variables.

## CLI

| Command | Purpose |
| --- | --- |
| `./bin/flixbox init [--non-interactive]` | Create `.env`, dirs, templates; generate API keys/passwords. **Linux:** set writable `DATA_DIR`/`CONFIG_DIR` in `.env` before `--non-interactive` — [Install § paths](04-install.md#storage-paths-and-permissions) |
| `./bin/flixbox up [profiles...]` | Start stack (`plex`, `proxy`, `recyclarr`; removes orphans on mode switch) |
| `./bin/flixbox reload [--reset-homepage] [profiles...]` | Recreate containers after `.env` / compose changes. `--reset-homepage` also overwrites managed Homepage templates (with backup) |
| `./bin/flixbox homepage refresh [--dry-run]` | Apply repo Homepage templates to live `${CONFIG_DIR}/homepage` (backup → overwrite managed files → sync → stamp → restart). Use after `git pull` when `up`/`reload` warn that templates are newer |
| `./bin/flixbox configure [--dry-run] [--sync-qbit-auth] [--sync-arr-ui]` | Idempotent wiring; heals drifted API keys. `--dry-run` previews only (no `.env`/API changes). `--sync-qbit-auth` forces qBit WebUI password from `.env` into qBit + *arr + Decluttarr. `--sync-arr-ui` applies `FLIXBOX_ARR_UI_*` Forms under `shared` (ADR 0020) |
| `./bin/flixbox credentials show <target>` | Print operator secret (`qbit`, `arr-ui`, `admin`, or `api radarr\|sonarr\|prowlarr`) — stdout only; keep private |
| `./bin/flixbox credentials set <target> --generate\|--prompt` | Write `.env` and apply. `qbit` = **rotate** (auth with current password first). `arr-ui` = shared Forms Host Config. `admin` = best-effort Jellyfin. Align-only qBit path remains `configure --sync-qbit-auth` |
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

**Profiles:** `recyclarr`, `caddy`, `plex` exist only when their profile is enabled — no alias substitutes an offline service. `docker-socket-proxy` always runs with Homepage.

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

## First-run order (~10–15 min with configure)

```
init → up → configure → Prowlarr indexers → optional Maintainerr / Recyclarr
```

| Step | Time | Action |
| --- | --- | --- |
| 1 | ~10 min | [Install](04-install.md): `init`, review `.env` (VPN if needed), `up` |
| 2 | ~2 min | `./bin/flixbox configure` |
| 3 | ~10 min | Add indexers in Prowlarr — [First-run](05-first-run.md) |

Preview configure without changes:

```bash
./bin/flixbox configure --dry-run   # no .env writes, no API calls; stack must be up
```

## Credentials quick map

| Credential | Used by | Where |
| --- | --- | --- |
| Radarr/Sonarr/Prowlarr API key | Compose AUTH, Unpackerr, Decluttarr, Seerr, Bazarr | Generated by `init` → `.env` |
| qBit username/password | Decluttarr, configure | `.env` `QBITTORRENT_*` (init) |
| `FLIXBOX_ADMIN_*` | Jellyfin startup, Seerr login | `.env` (init) |
| Jellyfin API key | Seerr, Maintainerr | Created by configure → `.env` |

*arr auth follows `FLIXBOX_ACCESS_PROFILE` (ADR 0015): default **`trusted`** = no UI login on LAN; **`shared`** = Forms login + admin ports on `127.0.0.1` — apply with `credentials set arr-ui` / `configure --sync-arr-ui` (ADR 0020). See [13 — Access profiles](13-access-profiles.md). Do not publish *arr ports to the WAN.

Full detail: [Configuration — Credentials](06-configuration.md#credentials-and-api-keys).

## Common fixes

| Symptom | Try |
| --- | --- |
| `.env` change ignored | `./bin/flixbox reload` |
| qBit WebUI shows plain `Unauthorized` | [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| `configure` fails VPN check | Wait for Gluetun healthy: `./bin/flixbox logs gluetun` |
| Torrents stuck at metaDL (VPN) | Confirm `tun0` bind — `./bin/flixbox configure` + custom-services sidecar |
| Hardlinks fail / double disk use | Same filesystem for `${DATA_DIR}` — [How it works](02-how-it-works.md) |
| Decluttarr idle | Ensure `QBITTORRENT_*` in `.env`, then `configure` or `reload` |

More: [Troubleshooting](10-troubleshooting.md).

## Related docs

- [Legal disclaimer](16-legal-disclaimer.md) · [Aviso legal (ES)](../es/user/16-legal-disclaimer.md)
- [Install](04-install.md) · [First-run](05-first-run.md) · [Configuration](06-configuration.md)
- [VPN and Direct](07-vpn-and-direct.md) · [Operations](09-operations.md)
