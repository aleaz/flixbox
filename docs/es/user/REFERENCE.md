<a id="quick-reference"></a>
# Referencia rápida

Hoja de consulta para operadores. Valores por defecto tras `./bin/flixbox init`.

> **Tras cambiar `.env`:** ejecuta `./bin/flixbox reload` (no un simple `restart`) para que los contenedores lean las variables nuevas.

> **Idioma:** si este archivo y la [REFERENCE (EN)](../../user/REFERENCE.md) divergen, **gana el inglés** ([ADR 0011](../../adr/0011-documentation-i18n.md)).

## CLI

Contrato completo: [17 — Referencia CLI](17-cli.md) (ADR 0021).

| Comando | Para qué |
| --- | --- |
| `./bin/flixbox init [--non-interactive]` | Crear `.env`, carpetas, plantillas; generar API keys/passwords. **Linux:** paths escribibles en `.env` antes de `--non-interactive` — [Install § paths](04-install.md#storage-paths-and-permissions) |
| `./bin/flixbox up [perfiles...]` | Levantar stack (`plex`, `proxy`, `recyclarr`, `notifications`, `vpn-heal`; elimina huérfanos al cambiar de modo) |
| `./bin/flixbox reload [--reset-homepage] [perfiles...]` | Recrear contenedores tras cambios en `.env` o compose. `--reset-homepage` también pisa plantillas Homepage gestionadas (con backup) |
| `./bin/flixbox update [--dry-run] [perfiles...]` | Pull de imágenes **pineadas** + reconciliar (`up -d --remove-orphans`); no reescribe a `:latest` — [14 — Image pins](14-image-pins.md) |
| `./bin/flixbox backup [--include-env] [--stop] [DEST]` | Archivar solo `${CONFIG_DIR}` (no media de `${DATA_DIR}`) |
| `./bin/flixbox restore ARCHIVE [--force]` | Restaurar archivo de CONFIG; `--force` para sobrescribir |
| `./bin/flixbox homepage refresh [--dry-run]` | Aplicar plantillas Homepage del repo a `${CONFIG_DIR}/homepage`. Usar tras `git pull` si `up`/`reload` avisan que hay templates más nuevos |
| `./bin/flixbox configure [--dry-run] [--sync-qbit-auth] [--sync-arr-ui]` | Cableado idempotente; sana API keys. `--dry-run` solo preview. `--sync-qbit-auth` fuerza password qBit desde `.env`. `--sync-arr-ui` aplica Forms en `shared` (ADR 0020) |
| `./bin/flixbox credentials show <target>` | Imprimir secreto (`qbit`, `arr-ui`, `admin`, o `api radarr\|sonarr\|prowlarr`) — solo stdout; no pegar en issues |
| `./bin/flixbox credentials set <target> --generate\|--prompt` | Escribir `.env` y aplicar. `qbit` = rotar; `arr-ui` = Forms en shared; `admin` = Jellyfin best-effort |
| `./bin/flixbox status [--json] [-q] [-v]` | Glance de salud + modo/paths; `-v` = compose ps completo |
| `./bin/flixbox doctor [--json]` | Checks de listo (Docker, .env, paths, hardlink/NFS/exFAT, VPN) |
| `./bin/flixbox logs [servicio]` | Ver logs |
| `./bin/flixbox vpn-test` | Comprobar VPN (solo modo VPN) |
| `./bin/flixbox recyclarr sync [--dry-run]` | Recyclarr one-shot (alias: `sync-profiles`) |
| `./bin/flixbox completion bash\|zsh` | Imprimir script de completion a stdout |
| `./bin/flixbox down` | Parar stack (volúmenes de config se conservan) |

**Sync Recyclarr (perfil opcional):**

```bash
./bin/flixbox recyclarr sync [--dry-run]
./bin/flixbox sync-profiles             # alias
```

## Web UI (host)

Reemplaza `localhost` por la IP LAN si entras desde otro dispositivo.

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

<a id="internal-hostname-contract-automation"></a>
## Contrato de hostnames internos

Usa **nombres de servicio Compose** en `flixbox_net` — no `container_name` (`flixbox-radarr`, etc.).

| Rol | Hostname | Puerto | Notas |
| --- | --- | --- | --- |
| Cliente de descarga (API qBit) | `qbittorrent` | `8080` | **Igual en VPN y Direct** (ADR 0014) |
| Películas | `radarr` | `7878` | |
| Series | `sonarr` | `8989` | |
| Indexers | `prowlarr` | `9696` | |
| Subtítulos | `bazarr` | `6767` | |
| Bypass CF | `byparr` | `8191` | |
| Pedidos | `seerr` | `5055` | |
| Streaming | `jellyfin` | `8096` | |
| VPN | `gluetun` | — | Solo modo VPN; no es el host de descarga de *arr |

<a id="internal-urls-arr-ui-wiring"></a>
## URLs internas (cableado en UIs *arr)

| Destino | URL |
| --- | --- |
| qBittorrent WebUI/API | `http://qbittorrent:8080` |
| Prowlarr | `http://prowlarr:9696` |
| Proxy Byparr | `http://byparr:8191` |
| Radarr | `http://radarr:7878` |
| Sonarr | `http://sonarr:8989` |
| Jellyfin | `http://jellyfin:8096` |

<a id="paths-inside-containers"></a>
## Rutas dentro de contenedores

| Ruta | Uso |
| --- | --- |
| `/data/torrents/` | Descargas qBit |
| `/data/torrents/incomplete/` | Torrents en curso |
| `/data/media/movies` | Raíz Radarr |
| `/data/media/tv` | Raíz Sonarr |

Equivalente en host: `${DATA_DIR}/…` del `.env`.

<a id="first-run-order-1015-min-with-configure"></a>
## Orden first-run (~10–15 min con configure)

```
init → up → configure → indexers en Prowlarr → Maintainerr / Recyclarr opcionales
```

| Paso | Tiempo | Acción |
| --- | --- | --- |
| 1 | ~10 min | [Install](04-install.md): `init`, revisar `.env` (VPN si aplica), `up` |
| 2 | ~2 min | `./bin/flixbox configure` |
| 3 | ~10 min | Agregar indexers en Prowlarr — [First-run](05-first-run.md) |

Vista previa sin cambios:

```bash
./bin/flixbox configure --dry-run   # sin escribir .env ni llamar APIs; el stack debe estar up
```

**Listo cuando:** status healthy · configure con 0 failed · ≥1 indexer · pedido Seerr en *arr · reproduce en Jellyfin — [Listo cuando](05-first-run.md#youre-done-when).

<a id="credentials-quick-map"></a>
## Mapa rápido de credenciales

| Credencial | La usa | Dónde |
| --- | --- | --- |
| API key Radarr/Sonarr/Prowlarr | Compose AUTH, Unpackerr, Decluttarr, Seerr, Bazarr | Generada por `init` → `.env` |
| Usuario/contraseña qBit | Decluttarr, configure | `.env` `QBITTORRENT_*` (init) |
| `FLIXBOX_ADMIN_*` | Startup Jellyfin, login Seerr | `.env` (init) |
| API key Jellyfin | Seerr, Maintainerr | Creada por configure → `.env` |

Auth de *arr sigue `FLIXBOX_ACCESS_PROFILE` (ADR 0015): **`trusted`** = sin login en LAN; **`shared`** = Forms + puertos admin en `127.0.0.1` — aplicar con `credentials set arr-ui` / `configure --sync-arr-ui` (ADR 0020).

Detalle: [Configuración — Credenciales](06-configuration.md#credentials-and-api-keys).

<a id="common-fixes"></a>
## Arreglos frecuentes

| Síntoma | Probar |
| --- | --- |
| Cambio en `.env` ignorado | `./bin/flixbox reload` |
| WebUI qBit muestra `Unauthorized` | [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| `configure` falla en VPN | Esperar Gluetun healthy: `./bin/flixbox logs gluetun` |
| Torrents trabados en metaDL (VPN) | Confirmar bind `tun0` — `./bin/flixbox configure` |
| Hardlinks fallan / doble disco | Mismo filesystem en `${DATA_DIR}` — [Cómo funciona](02-how-it-works.md) |
| Decluttarr idle | `QBITTORRENT_*` en `.env`, luego `configure` o `reload` |

Más: [Troubleshooting](10-troubleshooting.md).

<a id="related-docs"></a>
## Documentación relacionada

- [Aviso legal](16-legal-disclaimer.md) · [Legal disclaimer (EN)](../../user/16-legal-disclaimer.md)
- Índice ES: [INDEX.md](INDEX.md) · canónico EN: [docs/user/INDEX.md](../../user/INDEX.md)
- [Install](04-install.md) · [First-run](05-first-run.md) · [Configuración](06-configuration.md)
- [VPN y Direct](07-vpn-and-direct.md) · [Operación](09-operations.md)
