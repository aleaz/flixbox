# ADR 0004: Jellyfin-first media + Seerr requests

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-30 (API-assisted Jellyfin libraries + Seerr wiring via `configure`)

## Context

Flixbox is a public open-source project. In February 2026, Overseerr and Jellyseerr unified as **Seerr**, which supports Jellyfin, Plex, and Emby. Greenfield installs should not target legacy request apps.

Jellyfin and Seerr first-run wizards are the largest remaining UI steps after *arr wiring. Both expose stable HTTP APIs for startup/libraries (Jellyfin) and settings/initialize (Seerr).

## Decision

- **Jellyfin** is the primary, default media server.
- **Plex** may ship only as an optional Compose profile.
- Request portal is **Seerr** (`ghcr.io/seerr-team/seerr`) with `init: true` and UID 1000 config ownership.
- Do not ship Overseerr or Jellyseerr containers.
- **`flixbox configure`** SHOULD complete, when credentials are available (idempotent):
  - Jellyfin startup (admin user from `.env` if unset) and libraries at `/data/media/movies` + `/data/media/tv`.
  - Seerr Jellyfin login + Radarr/Sonarr service entries + `settings/initialize` when not yet initialized.
- Maintainerr connections remain operator UI (destructive rules must stay deliberate — ADR 0008).

## Consequences

- Docs, dashboard widgets, Maintainerr, and init defaults target Jellyfin + Seerr.
- Plex-specific quirks are not MVP blockers.
- Seerr can still talk to Plex if the optional profile is enabled later.
- `.env` may hold `JELLYFIN_API_KEY` and optional admin user/password used only for first-run automation — never commit `.env`.
