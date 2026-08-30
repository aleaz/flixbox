# Referencia rápida

Hoja de consulta para operadores. Valores por defecto tras `./bin/flixbox init`.

> **Tras cambiar `.env`:** ejecutá `./bin/flixbox reload` (no un simple `restart`) para que los contenedores lean las variables nuevas.

## CLI

| Comando | Para qué |
| --- | --- |
| `./bin/flixbox init [--non-interactive]` | Crear `.env`, carpetas, plantillas |
| `./bin/flixbox up [perfiles...]` | Levantar stack (`plex`, `proxy`, `socket-proxy`, `recyclarr`) |
| `./bin/flixbox reload [perfiles...]` | Recrear contenedores tras cambios en `.env` o compose |
| `./bin/flixbox configure [--dry-run]` | Cablear carpetas raíz, clientes de descarga, Byparr, apps Prowlarr, Bazarr |
| `./bin/flixbox status` | Estado + modo + URL del cliente de descarga |
| `./bin/flixbox logs [servicio]` | Ver logs |
| `./bin/flixbox vpn-test` | Comprobar VPN (solo modo VPN) |
| `./bin/flixbox down` | Parar stack (volúmenes de config se conservan) |

**Sync Recyclarr (perfil opcional):**

```bash
docker compose --profile recyclarr run --rm recyclarr sync
```

## Web UI (host)

Reemplazá `localhost` por la IP LAN si entrás desde otro dispositivo.

| Servicio | URL | Notas |
| --- | --- | --- |
| Homepage | `http://localhost:3000` | Panel |
| Seerr | `http://localhost:5055` | Pedidos |
| Jellyfin | `http://localhost:8096` | Streaming |
| qBittorrent | `http://localhost:8080` | WebUI (puerto host = `QBITTORRENT_PORT`) |
| Prowlarr | `http://localhost:9696` | Indexers |
| Radarr | `http://localhost:7878` | Películas |
| Sonarr | `http://localhost:8989` | Series |
| Bazarr | `http://localhost:6767` | Subtítulos |
| Maintainerr | `http://localhost:6246` | Higiene de biblioteca |
| Byparr | — | Sin WebUI; logs con `./bin/flixbox logs byparr` |
| Caddy | `http://localhost:80` | Solo perfil `proxy` |

## URLs internas (cableado en UIs *arr)

Usá estas **dentro de Docker** (clientes de descarga, apps en Prowlarr, etc.). Host qBit: **`qbittorrent:8080`** en Direct y VPN (ADR 0014).

| Destino | URL |
| --- | --- |
| qBittorrent WebUI/API | `http://qbittorrent:8080` |
| Prowlarr | `http://prowlarr:9696` |
| Proxy Byparr | `http://byparr:8191` |
| Radarr | `http://radarr:7878` |
| Sonarr | `http://sonarr:8989` |
| Jellyfin | `http://jellyfin:8096` |

## Rutas dentro de contenedores

| Ruta | Uso |
| --- | --- |
| `/data/torrents/` | Descargas qBit |
| `/data/torrents/incomplete/` | Torrents en curso |
| `/data/media/movies` | Raíz Radarr |
| `/data/media/tv` | Raíz Sonarr |

Equivalente en host: `${DATA_DIR}/…` del `.env`.

## Orden first-run (~30–45 min con configure)

```
init → up → login en cada app → configure → indexers → Jellyfin → Seerr → reload (claves Decluttarr en .env)
```

| Paso | Tiempo | Acción |
| --- | --- | --- |
| 1 | ~15 min | [Instalación](../../user/04-install.md): `init`, editar `.env`, `up` |
| 2 | ~5 min | Abrí Radarr, Sonarr, Prowlarr, Bazarr, qBit — wizard + cambiar contraseña qBit |
| 3 | ~5 min | `./bin/flixbox configure` |
| 4 | ~15 min | Indexers, bibliotecas Jellyfin, Seerr, claves Decluttarr — [First-run](../../user/05-first-run.md) (EN) |

Vista previa sin cambios:

```bash
./bin/flixbox configure --dry-run
```

## Mapa rápido de credenciales

| Credencial | La usa | Dónde |
| --- | --- | --- |
| API key Radarr/Sonarr | Unpackerr, Decluttarr, Prowlarr, Seerr, Bazarr | App → Settings → General; `.env` para servicios Compose |
| API key qBit | Cliente descarga en Radarr/Sonarr | qBit → Options → Web UI → API access |
| Usuario/contraseña qBit | Decluttarr, script configure | Login WebUI; `.env` `QBITTORRENT_*` |
| API key Jellyfin | Seerr, Maintainerr | Jellyfin → Dashboard → API Keys |

Detalle: [Configuration — Credentials](../../user/06-configuration.md#credentials-and-api-keys) (EN).

## Arreglos frecuentes

| Síntoma | Probar |
| --- | --- |
| Cambio en `.env` ignorado | `./bin/flixbox reload` |
| WebUI qBit muestra `Unauthorized` | [First-run §2b.1](../../user/05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) (EN) |
| `configure` falla en VPN | Esperar Gluetun healthy: `./bin/flixbox logs gluetun` |
| Hardlinks fallan / doble disco | Mismo filesystem en `${DATA_DIR}` |
| Decluttarr idle | `QBITTORRENT_USERNAME` + `QBITTORRENT_PASSWORD` en `.env`, luego `reload` |

Más: [Troubleshooting](../../user/10-troubleshooting.md) (EN).

## Documentación relacionada

- Guía EN canónica: [docs/user/INDEX.md](../../user/INDEX.md)
- [Install](../../user/04-install.md) · [First-run](../../user/05-first-run.md) · [Configuration](../../user/06-configuration.md)
