# Troubleshooting

| Symptom | Likely cause | What to try |
| --- | --- | --- |
| `cannot create DATA_DIR at /srv/flixbox/data — cannot write under /srv` | Linux default paths; regular user cannot create `/srv` without `sudo` | Create parent dirs + `chown` to your user, or set custom paths in `.env` (e.g. `/data/flixbox/data`) — [Install — Storage paths](04-install.md#storage-paths-and-permissions); re-run `./bin/flixbox init --non-interactive` |
| `Path validation failed` after `init`; `.env` exists | Writable paths not set before `--non-interactive` init | Edit `DATA_DIR` / `CONFIG_DIR` in `.env`, ensure parent is writable, re-run `init` (init incomplete — do not run `up` until init succeeds) |
| `mkdir: /srv: Read-only file system` on init | Linux template paths on macOS without `init` | Run `./bin/flixbox init --force --non-interactive` or set `DATA_DIR`/`CONFIG_DIR` under `$HOME/flixbox/` |
| `Directories missing` on `up` | `init` never completed bootstrap (validation failed or skipped) | Fix paths → `./bin/flixbox init --non-interactive` → verify `${DATA_DIR}/torrents/incomplete` exists |
| Imports are slow / disk doubles | Split mounts; hardlink failed (`EXDEV`) | One `${DATA_DIR}:/data` parent; check MergerFS/exFAT |
| Media missing after moving `DATA_DIR` | *arr / Jellyfin still ok but data not at expected host mount | Follow [Changing paths](09-operations.md#changing-paths-and-storage-layout); verify root folders and libraries use `/data/media/...` |
| qBit saves to wrong folder (`/downloads/`) | Hook not mounted at `/custom-cont-init.d` or not recreated | `./bin/flixbox init --non-interactive` then `docker compose up -d --force-recreate qbittorrent`; or `FLIXBOX_QBIT_FORCE_PATHS=true` — [First-run §2c](05-first-run.md#2c-download-paths-automatic) |
| Radarr/Sonarr qBit **Test** fails (auth) | Wrong credential type | Use qBit **API key** in *arr download client (not WebUI password). Leave username/password empty. Key from qBit → Options → Web UI → API access — [Credentials](06-configuration.md#credentials-and-api-keys) |
| Decluttarr cannot connect to qBit | Missing or wrong `.env` creds | Set `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` (WebUI login). Decluttarr does **not** use qBit API key. Then `./bin/flixbox up` |
| Decluttarr logs `idle — set QBITTORRENT_…` | Username/password not in `.env` yet (by design) | After qBit WebUI login, set both in `.env` → `docker compose up -d --force-recreate decluttarr` — [First-run §3c](05-first-run.md#3c-hygiene-credentials-decluttarr--unpackerr) |
| Decluttarr missing `/flixbox-entrypoint.sh` | Entrypoint not copied | `./bin/flixbox init --non-interactive` then recreate Decluttarr |
| Decluttarr `403` / “IP has been banned” | Fail-login loop before idle gate / old stack | `docker compose restart qbittorrent` (clears in-memory ban), confirm `.env` password, recreate Decluttarr; ensure cont-init whitelist + fixed `flixbox_net` subnet — [ADR 0008](../adr/0008-maintenance-decluttarr-maintainerr.md) |
| *arr banner: Connection refused to qBit, but **Test** is OK | Health check ran while qBit WebUI was still starting (or stale status) | System → Tasks → **Check Health**, or wait for the next cycle. With current Compose, *arr wait for qBit `healthy` on new boots |
| Services cannot join `flixbox_net` after upgrade | Old bridge without `172.30.42.0/24` | `docker compose down`, `docker network rm flixbox_net` if it still exists, then `./bin/flixbox up` |
| Radarr cannot reach qBit (VPN) | Missing Gluetun `qbittorrent` alias (pre–ADR 0014) or Gluetun unhealthy | Host **`qbittorrent`**; `compose up -d gluetun` after upgrade |
| qBit crash-loops at boot (VPN) | Started before Gluetun healthy | Healthcheck `depends_on`; restart qBit after Gluetun is healthy |
| VPN test shows home IP | Not in VPN mode / tunnel down | Check `VPN_ENABLED`, Gluetun logs, `vpn-test` |
| Homepage link goes to wrong port after `.env` change | `services.yaml` copied once at init with default ports | Edit `${CONFIG_DIR}/homepage/services.yaml` or regenerate from `.env` |
| qBit WebUI `Unauthorized` after login attempts | Not logged in yet | Browser → `http://localhost:<QBITTORRENT_PORT>`; user `admin`; temp password in `docker compose logs qbittorrent` |
| qBit WebUI plain `Unauthorized` (no login form) | qBittorrent 5.x rejects `Host: localhost:<mapped-port>` when internal WebUI is 8080 | Set `WebUI\HostHeaderValidation=false` and `WebUI\LocalHostAuth=false`; [First-run §2b.1 — why](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| qBit `Unauthorized` persists after port experiments | Stale `qBittorrent.conf` in config volume | Stop stack; remove `${CONFIG_DIR}/qbittorrent/qBittorrent/`; `./bin/flixbox up` (see [First-run §2e](05-first-run.md#2e-custom-host-ports-and-stale-config)) |
| Changed `WEBUI_PORT` + `8420:8420` style mapping | Internal/listen port mismatch | Prefer Flixbox default: `QBITTORRENT_PORT:8080` only; keep `WEBUI_PORT=8080` in Compose |
| Indexers fail Cloudflare (`blocked by CloudFlare Protection`) | Proxy missing, wrong host, or tags not linked | Create FlareSolverr proxy → host `byparr`, port `8191`; same **tag** on proxy and indexer; see [First-run §1](05-first-run.md#1-prowlarr--byparr) |
| Indexer test OK in Prowlarr but missing in Radarr/Sonarr | Tag on indexer but not on app | **Settings → Apps** → add the same tag to Radarr/Sonarr, or remove tags |
| Byparr logs show challenge then `200 OK` | Normal for CF indexers | No action; if search still fails, try another indexer or check `./bin/flixbox logs byparr` |
| Jellyfin dies on 4K transcode | Small `/dev/shm` | Mount host `/dev/shm` for transcode |
| *arr DB corrupt after reboot | Short stop timeout | `stop_grace_period: 60s`; local SSD for config |
| Config weirdness on NAS path | SQLite over NFS/SMB | Move `${CONFIG_DIR}` to local disk |
| Maintainerr deleted too much | Rules too aggressive | Tighten thresholds; use Keep list; review Leaving Soon first |
| Decluttarr removes wanted torrent | No protect tag | Add `flixbox-keep`; raise strikes |
| Permission denied on media | UID/GID mismatch | Align `PUID`/`PGID`; SGID on data dirs |
| `./bin/flixbox configure` fails on first run (API not ready) | *arr/Jellyfin still initializing SQLite | Wait 1–3 min after `up`, re-run `configure`. Script waits up to 180s per service — [First-run §0](05-first-run.md#0-script-assisted-wiring-recommended) |
| `configure` / *arr auth errors after wiping `${CONFIG_DIR}` | `.env` API keys stale vs new container `config.xml` | Re-run `./bin/flixbox configure` (syncs keys from container). Or `./bin/flixbox init --non-interactive` if keys were empty |
| `Invalid FLIXBOX_ACCESS_PROFILE=…` on `up` / `configure` | Typo in `.env` | Set `trusted` or `shared`; run `./bin/flixbox init --non-interactive` |
| Warn: Access profile out of sync (`FLIXBOX_ARR_AUTH_*`) | Changed profile without `init` | `./bin/flixbox init --non-interactive` then `docker compose up -d --force-recreate prowlarr radarr sonarr` — [§13](13-access-profiles.md) |
| `shared` profile: *arr login fails with `.env` password | Forms user never created in that app | Servarr does not read `FLIXBOX_ARR_UI_*` from env — create account manually in each *arr UI — [§13 — Create login](13-access-profiles.md#create-arr-login-shared) |
| `shared` profile: cannot open Radarr from phone on Wi‑Fi | Admin ports bind to `127.0.0.1` | Expected — use host browser or SSH tunnel; Jellyfin/Seerr stay on LAN — [§13](13-access-profiles.md) |
| `trusted` profile but *arr asks for login from LAN (IPv6) | Servarr RFC1918 bypass does not cover all IPv6 LAN clients | Use `shared`, or access *arr from IPv4 / localhost |
| Scripts fail with `\r` errors | CRLF line endings on Windows clone | Ensure LF via `.gitattributes` |

## Still stuck?

1. `./bin/flixbox status` and service logs  
2. Confirm mode (VPN vs Direct) and download-client host  
3. Re-read [How it works](02-how-it-works.md)  
4. Engineering depth: [operations risks](../07-operations-risks.md)

## Contributing / bugs

Use the GitHub issue tracker once the repository is public. Include Flixbox version/commit, OS, VPN or Direct, and redacted logs (no API keys).
