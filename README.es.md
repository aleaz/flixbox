<p align="center">
  <img src="docs/images/shared/logo.png" alt="Flixbox" width="180">
</p>

<h1 align="center">Flixbox</h1>

<p align="center">
  <strong>Pedí una película. Mirála en Jellyfin.</strong><br>
  Un CLI, una biblioteca, VPN opcional — sin pelear Compose a mano.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="Licencia MIT"></a>
  <a href="https://github.com/aleaz/flixbox/actions/workflows/ci.yml"><img src="https://github.com/aleaz/flixbox/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="docs/user/04-install.md"><img src="https://img.shields.io/badge/install-~15%20min-10b981.svg" alt="Install ~15 min"></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/es/user/INDEX.md">Guía</a> ·
  <a href="docs/user/04-install.md">Install (EN)</a>
</p>

---

<p align="center">
  <img src="docs/images/en/homepage-ops.png" alt="Dashboard Homepage Ops de Flixbox" width="920">
</p>

<p align="center"><em>Tu stack como consola de operaciones — no un montón de YAML.</em></p>

## ¿Por qué Flixbox?

- **Pedir → ver** — pedís en Seerr; Flixbox busca el release, lo descarga y lo deja en Jellyfin
- **Mismo disco, sin duplicar** — descargas y biblioteca comparten un árbol `/data` (hardlinks)
- **Direct hoy, VPN mañana** — cambiás de modo sin reconfigurar Radarr / Sonarr
- **Cuatro comandos** — `init`, `up`, `configure`, `status` con `./bin/flixbox`
- **Higiene sin sorpresas** — Decluttarr y Maintainerr con defaults conservadores
- **Tiempo honesto** — ~15 minutos hasta el stack arriba; indexers de Prowlarr después (no es zero-touch)

## En acción

<p align="center">
  <img src="docs/images/shared/cli-quickstart.gif" alt="flixbox init, up y status desde cero" width="920">
</p>

Cold start en el CLI: copiar `.env`, `init`, `up`, `status`.

## Cómo funciona

**Alguien pide un título → se descarga → aparece en Jellyfin.**

1. **Pedir** — Seerr → Radarr / Sonarr (+ Prowlarr)
2. **Descargar** — qBittorrent (Direct, o vía Gluetun en modo VPN)
3. **Ver** — hardlink a la biblioteca → Jellyfin

No hace falta Pi-hole ni reverse proxy para arrancar. Detalle: [How it works (EN)](docs/user/02-how-it-works.md).

## Inicio rápido

**Necesitás:** Docker Compose v2, ~4 GB RAM, Linux x86_64/ARM64 (macOS best-effort). Lista completa: [Requirements (EN)](docs/user/03-requirements.md).

**1. Clonar y setear paths**

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Editá DATA_DIR, CONFIG_DIR (escribibles), FLIXBOX_MODE, TZ
# Opcional: FLIXBOX_ACCESS_PROFILE=shared si compartís Wi‑Fi
```

**2. Levantar el stack**

```bash
./bin/flixbox init --non-interactive
./bin/flixbox up
./bin/flixbox status
```

**Esperado:** Homepage en http://localhost:3000 · Seerr `:5055` · Jellyfin `:8096` · qBittorrent `:8080`

**Logins:** `init` genera passwords en `.env`. Para verlos sin abrir el archivo:

```bash
./bin/flixbox credentials show qbit    # WebUI de qBittorrent
./bin/flixbox credentials show admin   # admin de Jellyfin (cuando esté)
```

Mapa completo: [Credentials and API keys (EN)](docs/user/06-configuration.md#credentials-and-api-keys).

**3. Cablear las apps**

```bash
./bin/flixbox configure
```

Después, indexers en Prowlarr (~10–15 min): [First-run (EN)](docs/user/05-first-run.md).

**Tip:** En Linux, creá y hacé `chown` de los paths (por defecto `/srv/flixbox/…`), o apuntá `.env` a paths que ya sean tuyos — [Install — storage paths (EN)](docs/user/04-install.md#storage-paths-and-permissions).

## Elegí tu camino

| Camino | Cuándo | Empezá acá |
| --- | --- | --- |
| **Primera prueba (Direct)** | Solo LAN, aprender el flujo | [Install (EN)](docs/user/04-install.md) |
| **Wi‑Fi compartido** | Convivientes en la misma LAN | `FLIXBOX_ACCESS_PROFILE=shared` — [Access profiles (EN)](docs/user/13-access-profiles.md) |
| **Privacidad (VPN)** | Torrents en producción | [VPN and Direct (EN)](docs/user/07-vpn-and-direct.md) |
| **HTTPS** | Reverse proxy | Perfil Caddy en [Configuration (EN)](docs/user/06-configuration.md) |
| **+ Plex** | Junto a Jellyfin o en su lugar | `./bin/flixbox up plex` |

## Documentación

| Doc | Para qué |
| --- | --- |
| [Guía de usuario (ES)](docs/es/user/INDEX.md) | Hub en español (parcial) |
| [Install (EN)](docs/user/04-install.md) | Clone → `init` → `up` |
| [First-run (EN)](docs/user/05-first-run.md) | `configure` + indexers |
| [Referencia rápida (ES)](docs/es/user/REFERENCE.md) | URLs, puertos, CLI |
| [Troubleshooting (EN)](docs/user/10-troubleshooting.md) | Fallos frecuentes |

**Contribuidores:** [Docs map (EN)](docs/INDEX.md) · [ADRs](docs/adr/) · [AGENTS.md](AGENTS.md) · [Doc style (EN)](docs/00-doc-style.md)

**English:** [README.md](README.md) · [User guide](docs/user/INDEX.md)

<details>
<summary><strong>Qué incluye</strong></summary>

Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy (opcional), docker-socket-proxy (con Homepage).

Defaults alineados con [TRaSH Guides](https://trash-guides.info/) donde aplica. Plataformas: Linux first-class (x86_64 / ARM64); Windows (Docker Desktop + WSL2) y macOS best-effort.

</details>

## Licencia

[MIT](LICENSE) © 2026 Alejandro Azario

## Aviso legal

Sos responsable de cumplir las leyes y términos de servicio aplicables al contenido, indexers o proveedores VPN que uses con este software.
