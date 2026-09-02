# ADR 0017: Compose healthchecks and Bazarr start order

- **Status:** Accepted
- **Date:** 2026-09-02
- **Related:** [0008](0008-maintenance-decluttarr-maintainerr.md), [0016](0016-configure-state-machine.md)

## Context

MVP Compose started *arr and Bazarr without HTTP healthchecks. Operators saw transient “connection refused” health tasks in *arr while peers were still booting SQLite. Bazarr had no `depends_on` link to Sonarr/Radarr despite configure wiring requiring both APIs.

## Decision

1. **HTTP healthchecks** on MVP core services that `configure` preflight probes:
   - Prowlarr, Radarr, Sonarr → `/ping` on container port
   - Bazarr → `/` on 6767
   - Jellyfin → `/System/Info/Public` on 8096
2. **Start order:** Bazarr `depends_on` Sonarr + Radarr with `condition: service_healthy`. Radarr/Sonarr keep `depends_on` qBit healthy (existing).
3. **Intervals:** 30s interval, 60s (90s Jellyfin) `start_period` — conservative for homelab disks.
4. **Resource limits:** not imposed by default; low-memory guidance stays in compose comments and user docs.

## Consequences

- Cold start may take slightly longer before Bazarr container starts; configure preflight already retries.
- CI compose-render and configure-smoke must remain green (C-76–C-77).
- Optional `deploy.resources` overrides remain operator responsibility.

## Validation

- `scripts/ci-validate.sh` C-76, C-77
- `scripts/ci-smoke-configure.sh` on direct stack
