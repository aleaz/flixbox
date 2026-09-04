# Troubleshooting

| Symptom | Likely cause | What to try |
| --- | --- | --- |
| `Cannot connect to the Docker daemon` / `Docker daemon check failed` | Docker daemon stopped, user not in `docker` group, or invalid `DOCKER_HOST` | Start Docker (`sudo systemctl start docker`) and add user to group (`sudo usermod -aG docker $USER && newgrp docker`). See [Docker daemon access](#docker-daemon-access) |
| `Unable to set ownership ... Both native chown and Docker alpine helper failed` | Host user lacks `CAP_CHOWN` and Docker daemon cannot be reached | Run manual chown: `sudo chown -R ${PUID}:${PGID} "${DATA_DIR}" "${CONFIG_DIR}"`. If using Podman, see [Storage paths and permissions](#storage-paths-and-permissions) |
| `Host port preflight failed` on `up` / `reload` | Internal collision in `.env` (duplicate port on two services) or port already bound by another host process | Set unique ports in `.env` (e.g. `QBITTORRENT_PORT=9898`) → `./bin/flixbox reload` — [First-run — port conflicts](05-first-run.md#host-port-conflicts). Existing `flixbox-*` ports are ignored |
| `Gluetun container not running` during `configure` | Switched to VPN in `.env` but stack was never recreated | `./bin/flixbox down && ./bin/flixbox up`, wait for Gluetun healthy, then `configure` — [VPN switch](07-vpn-and-direct.md#choose-a-mode) |
| Gluetun: `TUN device is not available` / `open /dev/net/tun: no such device` | Host kernel modules mismatch (common after Manjaro upgrade without reboot), or TUN missing in LXC/VM | `uname -r` must match `/lib/modules/$(uname -r)`; reboot after `linux*` upgrade; `sudo modprobe tun`; then `./bin/flixbox down && ./bin/flixbox up`. LXC: enable TUN/nest on the CT. Upstream: [Gluetun TUN wiki](https://github.com/qdm12/gluetun-wiki/blob/main/errors/tun.md) |
| `cannot create DATA_DIR at /srv/flixbox/data — cannot write under /srv` | Linux default paths; regular user cannot create `/srv` without `sudo` | Create parent dirs + `chown` to your user, or set custom paths in `.env` (e.g. `/data/flixbox/data`) — [Install — Storage paths](04-install.md#storage-paths-and-permissions); re-run `./bin/flixbox init --non-interactive` |
| `Path validation failed` after `init`; `.env` exists | Writable paths not set before `--non-interactive` init | Edit `DATA_DIR` / `CONFIG_DIR` in `.env`, ensure parent is writable, re-run `init` (init incomplete — do not run `up` until init succeeds) |
| `mkdir: /srv: Read-only file system` on init | Linux template paths on macOS without `init` | Run `./bin/flixbox init --force --non-interactive` or set `DATA_DIR`/`CONFIG_DIR` under `$HOME/flixbox/` |
| `Directories missing` on `up` | `init` never completed bootstrap (validation failed or skipped) | Fix paths → `./bin/flixbox init --non-interactive` → verify `${DATA_DIR}/torrents/incomplete` exists |
| Imports are slow / disk doubles | Split mounts; hardlink failed (`EXDEV`) | One `${DATA_DIR}:/data` parent; check MergerFS/exFAT |
| Media missing after moving `DATA_DIR` | *arr / Jellyfin still ok but data not at expected host mount | Follow [Changing paths](09-operations.md#changing-paths-and-storage-layout); verify root folders and libraries use `/data/media/...` |
| qBit saves to wrong folder (`/downloads/`) | Hook not mounted at `/custom-cont-init.d` or not recreated | `./bin/flixbox init --non-interactive` then `docker compose up -d --force-recreate qbittorrent`; or `FLIXBOX_QBIT_FORCE_PATHS=true` — [First-run §2c](05-first-run.md#2c-download-paths-automatic) |
| Radarr/Sonarr qBit **Test** fails (auth) | Stale password after qBit recreate, or wrong credential type | `docker compose restart qbittorrent` (clears ban), then `./bin/flixbox configure --sync-qbit-auth`. Prefer qBit **API key** in *arr (username/password optional). — [Credentials](06-configuration.md#credentials-and-api-keys) |
| Decluttarr cannot connect to qBit | Missing or wrong `.env` creds | Set `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` (WebUI login). Decluttarr does **not** use qBit API key. Then `./bin/flixbox configure --sync-qbit-auth` |
| Decluttarr logs `idle — set QBITTORRENT_…` | Username/password not in `.env` yet (by design) | After qBit WebUI login, set both in `.env` → `./bin/flixbox configure --sync-qbit-auth` (or `docker compose up -d --force-recreate decluttarr`) — [First-run §3c](05-first-run.md#3c-hygiene-credentials-decluttarr--unpackerr) |
| Decluttarr missing `/flixbox-entrypoint.sh` | Entrypoint not copied | `./bin/flixbox init --non-interactive` then recreate Decluttarr |
| Decluttarr / *arr `403` / “IP has been banned” | Failed logins before Docker subnet whitelist, or stale *arr password after qBit recreate | `docker compose restart qbittorrent` (clears in-memory ban) → `./bin/flixbox configure --sync-qbit-auth` → confirm Decluttarr logs `OK \| qBittorrent`. Whitelist is `172.30.42.0/24` only — [ADR 0008](../adr/0008-maintenance-decluttarr-maintainerr.md) |
| Changed qBit password (or API key) in the WebUI only | `.env` / Decluttarr / *arr still have old values | Password: align `.env`, then `--sync-qbit-auth`. API key only: plain `configure` is usually enough — [Credentials](06-configuration.md#accidental--intentional-key-changes) |
| Seerr restart-loop / `unhealthy` on first start | Config dir not writable by UID **1000** (Seerr ignores `PUID`) | `./bin/flixbox init --non-interactive` (sets ownership via helper), or `docker run --rm -v "${CONFIG_DIR}/seerr:/data" alpine chown -R 1000:1000 /data` then recreate Seerr |
| Radarr/Sonarr: cannot add root folder `/data/media/...` | `DATA_DIR` not writable by `PUID` (common in CI / no-sudo hosts) | Re-run `./bin/flixbox init --non-interactive` (alpine chown helper), or `chown -R ${PUID}:${PGID} "${DATA_DIR}"` |
| Regenerated Radarr/Sonarr API key in that app’s UI | Prowlarr/Seerr/Decluttarr/Unpackerr may still use the old key | `./bin/flixbox configure`; then update Maintainerr + Recyclarr YAML if needed — [Credentials](06-configuration.md#accidental--intentional-key-changes) |
| *arr banner: Connection refused to qBit, but **Test** is OK | Health check ran while qBit WebUI was still starting (or stale status) | System → Tasks → **Check Health**, or wait for the next cycle. With current Compose, *arr wait for qBit `healthy` on new boots |
| Services cannot join `flixbox_net` after upgrade | Old bridge without `172.30.42.0/24` | `./bin/flixbox down`, `docker network rm flixbox_net` if it still exists, then `./bin/flixbox up` |
| Radarr cannot reach qBit (VPN) | Missing Gluetun `qbittorrent` alias (pre–ADR 0014) or Gluetun unhealthy | Host **`qbittorrent`**; `compose up -d gluetun` after upgrade |
| qBit crash-loops at boot (VPN) | Started before Gluetun healthy | Healthcheck `depends_on`; restart qBit after Gluetun is healthy |
| qBit WebUI dead after Gluetun recreate | qBit stranded in old netns (`network_mode: service:gluetun`) | `docker compose up -d qbittorrent` or `./bin/flixbox reload` — [VPN drops](07-vpn-and-direct.md#what-happens-when-the-vpn-drops) |
| VPN test shows home IP | Not in VPN mode / tunnel down | Check `VPN_ENABLED`, Gluetun logs, `vpn-test` |
| Homepage link goes to wrong port after `.env` change | Custom port not yet synced to `services.yaml` | Run `./bin/flixbox reload` to automatically sync ports from `.env` while preserving your custom widgets, or edit `${CONFIG_DIR}/homepage/services.yaml` |
| qBit WebUI `Unauthorized` after login attempts | Not logged in yet | Browser → `http://localhost:<QBITTORRENT_PORT>`; user `admin`; temp password in `docker compose logs qbittorrent` |
| qBit WebUI plain `Unauthorized` (no login form) | qBittorrent 5.x rejects `Host: localhost:<mapped-port>` when internal WebUI is 8080; Preferences may have been wiped on start | Runtime WebUI contract service re-applies HostHeader off ([ADR 0019](../adr/0019-qbit-webui-runtime-contract.md)). Re-run `./bin/flixbox init --non-interactive` + recreate qBit if the service is missing; then `configure --sync-qbit-auth` — [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| qBit / Decluttarr auth fails right after Direct↔VPN | Temp WebUI password or stale `.env` sync after recreate | Wait for qBit healthy → `./bin/flixbox configure --sync-qbit-auth`. If banned: `./bin/flixbox restart qbittorrent` then configure again — [VPN guide](07-vpn-and-direct.md) |
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
| `./bin/flixbox configure --dry-run` fails with containers not running | Same core-stack assert as live configure | Start stack: `./bin/flixbox up` — dry-run previews wiring but does not skip the running-stack requirement |
| `./bin/flixbox configure --dry-run` expected zero side effects | Entry/preflight/modules must respect `$DRY_RUN` | No `.env` writes, no recreate, no API mutations — only `[dry-run]` lines (ADR 0016) |
| `./bin/flixbox configure` fails on first run (API not ready) | *arr/Jellyfin still initializing SQLite | Waits up to **15 min** (`CONFIGURE_PREFLIGHT_TIMEOUT=900`); parallel checks per pass — typical 1–3 min — [First-run §0](05-first-run.md#0-script-assisted-wiring-recommended) |
| `configure` / *arr auth errors after wiping `${CONFIG_DIR}` | `.env` API keys stale vs new container `config.xml` | Re-run `./bin/flixbox configure` (syncs keys from container). Or `./bin/flixbox init --non-interactive` if keys were empty |
| `Invalid FLIXBOX_ACCESS_PROFILE=…` on `up` / `configure` | Typo in `.env` | Set `trusted` or `shared`; run `./bin/flixbox init --non-interactive` |
| Warn: Access profile out of sync (then auto-sync + recreate admin services) | Changed `FLIXBOX_ACCESS_PROFILE` or empty derived bind/auth keys | `up`/`reload`/`configure` sync derived keys and force-recreate admin-bound services — [§13](13-access-profiles.md) |
| `shared` profile: *arr login fails with `.env` password | Forms not applied or never created | `./bin/flixbox configure --sync-arr-ui` or `credentials set arr-ui`; fallback: create account in each *arr UI — [§13](13-access-profiles.md#create-arr-login-shared) |
| `shared` profile: cannot open Radarr from phone on Wi‑Fi | Admin ports bind to `127.0.0.1` | Expected — use host browser or SSH tunnel; Jellyfin/Seerr stay on LAN — [§13](13-access-profiles.md) |
| `trusted` profile but *arr asks for login from LAN (IPv6) | Servarr RFC1918 bypass does not cover all IPv6 LAN clients | Use `shared`, or access *arr from IPv4 / localhost |
| Scripts fail with `\r` errors | CRLF line endings on Windows clone | Ensure LF via `.gitattributes` |

## Docker daemon access

Flixbox requires access to the Docker daemon socket (`/var/run/docker.sock` or `DOCKER_HOST`) without `sudo`.

1. **Verify daemon status:**
   ```bash
   sudo systemctl status docker
   sudo systemctl enable --now docker
   ```
2. **Grant non-root access:**
   ```bash
   sudo usermod -aG docker "$USER"
   newgrp docker # or log out and log back in
   ```
3. **Verify access:**
   ```bash
   docker info
   ```
   If `docker info` succeeds without `sudo`, `./bin/flixbox` commands will proceed normally.

## Storage paths and permissions

When Flixbox initializes or copies configuration templates, it sets runtime ownership to `PUID:PGID` (with Seerr configuration set to UID `1000`). If host permissions prevent host-side writes, Flixbox uses a short-lived `alpine` container helper to reclaim and restore ownership.

If both native `chown` and the Alpine helper fail (e.g. Docker daemon is down or rootless permissions differ):

1. **Fix ownership manually with `sudo`:**
   ```bash
   # Replace with your actual paths from .env
   sudo chown -R 1000:1000 /srv/flixbox/data /srv/flixbox/config
   sudo chown -R 1000:1000 /srv/flixbox/config/seerr
   ```
2. **Podman rootless environments:**
   In rootless Podman without a system Docker daemon, use `podman unshare` to modify ownership within the user namespace:
   ```bash
   podman unshare chown -R 1000:1000 /srv/flixbox/data
   podman unshare chown -R 1000:1000 /srv/flixbox/config
   ```
3. **Shared group permissions alternative:**
   If you prefer not to change ownership repeatedly, set the SGID bit and group write permissions:
   ```bash
   sudo chmod -R 2775 /srv/flixbox/data /srv/flixbox/config
   ```

## Still stuck?

1. `./bin/flixbox status` and service logs  
2. Confirm mode (VPN vs Direct) and download-client host  
3. Re-read [How it works](02-how-it-works.md)  
4. Engineering depth: [operations risks](../07-operations-risks.md)

## Contributing / bugs

Use the GitHub issue tracker once the repository is public. Include Flixbox version/commit, OS, VPN or Direct, and redacted logs (no API keys).
