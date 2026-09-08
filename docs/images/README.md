# Documentation images

Screenshots, diagrams, and CLI tapes for the user guide and README.  
**Visual brand:** follow [Documentation style guide](../00-doc-style.md) (Homepage palette + Bebas Neue / Montserrat).

## Layout (i18n-ready)

```text
docs/images/
├── README.md          ← this file
├── shared/            ← language-neutral diagrams + logo + CLI GIF/tape renders
├── en/                ← English UI screenshots (canonical guide)
└── es/                ← Spanish UI screenshots (future docs/es/user/)
```

Do **not** put English-only UI shots in `shared/`.  
Do **not** embed secrets, API keys, or personal media titles in screenshots or recordings.

## Naming

Use stable kebab-case names referenced from markdown:

| Asset | Path |
| --- | --- |
| Logo (docs copy) | `shared/logo.png` |
| Pipeline 3-step | `shared/pipeline-ask-download-watch.png` |
| `/data` hardlink | `shared/data-hardlink.png` |
| VPN vs Direct | `shared/vpn-vs-direct-qbit.png` |
| CLI quickstart / day-2 tape | `shared/cli-quickstart.gif` (or `.cast` + rendered GIF) |
| Homepage Ops | `en/homepage-ops.png` |
| Seerr request | `en/seerr-request.png` |
| Jellyfin library | `en/jellyfin-library.png` |

Spanish UI shots: same basename under `es/`.

## Markdown usage

```markdown
![Homepage Ops tab](../images/en/homepage-ops.png)
![Ask → download → watch](../images/shared/pipeline-ask-download-watch.png)
```

Spanish pages use `../images/es/...` (path relative to `docs/es/user/`).

---

## Brand-first capture checklist

Complete in order. Check off in the PR that adds README/user-facing visuals.

### P0 — required for README hero

- [x] **Logo for docs:** `shared/logo.png` (from Homepage templates)
- [x] **Homepage screenshot (wide):** `en/homepage-ops.png`
- [x] **Homepage screenshot (tall crop):** `en/homepage-ops-v.png` — optional alternate for narrow embeds
- [x] **CLI tape (~30s):** `shared/cli-quickstart.gif` (source: `shared/cli-quickstart.tape`)

#### Suggested VHS / tape script (day-0 + day-2)

Recorded against the **live lab stack** with dry-runs only (no `down`, no config wipe):

1. `./bin/flixbox status`
2. `./bin/flixbox configure --dry-run`
3. `./bin/flixbox homepage refresh --dry-run`

Re-render: `vhs docs/images/shared/cli-quickstart.tape`

A full wipe + `init`/`up` demo is optional later if you want a cold-start story; not required for the README hero.

### P1 — how-it-works / install

- [ ] `shared/pipeline-ask-download-watch.png` — three stages only (Ask / Download / Watch); dark canvas per style guide  
- [ ] `shared/data-hardlink.png` — replace placeholder in [user/02-how-it-works.md](../user/02-how-it-works.md)  
- [ ] `shared/vpn-vs-direct-qbit.png` — only qBit in Gluetun netns; *arr/Jellyfin on LAN  

### P2 — story stills (optional second sprint)

- [ ] `en/seerr-request.png`  
- [ ] `en/jellyfin-library.png` (fake/non-personal library titles)

### After capture

1. Link assets from README and the matching `docs/user/` pages.  
2. If Homepage UI changes materially, refresh `en/homepage-ops.png` in the same release as template bumps when possible.
