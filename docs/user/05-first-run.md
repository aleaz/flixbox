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

Use **Sync App Indexers** (or Prowlarr’s automatic sync) so Radarr and Sonarr receive the indexers from Prowlarr.

## 2. qBittorrent

1. Open WebUI (`:8080`).
2. Paths: `/data/torrents`, incomplete `/data/torrents/incomplete`.
3. Optional tag `flixbox-keep` for Decluttarr protection.
4. If VPN + port forwarding: enable **Bypass authentication for clients on localhost**.

## 3. Radarr / Sonarr

1. Root folders: `/data/media/movies`, `/data/media/tv`.
2. Download client:
   - Direct → host `qbittorrent`, port `8080`
   - VPN → host `gluetun`, port `8080`
3. Categories matching qBit.
4. Copy API keys into `.env` (`RADARR_API_KEY`, `SONARR_API_KEY`) and recreate Decluttarr/Unpackerr: `./bin/flixbox up`.

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
