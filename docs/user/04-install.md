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
| `direct` | `http://qbittorrent:8080` |
| `vpn` | `http://gluetun:8080` |

VPN: fill Gluetun secrets in `.env`, then `./scripts/vpn-test.sh` or `./bin/flixbox vpn-test`.

### qBittorrent paths

- Default: `/data/torrents`
- Incomplete: `/data/torrents/incomplete`
- First-run password: `docker compose logs qbittorrent`
- VPN port-forward: enable **Bypass authentication for clients on localhost**

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

[First-run setup](05-first-run.md) — wire APIs in the UI.
