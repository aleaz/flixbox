# Compose modules

| File | Status | Role |
| --- | --- | --- |
| `network-base.yml` | **active** | `flixbox_net` bridge |
| `downloaders-direct.yml` | **active** | qBittorrent (`FLIXBOX_MODE=direct`) |
| `downloaders-vpn.yml` | **active** | Gluetun + qBittorrent (`FLIXBOX_MODE=vpn`) |
| `servarr.yml` | planned | Prowlarr, Radarr, Sonarr, Bazarr, Byparr |
| `optimization.yml` | planned | Unpackerr, Recyclarr, Decluttarr, Maintainerr |
| `media-servers.yml` | planned | Jellyfin (+ optional Plex) |
| `requests.yml` | planned | Seerr |
| `dashboard.yml` | planned | Homepage |
| `proxy.yml` | planned | Caddy |

Root entrypoint: [`../compose.yaml`](../compose.yaml) includes `downloaders-${FLIXBOX_MODE}.yml`.

## Dual-mode rule

Set **one** mode in `.env`:

```bash
FLIXBOX_MODE=direct   # http://qbittorrent:8080 for *arr
# or
FLIXBOX_MODE=vpn      # http://gluetun:8080 for *arr
VPN_ENABLED=true
```

Never attach *arr / Seerr / Jellyfin to Gluetun’s network namespace. Only qBittorrent uses `network_mode: service:gluetun`.

Switching modes: `docker compose down` then change `FLIXBOX_MODE` and `docker compose up -d`.
