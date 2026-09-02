# ADR 0016: Configure readiness state machine

- **Status:** Accepted
- **Date:** 2026-09-01

## Context

`./bin/flixbox configure` wires MVP services after first container start (ADR 0005). First-run races (SQLite init, temp qBit passwords, Gluetun health) and duplicate waits between preflight and wiring modules caused flaky exits and confusing operator UX.

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
| `WAIT_TIMEOUT` | `180` | Per-service wait window within one pass |
| `CONFIGURE_SOFT_WAIT` | `1` during retry, `0` on final pass | Soft vs hard wait failures |
| `CONFIGURE_PREFLIGHT_PASSED` | bash dynamic scope | Skip wiring waits after preflight |

HTTP warm-up and authenticated API checks run **in parallel** within a preflight pass (worst case ≈ one `WAIT_TIMEOUT` window, not N×sequential).

### `--dry-run`

Must not mutate runtime state:

- No `.env` writes, no container recreate (entry, discover, wiring modules).
- Entry and preflight emit `[dry-run]` previews only.
- Core stack assert still runs (D4 CI gate: fails cleanly without stack).

### Failure model

- **Preflight fatal:** missing tools/stack, `.env` not writable, global timeout, VPN hard-fail → `exit 1`.
- **Wiring best-effort:** `fail()` increments `FAILED` and returns non-zero; script exits 1 if `FAILED>0` at end.
- **Optional services:** Seerr container absent → skip; Byparr down → skip CF proxy.

### qBit download client auth

`*arr` download client may use qBit **API key** (preferred) or **WebUI password** when the API key is not yet in `qBittorrent.conf`. `configure_qbittorrent` runs before *arr wiring and refreshes `QBIT_API_KEY` after password setup.

## Consequences

- **Pros:** One `configure` run on clean install; explicit contracts (CI C-67–C-69); no duplicate long waits after preflight.
- **Cons:** Global bash mutable state; parallel waits spawn subshells (acceptable for homelab scale).
- **Docs:** Operator timeouts in [05-first-run](../user/05-first-run.md); troubleshooting in [10-troubleshooting](../user/10-troubleshooting.md).

## References

- [ADR 0005](0005-cli-bash-first.md) — API-assisted first-run
- [ADR 0015](0015-access-profiles.md) — access profile entry sync
- `scripts/lib/configure-state.sh`, `scripts/lib/configure-entry.sh`, `scripts/configure/preflight.sh`
