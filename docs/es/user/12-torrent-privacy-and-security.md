<a id="torrent-privacy-and-security"></a>
# Privacidad y seguridad BitTorrent

**Estado:** Borrador de trabajo.  
**Idiomas:** [English](../../user/12-torrent-privacy-and-security.md) · Español (esta página)

Guía práctica para operadores que quieren **ocultar la IP de casa** frente a peers BitTorrent y evitar fugas habituales. Complementa [VPN y Direct](07-vpn-and-direct.md) (cómo cambiar de modo) con ajustes de qBittorrent, expectativas realistas y checklists de auditoría.

<a id="1-what-this-guide-covers"></a>
## 1. Qué cubre esta guía

| En alcance | Fuera de alcance |
| --- | --- |
| Enmascarar IP vía modo VPN | Asesoramiento legal sobre qué puedes descargar |
| Ajustes de privacidad del WebUI de qBittorrent | Elegir un proveedor VPN (más allá de lo básico) |
| Prevención y verificación de fugas | Pruebas de penetración completas |
| Exposición de red de los servicios Flixbox | Reglas específicas de cada tracker (léelas en cada uno) |

<a id="privacy-vs-anonymity"></a>
### Privacidad vs anonimato

- **Privacidad (objetivo realista):** Los peers y trackers ven la **IP de salida de la VPN**, no la IP de tu ISP en casa. Tu ISP ve tráfico VPN cifrado, no cargas BitTorrent hacia peers individuales.
- **Anonimato (no garantizado):** Nadie puede vincular la actividad contigo. BitTorrent no ofrece eso. Tu proveedor VPN, los trackers, el análisis temporal y las sesiones registradas aún pueden correlacionar actividad.

Flixbox ayuda con la **privacidad mediante aislamiento VPN**; no te hace anónimo.

<a id="disclaimer"></a>
### Aviso

Tú eres responsable de cumplir las leyes aplicables y los términos de servicio de contenido, indexers, trackers y proveedores VPN. Los controles de privacidad aquí son solo **técnicos** — no autorizan infracción. Aviso completo: [Legal disclaimer (EN)](../../user/16-legal-disclaimer.md) · [Aviso legal](16-legal-disclaimer.md). Ver también [Overview — Disclaimer](01-overview.md#disclaimer).

---

<a id="2-who-sees-what"></a>
## 2. Quién ve qué

| Observador | Modo Direct | Modo VPN (túnel sano) |
| --- | --- | --- |
| Peers BitTorrent | Tu IP pública de casa | IP de salida de la VPN |
| Trackers (announce) | Tu IP pública de casa | IP de salida de la VPN |
| Tu ISP | Tráfico BitTorrent hacia muchas IPs | Túnel cifrado a la VPN (solo metadatos) |
| Proveedor VPN | N/A | Extremos del túnel; puede registrar si su política lo permite |
| Otras apps Flixbox (*arr, Jellyfin) | Solo LAN / red Docker | Igual — permanecen fuera del netns de la VPN |

**Byparr** solo hace proxy del tráfico HTTP de indexers en Prowlarr (bypass de Cloudflare). **No** afecta las conexiones de peers BitTorrent.

---

<a id="3-how-flixbox-protects-torrent-traffic-vpn-mode"></a>
## 3. Cómo Flixbox protege el tráfico torrent (modo VPN)

Cuando `FLIXBOX_MODE=vpn`:

1. **Solo qBittorrent** usa `network_mode: service:gluetun`. Todo el egress P2P pasa por el túnel.
2. **Killswitch de Gluetun** bloquea qBit si el túnel cae (namespace de red compartido + firewall).
3. **Puerta de healthcheck:** qBittorrent solo arranca después de que Gluetun esté healthy.
4. **`BLOCK_IPV6=on`** (por defecto): reduce fugas por bypass IPv6 cuando la VPN no enruta IPv6.
5. **`DOT=on`** (por defecto): DNS over TLS dentro de Gluetun.
6. **Hook de port-forward** pone `upnp: false` al actualizar el puerto de escucha de qBit — no abre agujeros en el router de casa.

Radarr, Sonarr, Prowlarr, Seerr, Jellyfin y el resto permanecen en `flixbox_net`. Hablan con qBit en `http://qbittorrent:8080` (VPN: alias en Gluetun). Su propio tráfico no usa la VPN. Ver [Architecture (EN)](../../03-architecture.md).

Referencia completa de modos: [VPN y Direct](07-vpn-and-direct.md).

---

<a id="4-direct-mode-when-and-what-you-expose"></a>
## 4. Modo Direct: cuándo y qué expones

Usa `FLIXBOX_MODE=direct` cuando:

- Un tracker privado tiene en whitelist tu IP de casa.
- Necesitas la máxima velocidad de línea y aceptas exposición de IP.
- Estás probando en un laboratorio sin egress sensible.

En modo Direct, **tu IP pública real es visible** para cada peer y tracker del swarm. `./bin/flixbox vpn-test` mostrará tu IP normal del ISP — eso es lo esperado.

Host del cliente de descarga: `http://qbittorrent:8080`.

---

<a id="5-qbittorrent-settings-recommended"></a>
## 5. Ajustes de qBittorrent (recomendados)

Configúralos en el WebUI tras el primer login. Ruta: **Options** (icono de engranaje) salvo que se indique otra.

### 5.1 Connection

| Ajuste | Modo VPN | Modo Direct | Por qué |
| --- | --- | --- | --- |
| **UPnP / NAT-PMP** | Off | Off | Evita abrir puertos en tu router real; el hook Flixbox/Gluetun ya desactiva UPnP al actualizar el port-forward |
| **Use a proxy** | Off | Off | Flixbox usa el netns de la VPN, no un proxy SOCKS/HTTP en qBit |
| **Interface / bind** | Predeterminado | Predeterminado | En modo VPN el netns de Gluetun ya restringe el egress; el bind manual suele ser innecesario |

**Port forwarding de VPN** (`VPN_PORT_FORWARDING=on` en `.env`): mejora la conectividad entrante y el ratio en algunos setups. Los peers siguen viendo la **IP de la VPN**, no la de casa. Compromiso: algunos trackers bloquean rangos VPN conocidos; tu proveedor puede correlacionar el puerto reenviado con tu sesión.

Si el port forwarding está activo, habilita **Bypass authentication for clients on localhost** en **Options → Web UI** para que Gluetun pueda llamar a la WebAPI. Esto es distinto de `LocalHostAuth` (lo gestiona el hook de init de Flixbox para los port maps de Docker). Ver [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x).

### 5.2 BitTorrent

| Ajuste | Recomendación | Notas |
| --- | --- | --- |
| **Encryption mode** | Prefer encryption | Oculta la carga de la inspección del ISP; **no oculta tu IP a los peers** |
| **Encryption mode** | Require encryption | Más estricto; puede reducir el número de peers |
| **DHT** | On para indexers públicos; **off para trackers privados** | Muchos trackers privados prohíben DHT |
| **PeX** | Igual que DHT | Las reglas de trackers privados suelen exigir off |
| **Local Peer Discovery** | Off en setups compartidos/VPN | Opcional; el discovery en LAN rara vez hace falta en Docker |
| **Anonymous mode** | No confíes en él | **No** oculta tu IP; solo afecta algunas listas de peers del tracker |

### 5.3 Web UI

| Acción | Prioridad |
| --- | --- |
| Cambia la password por defecto de `admin` tras el primer login | Obligatorio |
| Usa **API key** en Radarr/Sonarr (no la password del WebUI) | Obligatorio — [Credentials](06-configuration.md#credentials-and-api-keys) |
| No publiques el puerto `8080` a Internet | Obligatorio |
| Define `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` en `.env` para Decluttarr si la auth está activa | Al usar Decluttarr |

**Red de automatización Docker (`172.30.42.0/24`):** Flixbox fija `flixbox_net` a ese CIDR y configura `AuthSubnetWhitelist` de qBittorrent para él. Los peers del stack (y a menudo el gateway Docker cuando abres el WebUI publicado desde el host) **omiten la password del WebUI**. Es intencional para Decluttarr/*arr en el bridge — mantén qBit fuera de Internet público ([ADR 0008](../../adr/0008-maintenance-decluttarr-maintainerr.md)). Esto **no** es lo mismo que el perfil LAN **`trusted`** / **`shared`** ([Perfiles de acceso](13-access-profiles.md)).

---

<a id="6-common-leak-and-misconfiguration-scenarios"></a>
## 6. Escenarios habituales de fuga y mala configuración

```
Your host / Docker
    │
    ├─► Direct mode on public swarms ──────► home IP visible to peers
    │
    ├─► qBit not in Gluetun netns ─────────► home IP despite VPN container running
    │
    ├─► IPv6 active without VPN IPv6 ──────► IPv6 leak (Flixbox: BLOCK_IPV6=on)
    │
    ├─► DNS outside tunnel ────────────────► ISP sees tracker lookups (Flixbox: DOT=on)
    │
    ├─► VPN down, no killswitch ───────────► brief home-IP exposure
    │
    ├─► WebUI on 0.0.0.0 published to WAN ► remote control of your client
    │
    ├─► *arr/Jellyfin behind Gluetun ─────► broken metadata + wrong design
    │
    └─► Radarr host still `qbittorrent` ───► *arr cannot reach qBit in VPN mode
        after switching to VPN without UI update
```

| Síntoma | Causa probable | Arreglo |
| --- | --- | --- |
| `vpn-test` muestra la IP del ISP en modo VPN | Túnel caído, modo incorrecto, o qBit fuera del netns de Gluetun | Revisa `FLIXBOX_MODE`, logs de Gluetun, recrea el stack |
| *arr no alcanza qBit tras cambiar a VPN | Falta el alias `qbittorrent` en Gluetun o Gluetun unhealthy | Mantén el host del cliente de descarga **`qbittorrent`**; revisa `docker compose ps gluetun` — [ADR 0014](../../adr/0014-stable-qbit-download-hostname.md) |
| Fuga IPv6 en test externo | `BLOCK_IPV6=off` o problema del proveedor | Mantén el default `on`; prueba desde el contenedor Gluetun |
| Puerto del router de casa abierto sin querer | UPnP habilitado en qBit | Desactiva UPnP/NAT-PMP en qBit |

Más arreglos: [Troubleshooting](10-troubleshooting.md).

---

<a id="7-what-does-not-provide-anonymity"></a>
## 7. Qué NO aporta anonimato

| Mito | Realidad |
| --- | --- |
| Cifrado del protocolo | Los peers siguen viendo tu IP (VPN o casa) |
| “Anonymous mode” de qBit | Nombre engañoso; no oculta la IP |
| Solo desactivar DHT | Trackers y peers conectados siguen viendo tu IP |
| Blocklists de IP | Bloquean IPs concretas; no son anonimato |
| Puerto de escucha aleatorio sin VPN | La IP no cambia |
| Byparr / proxies de indexers | Solo HTTP del indexer; no P2P |
| VPNs gratis o desconocidas | Pueden registrar, vender datos o filtrar |

---

<a id="8-privacy-audit-checklist"></a>
## 8. Checklist de auditoría de privacidad

Ejecútalo tras el primer `up`, tras cambiar de proveedor o servidor VPN, tras modificar `.env` o ajustes de qBit, o tras cualquier sospecha de fuga.

<a id="81-quick-checklist-10-minutes"></a>
### 8.1 Checklist rápido (~10 minutos)

**Flixbox / entorno**

- [ ] `FLIXBOX_MODE=vpn` si no quieres tu IP de casa en el swarm
- [ ] `VPN_ENABLED=true` coincide con el modo VPN (`flixbox init` lo sincroniza)
- [ ] Credenciales de Gluetun definidas; `docker compose ps` muestra `gluetun` healthy
- [ ] `BLOCK_IPV6=on` (default en `.env.example`)
- [ ] `DOT=on` (default)
- [ ] Host del cliente de descarga en Radarr/Sonarr es **`qbittorrent`** (puerto `8080`) en VPN y Direct — [ADR 0014](../../adr/0014-stable-qbit-download-hostname.md)
- [ ] `DECLUTTARR_QBIT_URL=http://qbittorrent:8080` (igual en VPN y Direct — ADR 0014) — `grep DECLUTTARR_QBIT_URL .env`
- [ ] `./bin/flixbox vpn-test` — modo VPN: IP **≠** la de tu ISP; Direct: IP **es** la de tu ISP
- [ ] WebUI de qBittorrent alcanzable solo en LAN (no reenviado en el router de casa a WAN)

**WebUI de qBittorrent**

- [ ] Password por defecto de `admin` cambiada
- [ ] API key configurada en Radarr/Sonarr; username/password vacíos en el cliente de descarga *arr
- [ ] UPnP y NAT-PMP desactivados
- [ ] Si `VPN_PORT_FORWARDING=on`: **Bypass authentication for clients on localhost** habilitado

**qBittorrent — BitTorrent**

- [ ] Encryption: Prefer (o Require si aceptas menos peers)
- [ ] DHT / PeX / LSD: off para trackers privados; on para indexers públicos según haga falta
- [ ] No confías en Anonymous mode para privacidad de IP

**Exposición de red**

- [ ] *arr, Jellyfin, Homepage no expuestos en WAN sin HTTPS y auth
- [ ] Solo qBittorrent usa el netns de Gluetun (ningún otro servicio en `network_mode: service:gluetun`)

**Credenciales**

- [ ] `.env` no commiteado a git
- [ ] Sin API keys ni claves VPN en capturas o reportes de issues

<a id="82-verification-commands"></a>
### 8.2 Comandos de verificación

IP pública desde el namespace activo del downloader:

```bash
./bin/flixbox vpn-test
```

Salud de Gluetun y errores recientes:

```bash
docker compose logs gluetun --tail 50
docker compose ps gluetun qbittorrent
```

Sonda opcional de fuga DNS desde el contenedor Gluetun (modo VPN):

```bash
docker exec flixbox-gluetun wget -qO- https://bash.ws/dnsleak/test/ | head -20
```

Interpreta los resultados con cuidado — algunos sitios de leak-test son ruidosos. La comprobación principal de Flixbox sigue siendo `vpn-test` (IP pública vía túnel).

<a id="83-extended-audit-optional"></a>
### 8.3 Auditoría ampliada (opcional)

Úsala anualmente, tras un cambio de proveedor VPN, o si sospechas una fuga.

| Área | Comprobación |
| --- | --- |
| Proveedor VPN | Política no-log en la que confíes; jurisdicción; soporta las funciones de Gluetun que necesitas |
| Killswitch | Detén Gluetun (`docker stop flixbox-gluetun`); confirma que qBit no puede obtener peers nuevos (no es un test de fuga a largo plazo — restaura el stack después) |
| Rutas de descarga | qBit guarda bajo `/data/torrents/` — [First-run §2c](05-first-run.md#2c-download-paths-automatic) |
| Smoke test Phase D | Validación VPN completa — [Smoke test § Phase D](11-smoke-test.md#phase-d--vpn-mode-optional-needs-provider-creds) |
| Reverse proxy | Si usas el profile Caddy: TLS on; sin puertos *arr crudos en WAN — [Requirements](03-requirements.md#network) |
| Reglas del tracker | Trackers privados: DHT/PeX off; política de ratio/VPN por tracker |

Registra resultados (fecha, salida de `vpn-test` redactada, checklist pass/fail) si operas varios hosts.

---

<a id="9-vpn-provider-considerations"></a>
## 9. Consideraciones del proveedor VPN

Flixbox no respalda un proveedor concreto. Al elegir uno para uso torrent:

| Factor | Por qué importa |
| --- | --- |
| **Política no-logs** | El proveedor podría vincular la IP VPN a tu cuenta |
| **Jurisdicción** | Presión legal sobre retención |
| **Soporte Gluetun** | Plantillas WireGuard/OpenVPN, API de port forwarding |
| **Port forwarding** | Mejor conectividad; el proveedor conoce el puerto asignado por sesión |
| **Reputación en trackers** | Algunos trackers bloquean rangos de IP datacenter/VPN |
| **Comportamiento del killswitch** | Gluetun añade una capa; el killswitch de la app del proveedor es irrelevante dentro de Docker |

Referencia env: [Configuration — VPN](06-configuration.md#vpn-mode-only).

---

<a id="10-beyond-bittorrent-flixbox-surface-area"></a>
## 10. Más allá de BitTorrent: superficie de Flixbox

La privacidad BitTorrent no protege otros servicios:

| Servicio | Riesgo si se expone a WAN |
| --- | --- |
| Radarr / Sonarr / Prowlarr | Manipulación de biblioteca, robo de API key |
| Jellyfin | Acceso a medios |
| WebUI de qBittorrent | Control total de descargas |
| Homepage | Divulgación de información |
| Byparr | Abuso del proxy de indexers |

**Mitigaciones:** acceso solo LAN, Caddy con HTTPS (profile `proxy`), reglas de firewall en el host. SSO (Authelia/Authentik) es post-MVP — ver [Roadmap (EN)](../../08-roadmap.md).

Notas de ingeniería: [Operations risks §3 (EN)](../../07-operations-risks.md#3-security--privacy).

---

<a id="11-quick-reference"></a>
## 11. Referencia rápida

<a id="mode-comparison"></a>
### Comparación de modos

| | Modo VPN | Modo Direct |
| --- | --- | --- |
| `.env` | `FLIXBOX_MODE=vpn` | `FLIXBOX_MODE=direct` |
| Host del cliente de descarga qBit | `qbittorrent` | `qbittorrent` |
| IP vista por peers | Salida VPN | ISP de casa |
| Gluetun en ejecución | Sí | No |
| Test de fuga | IP ≠ ISP | IP = ISP |

<a id="key-env-variables-vpn"></a>
### Variables clave de `.env` (VPN)

| Variable | Valor por defecto | Rol de privacidad |
| --- | --- | --- |
| `BLOCK_IPV6` | `on` | Bloquear fuga IPv6 |
| `DOT` | `on` | DNS over TLS |
| `VPN_PORT_FORWARDING` | `off` | Opcional; actívalo solo con soporte del proveedor |
| `FIREWALL_OUTBOUND_SUBNETS` | (vacío) | Acceso LAN a través de Gluetun si hace falta |

<a id="qbit-webui-paths"></a>
### Rutas del WebUI de qBit

| Tarea | Ubicación |
| --- | --- |
| Encryption, DHT, PeX | Options → BitTorrent |
| UPnP, ports | Options → Connection |
| Password, API key, localhost bypass | Options → Web UI |

---

<a id="related-guides"></a>
## Guías relacionadas

| Guía | Tema |
| --- | --- |
| [07 — VPN y Direct](07-vpn-and-direct.md) | Cambio de modos, anti-patrones |
| [06 — Configuration](06-configuration.md) | `.env`, credenciales, URLs del cliente de descarga |
| [05 — First-run](05-first-run.md) | Login qBit, rutas, cableado *arr |
| [11 — Smoke test](11-smoke-test.md) | Validación MVP incluida la fase VPN |
| [10 — Troubleshooting](10-troubleshooting.md) | Fallos habituales de qBit y VPN |
| [03 — Requirements](03-requirements.md) | Red y exposición básicas |
