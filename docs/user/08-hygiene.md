# Hygiene (Decluttarr + Maintainerr)

Flixbox includes two helpers so the stack does not silently rot.

## Decluttarr — download queue

Removes stuck or useless downloads and can ask Radarr/Sonarr to search again.

Default idea:

- Stalled / failed / orphan / missing files → remove after grace
- **Slow (absolute KiB/s)** → **off** by default (VPN-friendly)
- Tag **`flixbox-keep`** on a torrent → never auto-remove
- Do **not** remove “unmonitored” items by default

**Grace:** ~`REMOVE_TIMER × STRIKES` minutes (defaults **15 × 12 ≈ 3 hours** for stalled). Not “a few hours” unless your numbers multiply to that.

**VPN tip:** leave `DECLUTTARR_REMOVE_SLOW=False`. If you turn slow removal on under VPN, `flixbox up|reload|status` warns — prefer `flixbox-keep` for important torrents instead.

Use the download client host **`qbittorrent`** (port `8080`) in both modes ([ADR 0014](../adr/0014-stable-qbit-download-hostname.md)). Decluttarr auth uses qBit **username/password** in `.env`, not the qBit API key — [Credentials](06-configuration.md#credentials-and-api-keys). Until `QBITTORRENT_PASSWORD` is set, Decluttarr stays idle on purpose.

## Maintainerr — library cleanup

Uses **Jellyfin** watch state plus Radarr/Sonarr to clean forgotten media.

Standard pack (summary):

| Rule | Behavior |
| --- | --- |
| Unwatched movies | After **90 days** → Leaving Soon → delete after **14** more days |
| Quiet TV shows | No watches for **180 days** → Leaving Soon → delete after **21** more days |
| Brand new items | Never touch if added in the last **30 days** |
| Already watched movies | Not auto-deleted by default |

Always review rules before the first destructive run. Prefer a Keep / exclusion list for favorites.

After `./bin/flixbox init`, open **`${CONFIG_DIR}/maintainerr/rule-pack.md`** for step-by-step UI setup (Rules A/B/C). Same thresholds as [09-hygiene-defaults.md](../09-hygiene-defaults.md).

## Hardlinks and free space

Deleting a library file that is still hardlinked to an active torrent **does not free disk** until the torrent copy is gone too. Plan seeding vs cleanup together.

## Full thresholds

Engineering detail: [09-hygiene-defaults.md](../09-hygiene-defaults.md)

## Next

[Day-2 operations](09-operations.md)
