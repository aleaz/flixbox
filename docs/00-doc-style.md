# Flixbox documentation style guide

**Status:** Working Draft  
**Audience:** Anyone writing README, `docs/user/`, or visual assets for Flixbox.  
**Brand source of truth:** Homepage theme — `templates/homepage/custom.css` (and `templates/homepage/images/logo.png`).

This guide unifies **tone**, **page shape**, and **visual language** so the repo feels like one product (not a pile of engineering notes). Engineering precision stays in ADRs and `docs/05-standards.md`; this file owns **how we present Flixbox to operators**.

## 1. Brand tokens (match Homepage)

Use these when designing diagrams, README hero frames, slide stills, or thumbnail cards. GitHub Markdown cannot load custom fonts in prose, but **exported images and GIFs must**.

| Token | Value | Use |
| --- | --- | --- |
| Brand type | **Bebas Neue** | Wordmark “FLIXBOX” only |
| UI type | **Montserrat** (500–700) | Labels, captions, diagram text |
| Background | `#0b0d13` | Diagram / mock canvas |
| Card | `rgba(22, 26, 35, 0.80)` ≈ `#161a23` | Panels in composites |
| Border | `rgba(255, 255, 255, 0.12)` | Soft separators |
| Text primary | `#f0f6fc` | Titles |
| Text secondary | `#8b949e` | Body / captions |
| Text muted | `#6e7681` | Hints |
| Healthy | `#10b981` | Status OK |
| Warning | `#f59e0b` | Caution |
| Danger | `#f43f5e` | Fail / ban / leak |

**Do not** invent a second palette (no purple SaaS gradients, no cream/serif “editorial” look) for Flixbox marketing assets. Align with the Ops dashboard the operator already sees.

**Logo:** prefer `templates/homepage/images/logo.png` (copy into `docs/images/shared/` when publishing README/docs so paths stay stable under `docs/images/`).

## 2. Voice and promises

### Principles

1. **Benefit before inventory** — say what the operator gains; list services second.
2. **Honest time** — give ranges (`~15 min` up, indexers after). Never imply zero-touch.
3. **Show, then tell** — screenshot / diagram / CLI tape before long command walls when possible.
4. **One audience per layer** — README + `docs/user/` = operators; `docs/adr/` + engineering map = contributors.

### Prefer / avoid

| Prefer (operator) | Avoid in entry docs (too early) |
| --- | --- |
| “Four commands: init, up, configure, status” | “Bash orchestration and Compose modularity” |
| “Same disk for downloads and library — no double copy” | “Hardlink contract / ADR 0001” as the first sentence |
| “Flip to VPN without rewiring Radarr/Sonarr” | Leading with `network_mode: service:gluetun` |
| “Hygiene that does not delete by surprise” | Dumping Decluttarr env var tables in the README hero |

ADRs and contract IDs belong in engineering docs, troubleshooting deep links, and “see also” — not the first screen of the README.

## 3. User-guide page template

Use this shape for new or heavily revised pages under `docs/user/` (especially overview, how-it-works, install, first-run):

1. **At a glance** — one short paragraph + up to three bullets (outcome, who, time).
2. **Before you start** — only the requirements that matter for *this* page.
3. **Steps** — numbered, one primary action per step.
4. **Verify** — how the operator knows it worked (URL loads, `status` healthy, log line, etc.).
5. **If it fails** — two to four common failures with links to [Troubleshooting](user/10-troubleshooting.md).
6. **Next** — single clear link forward.

Keep REFERENCE and deep configuration pages more tabular; they do not need a marketing hero.

## 4. Callouts (consistent labels)

In English canonical docs, lead the blockquote or paragraph with a fixed label:

- **Tip:** shortcut or optional path  
- **Important:** contract / must-not-break (e.g. `/data`, `qbittorrent:8080`)  
- **Warning:** footgun (ban, shared Wi‑Fi, public bind)  
- **Expected:** what success looks like after a step  

Do not invent new label vocabularies per page.

## 5. Commands and verify

- Prefer `./bin/flixbox …` over raw `docker compose` in operator docs.  
- One command (or one short block) per step when teaching.  
- After non-obvious steps, add **Expected:** (status healthy, Homepage at `:3000`, etc.).  
- Never paste real passwords, API keys, or personal media titles into screenshots or tapes.

## 6. README shape (product face)

Target section order for the root `README.md` (implement when assets exist):

1. Wordmark / logo + one-line USP  
2. Badges (license, CI)  
3. Hero visual (Homepage screenshot and/or CLI tape)  
4. Why Flixbox (benefit bullets)  
5. How it works (3-step diagram, link to deep dive)  
6. Quick start (three steps max)  
7. Choose your path (Direct / shared / VPN / HTTPS)  
8. Docs hub links  
9. What’s included (`<details>`)  
10. License + disclaimer  

Full service inventory and ADR indexes stay out of the hero.

## 7. Visual assets

Naming, folders, and i18n rules: [images/README.md](images/README.md).  
Capture priorities and CLI tape script: same file, **Brand-first capture checklist**.

## 8. Relationship to other docs

| Doc | Owns |
| --- | --- |
| This file | Operator-facing tone, page shape, brand tokens for assets |
| [05-standards.md](05-standards.md) | Engineering writing, git commit rules, Compose/shell standards |
| [user/INDEX.md](user/INDEX.md) | Operator reading order |
| [AGENTS.md](../AGENTS.md) | AI/agent hard constraints |

When brand tokens in Homepage CSS change, update **§1** here and re-export affected diagrams/screenshots.
