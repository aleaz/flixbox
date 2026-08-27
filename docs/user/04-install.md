# Install

> **Implementation status:** Direct-mode Compose (qBittorrent) is available. The Bash CLI (`bin/flixbox`) arrives in Phase 5. VPN mode is next.

## Current bootstrap (Direct mode)

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Edit DATA_DIR / CONFIG_DIR / TZ / PUID / PGID if needed
./scripts/bootstrap-dirs.sh
docker compose --profile direct up -d
```

Ensure `.env` has `COMPOSE_PROFILES=direct` (default in `.env.example`), or pass `--profile direct` as above.

Open qBittorrent: http://localhost:8080  
(linuxserver prints the temporary WebUI password in container logs on first start.)

Set download paths in the WebUI:

- Default save path: `/data/torrents`
- Keep incomplete torrents in: `/data/torrents/incomplete`

```bash
docker compose --profile direct ps
docker compose --profile direct logs -f qbittorrent
docker compose --profile direct down
```

## Target UX (Phase 5+)

```bash
./bin/flixbox init
./bin/flixbox up
./bin/flixbox status
```

## Default ports (so far)

| Service | URL |
| --- | --- |
| qBittorrent (Direct) | http://localhost:8080 |

Full matrix (planned services): [Configuration](06-configuration.md).

## Next

[First-run setup](05-first-run.md) (full stack wiring — as more modules land).
