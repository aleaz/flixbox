<a id="vpn-and-direct-mode"></a>
# Modo VPN y Direct

**Idiomas:** [English](../../user/07-vpn-and-direct.md) · Español (esta página)

<a id="choose-a-mode"></a>
## Elige un modo

Flixbox tiene **un** switch de modo de descarga. Los modos son **excluyentes**: no puedes ejecutar egress Direct y un túnel Gluetun de Flixbox para qBittorrent al mismo tiempo.

### `FLIXBOX_MODE` vs `VPN_ENABLED`

| Variable | ¿La usa Compose? | Rol |
| --- | --- | --- |
| `FLIXBOX_MODE` | **Sí** | Elige `compose/downloaders-direct.yml` **o** `compose/downloaders-vpn.yml` |
| `VPN_ENABLED` | **No** | Espejo / etiqueta legacy. `flixbox init` la sincroniza desde `FLIXBOX_MODE`. Se mantiene por docs y CLI futura |

**Pon ambas juntas** para que `.env` no te mienta:

| Modo pretendido | Pon esto |
| --- | --- |
| Direct | `FLIXBOX_MODE=direct` y `VPN_ENABLED=false` |
| VPN | `FLIXBOX_MODE=vpn` y `VPN_ENABLED=true` |

| Desajuste | Qué corre de verdad |
| --- | --- |
| `FLIXBOX_MODE=direct` + `VPN_ENABLED=true` | **Direct** — Gluetun no está en el proyecto Compose |
| `FLIXBOX_MODE=vpn` + `VPN_ENABLED=false` | **VPN** — Gluetun + qBit en el netns de Gluetun |

`flixbox init` reescribe `VPN_ENABLED` desde `FLIXBOX_MODE` (y avisa si discrepaban). `flixbox up`, `status` y `vpn-test` avisan ante desajuste pero siguen `FLIXBOX_MODE`.

No hay un diseño de “tráfico Direct con la VPN aún up”. Si antes corrías VPN y pasas a Direct, ejecuta `./bin/flixbox down` y luego `./bin/flixbox up` para que un contenedor `flixbox-gluetun` sobrante no se confunda con un dual mode activo.

| `.env` | Comportamiento | Download client de *arr |
| --- | --- | --- |
| `FLIXBOX_MODE=direct` | qBittorrent en `flixbox_net`; Gluetun no arranca | `http://qbittorrent:8080` |
| `FLIXBOX_MODE=vpn` | qBittorrent comparte el netns de Gluetun; **alias** `qbittorrent` en Gluetun | `http://qbittorrent:8080` |

**Mismo hostname en ambos modos** (ADR 0014). El host del download client de Radarr/Sonarr es siempre `qbittorrent` — sin cambio de UI al cambiar de modo. `gluetun` sigue sirviendo para depuración.

| Elige **VPN** si… | Elige **Direct** si… |
| --- | --- |
| Quieres enmascarar el egress de torrents | Trackers privados con auth por IP |
| Tu proveedor funciona con Gluetun | Máxima velocidad de línea / pruebas de lab |

Pasar a VPN:

1. En `.env` **[REQUIRED]** (arriba): `FLIXBOX_MODE=vpn` y `VPN_ENABLED=true` (no solo el bloque Gluetun del final).
2. Rellena las vars de Gluetun bajo **[VPN ONLY]** (proveedor nativo o `custom` + `OPENVPN_CUSTOM_CONFIG` — ver [ejemplos abajo](#vpn-provider-examples) y `.env.example`).
3. `./bin/flixbox init --non-interactive` (actualiza `DECLUTTARR_QBIT_URL`, sincroniza `VPN_ENABLED`, instala custom-services VPN).
4. **Recrea el stack** para que aparezca Gluetun (Direct → VPN es un cambio de include de compose):
   - Preferido: `./bin/flixbox down` → `./bin/flixbox up`
   - O: `./bin/flixbox reload` si el stack ya está up (tras que el preflight de puertos del host permita puertos propios)
5. Espera hasta que Gluetun esté **healthy** (`./bin/flixbox status` / `logs gluetun`).
6. `./bin/flixbox configure --sync-qbit-auth` — realinea el password de WebUI de qBit + *arr/Decluttarr tras recrear (ADR 0019 también sana Host-header / whitelist de Docker en segundo plano).
7. `./bin/flixbox vpn-test`.

Si ejecutas `configure` justo después de editar `.env` sin `down`/`up`, verás *Gluetun container not running* — es lo esperado.

Tras **cualquier** cambio Direct↔VPN o recreación de qBit: prefiere `configure --sync-qbit-auth` una vez que Gluetun/qBit estén healthy. Si los logins de WebUI quedaron baneados, `./bin/flixbox restart qbittorrent` limpia el ban en memoria; luego vuelve a ejecutar configure.

<a id="vpn-bring-up-dependency-chain"></a>
### Arranque VPN (cadena de dependencias)

Cuando `FLIXBOX_MODE=vpn`, Compose espera health en este orden:

```text
gluetun (healthy) → qbittorrent (WebUI healthy) → radarr / sonarr / decluttarr / unpackerr
```

Si Gluetun está unhealthy, qBit y esos peers fallan con errores de dependencia. Es intencional (fail closed para la ruta de torrents). Seerr, Jellyfin, Prowlarr y apps similares no dependen de Gluetun y pueden arrancar igual. Arregla Gluetun primero (`./bin/flixbox logs gluetun`), luego recrea; o vuelve a Direct (`FLIXBOX_MODE=direct`, `VPN_ENABLED=false`, `./bin/flixbox init --non-interactive`, `./bin/flixbox up` — `up`/`reload` pasan `--remove-orphans` para que Gluetun se elimine al salir del modo VPN). El host del download client sigue siendo `qbittorrent`.

<a id="what-happens-when-the-vpn-drops"></a>
### Qué pasa cuando cae la VPN

Gluetun se reconecta **dentro del mismo contenedor** (default upstream). Mientras el túnel está caído, el killswitch bloquea el egress de qBit — las descargas se detienen; tu IP de casa debería seguir enmascarada. Esto es **fail closed**, no un fallback a Direct.

| Evento | Comportamiento esperado |
| --- | --- |
| Blip breve del túnel | Gluetun reinicia la VPN sola; qBit reanuda cuando está healthy |
| Corte prolongado | Gluetun se queda `unhealthy`; los health checks de qBit y *arr fallan hasta que vuelva la VPN |
| Contenedor Gluetun **recreado** | qBit puede quedar **varado** (cambió el netns) — ver [Troubleshooting](10-troubleshooting.md) |

Flixbox **nunca** cambiará solo `FLIXBOX_MODE` a Direct ante un fallo de VPN ([ADR 0013](../../adr/0013-vpn-resilience-no-direct-fallback.md)).

<a id="vpn-provider-examples"></a>
## Ejemplos de proveedor VPN

<a id="vpn-provider-examples"></a>

Tras poner `FLIXBOX_MODE=vpn` y `VPN_ENABLED=true`, rellena el bloque **[VPN ONLY]** en `.env`. Usa el id de proveedor Gluetun de la [Gluetun wiki](https://github.com/qdm12/gluetun-wiki). Nunca hagas commit de keys reales.

Luego: `./bin/flixbox init --non-interactive` → `./bin/flixbox down` → `./bin/flixbox up` → `./bin/flixbox vpn-test`.

<a id="wireguard-native-provider"></a>
### WireGuard (proveedor nativo)

Típico para Proton, Mullvad y la mayoría de proveedores modernos. Obtén la private key y la address de la config WireGuard del proveedor (o de la UI de la cuenta).

```env
FLIXBOX_MODE=vpn
VPN_ENABLED=true

VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_ADDRESSES=10.2.0.2/32
# Optional filters (provider-dependent):
# SERVER_COUNTRIES=Netherlands
# SERVER_CITIES=Amsterdam
VPN_PORT_FORWARDING=off
```

<a id="openvpn-native-provider"></a>
### OpenVPN (proveedor nativo)

Úsalo cuando tu proveedor emite credenciales OpenVPN en lugar de WireGuard.

```env
FLIXBOX_MODE=vpn
VPN_ENABLED=true

VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=openvpn
OPENVPN_USER=your_openvpn_username
OPENVPN_PASSWORD=your_openvpn_password
# Optional filters:
# SERVER_COUNTRIES=Netherlands
VPN_PORT_FORWARDING=off
```

<a id="custom-openvpn-file-lab-special-configs"></a>
### Archivo OpenVPN custom (lab / configs especiales)

Para un `.ovpn` que aportas tú (no sustituye a un proveedor comercial no-logs):

1. Coloca el archivo bajo `${CONFIG_DIR}/gluetun/` (volumen ya montado).
2. En el `.ovpn`, `remote` debe ser una **dirección IP** (no un hostname) — requisito de Gluetun.
3. Pon:

```env
FLIXBOX_MODE=vpn
VPN_ENABLED=true

VPN_SERVICE_PROVIDER=custom
VPN_TYPE=openvpn
OPENVPN_CUSTOM_CONFIG=/gluetun/custom.conf
# OPENVPN_USER=…
# OPENVPN_PASSWORD=…
VPN_PORT_FORWARDING=off
```

Bloque de comentarios completo y lista de variables: [`.env.example`](../../../.env.example) **[VPN ONLY]**.

<a id="vpn-mode-essentials"></a>
## Esenciales del modo VPN

1. Solo **qBittorrent** usa `network_mode: service:gluetun`.
2. Los puertos WebUI / BT se publican en **Gluetun**, no en el servicio qBittorrent.
3. Radarr/Sonarr/Decluttarr deben usar el host **`qbittorrent`** (igual en Direct — [ADR 0014](../../adr/0014-stable-qbit-download-hostname.md)).
4. IPv6 bloqueado por defecto (`BLOCK_IPV6=on`); DNS over TLS on (`DOT=on`).
5. Port forwarding opcional: `VPN_PORT_FORWARDING=on` (proveedores soportados). `./bin/flixbox configure` pone **Bypass authentication for clients on localhost** en qBittorrent cuando el port forwarding está habilitado (los hooks de Gluetun necesitan acceso API localhost sin auth).
6. Pon las credenciales del proveedor solo en `.env` o en archivos bajo `${CONFIG_DIR}/gluetun` — nunca en git.
7. Prefiere WireGuard cuando el proveedor lo soporte (keys más simples, suele ser más rápido). Usa OpenVPN cuando la cuenta solo ofrezca eso.

<a id="direct-mode-essentials"></a>
## Esenciales del modo Direct

1. Gluetun no arranca.
2. El host del download client es **`qbittorrent`**.
3. Sigue usando el layout único de hardlinks `/data`.

<a id="switching-modes"></a>
## Cambiar de modo

1. Pon `FLIXBOX_MODE` (y mantén `VPN_ENABLED` alineado) en `.env`.
2. Ejecuta `./bin/flixbox up` o `./bin/flixbox reload`.

Ambos comandos usan Compose `--remove-orphans`, así que los contenedores del otro módulo de downloader (p. ej. Gluetun tras pasar a Direct) se eliminan automáticamente ([ADR 0022](../../adr/0022-operator-footgun-remediations.md)). Un `down` completo es opcional.

Tras un cambio de modo o recreación de qBit, ejecuta `./bin/flixbox configure --sync-qbit-auth` si la ventana de auth de WebUI necesita re-bootstrap.

<a id="verify"></a>
## Verificar

```bash
./scripts/vpn-test.sh
```

Modo VPN: la IP pública **no** debería ser la de tu ISP de casa.  
Modo Direct: la IP pública es tu egress normal.

<a id="privacy-and-qbittorrent-settings"></a>
## Privacidad y ajustes de qBittorrent

Para expectativas de enmascarado de IP, recomendaciones de WebUI de qBit, escenarios de leak y checklist de auditoría, ver [Torrent privacy and security](12-torrent-privacy-and-security.md).

<a id="anti-patterns"></a>
## Anti-patrones

- Tratar `VPN_ENABLED` como un on/off independiente de Gluetun (Compose lo ignora)
- Poner Radarr/Sonarr/Seerr/Jellyfin detrás de Gluetun
- Montajes Docker partidos para torrents vs media
- Guardar `${CONFIG_DIR}` en NFS/SMB
- Correr ambos modos a la vez (no soportado — include de compose excluyente)

<a id="next"></a>
## Siguiente

[Higiene](08-hygiene.md)
