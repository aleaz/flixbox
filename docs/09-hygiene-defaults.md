# Hygiene defaults (Decluttarr + Maintainerr)

**Status:** Accepted defaults for v0.1 hygiene templates  
**Related:** [ADR 0008](adr/0008-maintenance-decluttarr-maintainerr.md)

These are the Flixbox-recommended starting rules. Templates shipped with the project MUST match this document. Operators can tighten or loosen after first boot.

---

## 1. Decluttarr — download queue

**Goal:** Clear dead downloads so *arr can grab another release. Home-friendly defaults: keep stalled/failed/orphan hygiene, but do **not** use absolute KiB/s “slow” removal (VPN footgun).

| Setting | Default | Rationale |
| --- | --- | --- |
| Remove stalled | **on** | No progress after strikes → remove + blocklist + re-search |
| Remove slow | **off** | Absolute KiB/s floors false-positive on VPN / slow seeders (upstream Decluttarr default is off) |
| Remove failed downloads | **on** | Failed in client or *arr |
| Remove failed imports | **on** | Import errors that will not self-heal |
| Remove missing files | **on** | Client points at gone paths |
| Remove orphans | **on** | In client but not tracked by *arr |
| Remove unmonitored | **off** | Avoid surprise deletes when user paused monitoring |
| Max strikes / permitted attempts | **12** | With timer 15 → ~**3 hours** grace for stalled (`TIMER × STRIKES`) |
| Check timer | **15 minutes** | Balance responsiveness vs API load |
| Min download speed | *(n/a unless REMOVE_SLOW on)* | If you re-enable slow, prefer a low floor (e.g. 30 KiB/s) and longer grace — not 100 KiB/s under VPN |
| Protected qBit tag | `flixbox-keep` | Torrents with this tag are never auto-removed |

**Grace math:** Decluttarr removes after roughly `DECLUTTARR_REMOVE_TIMER × DECLUTTARR_STRIKES` minutes of consecutive strikes (not “a few hours” unless you set numbers that multiply to that).

**VPN:** Prefer `DECLUTTARR_REMOVE_SLOW=False` (Flixbox default). `./bin/flixbox up|reload|status` warns when `FLIXBOX_MODE=vpn` and `REMOVE_SLOW` is enabled. Tag important torrents `flixbox-keep`.

**qBittorrent URL**

- Download client: `http://qbittorrent:8080` (VPN and Direct — ADR 0014)

Download client **name** in Decluttarr must match the name configured in Radarr/Sonarr (default suggestion: `qBittorrent`).

**Compose env (Decluttarr v2, Nov 2025):** list-based `RADARR` / `SONARR` / `QBITTORRENT` blocks in `optimization.yml`; protect tag is `PROTECTED_TAG: flixbox-keep` (v1 `NO_STALLED_REMOVAL_QBIT_TAG` is ignored).

**First-run idle gate:** if `QBITTORRENT_USERNAME` or `QBITTORRENT_PASSWORD` is empty, Decluttarr does not start its cleanup loop (`templates/decluttarr/entrypoint.sh`). Set WebUI login in `.env` and recreate the container — [ADR 0008](adr/0008-maintenance-decluttarr-maintainerr.md).

**qBittorrent / Docker:** `flixbox_net` uses subnet `172.30.42.0/24` (trusted); qBit whitelists that CIDR (**auth bypass** for stack peers). qBit has a WebUI healthcheck; Decluttarr waits until healthy.

**After removal:** trigger *arr search for a replacement when the app supports it.

---

## 2. Maintainerr — library cleanup

**Goal:** Free disk from forgotten media without nuking new or actively watched content. Uses Jellyfin as media server.

### 2.1 Safety rails (always)

- Media server: **Jellyfin** only (unless Plex profile is explicitly enabled and Maintainerr is retargeted).
- Do **not** delete items added in the last **30 days**.
- Do **not** delete if present in a manual **Keep** / favorites-style exclusion (document a `Keep` Maintainerr exclusion list / tag convention).
- Prefer **Leaving Soon** (or equivalent collection) before hard delete when Jellyfin collections are available.
- First boot: rules may be imported **disabled** or in preview until the operator confirms disk policy — then enable using this pack. Implementation SHOULD ship the rule pack ready-to-enable with these thresholds (not empty).

### 2.2 Rule pack (standard)

#### Rule A — Unwatched movies (90 / 14)

| Step | Condition | Action |
| --- | --- | --- |
| Match | Movie in Jellyfin, **never watched** (or watch progress &lt; 10%), **added &gt; 90 days** ago | Add to collection **Leaving Soon — Movies** |
| Delete | Still in that collection for **14 days** and still unwatched | Unmonitor + delete file via Radarr; remove from Jellyfin |

#### Rule B — Unwatched TV shows (180 / 21)

| Step | Condition | Action |
| --- | --- | --- |
| Match | Series with **no episode watched in 180 days**, and show **added &gt; 90 days** ago | Add to **Leaving Soon — TV** |
| Delete | Still in collection **21 days** and still no recent watches | Unmonitor + delete via Sonarr (series or ended seasons per Maintainerr capability) |

#### Rule C — Watched movies (optional, off by default)

| Condition | Action |
| --- | --- |
| Movie **fully watched**, last play **&gt; 365 days**, not in Keep list | Add to Leaving Soon only — **no auto-delete in the default pack** |

Operators who want aggressive reclaim enable delete on Rule C themselves.

### 2.3 Notifications

- Prefer Seerr / Maintainerr built-in notifications (Discord, ntfy, etc.) when configured.
- Day-0: Radarr/Sonarr native Connect (including Telegram) needs no extra Flixbox service.
- Optional Apprise hub (`notifications` profile) for multi-channel fan-out — [18-notifications.md](user/18-notifications.md), [ADR 0012](adr/0012-notifications-apprise-hub.md).
- Document that cleanup actions are irreversible for files (hardlinks: deleting library path may leave torrent path until client removes it — coordinate with seeding policy).

---

## 3. Seeding vs library delete

When Maintainerr deletes a library file that is still hardlinked to a torrent:

- Disk space is **not** freed until the torrent copy is also removed.
- Decluttarr does not replace a seeding-ratio policy; operators who want space back after Maintainerr delete should stop seeding or use *arr “delete from disk” consistently.
- Docs/README MUST mention this hardlink interaction.

---

## 4. Implementation checklist

- [ ] Decluttarr env/config template matches §1
- [ ] Maintainerr rule export / docs match §2.2
- [ ] `flixbox-keep` tag documented for qBit
- [ ] Keep exclusion documented for Maintainerr
- [ ] VPN/Direct qBit URL documented in Decluttarr template
