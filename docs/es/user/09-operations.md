<a id="day-2-operations"></a>
# Operación día a día

**Idiomas:** [English](../../user/09-operations.md) · Español (esta página)

<a id="status-and-logs"></a>
## Status y logs

```bash
./bin/flixbox status
./bin/flixbox logs
./bin/flixbox logs sonarr -f
```

<a id="restart-a-service"></a>
## Reiniciar un servicio

```bash
./bin/flixbox restart radarr
```

<a id="stop-the-stack"></a>
## Parar el stack

```bash
./bin/flixbox down
```

## Updates

Planificado:

```bash
./bin/flixbox update
```

Hasta que exista: haz pull de las imágenes y recrea contenedores con cuidado; en producción prefiere tags fijados (pinned).

## Backups

La config vive bajo `${CONFIG_DIR}`. Prefiere backups seguros para SQLite (`scripts/backup.sh`; aún no envuelto como `flixbox backup`). Siempre detén el stack o usa herramientas live-safe antes de copiar archivos de DB a ciegas.

<a id="hardlink-health-check"></a>
## Comprobación de salud de hardlinks

Tras un import:

```bash
ls -i ${DATA_DIR}/torrents/movies/example.mkv
ls -i ${DATA_DIR}/media/movies/Example\ \(2024\)/example.mkv
```

Mismo inode ⇒ el hardlink funcionó.

<a id="changing-paths-and-storage-layout"></a>
## Cambiar rutas y layout de almacenamiento

Flixbox usa **dos capas de rutas**:

```text
Host:  ${DATA_DIR}/torrents/...     ${DATA_DIR}/media/...
         │ mount                           │
Container:  /data/torrents/...         /data/media/...
```

Dentro de los contenedores, las rutas están siempre bajo **`/data/...`**. Editar `DATA_DIR` en `.env` solo cambia **qué directorio del host** se monta en `/data` — no las rutas dentro del contenedor.

**La mayoría de las apps no se auto-actualizan** cuando cambias el almacenamiento. Solo las rutas de qBittorrent se reconcilian al arrancar el contenedor (vía `${CONFIG_DIR}/qbittorrent-cont-init` → `/custom-cont-init.d`). Radarr, Sonarr, Jellyfin y otras guardan rutas en sus **propias bases de config** hasta que las cambies en cada UI.

<a id="what-updates-automatically-vs-manually"></a>
### Qué se actualiza solo vs a mano

| Cambio | qBittorrent | Radarr / Sonarr | Jellyfin | Bazarr | Homepage | Unpackerr |
| --- | --- | --- | --- | --- | --- | --- |
| Corregir defaults linuxserver `/downloads/` | **Restart** qBit (init hook) o `FLIXBOX_QBIT_FORCE_PATHS=true` | No | No | No | No | No |
| Cambiar `QBITTORRENT_PORT` (host) | Remap Compose; el hook arregla WebUI | El cliente de descarga sigue en `qbittorrent:8080` | — | — | **Manual:** `services.yaml` | — |
| Mover `DATA_DIR` a otra ruta del host (mismo árbol) | Bastante con restart si el mount está bien | **Manual:** verifica que root folders sigan `/data/media/...` | **Manual:** verifica libraries | Re-enlaza *arr en la UI | No | `./bin/flixbox up` |
| Cambiar layout dentro del contenedor (p. ej. nueva ruta de root folder) | Hook solo si legacy `/downloads/` o `FORCE_PATHS` | **Manual:** Settings → Media Management → Root folders | **Manual:** Libraries | **Manual** | No | No |
| Mover `CONFIG_DIR` | — | **Migración:** copia el árbol `${CONFIG_DIR}`; las rutas dentro de la DB no cambian | Igual | Igual | Copia homepage yaml | — |

<a id="migrating-data_dir-to-a-new-disk-checklist"></a>
### Migrar `DATA_DIR` a un disco nuevo (checklist)

1. **Parar el stack:** `./bin/flixbox down`
2. **Copia el árbol de datos** (preserva hardlinks si el método de copia es del mismo filesystem):

   ```bash
   rsync -aHAX --info=progress2 "${OLD_DATA}/" "${NEW_DATA}/"
   ```

3. **Actualiza `.env`:** `DATA_DIR=${NEW_DATA}` (mantén el layout: `torrents/`, `media/`).
4. **Arranca:** `./bin/flixbox up`
5. **qBittorrent:** `docker compose up -d --force-recreate qbittorrent` — verifica **Options → Downloads** → `/data/torrents/` (un `restart` simple basta solo si el mount cont-init ya existe).
6. **Radarr / Sonarr:** Settings → confirma root folders `/data/media/movies` y `/data/media/tv`; prueba el cliente de descarga.
7. **Jellyfin:** Dashboard → Libraries → las rutas siguen bajo `/data/media/...`.
8. **Seerr / Maintainerr / Bazarr:** confirma servidores enlazados y rutas si te lo pide.
9. **Comprobación de hardlink** (abajo) en un import reciente.

Si solo **renombras rutas del host** pero mantienes el mismo layout `/data/...` dentro del contenedor, los pasos 6–8 suelen ser solo verificación. Si los imports fallan o las libraries se ven vacías, los root folders o libraries aún apuntan a un modelo mental viejo — vuelve a agregarlos con rutas `/data/...`.

<a id="forcing-qbittorrent-paths-back-to-defaults"></a>
### Forzar las rutas de qBittorrent a los defaults

En `.env`:

```bash
FLIXBOX_QBIT_FORCE_PATHS=true
```

Luego `./bin/flixbox up` y `docker compose restart qbittorrent`. Vuelve a `false` tras verificar, salvo que quieras rutas forzadas en cada arranque.

<a id="related"></a>
### Relacionado

- Defaults de rutas en first-run: [05 — First-run §2c](05-first-run.md#2c-download-paths-automatic)
- Referencia de env: [06 — Configuración](06-configuration.md)
- Hardlinks / filesystem: [02 — Cómo funciona](02-how-it-works.md)

<a id="mvp-smoke-test-before-v01"></a>
## Smoke test MVP (antes de v0.1)

Checklist completo y helper automatizado:

```bash
./scripts/smoke-test.sh preflight   # no containers
./scripts/smoke-test.sh run         # init + up + HTTP probes (Direct)
./scripts/smoke-test.sh down
```

Ver [11 — Smoke test](11-smoke-test.md).

## Quality profiles

```bash
./bin/flixbox sync-profiles --dry-run   # planned
./bin/flixbox sync-profiles             # planned
```

<a id="next"></a>
## Siguiente

[Troubleshooting](10-troubleshooting.md)
