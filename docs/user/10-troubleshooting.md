# Troubleshooting

| Symptom | Likely cause | What to try |
| --- | --- | --- |
| `mkdir: /srv: Read-only file system` on init | Linux default paths on macOS | Set `DATA_DIR`/`CONFIG_DIR` under `$HOME/flixbox/` in `.env`, or `./bin/flixbox init --force --non-interactive` on macOS |
| Imports are slow / disk doubles | Split mounts; hardlink failed (`EXDEV`) | One `${DATA_DIR}:/data` parent; check MergerFS/exFAT |
| Radarr cannot reach qBit (VPN) | Wrong hostname or ports on wrong service | Use `http://gluetun:8080`; publish UI on Gluetun |
| qBit crash-loops at boot (VPN) | Started before Gluetun healthy | Healthcheck `depends_on`; restart qBit after Gluetun is healthy |
| VPN test shows home IP | Not in VPN mode / tunnel down | Check `VPN_ENABLED`, Gluetun logs, `vpn-test` |
| Indexers fail Cloudflare | Bypass service misconfigured | Byparr URL in Prowlarr proxy type “FlareSolverr” |
| Jellyfin dies on 4K transcode | Small `/dev/shm` | Mount host `/dev/shm` for transcode |
| *arr DB corrupt after reboot | Short stop timeout | `stop_grace_period: 60s`; local SSD for config |
| Config weirdness on NAS path | SQLite over NFS/SMB | Move `${CONFIG_DIR}` to local disk |
| Maintainerr deleted too much | Rules too aggressive | Tighten thresholds; use Keep list; review Leaving Soon first |
| Decluttarr removes wanted torrent | No protect tag | Add `flixbox-keep`; raise strikes |
| Permission denied on media | UID/GID mismatch | Align `PUID`/`PGID`; SGID on data dirs |
| Scripts fail with `\r` errors | CRLF line endings on Windows clone | Ensure LF via `.gitattributes` |

## Still stuck?

1. `./bin/flixbox status` and service logs  
2. Confirm mode (VPN vs Direct) and download-client host  
3. Re-read [How it works](02-how-it-works.md)  
4. Engineering depth: [operations risks](../07-operations-risks.md)

## Contributing / bugs

Use the GitHub issue tracker once the repository is public. Include Flixbox version/commit, OS, VPN or Direct, and redacted logs (no API keys).
