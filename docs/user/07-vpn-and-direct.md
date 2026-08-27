# VPN and Direct mode

## Choose a mode

Set in `.env` (only one downloader module is included):

| `.env` | Behavior | *arr download client |
| --- | --- | --- |
| `FLIXBOX_MODE=direct` | qBittorrent on `flixbox_net` | `http://qbittorrent:8080` |
| `FLIXBOX_MODE=vpn` | qBittorrent shares Gluetun netns | `http://gluetun:8080` |

Keep `VPN_ENABLED` aligned (`false` / `true`) for future CLI use.

| Choose **VPN** if… | Choose **Direct** if… |
| --- | --- |
| You want torrent egress masked | Private trackers with IP auth |
| Your provider works with Gluetun | Max line speed / lab testing |

Switching: `docker compose down` → change `FLIXBOX_MODE` → `docker compose up -d`.

## VPN mode essentials

1. Only **qBittorrent** uses `network_mode: service:gluetun`.
2. WebUI / BT ports are published on **Gluetun**, not on the qBittorrent service.
3. Radarr/Sonarr/Decluttarr must use host **`gluetun`**.
4. IPv6 blocked by default (`BLOCK_IPV6=on`); DNS over TLS on (`DOT=on`).
5. Optional port forwarding: `VPN_PORT_FORWARDING=on` (supported providers). Enable qBittorrent **Bypass authentication for clients on localhost**.
6. Put provider credentials only in `.env` or files under `${CONFIG_DIR}/gluetun` — never in git.

## Direct mode essentials

1. Gluetun is not started.
2. Download client host is **`qbittorrent`**.
3. Still use the single `/data` hardlink layout.

## Verify

```bash
./scripts/vpn-test.sh
```

VPN mode: public IP should **not** be your home ISP.  
Direct mode: public IP is your normal egress.

## Anti-patterns

- Putting Radarr/Sonarr/Seerr/Jellyfin behind Gluetun
- Split Docker mounts for torrents vs media
- Storing `${CONFIG_DIR}` on NFS/SMB
- Running both modes at once (unsupported — exclusive compose include)

## Next

[Hygiene](08-hygiene.md)
