# First-run setup

Do this **once** after `./bin/flixbox up`. Order matters.

## 1. Prowlarr + Byparr

Byparr bypasses Cloudflare on indexers that need it (for example 1337x). Configure the proxy **before** adding those indexers.

### 1a. Add the Byparr proxy (once)

1. Open Prowlarr (`:9696`).
2. **Settings** → **Indexers** → **Indexer Proxies** → **+**.
3. Type **FlareSolverr** (Prowlarr’s protocol name; the service in Flixbox is **Byparr**).
4. Set:
   - **Host:** `byparr` (not `localhost` — Prowlarr runs inside Docker)
   - **Port:** `8191`
   - **Use SSL:** off  
   Or use URL: `http://byparr:8191`
5. **Tags (recommended):** add a tag such as `cf` or `byparr` on the proxy entry.
6. **Test** — should succeed. If not: `./bin/flixbox logs byparr`.

### 1b. Add indexers

**Indexers without Cloudflare** — add normally (no proxy tag needed).

**Indexers with Cloudflare** (for example 1337x):

1. **Indexers** → **Add indexer**.
2. Configure the indexer as usual.
3. Under **Tags**, add the **same tag** you put on the Byparr proxy (for example `cf`).
4. **Test** — Prowlarr should reach the site via Byparr.

Successful Byparr logs look like:

```text
Challenge detected, waiting for it to clear...
Done https://... in 9.43s
POST /v1 HTTP/1.1" 200 OK
```

### 1c. Tags and app sync (important)

Prowlarr warns: *an indexer with a tag only syncs to apps with the same tag.*

If your Cloudflare indexers use tag `cf`:

1. **Settings** → **Apps** → open **Radarr** and **Sonarr**.
2. Add the same tag (`cf`) to each app **or** leave indexers untagged if you want them on all apps without tag rules.
3. **Test** each app connection, then confirm the indexer appears under each app’s indexer list.

### 1d. Sync to Radarr and Sonarr

Use **Sync App Indexers** (or Prowlarr’s automatic sync) so Radarr and Sonarr receive the **indexers** from Prowlarr.

Prowlarr does **not** sync download clients, root folders, or quality settings — only indexers. See [How it works — What Prowlarr syncs](02-how-it-works.md#what-prowlarr-syncs-and-what-it-does-not).

## 2. qBittorrent

### 2a. Open the WebUI

Use the **host** port from `.env` (`QBITTORRENT_PORT`, default `8080`). Example: if you set `9898`, open `http://localhost:9898`.

Inside Docker, Radarr/Sonarr still use host `qbittorrent` (or `gluetun` in VPN mode) and port **`8080`** — that internal port does not change when you remap the host port.

### 2b. Login (`Unauthorized`)

A bare `Unauthorized` response (curl or a blank page) usually means **not logged in yet**, not a wrong URL path. Open the URL in a normal browser tab; you should get the login form.

| Field | Value |
| --- | --- |
| Username | `admin` |
| Password | Temporary password from first container start |

```bash
docker compose logs qbittorrent 2>&1 | grep -iE 'password|temporary'
```

Change the password after login under **Options → Web UI**.

Use **`http://127.0.0.1:<QBITTORRENT_PORT>`** (not `:8080` on the host unless that is your mapped port). If port `8080` is already used by another app on the host, set `QBITTORRENT_PORT` in `.env` and use that port in the browser only.

### 2b.1 WebUI stuck on plain `Unauthorized` (qBittorrent 5.x)

#### Why this happens

Flixbox maps the WebUI as **`${QBITTORRENT_PORT}:8080`** (host port → container port). qBittorrent **always listens on 8080 inside the container**; only the published host port changes (for example `9898`).

When you open `http://localhost:9898`, the browser sends `Host: localhost:9898`. qBittorrent 5.x (linuxserver image) may reject that request before showing the login page:

| Setting | Default behavior | Problem behind Docker port remap |
| --- | --- | --- |
| `WebUI\HostHeaderValidation` | Validates the `Host` header against the internal WebUI port (`8080`) | Browser uses `:9898` → plain-text **`Unauthorized`**, no login form |
| `WebUI\LocalHostAuth` | Special handling for localhost auth | Can block normal login through the published port in some 5.x builds |

This is **not** a Flixbox bug and **not** fixed by Byparr or Gluetun. *arr apps are unaffected — they call `http://qbittorrent:8080` on the Docker network, not your host port.

#### Fix

Add to `${CONFIG_DIR}/qbittorrent/qBittorrent/qBittorrent.conf` while the stack is stopped (or let the init hook below apply it):

```ini
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
```

Then `./bin/flixbox up` and log in with `admin` plus the temporary password from `docker compose logs qbittorrent`. Access works with **`localhost:<QBITTORRENT_PORT>`** and **`127.0.0.1:<QBITTORRENT_PORT>`**.

#### Automation

`flixbox init` installs `99-flixbox-qbittorrent.sh` under `${CONFIG_DIR}/qbittorrent-cont-init/`, mounted into the container at **`/custom-cont-init.d`** (linuxserver’s supported path — **not** `/config/custom-cont-init.d`, which current images ignore). Re-run `./bin/flixbox init` then recreate qBit if your install predates this mount:

```bash
./bin/flixbox init --non-interactive
docker compose up -d --force-recreate qbittorrent
```

If you use **VPN port forwarding**, after login still enable **Bypass authentication for clients on localhost** under **Options → Web UI** (separate from the two keys above; Gluetun hooks call the API on `127.0.0.1:8080` inside the VPN netns).

### 2c. Download paths (automatic)

Flixbox sets qBittorrent paths **on container start** via `/custom-cont-init.d/99-flixbox-qbittorrent.sh` (no WebUI step required for defaults):

| Setting | Path |
| --- | --- |
| Default save | `/data/torrents/` |
| Incomplete | `/data/torrents/incomplete/` |

The hook runs **before** qBittorrent starts. It:

- Writes missing keys.
- Replaces **linuxserver legacy** paths (`/downloads/`, `/downloads/incomplete/`).
- **Leaves** other custom paths under `/data/` alone (if you deliberately use `/data/torrents/movies`, it is kept).
- With `FLIXBOX_QBIT_FORCE_PATHS=true` in `.env`, always resets to the table above (then `./bin/flixbox up`).

Verify under **Options → Downloads** after first start. Optional: tag `flixbox-keep` on torrents Decluttarr must not remove.

If you change `DATA_DIR`, host ports, or folder layout **after** first-run, see [Day-2 — Changing paths](09-operations.md#changing-paths-and-storage-layout).

### 2d. VPN port forwarding

If `FLIXBOX_MODE=vpn` and `VPN_PORT_FORWARDING=on`: enable **Bypass authentication for clients on localhost** in the qBit WebUI.

### 2e. Custom host ports and stale config

Flixbox publishes the WebUI as `${QBITTORRENT_PORT}:8080` (host → container). Only change **`QBITTORRENT_PORT`** in `.env`, then `./bin/flixbox up`. Do **not** remap `8420:8420` unless you also change `WEBUI_PORT` inside the container — the stock Compose keeps `WEBUI_PORT=8080` on purpose.

If the WebUI stays stuck on `Unauthorized` or refuses the new port **after** you changed ports or experimented with custom `WEBUI_PORT` / `TORRENTING_PORT`, the linuxserver config volume may still hold old values from a previous run. Restarting the container is not enough.

**Reset qBittorrent config (loses qBit settings, not torrents on disk):**

```bash
./bin/flixbox down
# default CONFIG_DIR; adjust if yours differs
rm -rf "${CONFIG_DIR:-/srv/flixbox/config}/qbittorrent/qBittorrent"
./bin/flixbox up
docker compose logs qbittorrent   # new temporary password
```

Also update `${CONFIG_DIR}/homepage/services.yaml` so the qBittorrent link uses your host port (Homepage is not updated automatically from `.env` yet).

## 3. Radarr / Sonarr

Configure **each app separately** (settings are not shared via Prowlarr).

### 3a. Root folders

| App | Root folder |
| --- | --- |
| Radarr | `/data/media/movies` |
| Sonarr | `/data/media/tv` |

### 3b. Download client (qBittorrent)

Add in **both** Radarr and Sonarr: **Settings → Download Clients → + → qBittorrent**

| Field | Direct mode | VPN mode |
| --- | --- | --- |
| Host | `qbittorrent` | `gluetun` |
| Port | `8080` | `8080` |
| URL Base | *(leave empty)* | *(leave empty)* |
| Username / Password | qBit WebUI creds if auth enabled | same |
| API Key | qBit → **Options → Web UI → API access** | same |

Use **Test** — must be green in Radarr **and** Sonarr. Host port `9898` (or any `QBITTORRENT_PORT`) is **only for your browser**; *arr always use internal port **8080**.

Optional: category `movies` (Radarr) / `tv` (Sonarr) if you use qBit categories.

### 3c. API keys for Decluttarr / Unpackerr

Copy **Radarr** and **Sonarr** API keys (Settings → General) into `.env` (`RADARR_API_KEY`, `SONARR_API_KEY`), then `./bin/flixbox up`.

## 4. Bazarr

Connect to Radarr/Sonarr; set subtitle language priorities.

## 5. Jellyfin

Wizard → libraries under `/data/media/movies` and `/data/media/tv`.

## 6. Seerr

Connect Jellyfin + Radarr + Sonarr; set household permissions.

## 7. Recyclarr

Edit `${CONFIG_DIR}/recyclarr/recyclarr.yml` API keys →  
`docker compose --profile recyclarr run --rm recyclarr sync`.

## 8. Decluttarr / Maintainerr

- Decluttarr uses env from `.env` (qBit URL set by `flixbox init` from mode).
- Maintainerr (`:6246`): connect **Jellyfin** + Radarr/Sonarr; apply rules from [Hygiene](08-hygiene.md) / [09-hygiene-defaults](../09-hygiene-defaults.md). Review before first delete.

## 9. Homepage / Caddy

Homepage (`:3000`) templates are copied by init. Enable Caddy with `./bin/flixbox up proxy` when ready.

## Next

[Configuration](06-configuration.md) · [VPN and Direct](07-vpn-and-direct.md)
