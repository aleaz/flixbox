# Image pins

Flixbox Compose modules pin Docker images to **explicit version tags** (ADR 0010). Do not use `:latest` in `compose/`.

**Pin set date:** 2026-09-12

| Service | Image | Tag |
| --- | --- | --- |
| Gluetun | `qmcgaw/gluetun` | `v3.41.3` |
| qBittorrent | `lscr.io/linuxserver/qbittorrent` | `5.2.3` |
| Prowlarr | `lscr.io/linuxserver/prowlarr` | `2.5.2` |
| Byparr | `ghcr.io/thephaseless/byparr` | `3.0.4` |
| Radarr | `lscr.io/linuxserver/radarr` | `6.3.0` |
| Sonarr | `lscr.io/linuxserver/sonarr` | `4.0.19` |
| Bazarr | `lscr.io/linuxserver/bazarr` | `1.6.0` |
| Unpackerr | `ghcr.io/unpackerr/unpackerr` | `v0.16.1` |
| Recyclarr | `ghcr.io/recyclarr/recyclarr` | `8.7.2` |
| Decluttarr | `ghcr.io/manimatter/decluttarr` | `v2.1.0` |
| Maintainerr | `ghcr.io/maintainerr/maintainerr` | `3.27.0` |
| Seerr | `ghcr.io/seerr-team/seerr` | `v3.4.1` |
| Jellyfin | `lscr.io/linuxserver/jellyfin` | `10.11.11` |
| Plex (profile) | `lscr.io/linuxserver/plex` | `1.43.3` |
| Homepage | `ghcr.io/gethomepage/homepage` | `v2.3.0` |
| Caddy (profile) | `caddy` | `2.11.4` |
| docker-socket-proxy | `tecnativa/docker-socket-proxy` | `v0.5.0` |
| Apprise API (profile `notifications`) | `lscr.io/linuxserver/apprise-api` | `1.5.4` |

## Updating pins

1. Pick a newer **stable** tag from the vendor (avoid `nightly` / `develop`).
2. `docker pull <image>:<tag>` to confirm the manifest exists for amd64 and arm64 when you care about both.
3. Edit `compose/*.yml`, update this table (and release notes when you cut a release).
4. Run `./scripts/ci-validate.sh` (fails if any `image: …:latest` remains).
5. Smoke: [11 — Smoke test](11-smoke-test.md).
6. Operators: `./bin/flixbox update` (or `--dry-run` first) after pulling the repo with new pins.

Digests (`@sha256:…`) are optional for stricter supply-chain pinning; version tags are the v0.1 baseline.

## Related

- [ADR 0010](../adr/0010-mit-and-image-tags.md)
- [Smoke test](11-smoke-test.md)
