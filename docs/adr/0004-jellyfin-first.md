# ADR 0004: Jellyfin-first media + Seerr requests

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-27 (Seerr replaces Jellyseerr)

## Context

Flixbox is a public open-source project. In February 2026, Overseerr and Jellyseerr unified as **Seerr**, which supports Jellyfin, Plex, and Emby. Greenfield installs should not target legacy request apps.

## Decision

- **Jellyfin** is the primary, default media server.
- **Plex** may ship only as an optional Compose profile.
- Request portal is **Seerr** (`ghcr.io/seerr-team/seerr`) with `init: true` and UID 1000 config ownership.
- Do not ship Overseerr or Jellyseerr containers.

## Consequences

- Docs, dashboard widgets, Maintainerr, and init defaults target Jellyfin + Seerr.
- Plex-specific quirks are not MVP blockers.
- Seerr can still talk to Plex if the optional profile is enabled later.
