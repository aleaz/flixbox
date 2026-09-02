# ADR 0014: Stable download-client hostname (`qbittorrent`) across VPN and Direct

- **Status:** Accepted
- **Date:** 2026-08-30
- **Related:** [0002](0002-vpn-gluetun-dual-mode.md), [0008](0008-maintenance-decluttarr-maintainerr.md)

## Context

ADR 0002 documented mode-specific download-client URLs: `http://gluetun:8080` (VPN) vs `http://qbittorrent:8080` (Direct). Radarr/Sonarr store the hostname in their SQLite config — not in `.env`. Operators who switch `FLIXBOX_MODE` must manually re-edit each *arr download client or see `Name does not resolve (qbittorrent:8080)` in VPN mode.

`flixbox init` only rewrote `DECLUTTARR_QBIT_URL`; it did not fix *arr UI settings. This is poor UX and was reported during VPN testing.

## Decision

1. **Canonical download-client host for all stack peers:** `qbittorrent` on port `8080` (`http://qbittorrent:8080`) in **both** modes.
2. **VPN implementation:** add Docker network alias `qbittorrent` on the **Gluetun** service (`compose/downloaders-vpn.yml`). qBittorrent remains `network_mode: service:gluetun`; the alias points peers on `flixbox_net` at Gluetun’s published WebUI port.
3. **Direct implementation:** unchanged — the `qbittorrent` service name already resolves.
4. **`DECLUTTARR_QBIT_URL`:** always `http://qbittorrent:8080`; remove mode-switching logic from `flixbox init`.
5. **`gluetun` hostname** remains valid for debugging but is **not** the documented operator/*arr setting.
6. First-run and troubleshooting docs must state: configure *arr once with host `qbittorrent`; mode switches require `./bin/flixbox down` / `./bin/flixbox up` only (no *arr hostname edits).

## Consequences

- Operators who already set `gluetun` in Radarr/Sonarr may keep it (still works) or normalize to `qbittorrent` for consistency.
- After upgrading Compose, recreate Gluetun (`docker compose up -d`) so the network alias is applied.
- CI/docs/contracts reference a single hostname; smoke tests no longer expect `gluetun` in Decluttarr URL.
- ADR 0002 client-host guidance is superseded for *arr wiring by this ADR (0002 VPN netns decision unchanged).
