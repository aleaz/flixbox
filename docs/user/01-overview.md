# Overview

## At a glance

Flixbox is an open-source, Docker-based home media suite: request a title, download it (optionally through a VPN), organize with **hardlinks**, keep queues tidy, and stream with **Jellyfin**.

- **Outcome:** Ask in Seerr → watch in Jellyfin on one disk layout  
- **Who:** Operators comfortable with Linux and Docker  
- **Time:** ~15 minutes to stack up with `configure`; indexers are the main manual step  

## Who it is for

- People comfortable with Linux and Docker who want a modern *arr-style stack
- Operators who want clear contracts (storage, VPN/Direct) instead of a fragile copy-paste compose
- Homes that prefer **Jellyfin** (FOSS) with optional Plex later

## Who it is not for

- Turnkey appliances with zero Docker knowledge (yet — the CLI automates plumbing; you still add Prowlarr indexers)
- People who need Kubernetes or multi-node cloud HA as the primary model
- Anyone expecting Flixbox to decide legal questions about what you download

## What you get

| Piece | Role |
| --- | --- |
| Seerr | Request portal |
| Prowlarr + Byparr | Indexers + Cloudflare bypass |
| Radarr / Sonarr | Movies / TV automation |
| qBittorrent + Gluetun (optional) | Downloads, VPN or Direct |
| Unpackerr / Recyclarr | Archives + TRaSH quality sync |
| Decluttarr / Maintainerr | Queue + library hygiene |
| Bazarr | Subtitles |
| Jellyfin | Streaming |
| Homepage + Caddy | Dashboard + HTTPS ingress |
| `bin/flixbox` | Bash CLI for init/up/configure/status |

## Honest expectations

`./bin/flixbox init` → `up` → **`configure`** wires qBittorrent, *arr download clients, Prowlarr apps/Byparr, Bazarr, Jellyfin libraries, and Seerr when the stack is healthy. You will still:

- Add **Prowlarr indexers** (and tag Cloudflare ones `cf`)
- Confirm Seerr / *arr / qBit look wired after configure (UI fallback only if automation failed)
- Enable **Maintainerr** rules deliberately (nothing destructive is on by default)
- Optionally run **Recyclarr sync** and set up Caddy / VPN credentials when you need them
- On **`shared` Wi‑Fi**, apply *arr Forms with `credentials set arr-ui` (or `configure --sync-arr-ui`)

## You’re done when

1. `./bin/flixbox status` shows core services healthy  
2. `./bin/flixbox configure` finishes with **0 failed** (safe to re-run)  
3. At least one Prowlarr indexer is added and synced to Radarr/Sonarr  
4. A Seerr request appears in Radarr or Sonarr  
5. A completed download imports into `/data/media` (hardlink) and plays in Jellyfin  

Full checklist: [First-run](05-first-run.md#youre-done-when) · happy-path smoke: [Smoke test — Phase F](11-smoke-test.md#phase-f--end-to-end-request-flow-manual).

## Verify

**Expected:** Homepage at `http://localhost:3000`, `./bin/flixbox status` healthy, Seerr at `:5055`, Jellyfin at `:8096`.

## If it fails

| Symptom | Start here |
| --- | --- |
| Docker permission denied | [Troubleshooting — Docker daemon](10-troubleshooting.md#docker-daemon-access) |
| `up` / port conflicts | [First-run — Host port conflicts](05-first-run.md#host-port-conflicts) |
| `configure` times out | [Troubleshooting — configure](10-troubleshooting.md) |

## Disclaimer

> Authors **do not condone** copyright infringement. Flixbox **only assembles** third-party tools — it does **not** develop them. **Use at your own risk;** you alone bear responsibility for content and compliance. Full notice: [Legal disclaimer](16-legal-disclaimer.md) · [Aviso legal (ES)](../es/user/16-legal-disclaimer.md)

## LAN security (access profiles)

Default profile is **`trusted`**: *arr admin UIs on your Wi‑Fi do not ask for login. If **roommates or guests share the same network**, set `FLIXBOX_ACCESS_PROFILE=shared` in `.env` before `init`/`up` — admin ports bind to localhost and *arr use Forms login. See [Access profiles](13-access-profiles.md).

## Next

Read [How it works](02-how-it-works.md) for the mental model, then [Requirements](03-requirements.md).
