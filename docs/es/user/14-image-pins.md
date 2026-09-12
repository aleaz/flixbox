<a id="image-pins"></a>
# Pins de imágenes

**Idiomas:** [English](../../user/14-image-pins.md) · Español (esta página)

Los módulos Compose de Flixbox fijan las imágenes Docker a **tags de versión explícitos** (ADR 0010). No uses `:latest` en `compose/`.

**Fecha del set de pins:** 2026-09-12

| Servicio | Imagen | Tag |
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

<a id="updating-pins"></a>
## Actualizar pins

1. Elige un tag **stable** más reciente del vendor (evita `nightly` / `develop`).
2. `docker pull <image>:<tag>` para confirmar que el manifiesto existe para amd64 y arm64 cuando te importen ambos.
3. Edita `compose/*.yml`, actualiza esta tabla (y las notas de release cuando cortes un release).
4. Ejecuta `./scripts/ci-validate.sh` (falla si queda algún `image: …:latest`).
5. Smoke: [11 — Smoke test](11-smoke-test.md).

Los digests (`@sha256:…`) son opcionales para un pin más estricto de supply-chain; los tags de versión son la línea base de v0.1.

<a id="related"></a>
## Relacionado

- [ADR 0010](../../adr/0010-mit-and-image-tags.md)
- [Smoke test](11-smoke-test.md)
