# ADR 0019: qBittorrent WebUI runtime security contract

- **Status:** Accepted
- **Date:** 2026-09-02
- **Updated:** 2026-09-02 — shared prefs JSON; no on-disk temp password; Decluttarr refresh after bootstrap
- **Related:** [0002](0002-vpn-gluetun-dual-mode.md), [0008](0008-maintenance-decluttarr-maintainerr.md), [0014](0014-stable-qbit-download-hostname.md), [0016](0016-configure-state-machine.md)

## Context

cont-init writes `WebUI\HostHeaderValidation` and `AuthSubnetWhitelist` into `qBittorrent.conf`, but qBittorrent 5.x often rewrites Preferences from memory on start and discards those keys (same class of failure as VPN `InterfaceName` — ADR 0002). After Direct↔VPN recreate, operators saw:

- plain `Unauthorized` on remapped `QBITTORRENT_PORT`
- ephemeral temp WebUI password ≠ `QBITTORRENT_PASSWORD` in `.env`
- Decluttarr / *arr auth failures and IP bans

`configure` (ADR 0016) already heals this when run with auth, but relying on operator memory after every recreate is not resilient.

## Decision

1. **Runtime invariant:** a linuxserver `custom-services.d` loop (`98-flixbox-webui-contract.sh`) runs in **both** Direct and VPN modes and periodically asserts via the WebUI API using prefs from `/config/.flixbox/webui-security-prefs*.json`.
2. **Single source of prefs:** `templates/qbittorrent/webui-security-prefs.json` and `webui-security-prefs-portforward.json` are consumed by configure, host bootstrap, and the in-container reconciler (copied on `init` / `copy_templates`).
3. **cont-init remains** best-effort for paths + initial Preferences; it is **not** the sole source of truth for WebUI security keys.
4. **Compose:** both downloader modules mount `${CONFIG_DIR}/qbittorrent-custom-services` and pass `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD`. VPN mode still installs `99-flixbox-bind-vpn-interface.sh`; Direct mode removes that script on template refresh.
5. **Configure state machine (ADR 0016) unchanged:** reconciler complements PREFLIGHT. `--sync-qbit-auth` remains the intentional force-push into *arr + Decluttarr. CLI `up` / `reload` run host bootstrap (`scripts/lib/qbit-webui-bootstrap.sh`) that reads the session temp password from **`docker logs` only** (never written to disk), applies password + security prefs, then **recreates Decluttarr** so it does not keep a failed session from the temp-password window.
6. **Security:** login via `/config/.flixbox/qbit-api-login.sh` (stdin; exit 2 on WebUI ban); never widen AuthSubnetWhitelist beyond flixbox_net; no Direct fallback on VPN failure (ADR 0013).
7. **Lifecycle:** `flixbox up` / `reload` refresh qBit custom-services via `copy_templates` so Direct↔VPN mode flips install/remove `99-flixbox-bind-vpn-interface.sh` without a separate `init` (operators should still run `init` when changing `.env` paths/secrets). Bootstrap soft-fails with a clear warning; `up`/`reload` still exit 0 so compose start is not rolled back.

## Consequences

- Pros: remapped-port WebUI and Docker-peer auth survive qBit recreate; Host-header readiness matches configure (`json-query` / missing key ⇒ not OK); prefs drift reduced via shared JSON templates.
- Cons: long-running s6 service inside qBit container; host bootstrap depends on `docker logs` for session temp password; full automated recreate smoke remains optional/manual outside CI structural gates (C-84/C-85).
- Operators still run `configure` for *arr wiring; reconciler does not replace ADR 0016.

## Validation

- `scripts/ci-validate.sh` C-84, C-85
- `scripts/ci-smoke-init.sh` custom-services mode flip + prefs template install
- Manual / operator: recreate qBit → host GET on `QBITTORRENT_PORT` 200; Decluttarr `OK | qBittorrent`
