# ADR 0006: MVP service inventory

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-27 (Seerr, Byparr, Decluttarr, Maintainerr)

## Context

The original proposal listed many services and outdated names (Jellyseerr, FlareSolverr-as-default). Audit + maintainer decisions freeze a coherent MVP including queue and library hygiene.

## Decision

MVP inventory is exactly:

**Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy**, and optional **docker-socket-proxy**.

Explicitly **not** MVP: Lidarr, Readarr, Audiobookshelf, SABnzbd, Whisper, Overseerr, Jellyseerr, Autobrr, cross-seed, Profilarr, Authelia/Authentik, Telegram bots, Vagrant, Streamystats.

FlareSolverr may be documented as an alternate Byparr-compatible image, not the default.

## Consequences

- Requirements and Compose modules must match this list.
- Adding a service requires scope + roadmap updates (and often a new ADR).
