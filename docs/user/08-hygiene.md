# Hygiene (Decluttarr + Maintainerr)

Flixbox includes two helpers so the stack does not silently rot.

## Decluttarr — download queue

Removes stuck or useless downloads and can ask Radarr/Sonarr to search again.

Default idea:

- Stalled / too slow / failed / orphan → remove (with a few strikes of grace)
- Tag **`flixbox-keep`** on a torrent → never auto-remove
- Do **not** remove “unmonitored” items by default

Use the correct qBit URL for your mode (`gluetun` vs `qbittorrent`).

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

## Hardlinks and free space

Deleting a library file that is still hardlinked to an active torrent **does not free disk** until the torrent copy is gone too. Plan seeding vs cleanup together.

## Full thresholds

Engineering detail: [09-hygiene-defaults.md](../09-hygiene-defaults.md)

## Next

[Day-2 operations](09-operations.md)
