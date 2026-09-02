# Maintainerr rule pack (Flixbox standard)

Copied to `${CONFIG_DIR}/maintainerr/` by `./bin/flixbox init`.

| File | Purpose |
| --- | --- |
| [rule-pack.md](rule-pack.md) | Step-by-step UI rules (A/B/C) matching [docs/09-hygiene-defaults.md](../../docs/09-hygiene-defaults.md) |

**Quick summary**

- Rule A — Unwatched movies: 90d → Leaving Soon → delete after 14d
- Rule B — Quiet TV: 180d no watches, added &gt; 90d → Leaving Soon → delete after 21d
- Rule C — Watched movies reclaim: **OFF** by default
- Skip items added in last 30 days; configure Keep exclusions before enabling deletes

Full operator runbook: [docs/user/15-credential-rotation.md](../../docs/user/15-credential-rotation.md) (after API key changes) · [docs/user/08-hygiene.md](../../docs/user/08-hygiene.md)
