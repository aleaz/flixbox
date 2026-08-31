# Install

> **Implementation status:** Full MVP Compose stack + `bin/flixbox` CLI are available. Optional profiles: `plex`, `proxy`, `socket-proxy`, `recyclarr`.

## Bootstrap

Flixbox reads paths from **`.env`** (not shell `export`). With `--non-interactive`, `init` does **not** pause for edits — set writable `DATA_DIR` / `CONFIG_DIR` **before** `init` completes, or edit `.env` and re-run `init` if validation failed.

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Edit .env: DATA_DIR, CONFIG_DIR, FLIXBOX_MODE, TZ, optional FLIXBOX_ACCESS_PROFILE
# (trusted default; shared on roommate Wi‑Fi — docs/user/13-access-profiles.md)
./bin/flixbox init --non-interactive   # creates dirs, templates, API keys/passwords; .env mode 600
./bin/flixbox up
./bin/flixbox status
./bin/flixbox configure   # idempotent wiring; then add Prowlarr indexers
```

Interactive alternative (pauses after creating `.env` so you can edit paths in another terminal):

```bash
./bin/flixbox init
# Press Enter only after DATA_DIR and CONFIG_DIR are writable paths in .env
```

Prefer `./bin/flixbox init` + `up` over a bare `docker compose up`. Raw Compose skips access-profile sync, secret generation, and path validation.
### Storage paths and permissions

On Linux, `init` defaults to **`/srv/flixbox/data`** and **`/srv/flixbox/config`** (FHS). Most desktop installs need you to **create the parent tree and own it** before `init`, or pick another path in `.env`.

**Requirements:**

- **Absolute paths** only (e.g. `/data/flixbox/data`, not `~/flixbox/data` in `.env`).
- **`DATA_DIR`:** one local filesystem for torrents + media (hardlinks). Not NFS/SMB/exFAT; not WSL `/mnt/c/...`.
- **`CONFIG_DIR`:** local SSD/NVMe (SQLite app databases).
- **`PUID` / `PGID`:** must match the user/group that owns both trees (default `1000` on Linux).

`init` validates that paths are writable (or creatable under a writable parent). If validation fails, **`.env` may exist but init did not finish** — fix paths in `.env`, then run `./bin/flixbox init --non-interactive` again (no need to delete `.env`).

**Option A — custom path (common on Manjaro/Ubuntu desktops):**

```bash
sudo mkdir -p /data/flixbox/data /data/flixbox/config
sudo chown -R "$(id -u):$(id -g)" /data/flixbox

cp .env.example .env
# Set in .env:
#   DATA_DIR=/data/flixbox/data
#   CONFIG_DIR=/data/flixbox/config
./bin/flixbox init --non-interactive
```

**Option B — FHS `/srv` (server or you already use `/srv`):**

```bash
sudo mkdir -p /srv/flixbox/data /srv/flixbox/config
sudo chown -R "$(id -u):$(id -g)" /srv/flixbox

cp .env.example .env
# Defaults already point at /srv/flixbox/…
./bin/flixbox init --non-interactive
```

**macOS:** `init` rewrites paths to `$HOME/flixbox/{data,config}` and sets `PUID`/`PGID` from your user — no `sudo` for paths.

After a successful init, `bootstrap-dirs.sh` creates `torrents/` and `media/` under `DATA_DIR` and applies SGID so group-writable files match `UMASK=002`.

See also: [Configuration — paths](06-configuration.md#required-before-first-up), [Troubleshooting](10-troubleshooting.md).

### Modes

| `FLIXBOX_MODE` | Download client for *arr / Decluttarr |
| --- | --- |
| `direct` or `vpn` | `http://qbittorrent:8080` (VPN: alias on Gluetun — ADR 0014) |

VPN: fill Gluetun secrets in `.env`, then `./scripts/vpn-test.sh` or `./bin/flixbox vpn-test`.

### qBittorrent paths and ports

- Default host WebUI: port `8080` (`QBITTORRENT_PORT` in `.env`)
- Inside Docker, WebUI stays on port **8080**; *arr always use host **`qbittorrent`** (ADR 0014).
- Custom host port example: `QBITTORRENT_PORT=9898` → browser `http://localhost:9898`, *arr still `8080`
- First-run password: from `.env` `QBITTORRENT_*` after init (or `docker compose logs qbittorrent` for temporary)
- VPN port-forward: enable **Bypass authentication for clients on localhost**
- HostHeader / remapped port issues: [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x)

### Optional profiles

```bash
./bin/flixbox up plex proxy
# COMPOSE_PROFILES=plex,proxy in .env also works
```

### Recyclarr sync

```bash
docker compose --profile recyclarr run --rm recyclarr sync
```

## Default ports

| Service | Port |
| --- | --- |
| Homepage | 3000 |
| Seerr | 5055 |
| Jellyfin | 8096 |
| qBittorrent | 8080 |
| Prowlarr | 9696 |
| Byparr | 8191 |
| Radarr | 7878 |
| Sonarr | 8989 |
| Bazarr | 6767 |
| Maintainerr | 6246 |
| Caddy | 80/443 (profile `proxy`) |

## Next

[First-run setup](05-first-run.md) — `./bin/flixbox configure`, then add indexers.  
[Quick reference](REFERENCE.md) — ports, URLs, CLI.
