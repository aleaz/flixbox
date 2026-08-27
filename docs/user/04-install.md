# Install

> **Implementation status:** Direct and VPN downloader modes are available (qBittorrent ± Gluetun). Servarr and `bin/flixbox` land in later phases.

## Bootstrap

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# Edit DATA_DIR, CONFIG_DIR, TZ, PUID/PGID
# Choose mode: FLIXBOX_MODE=direct  OR  FLIXBOX_MODE=vpn (+ VPN_* secrets)
./scripts/bootstrap-dirs.sh
docker compose up -d
```

`compose.yaml` includes `compose/downloaders-${FLIXBOX_MODE}.yml` automatically.

### Direct mode (`FLIXBOX_MODE=direct`)

- Open http://localhost:8080 (qBittorrent)
- *arr download client host later: `qbittorrent`
- Password: see `docker compose logs qbittorrent` on first start

### VPN mode (`FLIXBOX_MODE=vpn`)

1. Set `VPN_ENABLED=true` and fill Gluetun variables in `.env` (see [Gluetun wiki](https://github.com/qdm12/gluetun-wiki)).
2. `docker compose up -d` — qBittorrent starts only after Gluetun is **healthy**.
3. WebUI still on http://localhost:8080 (published on **Gluetun**).
4. *arr / Decluttarr download client host: **`gluetun`** (not `qbittorrent`).
5. In qBittorrent WebUI, enable **Bypass authentication for clients on localhost** if you use VPN port forwarding.
6. Check tunnel: `./scripts/vpn-test.sh`

### qBittorrent paths (both modes)

- Default save path: `/data/torrents`
- Incomplete: `/data/torrents/incomplete`

```bash
docker compose ps
docker compose logs -f
docker compose down
./scripts/vpn-test.sh
```

## Target UX (Phase 5+)

```bash
./bin/flixbox init
./bin/flixbox up
./bin/flixbox vpn-test
```

## Ports (downloaders)

| Service | URL / port |
| --- | --- |
| qBittorrent WebUI | http://localhost:8080 |

## Next

[VPN and Direct](07-vpn-and-direct.md) · [First-run setup](05-first-run.md)
