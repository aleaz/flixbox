# ADR 0022: Operator footgun remediations

- **Status:** Accepted
- **Date:** 2026-09-07
- **Updated:** 2026-09-07 (review remediations: Seerr probe, proxy healthcheck, docker.yaml migration)
- **Related:** [0003](0003-compose-modularity.md), [0006](0006-mvp-service-inventory.md), [0007](0007-platform-support-tiers.md), [0018](0018-runtime-secrets-and-lan-trust.md)

## Context

Live operator footguns from the stack audit:

1. Switching `FLIXBOX_MODE` left orphan containers (e.g. Gluetun after Direct) because Compose does not remove them by default.
2. Homepage mounted the host Docker socket read-only while `docker-socket-proxy` was an optional profile — the least-privilege path was unused by default.
3. Seerr ignores `PUID`/`PGID` and needs UID/GID `1000` on `${CONFIG_DIR}/seerr`; ownership failure only warned, so first-run could restart-loop.

Accepted residuals (not changed here): VPN fail-closed ([ADR 0013](0013-vpn-resilience-no-direct-fallback.md)); secrets in Compose env + `trusted` LAN banner ([ADR 0018](0018-runtime-secrets-and-lan-trust.md)).

## Decision

1. **`up` / `reload` always pass `--remove-orphans`** so mode switches and removed services do not leave stranded containers in the project.
2. **`docker-socket-proxy` is always on** with Homepage (no Compose profile). Homepage does **not** mount `/var/run/docker.sock`; it reaches Docker via `docker-socket-proxy:2375` (`templates/homepage/docker.yaml`). Proxy policy stays read-limited (`POST`/`DELETE`/`EXEC` denied). Proxy has a healthcheck; Homepage waits `service_healthy`. Live `docker.yaml` that still uses a `socket:` mount or lacks `host: docker-socket-proxy` is rewritten on template copy (logged).
3. **`up` / `reload` / `init` fail closed** if `${CONFIG_DIR}/seerr` cannot be owned as `1000:1000`. Write verification uses host UID when it reports `1000`, or a **cached** `alpine:3.20` probe with `--pull=never` — never pull an image solely to verify ownership.

Optional Compose profiles remain: `plex`, `proxy`, `recyclarr`. Legacy `socket-proxy` in `COMPOSE_PROFILES` is ignored (warn once; whitespace-tolerant).

## Consequences

- Mode switch: `edit .env` → `flixbox up` (or `reload`) removes Gluetun when switching to Direct without a separate orphan hunt.
- Attack surface: only the proxy container mounts the host socket; Homepage is a Docker API client over the bridge. **Residual:** a compromised Homepage can still call the read-limited Docker API (`CONTAINERS`/`INFO`/`NETWORKS`) — Homepage is not a security boundary ([ADR 0018](0018-runtime-secrets-and-lan-trust.md)).
- Operators without `chown` / Docker helper access cannot start until Seerr ownership is fixed (documented troubleshooting remains).
- ADR 0006 inventory: socket-proxy is required with Homepage, not optional.
- **Platform:** proxy mounts `/var/run/docker.sock` (rootful Engine first-class path). Rootless Docker / custom `DOCKER_HOST` may need operator adaptation ([ADR 0007](0007-platform-support-tiers.md)).

## Validation

- CI: `up`/`reload` use `--remove-orphans`; `dashboard.yml` has no Homepage `docker.sock` mount, proxy healthcheck + Homepage `service_healthy`, no `socket-proxy` profile; Seerr gate fails hard without unconditional alpine pulls.
- Operator smoke: mode orphans, Homepage Docker via proxy, Seerr ownership fail-closed ([11-smoke-test.md](../user/11-smoke-test.md) Phase G).
