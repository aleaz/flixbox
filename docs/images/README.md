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
| CLI cold-start tape | `shared/cli-quickstart.gif` (+ `.tape` source) |
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

- [x] **Logo for docs:** `shared/logo.png` (from Homepage templates) — README embeds at ~110px
- [x] **Homepage screenshot (wide):** `en/homepage-ops.png`
- [x] **Homepage screenshot (tall crop):** `en/homepage-ops-v.png` — optional alternate for narrow embeds
- [x] **CLI tape (~35–50s feel):** `shared/cli-quickstart.gif` (source: `shared/cli-quickstart.tape`)

#### README narrative order (comms)

1. Compact logo + name + tagline + badges  
2. **How it works** (Ask → Download → Watch) — concept before UI chrome  
3. Homepage screenshot (proof of destination)  
4. CLI GIF (proof of path)  
5. Why Flixbox → Quick start  

#### VHS / tape script (cold start, Direct)

Record from the **repo root** with host **`:8080` free** (default `QBITTORRENT_PORT`) and writable paths from `.env.example` (Linux: `/srv/flixbox/…`).

Visible in the GIF:

1. `cp .env.example .env`
2. `./bin/flixbox init --non-interactive`
3. `./bin/flixbox up`
4. `./bin/flixbox status`
5. `./bin/flixbox configure` (automatic app wiring; indexers stay manual)

Lab-only: if a leftover `.env` must be removed before `cp`, do it under `Hide` and **`clear` before `Show`** so `rm` never appears in scrollback.

Re-render: `vhs docs/images/shared/cli-quickstart.tape`  
Use `PlaybackSpeed` **~1.4** (not 3.0) so success lines stay readable; hold longer after Init/Stack started/status. Prefer cutting dead `up` wait over speeding the whole demo.

If you only need to slow an existing **clean** render without re-running the stack:  
`ffmpeg -i cli-quickstart.gif -filter_complex "setpts=FACTOR*PTS,split[a][b];[a]palettegen[p];[b][p]paletteuse" out.gif`  
(e.g. factor `2.14` maps a 3.0× tape to ~1.4× feel). Do **not** ffmpeg-slow a GIF that still contains lab helpers — re-record instead.

VPN demo is a separate optional take (not in this tape).

### P1 — how-it-works / install

- [ ] `shared/pipeline-ask-download-watch.png` — three stages only (Ask / Download / Watch); dark canvas per style guide  
- [ ] `shared/data-hardlink.png` — replace placeholder in [user/02-how-it-works.md](../user/02-how-it-works.md)  
- [ ] `shared/vpn-vs-direct-qbit.png` — only qBit in Gluetun netns; *arr/Jellyfin on LAN  

### P2 — story stills (optional second sprint)

- [ ] `en/seerr-request.png`  
- [ ] `en/jellyfin-library.png` (fake/non-personal library titles)

### After capture

1. Link assets from README and the matching `docs/user/` pages.  
   - Done for P0: root `README.md` / `README.es.md` use `shared/logo.png`, `en/homepage-ops.png`, and `shared/cli-quickstart.gif`.
2. If Homepage UI changes materially, refresh `en/homepage-ops.png` in the same release as template bumps when possible.
