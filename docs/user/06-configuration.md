# Configuration

Environment variables live in `.env` (created from `.env.example` or by `./bin/flixbox init`). **Never commit `.env`.**

The template file groups variables by when you need them: **required before first `up`**, **optional**, **after first-run**, and **VPN only**. This page is the full reference.

## Setup order

1. **Before first `up`:** `DATA_DIR`, `CONFIG_DIR`, `FLIXBOX_MODE`, `TZ`, `PUID`/`PGID` if not 1000.
2. **Start stack:** `./bin/flixbox up`
3. **After *arr first login:** `RADARR_API_KEY`, `SONARR_API_KEY` → `./bin/flixbox up`
4. **If qBit auth enabled:** `QBITTORRENT_USERNAME`, `QBITTORRENT_PASSWORD`
5. **VPN mode only:** Gluetun credentials → `./bin/flixbox vpn-test`
6. **UI wiring:** [First-run setup](05-first-run.md)

## Required before first `up`

Platform defaults when you run `./bin/flixbox init` (new `.env`):

| OS | `DATA_DIR` | `CONFIG_DIR` |
| --- | --- | --- |
| Linux | `/srv/flixbox/data` | `/srv/flixbox/config` |
| macOS | `$HOME/flixbox/data` | `$HOME/flixbox/config` |

`.env.example` shows the Linux reference paths. `init` rewrites them on macOS.

| Variable | Default | Valid values | Notes |
| --- | --- | --- | --- |
| `FLIXBOX_MODE` | `direct` | `direct`, `vpn` | Selects `compose/downloaders-*.yml`. See [VPN and Direct](07-vpn-and-direct.md). |
| `VPN_ENABLED` | `false` | `true`, `false` | Must match mode. `flixbox init` syncs this from `FLIXBOX_MODE`. |
| `DATA_DIR` | OS-dependent (table above) | Absolute path | Torrents + media on one filesystem for hardlinks. Not NFS/SMB/exFAT; not WSL `/mnt/c`. **If you change this after setup**, see [Day-2 — Changing paths](09-operations.md#changing-paths-and-storage-layout). |
| `CONFIG_DIR` | OS-dependent (table above) | Absolute path | App configs on local SSD/NVMe only. Changing it is a config migration — same guide. |
| `COMPOSE_PROJECT_NAME` | `flixbox` | Docker project name | Rarely changed. |

## File ownership and timezone

| Variable | Default | Notes |
| --- | --- | --- |
| `PUID` | `1000` (Linux) / `id -u` (macOS via `init`) | UID for linuxserver-style containers and file ownership. |
| `PGID` | `1000` (Linux) / `id -g` (macOS via `init`) | GID; should match the group that owns `DATA_DIR`. |
| `UMASK` | `002` | Group-writable new files (`init` also sets SGID on data dirs). |
| `TZ` | `UTC` | IANA timezone for all containers. |

## Host ports

Change **only** if the default port is already bound on the host. Internal service ports inside containers do not change.

After changing any `*_PORT` in `.env`:

1. Run `./bin/flixbox up` so Compose republishes ports.
2. Update `${CONFIG_DIR}/homepage/services.yaml` links to match (or run `./bin/flixbox sync-templates` when available).
3. *arr download clients still use **internal** ports (`8080` for qBit) — see [Download client URLs](#download-client-urls-arr-ui).

| Variable | Default | Service |
| --- | --- | --- |
| `HOMEPAGE_PORT` | `3000` | Homepage |
| `SEERR_PORT` | `5055` | Seerr |
| `JELLYFIN_PORT` | `8096` | Jellyfin |
| `QBITTORRENT_PORT` | `8080` | qBittorrent WebUI (published on Gluetun in VPN mode). Browser uses this port; *arr use internal **8080**. If remapped, see [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) (Host header vs Docker publish). |
| `QBITTORRENT_BT_PORT` | `6881` | BitTorrent listen port |
| `FLIXBOX_QBIT_FORCE_PATHS` | `false` | If `true`, qBit save paths reset to `/data/torrents/...` every start. Default: only fix missing or linuxserver `/downloads/` paths ([First-run §2c](05-first-run.md#2c-download-paths-automatic)). |
| `PROWLARR_PORT` | `9696` | Prowlarr |
| `BYPARR_PORT` | `8191` | Byparr |
| `RADARR_PORT` | `7878` | Radarr |
| `SONARR_PORT` | `8989` | Sonarr |
| `BAZARR_PORT` | `6767` | Bazarr |
| `MAINTAINERR_PORT` | `6246` | Maintainerr |
| `PLEX_PORT` | `32400` | Plex (profile `plex`) |
| `CADDY_HTTP_PORT` | `80` | Caddy HTTP (profile `proxy`) |
| `CADDY_HTTPS_PORT` | `443` | Caddy HTTPS (profile `proxy`) |

## Optional Compose profiles

| Variable | Values | Effect |
| --- | --- | --- |
| `COMPOSE_PROFILES` | `plex`, `proxy`, `socket-proxy`, `recyclarr` (comma-separated) | Enables optional services. |

Alternative without editing `.env`:

```bash
./bin/flixbox up plex proxy
docker compose --profile recyclarr run --rm recyclarr sync
```

| Profile | Service |
| --- | --- |
| `plex` | Plex media server |
| `proxy` | Caddy reverse proxy |
| `socket-proxy` | Read-only Docker socket proxy for Homepage |
| `recyclarr` | TRaSH Guides sync (one-shot via `run`) |

## After first-run (API keys and auth)

| Variable | When required | Source |
| --- | --- | --- |
| `RADARR_API_KEY` | Unpackerr, Decluttarr | Radarr → Settings → General |
| `SONARR_API_KEY` | Unpackerr, Decluttarr | Sonarr → Settings → General |
| `QBITTORRENT_USERNAME` | Decluttarr, if qBit auth on | qBittorrent WebUI |
| `QBITTORRENT_PASSWORD` | Decluttarr, if qBit auth on | qBittorrent WebUI |

The stack **starts** without API keys. Unpackerr and Decluttarr cannot talk to *arr until keys are set. After editing `.env`, run `./bin/flixbox up` to recreate those containers.

Recyclarr reads API keys from `${CONFIG_DIR}/recyclarr/recyclarr.yml` (template copied by `init`), not from `.env`.

## Decluttarr tuning

| Variable | Default | Notes |
| --- | --- | --- |
| `DECLUTTARR_QBIT_URL` | mode-dependent | `http://qbittorrent:8080` (direct) or `http://gluetun:8080` (vpn). Set by `flixbox init`. |
| `DECLUTTARR_REMOVE_TIMER` | `10` | Minutes between queue checks. |
| `DECLUTTARR_STRIKES` | `5` | Strikes before stalled/slow removal. |
| `DECLUTTARR_MIN_SPEED` | `100` | Minimum KiB/s before "slow" removal. |

Defaults match [09-hygiene-defaults.md](../09-hygiene-defaults.md). Protected tag `flixbox-keep` is set in Compose.

## App-specific

| Variable | Default | Notes |
| --- | --- | --- |
| `HOMEPAGE_ALLOWED_HOSTS` | `localhost:3000,127.0.0.1:3000` | Add `host:port` when accessing Homepage by LAN IP or DNS. |
| `JELLYFIN_PUBLISHED_URL` | (empty) | Public URL for Jellyfin when behind Caddy/reverse proxy. |
| `SEERR_LOG_LEVEL` | `info` | `error`, `warn`, `info`, `debug`. |
| `PLEX_CLAIM` | (empty) | One-time claim token from [plex.tv/claim](https://www.plex.tv/claim/) (profile `plex`). |

## VPN only (Gluetun)

Ignore when `FLIXBOX_MODE=direct`. Full guide: [VPN and Direct](07-vpn-and-direct.md).

| Variable | Default | Notes |
| --- | --- | --- |
| `VPN_SERVICE_PROVIDER` | `protonvpn` | Gluetun provider id — see [gluetun-wiki](https://github.com/qdm12/gluetun-wiki). |
| `VPN_TYPE` | `wireguard` | `wireguard` or `openvpn`. |
| `WIREGUARD_PRIVATE_KEY` | (empty) | Required for WireGuard providers. |
| `WIREGUARD_ADDRESSES` | (empty) | e.g. `10.x.x.x/32` from provider. |
| `SERVER_COUNTRIES` | (empty) | Optional server filter. |
| `SERVER_CITIES` | (empty) | Optional server filter. |
| `SERVER_REGIONS` | (empty) | Optional server filter. |
| `OPENVPN_USER` | (empty) | OpenVPN username. |
| `OPENVPN_PASSWORD` | (empty) | OpenVPN password. |
| `BLOCK_IPV6` | `on` | Block IPv6 through tunnel (recommended). |
| `DOT` | `on` | DNS over TLS. |
| `VPN_PORT_FORWARDING` | `off` | Set `on` only if provider supports it; enable qBit localhost auth bypass. |
| `FIREWALL_OUTBOUND_SUBNETS` | (empty) | LAN CIDR (e.g. `192.168.1.0/24`) for host/LAN access through Gluetun. |

Verify after start: `./bin/flixbox vpn-test`.

## Download client URLs (*arr UI)

Configure in Radarr/Sonarr (not only in `.env`):

| Mode | Download client host | Port |
| --- | --- | --- |
| `direct` | `qbittorrent` | `8080` |
| `vpn` | `gluetun` | `8080` |

`DECLUTTARR_QBIT_URL` must use the same host as above.

## Secrets

- Store credentials only in `.env` or `${CONFIG_DIR}` volumes.
- Never commit `.env`, VPN keys, or API tokens to git.
- `.env.example` uses empty placeholders only.

## Image tags

Early builds use `:latest` ([ADR 0010](../adr/0010-mit-and-image-tags.md)). Pin before production v0.1.

## Next

[VPN and Direct](07-vpn-and-direct.md) · [First-run setup](05-first-run.md) · [Hygiene](08-hygiene.md)
