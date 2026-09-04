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
# shared → init generates FLIXBOX_ARR_UI_* (apply via credentials set arr-ui):
# FLIXBOX_ARR_UI_USER=admin
# FLIXBOX_ARR_UI_PASSWORD=...
# FLIXBOX_ADMIN_BIND_IP=127.0.0.1   # set by init from profile — do not hand-edit
```

After changing profile:

```bash
# up / reload / configure auto-sync derived bind + auth keys into .env
# and force-recreate admin-bound services when derived keys drifted
./bin/flixbox reload
# Optional: re-run init so shared FLIXBOX_ARR_UI_* placeholders are generated if empty
./bin/flixbox init --non-interactive
./bin/flixbox reload
./bin/flixbox credentials set arr-ui --generate
```

When switching to **`shared`**, `up` / `configure` / `reload` also ensure **`FLIXBOX_ARR_UI_USER`** and **`FLIXBOX_ARR_UI_PASSWORD`** exist in `.env` (generated if empty). They also sync Homepage (`services.yaml`): under **`shared`**, admin widget blocks are removed so LAN-reachable Homepage does not keep *arr/qBit secrets. Apply Forms with:

```bash
./bin/flixbox credentials set arr-ui --generate   # or --prompt
# equivalent force-push during configure:
./bin/flixbox configure --sync-arr-ui
```

`./bin/flixbox configure` (without `--sync-arr-ui`) uses **API keys** on `127.0.0.1` — it does not apply Forms on every run.

## Create *arr login (`shared`)

Servarr has **no environment variable** for Forms username/password ([Servarr env docs](https://wiki.servarr.com/sonarr/environment-variables)). Flixbox applies Forms via the Host Config API (ADR 0020).

With `FLIXBOX_ACCESS_PROFILE=shared`, `init` generates **`FLIXBOX_ARR_UI_USER`** and **`FLIXBOX_ARR_UI_PASSWORD`** as the source of truth.

**After** `./bin/flixbox up` and `./bin/flixbox configure`:

1. Apply Forms: `./bin/flixbox credentials set arr-ui --generate` (or `configure --sync-arr-ui` if values already in `.env`).
2. On the **host** (or via SSH tunnel), open **Radarr**, **Sonarr**, and **Prowlarr** at `http://127.0.0.1:<port>` and sign in with `FLIXBOX_ARR_UI_*` (`./bin/flixbox credentials show arr-ui`).
3. If Host Config apply fails, create the Forms account manually in each WebUI using the same values — each app has its own user store.

**Order matters:** run `configure` **before** relying on Forms so API wiring completes without browser wizards blocking automation.

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

## Threat model (homelab)

Flixbox MVP assumes **one trusted operator** on the Docker host:

| Surface | Risk | Mitigation |
| --- | --- | --- |
| Docker socket / `docker inspect` | Env secrets (API keys, passwords) visible | Limit host access; treat `config/` backups like `.env` |
| `trusted` profile + `0.0.0.0` bind | *arr admin UIs open on LAN without login | Use `shared` on guest Wi‑Fi; `./bin/flixbox up` warns on `trusted` + all interfaces |
| Homepage | No authentication | Internal dashboard only — do not expose to WAN. Under **`shared`**, Flixbox **removes** *arr/qBit/Bazarr/Maintainerr/Byparr admin widget blocks from Homepage (LAN-reachable) and does not inject their secrets; Jellyfin/Seerr widgets may still sync. Sync runs on `init`/`up`/`reload`/`configure`. |
| Jellyfin / Seerr | Household apps on LAN | Per-user accounts; do not share `FLIXBOX_ADMIN_PASSWORD` |

See [ADR 0018](../adr/0018-runtime-secrets-and-lan-trust.md).

## Related

- [Configuration reference](06-configuration.md)
- [First-run setup](05-first-run.md)
- [Torrent privacy and security](12-torrent-privacy-and-security.md)
