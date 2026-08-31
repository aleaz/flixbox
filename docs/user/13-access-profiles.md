# Access profiles

LAN auth policy for admin UIs. See [ADR 0015](../adr/0015-access-profiles.md).

## Profiles

Set in `.env` before `up`:

| Profile | When to use | *arr WebUI from another device on `192.168.x.x` | Admin ports bind |
| --- | --- | --- | --- |
| `trusted` (default) | You trust everyone on your Wi‑Fi | No login (RFC1918 bypass) | All interfaces (`0.0.0.0`) |
| `shared` | Roommates / guests on same network | Login required (`Forms`) + **localhost-only** publish | `127.0.0.1` only |

```env
FLIXBOX_ACCESS_PROFILE=trusted
# shared → init generates reference values (create users manually — see below):
# FLIXBOX_ARR_UI_USER=admin
# FLIXBOX_ARR_UI_PASSWORD=...
# FLIXBOX_ADMIN_BIND_IP=127.0.0.1   # set by init from profile — do not hand-edit
```

After changing profile:

```bash
# up / reload / configure auto-sync derived bind + auth keys into .env
./bin/flixbox reload
# Optional: also re-run init so shared UI password placeholders are generated if empty
./bin/flixbox init --non-interactive
./bin/flixbox reload
```

`./bin/flixbox configure` uses **API keys** on `127.0.0.1` — it does not create *arr Forms users or need UI passwords.

## Create *arr login (`shared`)

Servarr has **no environment variable** for Forms username/password ([Servarr env docs](https://wiki.servarr.com/sonarr/environment-variables)). Flixbox cannot seed browser login via `configure`.

With `FLIXBOX_ACCESS_PROFILE=shared`, `init` generates **`FLIXBOX_ARR_UI_USER`** and **`FLIXBOX_ARR_UI_PASSWORD`** as **reference values** — use them when each app asks you to create an account on first visit.

**After** `./bin/flixbox up` and `./bin/flixbox configure`:

1. On the **host** (or via SSH tunnel), open **Radarr**, **Sonarr**, and **Prowlarr** at `http://127.0.0.1:<port>` (LAN devices cannot reach admin ports in `shared`).
2. On first visit, each app shows a **create account** or **sign in** screen (Forms auth).
3. Create the admin user with the same username/password as in `.env` (`FLIXBOX_ARR_UI_*`).
4. Repeat for all three apps — each has its own user database.

If login fails, confirm you created the user in **that** app (not only in Radarr). Reset via the app’s own auth settings if needed.

**Order matters:** run `configure` **before** creating Forms users so API wiring completes without browser wizards blocking automation.

### Admin surfaces bound to localhost in `shared`

| Service | Host reachability in `shared` |
| --- | --- |
| Prowlarr, Radarr, Sonarr, Bazarr | `127.0.0.1` only |
| Byparr | `127.0.0.1` only (Prowlarr still uses `http://byparr:8191` on Docker net) |
| Maintainerr | `127.0.0.1` only |
| qBittorrent WebUI | `127.0.0.1` only (BitTorrent listen port stays published) |
| Jellyfin, Seerr, Homepage | Still on LAN (household consumers) |

### qBittorrent (all profiles)

| From | WebUI password |
| --- | --- |
| Same server (`127.0.0.1`) | Often skipped (Docker bridge path) |
| Phone/laptop on LAN (`192.168.x.x`) | **Required** when published (`trusted`). Unreachable host port in `shared`. |

### Jellyfin / Seerr

Always use per-person accounts on shared networks. Do not share `FLIXBOX_ADMIN_PASSWORD`.

## Do not publish admin ports to the internet

Radarr, Sonarr, Prowlarr, and qBittorrent WebUI ports are for **LAN or localhost** only unless a future reverse-proxy design is implemented. Profile `trusted` on a shared Wi‑Fi is insecure — use `shared`.

## Related

- [Configuration reference](06-configuration.md)
- [First-run setup](05-first-run.md)
- [Torrent privacy and security](12-torrent-privacy-and-security.md)
