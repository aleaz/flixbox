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

- [ ] **Logo for docs:** copy `templates/homepage/images/logo.png` → `shared/logo.png` (do not leave README pointing only at `templates/`).
- [ ] **Homepage screenshot:** Ops tab, browser zoom 100%, crop chrome noise; no WAN exposure narrative; blur any hostnames you do not want public → `en/homepage-ops.png`.
- [ ] **CLI tape (~25–40s):** record with [charmbracelet/vhs](https://github.com/charmbracelet/vhs) or asciinema → GIF under `shared/cli-quickstart.gif`.

#### Suggested VHS / tape script (day-0 + day-2)

Narrate or title-card lightly; prefer real commands against a disposable or sanitized env:

1. `./bin/flixbox status` — show healthy core services  
2. `./bin/flixbox configure --dry-run` **or** a short successful `configure` on a lab stack  
3. Trigger or show Homepage stale-template **warn** path, then `./bin/flixbox homepage refresh --dry-run` (or full refresh on lab)  
4. End frame: open Homepage URL (`http://localhost:3000` or your lab port)

**Tape rules:** no passwords in clear text; no `.env` dump; use lab `DATA_DIR`/`CONFIG_DIR`; font large enough for GitHub embed (~80–100 cols).

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
