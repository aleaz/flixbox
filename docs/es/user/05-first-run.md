<a id="first-run-setup"></a>
# Configuración first-run

**Idiomas:** [English](../../user/05-first-run.md) · Español (esta página)

<a id="at-a-glance"></a>
## De un vistazo

Haz esto **una vez** después de `./bin/flixbox init` y `./bin/flixbox up`.

- **Resultado:** Apps cableadas; ≥1 indexer; la ruta de pedidos funciona  
- **Tiempo:** ~10–15 minutos con `./bin/flixbox configure` (sobre todo agregar indexers); más si cableas todo a mano  
- **Sigue siendo manual:** indexers de Prowlarr; reglas de Maintainerr; Recyclarr / Caddy opcionales  

<a id="progress"></a>
## Progreso

- [ ] `./bin/flixbox init` (genera API keys + passwords en `.env`)
- [ ] `./bin/flixbox up` (modo VPN: espera hasta que Gluetun esté healthy)
- [ ] `./bin/flixbox configure` (o `--dry-run` primero)
- [ ] **Solo perfil `shared`:** aplica Forms con `./bin/flixbox credentials set arr-ui --generate` (o `configure --sync-arr-ui`) — [§13 — Crear login *arr](13-access-profiles.md#create-arr-login-shared)
- [ ] Agrega indexers en Prowlarr (tag `cf` en indexers con Cloudflare)
- [ ] Opcional: reglas de Maintainerr, sync de Recyclarr, Caddy

Hoja de consulta: [Referencia rápida](REFERENCE.md).

---

<a id="0-script-assisted-wiring-recommended"></a>
## 0. Cableado asistido por script (recomendado)

<a id="0-script-assisted-wiring-recommended"></a>

```bash
./bin/flixbox configure
./bin/flixbox configure --dry-run
./bin/flixbox configure --sync-qbit-auth   # after changing qBit password — see [Credentials](06-configuration.md#accidental--intentional-key-changes)
```

En el first-run justo después de `up`, el script **espera y reintenta** (por defecto **15 minutos** en total, heartbeats cada 10s) antes de cablear. Cada pasada tiene fases secuenciales (qBit → warm-up HTTP → descubrimiento de keys → APIs de auth); las comprobaciones HTTP/API dentro de una fase corren **en paralelo**. Las esperas están limitadas por el presupuesto restante para que los reintentos suaves no pasen del deadline. Típico: **1–3 minutos** después de `up`; el peor caso se acerca a los **15 minutos** completos. Deberías ver `Waiting for first-start initialization…` antes de `Discovering API keys…`. Override: `CONFIGURE_PREFLIGHT_TIMEOUT=1200 ./bin/flixbox configure`.

Vista previa sin cambios de API ni de `.env`:

```bash
./bin/flixbox configure --dry-run
```

`--dry-run` imprime lo que se ejecutaría; **no** escribe `.env`, no recrea contenedores ni llama a las APIs de los servicios. Sigue exigiendo que los contenedores core estén up (igual que una ejecución en vivo).

**Lo que configura el script (idempotente — seguro reejecutar):**

| Servicio | Ajustes |
| --- | --- |
| qBittorrent | Categorías `tv` / `movies`, prefs (TMM, UPnP off, encryption); VPN → bind `tun0`; password de WebUI desde `.env` |
| Sonarr / Radarr | Root folders, cliente qBittorrent, metadatos NFO, custom format Reject ISO |
| Prowlarr | Proxy Byparr cuando `flixbox-byparr` está en marcha (`http://byparr:8191`, tag `cf`), sync de apps Radarr + Sonarr |
| Bazarr | Conexiones Sonarr + Radarr, ffsubsync |
| Jellyfin | Startup (si hace falta), bibliotecas `/data/media/movies` + `/data/media/tv`, API key |
| Seerr | Login Jellyfin + servicios Radarr/Sonarr + initialize |
| Secrets | Escribe keys vacías en `.env`; parchea placeholders de Recyclarr; recrea Decluttarr/Unpackerr cuando cambian las keys |

**Prerrequisitos:**

1. `./bin/flixbox init` (API keys + `QBITTORRENT_*` + `FLIXBOX_ADMIN_*` generados cuando están vacíos).
2. Stack en marcha (`./bin/flixbox status`). Modo VPN: Gluetun **healthy**.
3. La auth de *arr sigue **`FLIXBOX_ACCESS_PROFILE`** ([ADR 0015](../../adr/0015-access-profiles.md)): por defecto **`trusted`** (sin login de UI *arr en LAN); **`shared`** si compañeros de piso comparten Wi‑Fi. `configure` siempre usa API keys para el cableado. Con **`shared`**, aplica Forms vía `./bin/flixbox credentials set arr-ui` (ADR 0020) — ver [13 — Crear login *arr](13-access-profiles.md#create-arr-login-shared).

**Sigue siendo manual:** indexers de Prowlarr; habilitar reglas de Maintainerr; sync opcional de Recyclarr; crear Forms en la UI solo si falla el apply de Host Config.

<a id="host-port-conflicts"></a>
### Conflictos de puertos en el host

`./bin/flixbox up` y `reload` ejecutan un **preflight de puertos del host** antes de que Compose arranque. Valida:
1. **Colisiones internas:** Comprueba que no haya dos servicios en `.env` con el mismo puerto de host (p. ej. poner por error `QBITTORRENT_PORT=8989` cuando `SONARR_PORT=8989`).
2. **Colisiones externas:** Comprueba si un puerto ya está ocupado **por otro proceso** en tu máquina (común: `8080` usado por otra app). Los puertos ya publicados por contenedores `flixbox-*` en ejecución se **ignoran** para que el `reload` del mismo stack funcione.

Si se detecta algún conflicto, `up` falla con un mensaje accionable y sugerencias en lugar de un error de bind de Docker.

1. Elige un puerto libre del host en `.env`, por ejemplo `QBITTORRENT_PORT=9898` (el puerto del contenedor sigue siendo `8080`).
2. Ejecuta `./bin/flixbox reload` (o `up` si el stack está caído).
3. Abre qBit en `http://localhost:9898` — *arr y Decluttarr siguen usando `http://qbittorrent:8080` dentro de Docker ([ADR 0014](../../adr/0014-stable-qbit-download-hostname.md)).

Jellyfin y Seerr siguen en todas las interfaces del host incluso en el perfil `shared` (apps del hogar). El preflight de puertos los sondea en `0.0.0.0`, no en `FLIXBOX_ADMIN_BIND_IP`.

Ver también [Troubleshooting — port preflight](10-troubleshooting.md).

---

<a id="youre-done-when"></a>
## Estás listo cuando

<a id="youre-done-when"></a>

Distingue **stack up** (contenedores healthy) de **pipeline works** (pedido → watch):

| Punto de control | Cómo verificar |
| --- | --- |
| Stack healthy | `./bin/flixbox status` — servicios core up |
| Apps cableadas | `./bin/flixbox configure` termina con **0 failed** (idempotente) |
| Indexers | ≥1 indexer en Prowlarr, sincronizado a Radarr/Sonarr |
| Ruta de pedidos | Un pedido de Seerr aparece en Radarr o Sonarr |
| Import + play | Archivo bajo `/data/media/…`, se reproduce en Jellyfin |

Recorrido opcional completo: [Smoke test — Phase F](11-smoke-test.md#phase-f--end-to-end-request-flow-manual) (happy path manual; no es la puerta CI de v0.1).

<a id="verify"></a>
## Verificar

**Esperado:** `configure` termina con **0 failed**; Prowlarr muestra apps + ≥1 indexer; un pedido de Seerr aparece en Radarr o Sonarr.

<a id="if-it-fails"></a>
## Si falla

| Síntoma | Empieza aquí |
| --- | --- |
| Timeout de preflight / first-start | [Troubleshooting — configure](10-troubleshooting.md) · sube `CONFIGURE_PREFLIGHT_TIMEOUT` |
| qBit `Unauthorized` / puerto remapeado | [§2b.1](#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) |
| Decluttarr idle / keys de higiene | [§3 higiene](#3-radarr--sonarr--hygiene) · [Troubleshooting](10-troubleshooting.md) |

---

## 1. Prowlarr + Byparr

<a id="1-prowlarr--byparr"></a>

Si ejecutaste `configure`, el proxy Byparr y las apps Radarr/Sonarr ya deberían existir. Verifica en **Settings → Indexers → Indexer Proxies** y **Settings → Apps**.

<a id="1a-add-indexers"></a>
### 1a. Agregar indexers

**Indexers sin Cloudflare** — agrégalos con normalidad.

**Indexers con Cloudflare** (por ejemplo 1337x):

1. **Indexers** → **Add indexer**.
2. En **Tags**, agrega **`cf`** (el mismo tag que el proxy Byparr).
3. **Test**.

<a id="1b-tags-and-app-sync"></a>
### 1b. Tags y sync de apps

Prowlarr avisa: *an indexer with a tag only syncs to apps with the same tag.* Mantén `cf` en las apps Radarr/Sonarr (configure lo deja así) o deja los indexers sin tag para todas las apps.

Sincroniza indexers con **Sync App Indexers**. Prowlarr **no** sincroniza download clients ni root folders.

Fallback manual de Byparr (si configure lo omitió): tipo de proxy **FlareSolverr**, host `http://byparr:8191`, tag `cf`.

---

## 2. qBittorrent

<a id="2c-download-paths-automatic"></a>
<a id="2e-custom-host-ports-and-stale-config"></a>

WebUI: `http://127.0.0.1:${QBITTORRENT_PORT}` (default `8080`).

Login: `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` de `.env` (lo pone init; configure aplica el password si qBit aún tiene uno temporal).

**Rutas de descarga (automáticas):** cont-init configura saves bajo `/data/torrents/` con incomplete bajo `torrents/incomplete`. Fuerza en cada arranque con `FLIXBOX_QBIT_FORCE_PATHS=true` si una ruta mala vuelve. Modo VPN: un custom service vuelve a enlazar BitTorrent a `tun0` para que los torrents no se queden en metaDL (ADR 0002).

**Puertos de host personalizados / config obsoleta:** si remapeaste `QBITTORRENT_PORT` y la WebUI sigue rota tras experimentos, para el stack, elimina `${CONFIG_DIR}/qbittorrent/qBittorrent/`, luego `./bin/flixbox up` y `configure --sync-qbit-auth` si la auth se desalineó.

Si la WebUI muestra un `Unauthorized` plano con un puerto de host remapeado, ver [§2b.1](#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) más abajo.

<a id="2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x"></a>
### 2b.1 WebUI atascada en `Unauthorized` plano (qBittorrent 5.x)

<a id="2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x"></a>

Flixbox mapea `${QBITTORRENT_PORT}:8080`. qBit 5.x puede rechazar `Host: localhost:<mapped-port>` cuando `HostHeaderValidation` espera `:8080`.

`flixbox init` instala cont-init que pone `WebUI\HostHeaderValidation=false` y `WebUI\LocalHostAuth=false`, y un **runtime custom-service** ([ADR 0019](../../adr/0019-qbit-webui-runtime-contract.md)) reaplica el contrato de seguridad de la WebUI vía API porque qBit puede descartar Preferences al arrancar.

Vuelve a ejecutar init y recrea qBit si tu instalación es anterior a ese mount:

```bash
./bin/flixbox init --non-interactive
./bin/flixbox reload
# If password / *arr clients drifted after recreate:
./bin/flixbox configure --sync-qbit-auth
```

<a id="2d-vpn-port-forwarding"></a>
### 2d. Port forwarding VPN

Si `VPN_PORT_FORWARDING=on`: habilita **Bypass authentication for clients on localhost** en la WebUI de qBit (los hooks de Gluetun llaman a `127.0.0.1:8080`).

---

<a id="3-radarr-sonarr-hygiene"></a>
## 3. Radarr / Sonarr / higiene

<a id="3-radarr--sonarr--hygiene"></a>
<a id="3-radarr--sonarr"></a>
<a id="3b-download-client-qbittorrent"></a>
<a id="3c-hygiene-credentials-decluttarr--unpackerr"></a>

`configure` agrega root folders y el download client de qBittorrent (`host: qbittorrent`, puerto `8080`). En ejecuciones posteriores **vuelve a probar** ese cliente y actualiza username/password/API key cuando Test falla **o** la API key de qBit guardada se desalineó (p. ej. regeneración accidental en la WebUI). Para **forzar** un push completo desde `.env` a qBit + *arr + Decluttarr tras un cambio manual de password, usa `./bin/flixbox configure --sync-qbit-auth` — [Credentials — key changes](06-configuration.md#accidental--intentional-key-changes).

**Credenciales de higiene:** Decluttarr/Unpackerr toman `RADARR_API_KEY` / `SONARR_API_KEY` / `QBITTORRENT_*` de `.env`. Configure los recrea cuando escribe esas keys o cuando pasas `--sync-qbit-auth`; si no, `./bin/flixbox reload`.

---

## 4. Bazarr / Jellyfin / Seerr

<a id="4-bazarr--jellyfin--seerr"></a>
<a id="4-bazarr"></a>
<a id="6-seerr"></a>

Configure conecta Bazarr a Sonarr/Radarr, completa las bibliotecas de Jellyfin cuando `FLIXBOX_ADMIN_*` está definido y cablea Seerr.

Si falla la automatización de Jellyfin o Seerr (peculiaridades de versión), termina el wizard de la UI una vez y vuelve a ejecutar `./bin/flixbox configure` — los pasos restantes deberían **omitirse** (skip).

| Bibliotecas Jellyfin | Ruta |
| --- | --- |
| Movies | `/data/media/movies` |
| TV | `/data/media/tv` |

**Consejo de reproducción:** `./bin/flixbox configure` limpia un bind solitario de Jellyfin a `::` (IPv6 any) para que las URLs de stream no se queden en `::1`. Deja **Dashboard → Networking → Bind to local network address** vacío si lo editas a mano. Ese ajuste no es un firewall; Compose ya publica Jellyfin en `:8096` para uso del hogar. Ver [Troubleshooting](10-troubleshooting.md).

---

## 5. Recyclarr / Maintainerr / Homepage

<a id="5-recyclarr--maintainerr--homepage"></a>
<a id="8-decluttarr--maintainerr"></a>

- Recyclarr: placeholders parcheados por configure →  
  `docker compose --profile recyclarr run --rm recyclarr sync`
- Maintainerr (`:6246`): conecta Jellyfin + *arr; habilita reglas de [Higiene](08-hygiene.md) a propósito.
- Las plantillas de Homepage las copia init; los widgets de API mejoran a medida que las keys llegan a `.env`.

<a id="next"></a>
## Siguiente

[Configuración](06-configuration.md) · [VPN y Direct](07-vpn-and-direct.md) · [Estás listo cuando](#youre-done-when)
