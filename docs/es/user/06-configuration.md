<a id="configuration"></a>
# Configuración

**Idiomas:** [English](../../user/06-configuration.md) · Español (esta página)

Las variables de entorno viven en `.env` (creado desde `.env.example` o por `./bin/flixbox init`). **Nunca hagas commit de `.env`.**

El archivo plantilla agrupa las variables según cuándo las necesitas: **requeridas antes del primer `up`**, **opcionales**, **después del first-run** y **solo VPN**. Esta página es la referencia completa.

<a id="setup-order"></a>
## Orden de setup

1. **Antes del primer `up`:** `DATA_DIR`, `CONFIG_DIR`, `FLIXBOX_MODE`, `TZ`, `PUID`/`PGID` si no son 1000, y opcionalmente `FLIXBOX_ACCESS_PROFILE` (`trusted` por defecto, o `shared` en Wi‑Fi compartida — [§13](13-access-profiles.md)).
2. **Arrancar el stack:** `./bin/flixbox up` (sincroniza keys derivadas de bind/auth si el perfil se desalineó)
3. **Cablear apps:** `./bin/flixbox configure` — ver [First-run §0](05-first-run.md#0-script-assisted-wiring-recommended) para lo que configura
4. **Después de configure:** solo si cambiaste secrets a mano — [Credenciales y API keys](#credentials-and-api-keys) → `./bin/flixbox reload` cuando los consumidores de Compose necesiten valores nuevos de `.env`
5. **Solo modo VPN:** credenciales de Gluetun en `.env` antes de `up`/`reload` → `./bin/flixbox vpn-test`
6. **Sigue siendo manual:** indexers de Prowlarr; reglas opcionales de Maintainerr / sync de Recyclarr; Forms en `shared` vía `credentials set arr-ui` — [First-run](05-first-run.md)

Consulta rápida: [REFERENCE](REFERENCE.md).

<a id="required-before-first-up"></a>
## Requerido antes del primer `up`

Defaults de plataforma cuando ejecutas `./bin/flixbox init` (`.env` nuevo):

| OS | `DATA_DIR` | `CONFIG_DIR` |
| --- | --- | --- |
| Linux | `/srv/flixbox/data` | `/srv/flixbox/config` |
| macOS (OrbStack / Docker Desktop) | `$HOME/flixbox/data` | `$HOME/flixbox/config` |

`.env.example` muestra las rutas de referencia de Linux. `init` las reescribe en macOS. **OrbStack** es un runtime de desarrollo macOS soportado; el smoke de la tag v0.1 sigue apuntando a Linux.

En Linux, `/srv/flixbox/…` no es escribible hasta que lo crees (normalmente con `sudo`) o elijas otra ruta — ver [Install — Storage paths and permissions](04-install.md#storage-paths-and-permissions). Flixbox solo lee rutas desde `.env`; un `export DATA_DIR=…` en el shell no afecta a `init` ni a `up` a menos que también escribas ese valor en `.env`.

| Variable | Valor por defecto | Valores válidos | Notas |
| --- | --- | --- | --- |
| `FLIXBOX_MODE` | `direct` | `direct`, `vpn` | **Único switch que Compose lee** para downloaders. Ver [VPN y Direct](07-vpn-and-direct.md). |
| `VPN_ENABLED` | `false` | `true`, `false` | **Compose no lo lee.** Espejo del modo; `init` lo sincroniza. Manténlo alineado (`direct`↔`false`, `vpn`↔`true`) para que docs/CLI no mientan. |
| `DATA_DIR` | Depende del OS (tabla arriba) | Ruta absoluta | Torrents + media en un solo filesystem para hardlinks. No NFS/SMB/exFAT; no WSL `/mnt/c`. **Si lo cambias después del setup**, ver [Day-2 — Changing paths](09-operations.md#changing-paths-and-storage-layout). |
| `CONFIG_DIR` | Depende del OS (tabla arriba) | Ruta absoluta | Configs de apps solo en SSD/NVMe local. Cambiarlo es una migración de config — misma guía. |
| `COMPOSE_PROJECT_NAME` | `flixbox` | Nombre de proyecto Docker | Casi nunca se cambia. |

<a id="access-profile-adr-0015"></a>
## Perfil de acceso (ADR 0015)

Guía completa: [13 — Access profiles](13-access-profiles.md).

| Variable | Valor por defecto | Valores | Efecto |
| --- | --- | --- | --- |
| `FLIXBOX_ACCESS_PROFILE` | `trusted` | `trusted`, `shared` | `trusted`: WebUI *arr abierta en LAN (RFC1918). `shared`: *arr exige login (`Forms`) + puertos admin en localhost. |
| `FLIXBOX_ARR_AUTH_METHOD` | *(desde el perfil)* | `External`, `Forms` | Lo pone `init` — no lo edites a mano salvo que conozcas la auth de Servarr. |
| `FLIXBOX_ARR_AUTH_REQUIRED` | *(desde el perfil)* | `DisabledForLocalAddresses`, `Enabled` | `Enabled` en `shared`. |
| `FLIXBOX_ADMIN_BIND_IP` | *(desde el perfil)* | `0.0.0.0`, `127.0.0.1` | Bind de host para WebUIs de admin (*arr, Byparr, Bazarr, Maintainerr, WebUI de qBit). Lo pone `init`. |
| `FLIXBOX_ARR_UI_USER` | `admin` | string | SoT del username de Forms (solo `shared`). Lo aplica `credentials set arr-ui` / `configure --sync-arr-ui` (ADR 0020). |
| `FLIXBOX_ARR_UI_PASSWORD` | *(generado)* | string | SoT del password de Forms; **`configure` sin `--sync-arr-ui` usa API keys, no esto.** |

Servarr no tiene variable de entorno para username/password de Forms — ver [13 — Create *arr login](13-access-profiles.md#create-arr-login-shared) y [ADR 0020](../../adr/0020-operator-credentials-cli.md).

Tras cambiar `FLIXBOX_ACCESS_PROFILE`: `./bin/flixbox up`, `reload` o `configure` (auto-sincroniza keys derivadas; **`configure` también sincroniza Homepage** para que `shared` quite secrets de widgets de admin). Opcionalmente `./bin/flixbox init --non-interactive` para que se generen placeholders de password de UI shared si están vacíos. Luego aplica Forms con `credentials set arr-ui`.

<a id="file-ownership-and-timezone"></a>
## Propiedad de archivos y zona horaria

| Variable | Valor por defecto | Notas |
| --- | --- | --- |
| `PUID` | `1000` (Linux) / `id -u` (macOS vía `init`) | UID para contenedores estilo linuxserver y propiedad de archivos. |
| `PGID` | `1000` (Linux) / `id -g` (macOS vía `init`) | GID; debe coincidir con el grupo dueño de `DATA_DIR`. |
| `UMASK` | `002` | Archivos nuevos escribibles por el grupo (`init` también pone SGID en dirs de data). |
| `TZ` | `UTC` | Zona horaria IANA para todos los contenedores. |

<a id="host-ports"></a>
## Puertos del host

Cambia **solo** si el puerto por defecto ya está ocupado en el host. Los puertos internos de servicio dentro de los contenedores no cambian.

Tras cambiar cualquier `*_PORT` en `.env`:

1. Ejecuta `./bin/flixbox reload` (o `up`) para que Compose vuelva a publicar los puertos y los links de Homepage en `${CONFIG_DIR}/homepage/services.yaml` se sincronicen automáticamente (se conservan widgets y servicios personalizados).
2. Si `up`/`reload` avisan que las **plantillas de Homepage son más nuevas que la config en vivo**, ejecuta `./bin/flixbox homepage refresh` (o `reload --reset-homepage`) para que layout/CSS/icons del repo reemplacen los archivos gestionados en vivo (se escribe un backup con timestamp bajo `${CONFIG_DIR}/homepage.bak.*`).
2. Los download clients de *arr siguen usando puertos **internos** (`8080` para qBit) — ver [URLs del download client](#download-client-urls-arr-ui).

| Variable | Valor por defecto | Servicio |
| --- | --- | --- |
| `HOMEPAGE_PORT` | `3000` | Homepage |
| `SEERR_PORT` | `5055` | Seerr |
| `JELLYFIN_PORT` | `8096` | Jellyfin |
| `QBITTORRENT_PORT` | `8080` | WebUI de qBittorrent (publicado en Gluetun en modo VPN). El navegador usa este puerto; *arr usan el **8080** interno. Si lo remapeas, ver [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) (Host header vs publish de Docker). |
| `QBITTORRENT_BT_PORT` | `6881` | Puerto de escucha BitTorrent |
| `FLIXBOX_QBIT_FORCE_PATHS` | `false` | Si es `true`, las rutas de guardado de qBit se resetean a `/data/torrents/...` en cada arranque. Por defecto: solo corrige rutas faltantes o de linuxserver `/downloads/` ([First-run §2c](05-first-run.md#2c-download-paths-automatic)). |
| `PROWLARR_PORT` | `9696` | Prowlarr |
| `BYPARR_PORT` | `8191` | Byparr |
| `RADARR_PORT` | `7878` | Radarr |
| `SONARR_PORT` | `8989` | Sonarr |
| `BAZARR_PORT` | `6767` | Bazarr |
| `MAINTAINERR_PORT` | `6246` | Maintainerr |
| `PLEX_PORT` | `32400` | Plex (perfil `plex`) |
| `CADDY_HTTP_PORT` | `80` | Caddy HTTP (perfil `proxy`) |
| `CADDY_HTTPS_PORT` | `443` | Caddy HTTPS (perfil `proxy`) |

<a id="optional-compose-profiles"></a>
## Perfiles Compose opcionales

| Variable | Valores | Efecto |
| --- | --- | --- |
| `COMPOSE_PROFILES` | `plex`, `proxy`, `recyclarr` (separados por comas) | Habilita servicios opcionales. `docker-socket-proxy` siempre va con Homepage. |

Alternativa sin editar `.env`:

```bash
./bin/flixbox up plex proxy
docker compose --profile recyclarr run --rm recyclarr sync
```

| Perfil | Servicio |
| --- | --- |
| `plex` | Servidor de medios Plex |
| `proxy` | Reverse proxy Caddy |
| `recyclarr` | Sync de TRaSH Guides (one-shot vía `run`) |

`docker-socket-proxy` siempre corre con Homepage (no es un perfil — [ADR 0022](../../adr/0022-operator-footgun-remediations.md)).

<a id="credentials-and-api-keys"></a>
## Credenciales y API keys

<a id="credentials-and-api-keys"></a>

Flixbox usa **cinco tipos de credenciales** para el cableado entre apps (más cuentas de tracker por indexer en Prowlarr). No son intercambiables: cada consumidor espera la que se lista abajo.

| Credencial | La usa | Fuente de verdad | Notas |
| --- | --- | --- | --- |
| **Login WebUI** de qBittorrent (username + password) | Tú (navegador), **Decluttarr**, opcionalmente *arr | **`.env`** (`QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD`) | `init` genera un password; `configure` lo aplica cuando qBit aún tiene uno temporal. Decluttarr **no** usa la API key de qBit. |
| **API key** de qBittorrent | **Radarr**, **Sonarr** (download client) | Config de qBit (la lee `configure`); también WebUI → Options → Web UI → API access | No se guarda en `.env`. `configure` la empuja a *arr. |
| API key de **Radarr** | Unpackerr, Decluttarr; también Prowlarr Apps, Seerr, Bazarr, Maintainerr, Recyclarr | `config.xml` de Radarr (sincronizado a `.env` por `configure`) | La misma key en todas partes — ver [Cambios accidentales / intencionales de keys](#accidental--intentional-key-changes). |
| API key de **Sonarr** | Mismo patrón que Radarr | `config.xml` de Sonarr → `.env` vía `configure` | Igual que Radarr. |
| API key de **Jellyfin** | Seerr, Maintainerr | Jellyfin → Dashboard → **API Keys** | Se crea después de que exista la cuenta admin de Jellyfin. |

<a id="runtime-secrets-in-docker"></a>
### Secrets en runtime en Docker

Compose pasa algunas credenciales como **variables de entorno del contenedor** (por ejemplo `QBITTORRENT_PASSWORD`, `RADARR_API_KEY` en Decluttarr). Quien pueda ejecutar `docker inspect` o `docker exec` en el host puede leerlas. Eso es normal en stacks Compose de homelab — limita el acceso al socket de Docker a la cuenta del operador. Las API keys también viven bajo `${CONFIG_DIR}` en archivos de config de las apps; trata los backups de `config/` como `.env`. Ver [ADR 0018](../../adr/0018-runtime-secrets-and-lan-trust.md) y [Access profiles — threat model](13-access-profiles.md#threat-model-homelab).

<a id="accidental-intentional-key-changes"></a>
### Cambios accidentales / intencionales de keys

<a id="accidental--intentional-key-changes"></a>

Cambiar un password o regenerar una API key **solo en una WebUI** no actualiza a todos los consumidores. Usa esta tabla — sobre todo tras un clic accidental en “Regenerate”. Para procedimientos completos de rotación, ver [Credential rotation runbook](15-credential-rotation.md).

| Qué ocurrió | Se rompe | Arreglo |
| --- | --- | --- |
| **Quieres un password nuevo de qBit gestionado por Flixbox** | — | **Rotar:** `./bin/flixbox credentials set qbit --generate` (o `--prompt`). Auth con `.env`/temp actual → aplica nuevo → escribe `.env` → recrea Decluttarr. |
| **Password de qBit** cambiado en la WebUI (copiado a `.env`) | Decluttarr (y *arr si dependen del password) | **Alinear:** `./bin/flixbox configure --sync-qbit-auth` |
| **API key de qBit** regenerada en la WebUI | Download client de *arr (puede seguir “Test OK” vía password mientras la key guardada está obsoleta) | `./bin/flixbox configure` (refresca keys desalineadas) o `./bin/flixbox configure --sync-qbit-auth` para forzar un push completo |
| **Quieres aplicar el password de `.env` sobre qBit** | — | **Solo alinear:** funciona si `configure` aún puede **iniciar sesión** (`.env` ya coincide con la WebUI, **o** password temporal en `docker compose logs qbittorrent`). Para inventar un password nuevo, usa `credentials set qbit`, no solo editar a mano. |
| **API key de Radarr / Sonarr** regenerada en la UI de esa app | `.env`, Decluttarr, Unpackerr, Prowlarr Apps, Bazarr, Seerr; Recyclarr / Maintainerr si ya estaban cableados | `./bin/flixbox configure` (sincroniza `.env` desde `config.xml`, refresca Prowlarr/Bazarr/Seerr, recrea Decluttarr/Unpackerr). Luego: actualiza **Maintainerr** en su UI; edita `${CONFIG_DIR}/recyclarr/recyclarr.yml` si los placeholders ya se habían reemplazado. |
| Perdiste el password de la WebUI de qBit (sin temp en logs) | `configure` / rotate no pueden autenticar | Define un password nuevo en la UI de qBit (o limpia `${CONFIG_DIR}/qbittorrent/`), ponlo en `.env`, luego `--sync-qbit-auth` |

<a id="rotate-vs-align-vs-configure"></a>
#### Rotar vs alinear vs `configure`

| Comando | Uso típico |
| --- | --- |
| `./bin/flixbox credentials set qbit …` | **Rotar** el password de WebUI (viejo → nuevo); escribe `.env` solo después de que qBit acepte el cambio. |
| `./bin/flixbox configure` | Cableado idempotente de first-run; sana API keys de qBit desalineadas en *arr y API keys de *arr desalineadas en Prowlarr/Bazarr/Seerr cuando Test/compare detecta mismatch. |
| `./bin/flixbox configure --sync-qbit-auth` | **Alinear:** fuerza el password de WebUI actual de `.env` sobre qBit, reescribe download clients de *arr, recrea Decluttarr/Unpackerr — cuando `.env` ya coincide con un password con el que se puede iniciar sesión. |
| `./bin/flixbox configure --sync-arr-ui` | **Forzar** `FLIXBOX_ARR_UI_*` sobre Forms de Prowlarr/Radarr/Sonarr (solo `shared` — ADR 0020). |
| `./bin/flixbox credentials show\|set …` | Leer o rotar secrets del operador sin editar `.env` a mano — [Credential rotation](15-credential-rotation.md). |

**Recyclarr** usa API keys de Radarr/Sonarr en `${CONFIG_DIR}/recyclarr/recyclarr.yml` (plantilla copiada por `init`). `configure` solo reemplaza placeholders `REPLACE_*` — no reescribe keys ya guardadas en ese archivo.

El stack **arranca** sin keys de after-first-run. Unpackerr no puede hablar con *arr hasta que `RADARR_API_KEY` y `SONARR_API_KEY` estén definidas. Decluttarr **queda idle** (sin login a qBit) hasta que `QBITTORRENT_USERNAME` y `QBITTORRENT_PASSWORD` estén definidos — ver [ADR 0008](../../adr/0008-maintenance-decluttarr-maintainerr.md). Tras editar a mano las creds de **qBit** en `.env` para que coincidan con la WebUI, usa `configure --sync-qbit-auth`. Para cambiar el password que gestiona Flixbox, prefiere `credentials set qbit`. Tras editar solo `RADARR_API_KEY` / `SONARR_API_KEY`, `configure` o `./bin/flixbox reload` basta para los consumidores de Compose.

<a id="env-variables-after-first-run"></a>
### Variables de `.env` (después del first-run)

| Variable | Cuándo se requiere | Fuente |
| --- | --- | --- |
| `RADARR_API_KEY` | Unpackerr, Decluttarr | Radarr → Settings → General |
| `SONARR_API_KEY` | Unpackerr, Decluttarr | Sonarr → Settings → General |
| `QBITTORRENT_USERNAME` | Decluttarr (una vez activa la auth de WebUI de qBit) | Login de WebUI de qBittorrent |
| `QBITTORRENT_PASSWORD` | Decluttarr (una vez activa la auth de WebUI de qBit) | Login de WebUI de qBittorrent |

<a id="app-to-app-connections"></a>
### Conexiones app-a-app

La mayoría de las apps de Flixbox hablan por la red Docker (`flixbox_net`). Solo **Unpackerr**, **Decluttarr** y **Gluetun** leen auth desde `.env`; el resto guarda conexiones en su propia UI o archivo de config.

| App | Se conecta a | Credencial | Dónde configurar |
| --- | --- | --- | --- |
| **Prowlarr** | Radarr, Sonarr | **API key** de cada *arr | **`configure`** (fallback UI: Settings → Apps) — [First-run §1](05-first-run.md#1-prowlarr--byparr) |
| **Prowlarr** | Indexers (trackers) | Login/API por indexer | **Manual** — Prowlarr → Indexers (no en `.env`) |
| **Prowlarr** | Byparr | *(ninguna)* | **`configure`** cuando Byparr está en marcha — host `byparr:8191` |
| **Radarr / Sonarr** | qBittorrent | **API key** de qBit | **`configure`** (fallback UI: Download Clients) — [First-run §3](05-first-run.md#3-radarr--sonarr--hygiene) |
| **Seerr** | Jellyfin, Radarr, Sonarr | **API key** de cada servicio | **`configure`** (fallback UI si falla la automatización) — [First-run §4](05-first-run.md#4-bazarr--jellyfin--seerr) |
| **Bazarr** | Radarr, Sonarr | **API keys** de *arr | **`configure`** (fallback UI) — [First-run §4](05-first-run.md#4-bazarr--jellyfin--seerr) |
| **Maintainerr** | Jellyfin, Radarr, Sonarr | **API key** de cada servicio | **Manual** en la UI de Maintainerr — [First-run §5](05-first-run.md#5-recyclarr--maintainerr--homepage) |
| **Recyclarr** | Radarr, Sonarr | **API keys** de *arr | `${CONFIG_DIR}/recyclarr/recyclarr.yml` |
| **Unpackerr** | Radarr, Sonarr | **API keys** de *arr | `.env` (`RADARR_API_KEY`, `SONARR_API_KEY`) |
| **Decluttarr** | Radarr, Sonarr, qBit | API keys de *arr + **user/pass** de qBit | `.env` — tabla de arriba |
| **Jellyfin** | *(servido a usuarios)* | Cuenta admin + usuarios opcionales | Wizard de first-run de Jellyfin |
| **Seerr** | *(usuarios del portal de pedidos)* | Cuentas de login de Seerr | UI de Seerr (separadas de los usuarios de Jellyfin) |
| **Homepage** | Links del dashboard + widgets opcionales | **`trusted`:** puede sincronizar user/pass de qBit y API keys de *arr en bloques de widgets. **`shared`:** los widgets de admin (qBit/*arr/Bazarr/Maintainerr/Byparr) se **eliminan**; los widgets de Jellyfin (y Seerr si hay key) aún pueden sincronizarse. | `${CONFIG_DIR}/homepage/services.yaml` — la UI de Homepage no tiene login; no la expongas a WAN ([§13](13-access-profiles.md#threat-model-homelab)) |
| **Byparr** | *(proxy CF)* | *(ninguna)* | Sin login; no expuesto más allá de tu LAN salvo que lo publiques |

`SEERR_API_KEY` es **opcional** en `.env` (ver `.env.example`). Compose y `configure` **no** la usan — solo `homepage-sync` para el widget de Seerr en el dashboard. Copia la key desde Seerr → Settings → API. Si no está definida, Seerr sigue funcionando; el widget de Homepage queda muted. `JELLYFIN_API_KEY` es similar para Homepage (y también puede escribirla `configure` cuando la descubre). `PROWLARR_API_KEY` **sí** la genera `init` y la usan Compose / `configure`.

<a id="decluttarr-tuning"></a>
## Ajuste de Decluttarr

| Variable | Valor por defecto | Notas |
| --- | --- | --- |
| `DECLUTTARR_QBIT_URL` | `http://qbittorrent:8080` | Siempre (ADR 0014). La pone/normaliza `flixbox init`. |
| `DECLUTTARR_REMOVE_TIMER` | `15` | Minutos entre comprobaciones de cola. |
| `DECLUTTARR_STRIKES` | `12` | Strikes antes de eliminar stalled (y slow, si está habilitado). Gracia ≈ timer × strikes (~3h). |
| `DECLUTTARR_REMOVE_SLOW` | `False` | Eliminación “slow” por KiB/s absolutos. Déjala off bajo VPN; la CLI avisa si está on en modo VPN. |

Para reactivar slow con un piso personalizado, pon `DECLUTTARR_REMOVE_SLOW=True` (min_speed default de Decluttarr) o sobrescribe `REMOVE_SLOW` con un dict YAML en `compose/optimization.yml` (ver [09-hygiene-defaults.md](../../09-hygiene-defaults.md)). El tag protegido `flixbox-keep` se define en Compose.

<a id="app-specific"></a>
## Específico por app

| Variable | Valor por defecto | Notas |
| --- | --- | --- |
| `FLIXBOX_PUBLIC_HOST` | (vacío) | IP LAN o DNS (sin scheme/port). En `up`/`reload`/`configure`: fija hrefs de Jellyfin/Seerr en Homepage; añade `host:HOMEPAGE_PORT` a `HOMEPAGE_ALLOWED_HOSTS`; rellena `JELLYFIN_PUBLISHED_URL` vacío. Ver [Access profiles — Homepage](13-access-profiles.md#homepage-links-from-phones--tvs). |
| `HOMEPAGE_ALLOWED_HOSTS` | `localhost:3000,127.0.0.1:3000` | Allowlist de Host de Homepage. Se auto-extiende desde `FLIXBOX_PUBLIC_HOST` cuando está definido. Aún puedes añadir hosts extra (DNS de Caddy, etc.). |
| `JELLYFIN_PUBLISHED_URL` | (vacío) | Published Server URL de Jellyfin para streams. Se auto-define desde `FLIXBOX_PUBLIC_HOST` cuando está vacío; ponlo a mano para Caddy HTTPS — [Troubleshooting — Jellyfin media source](10-troubleshooting.md). |
| `JELLYFIN_DOMAIN` | `jellyfin.local` | Dominio/host personalizado para reverse proxy Caddy (perfil `proxy`). |
| `SEERR_DOMAIN` | `requests.local` | Dominio/host personalizado para Seerr en Caddy (perfil `proxy`). |
| `HOMEPAGE_DOMAIN` | `home.local` | Dominio/host personalizado para Homepage en Caddy (perfil `proxy`). |
| `SEERR_LOG_LEVEL` | `info` | `error`, `warn`, `info`, `debug`. |
| `PLEX_CLAIM` | (vacío) | Token de claim de un solo uso desde [plex.tv/claim](https://www.plex.tv/claim/) (perfil `plex`). |

<a id="vpn-only-gluetun"></a>
<a id="vpn-mode-only"></a>
## Solo VPN (Gluetun)

Ignora cuando `FLIXBOX_MODE=direct`. Guía completa: [VPN y Direct](07-vpn-and-direct.md).

**El modo no está en esta tabla** — pon `FLIXBOX_MODE=vpn` y `VPN_ENABLED=true` en la sección **REQUIRED** de `.env` (arriba), luego rellena las variables de abajo. `flixbox init` sincroniza `VPN_ENABLED` y `DECLUTTARR_QBIT_URL`.

| Variable | Valor por defecto | Notas |
| --- | --- | --- |
| `VPN_SERVICE_PROVIDER` | `protonvpn` | Id de proveedor Gluetun, o `custom` para un `.ovpn` montado — ver [gluetun-wiki](https://github.com/qdm12/gluetun-wiki). |
| `VPN_TYPE` | `wireguard` | `wireguard` u `openvpn`. |
| `WIREGUARD_PRIVATE_KEY` | (vacío) | Requerido para proveedores WireGuard. |
| `WIREGUARD_ADDRESSES` | (vacío) | p. ej. `10.x.x.x/32` del proveedor. |
| `SERVER_COUNTRIES` | (vacío) | Filtro opcional de servidores. |
| `SERVER_CITIES` | (vacío) | Filtro opcional de servidores. |
| `SERVER_REGIONS` | (vacío) | Filtro opcional de servidores. |
| `OPENVPN_USER` | (vacío) | Username de OpenVPN (nativo o custom). |
| `OPENVPN_PASSWORD` | (vacío) | Password de OpenVPN. |
| `OPENVPN_CUSTOM_CONFIG` | (vacío) | Ruta en el contenedor a un `.ovpn` custom (p. ej. `/gluetun/custom.conf`). El archivo vive bajo `${CONFIG_DIR}/gluetun/`. Requiere `VPN_SERVICE_PROVIDER=custom`. El `remote` del archivo debe ser una IP, no un hostname. |
| `BLOCK_IPV6` | `on` | Bloquear IPv6 por el túnel (recomendado). |
| `DOT` | `on` | DNS over TLS. |
| `VPN_PORT_FORWARDING` | `off` | Pon `on` solo si el proveedor lo soporta; habilita el bypass de auth localhost de qBit. |
| `FIREWALL_OUTBOUND_SUBNETS` | (vacío) | CIDR de LAN (p. ej. `192.168.1.0/24`) para acceso host/LAN a través de Gluetun. |

Verifica tras arrancar: `./bin/flixbox vpn-test`. Checklist completa de privacidad: [Torrent privacy and security](12-torrent-privacy-and-security.md).

<a id="download-client-urls-arr-ui"></a>
## URLs del download client (UI *arr)

<a id="download-client-urls-arr-ui"></a>

Configura en Radarr/Sonarr (no solo en `.env`):

| Modo | Host del download client | Puerto |
| --- | --- | --- |
| `direct` | `qbittorrent` | `8080` |
| `vpn` | `qbittorrent` | `8080` |

Mismo hostname en ambos modos ([ADR 0014](../../adr/0014-stable-qbit-download-hostname.md) — Gluetun aliasa `qbittorrent` en modo VPN). `DECLUTTARR_QBIT_URL` debe usar `http://qbittorrent:8080`.

## Secrets

- Guarda credenciales solo en `.env` o volúmenes de `${CONFIG_DIR}`.
- Nunca hagas commit de `.env`, keys VPN ni tokens de API a git.
- `.env.example` solo usa placeholders vacíos.
- `init` crea `.env` con modo `600` (solo lectura/escritura del dueño).

<a id="image-tags"></a>
## Tags de imagen

Los módulos Compose fijan tags de versión explícitos ([ADR 0010](../../adr/0010-mit-and-image-tags.md)). Inventario y procedimiento de bump: [14 — Image pins](14-image-pins.md).

<a id="next"></a>
## Siguiente

[VPN y Direct](07-vpn-and-direct.md) · [Configuración first-run](05-first-run.md) · [Higiene](08-hygiene.md)
