# ADR 0019: qBittorrent WebUI runtime security contract

- **Status:** Accepted
- **Date:** 2026-09-02
- **Related:** [0002](0002-vpn-gluetun-dual-mode.md), [0008](0008-maintenance-decluttarr-maintainerr.md), [0014](0014-stable-qbit-download-hostname.md), [0016](0016-configure-state-machine.md)

## Context

cont-init writes `WebUI\HostHeaderValidation` and `AuthSubnetWhitelist` into `qBittorrent.conf`, but qBittorrent 5.x often rewrites Preferences from memory on start and discards those keys (same class of failure as VPN `InterfaceName` — ADR 0002). After Direct↔VPN recreate, operators saw:

- plain `Unauthorized` on remapped `QBITTORRENT_PORT`
- ephemeral temp WebUI password ≠ `QBITTORRENT_PASSWORD` in `.env`
- Decluttarr / *arr auth failures and IP bans

`configure` (ADR 0016) already heals this when run with auth, but relying on operator memory after every recreate is not resilient.

## Decision

1. **Runtime invariant:** a linuxserver `custom-services.d` loop (`98-flixbox-webui-contract.sh`) runs in **both** Direct and VPN modes and periodically asserts via the WebUI API:
   - `web_ui_host_header_validation_enabled=false`
   - `bypass_auth_subnet_whitelist_enabled=true` with `172.30.42.0/24` only (flixbox_net — ADR 0008)
   - soft `web_ui_max_auth_fail_count` / `web_ui_ban_duration` for first-run
   - when `QBITTORRENT_PASSWORD` is set: align live WebUI password to `.env` (bootstrap from session temp password when present)
2. **cont-init remains** best-effort for paths + initial Preferences; it is **not** the sole source of truth for WebUI security keys.
3. **Compose:** both downloader modules mount `${CONFIG_DIR}/qbittorrent-custom-services` and pass `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD`. VPN mode still installs `99-flixbox-bind-vpn-interface.sh`; Direct mode removes that script on `init`.
4. **Configure state machine (ADR 0016) unchanged:** reconciler complements PREFLIGHT (makes auth more likely to succeed). `--sync-qbit-auth` remains the intentional force-push into *arr + Decluttarr. CLI `up` / `reload` run a **host bootstrap** (`scripts/lib/qbit-webui-bootstrap.sh`) that reads the session temp password from `docker logs` (not available inside the container) and applies password + security prefs; tips still mention `--sync-qbit-auth` after mode switches.
5. **Security:** login via `/config/.flixbox/qbit-api-login.sh` stdin only; never widen AuthSubnetWhitelist beyond flixbox_net; no Direct fallback on VPN failure (ADR 0013).

## Consequences

- Pros: remapped-port WebUI and Docker-peer auth survive qBit recreate without manual curl; pattern matches tun0 bind.
- Cons: long-running s6 service inside qBit container; password bootstrap depends on temp password appearing in qBit logs under `/config` when env login fails.
- Operators still run `configure` for *arr wiring; reconciler does not replace ADR 0016.

## Validation

- `scripts/ci-validate.sh` C-84
- Manual / smoke: recreate qBit → host GET on `QBITTORRENT_PORT` 200; Decluttarr `OK | qBittorrent` without hand-edited prefs
