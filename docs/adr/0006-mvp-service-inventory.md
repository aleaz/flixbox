# ADR 0006: MVP service inventory

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-09-07 (socket-proxy always on with Homepage — ADR 0022); 2026-09-15 (clarify: “MVP” here = shipped **v0.1 core inventory**)

> **Note:** The title keeps “MVP” for stable ADR identity. In current docs prefer **v0.1 baseline** / **core inventory** ([01-scope.md](../01-scope.md)).

## Context

The original proposal listed many services and outdated names (Jellyseerr, FlareSolverr-as-default). Audit + maintainer decisions freeze a coherent core inventory including queue and library hygiene.

## Decision

The **v0.1 core inventory** (historically “MVP”) is exactly:

**Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy**, and **docker-socket-proxy** (always on with Homepage — [ADR 0022](0022-operator-footgun-remediations.md)).

Explicitly **not** in that baseline: Lidarr, Readarr, Audiobookshelf, SABnzbd, Whisper, Overseerr, Jellyseerr, Autobrr, cross-seed, Profilarr, Authelia/Authentik, Telegram bots, Vagrant, Streamystats.

FlareSolverr may be documented as an alternate Byparr-compatible image, not the default.

## Consequences

- Requirements and Compose modules must match this list.
- Adding a service requires scope + roadmap updates (and often a new ADR).

## Updates

- **2026-09-07:** docker-socket-proxy required with Homepage (no longer an optional Compose profile).