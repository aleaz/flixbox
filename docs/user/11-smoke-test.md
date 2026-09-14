# Smoke test checklist

Use this checklist **before tagging v0.1**. It validates that the implemented stack works on a real host, not only that Compose resolves in CI.

**Reference platform:** Linux x86_64 or ARM64 with Docker Engine + Compose v2. WSL2 (ext4 paths) and macOS (**OrbStack** or Docker Desktop) are best-effort — hardlink tests may be inconclusive on macOS.

## Quick automated preflight

From the repo root:

```bash
./scripts/ci-validate.sh          # contract checks (no containers)
./scripts/ci-smoke-init.sh        # C-50–52 + env-file unit (worktree; safe with stack up)
./scripts/smoke-test.sh preflight   # docker + compose config
```

**Idempotency (stack running):** after first `./bin/flixbox configure`, a second run should report **`0` updated** (all unchanged). If not, file an issue with both outputs.

**Day-2 readiness:** `./bin/flixbox doctor` (filesystem hardlink/NFS/exFAT guards + Docker/VPN). Prefer doctor before blaming Compose when imports or SQLite misbehave — [17 — CLI](17-cli.md) · [09 — Operations](09-operations.md#hardlink-health-check).

## Full automated smoke (Direct mode, `trusted`)

Uses `/tmp/flixbox-smoke` for data/config so you do not need `/srv/flixbox`:

```bash
./scripts/smoke-test.sh run
```

This runs `init`, `up`, HTTP probes, and prints manual steps still required.

If you already have a `.env` in the repo root, `run` **backs it up and restores it on exit** — only the smoke paths under `/tmp/flixbox-smoke` are used for data/config during the test.

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
| A4 | Decluttarr URL | `grep DECLUTTARR_QBIT_URL .env` | `http://qbittorrent:8080` (VPN and Direct) |
| A5 | Access profile defaults | `grep FLIXBOX_ACCESS_PROFILE .env` | `trusted`; `FLIXBOX_ADMIN_BIND_IP=0.0.0.0` |
| A6 | Unsafe path warnings | Set `DATA_DIR=/mnt/c/test` and run `init` | CLI warns (WSL NTFS) |

## Phase B — Stack up (Direct mode, `trusted`)

| # | Check | How | Pass |
|---|-------|-----|------|
| B1 | All core containers running | `./bin/flixbox status` | 12 services up (no gluetun) |
| B2 | qBittorrent WebUI | `http://localhost:8080` | Login page loads |
| B3 | Prowlarr | `:9696` | UI loads |
| B4 | Radarr / Sonarr | `:7878` / `:8989` | UI loads (no Forms login on LAN) |
| B5 | Jellyfin | `:8096` | Setup or dashboard loads |
| B6 | Seerr | `:5055` | UI loads |
| B7 | Homepage | `:3000` | Dashboard loads |
| B8 | Maintainerr | `:6246` | UI loads |
| B9 | Byparr | `:8191` | Health/status responds |
| B10 | `configure` | `./bin/flixbox configure` | Exit 0 after wait; re-run idempotent |

Expected Direct services: `bazarr`, `byparr`, `decluttarr`, `homepage`, `jellyfin`, `maintainerr`, `prowlarr`, `qbittorrent`, `radarr`, `seerr`, `sonarr`, `unpackerr`.

## Phase Bʹ — Access profile `shared` (manual)

Fresh paths recommended (or recreate *arr + admin-bound services after profile change).

```bash
# In .env:
FLIXBOX_ACCESS_PROFILE=shared
./bin/flixbox init --non-interactive
./bin/flixbox reload
./bin/flixbox configure
```

| # | Check | How | Pass |
|---|-------|-----|------|
| S1 | Derived env | `grep -E 'FLIXBOX_ARR_AUTH_|FLIXBOX_ADMIN_BIND' .env` | `Forms` + `Enabled` + `127.0.0.1` |
| S2 | Host bind | `ss -lntp \| grep -E '7878\|8989\|9696\|8191\|8080'` (or `docker port`) | Listen on `127.0.0.1`, not `0.0.0.0` |
| S3 | LAN blocked | From another LAN device, open `http://<host>:7878` | Connection refused / timeout |
| S4 | Host OK | On the server: `http://127.0.0.1:7878` | Forms / create-account UI |
| S5 | Forms users (`shared`) | `./bin/flixbox credentials set arr-ui --generate` (or `--sync-arr-ui`) | Login works with `credentials show arr-ui`; `configure` still OK via API keys |
| S6 | Consumers on LAN | Jellyfin `:8096`, Seerr `:5055`, Homepage `:3000` from LAN | Still reachable |
| S7 | Byparr | LAN `:8191` | Unreachable; Prowlarr indexer proxy still works |

See [Access profiles](13-access-profiles.md).

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

<a id="phase-d--vpn-mode-optional-needs-provider-creds"></a>
## Phase D — VPN mode (optional, needs provider creds)

| # | Check | How | Pass |
|---|-------|-----|------|
| D1 | Switch mode | `FLIXBOX_MODE=vpn` in `.env`, fill Gluetun secrets, `./bin/flixbox up` (no separate `down` required — `--remove-orphans`) | `gluetun` + `qbittorrent` healthy |
| D1b | Orphans cleared | From VPN, set `FLIXBOX_MODE=direct`, `./bin/flixbox up` | `gluetun` container gone; `qbittorrent` healthy on bridge |
| D2 | qBit via Gluetun port | `http://localhost:8080` (or `127.0.0.1` if `shared`) | WebUI loads |
| D3 | *arr download client | Radarr/Sonarr host `qbittorrent:8080` | Test succeeds |
| D4 | Leak test | `./bin/flixbox vpn-test` | Container IP ≠ host public IP |
| D5 | Port forward (if provider supports) | `VPN_PORT_FORWARDING=on` + localhost bypass in qBit | Listen port updates in qBit logs |

Privacy checklist and qBit settings: [Torrent privacy and security](12-torrent-privacy-and-security.md).

## Phase E — Hygiene wiring (manual, after credentials)

Reference: [Credentials and API keys](06-configuration.md#credentials-and-api-keys) · [App-to-app connections](06-configuration.md#app-to-app-connections).

| # | Check | How | Pass |
|---|-------|-----|------|
| E1 | *arr API keys in `.env` | Prefer `./bin/flixbox configure` (syncs keys) | Unpackerr/Decluttarr logs show no *arr auth errors |
| E1b | qBit creds for Decluttarr | `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` in `.env` (WebUI login, not API key) | Decluttarr logs connect to qBit (not `idle — set QBITTORRENT_…`) |
| E1c | Recreate after `.env` | `docker compose up -d --force-recreate decluttarr` | New env applied (restart alone is not enough) |
| E2 | Decluttarr | Logs | Connects to Radarr, Sonarr, qBit |
| E3 | Maintainerr | UI → Jellyfin + Radarr + Sonarr (each **API key**) | Connection test OK |
| E3b | Seerr | UI → Jellyfin + Radarr + Sonarr (each **API key**) | Connection test OK |
| E4 | Maintainerr rules | Rules disabled or preview first | No surprise deletes |
| E5 | Recyclarr | `docker compose --profile recyclarr run --rm recyclarr sync` | Sync completes (after keys in recyclarr.yml) |
| E6 | Apprise (optional) | `./bin/flixbox up notifications` then `docker compose --profile notifications ps apprise-api` | Running; no host port published; *arr can reach `http://apprise-api:8000` |

<a id="phase-f--end-to-end-request-flow-manual"></a>
## Phase F — End-to-end request flow (manual)

| # | Check | How | Pass |
|---|-------|-----|------|
| F1 | Prowlarr indexers | Add test indexer, sync to *arr | Search works in Radarr/Sonarr |
| F2 | Seerr request | Request a movie/show | Appears in Radarr/Sonarr |
| F3 | Download + import | Grab releases to qBit | Import to `/data/media` |
| F4 | Jellyfin playback | Play imported file | Streams |

## Phase G — Footgun remediations (ADR 0022)

| # | Check | How | Pass |
|---|-------|-----|------|
| G1 | Mode orphans | After D1b (or Direct↔VPN round-trip) | No leftover `flixbox-gluetun` when mode is `direct` |
| G2 | Homepage Docker API | Homepage UI → Docker / service status chips | Status resolves (via `docker-socket-proxy:2375`, not host sock) |
| G3 | Proxy healthy before Homepage | `docker inspect flixbox-docker-socket-proxy --format '{{.State.Health.Status}}'` after `up` | `healthy`; Homepage started after proxy |
| G4 | Seerr ownership gate | Temporarily `chmod 000` or root-own `${CONFIG_DIR}/seerr`, run `./bin/flixbox up` | Non-zero exit + UID 1000 troubleshooting hint; restore perms after |
| G5 | `docker.yaml` contract | `grep host: "${CONFIG_DIR}/homepage/docker.yaml"` | `host: docker-socket-proxy` (no `socket:` line) |

---

## Recording results

Copy this block into your release notes or a local log:

```
Date:
Host OS:
Commit / image pin set:
FLIXBOX_MODE:
FLIXBOX_ACCESS_PROFILE: trusted / shared
DATA_DIR filesystem (df -T):

Phase A:  [ ] pass  [ ] fail  notes:
Phase B:  [ ] pass  [ ] fail  notes:
Phase Bʹ: [ ] pass  [ ] fail  [ ] skipped (trusted-only RC)
Phase C:  [ ] pass  [ ] fail  [ ] skipped (macOS)
Phase D:  [ ] pass  [ ] fail  [ ] skipped (no VPN)
Phase E:  [ ] pass  [ ] fail  notes:
Phase F:  [ ] pass  [ ] fail  notes:
Phase G:  [ ] pass  [ ] fail  notes:  # ADR 0022 footguns
```

**v0.1 gate:** Phases A–C and B pass on Linux (`trusted`). Phase Bʹ (`shared`) recommended before advertising the shared Wi‑Fi setup in the README.

When Phases A–C and at least B pass on Linux, update the verification checklist in [06-development-guide.md](../06-development-guide.md).

## Next

[First-run setup](05-first-run.md) · [Access profiles](13-access-profiles.md) · [Image pins](14-image-pins.md) · [Day-2 operations](09-operations.md) · [Troubleshooting](10-troubleshooting.md)
