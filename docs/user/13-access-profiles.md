# Access profiles

LAN auth policy for *arr admin UIs. See [ADR 0015](../adr/0015-access-profiles-and-remote-transport.md).

## Profiles

Set in `.env` before `up`:

| Profile | When to use | *arr WebUI from another device on `192.168.x.x` |
| --- | --- | --- |
| `trusted` (default) | You trust everyone on your Wi‑Fi | No login (RFC1918 bypass) |
| `shared` | Roommates / guests on same network | Login required (`Forms`) |

```env
FLIXBOX_ACCESS_PROFILE=trusted
# shared → also set or let init generate:
# FLIXBOX_ARR_UI_USER=admin
# FLIXBOX_ARR_UI_PASSWORD=...
```

After changing profile:

```bash
./bin/flixbox init --non-interactive   # syncs derived auth vars
docker compose up -d --force-recreate prowlarr radarr sonarr
```

`./bin/flixbox configure` uses **API keys** — it does not need *arr UI passwords.

### qBittorrent (all profiles)

| From | WebUI password |
| --- | --- |
| Same server (`127.0.0.1`) | Often skipped (Docker bridge path) |
| Phone/laptop on LAN (`192.168.x.x`) | **Required** (`QBITTORRENT_PASSWORD`) |

### Jellyfin / Seerr

Always use per-person accounts on shared networks. Do not share `FLIXBOX_ADMIN_PASSWORD`.

## Do not publish admin ports to the internet

Radarr, Sonarr, Prowlarr, and qBittorrent WebUI ports are for **LAN or localhost** only unless a future reverse-proxy design is implemented. Profile `trusted` on a shared Wi‑Fi is insecure — use `shared`.

## Related

- [Configuration reference](06-configuration.md)
- [Torrent privacy and security](12-torrent-privacy-and-security.md)
