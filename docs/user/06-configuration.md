# Configuration

Environment variables live in `.env` (created from `.env.example` or by `./bin/flixbox init`). **Never commit `.env`.**

The template file groups variables by when you need them: **required before first `up`**, **optional**, **after first-run**, and **VPN only**. This page is the full reference.

## Setup order

1. **Before first `up`:** `DATA_DIR`, `CONFIG_DIR`, `FLIXBOX_MODE`, `TZ`, `PUID`/`PGID` if not 1000.
2. **Start stack:** `./bin/flixbox up`
3. **After each *arr first login:** `./bin/flixbox configure` (or manual wiring in [First-run](05-first-run.md))
4. **After configure / *arr login:** copy remaining credentials per [Credentials and API keys](#credentials-and-api-keys) → `./bin/flixbox reload`
5. **VPN mode only:** Gluetun credentials → `./bin/flixbox vpn-test`
6. **Remaining UI:** indexers, Jellyfin, Seerr — [First-run setup](05-first-run.md)

Quick lookup: [REFERENCE](REFERENCE.md).

## Required before first `up`

Platform defaults when you run `./bin/flixbox init` (new `.env`):

| OS | `DATA_DIR` | `CONFIG_DIR` |
| --- | --- | --- |
| Linux | `/srv/flixbox/data` | `/srv/flixbox/config` |
| macOS | `$HOME/flixbox/data` | `$HOME/flixbox/config` |

`.env.example` shows the Linux reference paths. `init` rewrites them on macOS.

On Linux, `/srv/flixbox/…` is not writable until you create it (usually with `sudo`) or you choose another path — see [Install — Storage paths and permissions](04-install.md#storage-paths-and-permissions). Flixbox reads paths from `.env` only; shell `export DATA_DIR=…` does not affect `init` or `up` unless you also write that value into `.env`.

| Variable | Default | Valid values | Notes |
| --- | --- | --- | --- |
| `FLIXBOX_MODE` | `direct` | `direct`, `vpn` | **Only switch Compose reads** for downloaders. See [VPN and Direct](07-vpn-and-direct.md). |
| `VPN_ENABLED` | `false` | `true`, `false` | **Not read by Compose.** Mirror of mode; `init` syncs it. Keep aligned (`direct`↔`false`, `vpn`↔`true`) so docs/CLI stay honest. |
| `DATA_DIR` | OS-dependent (table above) | Absolute path | Torrents + media on one filesystem for hardlinks. Not NFS/SMB/exFAT; not WSL `/mnt/c`. **If you change this after setup**, see [Day-2 — Changing paths](09-operations.md#changing-paths-and-storage-layout). |
| `CONFIG_DIR` | OS-dependent (table above) | Absolute path | App configs on local SSD/NVMe only. Changing it is a config migration — same guide. |
| `COMPOSE_PROJECT_NAME` | `flixbox` | Docker project name | Rarely changed. |

## Access profile (ADR 0015)

Full guide: [13 — Access profiles](13-access-profiles.md).

| Variable | Default | Values | Effect |
| --- | --- | --- | --- |
| `FLIXBOX_ACCESS_PROFILE` | `trusted` | `trusted`, `shared` | `trusted`: *arr WebUI open on LAN (RFC1918). `shared`: *arr require login (`Forms`). |
| `FLIXBOX_ARR_AUTH_METHOD` | *(from profile)* | `External`, `Forms` | Set by `init` — do not hand-edit unless you know Servarr auth. |
| `FLIXBOX_ARR_AUTH_REQUIRED` | *(from profile)* | `DisabledForLocalAddresses`, `Enabled` | `Enabled` in `shared`. |
| `FLIXBOX_ARR_UI_USER` | `admin` | string | **Reference** for manual Forms signup (`shared` only). Not applied by Compose or `configure`. |
| `FLIXBOX_ARR_UI_PASSWORD` | *(generated)* | string | **Reference** for manual Forms signup; **`configure` uses API keys, not this.** |

Servarr has no env var for Forms username/password — see [13 — Create *arr login](13-access-profiles.md#create-arr-login-shared).

After changing `FLIXBOX_ACCESS_PROFILE`: `./bin/flixbox init --non-interactive` then recreate *arr containers.

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

## Credentials and API keys

Flixbox uses **five credential types** for inter-app wiring (plus per-indexer tracker accounts in Prowlarr). They are not interchangeable — each consumer expects the one listed below.

| Credential | Used by | Where to configure | Notes |
| --- | --- | --- | --- |
| qBittorrent **WebUI login** (username + password) | You (browser), **Decluttarr** | qBit WebUI; `.env` as `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` | Default user is `admin`. Change the temporary password after first login. Decluttarr does **not** use qBit’s API key. |
| qBittorrent **API key** | **Radarr**, **Sonarr** (download client) | qBit → **Options → Web UI → API access**; paste in *arr → **Settings → Download Clients → qBittorrent** | **Recommended:** use API key only; leave username/password empty in *arr. See [First-run §3b](05-first-run.md#3b-download-client-qbittorrent). |
| **Radarr** API key | Unpackerr, Decluttarr; also Prowlarr Apps, Seerr, Bazarr, Maintainerr, Recyclarr | Radarr → Settings → General | Same key everywhere — `.env` for Compose services; each app’s UI or `recyclarr.yml` for the rest. See [App-to-app connections](#app-to-app-connections). |
| **Sonarr** API key | Unpackerr, Decluttarr; also Prowlarr Apps, Seerr, Bazarr, Maintainerr, Recyclarr | Sonarr → Settings → General | Same as Radarr — per-app key. |
| **Jellyfin** API key | Seerr, Maintainerr | Jellyfin → Dashboard → **API Keys** | Created after the Jellyfin admin account exists. Not stored in `.env`. |

**Recyclarr** uses Radarr/Sonarr API keys in `${CONFIG_DIR}/recyclarr/recyclarr.yml` (template copied by `init`), not in `.env`.

The stack **starts** without after-first-run keys. Unpackerr cannot talk to *arr until `RADARR_API_KEY` and `SONARR_API_KEY` are set. Decluttarr **idles** (no qBit login) until both `QBITTORRENT_USERNAME` and `QBITTORRENT_PASSWORD` are set — see [ADR 0008](../adr/0008-maintenance-decluttarr-maintainerr.md). After editing `.env`, run `./bin/flixbox up` to recreate affected containers.

### `.env` variables (after first-run)

| Variable | When required | Source |
| --- | --- | --- |
| `RADARR_API_KEY` | Unpackerr, Decluttarr | Radarr → Settings → General |
| `SONARR_API_KEY` | Unpackerr, Decluttarr | Sonarr → Settings → General |
| `QBITTORRENT_USERNAME` | Decluttarr (once qBit WebUI auth is on) | qBittorrent WebUI login |
| `QBITTORRENT_PASSWORD` | Decluttarr (once qBit WebUI auth is on) | qBittorrent WebUI login |

### App-to-app connections

Most Flixbox apps talk over the Docker network (`flixbox_net`). Only **Unpackerr**, **Decluttarr**, and **Gluetun** read auth from `.env`; everything else stores connections in its own UI or config file.

| App | Connects to | Credential | Where to configure |
| --- | --- | --- | --- |
| **Prowlarr** | Radarr, Sonarr | Each *arr **API key** | Prowlarr → Settings → Apps — [First-run §1](05-first-run.md#1-prowlarr--byparr) |
| **Prowlarr** | Indexers (trackers) | Per-indexer login/API | Prowlarr → Indexers (external accounts; not in `.env`) |
| **Prowlarr** | Byparr | *(none)* | Proxy host `byparr`, port `8191` — internal HTTP only |
| **Radarr / Sonarr** | qBittorrent | qBit **API key** | *arr → Download Clients — [First-run §3b](05-first-run.md#3b-download-client-qbittorrent) |
| **Seerr** | Jellyfin, Radarr, Sonarr | Each service **API key** | Seerr setup wizard / Settings — [First-run §6](05-first-run.md#6-seerr) |
| **Bazarr** | Radarr, Sonarr | *arr **API keys** | Bazarr UI — [First-run §4](05-first-run.md#4-bazarr) |
| **Maintainerr** | Jellyfin, Radarr, Sonarr | Each service **API key** | Maintainerr UI — [First-run §8](05-first-run.md#8-decluttarr--maintainerr) |
| **Recyclarr** | Radarr, Sonarr | *arr **API keys** | `${CONFIG_DIR}/recyclarr/recyclarr.yml` |
| **Unpackerr** | Radarr, Sonarr | *arr **API keys** | `.env` (`RADARR_API_KEY`, `SONARR_API_KEY`) |
| **Decluttarr** | Radarr, Sonarr, qBit | *arr API keys + qBit **user/pass** | `.env` — table above |
| **Jellyfin** | *(served to users)* | Admin account + optional users | Jellyfin first-run wizard |
| **Seerr** | *(request portal users)* | Seerr login accounts | Seerr UI (separate from Jellyfin users) |
| **Homepage** | *(links only)* | *(none)* | `${CONFIG_DIR}/homepage/services.yaml` — no API auth |
| **Byparr** | *(CF proxy)* | *(none)* | No login; not exposed beyond your LAN unless you publish it |

There is no `SEERR_API_KEY` or `PROWLARR_API_KEY` in `.env` — those apps expose their own API keys only if you integrate them externally.

## Decluttarr tuning

| Variable | Default | Notes |
| --- | --- | --- |
| `DECLUTTARR_QBIT_URL` | `http://qbittorrent:8080` | Always (ADR 0014). Set/normalized by `flixbox init`. |
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

**Mode is not in this table** — set `FLIXBOX_MODE=vpn` and `VPN_ENABLED=true` in the **REQUIRED** section of `.env` (top), then fill the variables below. `flixbox init` syncs `VPN_ENABLED` and `DECLUTTARR_QBIT_URL`.

| Variable | Default | Notes |
| --- | --- | --- |
| `VPN_SERVICE_PROVIDER` | `protonvpn` | Gluetun provider id, or `custom` for a mounted `.ovpn` — see [gluetun-wiki](https://github.com/qdm12/gluetun-wiki). |
| `VPN_TYPE` | `wireguard` | `wireguard` or `openvpn`. |
| `WIREGUARD_PRIVATE_KEY` | (empty) | Required for WireGuard providers. |
| `WIREGUARD_ADDRESSES` | (empty) | e.g. `10.x.x.x/32` from provider. |
| `SERVER_COUNTRIES` | (empty) | Optional server filter. |
| `SERVER_CITIES` | (empty) | Optional server filter. |
| `SERVER_REGIONS` | (empty) | Optional server filter. |
| `OPENVPN_USER` | (empty) | OpenVPN username (native or custom). |
| `OPENVPN_PASSWORD` | (empty) | OpenVPN password. |
| `OPENVPN_CUSTOM_CONFIG` | (empty) | Container path to a custom `.ovpn` (e.g. `/gluetun/custom.conf`). File lives under `${CONFIG_DIR}/gluetun/`. Requires `VPN_SERVICE_PROVIDER=custom`. `remote` in the file must be an IP, not a hostname. |
| `BLOCK_IPV6` | `on` | Block IPv6 through tunnel (recommended). |
| `DOT` | `on` | DNS over TLS. |
| `VPN_PORT_FORWARDING` | `off` | Set `on` only if provider supports it; enable qBit localhost auth bypass. |
| `FIREWALL_OUTBOUND_SUBNETS` | (empty) | LAN CIDR (e.g. `192.168.1.0/24`) for host/LAN access through Gluetun. |

Verify after start: `./bin/flixbox vpn-test`. Full privacy checklist: [Torrent privacy and security](12-torrent-privacy-and-security.md).

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
