# Operations risks and edge cases

**Status:** Working Draft  
Use this as an implementation checklist. Mitigations marked **enforce** should be coded into Compose/CLI; **document** means warn in docs/README.

---

## 1. Linux / kernel

### 1.1 Inotify watch exhaustion

- **Risk:** Large libraries exceed `fs.inotify.max_user_watches`.
- **Mitigation (enforce):** `scripts/host-tuning.sh` → e.g. `fs.inotify.max_user_watches=524288`.

### 1.2 Permissions / group inheritance

- **Risk:** Mixed UIDs/umasks → *arr cannot rename/delete.
- **Mitigation (enforce):** Single shared `PUID`/`PGID`, `UMASK=002`, SGID on data dirs.

### 1.3 Socket buffers / file descriptors

- **Mitigation (document/optional):** Raise `rmem_max`/`wmem_max` and `nofile` on high-swarm hosts.

### 1.4 Filesystems without hardlinks

- **Risk:** `exFAT` and similar cannot hardlink.
- **Mitigation (enforce):** `flixbox doctor` hardlink probe + exFAT/WSL detection (exit 4); `init` warns via shared FS guards; docs forbid exFAT for `${DATA_DIR}`.

---

## 2. Docker networking

### 2.1 qBittorrent hostname and ports in VPN mode

- **Risk:** Using `http://qbittorrent:8080` without the Gluetun **network alias** in VPN mode (DNS does not resolve).
- **Mitigation (enforce):** ADR 0014 — alias `qbittorrent` on Gluetun in `downloaders-vpn.yml`; publish WebUI/BT ports on **Gluetun**.

### 2.2 DNS blackhole at boot

- **Mitigation (enforce):** `depends_on` with `condition: service_healthy` on Gluetun.

### 2.3 Putting *arr behind Gluetun (anti-pattern)

- **Risk:** Breaks LAN metadata, discovery, and Seerr/Jellyfin integration.
- **Mitigation (enforce):** Only qBittorrent may use `network_mode: service:gluetun`.

### 2.4 Port forwarding not applied to qBit

- **Risk:** Gluetun obtains a forwarded port but qBit keeps an old listen port → poor peer connectivity.
- **Mitigation (enforce/document):** `VPN_PORT_FORWARDING=on` + `VPN_PORT_FORWARDING_UP_COMMAND` / `DOWN_COMMAND`; enable qBit “bypass authentication for localhost”.

### 2.5 SQLite corruption on short stop timeout

- **Mitigation (enforce):** `stop_grace_period: 60s` on stateful services.

### 2.6 VPN tunnel drop vs container recreate

- **Risk:** Operators expect Flixbox to “fail over to Direct” or always recreate containers; or assume Gluetun container restart alone always heals qBit.
- **Mitigation (document):** Gluetun **internally** restarts the VPN on failed health checks; killswitch keeps fail-closed (no ISP torrent egress). After Gluetun **container** recreate, qBit may need recreate (`compose up -d qbittorrent`). Never auto-switch to Direct — [ADR 0013](adr/0013-vpn-resilience-no-direct-fallback.md), [planning note](11-future-notifications-and-vpn-resilience.md).
- **Future:** optional `vpn-heal` profile (Proposed) for stranded netns dependents.

---

## 3. Security / privacy

Operator guide: [Torrent privacy and security](user/12-torrent-privacy-and-security.md) (qBit settings, leak checklist).

### 3.1 IPv6 bypass leak

- **Mitigation (enforce):** Gluetun `BLOCK_IPV6=on` by default unless user supplies IPv6 VPN.

### 3.2 Docker socket hijack

- **Mitigation (enforce):** Homepage never mounts the host socket. Always-on `docker-socket-proxy` with create/delete/exec denied; Homepage talks to `docker-socket-proxy:2375` ([ADR 0022](adr/0022-operator-footgun-remediations.md)).

### 3.3 LAN plaintext / internet exposure

- **Mitigation (document):** Prefer Caddy HTTPS; Authelia/Authentik are post-MVP — warn that raw port publish to WAN is unsafe.

### 3.4 Killswitch expectation

- **Mitigation (document):** Shared netns + Gluetun firewall; verify with `vpn-test`. No millisecond SLA claims.

### 3.5 Decluttarr / qBit WebUI ban during first-run

- **Mitigation (enforce):** Decluttarr idle entrypoint when WebUI username/password missing; `flixbox_net` fixed subnet + qBit AuthSubnetWhitelist (trusted-peer auth bypass); qBit WebUI healthcheck + `depends_on` for *arr/Decluttarr/Unpackerr. See [ADR 0008](adr/0008-maintenance-decluttarr-maintainerr.md).

### 3.6 Stale *arr “Connection refused” to qBit

- **Mitigation (enforce + document):** Healthcheck gate on qBit; troubleshooting row when Test is OK but System status is stale.

---

## 4. Storage and transcoding

### 4.1 MergerFS / Unraid / multi-disk `EXDEV`

- **Mitigation (document):** Single filesystem for `${DATA_DIR}`; MergerFS path-preserving create policy if pooled.

### 4.2 SQLite on NFS/SMB

- **Mitigation (enforce):** `flixbox doctor` fails (exit 4) when `CONFIG_DIR` is on nfs/cifs/smb/9p/sshfs; `init` warns via shared FS guards.

### 4.3 `/dev/shm` transcode vs. memory exhaustion

- **Risk:** Mounting `/dev/shm:/transcode` keeps temporary video chunks in host RAM (reducing SSD write wear). On servers with ≤8 GB RAM, concurrent high-bitrate transcodes can consume available tmpfs memory and trigger the Linux OOM Killer.
- **Mitigation (document/optional):** Recommended on hosts with ≥8–16 GB RAM. On low-memory hosts (≤8 GB RAM), remap the transcode volume to local disk (e.g. `${CONFIG_DIR}/jellyfin/transcode:/transcode` in `compose/media-servers.yml`).

### 4.4 Hardlink verification

- **Mitigation (enforce + document):** `flixbox doctor` runs a write/`ln` probe under `${DATA_DIR}`; after import, compare inodes with `ls -i` (day-2 ops).

### 4.5 Path changes do not propagate to all apps

- **Risk:** Operator changes `DATA_DIR` or folder layout; qBit hook updates save paths, but Radarr/Sonarr/Jellyfin keep old root folders or libraries in SQLite until UI is updated — imports fail or libraries look empty.
- **Mitigation (document):** [user/09-operations.md — Changing paths](user/09-operations.md#changing-paths-and-storage-layout).

---

## 5. Cross-platform

### 5.1 WSL2 + NTFS (`/mnt/c`)

- **Mitigation (document):** Store data on WSL2 ext4 only.

### 5.2 CRLF in shell scripts

- **Mitigation (enforce):** `.gitattributes` / `.editorconfig` force LF.

### 5.3 macOS VirtioFS / APFS (OrbStack / Docker Desktop)

- **Mitigation (document):** Best-effort for dev; Linux is reference. Hardlink smoke (Phase C) may be skipped on macOS.

---

## 6. Pipeline and hygiene failure modes

| Component | Failure | Mitigation |
| --- | --- | --- |
| Unpackerr | Disk full mid-extract | Free-space threshold before extract |
| Byparr | Captcha / CF loops | Retry limits; alternate indexer; optional FlareSolverr image |
| Recyclarr | Upstream schema drift | Pin versions; explicit sync; dry-run |
| Prowlarr | HTTP 429 | Respect rate limits / backoff |
| Decluttarr | Over-aggressive removals | `REMOVE_SLOW` off by default; longer stalled grace (`TIMER×STRIKES`); `flixbox-keep`; VPN warn if slow re-enabled — [09-hygiene-defaults.md](09-hygiene-defaults.md) |
| Decluttarr | Wrong qBit URL after mode switch | Always `qbittorrent:8080` (ADR 0014 Gluetun alias) |
| Maintainerr | Accidental mass delete | Ship with rules disabled / dry examples; require explicit enable |
| Maintainerr | Wrong media server | Default Jellyfin; one server at a time |
| Seerr | Permission errors on config | UID 1000 ownership fail-closed on `init`/`up`/`reload` ([ADR 0022](adr/0022-operator-footgun-remediations.md)) |

---

## 7. Implementation priority

1. Hardlink mount contract + incomplete path + hostname/ports rules for VPN/Direct  
2. Gluetun healthcheck + IPv6 block + grace period + port-forward hooks  
3. Byparr + Seerr compose defaults  
4. Decluttarr stable qBit URL (`qbittorrent`) + Maintainerr Jellyfin default  
5. Local `/config` warning + `/dev/shm` + exFAT warning  
6. Host tuning + socket proxy profile  
7. MergerFS/WSL warnings in CLI/docs  
