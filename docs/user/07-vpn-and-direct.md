# VPN and Direct mode

## Choose a mode

| Choose **VPN** if… | Choose **Direct** if… |
| --- | --- |
| You want torrent egress masked | You use IP-authenticated private trackers |
| Your provider works with Gluetun | You want maximum line speed |
| You accept VPN overhead | You accept that your IP is visible to peers |

You can switch later by changing `VPN_ENABLED` and recreating the downloader stack (`flixbox up` after config change).

## VPN mode essentials

1. Only **qBittorrent** uses `network_mode: service:gluetun`.
2. WebUI ports are published on **Gluetun**, not on the qBittorrent service.
3. Radarr/Sonarr/Decluttarr must use download client host **`gluetun`**.
4. IPv6 is blocked by default unless you configure an IPv6 VPN on purpose.
5. Port forwarding (when the provider supports it) should update qBittorrent’s listen port automatically via Gluetun hooks.

## Direct mode essentials

1. Gluetun is not started.
2. Download client host is **`qbittorrent`**.
3. Still keep the single `/data` hardlink layout.

## Verify

```bash
./bin/flixbox vpn-test
```

You want a public IP that is **not** your home ISP when VPN mode is on, and no obvious DNS leak in the test output.

## Anti-patterns

- Putting Radarr/Sonarr/Seerr/Jellyfin behind Gluetun
- Split Docker mounts for torrents vs media
- Storing `${CONFIG_DIR}` on NFS/SMB

## Next

[Hygiene](08-hygiene.md)
