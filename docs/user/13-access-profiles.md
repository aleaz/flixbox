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
# shared → init generates reference values (create users manually — see below):
# FLIXBOX_ARR_UI_USER=admin
# FLIXBOX_ARR_UI_PASSWORD=...
```

After changing profile:

```bash
./bin/flixbox init --non-interactive   # syncs derived auth vars
docker compose up -d --force-recreate prowlarr radarr sonarr
```

`./bin/flixbox configure` uses **API keys** — it does not create *arr Forms users or need UI passwords.

## Create *arr login (`shared`)

Servarr has **no environment variable** for Forms username/password ([Servarr env docs](https://wiki.servarr.com/sonarr/environment-variables)). Flixbox cannot seed browser login via `configure`.

With `FLIXBOX_ACCESS_PROFILE=shared`, `init` generates **`FLIXBOX_ARR_UI_USER`** and **`FLIXBOX_ARR_UI_PASSWORD`** as **reference values** — use them when each app asks you to create an account on first visit.

**After** `./bin/flixbox up` and `./bin/flixbox configure`:

1. Open **Radarr**, **Sonarr**, and **Prowlarr** in a browser (from the host or another device on your LAN).
2. On first visit, each app shows a **create account** or **sign in** screen (Forms auth).
3. Create the admin user with the same username/password as in `.env` (`FLIXBOX_ARR_UI_*`).
4. Repeat for all three apps — each has its own user database.

If login fails, confirm you created the user in **that** app (not only in Radarr). Reset via the app’s own auth settings if needed.

**Order matters:** run `configure` **before** creating Forms users so API wiring completes without browser wizards blocking automation.

### qBittorrent (all profiles)

| From | WebUI password |
| --- | --- |
| Same server (`127.0.0.1`) | Often skipped (Docker bridge path) |
| Phone/laptop on LAN (`192.168.x.x`) | **Required** (`QBITTORRENT_PASSWORD`) |

### Jellyfin / Seerr

Always use per-person accounts on shared networks. Do not share `FLIXBOX_ADMIN_PASSWORD`.

## Do not publish admin ports to the internet

Radarr, Sonarr, Prowlarr, and qBittorrent WebUI ports are for **LAN or localhost** only unless a future reverse-proxy design is implemented. Profile `trusted` on a shared Wi‑Fi is insecure — use `shared`.

Byparr and Bazarr are not covered by *arr Forms auth; treat them as admin surfaces on a shared LAN (future: localhost-only bind — ADR 0015 phase 2).

## Related

- [Configuration reference](06-configuration.md)
- [First-run setup](05-first-run.md)
- [Torrent privacy and security](12-torrent-privacy-and-security.md)
