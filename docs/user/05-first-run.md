# First-run setup

Do this **once** after `./bin/flixbox init` and `./bin/flixbox up`.

**Estimated time:** ~10–15 minutes with `./bin/flixbox configure` (mostly adding indexers); longer if you wire everything manually.

## Progress

- [ ] `./bin/flixbox init` (generates API keys + passwords into `.env`)
- [ ] `./bin/flixbox up` (VPN mode: wait until Gluetun is healthy)
- [ ] `./bin/flixbox configure` (or `--dry-run` first)
- [ ] **`shared` profile only:** apply Forms with `./bin/flixbox credentials set arr-ui --generate` (or `configure --sync-arr-ui`) — [§13 — Create *arr login](13-access-profiles.md#create-arr-login-shared)
- [ ] Add indexers in Prowlarr (tag `cf` on Cloudflare indexers)
- [ ] Optional: Maintainerr rules, Recyclarr sync, Caddy

Cheat sheet: [Quick reference](REFERENCE.md).

---

## 0. Script-assisted wiring (recommended)

```bash
./bin/flixbox configure
./bin/flixbox configure --dry-run
./bin/flixbox configure --sync-qbit-auth   # after changing qBit password — see [Credentials](06-configuration.md#accidental--intentional-key-changes)
```

On first run right after `up`, the script **waits and retries** (default **15 minutes** total, heartbeats every 10s) before wiring. HTTP and API checks run **in parallel** per pass (typically 1–3 min after `up`, not 15). You should see `Waiting for first-start initialization…` before `Discovering API keys…`. Override: `CONFIGURE_PREFLIGHT_TIMEOUT=1200 ./bin/flixbox configure`.

Preview without API or `.env` changes:

```bash
./bin/flixbox configure --dry-run
```

`--dry-run` prints what would run; it does **not** write `.env`, recreate containers, or call service APIs. It still requires core containers to be up (same as a live run).

**What the script configures (idempotent — safe to re-run):**

| Service | Settings |
| --- | --- |
| qBittorrent | Categories `tv` / `movies`, prefs (TMM, UPnP off, encryption); VPN → bind `tun0`; WebUI password from `.env` |
| Sonarr / Radarr | Root folders, qBittorrent client, NFO metadata, Reject ISO custom format |
| Prowlarr | Byparr proxy when `flixbox-byparr` is running (`http://byparr:8191`, tag `cf`), Radarr + Sonarr app sync |
| Bazarr | Sonarr + Radarr connections, ffsubsync |
| Jellyfin | Startup (if needed), libraries `/data/media/movies` + `/data/media/tv`, API key |
| Seerr | Jellyfin login + Radarr/Sonarr services + initialize |
| Secrets | Writes empty `.env` keys; patches Recyclarr placeholders; recreates Decluttarr/Unpackerr when keys change |

**Prerequisites:**

1. `./bin/flixbox init` (API keys + `QBITTORRENT_*` + `FLIXBOX_ADMIN_*` generated when empty).
2. Stack running (`./bin/flixbox status`). VPN mode: Gluetun **healthy**.
3. *arr auth follows **`FLIXBOX_ACCESS_PROFILE`** ([ADR 0015](../adr/0015-access-profiles.md)): default **`trusted`** (no *arr UI login on LAN); **`shared`** if roommates share Wi‑Fi. `configure` always uses API keys for wiring. With **`shared`**, apply Forms via `./bin/flixbox credentials set arr-ui` (ADR 0020) — see [13 — Create *arr login](13-access-profiles.md#create-arr-login-shared).

**Stays manual:** Prowlarr indexers; Maintainerr rule enablement; optional Recyclarr sync; Forms UI create only if Host Config apply fails.

### Host port conflicts

`./bin/flixbox up` and `reload` run a **host port preflight** before Compose starts. It validates:
1. **Internal collisions:** Checks that no two services in `.env` share the same host port (e.g. accidentally setting `QBITTORRENT_PORT=8989` when `SONARR_PORT=8989`).
2. **External collisions:** Checks if a port is already taken **by another process** on your machine (common: `8080` used by another app). Ports already published by running `flixbox-*` containers are **ignored** so `reload` of the same stack works.

If any conflict is detected, `up` fails with an actionable message and suggestions instead of a Docker bind error.

1. Pick a free host port in `.env`, for example `QBITTORRENT_PORT=9898` (container port stays `8080`).
2. Run `./bin/flixbox reload` (or `up` if the stack is down).
3. Open qBit at `http://localhost:9898` — *arr and Decluttarr still use `http://qbittorrent:8080` inside Docker ([ADR 0014](../adr/0014-stable-qbit-download-hostname.md)).

Jellyfin and Seerr stay on all host interfaces even in the `shared` profile (household apps). Port preflight probes them on `0.0.0.0`, not `FLIXBOX_ADMIN_BIND_IP`.

See also [Troubleshooting — port preflight](10-troubleshooting.md).

---

## 1. Prowlarr + Byparr

If you ran `configure`, the Byparr proxy and Radarr/Sonarr apps should already exist. Verify under **Settings → Indexers → Indexer Proxies** and **Settings → Apps**.

### 1a. Add indexers

**Indexers without Cloudflare** — add normally.

**Indexers with Cloudflare** (for example 1337x):

1. **Indexers** → **Add indexer**.
2. Under **Tags**, add **`cf`** (same tag as the Byparr proxy).
3. **Test**.

### 1b. Tags and app sync

Prowlarr warns: *an indexer with a tag only syncs to apps with the same tag.* Keep `cf` on Radarr/Sonarr apps (configure sets this) or leave indexers untagged for all apps.

Sync indexers with **Sync App Indexers**. Prowlarr does **not** sync download clients or root folders.

Manual Byparr fallback (if configure skipped it): proxy type **FlareSolverr**, host `http://byparr:8191`, tag `cf`.

---

## 2. qBittorrent

WebUI: `http://127.0.0.1:${QBITTORRENT_PORT}` (default `8080`).

Login: `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` from `.env` (set by init; configure applies the password if qBit still has a temporary one).

Paths are set by cont-init (`/data/torrents/`, incomplete under `torrents/incomplete`). VPN mode: a custom service re-binds BitTorrent to `tun0` so torrents do not stall at metaDL (ADR 0002).

If the WebUI shows plain `Unauthorized` with a remapped host port, see [§2b.1](#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x) below.

### 2b.1 WebUI stuck on plain `Unauthorized` (qBittorrent 5.x)

Flixbox maps `${QBITTORRENT_PORT}:8080`. qBit 5.x may reject `Host: localhost:<mapped-port>` when `HostHeaderValidation` expects `:8080`.

`flixbox init` installs cont-init that sets `WebUI\HostHeaderValidation=false` and `WebUI\LocalHostAuth=false`, and a **runtime custom-service** ([ADR 0019](../adr/0019-qbit-webui-runtime-contract.md)) re-applies the WebUI security contract via API because qBit may discard Preferences on start.

Re-run init and recreate qBit if your install predates that mount:

```bash
./bin/flixbox init --non-interactive
./bin/flixbox reload
# If password / *arr clients drifted after recreate:
./bin/flixbox configure --sync-qbit-auth
```

### 2d. VPN port forwarding

If `VPN_PORT_FORWARDING=on`: enable **Bypass authentication for clients on localhost** in the qBit WebUI (Gluetun hooks call `127.0.0.1:8080`).

---

## 3. Radarr / Sonarr / hygiene

`configure` adds root folders and the qBittorrent download client (`host: qbittorrent`, port `8080`). On later runs it **re-tests** that client and updates username/password/API key when Test fails **or** the stored qBit API key drifted (e.g. accidental regenerate in the WebUI). To **force** a full push from `.env` into qBit + *arr + Decluttarr after a manual password change, use `./bin/flixbox configure --sync-qbit-auth` — [Credentials — key changes](06-configuration.md#accidental--intentional-key-changes).

Decluttarr/Unpackerr pick up `RADARR_API_KEY` / `SONARR_API_KEY` / `QBITTORRENT_*` from `.env`. Configure recreates them when it writes those keys or when you pass `--sync-qbit-auth`; otherwise `./bin/flixbox reload`.

---

## 4. Bazarr / Jellyfin / Seerr

Configure connects Bazarr to Sonarr/Radarr, completes Jellyfin libraries when `FLIXBOX_ADMIN_*` is set, and wires Seerr.

If Jellyfin or Seerr automation fails (version quirks), finish the UI wizard once and re-run `./bin/flixbox configure` — remaining steps should **skip**.

| Jellyfin libraries | Path |
| --- | --- |
| Movies | `/data/media/movies` |
| TV | `/data/media/tv` |

---

## 5. Recyclarr / Maintainerr / Homepage

- Recyclarr: placeholders patched by configure →  
  `docker compose --profile recyclarr run --rm recyclarr sync`
- Maintainerr (`:6246`): connect Jellyfin + *arr; enable rules from [Hygiene](08-hygiene.md) deliberately.
- Homepage templates are copied by init; API widgets improve as keys land in `.env`.

## Next

[Configuration](06-configuration.md) · [VPN and Direct](07-vpn-and-direct.md)
