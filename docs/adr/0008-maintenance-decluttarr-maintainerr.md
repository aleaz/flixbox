# ADR 0008: Decluttarr + Maintainerr hygiene pair

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-27 (standard rule pack)

## Context

Core *arr stacks often stall on dead torrents and accumulate unwatched media. Community practice pairs **Decluttarr** (download queue) with **Maintainerr** (library rules). Maintainerr supports Jellyfin.

## Decision

- Include **Decluttarr** and **Maintainerr** in the MVP inventory under `compose/optimization.yml`.
- Decluttarr manages Radarr/Sonarr queues and qBittorrent; must use mode-aware qBit URL (`gluetun` vs `qbittorrent`).
- Maintainerr defaults to **Jellyfin** + Radarr/Sonarr. One media server at a time.
- Default behavior and thresholds are defined in [docs/09-hygiene-defaults.md](../09-hygiene-defaults.md):
  - Decluttarr: stalled/slow/failed/orphan cleanup with 5 strikes, 100 KiB/s floor, `flixbox-keep` protect tag; unmonitored removal **off**.
  - Maintainerr: unwatched movies 90d → Leaving Soon → delete after 14d; unwatched TV 180d → Leaving Soon → delete after 21d; skip items &lt; 30d old; watched-movie reclaim **off** by default.
- Streamystats remains optional/post-MVP.

## Consequences

- Templates must implement the hygiene defaults doc, not invent ad-hoc aggressive rules.
- Hardlink + seeding interaction must be documented (deleting library path may not free space while seeding).
