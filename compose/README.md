# Compose modules

| File | Status | Role |
| --- | --- | --- |
| `network-base.yml` | active | `flixbox_net` — fixed subnet `172.30.42.0/24` (see file header: Decluttarr ban fix / qBit whitelist sync) |
| `downloaders-direct.yml` | active | qBittorrent (`FLIXBOX_MODE=direct`) |
| `downloaders-vpn.yml` | active | Gluetun + qBittorrent (`FLIXBOX_MODE=vpn`) |
| `servarr.yml` | active | Prowlarr, Byparr, Radarr, Sonarr, Bazarr |
| `optimization.yml` | active | Unpackerr, Recyclarr, Decluttarr, Maintainerr |
| `media-servers.yml` | active | Jellyfin (+ optional `plex` profile) |
| `requests.yml` | active | Seerr |
| `dashboard.yml` | active | Homepage + always-on `docker-socket-proxy` |
| `proxy.yml` | active | Caddy (`proxy` profile) |
| `notifications.yml` | active | Apprise API (`notifications` profile) |
| `vpn-heal.yml` | active | gluetun-monitor + heal socket-proxy (`vpn-heal` profile) |

Root: [`../compose.yaml`](../compose.yaml).

## Dual-mode

```bash
FLIXBOX_MODE=direct   # *arr client http://qbittorrent:8080
FLIXBOX_MODE=vpn      # same host; Gluetun carries qbittorrent alias
```

Never put *arr / Seerr / Jellyfin on Gluetun’s netns.

## Optional profiles

```bash
docker compose --profile plex --profile proxy up -d
docker compose --profile recyclarr run --rm recyclarr sync
docker compose --profile notifications up -d
# VPN mode only:
docker compose --profile vpn-heal up -d
# or: ./bin/flixbox up plex proxy notifications vpn-heal
```
