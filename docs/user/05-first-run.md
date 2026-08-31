# First-run setup

Do this **once** after `./bin/flixbox init` and `./bin/flixbox up`.

**Estimated time:** ~10–15 minutes with `./bin/flixbox configure` (mostly adding indexers); longer if you wire everything manually.

## Progress

- [ ] `./bin/flixbox init` (generates API keys + passwords into `.env`)
- [ ] `./bin/flixbox up` (VPN mode: wait until Gluetun is healthy)
- [ ] `./bin/flixbox configure` (or `--dry-run` first)
- [ ] **`shared` profile only:** create Forms login in Radarr, Sonarr, Prowlarr UI with `FLIXBOX_ARR_UI_*` from `.env` — [§13 — Create *arr login](13-access-profiles.md#create-arr-login-shared)
- [ ] Add indexers in Prowlarr (tag `cf` on Cloudflare indexers)
- [ ] Optional: Maintainerr rules, Recyclarr sync, Caddy

Cheat sheet: [Quick reference](REFERENCE.md).

---

## 0. Script-assisted wiring (recommended)

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
| qBittorrent | Categories `tv` / `movies`, prefs (TMM, UPnP off, encryption); VPN → bind `tun0`; WebUI password from `.env` |
| Sonarr / Radarr | Root folders, qBittorrent client, NFO metadata, Reject ISO custom format |
| Prowlarr | Byparr proxy (`http://byparr:8191`, tag `cf`), Radarr + Sonarr app sync |
| Bazarr | Sonarr + Radarr connections, ffsubsync |
| Jellyfin | Startup (if needed), libraries `/data/media/movies` + `/data/media/tv`, API key |
| Seerr | Jellyfin login + Radarr/Sonarr services + initialize |
| Secrets | Writes empty `.env` keys; patches Recyclarr placeholders; recreates Decluttarr/Unpackerr when keys change |

**Prerequisites:**

1. `./bin/flixbox init` (API keys + `QBITTORRENT_*` + `FLIXBOX_ADMIN_*` generated when empty).
2. Stack running (`./bin/flixbox status`). VPN mode: Gluetun **healthy**.
3. *arr auth follows **`FLIXBOX_ACCESS_PROFILE`** ([ADR 0015](../adr/0015-access-profiles.md)): default **`trusted`** (no *arr UI login on LAN); **`shared`** if roommates share Wi‑Fi. `configure` always uses API keys. With **`shared`**, you must **create Forms users manually** in each *arr UI after `configure` — see [13 — Create *arr login](13-access-profiles.md#create-arr-login-shared).

**Stays manual:** Prowlarr indexers; *arr Forms users (`shared`); Maintainerr rule enablement; optional Recyclarr sync.

---

## 1. Prowlarr + Byparr

If you ran `configure`, the Byparr proxy and Radarr/Sonarr apps should already exist. Verify under **Settings → Indexers → Indexer Proxies** and **Settings → Apps**.

### 1a. Add indexers

**Indexers without Cloudflare** — add normally.

**Indexers with Cloudflare** (for example 1337x):

1. **Indexers** → **Add indexer**.
2. Under **Tags**, add **`cf`** (same tag as the Byparr proxy).
3. **Test**.

### 1b. Tags and app sync

Prowlarr warns: *an indexer with a tag only syncs to apps with the same tag.* Keep `cf` on Radarr/Sonarr apps (configure sets this) or leave indexers untagged for all apps.

Sync indexers with **Sync App Indexers**. Prowlarr does **not** sync download clients or root folders.

Manual Byparr fallback (if configure skipped it): proxy type **FlareSolverr**, host `http://byparr:8191`, tag `cf`.

---

## 2. qBittorrent

WebUI: `http://127.0.0.1:${QBITTORRENT_PORT}` (default `8080`).

Login: `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` from `.env` (set by init; configure applies the password if qBit still has a temporary one).

Paths are set by cont-init (`/data/torrents/`, incomplete under `torrents/incomplete`). VPN mode: a custom service re-binds BitTorrent to `tun0` so torrents do not stall at metaDL (ADR 0002).

If the WebUI shows plain `Unauthorized` with a remapped host port, see [§2b.1](#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) below.

### 2b.1 WebUI stuck on plain `Unauthorized` (qBittorrent 5.x)

Flixbox maps `${QBITTORRENT_PORT}:8080`. qBit 5.x may reject `Host: localhost:<mapped-port>` when `HostHeaderValidation` expects `:8080`.

`flixbox init` installs cont-init that sets:

```ini
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=false
```

Re-run init and recreate qBit if your install predates that mount:

```bash
./bin/flixbox init --non-interactive
docker compose up -d --force-recreate qbittorrent
```

### 2d. VPN port forwarding

If `VPN_PORT_FORWARDING=on`: enable **Bypass authentication for clients on localhost** in the qBit WebUI (Gluetun hooks call `127.0.0.1:8080`).

---

## 3. Radarr / Sonarr / hygiene

`configure` adds root folders and the qBittorrent download client (`host: qbittorrent`, port `8080`). On later runs it **re-tests** that client and updates username/password/API key from `.env` if Test fails (common after recreating qBit). Use **Test** in each app to confirm.

Decluttarr/Unpackerr pick up `RADARR_API_KEY` / `SONARR_API_KEY` / `QBITTORRENT_*` from `.env`. Configure recreates them when it writes those keys; otherwise `./bin/flixbox reload`.

---

## 4. Bazarr / Jellyfin / Seerr

Configure connects Bazarr to Sonarr/Radarr, completes Jellyfin libraries when `FLIXBOX_ADMIN_*` is set, and wires Seerr.

If Jellyfin or Seerr automation fails (version quirks), finish the UI wizard once and re-run `./bin/flixbox configure` — remaining steps should **skip**.

| Jellyfin libraries | Path |
| --- | --- |
| Movies | `/data/media/movies` |
| TV | `/data/media/tv` |

---

## 5. Recyclarr / Maintainerr / Homepage

- Recyclarr: placeholders patched by configure →  
  `docker compose --profile recyclarr run --rm recyclarr sync`
- Maintainerr (`:6246`): connect Jellyfin + *arr; enable rules from [Hygiene](08-hygiene.md) deliberately.
- Homepage templates are copied by init; API widgets improve as keys land in `.env`.

## Next

[Configuration](06-configuration.md) · [VPN and Direct](07-vpn-and-direct.md)
