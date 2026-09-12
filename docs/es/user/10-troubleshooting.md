# Troubleshooting

**Idiomas:** [English](../../user/10-troubleshooting.md) · Español (esta página)

| Síntoma | Causa probable | Qué probar |
| --- | --- | --- |
| `Cannot connect to the Docker daemon` / `Docker daemon check failed` | Daemon de Docker parado, usuario fuera del grupo `docker`, o `DOCKER_HOST` inválido | Arranca Docker (`sudo systemctl start docker`) y agrega el usuario al grupo (`sudo usermod -aG docker $USER && newgrp docker`). Ver [Acceso al daemon Docker](#acceso-al-daemon-docker) |
| `Unable to set ownership ... Both native chown and Docker alpine helper failed` | El usuario del host carece de `CAP_CHOWN` y no se puede alcanzar el daemon Docker | Ejecuta chown manual: `sudo chown -R ${PUID}:${PGID} "${DATA_DIR}" "${CONFIG_DIR}"`. Si usas Podman, ver [Rutas de almacenamiento y permisos](#rutas-de-almacenamiento-y-permisos) |
| `Host port preflight failed` en `up` / `reload` | Colisión interna en `.env` (puerto duplicado en dos servicios) o puerto ya ocupado por otro proceso del host | Pon puertos únicos en `.env` (p. ej. `QBITTORRENT_PORT=9898`) → `./bin/flixbox reload` — [First-run — conflictos de puerto](05-first-run.md#host-port-conflicts). Los puertos `flixbox-*` existentes se ignoran |
| `Gluetun container not running` durante `configure` | Cambiaste a VPN en `.env` pero el stack nunca se recreó | `./bin/flixbox down && ./bin/flixbox up`, espera a que Gluetun esté healthy, luego `configure` — [Cambio a VPN](07-vpn-and-direct.md#choose-a-mode) |
| Gluetun: `TUN device is not available` / `open /dev/net/tun: no such device` | Desajuste de módulos del kernel del host (común tras upgrade de Manjaro sin reiniciar), o TUN ausente en LXC/VM | `uname -r` debe coincidir con `/lib/modules/$(uname -r)`; reinicia tras upgrade de `linux*`; `sudo modprobe tun`; luego `./bin/flixbox down && ./bin/flixbox up`. LXC: habilita TUN/nest en el CT. Upstream: [Gluetun TUN wiki](https://github.com/qdm12/gluetun-wiki/blob/main/errors/tun.md) |
| `cannot create DATA_DIR at /srv/flixbox/data — cannot write under /srv` | Rutas Linux por defecto; un usuario normal no puede crear `/srv` sin `sudo` | Crea directorios padre + `chown` a tu usuario, o pon rutas personalizadas en `.env` (p. ej. `/data/flixbox/data`) — [Install — Rutas de almacenamiento](04-install.md#storage-paths-and-permissions); vuelve a ejecutar `./bin/flixbox init --non-interactive` |
| `Path validation failed` tras `init`; existe `.env` | Rutas escribibles no definidas antes de `init --non-interactive` | Edita `DATA_DIR` / `CONFIG_DIR` en `.env`, asegúrate de que el padre sea escribible, vuelve a ejecutar `init` (init incompleto — no ejecutes `up` hasta que init tenga éxito) |
| `mkdir: /srv: Read-only file system` en init | Rutas de la plantilla Linux en macOS sin `init` | Ejecuta `./bin/flixbox init --force --non-interactive` o define `DATA_DIR`/`CONFIG_DIR` bajo `$HOME/flixbox/` |
| `Directories missing` en `up` | `init` nunca completó el bootstrap (validación fallida u omitida) | Corrige rutas → `./bin/flixbox init --non-interactive` → verifica que exista `${DATA_DIR}/torrents/incomplete` |
| Imports lentos / el disco se duplica | Montajes partidos; hardlink falló (`EXDEV`) | Un solo padre `${DATA_DIR}:/data`; revisa MergerFS/exFAT |
| Medios ausentes tras mover `DATA_DIR` | *arr / Jellyfin siguen bien pero los datos no están en el mount del host esperado | Sigue [Cambiar rutas](09-operations.md#cambiar-rutas-y-layout-de-almacenamiento); verifica que root folders y libraries usen `/data/media/...` |
| qBit guarda en la carpeta equivocada (`/downloads/`) | Hook no montado en `/custom-cont-init.d` o no recreado | `./bin/flixbox init --non-interactive` luego `docker compose up -d --force-recreate qbittorrent`; o `FLIXBOX_QBIT_FORCE_PATHS=true` — [First-run §2c](05-first-run.md#2c-download-paths-automatic) |
| Radarr/Sonarr qBit **Test** falla (auth) | Password obsoleto tras recrear qBit, o tipo de credencial incorrecto | `docker compose restart qbittorrent` (limpia el ban), luego `./bin/flixbox configure --sync-qbit-auth`. Prefiere **API key** de qBit en *arr (username/password opcional). — [Credenciales](06-configuration.md#credentials-and-api-keys) |
| Decluttarr no puede conectar a qBit | Credenciales `.env` ausentes o incorrectas | Define `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` (login WebUI). Decluttarr **no** usa la API key de qBit. Luego `./bin/flixbox configure --sync-qbit-auth` |
| Decluttarr logs `idle — set QBITTORRENT_…` | Username/password aún no en `.env` (por diseño) | Tras el login WebUI de qBit, pon ambos en `.env` → `./bin/flixbox configure --sync-qbit-auth` (o `docker compose up -d --force-recreate decluttarr`) — [First-run §3c](05-first-run.md#3c-hygiene-credentials-decluttarr--unpackerr) |
| Decluttarr falta `/flixbox-entrypoint.sh` | Entrypoint no copiado | `./bin/flixbox init --non-interactive` luego recrea Decluttarr |
| Decluttarr / *arr `403` / “IP has been banned” | Logins fallidos antes del whitelist de la subred Docker, o password *arr obsoleto tras recrear qBit | `docker compose restart qbittorrent` (limpia el ban en memoria) → `./bin/flixbox configure --sync-qbit-auth` → confirma en logs de Decluttarr `OK \| qBittorrent`. El whitelist es solo `172.30.42.0/24` — [ADR 0008](../../adr/0008-maintenance-decluttarr-maintainerr.md) |
| Cambiaste password (o API key) de qBit solo en la WebUI | `.env` / Decluttarr / *arr aún tienen valores viejos | Password: alinea `.env`, luego `--sync-qbit-auth`. Solo API key: un `configure` normal suele bastar — [Credenciales](06-configuration.md#accidental--intentional-key-changes) |
| Seerr en restart-loop / `unhealthy` en el primer arranque | Directorio de config no escribible por UID **1000** (Seerr ignora `PUID`) | `./bin/flixbox init --non-interactive` (define ownership; falla cerrado si no puede). Manual: `docker run --rm -v "${CONFIG_DIR}/seerr:/data" alpine chown -R 1000:1000 /data` luego recrea Seerr |
| Radarr/Sonarr: no se puede agregar root folder `/data/media/...` | `DATA_DIR` no escribible por `PUID` (común en CI / hosts sin sudo) | Vuelve a ejecutar `./bin/flixbox init --non-interactive` (helper alpine chown), o `chown -R ${PUID}:${PGID} "${DATA_DIR}"` |
| Regeneraste la API key de Radarr/Sonarr en la UI de esa app | Prowlarr/Seerr/Decluttarr/Unpackerr pueden seguir con la key vieja | `./bin/flixbox configure`; luego actualiza Maintainerr + YAML de Recyclarr si hace falta — [Credenciales](06-configuration.md#accidental--intentional-key-changes) |
| Banner *arr: Connection refused a qBit, pero **Test** está OK | El health check corrió mientras la WebUI de qBit aún arrancaba (o status obsoleto) | System → Tasks → **Check Health**, o espera al siguiente ciclo. Con el Compose actual, *arr espera a que qBit esté `healthy` en arranques nuevos |
| Los servicios no pueden unirse a `flixbox_net` tras un upgrade | Bridge viejo sin `172.30.42.0/24` | `./bin/flixbox down`, `docker network rm flixbox_net` si aún existe, luego `./bin/flixbox up` |
| Radarr no alcanza qBit (VPN) | Falta el alias `qbittorrent` de Gluetun (pre–ADR 0014) o Gluetun unhealthy | Host **`qbittorrent`**; `compose up -d gluetun` tras el upgrade |
| qBit en crash-loop al arrancar (VPN) | Arrancó antes de que Gluetun estuviera healthy | Healthcheck `depends_on`; reinicia qBit cuando Gluetun esté healthy |
| WebUI de qBit muerta tras recrear Gluetun | qBit varado en netns viejo (`network_mode: service:gluetun`) | `docker compose up -d qbittorrent` o `./bin/flixbox reload` — [Caídas de VPN](07-vpn-and-direct.md#what-happens-when-the-vpn-drops) |
| El test VPN muestra la IP de casa | No estás en modo VPN / túnel caído | Revisa `VPN_ENABLED`, logs de Gluetun, `vpn-test` |
| Homepage: `Host validation failed` desde un teléfono/PC LAN | `HOMEPAGE_ALLOWED_HOSTS` solo lista localhost | Define `FLIXBOX_PUBLIC_HOST` luego `./bin/flixbox reload` (extiende la allowlist sola) — o agrega `LAN_IP:3000` a mano — [§13 Enlaces Homepage](13-access-profiles.md#homepage-links-from-phones--tvs) |
| Enlaces Homepage de Jellyfin/Seerr abren `localhost` en otro dispositivo | `FLIXBOX_PUBLIC_HOST` sin definir | Define `FLIXBOX_PUBLIC_HOST`, luego `./bin/flixbox reload` — [§13](13-access-profiles.md#homepage-links-from-phones--tvs) |
| Enlaces admin de Homepage bajo `shared` | En el host: `http://127.0.0.1:<port>` + Forms. En LAN: puertos no publicados | Abre Homepage en el servidor (o túnel SSH); `credentials set arr-ui` — [§13](13-access-profiles.md) |
| Homepage: `Failed to load services.yaml` tras cambiar a `shared` | `homepage-sync` antes dejaba de saltar widgets admin en líneas anidadas `- level:` / `- field:`, dejando YAML huérfano | Corregido en `scripts/lib/homepage-sync.py`. Reparar: `cp templates/homepage/services.yaml "${CONFIG_DIR}/homepage/services.yaml"` luego `./bin/flixbox reload` (o `homepage-sync` vía `up`/`configure`). Haz backup del archivo roto primero. |
| El enlace Homepage va al puerto equivocado tras cambio en `.env` | Puerto custom aún no sincronizado a `services.yaml` | Ejecuta `./bin/flixbox reload` para sincronizar puertos desde `.env` preservando tus widgets custom, o edita `${CONFIG_DIR}/homepage/services.yaml` |
| qBit WebUI `Unauthorized` tras intentos de login | Aún no has iniciado sesión | Navegador → `http://localhost:<QBITTORRENT_PORT>`; usuario `admin`; password temporal en `docker compose logs qbittorrent` |
| qBit WebUI `Unauthorized` plano (sin formulario de login) | qBittorrent 5.x rechaza `Host: localhost:<mapped-port>` cuando el WebUI interno es 8080; Preferences pueden haberse borrado al arrancar | El servicio de contrato WebUI en runtime reaplica HostHeader off ([ADR 0019](../../adr/0019-qbit-webui-runtime-contract.md)). Vuelve a ejecutar `./bin/flixbox init --non-interactive` + recrea qBit si falta el servicio; luego `configure --sync-qbit-auth` — [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| Auth qBit / Decluttarr falla justo tras Direct↔VPN | Password temporal WebUI o sync `.env` obsoleto tras recreate | Espera a que qBit esté healthy → `./bin/flixbox configure --sync-qbit-auth`. Si hay ban: `./bin/flixbox restart qbittorrent` luego configure de nuevo — [Guía VPN](07-vpn-and-direct.md) |
| qBit `Unauthorized` persiste tras experimentos de puerto | `qBittorrent.conf` obsoleto en el volumen de config | Para el stack; elimina `${CONFIG_DIR}/qbittorrent/qBittorrent/`; `./bin/flixbox up` (ver [First-run §2e](05-first-run.md#2e-custom-host-ports-and-stale-config)) |
| Cambiaste `WEBUI_PORT` + mapeo estilo `8420:8420` | Desajuste puerto interno/listen | Prefiere el default Flixbox: solo `QBITTORRENT_PORT:8080`; mantén `WEBUI_PORT=8080` en Compose |
| Indexers fallan Cloudflare (`blocked by CloudFlare Protection`) | Proxy ausente, host incorrecto, o tags no enlazados | Crea proxy FlareSolverr → host `byparr`, puerto `8191`; mismo **tag** en proxy e indexer; ver [First-run §1](05-first-run.md#1-prowlarr--byparr) |
| Test de indexer OK en Prowlarr pero falta en Radarr/Sonarr | Tag en el indexer pero no en la app | **Settings → Apps** → agrega el mismo tag a Radarr/Sonarr, o quita tags |
| Logs de Byparr muestran challenge luego `200 OK` | Normal en indexers CF | Sin acción; si la búsqueda sigue fallando, prueba otro indexer o revisa `./bin/flixbox logs byparr` |
| Jellyfin: “No compatible streams” / “Could not find a valid media source” (UI carga, play falla) | `network.xml` **Bind to local network address** en `::` (IPv6 any) — Jellyfin anuncia URLs de stream `::1`; rompe en localhost **y** LAN | Vuelve a ejecutar `./bin/flixbox configure` (limpia un bind `::` solo y reinicia Jellyfin). Manual: Dashboard → Networking → limpia bind (déjalo vacío); opcional Published Server URL `http://<host>:8096`. Limpiar bind **no** cambia la exposición LAN — Compose sigue publicando `:8096` ([§13](13-access-profiles.md)). |
| Subtítulos externos `.srt` de Jellyfin ausentes en el player | Library no reescaneada tras descarga de Bazarr, o idioma de subtítulos preferido sin definir | Refresh/scan del ítem; define idioma de subtítulos preferido en el usuario (o library). El filename debe compartir el basename del video (`video.es-MX.srt` / `video.spa.srt`). |
| Jellyfin muere en transcode 4K | `/dev/shm` pequeño | Monta `/dev/shm` del host para transcode |
| DB *arr corrupta tras reboot | Timeout de stop corto | `stop_grace_period: 60s`; SSD local para config |
| Rarezas de config en ruta NAS | SQLite sobre NFS/SMB | Mueve `${CONFIG_DIR}` a disco local |
| Maintainerr borró demasiado | Reglas demasiado agresivas | Ajusta umbrales; usa lista Keep; revisa Leaving Soon primero |
| Decluttarr quita un torrent deseado | Descarga VPN lenta chocó el piso absoluto KiB/s, o realmente stalled sin tag de protección | Mantén `DECLUTTARR_REMOVE_SLOW=False` (default); agrega `flixbox-keep`; sube `DECLUTTARR_STRIKES` / timer — [Higiene](08-hygiene.md) |
| Permission denied en media | Desajuste UID/GID | Alinea `PUID`/`PGID`; SGID en dirs de data |
| `./bin/flixbox configure --dry-run` falla con containers not running | El mismo assert de core-stack que configure en vivo | Arranca el stack: `./bin/flixbox up` — dry-run previsualiza el cableado pero no omite el requisito de stack en ejecución |
| `./bin/flixbox configure --dry-run` esperaba cero efectos secundarios | Entry/preflight/módulos deben respetar `$DRY_RUN` | Sin escrituras a `.env`, sin recreate, sin mutaciones API — solo líneas `[dry-run]` (ADR 0016) |
| `./bin/flixbox configure` falla en el primer arranque (API no lista) | *arr/Jellyfin aún inicializando SQLite | Espera hasta **15 min** (`CONFIGURE_PREFLIGHT_TIMEOUT=900`); las fases están limitadas por el presupuesto restante — típico 1–3 min — [First-run §0](05-first-run.md#0-script-assisted-wiring-recommended) |
| Errores de auth en `configure` / *arr tras borrar `${CONFIG_DIR}` | API keys de `.env` obsoletas frente al `config.xml` nuevo del contenedor | Vuelve a ejecutar `./bin/flixbox configure` (sincroniza keys desde el contenedor). O `./bin/flixbox init --non-interactive` si las keys estaban vacías |
| `Invalid FLIXBOX_ACCESS_PROFILE=…` en `up` / `configure` | Typo en `.env` | Pon `trusted` o `shared`; ejecuta `./bin/flixbox init --non-interactive` |
| Warn: Access profile out of sync (luego auto-sync + recreate de servicios admin) | Cambiaste `FLIXBOX_ACCESS_PROFILE` o keys derivadas bind/auth vacías | `up`/`reload`/`configure` sincronizan keys derivadas y force-recreate servicios bound a admin — [§13](13-access-profiles.md) |
| Perfil `shared`: login *arr falla con password de `.env` | Forms no aplicados o nunca creados | `./bin/flixbox configure --sync-arr-ui` o `credentials set arr-ui`; fallback: crea cuenta en cada UI *arr — [§13](13-access-profiles.md#create-arr-login-shared) |
| Perfil `shared`: no se puede abrir Radarr desde el teléfono en Wi‑Fi | Puertos admin bound a `127.0.0.1` | Esperado — usa el navegador del host o túnel SSH; Jellyfin/Seerr siguen en LAN — [§13](13-access-profiles.md) |
| Perfil `trusted` pero *arr pide login desde LAN (IPv6) | El bypass RFC1918 de Servarr no cubre todos los clientes LAN IPv6 | Usa `shared`, o accede a *arr desde IPv4 / localhost |
| Scripts fallan con errores `\r` | Fin de línea CRLF en clone Windows | Asegura LF vía `.gitattributes` |

<a id="docker-daemon-access"></a>
## Acceso al daemon Docker

Flixbox requiere acceso al socket del daemon Docker (`/var/run/docker.sock` o `DOCKER_HOST`) sin `sudo`.

1. **Verifica el estado del daemon:**
   ```bash
   sudo systemctl status docker
   sudo systemctl enable --now docker
   ```
2. **Concede acceso sin root:**
   ```bash
   sudo usermod -aG docker "$USER"
   newgrp docker # or log out and log back in
   ```
3. **Verifica el acceso:**
   ```bash
   docker info
   ```
   Si `docker info` funciona sin `sudo`, los comandos `./bin/flixbox` procederán con normalidad.

**Homepage / socket-proxy:** Compose monta `/var/run/docker.sock` solo en `docker-socket-proxy` (Homepage usa `docker-socket-proxy:2375` en `flixbox_net`). La ruta de primera clase es Docker Engine rootful. Docker rootless o un `DOCKER_HOST` custom pueden exigir adaptar ese mount — ver [ADR 0007](../../adr/0007-platform-support-tiers.md) y [ADR 0022](../../adr/0022-operator-footgun-remediations.md).

<a id="storage-paths-and-permissions"></a>
## Rutas de almacenamiento y permisos

Cuando Flixbox inicializa o copia plantillas de configuración, fija el ownership de runtime a `PUID:PGID` (con la config de Seerr en UID `1000`). Si los permisos del host impiden escrituras del lado host, Flixbox usa un helper efímero `alpine` para reclamar y restaurar ownership.

Si fallan tanto el `chown` nativo como el helper Alpine (p. ej. daemon Docker caído o permisos rootless distintos):

1. **Corrige ownership a mano con `sudo`:**
   ```bash
   # Replace with your actual paths from .env
   sudo chown -R 1000:1000 /srv/flixbox/data /srv/flixbox/config
   sudo chown -R 1000:1000 /srv/flixbox/config/seerr
   ```
2. **Entornos Podman rootless:**
   En Podman rootless sin daemon Docker de sistema, usa `podman unshare` para modificar ownership dentro del user namespace:
   ```bash
   podman unshare chown -R 1000:1000 /srv/flixbox/data
   podman unshare chown -R 1000:1000 /srv/flixbox/config
   ```
3. **Alternativa con permisos de grupo compartido:**
   Si prefieres no cambiar ownership una y otra vez, pon el bit SGID y permisos de escritura de grupo:
   ```bash
   sudo chmod -R 2775 /srv/flixbox/data /srv/flixbox/config
   ```

<a id="still-stuck"></a>
## ¿Sigues atascado?

1. `./bin/flixbox status` y logs del servicio  
2. Confirma el modo (VPN vs Direct) y el host del cliente de descarga  
3. Relee [Cómo funciona](02-how-it-works.md)  
4. Profundidad de ingeniería: [operations risks](../../07-operations-risks.md)

<a id="contributing-bugs"></a>
## Contribuir / bugs

Usa el issue tracker de GitHub cuando el repositorio sea público. Incluye versión/commit de Flixbox, SO, VPN o Direct, y logs redactados (sin API keys).
