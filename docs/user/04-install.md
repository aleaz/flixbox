# Install

> **Target experience.** The CLI and Compose modules are not in the repo yet. This is the intended flow once Phase 0–5 land.

## 1. Clone

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
```

## 2. Initialize

```bash
./bin/flixbox init
```

The wizard should ask for:

- Timezone
- `${DATA_DIR}` (default suggestion: `/srv/flixbox/data`)
- `${CONFIG_DIR}` (default suggestion: `/srv/flixbox/config`)
- VPN or Direct mode (+ provider/protocol if VPN)
- Basic permission IDs (`PUID`/`PGID`, usually `1000`)

It creates the directory tree (including `torrents/incomplete`) and a local `.env` that is **not** committed to git.

## 3. Start

```bash
./bin/flixbox up
```

Useful variants (planned):

```bash
./bin/flixbox up core
./bin/flixbox up media
./bin/flixbox status
./bin/flixbox logs
```

## 4. Open the UIs

Default ports (see [Configuration](06-configuration.md)):

| Service | URL |
| --- | --- |
| Homepage | http://localhost:3000 |
| Seerr | http://localhost:5055 |
| Jellyfin | http://localhost:8096 |
| Prowlarr | http://localhost:9696 |
| Radarr | http://localhost:7878 |
| Sonarr | http://localhost:8989 |

## 5. Verify basics

```bash
# VPN mode only
./bin/flixbox vpn-test

# Hardlinks (after a test import) — same inode on both paths
ls -i /srv/flixbox/data/torrents/movies/...
ls -i /srv/flixbox/data/media/movies/...
```

## Next

[First-run setup](05-first-run.md) — wire the apps in the right order.
