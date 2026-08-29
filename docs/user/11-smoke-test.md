# MVP smoke test checklist

Use this checklist **before tagging v0.1**. It validates that the implemented stack works on a real host, not only that Compose resolves in CI.

**Reference platform:** Linux x86_64 or ARM64 with Docker Engine + Compose v2. WSL2 (ext4 paths) and macOS Docker Desktop are best-effort — hardlink tests may be inconclusive on macOS.

## Quick automated preflight

From the repo root:

```bash
./scripts/ci-validate.sh          # contract checks (no containers)
./scripts/smoke-test.sh preflight   # docker + compose config
```

## Full automated smoke (Direct mode)

Uses `/tmp/flixbox-smoke` for data/config so you do not need `/srv/flixbox`:

```bash
./scripts/smoke-test.sh run
```

This runs `init`, `up`, HTTP probes, and prints manual steps still required.

To tear down:

```bash
./scripts/smoke-test.sh down
```

---

## Phase A — Bootstrap (automated + spot-check)

| # | Check | How | Pass |
|---|-------|-----|------|
| A1 | `init` completes | `./bin/flixbox init --non-interactive` | No errors; dirs + templates exist |
| A2 | Data tree | `ls ${DATA_DIR}/torrents/incomplete` | Directory exists |
| A3 | Templates copied | `ls ${CONFIG_DIR}/homepage/services.yaml` | File exists |
| A4 | Decluttarr URL (Direct) | `grep DECLUTTARR_QBIT_URL .env` | `http://qbittorrent:8080` |
| A5 | Decluttarr URL (VPN) | Re-init with `FLIXBOX_MODE=vpn` on a test `.env` | `http://gluetun:8080` |
| A6 | Unsafe path warnings | Set `DATA_DIR=/mnt/c/test` and run `init` | CLI warns (WSL NTFS) |

## Phase B — Stack up (Direct mode)

| # | Check | How | Pass |
|---|-------|-----|------|
| B1 | All core containers running | `./bin/flixbox status` | 12 services up (no gluetun) |
| B2 | qBittorrent WebUI | `http://localhost:8080` | Login page loads |
| B3 | Prowlarr | `:9696` | UI loads |
| B4 | Radarr / Sonarr | `:7878` / `:8989` | UI loads |
| B5 | Jellyfin | `:8096` | Setup or dashboard loads |
| B6 | Seerr | `:5055` | UI loads |
| B7 | Homepage | `:3000` | Dashboard loads |
| B8 | Maintainerr | `:6246` | UI loads |
| B9 | Byparr | `:8191` | Health/status responds |

Expected Direct services: `bazarr`, `byparr`, `decluttarr`, `homepage`, `jellyfin`, `maintainerr`, `prowlarr`, `qbittorrent`, `radarr`, `seerr`, `sonarr`, `unpackerr`.

## Phase C — Storage contract (manual)

| # | Check | How | Pass |
|---|-------|-----|------|
| C1 | qBit paths | qBittorrent → Downloads | `/data/torrents`, incomplete `/data/torrents/incomplete` |
| C2 | *arr root folders | Radarr/Sonarr settings | `/data/media/movies`, `/data/media/tv` |
| C3 | Hardlink test | Import one release; compare inodes | Same inode in `torrents/` and `media/` |
| C4 | Jellyfin libraries | Libraries point at `/data/media/...` | Media visible after import |

Hardlink inode check:

```bash
ls -i "${DATA_DIR}/torrents/movies/"*/*.mkv 2>/dev/null | head -1
ls -i "${DATA_DIR}/media/movies/"*/*.mkv 2>/dev/null | head -1
```

Same leading number ⇒ hardlink OK.

## Phase D — VPN mode (optional, needs provider creds)

| # | Check | How | Pass |
|---|-------|-----|------|
| D1 | Switch mode | `FLIXBOX_MODE=vpn` in `.env`, fill Gluetun secrets, `./bin/flixbox up` | `gluetun` + `qbittorrent` healthy |
| D2 | qBit via Gluetun port | `http://localhost:8080` | WebUI loads |
| D3 | *arr download client | Radarr/Sonarr client host `gluetun:8080` | Test succeeds |
| D4 | Leak test | `./bin/flixbox vpn-test` | Container IP ≠ host public IP |
| D5 | Port forward (if provider supports) | `VPN_PORT_FORWARDING=on` + localhost bypass in qBit | Listen port updates in qBit logs |

## Phase E — Hygiene wiring (manual, after credentials)

Reference: [Credentials and API keys](06-configuration.md#credentials-and-api-keys) · [App-to-app connections](06-configuration.md#app-to-app-connections).

| # | Check | How | Pass |
|---|-------|-----|------|
| E1 | *arr API keys in `.env` | Radarr/Sonarr → Settings → General → `RADARR_API_KEY` / `SONARR_API_KEY` → `./bin/flixbox up` | Unpackerr/Decluttarr logs show no *arr auth errors |
| E1b | qBit creds for Decluttarr | If qBit auth on: `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` in `.env` (WebUI login, not API key) | Decluttarr logs connect to qBit |
| E2 | Decluttarr | Logs | Connects to Radarr, Sonarr, qBit |
| E3 | Maintainerr | UI → Jellyfin + Radarr + Sonarr (each **API key**) | Connection test OK |
| E3b | Seerr | UI → Jellyfin + Radarr + Sonarr (each **API key**) | Connection test OK |
| E4 | Maintainerr rules | Rules disabled or preview first | No surprise deletes |
| E5 | Recyclarr | `docker compose --profile recyclarr run --rm recyclarr sync` | Sync completes (after keys in recyclarr.yml) |

## Phase F — End-to-end request flow (manual)

| # | Check | How | Pass |
|---|-------|-----|------|
| F1 | Prowlarr indexers | Add test indexer, sync to *arr | Search works in Radarr/Sonarr |
| F2 | Seerr request | Request a movie/show | Appears in Radarr/Sonarr |
| F3 | Download + import | Grab releases to qBit | Import to `/data/media` |
| F4 | Jellyfin playback | Play imported file | Streams |

---

## Recording results

Copy this block into your release notes or a local log:

```
Date:
Host OS:
FLIXBOX_MODE:
DATA_DIR filesystem (df -T):

Phase A: [ ] pass  [ ] fail  notes:
Phase B: [ ] pass  [ ] fail  notes:
Phase C: [ ] pass  [ ] fail  [ ] skipped (macOS)
Phase D: [ ] pass  [ ] fail  [ ] skipped (no VPN)
Phase E: [ ] pass  [ ] fail  notes:
Phase F: [ ] pass  [ ] fail  notes:
```

When Phases A–C and at least B pass on Linux, update the verification checklist in [06-development-guide.md](../06-development-guide.md).

## Next

[First-run setup](05-first-run.md) · [Day-2 operations](09-operations.md) · [Troubleshooting](10-troubleshooting.md)
