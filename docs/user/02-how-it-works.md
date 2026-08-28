# How it works

This page is the mental model. If you understand it, the rest of the UI setup makes sense.

## Pipeline

```text
You → Seerr → Radarr/Sonarr → Prowlarr (+ Byparr)
                ↓
         qBittorrent ── VPN mode: via Gluetun
                │         Direct mode: plain Docker network
                ↓
     /data/torrents/...  ──hardlink──►  /data/media/...
                ↓
            Jellyfin (+ Bazarr subtitles)

Decluttarr cleans stuck downloads.
Maintainerr cleans forgotten library items (rules).
```

1. **Request** something in Seerr (or add it in Radarr/Sonarr).
2. **Search** goes through Prowlarr. Cloudflare-protected indexers (for example 1337x) need the **Byparr** proxy in Prowlarr — see [First-run setup](05-first-run.md#1-prowlarr--byparr).
3. **Download** lands in `/data/torrents/...` via qBittorrent.
4. **Import** creates a **hardlink** into `/data/media/...` (same file, second name — almost no extra disk).
5. **Stream** from Jellyfin; Bazarr can fetch subtitles.
6. **Hygiene** tools keep queues and libraries from rotting.

## Why one `/data` mount matters

All download and library apps must see the **same parent folder** inside the container (`/data`). If torrents and media are separate Docker mounts, hardlinks fail and *arr falls back to a full **copy** (slow, doubles disk while seeding).

```text
Host ${DATA_DIR}/          →  Container /data/
├── torrents/
│   ├── incomplete/
│   ├── movies/
│   └── tv/
└── media/
    ├── movies/
    └── tv/
```

Config databases live separately under `${CONFIG_DIR}` on a **local SSD/NVMe** (not NFS/SMB).

> Screenshot placeholder: `docs/images/shared/data-layout.png`

## VPN mode vs Direct mode

| Mode | When to use | What is protected |
| --- | --- | --- |
| **VPN** (`VPN_ENABLED=true`) | You want torrent traffic masked | Only **qBittorrent** shares Gluetun’s network |
| **Direct** (`VPN_ENABLED=false`) | Private trackers / max speed / no VPN | qBittorrent on the normal Docker network |

**Important:** Radarr, Sonarr, Seerr, Jellyfin, etc. stay on the normal network. Putting them behind the VPN breaks metadata and LAN access.

In VPN mode, other apps talk to qBittorrent at `http://gluetun:8080`.  
In Direct mode, they use `http://qbittorrent:8080`.

## Hygiene in one sentence

- **Decluttarr** — “this download is dead; remove it and try another.”
- **Maintainerr** — “nobody watched this in months; warn, then clean up.”

Defaults are documented in [Hygiene](08-hygiene.md) and [engineering defaults](../09-hygiene-defaults.md).

## Next

[Requirements](03-requirements.md) → [Install](04-install.md).
