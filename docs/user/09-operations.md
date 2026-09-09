# Day-2 operations

## Status and logs

```bash
./bin/flixbox status
./bin/flixbox logs
./bin/flixbox logs sonarr -f
```

## Restart a service

```bash
./bin/flixbox restart radarr
```

## Stop the stack

```bash
./bin/flixbox down
```

## Updates

Planned:

```bash
./bin/flixbox update
```

Until that exists: pull images and recreate containers carefully; prefer pinned tags in production.

## Backups

Config lives under `${CONFIG_DIR}`. Prefer SQLite-safe backups (`scripts/backup.sh`; not yet wrapped as `flixbox backup`). Always stop or use live-safe tools before copying DB files blindly.

## Hardlink health check

After an import:

```bash
ls -i ${DATA_DIR}/torrents/movies/example.mkv
ls -i ${DATA_DIR}/media/movies/Example\ \(2024\)/example.mkv
```

Same inode ⇒ hardlink worked.

## Changing paths and storage layout

Flixbox uses **two path layers**:

```text
Host:  ${DATA_DIR}/torrents/...     ${DATA_DIR}/media/...
         │ mount                           │
Container:  /data/torrents/...         /data/media/...
```

Inside containers, paths are always under **`/data/...`**. Editing `DATA_DIR` in `.env` only changes **which host directory** is mounted at `/data` — not the in-container paths.

**Most apps do not auto-update** when you change storage. Only qBittorrent paths are reconciled on container start (via `${CONFIG_DIR}/qbittorrent-cont-init` → `/custom-cont-init.d`). Radarr, Sonarr, Jellyfin, and others keep paths in their **own config databases** until you change them in each UI.

### What updates automatically vs manually

| Change | qBittorrent | Radarr / Sonarr | Jellyfin | Bazarr | Homepage | Unpackerr |
| --- | --- | --- | --- | --- | --- | --- |
| Fix linuxserver `/downloads/` defaults | **Restart** qBit (init hook) or `FLIXBOX_QBIT_FORCE_PATHS=true` | No | No | No | No | No |
| Change `QBITTORRENT_PORT` (host) | Compose remap; hook fixes WebUI | Download client stays `qbittorrent:8080` | — | — | **Manual:** `services.yaml` | — |
| Move `DATA_DIR` to another host path (same tree) | Restart enough if mount ok | **Manual:** verify root folders still `/data/media/...` | **Manual:** verify libraries | Re-link *arr in UI | No | `./bin/flixbox up` |
| Change in-container layout (e.g. new root folder path) | Hook only if legacy `/downloads/` or `FORCE_PATHS` | **Manual:** Settings → Media Management → Root folders | **Manual:** Libraries | **Manual** | No | No |
| Move `CONFIG_DIR` | — | **Migration:** copy `${CONFIG_DIR}` tree; paths inside DB unchanged | Same | Same | Copy homepage yaml | — |

### Migrating `DATA_DIR` to a new disk (checklist)

1. **Stop the stack:** `./bin/flixbox down`
2. **Copy the data tree** (preserves hardlinks if same filesystem copy method):

   ```bash
   rsync -aHAX --info=progress2 "${OLD_DATA}/" "${NEW_DATA}/"
   ```

3. **Update `.env`:** `DATA_DIR=${NEW_DATA}` (keep layout: `torrents/`, `media/`).
4. **Start:** `./bin/flixbox up`
5. **qBittorrent:** `docker compose up -d --force-recreate qbittorrent` — verify **Options → Downloads** → `/data/torrents/` (plain `restart` is enough only if the cont-init mount already exists).
6. **Radarr / Sonarr:** Settings → confirm root folders `/data/media/movies` and `/data/media/tv`; test download client.
7. **Jellyfin:** Dashboard → Libraries → paths still under `/data/media/...`.
8. **Seerr / Maintainerr / Bazarr:** confirm linked servers and paths if prompted.
9. **Hardlink check** (below) on a recent import.

If you only **rename host paths** but keep the same in-container `/data/...` layout, steps 6–8 are usually verification only. If imports break or libraries look empty, root folders or libraries still point at an old mental model — re-add using `/data/...` paths.

### Forcing qBittorrent paths back to defaults

In `.env`:

```bash
FLIXBOX_QBIT_FORCE_PATHS=true
```

Then `./bin/flixbox up` and `docker compose restart qbittorrent`. Set back to `false` after verification unless you want enforced paths on every start.

### Related

- First-run path defaults: [05 — First-run §2c](05-first-run.md#2c-download-paths-automatic)
- Env reference: [06 — Configuration](06-configuration.md)
- Hardlinks / filesystem: [02 — How it works](02-how-it-works.md)

## MVP smoke test (before v0.1)

Full checklist and automated helper:

```bash
./scripts/smoke-test.sh preflight   # no containers
./scripts/smoke-test.sh run         # init + up + HTTP probes (Direct)
./scripts/smoke-test.sh down
```

See [11 — Smoke test](11-smoke-test.md).

## Quality profiles

```bash
./bin/flixbox sync-profiles --dry-run   # planned
./bin/flixbox sync-profiles             # planned
```

## Next

[Troubleshooting](10-troubleshooting.md)
