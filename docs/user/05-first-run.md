# First-run setup

Do this **once** after `./bin/flixbox up`. Order matters.

## 1. Prowlarr + Byparr

1. Open Prowlarr (`:9696`).
2. Add indexers.
3. Settings → Indexers → Add Indexer Proxy → type **FlareSolverr** → URL `http://byparr:8191` (protocol name stays FlareSolverr; service is Byparr).
4. Sync apps to Radarr and Sonarr.

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
