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

Config lives under `${CONFIG_DIR}`. Prefer SQLite-safe backups (planned `scripts/backup.sh` / `flixbox backup`). Always stop or use live-safe tools before copying DB files blindly.

## Hardlink health check

After an import:

```bash
ls -i ${DATA_DIR}/torrents/movies/example.mkv
ls -i ${DATA_DIR}/media/movies/Example\ \(2024\)/example.mkv
```

Same inode ⇒ hardlink worked.

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
