# First-run setup

Do this **once** after `flixbox up`. Order matters.

> Screenshot placeholders below will become real PNGs under `docs/images/en/` (and `docs/images/es/` for the Spanish guide).

## Recommended order

### 1. Prowlarr — indexers + Byparr

1. Open Prowlarr.
2. Add your indexers.
3. Add an indexer proxy of type **FlareSolverr** pointing at Byparr (for example `http://byparr:8191`). The UI label says “FlareSolverr”; the Flixbox default service is **Byparr**.
4. Sync apps to Radarr and Sonarr when they exist.

> Screenshot: `docs/images/en/prowlarr-byparr-proxy.png`

### 2. qBittorrent — categories and paths

1. Open the WebUI (VPN mode: published via Gluetun).
2. Default save paths under `/data/torrents/...` (incomplete under `/data/torrents/incomplete`).
3. Optional: create tag `flixbox-keep` for torrents Decluttarr must never remove.
4. Enable **Bypass authentication for clients on localhost** if you use Gluetun port-forward hooks.

### 3. Radarr / Sonarr — root folders + download client

1. Root folders: `/data/media/movies` and `/data/media/tv`.
2. Download client:
   - VPN mode → host **`gluetun`**, port `8080`
   - Direct mode → host **`qbittorrent`**, port `8080`
3. Categories matching qBittorrent (for example `movies` / `tv`).
4. Enable hardlinks / use the standard media management options recommended by TRaSH where applicable.

> Screenshot: `docs/images/en/radarr-download-client-gluetun.png`

### 4. Bazarr

Connect to Radarr/Sonarr; set language priorities (Castellano / Latino / English are common defaults to document).

### 5. Jellyfin

1. Complete the wizard.
2. Add libraries pointing at `/data/media/movies` and `/data/media/tv`.
3. Create users you will link from Seerr / Maintainerr.

### 6. Seerr

1. Connect Jellyfin.
2. Connect Radarr and Sonarr (API keys from each app).
3. Set request permissions / approval rules for your household.

> Screenshot: `docs/images/en/seerr-jellyfin.png`

### 7. Recyclarr

Run profile sync when the CLI command exists (`flixbox sync-profiles`), or run the container/job documented in engineering docs. Start from TRaSH-oriented templates.

### 8. Decluttarr / Maintainerr

1. Point Decluttarr at Radarr, Sonarr, and the correct qBit URL for your mode.
2. Point Maintainerr at **Jellyfin** + Radarr/Sonarr.
3. Import / enable the [standard hygiene pack](08-hygiene.md). Review before the first delete cycle.

### 9. Homepage + Caddy

Add service widgets and (if used) TLS routes. Prefer not publishing raw admin UIs to the WAN.

## Next

[Configuration reference](06-configuration.md) · [VPN and Direct](07-vpn-and-direct.md)
