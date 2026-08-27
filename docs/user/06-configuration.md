# Configuration

## Paths

| Variable | Typical default | Purpose |
| --- | --- | --- |
| `DATA_DIR` | `/srv/flixbox/data` | Torrents + media (hardlink tree) |
| `CONFIG_DIR` | `/srv/flixbox/config` | App databases (local SSD) |
| `PUID` / `PGID` | `1000` / `1000` | File ownership |
| `UMASK` | `002` | Group-writable new files |
| `TZ` | e.g. `America/Argentina/Buenos_Aires` | Timezone |
| `VPN_ENABLED` | `true` / `false` | Dual-mode switch |

Secrets belong in `.env` or provider files under config — never in git.

## Default ports

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

In VPN mode, qBittorrent’s UI port is published on the **Gluetun** service.

## Compose profiles (planned)

Examples of optional toggles:

- Plex media server
- docker-socket-proxy for Homepage
- Proxy-only / media-only subsets via `flixbox up <profile>`

Exact profile names will match the Compose files when implemented.

## Image tags

Early development may use `:latest`. Pin versions before you treat a deploy as production / before v0.1 — see [ADR 0010](../adr/0010-mit-and-image-tags.md).

## Next

[VPN and Direct](07-vpn-and-direct.md)
