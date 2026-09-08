# Flixbox

**Tu pipeline de media en casa — pedir, descargar, organizar, ver.**

Pedís una película o serie en Seerr. Flixbox busca un release, lo descarga (opcionalmente por VPN), lo hardlinkea a tu biblioteca y lo servís en Jellyfin. Un CLI, un árbol `/data`, defaults alineados con [TRaSH Guides](https://trash-guides.info/).

Also available in [English](README.md).

## Cómo funciona

**El flujo:** alguien pide un título → se descarga → aparece en Jellyfin.

```text
Pedido:   Seerr → Radarr / Sonarr → Prowlarr (+ Byparr)
Descarga: qBittorrent  (Direct, o vía Gluetun en modo VPN)
Ver:      Jellyfin
Mantener: Decluttarr (colas) · Maintainerr (reglas de biblioteca)
```

No hace falta Pi-hole ni reverse proxy para arrancar.

## ¿Por qué Flixbox?

- **Empezá simple** — modo Direct en ~15 minutos; pasá a VPN cuando quieras producción
- **Un solo CLI** — `bin/flixbox`: `init`, `up`, `configure`, `reload`, `status`, `vpn-test`
- **Higiene incluida** — Decluttarr y Maintainerr con defaults conservadores (sin borrados sorpresa)
- **Compose modular** — YAML chico y perfiles opcionales (`plex`, `proxy`, `recyclarr`), no un monolito
- **Contratos explícitos** — un solo `/data` con hardlinks, host de descarga `qbittorrent` en Direct y VPN ([ADRs](docs/adr/))

## Elegí tu setup

| Setup | Cuándo | Empezá acá |
| --- | --- | --- |
| **Core (Direct)** | Primera prueba, solo LAN | [Install (EN)](docs/user/04-install.md) |
| **Wi‑Fi compartido** | Convivientes en la misma LAN | `FLIXBOX_ACCESS_PROFILE=shared` + `init`/`up` — guía en inglés: [Access profiles](docs/user/13-access-profiles.md) (aún sin mirror ES) |
| **+ VPN** | Torrents en producción | [VPN and Direct (EN)](docs/user/07-vpn-and-direct.md) |
| **+ HTTPS** | Reverse proxy | Perfil Caddy en [Configuration (EN)](docs/user/06-configuration.md) |
| **+ Plex** | Junto a Jellyfin o en su lugar | `./bin/flixbox up plex` |

## Inicio rápido

**Requisitos:** Docker Compose v2, ~4 GB RAM, Linux x86_64/ARM64 (macOS best-effort). Ver [Requirements (EN)](docs/user/03-requirements.md).

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Editá .env: DATA_DIR, CONFIG_DIR (paths escribibles), FLIXBOX_MODE, TZ
./bin/flixbox init --non-interactive
./bin/flixbox up
./bin/flixbox status
./bin/flixbox configure
```

Linux: los paths por defecto usan `/srv/flixbox/…` — creálos con `sudo` y `chown`, o poné paths como `/data/flixbox/data` en `.env`. Ver [Install — storage paths (EN)](docs/user/04-install.md#storage-paths-and-permissions).

**Después (~10–15 min):** indexers en Prowlarr — [First-run (EN)](docs/user/05-first-run.md).

| Servicio | URL por defecto |
| --- | --- |
| Homepage | http://localhost:3000 |
| Seerr | http://localhost:5055 |
| Jellyfin | http://localhost:8096 |
| qBittorrent | http://localhost:8080 |

Puertos completos: [Referencia rápida (ES)](docs/es/user/REFERENCE.md).

## Documentación

| Doc | Para qué |
| --- | --- |
| [Guía de usuario (ES)](docs/es/user/INDEX.md) | Hub en español (parcial) |
| [Install (EN)](docs/user/04-install.md) | Clone → `init` → `up` (~15 min) |
| [First-run (EN)](docs/user/05-first-run.md) | `configure` + cableado restante |
| [Referencia rápida (ES)](docs/es/user/REFERENCE.md) | URLs, puertos, CLI |
| [How it works (EN)](docs/user/02-how-it-works.md) | Pipeline, `/data`, VPN vs Direct |
| [Troubleshooting (EN)](docs/user/10-troubleshooting.md) | Fallos frecuentes |

**Contribuidores:** [Docs map (EN)](docs/INDEX.md) · [ADRs](docs/adr/) · [AGENTS.md](AGENTS.md)

## Estado

El stack MVP arranca con `./bin/flixbox up`. Después del boot, cableás indexers y API keys en la UI (~30–45 min con `configure`). No es zero-touch — y no lo decimos. Ver [first-run (EN)](docs/user/05-first-run.md).

<details>
<summary><strong>Stack completo (MVP)</strong></summary>

Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy (opcional), docker-socket-proxy (con Homepage).

</details>

## Plataformas

- **First-class:** Linux (x86_64 / ARM64)
- **Best-effort:** Windows (Docker Desktop + WSL2 ext4), macOS

## Licencia

[MIT](LICENSE) © 2026 Alejandro Azario

## Aviso legal

Sos responsable de cumplir las leyes y términos de servicio aplicables al contenido, indexers o proveedores VPN que uses con este software.
