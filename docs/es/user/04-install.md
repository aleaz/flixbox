<a id="install"></a>
# Instalación

**Idiomas:** [English](../../user/04-install.md) · Español (esta página)

<a id="at-a-glance"></a>
## De un vistazo

Arranca Flixbox con cuatro comandos: clone → `init` → `up` → `configure`. Las rutas viven en **`.env`** (no en `export` del shell).

- **Resultado:** Contenedores principales sanos; apps cableadas por `configure`
- **Antes de empezar:** Docker Compose v2, `DATA_DIR` / `CONFIG_DIR` escribibles, [piso 4 GB RAM / 8 GB cómodo](03-requirements.md)
- **Tiempo:** ~15 minutos hasta el primer `status` sano

> **Estado de implementación:** El stack Compose completo + la CLI `bin/flixbox` están **Implemented**. Perfiles opcionales: `plex`, `proxy`, `recyclarr`. `docker-socket-proxy` siempre corre con Homepage.

## Bootstrap

Flixbox lee las rutas desde **`.env`** (no desde `export` del shell). Con `--non-interactive`, `init` **no** se detiene para ediciones — define `DATA_DIR` / `CONFIG_DIR` escribibles **antes** de que `init` termine, o edita `.env` y vuelve a ejecutar `init` si falló la validación.

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Edit .env: DATA_DIR, CONFIG_DIR, FLIXBOX_MODE, TZ, optional FLIXBOX_ACCESS_PROFILE
# (trusted default; shared on roommate Wi‑Fi — docs/user/13-access-profiles.md)
./bin/flixbox init --non-interactive   # creates dirs, templates, API keys/passwords; .env mode 600
./bin/flixbox up
./bin/flixbox status
./bin/flixbox configure   # idempotent wiring; then add Prowlarr indexers
```

Alternativa interactiva (se detiene tras crear `.env` para que edites las rutas en otra terminal):

```bash
./bin/flixbox init
# Press Enter only after DATA_DIR and CONFIG_DIR are writable paths in .env
```

Prefiere `./bin/flixbox init` + `up` sobre un `docker compose up` pelado. Compose crudo salta la sync del perfil de acceso, la generación de secretos y la validación de rutas.

> [!TIP]
> **Acceso al daemon Docker en Linux:** Asegúrate de que tu usuario pertenezca al grupo `docker` para que los comandos `./bin/flixbox` corran sin `sudo`:
> ```bash
> sudo usermod -aG docker "$USER"
> newgrp docker # or log out and back in
> ```

<a id="storage-paths-and-permissions"></a>
### Rutas de almacenamiento y permisos

En Linux, `init` usa por defecto **`/srv/flixbox/data`** y **`/srv/flixbox/config`** (FHS). La mayoría de instalaciones de escritorio necesitan que **crees el árbol padre y te hagas dueño** antes de `init`, o elijas otra ruta en `.env`.

**Requisitos:**

- Solo **rutas absolutas** (p. ej. `/data/flixbox/data`, no `~/flixbox/data` en `.env`).
- **`DATA_DIR`:** un filesystem local para torrents + media (hardlinks). No NFS/SMB/exFAT; no WSL `/mnt/c/...`.
- **`CONFIG_DIR`:** SSD/NVMe local (bases SQLite de las apps).
- **`PUID` / `PGID`:** deben coincidir con el usuario/grupo dueño de ambos árboles (por defecto `1000` en Linux).

`init` valida que las rutas sean escribibles (o creables bajo un padre escribible). Si la validación falla, **`.env` puede existir pero init no terminó** — corrige las rutas en `.env` y vuelve a ejecutar `./bin/flixbox init --non-interactive` (no hace falta borrar `.env`).

**Opción A — ruta personalizada (común en escritorios Manjaro/Ubuntu):**

```bash
sudo mkdir -p /data/flixbox/data /data/flixbox/config
sudo chown -R "$(id -u):$(id -g)" /data/flixbox

cp .env.example .env
# Set in .env:
#   DATA_DIR=/data/flixbox/data
#   CONFIG_DIR=/data/flixbox/config
./bin/flixbox init --non-interactive
```

**Opción B — FHS `/srv` (servidor o ya usas `/srv`):**

```bash
sudo mkdir -p /srv/flixbox/data /srv/flixbox/config
sudo chown -R "$(id -u):$(id -g)" /srv/flixbox

cp .env.example .env
# Defaults already point at /srv/flixbox/…
./bin/flixbox init --non-interactive
```

**macOS (Docker Desktop o OrbStack):** `init` reescribe las rutas a `$HOME/flixbox/{data,config}` y define `PUID`/`PGID` desde tu usuario — sin `sudo` para las rutas. OrbStack es el runtime macOS recomendado para desarrollo de Flixbox (bind mounts rápidos, compatible con Compose v2). Usa Linux para smoke de release y verificación de hardlinks.

Tras un init exitoso, `bootstrap-dirs.sh` crea `torrents/` y `media/` bajo `DATA_DIR` y aplica SGID para que los archivos escribibles por grupo coincidan con `UMASK=002`.

Ver también: [Configuration — paths](06-configuration.md#required-before-first-up), [Troubleshooting](10-troubleshooting.md).

<a id="modes"></a>
### Modos

| `FLIXBOX_MODE` | Cliente de descarga para *arr / Decluttarr |
| --- | --- |
| `direct` o `vpn` | `http://qbittorrent:8080` (VPN: alias en Gluetun — ADR 0014) |

VPN: completa los secretos de Gluetun en `.env`, luego `./scripts/vpn-test.sh` o `./bin/flixbox vpn-test`.

<a id="qbittorrent-paths-and-ports"></a>
### Rutas y puertos de qBittorrent

- WebUI del host por defecto: puerto `8080` (`QBITTORRENT_PORT` en `.env`)
- Dentro de Docker, la WebUI se queda en el puerto **8080**; *arr siempre usan el host **`qbittorrent`** (ADR 0014).
- Ejemplo de puerto de host personalizado: `QBITTORRENT_PORT=9898` → navegador `http://localhost:9898`, *arr siguen en `8080`
- Password del primer arranque: desde `.env` `QBITTORRENT_*` tras init (o `docker compose logs qbittorrent` para el temporal)
- Port-forward VPN: activa **Bypass authentication for clients on localhost**
- Problemas de HostHeader / puerto remapado: [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x)

<a id="optional-profiles"></a>
### Perfiles opcionales

```bash
./bin/flixbox up plex proxy
# COMPOSE_PROFILES=plex,proxy in .env also works
```

<a id="recyclarr-sync"></a>
### Sync de Recyclarr

```bash
docker compose --profile recyclarr run --rm recyclarr sync
```

<a id="default-ports"></a>
## Puertos por defecto

| Servicio | Puerto |
| --- | --- |
| Homepage | 3000 |
| Seerr | 5055 |
| Jellyfin | 8096 |
| qBittorrent | 8080 |
| Prowlarr | 9696 |
| Byparr | 8191 |
| Radarr | 7878 |
| Sonarr | 8989 |
| Bazarr | 6767 |
| Maintainerr | 6246 |
| Caddy | 80/443 (perfil `proxy`) |

<a id="verify"></a>
## Verificar

**Esperado:** `./bin/flixbox status` muestra los servicios principales arriba; Homepage abre en `http://localhost:3000`.

<a id="if-it-fails"></a>
## Si falla

| Síntoma | Empieza aquí |
| --- | --- |
| Rutas no escribibles / init incompleto | [Rutas de almacenamiento](#rutas-de-almacenamiento-y-permisos) · [Troubleshooting](10-troubleshooting.md) |
| Puerto del host ya en uso | [First-run — port conflicts](05-first-run.md#host-port-conflicts) |
| Docker permission denied | [Troubleshooting — Docker](10-troubleshooting.md#docker-daemon-access) |

<a id="next"></a>
## Siguiente

[First-run setup](05-first-run.md) — `./bin/flixbox configure`, luego agrega indexers.  
[Quick reference](REFERENCE.md) — puertos, URLs, CLI.
