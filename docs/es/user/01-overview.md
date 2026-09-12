<a id="overview"></a>
# Resumen

**Idiomas:** [English](../../user/01-overview.md) · Español (esta página)

<a id="at-a-glance"></a>
## De un vistazo

Flixbox es un suite de medios doméstico open-source basado en Docker: pides un título, lo descargas (opcionalmente a través de una VPN), lo organizas con **hardlinks**, mantienes las colas ordenadas y reproduces con **Jellyfin**.

- **Resultado:** Pides en Seerr → ves en Jellyfin con un solo diseño de disco  
- **Para quién:** Operadores cómodos con Linux y Docker  
- **Tiempo:** ~15 minutos para levantar el stack con `configure`; los indexers son el paso manual principal  

<a id="who-it-is-for"></a>
## Para quién es

- Personas cómodas con Linux y Docker que quieren un stack moderno estilo *arr
- Operadores que prefieren contratos claros (almacenamiento, VPN/Direct) en lugar de un compose frágil de copiar y pegar
- Hogares que prefieren **Jellyfin** (FOSS) con Plex opcional más adelante

<a id="who-it-is-not-for"></a>
## Para quién no es

- Aparatos llave en mano sin conocimiento de Docker (aún — la CLI automatiza la tubería; tú sigues agregando indexers en Prowlarr)
- Quienes necesitan Kubernetes o HA multi-nodo en la nube como modelo principal
- Quien espera que Flixbox decida las cuestiones legales sobre lo que descargas

<a id="what-you-get"></a>
## Qué obtienes

| Pieza | Rol |
| --- | --- |
| Seerr | Portal de solicitudes |
| Prowlarr + Byparr | Indexers + bypass de Cloudflare |
| Radarr / Sonarr | Automatización de películas / series |
| qBittorrent + Gluetun (opcional) | Descargas, VPN o Direct |
| Unpackerr / Recyclarr | Archivos + sync de calidad TRaSH |
| Decluttarr / Maintainerr | Higiene de cola + biblioteca |
| Bazarr | Subtítulos |
| Jellyfin | Streaming |
| Homepage + Caddy | Dashboard + ingress HTTPS |
| `bin/flixbox` | CLI Bash para init/up/configure/status |

<a id="honest-expectations"></a>
## Expectativas honestas

`./bin/flixbox init` → `up` → **`configure`** cablea qBittorrent, clientes de descarga *arr, apps/Byparr de Prowlarr, Bazarr, bibliotecas de Jellyfin y Seerr cuando el stack está sano. Aun así deberás:

- Agregar **indexers de Prowlarr** (y etiquetar los de Cloudflare con `cf`)
- Confirmar que Seerr / *arr / qBit quedaron cableados tras configure (fallback por UI solo si falló la automatización)
- Activar reglas de **Maintainerr** a propósito (nada destructivo está activo por defecto)
- Opcionalmente ejecutar **Recyclarr sync** y configurar Caddy / credenciales VPN cuando las necesites
- En Wi‑Fi **`shared`**, aplicar Forms de *arr con `credentials set arr-ui` (o `configure --sync-arr-ui`)

<a id="youre-done-when"></a>
## Listo cuando

1. `./bin/flixbox status` muestra los servicios principales sanos  
2. `./bin/flixbox configure` termina con **0 failed** (seguro reejecutar)  
3. Al menos un indexer de Prowlarr está agregado y sincronizado a Radarr/Sonarr  
4. Una solicitud de Seerr aparece en Radarr o Sonarr  
5. Una descarga completada se importa a `/data/media` (hardlink) y reproduce en Jellyfin  

Checklist completo: [First-run](05-first-run.md#youre-done-when) · smoke del happy-path: [Smoke test — Phase F](11-smoke-test.md#phase-f--end-to-end-request-flow-manual).

<a id="verify"></a>
## Verificar

**Esperado:** Homepage en `http://localhost:3000`, `./bin/flixbox status` sano, Seerr en `:5055`, Jellyfin en `:8096`.

<a id="if-it-fails"></a>
## Si falla

| Síntoma | Empieza aquí |
| --- | --- |
| Docker permission denied | [Troubleshooting — Docker daemon](10-troubleshooting.md#docker-daemon-access) |
| Conflictos de `up` / puertos | [First-run — Host port conflicts](05-first-run.md#host-port-conflicts) |
| `configure` hace timeout | [Troubleshooting — configure](10-troubleshooting.md) |

<a id="disclaimer"></a>
## Aviso legal

> Los autores **no aprueban** la infracción de derechos de autor. Flixbox **solo ensambla** herramientas de terceros — **no** las desarrolla. **Úsalo bajo tu propio riesgo;** solo tú respondes por el contenido y el cumplimiento. Aviso completo: [Aviso legal](16-legal-disclaimer.md) · [Legal disclaimer (EN)](../../user/16-legal-disclaimer.md)

<a id="lan-security-access-profiles"></a>
## Seguridad en LAN (perfiles de acceso)

El perfil por defecto es **`trusted`**: las UIs de administración *arr en tu Wi‑Fi no piden login. Si **compañeros de piso o invitados comparten la misma red**, define `FLIXBOX_ACCESS_PROFILE=shared` en `.env` antes de `init`/`up` — los puertos de admin se enlazan a localhost y *arr usan login Forms. Ver [Access profiles](13-access-profiles.md).

<a id="next"></a>
## Siguiente

Lee [How it works](02-how-it-works.md) para el modelo mental, luego [Requirements](03-requirements.md).
