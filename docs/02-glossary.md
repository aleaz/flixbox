# Glossary

Shared vocabulary for Flixbox docs, ADRs, and AI-assisted development.

| Term | Meaning |
| --- | --- |
| **Servarr** | Family of automation apps (*arr): Radarr, Sonarr, Prowlarr, Bazarr, etc. |
| **Radarr** | Movie library manager; finds releases and sends download jobs. |
| **Sonarr** | TV series library manager. |
| **Prowlarr** | Central indexer manager; syncs indexers to *arr apps. |
| **Bazarr** | Subtitle downloader integrated with Radarr/Sonarr. |
| **Seerr** | Unified request portal (successor to Overseerr + Jellyseerr); supports Jellyfin/Plex/Emby. |
| **Jellyseerr / Overseerr** | Legacy request apps superseded by Seerr for new installs. |
| **Jellyfin** | FOSS media server (primary in Flixbox). |
| **Homepage** | Dashboard UI with API widgets for stack status (YAML config). |
| **Caddy** | Reverse proxy with automatic HTTPS. |
| **qBittorrent** | BitTorrent client used for P2P ingestion. |
| **Gluetun** | VPN client container supporting many providers and protocols. |
| **Byparr** | Anti-bot bypass service; speaks FlareSolverr-compatible API for Prowlarr. |
| **FlareSolverr** | Original CF bypass project / API name; Flixbox default image is Byparr. |
| **Unpackerr** | Extracts RAR/ZIP from downloads without stopping seeding. |
| **Recyclarr** | CLI sync of TRaSH Guides quality profiles and custom formats into *arr. |
| **Profilarr** | GUI alternative to Recyclarr (out of MVP). |
| **Decluttarr** | Removes stalled/failed/orphan downloads and can trigger *arr re-search. |
| **Maintainerr** | Rule-based library cleanup using media-server watch state + *arr. |
| **TRaSH Guides** | Community best practices for *arr quality and storage layout. |
| **Hardlink** | Second directory entry for the same inode (`link()`); zero extra disk bytes. |
| **Symlink** | Path pointer to another path; not a substitute for hardlinks in this design. |
| **Copy (anti-pattern)** | Import that reads/writes a full duplicate across mounts (`EXDEV` fallback). |
| **`/data` contract** | Single parent bind mount shared by downloaders and *arr so hardlinks work. |
| **`/config`** | Per-app persistent config; must live on local SSD/NVMe, not NFS/SMB. |
| **VPN mode** | `VPN_ENABLED=true`; qBittorrent uses `network_mode: service:gluetun`. |
| **Direct mode** | `VPN_ENABLED=false`; qBittorrent attaches to `flixbox_net` without VPN. |
| **Killswitch** | No independent egress for qBit when Gluetun/tunnel is down (shared netns + firewall). |
| **netns** | Linux network namespace; containers can share one (VPN sidecar pattern). |
| **Port forwarding (VPN)** | Provider assigns an inbound port; Gluetun can push it into qBittorrent via UP_COMMAND. |
| **Compose profile** | Docker Compose mechanism to enable optional service groups. |
| **`include:`** | Compose v2 feature to split stack definition across YAML files. |
| **PUID / PGID** | Host user/group IDs mapped into linuxserver-style containers. |
| **UMASK** | File creation mask (Flixbox: `002` with single shared UID). |
| **SGID bit** | Directory mode so new files inherit the parent group. |
| **DoT** | DNS over TLS (used inside Gluetun to reduce DNS leaks). |
| **MVP** | Minimum viable product inventory frozen in [01-scope.md](01-scope.md). |
| **ADR** | Architecture Decision Record under `docs/adr/`. |
| **Working Draft** | Current doc status until MVP implementation lands. |
| **First-class platform** | Fully supported and tested (Linux). |
| **Best-effort platform** | Documented and allowed; limitations accepted (WSL2, macOS). |
