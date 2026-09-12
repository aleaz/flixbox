<p align="center">
  <img src="docs/images/shared/logo.png" alt="Flixbox" width="110">
</p>

<h1 align="center">Flixbox</h1>

<p align="center">
  <strong>Pide una película. Mírala en Jellyfin.</strong><br>
  Un CLI, una biblioteca, VPN opcional — sin pelear Compose a mano.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="Licencia MIT"></a>
  <a href="https://github.com/aleaz/flixbox/releases/tag/v0.1.1"><img src="https://img.shields.io/badge/release-v0.1.1-0ea5e9.svg" alt="Release v0.1.1"></a>
  <a href="https://github.com/aleaz/flixbox/actions/workflows/ci.yml"><img src="https://github.com/aleaz/flixbox/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="docs/es/user/04-install.md"><img src="https://img.shields.io/badge/install-~15%20min-10b981.svg" alt="Install ~15 min"></a>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="docs/es/user/INDEX.md">Guía</a> ·
  <a href="docs/es/user/04-install.md">Install</a>
</p>

---

## Cómo funciona

**Alguien pide un título → se descarga → aparece en Jellyfin.**

| | Etapa | Qué corre |
| --- | --- | --- |
| **1** | **Pedir** | Seerr → Radarr / Sonarr (+ Prowlarr) |
| **2** | **Descargar** | qBittorrent — Direct, o vía Gluetun en modo VPN |
| **3** | **Ver** | Hardlink a `/data/media` → Jellyfin |

No hace falta Pi-hole ni reverse proxy para arrancar. Diagrama completo: [Cómo funciona](docs/es/user/02-how-it-works.md).

---

<p align="center">
  <img src="docs/images/en/homepage-ops.png" alt="Dashboard Homepage Ops de Flixbox" width="920">
</p>

<p align="center"><em>Tu stack como consola de operaciones — el pipeline de arriba, en una pantalla.</em></p>

## De cero a corriendo

<p align="center">
  <img src="docs/images/shared/cli-quickstart.gif" alt="flixbox init, up y status desde cero" width="920">
</p>

Cold start en el CLI: `cp .env.example .env`, `init`, `up`, `status`, luego `configure` cablea las apps.

## ¿Por qué Flixbox?

- **Pedir → ver** — pides en Seerr; Flixbox busca el release, lo descarga y lo deja en Jellyfin
- **Mismo disco, sin duplicar** — descargas y biblioteca comparten un árbol `/data` (hardlinks)
- **Direct hoy, VPN mañana** — cambias de modo sin reconfigurar Radarr / Sonarr
- **Cuatro comandos** — `init`, `up`, `configure`, `status` con `./bin/flixbox`
- **Higiene sin sorpresas** — Decluttarr y Maintainerr con defaults conservadores
- **Tiempo honesto** — ~15 minutos hasta el stack arriba; indexers de Prowlarr después (no es zero-touch)

## Inicio rápido

**Necesitas:** Docker Compose v2, **4 GB RAM mínimo / 8 GB cómodo**, Linux x86_64/ARM64 (macOS best-effort). Lista completa: [Requisitos](docs/es/user/03-requirements.md).

**1. Clonar y definir paths**

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Edita DATA_DIR, CONFIG_DIR (escribibles), FLIXBOX_MODE, TZ
# Opcional: FLIXBOX_ACCESS_PROFILE=shared si compartes Wi‑Fi
```

**Tip (Linux):** crea y haz `chown` de los paths primero (por defecto `/srv/flixbox/…`), o apunta `.env` a paths que ya sean tuyos — [Install — rutas](docs/es/user/04-install.md#storage-paths-and-permissions).

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

Mapa completo: [Credenciales y API keys](docs/es/user/06-configuration.md#credentials-and-api-keys).

**3. Cablear las apps**

```bash
./bin/flixbox configure
# Si FLIXBOX_ACCESS_PROFILE=shared:
# ./bin/flixbox credentials set arr-ui --generate
```

Después, indexers en Prowlarr (~10–15 min): [First-run](docs/es/user/05-first-run.md).

**Listo cuando:** `status` healthy · `configure` con **0 failed** · ≥1 indexer · pedido Seerr en *arr · reproduce en Jellyfin — detalle en [First-run](docs/es/user/05-first-run.md#youre-done-when).

## Elige tu camino

| Camino | Cuándo | Empieza aquí |
| --- | --- | --- |
| **Primera prueba (Direct)** | Solo LAN, aprender el flujo | [Install](docs/es/user/04-install.md) |
| **Wi‑Fi compartido** | Convivientes en la misma LAN | `FLIXBOX_ACCESS_PROFILE=shared` y luego `credentials set arr-ui` — [Perfiles de acceso](docs/es/user/13-access-profiles.md) |
| **Privacidad (VPN)** | Torrents en producción | [VPN y Direct](docs/es/user/07-vpn-and-direct.md) |
| **HTTPS** | Reverse proxy (LAN; no endurecido solo para WAN) | Perfil Caddy en [Configuración](docs/es/user/06-configuration.md) |
| **+ Plex** | Junto a Jellyfin o en su lugar | `./bin/flixbox up plex` |

## Documentación

| Doc | Para qué |
| --- | --- |
| [Guía de usuario (ES)](docs/es/user/INDEX.md) | Hub en español (espejo completo) |
| [Install](docs/es/user/04-install.md) | Clone → `init` → `up` |
| [First-run](docs/es/user/05-first-run.md) | `configure` + indexers |
| [Referencia rápida](docs/es/user/REFERENCE.md) | URLs, puertos, CLI |
| [Troubleshooting](docs/es/user/10-troubleshooting.md) | Fallos frecuentes |

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

> Los autores **no aprueban** la infracción de derechos de autor. **Flixbox no desarrolla** qBittorrent, Radarr, Sonarr, Jellyfin ni las demás apps del stack: solo **ensambla y conecta** herramientas de terceros. **Úsalo bajo tu propio riesgo:** tú eliges el contenido, los indexers y la VPN, y asumes la responsabilidad legal y operativa. Flixbox **no está afiliado** a esos proyectos upstream. Se ofrece **TAL CUAL (*AS IS*)** bajo la [Licencia MIT](LICENSE).

Aviso completo (ES/EN): [Aviso legal](docs/es/user/16-legal-disclaimer.md) · [Legal disclaimer](docs/user/16-legal-disclaimer.md)
