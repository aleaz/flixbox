# Configuration

## Paths and mode

| Variable | Typical default | Purpose |
| --- | --- | --- |
| `FLIXBOX_MODE` | `direct` | `direct` or `vpn` downloader include |
| `VPN_ENABLED` | `false` | Keep aligned with mode |
| `DATA_DIR` | `/srv/flixbox/data` | Torrents + media (hardlinks) |
| `CONFIG_DIR` | `/srv/flixbox/config` | App configs (local SSD) |
| `PUID` / `PGID` | `1000` | File ownership |
| `UMASK` | `002` | Group-writable creates |
| `DECLUTTARR_QBIT_URL` | mode-dependent | `http://qbittorrent:8080` or `http://gluetun:8080` |

Secrets only in `.env` / config volumes — never in git.

## Ports

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
| Caddy | 80 / 443 |

## Optional profiles

`plex`, `proxy`, `socket-proxy`, `recyclarr` — via `COMPOSE_PROFILES` or `./bin/flixbox up <profile>` / `docker compose --profile recyclarr run ...`.

## Image tags

Early builds use `:latest` ([ADR 0010](../adr/0010-mit-and-image-tags.md)). Pin before production v0.1.

## Next

[VPN and Direct](07-vpn-and-direct.md)
