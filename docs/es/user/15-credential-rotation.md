<a id="credential-rotation-runbook"></a>
# Runbook de rotación de credenciales

**Idiomas:** [English](../../user/15-credential-rotation.md) · Español (esta página)

Recuperación paso a paso cuando cambian passwords o API keys — por accidente o a propósito. Para el mapa de credenciales, ver [Configuration — Credentials](06-configuration.md#credentials-and-api-keys).

**Prefiere la CLI (ADR 0020)**

```bash
./bin/flixbox credentials show qbit|arr-ui|admin
./bin/flixbox credentials show api radarr|sonarr|prowlarr
./bin/flixbox credentials set qbit --generate|--prompt
./bin/flixbox credentials set arr-ui --generate|--prompt   # shared only
./bin/flixbox credentials set admin --generate|--prompt
```

**Principios**

1. **Fuente de verdad:** `.env` para el login WebUI de qBit, `FLIXBOX_ADMIN_*`, `FLIXBOX_ARR_UI_*` (Forms en shared), y API keys *arr (tras que `configure` sincronice desde `config.xml`); la API key de qBit vive en la config de qBit (no en `.env`).
2. **`configure` usa API keys** en `127.0.0.1` — Forms solo se aplica vía `credentials set arr-ui` o `configure --sync-arr-ui`.
3. Tras cambiar secretos en `.env` a mano, recrea los contenedores de higiene cuando `configure` reporte escrituras en `.env` o usa `--sync-qbit-auth` / `--sync-arr-ui` según corresponda.

---

<a id="quick-reference"></a>
## Referencia rápida

| Credencial | Disparador típico | Arreglo principal |
| --- | --- | --- |
| Password WebUI de qBit | Cambio manual o rotación | **Rotar:** `credentials set qbit`. **Alinear** (`.env` ya coincide con el WebUI): `configure --sync-qbit-auth` |
| API key de qBit | Regenerar en la UI de qBit | `configure` (sanar drift) o `--sync-qbit-auth` |
| API key de Radarr / Sonarr | Regenerar en la UI *arr | `configure` → actualiza YAML de Maintainerr / Recyclarr si hace falta |
| API key de Prowlarr | Regenerar en la UI de Prowlarr | `configure` (reescribe `.env` desde la config) |
| API key de Jellyfin | Revocar / nueva key en Jellyfin | Recréala en la UI de Jellyfin → actualiza Seerr / Maintainerr a mano |
| `FLIXBOX_ADMIN_PASSWORD` | Rotación del operador | `credentials set admin` **o** actualiza `.env` → alinea UI de Jellyfin / `configure` |
| `FLIXBOX_ARR_UI_*` (`shared`) | Política de password de compañeros de piso | `credentials set arr-ui` **o** `configure --sync-arr-ui` |
| Perfil de acceso | `trusted` ↔ `shared` | Cambia `.env` → `up` / `reload` / `configure` (auto-sync + recreate de servicios admin) |

---

<a id="qbittorrent-webui-password"></a>
## Password WebUI de qBittorrent

**Rotar** (cambiar la password que gestiona Flixbox):

1. `./bin/flixbox credentials set qbit --generate` (o `--prompt`).
2. La CLI autentica con la password **actual** de `.env` (o temp de sesión), aplica la nueva password a qBit, **luego** escribe `.env`, y recrea Decluttarr.
3. Si la verificación de re-auth falla después de que qBit aceptó el cambio, la CLI igual persiste `.env` y avisa — confirma el WebUI con `credentials show qbit`.
4. Confirma que los logs de Decluttarr muestran qBit OK (no idle).
5. Si el Test del download-client *arr falla: `./bin/flixbox configure --sync-qbit-auth`.

**Alinear** (`.env` ya coincide con una password del WebUI con la que puedes iniciar sesión — p. ej. cambiaste la password en la UI y la copiaste a `.env`):

1. Pon la password **actual** del WebUI en `.env` como `QBITTORRENT_PASSWORD`.
2. `./bin/flixbox configure --sync-qbit-auth`.
3. Confirma Decluttarr / configure idempotente.

Si el login falla y los logs no muestran password temporal: restablece en la UI de qBit o borra `${CONFIG_DIR}/qbittorrent/` (último recurso), alinea `.env` y luego `--sync-qbit-auth`.

---

<a id="qbittorrent-api-key"></a>
## API key de qBittorrent

1. Si regeneraste la key en la UI de qBit, ejecuta `./bin/flixbox configure`.
2. Verifica que Radarr/Sonarr → Download Clients → qBittorrent **Test** pase.
3. Si el Test pasa pero la key está desfasada, ejecuta `./bin/flixbox configure --sync-qbit-auth`.

---

<a id="radarr-or-sonarr-api-key"></a>
## API key de Radarr o Sonarr

1. Tras regenerar en la UI *arr, ejecuta `./bin/flixbox configure` (sincroniza la key desde `config.xml` a `.env`, refresca clientes Prowlarr/Bazarr/Seerr, recrea Decluttarr/Unpackerr cuando haga falta).
2. **Maintainerr:** Settings → actualiza a mano las API keys de conexión Radarr/Sonarr.
3. **Recyclarr:** si `${CONFIG_DIR}/recyclarr/recyclarr.yml` ya no tiene placeholders `REPLACE_*`, edita las keys en ese archivo y luego `docker compose --profile recyclarr run --rm recyclarr sync`.

Mostrar la key actual: `./bin/flixbox credentials show api radarr` (o `sonarr` / `prowlarr`).

---

<a id="prowlarr-api-key"></a>
## API key de Prowlarr

1. Ejecuta `./bin/flixbox configure` tras regenerar (sincroniza `.env` desde la config de Prowlarr).
2. Prowlarr → Apps → las entradas Radarr/Sonarr las refresca `configure` cuando detecta drift.

---

<a id="jellyfin-api-key"></a>
## API key de Jellyfin

1. Jellyfin → Dashboard → **API Keys** → crea o copia la key.
2. Opcional: añádela a `.env` como `JELLYFIN_API_KEY` si `configure` creó una antes.
3. **Seerr:** reautentica o actualiza la integración Jellyfin si fallan las solicitudes.
4. **Maintainerr:** Settings → Jellyfin → pega la nueva API key.

---

<a id="jellyfin-seerr-admin-password-flixbox_admin_"></a>
## Password admin de Jellyfin / Seerr (`FLIXBOX_ADMIN_*`)

1. Prefiere `./bin/flixbox credentials set admin --generate` (actualiza `.env` + cambio best-effort vía API de Jellyfin).
2. O actualiza `FLIXBOX_ADMIN_*` en `.env` y cambia la password del usuario Jellyfin correspondiente en la UI.
3. Ejecuta `./bin/flixbox configure` si el cableado de auth Jellyfin en Seerr necesita un refresh.

---

<a id="shared-profile-arr-forms-users-flixbox_arr_ui_"></a>
## Perfil shared — usuarios Forms *arr (`FLIXBOX_ARR_UI_*`)

Servarr no lee username/password de Forms desde el env de Compose. `.env` guarda la SoT; aplica vía Host Config:

1. `./bin/flixbox credentials set arr-ui --generate` — la aplicación Host Config corre **antes** de escribir `.env` (no escribe si fallan las tres apps).
2. O edita `.env` y luego `./bin/flixbox configure --sync-arr-ui` para empujar los valores SoT existentes.
3. Si la aplicación falla, crea/cambia el login Forms en **cada** UI de Radarr, Sonarr y Prowlarr por separado.
4. `configure` (sin `--sync-arr-ui`) sigue funcionando vía API keys — no hace falta login Forms para la automatización.

---

<a id="access-profile-change-trusted-shared"></a>
## Cambio de perfil de acceso (`trusted` ↔ `shared`)

1. Define `FLIXBOX_ACCESS_PROFILE` en `.env`.
2. Ejecuta `./bin/flixbox init --non-interactive` (opcional — asegura `FLIXBOX_ARR_UI_*` al pasar a `shared`).
3. Ejecuta `./bin/flixbox reload`, `up` o `configure` — se sincronizan bind/auth derivados, los servicios admin se recrean ante drift, y se sincronizan los widgets de Homepage (`shared` quita widgets admin).
4. En `shared`, aplica Forms: `./bin/flixbox credentials set arr-ui --generate` — [Perfiles de acceso](13-access-profiles.md#crear-login-arr-shared).

---

<a id="post-rotation-checklist"></a>
## Checklist post-rotación

- [ ] `./bin/flixbox configure` termina con exit 0
- [ ] `./bin/flixbox status` — modo y perfil de acceso coherentes
- [ ] **Test** del download client Radarr/Sonarr OK
- [ ] Decluttarr no idle (creds qBit en `.env`)
- [ ] Los indexers de Prowlarr siguen funcionando (sin cambio por rotación de keys salvo que se rotara la key de Prowlarr)
- [ ] Conexiones Maintainerr / Seerr probadas si cambiaron sus keys upstream
- [ ] Sync de Recyclarr si editaste keys YAML a mano
- [ ] Bajo `shared`, el login Forms funciona tras `credentials set arr-ui` / `--sync-arr-ui`

---

<a id="related"></a>
## Relacionado

- [Configuration — Accidental / intentional key changes](06-configuration.md#accidental--intentional-key-changes)
- [Troubleshooting](10-troubleshooting.md)
- [ADR 0015 — Access profiles](../../adr/0015-access-profiles.md)
- [ADR 0020 — Operator credentials CLI](../../adr/0020-operator-credentials-cli.md)
