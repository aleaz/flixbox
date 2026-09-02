# Maintainerr rule pack (Flixbox standard)

Operator guide for the thresholds in [docs/09-hygiene-defaults.md](../../docs/09-hygiene-defaults.md). Maintainerr has no importable JSON in MVP — configure these rules in the UI at `http://127.0.0.1:6246` (or your host bind).

**Before any delete rule:** connect Jellyfin, Radarr, and Sonarr with each service **API key** (from `.env` after `./bin/flixbox configure`). Test connections in Maintainerr Settings.

---

## Safety rails (enable first)

1. **Media server:** Jellyfin only (default Flixbox; do not point at Plex unless you deliberately switched).
2. **Keep exclusion:** create a Jellyfin collection or tag convention (e.g. `Keep`) and add an exclusion in Maintainerr so matched items are never deleted.
3. **New content:** global guard — do not act on items added in the last **30 days**.
4. **First run:** import or create rules **disabled** (or preview-only), verify Leaving Soon collections exist, then enable one rule at a time.

---

## Rule A — Unwatched movies (90 / 14)

| Step | Condition | Action |
| --- | --- | --- |
| Match | Movie in Jellyfin, never watched (or progress &lt; 10%), added **&gt; 90 days** ago | Add to collection **Leaving Soon — Movies** |
| Delete | Still in that collection **14 days**, still unwatched | Unmonitor + delete via Radarr; remove from Jellyfin |

**UI hints:** rule type “unwatched” / watch-progress threshold; tie Radarr delete to unmonitor; use Jellyfin collection for Leaving Soon.

---

## Rule B — Unwatched TV (180 / 21)

| Step | Condition | Action |
| --- | --- | --- |
| Match | Series with **no episode watched in 180 days**, show added **&gt; 90 days** ago | Add to **Leaving Soon — TV** |
| Delete | Still in collection **21 days**, still no recent watches | Unmonitor + delete via Sonarr (series or ended seasons per Maintainerr version) |

---

## Rule C — Watched movies reclaim (OFF by default)

| Condition | Action |
| --- | --- |
| Movie fully watched, last play **&gt; 365 days**, not in Keep list | Add to Leaving Soon only — **no auto-delete** in Flixbox default |

Enable delete on Rule C only if you explicitly want aggressive reclaim.

---

## After enabling deletes

- Run a dry period with notifications (Discord / ntfy / email in Maintainerr) before unattended deletes.
- Coordinate with seeding: library delete may not free disk while a hardlinked torrent still seeds — see [Hygiene — hardlinks](../../docs/user/08-hygiene.md#hardlinks-and-free-space).
- If you regenerate *arr or Jellyfin API keys, update Maintainerr connections — [Credential rotation](../../docs/user/15-credential-rotation.md).

---

## Related

- [User guide — Hygiene](../../docs/user/08-hygiene.md)
- [First-run §8](../../docs/user/05-first-run.md#8-decluttarr--maintainerr)
