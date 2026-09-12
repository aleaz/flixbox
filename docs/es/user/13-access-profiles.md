<a id="access-profiles"></a>
# Perfiles de acceso

**Idiomas:** [English](../../user/13-access-profiles.md) · Español (esta página)

Política de auth en LAN para UIs de administración. Ver [ADR 0015](../../adr/0015-access-profiles.md).

<a id="profiles"></a>
## Perfiles

Define en `.env` antes de `up`:

| Perfil | Cuándo usarlo | WebUI *arr desde otro dispositivo en `192.168.x.x` | Bind de puertos admin |
| --- | --- | --- | --- |
| `trusted` (default) | Confías en todos en tu Wi‑Fi | Sin login (bypass RFC1918) | Todas las interfaces (`0.0.0.0`) |
| `shared` | Compañeros de piso / invitados en la misma red | Login obligatorio (`Forms`) + publicación **solo localhost** | Solo `127.0.0.1` |

```env
FLIXBOX_ACCESS_PROFILE=trusted
# shared → init generates FLIXBOX_ARR_UI_* (apply via credentials set arr-ui):
# FLIXBOX_ARR_UI_USER=admin
# FLIXBOX_ARR_UI_PASSWORD=...
# FLIXBOX_ADMIN_BIND_IP=127.0.0.1   # set by init from profile — do not hand-edit
```

Tras cambiar el perfil:

```bash
# up / reload / configure auto-sync derived bind + auth keys into .env
# and force-recreate admin-bound services when derived keys drifted
./bin/flixbox reload
# Optional: re-run init so shared FLIXBOX_ARR_UI_* placeholders are generated if empty
./bin/flixbox init --non-interactive
./bin/flixbox reload
./bin/flixbox credentials set arr-ui --generate
```

Al pasar a **`shared`**, `up` / `configure` / `reload` también aseguran que existan **`FLIXBOX_ARR_UI_USER`** y **`FLIXBOX_ARR_UI_PASSWORD`** en `.env` (se generan si están vacíos). También sincronizan Homepage (`services.yaml`): bajo **`shared`**, se eliminan los bloques de widgets admin para que Homepage alcanzable en LAN no conserve secretos de *arr/qBit. Aplica Forms con:

```bash
./bin/flixbox credentials set arr-ui --generate   # or --prompt
# equivalent force-push during configure:
./bin/flixbox configure --sync-arr-ui
```

`./bin/flixbox configure` (sin `--sync-arr-ui`) usa **API keys** en `127.0.0.1` — no aplica Forms en cada ejecución.

<a id="create-arr-login-shared"></a>
## Crear login *arr (`shared`)

Servarr **no tiene variable de entorno** para username/password de Forms ([Servarr env docs](https://wiki.servarr.com/sonarr/environment-variables)). Flixbox aplica Forms vía la API Host Config (ADR 0020).

Con `FLIXBOX_ACCESS_PROFILE=shared`, `init` genera **`FLIXBOX_ARR_UI_USER`** y **`FLIXBOX_ARR_UI_PASSWORD`** como fuente de verdad.

**Después** de `./bin/flixbox up` y `./bin/flixbox configure`:

1. Aplica Forms: `./bin/flixbox credentials set arr-ui --generate` (o `configure --sync-arr-ui` si los valores ya están en `.env`).
2. En el **host** (o vía túnel SSH), abre **Radarr**, **Sonarr** y **Prowlarr** en `http://127.0.0.1:<port>` e inicia sesión con `FLIXBOX_ARR_UI_*` (`./bin/flixbox credentials show arr-ui`).
3. Si falla la aplicación Host Config, crea la cuenta Forms a mano en cada WebUI con los mismos valores — cada app tiene su propio almacén de usuarios.

**El orden importa:** ejecuta `configure` **antes** de depender de Forms para que el cableado API termine sin que los wizards del navegador bloqueen la automatización.

<a id="admin-surfaces-bound-to-localhost-in-shared"></a>
### Superficies admin ligadas a localhost en `shared`

| Servicio | Alcance desde el host en `shared` |
| --- | --- |
| Prowlarr, Radarr, Sonarr, Bazarr | Solo `127.0.0.1` |
| Byparr | Solo `127.0.0.1` (Prowlarr sigue usando `http://byparr:8191` en la red Docker) |
| Maintainerr | Solo `127.0.0.1` |
| WebUI de qBittorrent | Solo `127.0.0.1` (el puerto de escucha BitTorrent sigue publicado) |
| Jellyfin, Seerr, Homepage | Siguen en LAN (consumidores del hogar) |

<a id="homepage-links-from-phones-tvs"></a>
<a id="homepage-links-from-phones--tvs"></a>
### Enlaces de Homepage desde teléfonos / TVs

Las plantillas usan por defecto `href: http://localhost:…`, que solo funciona en el host Docker.

1. Define **`FLIXBOX_PUBLIC_HOST`** con la IP LAN o DNS de esta máquina (sin `http://`, sin puerto), p. ej. `192.168.1.50`.
2. Ejecuta `./bin/flixbox reload` (o `up` / `configure`). Flixbox entonces:
   - Añade `192.168.1.50:3000` a **`HOMEPAGE_ALLOWED_HOSTS`** si falta (validación Host de Homepage)
   - Pone **`JELLYFIN_PUBLISHED_URL`** vacío en `http://192.168.1.50:8096` (anuncio de stream)
   - Fija los hrefs de Jellyfin/Seerr en Homepage a ese host (se reaplican si cambias la IP/DNS)
3. Aún puedes editar a mano `HOMEPAGE_ALLOWED_HOSTS` / `JELLYFIN_PUBLISHED_URL` (p. ej. URL HTTPS de Caddy) — una Published URL no vacía se deja intacta.

Bajo **`shared`**, las tarjetas admin (Radarr/Sonarr/qBit/…) conservan el estado Docker; el **href es `http://127.0.0.1:<port>`** para que un navegador **en el host Docker** pueda abrir y usar Forms. Desde un teléfono en Wi‑Fi esos enlaces golpean el loopback del propio teléfono (fallan) — los puertos admin no se publican en la LAN. Aplica Forms con `credentials set arr-ui`.

<a id="qbittorrent-all-profiles"></a>
### qBittorrent (todos los perfiles)

| Desde | Password del WebUI |
| --- | --- |
| Mismo servidor (`127.0.0.1`) | A menudo omitida (ruta del bridge Docker) |
| Teléfono/portátil en LAN (`192.168.x.x`) | **Obligatoria** cuando está publicado (`trusted`). Puerto del host inalcanzable en `shared`. |

### Jellyfin / Seerr

Usa siempre cuentas por persona en redes compartidas. No compartas `FLIXBOX_ADMIN_PASSWORD`.

<a id="do-not-publish-admin-ports-to-the-internet"></a>
## No publiques puertos admin a Internet

Los puertos WebUI de Radarr, Sonarr, Prowlarr y qBittorrent son solo para **LAN o localhost**, salvo que se implemente un diseño futuro de reverse-proxy. El perfil `trusted` en un Wi‑Fi compartido es inseguro — usa `shared`.

<a id="threat-model-homelab"></a>
## Modelo de amenaza (homelab)

Flixbox asume **un operador de confianza** en el host Docker:

| Superficie | Riesgo | Mitigación |
| --- | --- | --- |
| Docker socket / `docker inspect` | Secretos env (API keys, passwords) visibles | Limita el acceso al host; trata los backups de `config/` como `.env` |
| Perfil `trusted` + bind `0.0.0.0` | UIs admin *arr abiertas en LAN sin login | Usa `shared` en Wi‑Fi de invitados; `./bin/flixbox up` avisa con `trusted` + todas las interfaces |
| Homepage | Sin autenticación | Solo dashboard interno — no lo expongas a WAN. Bajo **`shared`**, Flixbox **elimina** los bloques de widgets admin de *arr/qBit/Bazarr/Maintainerr/Byparr, apunta esas tarjetas a `http://127.0.0.1:<port>` (Forms solo en el host) y no inyecta sus secretos; los widgets de Jellyfin/Seerr pueden seguir sincronizándose. La sync corre en `init`/`up`/`reload`/`configure`. |
| Jellyfin / Seerr | Apps del hogar en LAN | Cuentas por usuario; no compartas `FLIXBOX_ADMIN_PASSWORD` |

Ver [ADR 0018](../../adr/0018-runtime-secrets-and-lan-trust.md).

<a id="related"></a>
## Relacionado

- [Configuration reference](06-configuration.md)
- [First-run setup](05-first-run.md)
- [Privacidad y seguridad BitTorrent](12-torrent-privacy-and-security.md)
