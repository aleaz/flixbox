# Configuration

Environment variables live in `.env` (created from `.env.example` or by `./bin/flixbox init`). **Never commit `.env`.**

The template file groups variables by when you need them: **required before first `up`**, **optional**, **after first-run**, and **VPN only**. This page is the full reference.

## Setup order

1. **Before first `up`:** `DATA_DIR`, `CONFIG_DIR`, `FLIXBOX_MODE`, `TZ`, `PUID`/`PGID` if not 1000, and optionally `FLIXBOX_ACCESS_PROFILE` (`trusted` default, or `shared` on shared Wi‑Fi — [§13](13-access-profiles.md)).
2. **Start stack:** `./bin/flixbox up` (syncs derived bind/auth keys if the profile drifted)
3. **Wire apps:** `./bin/flixbox configure` — see [First-run §0](05-first-run.md#0-script-assisted-wiring-recommended) for what it configures
4. **After configure:** only if you changed secrets by hand — [Credentials and API keys](#credentials-and-api-keys) → `./bin/flixbox reload` when Compose consumers need new `.env` values
5. **VPN mode only:** Gluetun credentials in `.env` before `up`/`reload` → `./bin/flixbox vpn-test`
6. **Still manual:** Prowlarr indexers; optional Maintainerr rules / Recyclarr sync; `shared` Forms via `credentials set arr-ui` — [First-run](05-first-run.md)

Quick lookup: [REFERENCE](REFERENCE.md).

## Required before first `up`

Platform defaults when you run `./bin/flixbox init` (new `.env`):

| OS | `DATA_DIR` | `CONFIG_DIR` |
| --- | --- | --- |
| Linux | `/srv/flixbox/data` | `/srv/flixbox/config` |
| macOS (OrbStack / Docker Desktop) | `$HOME/flixbox/data` | `$HOME/flixbox/config` |

`.env.example` shows the Linux reference paths. `init` rewrites them on macOS. **OrbStack** is a supported macOS dev runtime; tag v0.1 smoke still targets Linux.

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
| `FLIXBOX_ACCESS_PROFILE` | `trusted` | `trusted`, `shared` | `trusted`: *arr WebUI open on LAN (RFC1918). `shared`: *arr require login (`Forms`) + admin ports on localhost. |
| `FLIXBOX_ARR_AUTH_METHOD` | *(from profile)* | `External`, `Forms` | Set by `init` — do not hand-edit unless you know Servarr auth. |
| `FLIXBOX_ARR_AUTH_REQUIRED` | *(from profile)* | `DisabledForLocalAddresses`, `Enabled` | `Enabled` in `shared`. |
| `FLIXBOX_ADMIN_BIND_IP` | *(from profile)* | `0.0.0.0`, `127.0.0.1` | Host bind for admin WebUIs (*arr, Byparr, Bazarr, Maintainerr, qBit WebUI). Set by `init`. |
| `FLIXBOX_ARR_UI_USER` | `admin` | string | Forms username SoT (`shared` only). Applied by `credentials set arr-ui` / `configure --sync-arr-ui` (ADR 0020). |
| `FLIXBOX_ARR_UI_PASSWORD` | *(generated)* | string | Forms password SoT; **`configure` without `--sync-arr-ui` uses API keys, not this.** |

Servarr has no env var for Forms username/password — see [13 — Create *arr login](13-access-profiles.md#create-arr-login-shared) and [ADR 0020](../adr/0020-operator-credentials-cli.md).

After changing `FLIXBOX_ACCESS_PROFILE`: `./bin/flixbox up`, `reload`, or `configure` (auto-syncs derived keys; **`configure` also syncs Homepage** so `shared` drops admin widget secrets). Optionally `./bin/flixbox init --non-interactive` so shared UI password placeholders are generated if empty. Then apply Forms with `credentials set arr-ui`.

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

1. Run `./bin/flixbox reload` (or `up`) so Compose republishes ports and Homepage links in `${CONFIG_DIR}/homepage/services.yaml` are automatically synchronized (custom widgets and services are preserved).
2. If `up`/`reload` warn that **Homepage templates are newer than live config**, run `./bin/flixbox homepage refresh` (or `reload --reset-homepage`) so layout/CSS/icons from the repo replace the live managed files (a timestamped backup is written under `${CONFIG_DIR}/homepage.bak.*`).
2. *arr download clients still use **internal** ports (`8080` for qBit) — see [Download client URLs](#download-client-urls-arr-ui).

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
| `COMPOSE_PROFILES` | `plex`, `proxy`, `recyclarr` (comma-separated) | Enables optional services. `docker-socket-proxy` is always on with Homepage. |

Alternative without editing `.env`:

```bash
./bin/flixbox up plex proxy
docker compose --profile recyclarr run --rm recyclarr sync
```

| Profile | Service |
| --- | --- |
| `plex` | Plex media server |
| `proxy` | Caddy reverse proxy |
| `recyclarr` | TRaSH Guides sync (one-shot via `run`) |

`docker-socket-proxy` always runs with Homepage (not a profile — [ADR 0022](../adr/0022-operator-footgun-remediations.md)).

## Credentials and API keys

Flixbox uses **five credential types** for inter-app wiring (plus per-indexer tracker accounts in Prowlarr). They are not interchangeable — each consumer expects the one listed below.

| Credential | Used by | Source of truth | Notes |
| --- | --- | --- | --- |
| qBittorrent **WebUI login** (username + password) | You (browser), **Decluttarr**, optionally *arr | **`.env`** (`QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD`) | `init` generates a password; `configure` applies it when qBit still has a temporary one. Decluttarr does **not** use qBit’s API key. |
| qBittorrent **API key** | **Radarr**, **Sonarr** (download client) | qBit config (read by `configure`); also WebUI → Options → Web UI → API access | Not stored in `.env`. `configure` pushes it into *arr. |
| **Radarr** API key | Unpackerr, Decluttarr; also Prowlarr Apps, Seerr, Bazarr, Maintainerr, Recyclarr | Radarr `config.xml` (synced into `.env` by `configure`) | Same key everywhere — see [Accidental / intentional key changes](#accidental--intentional-key-changes). |
| **Sonarr** API key | Same pattern as Radarr | Sonarr `config.xml` → `.env` via `configure` | Same as Radarr. |
| **Jellyfin** API key | Seerr, Maintainerr | Jellyfin → Dashboard → **API Keys** | Created after the Jellyfin admin account exists. |

### Runtime secrets in Docker

Compose passes some credentials as **container environment variables** (for example `QBITTORRENT_PASSWORD`, `RADARR_API_KEY` on Decluttarr). Anyone who can run `docker inspect` or `docker exec` on the host can read them. That is normal for Compose homelab stacks — keep Docker socket access limited to the operator account. API keys also live under `${CONFIG_DIR}` in app config files; treat backups of `config/` like `.env`. See [ADR 0018](../adr/0018-runtime-secrets-and-lan-trust.md) and [Access profiles — threat model](13-access-profiles.md#threat-model-homelab).

<a id="accidental--intentional-key-changes"></a>
<a id="accidental-intentional-key-changes"></a>
### Accidental / intentional key changes

Changing a password or regenerating an API key **in a WebUI alone** does not update every consumer. Use this table — especially after an accidental click on “Regenerate”. For full rotation procedures, see [Credential rotation runbook](15-credential-rotation.md).

| What happened | Breaks | Fix |
| --- | --- | --- |
| **Want a new Flixbox-managed qBit password** | — | **Rotate:** `./bin/flixbox credentials set qbit --generate` (or `--prompt`). Auth with current `.env`/temp → apply new → write `.env` → recreate Decluttarr. |
| **qBit password** changed in WebUI (copied into `.env`) | Decluttarr (and *arr if they rely on password) | **Align:** `./bin/flixbox configure --sync-qbit-auth` |
| **qBit API key** regenerated in WebUI | *arr download client (may still “Test OK” via password while the stored key is stale) | `./bin/flixbox configure` (refreshes drifted keys) or `./bin/flixbox configure --sync-qbit-auth` to force a full push |
| **Want `.env` password applied onto qBit** | — | **Align only:** works if `configure` can still **log in** (`.env` already matches WebUI, **or** temp password in `docker compose logs qbittorrent`). To invent a new password, use `credentials set qbit`, not hand-edit alone. |
| **Radarr / Sonarr API key** regenerated in that app’s UI | `.env`, Decluttarr, Unpackerr, Prowlarr Apps, Bazarr, Seerr; Recyclarr / Maintainerr if already wired | `./bin/flixbox configure` (syncs `.env` from `config.xml`, refreshes Prowlarr/Bazarr/Seerr, recreates Decluttarr/Unpackerr). Then: update **Maintainerr** in its UI; edit `${CONFIG_DIR}/recyclarr/recyclarr.yml` if placeholders were already replaced. |
| Lost qBit WebUI password (no temp in logs) | `configure` / rotate cannot auth | Set a new password in the qBit UI (or wipe `${CONFIG_DIR}/qbittorrent/`), put it in `.env`, then `--sync-qbit-auth` |

#### Rotate vs align vs `configure`

| Command | Typical use |
| --- | --- |
| `./bin/flixbox credentials set qbit …` | **Rotate** WebUI password (old → new); writes `.env` only after qBit accepts the change. |
| `./bin/flixbox configure` | Idempotent first-run wiring; heals drifted qBit API keys on *arr and drifted *arr API keys on Prowlarr/Bazarr/Seerr when Test/compare detects mismatch. |
| `./bin/flixbox configure --sync-qbit-auth` | **Align:** force current `.env` WebUI password onto qBit, rewrite *arr download clients, recreate Decluttarr/Unpackerr — when `.env` already matches a loginable password. |
| `./bin/flixbox configure --sync-arr-ui` | **Force** `FLIXBOX_ARR_UI_*` onto Prowlarr/Radarr/Sonarr Forms (`shared` only — ADR 0020). |
| `./bin/flixbox credentials show\|set …` | Read or rotate operator secrets without hand-editing `.env` — [Credential rotation](15-credential-rotation.md). |

**Recyclarr** uses Radarr/Sonarr API keys in `${CONFIG_DIR}/recyclarr/recyclarr.yml` (template copied by `init`). `configure` only replaces `REPLACE_*` placeholders — it does not rewrite keys already saved in that file.

The stack **starts** without after-first-run keys. Unpackerr cannot talk to *arr until `RADARR_API_KEY` and `SONARR_API_KEY` are set. Decluttarr **idles** (no qBit login) until both `QBITTORRENT_USERNAME` and `QBITTORRENT_PASSWORD` are set — see [ADR 0008](../adr/0008-maintenance-decluttarr-maintainerr.md). After hand-editing **qBit** creds in `.env` to match the WebUI, use `configure --sync-qbit-auth`. To change the password Flixbox manages, prefer `credentials set qbit`. After editing only `RADARR_API_KEY` / `SONARR_API_KEY`, `configure` or `./bin/flixbox reload` is enough for Compose consumers.

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
| **Prowlarr** | Radarr, Sonarr | Each *arr **API key** | **`configure`** (UI fallback: Settings → Apps) — [First-run §1](05-first-run.md#1-prowlarr--byparr) |
| **Prowlarr** | Indexers (trackers) | Per-indexer login/API | **Manual** — Prowlarr → Indexers (not in `.env`) |
| **Prowlarr** | Byparr | *(none)* | **`configure`** when Byparr is running — host `byparr:8191` |
| **Radarr / Sonarr** | qBittorrent | qBit **API key** | **`configure`** (UI fallback: Download Clients) — [First-run §3](05-first-run.md#3-radarr--sonarr--hygiene) |
| **Seerr** | Jellyfin, Radarr, Sonarr | Each service **API key** | **`configure`** (UI fallback if automation fails) — [First-run §4](05-first-run.md#4-bazarr--jellyfin--seerr) |
| **Bazarr** | Radarr, Sonarr | *arr **API keys** | **`configure`** (UI fallback) — [First-run §4](05-first-run.md#4-bazarr--jellyfin--seerr) |
| **Maintainerr** | Jellyfin, Radarr, Sonarr | Each service **API key** | **Manual** in Maintainerr UI — [First-run §5](05-first-run.md#5-recyclarr--maintainerr--homepage) |
| **Recyclarr** | Radarr, Sonarr | *arr **API keys** | `${CONFIG_DIR}/recyclarr/recyclarr.yml` |
| **Unpackerr** | Radarr, Sonarr | *arr **API keys** | `.env` (`RADARR_API_KEY`, `SONARR_API_KEY`) |
| **Decluttarr** | Radarr, Sonarr, qBit | *arr API keys + qBit **user/pass** | `.env` — table above |
| **Jellyfin** | *(served to users)* | Admin account + optional users | Jellyfin first-run wizard |
| **Seerr** | *(request portal users)* | Seerr login accounts | Seerr UI (separate from Jellyfin users) |
| **Homepage** | Dashboard links + optional widgets | **`trusted`:** may sync qBit user/pass and *arr API keys into widget blocks. **`shared`:** admin widgets (qBit/*arr/Bazarr/Maintainerr/Byparr) are **removed**; Jellyfin (and Seerr if a key is present) widgets may still sync. | `${CONFIG_DIR}/homepage/services.yaml` — Homepage UI has no login; do not expose to WAN ([§13](13-access-profiles.md#threat-model-homelab)) |
| **Byparr** | *(CF proxy)* | *(none)* | No login; not exposed beyond your LAN unless you publish it |

`SEERR_API_KEY` is **optional** in `.env` (see `.env.example`). It is **not** used by Compose or `configure` — only by `homepage-sync` for the Seerr dashboard widget. Copy the key from Seerr → Settings → API. If unset, Seerr still works; the Homepage widget stays muted. `JELLYFIN_API_KEY` is similar for Homepage (and may also be written by `configure` when discovered). `PROWLARR_API_KEY` **is** generated by `init` and used by Compose / `configure`.

## Decluttarr tuning

| Variable | Default | Notes |
| --- | --- | --- |
| `DECLUTTARR_QBIT_URL` | `http://qbittorrent:8080` | Always (ADR 0014). Set/normalized by `flixbox init`. |
| `DECLUTTARR_REMOVE_TIMER` | `15` | Minutes between queue checks. |
| `DECLUTTARR_STRIKES` | `12` | Strikes before stalled (and slow, if enabled) removal. Grace ≈ timer × strikes (~3h). |
| `DECLUTTARR_REMOVE_SLOW` | `False` | Absolute KiB/s “slow” removal. Keep off under VPN; CLI warns if on in VPN mode. |

To re-enable slow with a custom floor, set `DECLUTTARR_REMOVE_SLOW=True` (Decluttarr default min_speed) or override `REMOVE_SLOW` with a YAML dict in `compose/optimization.yml` (see [09-hygiene-defaults.md](../09-hygiene-defaults.md)). Protected tag `flixbox-keep` is set in Compose.

## App-specific

| Variable | Default | Notes |
| --- | --- | --- |
| `FLIXBOX_PUBLIC_HOST` | (empty) | LAN IP or DNS (no scheme/port). On `up`/`reload`/`configure`: pins Homepage Jellyfin/Seerr hrefs; appends `host:HOMEPAGE_PORT` to `HOMEPAGE_ALLOWED_HOSTS`; fills empty `JELLYFIN_PUBLISHED_URL`. See [Access profiles — Homepage](13-access-profiles.md#homepage-links-from-phones--tvs). |
| `HOMEPAGE_ALLOWED_HOSTS` | `localhost:3000,127.0.0.1:3000` | Homepage Host allowlist. Auto-extends from `FLIXBOX_PUBLIC_HOST` when set. You can still add extra hosts (Caddy DNS, etc.). |
| `JELLYFIN_PUBLISHED_URL` | (empty) | Jellyfin Published Server URL for streams. Auto-set from `FLIXBOX_PUBLIC_HOST` when empty; set manually for Caddy HTTPS — [Troubleshooting — Jellyfin media source](10-troubleshooting.md). |
| `JELLYFIN_DOMAIN` | `jellyfin.local` | Custom domain/host for Caddy reverse proxy (profile `proxy`). |
| `SEERR_DOMAIN` | `requests.local` | Custom domain/host for Seerr in Caddy (profile `proxy`). |
| `HOMEPAGE_DOMAIN` | `home.local` | Custom domain/host for Homepage in Caddy (profile `proxy`). |
| `SEERR_LOG_LEVEL` | `info` | `error`, `warn`, `info`, `debug`. |
| `PLEX_CLAIM` | (empty) | One-time claim token from [plex.tv/claim](https://www.plex.tv/claim/) (profile `plex`). |

<a id="vpn-only-gluetun"></a>
<a id="vpn-mode-only"></a>
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
| `vpn` | `qbittorrent` | `8080` |

Same hostname in both modes ([ADR 0014](../adr/0014-stable-qbit-download-hostname.md) — Gluetun aliases `qbittorrent` in VPN mode). `DECLUTTARR_QBIT_URL` must use `http://qbittorrent:8080`.

## Secrets

- Store credentials only in `.env` or `${CONFIG_DIR}` volumes.
- Never commit `.env`, VPN keys, or API tokens to git.
- `.env.example` uses empty placeholders only.
- `init` creates `.env` with mode `600` (owner read/write only).

## Image tags

Compose modules pin explicit version tags ([ADR 0010](../adr/0010-mit-and-image-tags.md)). Inventory and bump procedure: [14 — Image pins](14-image-pins.md).

## Next

[VPN and Direct](07-vpn-and-direct.md) · [First-run setup](05-first-run.md) · [Hygiene](08-hygiene.md)
