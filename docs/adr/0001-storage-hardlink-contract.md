# ADR 0001: Storage hardlink contract

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-27 (incomplete path + permissions note)

## Context

Split mounts (`/downloads` vs `/movies`) cause cross-device copies, double disk use while seeding, and slow imports. TRaSH Guides recommend a shared parent path so *arr can `link()`.

## Decision

All containers that read/write downloads or libraries MUST mount the same host parent as `${DATA_DIR}:/data`.

v0.1 baseline layout:

```
/data/torrents/incomplete
/data/torrents/movies|tv
/data/media/movies|tv
```

`/config` stays on local SSD/NVMe and is separate from `/data`.

Permissions: **single shared PUID/PGID** with `UMASK=002` and SGID on data dirs (Flixbox simpler model). Not TRaSH per-app UID model.

## Consequences

- Hardlinks work on a single filesystem device.
- MergerFS/Unraid/multi-disk/`exFAT` layouts need special care or fail.
- Contributors must never remount subpaths as separate parent volumes.
