# ADR 0008: Decluttarr + Maintainerr hygiene pair

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-31 (whitelist scope clarified — ADR 0015)

## Context

Core *arr stacks often stall on dead torrents and accumulate unwatched media. Community practice pairs **Decluttarr** and **Maintainerr** (library rules). Maintainerr supports Jellyfin.

Decluttarr authenticates to qBittorrent with **WebUI username/password** (not the qBit API key). During first-run those values are often empty in `.env`, which caused Decluttarr to fail-login in a loop and **ban its Docker IP** in qBittorrent — a confusing 403 even after credentials were fixed.

Compose must not interpolate secrets into `command:` / `entrypoint:` shell strings (they are baked into the container config at create time).

## Decision

- Include **Decluttarr** and **Maintainerr** in the MVP inventory under `compose/optimization.yml`.
- Decluttarr manages Radarr/Sonarr queues and qBittorrent; must use mode-aware qBit URL (`gluetun` vs `qbittorrent`).
- Maintainerr defaults to **Jellyfin** + Radarr/Sonarr. One media server at a time.
- Default behavior and thresholds are defined in [docs/09-hygiene-defaults.md](../09-hygiene-defaults.md).
- Streamystats remains optional/post-MVP.
- **Decluttarr idle entrypoint:** `templates/decluttarr/entrypoint.sh` (copied by `flixbox init` to `${CONFIG_DIR}/decluttarr-entrypoint.sh`). If `QBITTORRENT_USERNAME` or `QBITTORRENT_PASSWORD` is empty, sleep with a clear log line — **no** qBit login. Credentials are read from container **environment at runtime** only.
- **Docker automation network (`172.30.42.0/24`):** `flixbox_net` is pinned to that CIDR ([compose/network-base.yml](../../compose/network-base.yml), hardcoded). qBittorrent cont-init enables `WebUI\AuthSubnetWhitelist` for that CIDR. That bypasses WebUI password **only for clients on `flixbox_net`** (stack peers) and often the host path via the Docker bridge gateway — **not** for arbitrary home LAN `192.168.x.x` clients ([ADR 0015](0015-access-profiles.md)). Distinct from LAN profile `trusted` / `shared`. Do not publish qBit WebUI to the public internet. Not env-configurable (Compose subnet and whitelist must stay identical).
- **Startup order:** qBittorrent has a WebUI healthcheck; Radarr, Sonarr, Decluttarr, and Unpackerr `depends_on: qbittorrent: condition: service_healthy` so first health checks are not `Connection refused` races. In VPN mode qBit still waits on Gluetun first; peers reach qBit via `http://qbittorrent:8080` (Gluetun network alias — ADR 0014).

## Consequences

- Templates must implement the hygiene defaults doc, not invent ad-hoc aggressive rules.
- Hardlink + seeding interaction must be documented (deleting library path may not free space while seeding).
- Existing installs that created `flixbox_net` without the fixed subnet must recreate the network (`docker compose down`, remove `flixbox_net` if needed, then `up`) for the whitelist to match.
- Operators must run `flixbox init` (or copy the Decluttarr entrypoint) before Decluttarr can start after upgrades that add the mount.
- Operators must still put qBit WebUI login in `.env` for Decluttarr; whitelist does not replace the idle gate (Decluttarr always attempts login when active).
- **`flixbox configure`** SHOULD write `RADARR_API_KEY` / `SONARR_API_KEY` / `QBITTORRENT_*` into `.env` when empty (discovered or operator-supplied) and recreate Decluttarr/Unpackerr so hygiene leaves idle without a manual copy-paste step.
