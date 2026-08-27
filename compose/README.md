# Compose modules

| File | Status | Role |
| --- | --- | --- |
| `network-base.yml` | **active** | `flixbox_net` bridge |
| `downloaders-direct.yml` | **active** | qBittorrent (`profile: direct`) |
| `downloaders-vpn.yml` | planned | Gluetun + qBittorrent (`profile: vpn`) |
| `servarr.yml` | planned | Prowlarr, Radarr, Sonarr, Bazarr, Byparr |
| `optimization.yml` | planned | Unpackerr, Recyclarr, Decluttarr, Maintainerr |
| `media-servers.yml` | planned | Jellyfin (+ optional Plex) |
| `requests.yml` | planned | Seerr |
| `dashboard.yml` | planned | Homepage |
| `proxy.yml` | planned | Caddy |

Root entrypoint: [`../compose.yaml`](../compose.yaml).

## Dual-mode rule

Only one downloader profile at a time (`COMPOSE_PROFILES=direct` **or** `vpn`). Never attach *arr / Seerr / Jellyfin to Gluetun’s network namespace.
