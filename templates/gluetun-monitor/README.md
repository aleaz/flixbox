# Gluetun monitor (optional `vpn-heal` profile)

Watchdog for stranded qBittorrent after Gluetun **container** recreate and prolonged VPN failures.
Uses [gluetun-monitor](https://github.com/csmarshall/gluetun-monitor) via a dedicated Docker socket proxy (POST/EXEC). **Default off.**

## Enable (VPN mode only)

```bash
# FLIXBOX_MODE=vpn must already be running
./bin/flixbox up vpn-heal
# or: COMPOSE_PROFILES=vpn-heal in .env
```

Do **not** enable under `FLIXBOX_MODE=direct` — there is no Gluetun to heal.

## Threat model

- Homepage uses a **read-only** socket proxy (`POST=0`).
- `vpn-heal` adds a **separate** proxy with `POST=1` + `EXEC=1` so the monitor can restart/recreate Gluetun dependents.
- Blast radius is limited to Docker container lifecycle APIs exposed by that proxy — still powerful. Leave the profile off unless you need automated netns recovery.

## Notifications

Optional: set `VPN_HEAL_APPRISE_URLS` in `.env` (Apprise URL schemes).  
With the `notifications` profile you can fan out through the same channels you use for *arr — see `docs/user/18-notifications.md`.

## Manual recovery (no profile)

```bash
docker compose up -d gluetun
# wait healthy
docker compose up -d qbittorrent
./bin/flixbox vpn-test
```
