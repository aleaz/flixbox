# Install

> **Implementation status:** Full MVP Compose stack + `bin/flixbox` CLI are available. Optional profiles: `plex`, `proxy`, `socket-proxy`, `recyclarr`.

## Bootstrap

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
./bin/flixbox init --non-interactive
# Edit .env — see docs/user/06-configuration.md (DATA_DIR, FLIXBOX_MODE, TZ, VPN if needed)
./bin/flixbox up
./bin/flixbox status
./bin/flixbox configure   # after logging into each app once
```

Or manually:

```bash
cp .env.example .env
./scripts/bootstrap-dirs.sh
docker compose up -d
```

### Modes

| `FLIXBOX_MODE` | Download client for *arr / Decluttarr |
| --- | --- |
| `direct` or `vpn` | `http://qbittorrent:8080` (VPN: alias on Gluetun — ADR 0014) |

VPN: fill Gluetun secrets in `.env`, then `./scripts/vpn-test.sh` or `./bin/flixbox vpn-test`.

### qBittorrent paths and ports

- Default host WebUI: port `8080` (`QBITTORRENT_PORT` in `.env`)
- Inside Docker, WebUI stays on port **8080**; *arr always use host **`qbittorrent`** (ADR 0014).
- Custom host port example: `QBITTORRENT_PORT=9898` → browser `http://localhost:9898`, *arr still `8080`
- First-run password: `docker compose logs qbittorrent`
- VPN port-forward: enable **Bypass authentication for clients on localhost**
- Stale config after port changes: see [First-run §2e](05-first-run.md#2e-custom-host-ports-and-stale-config)

### Optional profiles

```bash
./bin/flixbox up plex proxy
# COMPOSE_PROFILES=plex,proxy in .env also works
```

### Recyclarr sync

```bash
docker compose --profile recyclarr run --rm recyclarr sync
```

## Default ports

| Service | Port |
| --- | --- |
| Homepage | 3000 |
| Seerr | 5055 |
| Jellyfin | 8096 |
| qBittorrent | 8080 |
| Prowlarr | 9696 |
| Byparr | 8191 |
| Radarr | 7878 |
| Sonarr | 8989 |
| Bazarr | 6767 |
| Maintainerr | 6246 |
| Caddy | 80/443 (profile `proxy`) |

## Next

[First-run setup](05-first-run.md) — `./bin/flixbox configure` then remaining UI steps.  
[Quick reference](REFERENCE.md) — ports, URLs, CLI.
