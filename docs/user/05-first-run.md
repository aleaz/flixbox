# First-run setup

Do this **once** after `./bin/flixbox up`.

**Estimated time:** ~30–45 minutes with `./bin/flixbox configure`; ~60 minutes if you wire everything manually.

## Progress

- [ ] Log into qBittorrent, Radarr, Sonarr, Prowlarr, Bazarr (each first-run wizard)
- [ ] Run `./bin/flixbox configure` (or `--dry-run` first)
- [ ] Add indexers in Prowlarr
- [ ] Jellyfin libraries + API key
- [ ] Seerr → Jellyfin / Radarr / Sonarr
- [ ] Decluttarr credentials in `.env` → `./bin/flixbox reload`
- [ ] Optional: Recyclarr, Maintainerr, Caddy

Cheat sheet: [Quick reference](REFERENCE.md).

---

## 0. Script-assisted wiring (recommended)

After each app has completed its first-run wizard (admin account / qBit password changed):

```bash
./bin/flixbox configure
```

Preview without changes:

```bash
./bin/flixbox configure --dry-run
```

**What the script configures (idempotent — safe to re-run):**

| Service | Settings |
| --- | --- |
| qBittorrent | Categories `tv` / `movies`, basic preferences |
| Sonarr | Root folder `/data/media/tv`, qBittorrent download client |
| Radarr | Root folder `/data/media/movies`, qBittorrent download client |
| Prowlarr | Byparr proxy (`http://byparr:8191`, tag `cf`), Radarr + Sonarr app sync |
| Bazarr | Sonarr + Radarr connections |

**Also:** writes `RADARR_API_KEY` and `SONARR_API_KEY` to `.env` when those fields are empty.

**Prerequisites:**

1. Stack running and healthy (`./bin/flixbox status`).
2. VPN mode: Gluetun must be **healthy** before configure runs.
3. qBittorrent: log in via WebUI and change the temporary password.
4. Radarr, Sonarr, Prowlarr, Bazarr: complete each app's setup wizard once.

**Stays manual** (sections below): indexers, Jellyfin, Seerr, Decluttarr `.env` password, Maintainerr, Recyclarr.

If configure fails for qBit download clients, ensure qBit has an **API key** (Options → Web UI → API access) and re-run.

---

## 1. Prowlarr + Byparr

If you ran `./bin/flixbox configure`, the Byparr proxy and Radarr/Sonarr app entries should already exist. Verify under **Settings → Indexers → Indexer Proxies** and **Settings → Apps**.

Byparr bypasses Cloudflare on indexers that need it (for example 1337x). Configure the proxy **before** adding those indexers.

### 1a. Add the Byparr proxy (manual fallback)

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

When you add Radarr/Sonarr under **Settings → Apps**, Prowlarr asks for each app’s **API key** (Radarr/Sonarr → Settings → General). That is the same key you later copy to `.env` for Unpackerr/Decluttarr — [App-to-app connections](06-configuration.md#app-to-app-connections).

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

If you ran `./bin/flixbox configure`, root folders and the qBittorrent download client should already exist. Use **Test** in each app to confirm.

Configure **each app separately** (settings are not shared via Prowlarr).

### 3a. Root folders (manual fallback)

| App | Root folder |
| --- | --- |
| Radarr | `/data/media/movies` |
| Sonarr | `/data/media/tv` |

### 3b. Download client (qBittorrent) — manual fallback

Add in **both** Radarr and Sonarr: **Settings → Download Clients → + → qBittorrent**

| Field | Direct mode | VPN mode |
| --- | --- | --- |
| Host | `qbittorrent` | `gluetun` |
| Port | `8080` | `8080` |
| URL Base | *(leave empty)* | *(leave empty)* |
| **API Key** | qBit → **Options → Web UI → API access** | same |
| Username / Password | *(leave empty)* when API key works | same |

**Use the qBit API key**, not your WebUI login. Radarr and Sonarr authenticate to qBittorrent with this key; Decluttarr is different — it uses username/password in `.env` ([Configuration — Credentials](06-configuration.md#credentials-and-api-keys)).

Use **Test** — must be green in Radarr **and** Sonarr. Host port `9898` (or any `QBITTORRENT_PORT`) is **only for your browser**; *arr always use internal port **8080**.

Optional: category `movies` (Radarr) / `tv` (Sonarr) if you use qBit categories.

### 3c. Hygiene credentials (Decluttarr / Unpackerr)

**Order matters** — Decluttarr stays **idle** until both qBit WebUI username and password are in `.env` (avoids fail-login loops that ban its Docker IP). Ensure `flixbox init` has copied `${CONFIG_DIR}/decluttarr-entrypoint.sh`.

1. Finish qBit login and set a stable WebUI password ([§2](#2-qbittorrent)).
2. Copy **Radarr** and **Sonarr** API keys (each app → Settings → General) into `.env`:

```env
RADARR_API_KEY=...
SONARR_API_KEY=...
QBITTORRENT_USERNAME=admin
QBITTORRENT_PASSWORD=your_qbit_password
```

3. Recreate hygiene containers:

```bash
./bin/flixbox reload
# or: docker compose up -d --force-recreate decluttarr unpackerr
```

4. Confirm Decluttarr: `docker compose logs decluttarr` — should connect (not the `idle — set QBITTORRENT_…` line).

Decluttarr needs WebUI username/password; it does **not** accept qBit’s API key. Unpackerr only needs the Radarr/Sonarr keys.

Full reference: [Configuration — Credentials](06-configuration.md#credentials-and-api-keys).

## 4. Bazarr

If configure ran successfully, Bazarr should already list Sonarr and Radarr. Otherwise connect manually using each app’s **API key** (Settings → General in Radarr/Sonarr). Set subtitle language priorities in the Bazarr UI.

## 5. Jellyfin

Complete the first-run wizard (admin account). Add libraries under `/data/media/movies` and `/data/media/tv`.

Create a **Jellyfin API key** (Dashboard → **API Keys**) for Seerr and Maintainerr — [App-to-app connections](06-configuration.md#app-to-app-connections).

## 6. Seerr

Connect **Jellyfin**, **Radarr**, and **Sonarr** using each service’s **API key** (not your Jellyfin password). Set household permissions and approval rules.

| Service | API key source |
| --- | --- |
| Jellyfin | Jellyfin → Dashboard → API Keys |
| Radarr | Radarr → Settings → General |
| Sonarr | Sonarr → Settings → General |

## 7. Recyclarr

Edit `${CONFIG_DIR}/recyclarr/recyclarr.yml` with the same Radarr/Sonarr **API keys** (Settings → General) →  
`docker compose --profile recyclarr run --rm recyclarr sync`.

## 8. Decluttarr / Maintainerr

- Decluttarr: after [§3c](#3c-hygiene-credentials-decluttarr--unpackerr), logs should show a normal start (not idle). Reads Radarr/Sonarr API keys, qBit username/password, and mode-aware qBit URL — [Credentials](06-configuration.md#credentials-and-api-keys).
- Maintainerr (`:6246`): connect **Jellyfin**, **Radarr**, and **Sonarr** with each service’s **API key** (same sources as Seerr); apply rules from [Hygiene](08-hygiene.md) / [09-hygiene-defaults](../09-hygiene-defaults.md). Review before first delete.

## 9. Homepage / Caddy

Homepage (`:3000`) templates are copied by init. Enable Caddy with `./bin/flixbox up proxy` when ready.

## Next

[Configuration](06-configuration.md) · [VPN and Direct](07-vpn-and-direct.md)
