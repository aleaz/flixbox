# ADR 0016: Configure readiness state machine

- **Status:** Accepted
- **Date:** 2026-09-01
- **Updated:** 2026-09-09 — Cap preflight waits to global deadline; clear soft-wait after PREFLIGHT_PASSED; Bazarr post-restart warn-only

## Context

`./bin/flixbox configure` wires core services after first container start (ADR 0005). First-run races (SQLite init, temp qBit passwords, Gluetun health) and duplicate waits between preflight and wiring modules caused flaky exits and confusing operator UX.

Access profile drift (ADR 0015) must sync before wiring whether the operator uses `bin/flixbox configure` or `./scripts/configure-apps.sh` directly.

## Decision

### State machine

```
INIT → ASSERT → PREFLIGHT_RETRY* → PREFLIGHT_PASSED → WIRING → DONE | PARTIAL
```

| Phase | Responsibility | Module |
| --- | --- | --- |
| **Entry** | Access profile validate/sync/recreate | `scripts/lib/configure-entry.sh` |
| **ASSERT** | tools, core stack (+ Jellyfin), `.env` writable | `scripts/lib/configure-state.sh` |
| **PREFLIGHT_RETRY** | HTTP warm-up, key discover, auth API verify; soft retry until budget | `scripts/configure/preflight.sh` |
| **PREFLIGHT_PASSED** | `CONFIGURE_PREFLIGHT_PASSED=true` — wiring skips duplicate waits | `configure-state.sh` |
| **WIRING** | Per-service idempotent API modules | `scripts/configure/*.sh` |
| **PARTIAL** | `FAILED>0` → exit 1 with summary | `configure-apps.sh` |

### Flags and timeouts

| Variable | Default | Purpose |
| --- | --- | --- |
| `CONFIGURE_PREFLIGHT_TIMEOUT` | `900` | Total preflight retry budget (seconds) |
| `WAIT_TIMEOUT` | `180` | Per-phase wait window within one pass (qBit, HTTP warm-up, auth APIs) |
| `CONFIGURE_PREFLIGHT_DEADLINE` | set for preflight only | Caps each wait to remaining budget (prevents soft passes overshooting) |
| `CONFIGURE_SOFT_WAIT` | `1` during retry, `0` on final pass / after `PREFLIGHT_PASSED` | Soft vs hard wait failures |
| `CONFIGURE_PREFLIGHT_PASSED` | bash dynamic scope | Skip wiring waits after preflight; clears soft-wait |

Within a pass, HTTP warm-up and authenticated API checks each run **in parallel** (≈ one `WAIT_TIMEOUT` per phase, not N×services). Phases are **sequential** (qBit → HTTP → key discover → auth APIs), so a soft pass can consume multiple windows — but every wait is capped by `CONFIGURE_PREFLIGHT_DEADLINE`, so wall clock stays within `CONFIGURE_PREFLIGHT_TIMEOUT` (+ small sleep/overhead). Typical cold start: 1–3 minutes; worst case approaches the full budget.

### `--dry-run`

Must not mutate runtime state:

- No `.env` writes, no container recreate (entry, discover, wiring modules).
- Entry and preflight emit `[dry-run]` previews only.
- Core stack assert still runs (D4 CI gate: fails cleanly without stack).

### JSON queries

Configure modules use `scripts/lib/json-query.py` with parameters in `JSON_QUERY_PARAMS` (never shell-interpolated Python). `json_extract` is deprecated — configure modules must use named `json_query` handlers only (CI C-79).

### Wiring context

`scripts/lib/configure-context.sh` documents and resets counters/flags at configure start. API keys and qBit context are populated during preflight and qBit wiring (bash dynamic scope).

### Failure model

- **Preflight fatal:** missing tools/stack, `.env` not writable, global timeout, VPN hard-fail → `exit 1` (or `return 1` from retry loop).
- **Wiring best-effort (PARTIAL):** `fail()` increments `FAILED` and **returns 0** so `set -euo pipefail` does not abort mid-run; `configure-apps.sh` exits 1 only when `FAILED>0` after the full wiring pass and summary.
- **Wait helpers:** after `fail()` on hard timeout they still `return 1` to signal preflight retry / module early-exit (e.g. skip rest of one service when API never came up).
- **Bazarr post-restart:** re-wait uses soft semantics (`CONFIGURE_SOFT_WAIT=1`) so a slow restart warns without inflating `FAILED`.
- **Optional services:** Seerr container absent → skip; Byparr down → skip CF proxy.

### qBit download client auth

`*arr` download client may use qBit **API key** (preferred) or **WebUI password** when the API key is not yet in `qBittorrent.conf`. `configure_qbittorrent` runs before *arr wiring and refreshes `QBIT_API_KEY` after password setup (conf file, then WebUI preferences JSON when authenticated).

WebUI Host-header / Docker subnet whitelist are also a **runtime invariant** enforced by a qBit custom-service ([ADR 0019](0019-qbit-webui-runtime-contract.md)); configure still applies the same prefs during WIRING when needed and `--sync-qbit-auth` remains the intentional `.env` force-push into *arr + Decluttarr.

### Service Ports: Host Probe vs. Internal Network

Host probe functions in `configure` (`wait_for_arr_api`, `configure_ensure_http`) dynamically use `SONARR_PORT` / `RADARR_PORT` / `QBITTORRENT_PORT` from `.env` to connect to `127.0.0.1:${PORT}` on the host. In contrast, inter-service URLs in Docker network `flixbox_net` (e.g. Seerr/Prowlarr/Bazarr connecting to `radarr` and `sonarr`) strictly use the canonical container listening ports (`7878` for Radarr, `8989` for Sonarr, `8080` for qBittorrent) matching the internal hostname contract in [REFERENCE](../user/REFERENCE.md).

## Consequences

- **Pros:** One `configure` run on clean install; explicit contracts (CI C-67–C-69); no duplicate long waits after preflight.
- **Cons:** Global bash mutable state; parallel waits spawn subshells (acceptable for homelab scale).
- **Docs:** Operator timeouts in [05-first-run](../user/05-first-run.md); troubleshooting in [10-troubleshooting](../user/10-troubleshooting.md).

## References

- [ADR 0005](0005-cli-bash-first.md) — API-assisted first-run
- [ADR 0015](0015-access-profiles.md) — access profile entry sync
- `scripts/lib/configure-state.sh`, `scripts/lib/configure-entry.sh`, `scripts/configure/preflight.sh`
