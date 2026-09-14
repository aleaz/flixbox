<a id="mvp-smoke-test-checklist"></a>
# Checklist de smoke test

**Idiomas:** [English](../../user/11-smoke-test.md) · Español (esta página)

Usa este checklist para validar que el stack funciona en un host real, no solo que Compose resuelve en CI.

**Plataforma de referencia:** Linux x86_64 o ARM64 con Docker Engine + Compose v2. WSL2 (rutas ext4) y macOS (**OrbStack** o Docker Desktop) son best-effort — las pruebas de hardlink pueden ser inconclusas en macOS.

<a id="quick-automated-preflight"></a>
## Preflight automatizado rápido

Desde la raíz del repo:

```bash
./scripts/ci-validate.sh          # contract checks (no containers)
./scripts/ci-smoke-init.sh        # C-50–52 + env-file unit (worktree; safe with stack up)
./scripts/smoke-test.sh preflight   # docker + compose config
```

**Idempotencia (stack en ejecución):** tras el primer `./bin/flixbox configure`, una segunda ejecución debería reportar **`0` updated** (todo unchanged). Si no, abre un issue con ambas salidas.

**Listo day-2:** `./bin/flixbox doctor` (hardlink/NFS/exFAT + Docker/VPN). Preferí doctor antes de culpar a Compose si fallan imports o SQLite — [17 — CLI](17-cli.md) · [09 — Operaciones](09-operations.md#hardlink-health-check).

<a id="full-automated-smoke-direct-mode-trusted"></a>
## Smoke automatizado completo (modo Direct, `trusted`)

Usa `/tmp/flixbox-smoke` para data/config de modo que no necesites `/srv/flixbox`:

```bash
./scripts/smoke-test.sh run
```

Esto ejecuta `init`, `up`, probes HTTP, e imprime los pasos manuales que aún hacen falta.

Si ya tienes un `.env` en la raíz del repo, `run` **hace backup y lo restaura al salir** — durante el test solo se usan las rutas de smoke bajo `/tmp/flixbox-smoke` para data/config.

Para bajar el stack:

```bash
./scripts/smoke-test.sh down
```

---

<a id="phase-a-bootstrap-automated-spot-check"></a>
## Fase A — Bootstrap (automatizado + spot-check)

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| A1 | `init` completa | `./bin/flixbox init --non-interactive` | Sin errores; dirs + templates existen |
| A2 | Árbol de datos | `ls ${DATA_DIR}/torrents/incomplete` | El directorio existe |
| A3 | Templates copiados | `ls ${CONFIG_DIR}/homepage/services.yaml` | El archivo existe |
| A4 | URL Decluttarr | `grep DECLUTTARR_QBIT_URL .env` | `http://qbittorrent:8080` (VPN y Direct) |
| A5 | Defaults del perfil de acceso | `grep FLIXBOX_ACCESS_PROFILE .env` | `trusted`; `FLIXBOX_ADMIN_BIND_IP=0.0.0.0` |
| A6 | Warnings de rutas inseguras | Define `DATA_DIR=/mnt/c/test` y ejecuta `init` | La CLI avisa (WSL NTFS) |

<a id="phase-b-stack-up-direct-mode-trusted"></a>
## Fase B — Stack up (modo Direct, `trusted`)

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| B1 | Todos los contenedores core en ejecución | `./bin/flixbox status` | 12 servicios up (sin gluetun) |
| B2 | WebUI qBittorrent | `http://localhost:8080` | Carga la página de login |
| B3 | Prowlarr | `:9696` | Carga la UI |
| B4 | Radarr / Sonarr | `:7878` / `:8989` | Carga la UI (sin login Forms en LAN) |
| B5 | Jellyfin | `:8096` | Carga setup o dashboard |
| B6 | Seerr | `:5055` | Carga la UI |
| B7 | Homepage | `:3000` | Carga el dashboard |
| B8 | Maintainerr | `:6246` | Carga la UI |
| B9 | Byparr | `:8191` | Responde health/status |
| B10 | `configure` | `./bin/flixbox configure` | Exit 0 tras la espera; re-ejecución idempotente |

Servicios Direct esperados: `bazarr`, `byparr`, `decluttarr`, `homepage`, `jellyfin`, `maintainerr`, `prowlarr`, `qbittorrent`, `radarr`, `seerr`, `sonarr`, `unpackerr`.

<a id="phase-bʹ-access-profile-shared-manual-before-v01"></a>
## Fase Bʹ — Perfil de acceso `shared` (manual)

Se recomiendan rutas frescas (o recrear *arr + servicios bound a admin tras el cambio de perfil).

```bash
# In .env:
FLIXBOX_ACCESS_PROFILE=shared
./bin/flixbox init --non-interactive
./bin/flixbox reload
./bin/flixbox configure
```

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| S1 | Env derivado | `grep -E 'FLIXBOX_ARR_AUTH_|FLIXBOX_ADMIN_BIND' .env` | `Forms` + `Enabled` + `127.0.0.1` |
| S2 | Bind del host | `ss -lntp \| grep -E '7878\|8989\|9696\|8191\|8080'` (o `docker port`) | Listen en `127.0.0.1`, no `0.0.0.0` |
| S3 | LAN bloqueada | Desde otro dispositivo LAN, abre `http://<host>:7878` | Connection refused / timeout |
| S4 | Host OK | En el servidor: `http://127.0.0.1:7878` | Forms / UI de create-account |
| S5 | Usuarios Forms (`shared`) | `./bin/flixbox credentials set arr-ui --generate` (o `--sync-arr-ui`) | El login funciona con `credentials show arr-ui`; `configure` sigue OK vía API keys |
| S6 | Consumidores en LAN | Jellyfin `:8096`, Seerr `:5055`, Homepage `:3000` desde LAN | Siguen alcanzables |
| S7 | Byparr | LAN `:8191` | Inalcanzable; el proxy de indexer de Prowlarr sigue funcionando |

Ver [Perfiles de acceso](13-access-profiles.md).

<a id="phase-c-storage-contract-manual"></a>
## Fase C — Contrato de almacenamiento (manual)

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| C1 | Rutas qBit | qBittorrent → Downloads | `/data/torrents`, incomplete `/data/torrents/incomplete` |
| C2 | Root folders *arr | Settings de Radarr/Sonarr | `/data/media/movies`, `/data/media/tv` |
| C3 | Prueba de hardlink | Importa un release; compara inodes | Mismo inode en `torrents/` y `media/` |
| C4 | Libraries Jellyfin | Libraries apuntan a `/data/media/...` | Medios visibles tras el import |

Comprobación de inode hardlink:

```bash
ls -i "${DATA_DIR}/torrents/movies/"*/*.mkv 2>/dev/null | head -1
ls -i "${DATA_DIR}/media/movies/"*/*.mkv 2>/dev/null | head -1
```

Mismo número inicial ⇒ hardlink OK.

<a id="phase-d-vpn-mode-optional-needs-provider-creds"></a>
<a id="phase-d--vpn-mode-optional-needs-provider-creds"></a>
## Fase D — Modo VPN (opcional, necesita creds del provider)

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| D1 | Cambiar modo | `FLIXBOX_MODE=vpn` en `.env`, rellena secretos Gluetun, `./bin/flixbox up` (no hace falta `down` aparte — `--remove-orphans`) | `gluetun` + `qbittorrent` healthy |
| D1b | Huérfanos limpiados | Desde VPN, pon `FLIXBOX_MODE=direct`, `./bin/flixbox up` | Contenedor `gluetun` ausente; `qbittorrent` healthy en el bridge |
| D2 | qBit vía puerto Gluetun | `http://localhost:8080` (o `127.0.0.1` si `shared`) | Carga la WebUI |
| D3 | Cliente de descarga *arr | Host Radarr/Sonarr `qbittorrent:8080` | Test OK |
| D4 | Prueba de fuga | `./bin/flixbox vpn-test` | IP del contenedor ≠ IP pública del host |
| D5 | Port forward (si el provider lo soporta) | `VPN_PORT_FORWARDING=on` + bypass localhost en qBit | El puerto listen se actualiza en logs de qBit |

Checklist de privacidad y settings qBit: [Privacidad y seguridad BitTorrent](12-torrent-privacy-and-security.md).

<a id="phase-e-hygiene-wiring-manual-after-credentials"></a>
## Fase E — Cableado de higiene (manual, tras credenciales)

Referencia: [Credenciales y API keys](06-configuration.md#credentials-and-api-keys) · [Conexiones app-to-app](06-configuration.md#app-to-app-connections).

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| E1 | API keys *arr en `.env` | Prefiere `./bin/flixbox configure` (sincroniza keys) | Logs de Unpackerr/Decluttarr sin errores de auth *arr |
| E1b | Creds qBit para Decluttarr | `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` en `.env` (login WebUI, no API key) | Logs de Decluttarr conectan a qBit (no `idle — set QBITTORRENT_…`) |
| E1c | Recreate tras `.env` | `docker compose up -d --force-recreate decluttarr` | Nuevo env aplicado (solo restart no basta) |
| E2 | Decluttarr | Logs | Conecta a Radarr, Sonarr, qBit |
| E3 | Maintainerr | UI → Jellyfin + Radarr + Sonarr (cada **API key**) | Connection test OK |
| E3b | Seerr | UI → Jellyfin + Radarr + Sonarr (cada **API key**) | Connection test OK |
| E4 | Reglas Maintainerr | Reglas deshabilitadas o preview primero | Sin deletes sorpresa |
| E5 | Recyclarr | `docker compose --profile recyclarr run --rm recyclarr sync` | Sync completa (tras keys en recyclarr.yml) |

<a id="phase-f-end-to-end-request-flow-manual"></a>
<a id="phase-f--end-to-end-request-flow-manual"></a>
## Fase F — Flujo de pedido end-to-end (manual)

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| F1 | Indexers Prowlarr | Agrega indexer de prueba, sync a *arr | La búsqueda funciona en Radarr/Sonarr |
| F2 | Pedido Seerr | Pide una película/serie | Aparece en Radarr/Sonarr |
| F3 | Download + import | Grab releases a qBit | Import a `/data/media` |
| F4 | Reproducción Jellyfin | Reproduce el archivo importado | Streams |

<a id="phase-g-footgun-remediations-adr-0022"></a>
## Fase G — Remediaciones de footgun (ADR 0022)

| # | Check | Cómo | Pass |
|---|-------|-----|------|
| G1 | Huérfanos de modo | Tras D1b (o ida y vuelta Direct↔VPN) | Sin `flixbox-gluetun` residual cuando el modo es `direct` |
| G2 | API Docker de Homepage | UI Homepage → chips Docker / status de servicio | Status resuelve (vía `docker-socket-proxy:2375`, no sock del host) |
| G3 | Proxy healthy antes de Homepage | `docker inspect flixbox-docker-socket-proxy --format '{{.State.Health.Status}}'` tras `up` | `healthy`; Homepage arrancó después del proxy |
| G4 | Gate de ownership Seerr | Temporalmente `chmod 000` o ownership root en `${CONFIG_DIR}/seerr`, ejecuta `./bin/flixbox up` | Exit distinto de cero + pista de troubleshooting UID 1000; restaura perms después |
| G5 | Contrato `docker.yaml` | `grep host: "${CONFIG_DIR}/homepage/docker.yaml"` | `host: docker-socket-proxy` (sin línea `socket:`) |

---

<a id="recording-results"></a>
## Registrar resultados

Copia este bloque a tus release notes o a un log local:

```
Date:
Host OS:
Commit / image pin set:
FLIXBOX_MODE:
FLIXBOX_ACCESS_PROFILE: trusted / shared
DATA_DIR filesystem (df -T):

Phase A:  [ ] pass  [ ] fail  notes:
Phase B:  [ ] pass  [ ] fail  notes:
Phase Bʹ: [ ] pass  [ ] fail  [ ] skipped (trusted-only RC)
Phase C:  [ ] pass  [ ] fail  [ ] skipped (macOS)
Phase D:  [ ] pass  [ ] fail  [ ] skipped (no VPN)
Phase E:  [ ] pass  [ ] fail  notes:
Phase F:  [ ] pass  [ ] fail  notes:
Phase G:  [ ] pass  [ ] fail  notes:  # ADR 0022 footguns
```

**Baseline v0.1:** Las fases A–C y B pasan en Linux (`trusted`). La fase Bʹ (`shared`) se recomienda antes de anunciar el setup Wi‑Fi shared en el README.

Cuando las fases A–C y al menos B pasen en Linux, actualiza el checklist de verificación en [06-development-guide.md](../../06-development-guide.md).

<a id="next"></a>
## Siguiente

[First-run setup](05-first-run.md) · [Perfiles de acceso](13-access-profiles.md) · [Image pins](14-image-pins.md) · [Operación día a día](09-operations.md) · [Troubleshooting](10-troubleshooting.md)
