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
- **Mitigation (document/enforce):** `init` warns; docs forbid exFAT for `${DATA_DIR}`.

---

## 2. Docker networking

### 2.1 qBittorrent hostname and ports in VPN mode

- **Risk:** Using `http://qbittorrent:8080` or publishing ports on the qBit service fails in VPN mode.
- **Mitigation (enforce/document):** URL `http://gluetun:8080`; publish ports on **Gluetun**. Decluttarr must use the same URL.

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

- **Mitigation (enforce optional profile):** docker-socket-proxy with create/delete denied.

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

- **Mitigation (enforce):** Refuse/warn if `CONFIG_DIR` looks remote.

### 4.3 `/dev/shm` too small for transcode

- **Mitigation (enforce):** Mount host `/dev/shm` into Jellyfin transcode path.

### 4.4 Hardlink verification

- **Mitigation (document):** Compare inodes with `ls -i` after import.

### 4.5 Path changes do not propagate to all apps

- **Risk:** Operator changes `DATA_DIR` or folder layout; qBit hook updates save paths, but Radarr/Sonarr/Jellyfin keep old root folders or libraries in SQLite until UI is updated — imports fail or libraries look empty.
- **Mitigation (document):** [user/09-operations.md — Changing paths](user/09-operations.md#changing-paths-and-storage-layout).

---

## 5. Cross-platform

### 5.1 WSL2 + NTFS (`/mnt/c`)

- **Mitigation (document):** Store data on WSL2 ext4 only.

### 5.2 CRLF in shell scripts

- **Mitigation (enforce):** `.gitattributes` / `.editorconfig` force LF.

### 5.3 macOS VirtioFS / APFS

- **Mitigation (document):** Best-effort; Linux is reference.

---

## 6. Pipeline and hygiene failure modes

| Component | Failure | Mitigation |
| --- | --- | --- |
| Unpackerr | Disk full mid-extract | Free-space threshold before extract |
| Byparr | Captcha / CF loops | Retry limits; alternate indexer; optional FlareSolverr image |
| Recyclarr | Upstream schema drift | Pin versions; explicit sync; dry-run |
| Prowlarr | HTTP 429 | Respect rate limits / backoff |
| Decluttarr | Over-aggressive removals | Conservative default strikes; protect tags; document |
| Decluttarr | Wrong qBit URL in VPN mode | Mode-aware `gluetun` hostname |
| Maintainerr | Accidental mass delete | Ship with rules disabled / dry examples; require explicit enable |
| Maintainerr | Wrong media server | Default Jellyfin; one server at a time |
| Seerr | Permission errors on config | UID 1000 ownership + `init: true` |

---

## 7. Implementation priority

1. Hardlink mount contract + incomplete path + hostname/ports rules for VPN/Direct  
2. Gluetun healthcheck + IPv6 block + grace period + port-forward hooks  
3. Byparr + Seerr compose defaults  
4. Decluttarr mode-aware qBit URL + Maintainerr Jellyfin default  
5. Local `/config` warning + `/dev/shm` + exFAT warning  
6. Host tuning + socket proxy profile  
7. MergerFS/WSL warnings in CLI/docs  
