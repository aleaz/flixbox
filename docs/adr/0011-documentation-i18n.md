# ADR 0011: Documentation internationalization (i18n)

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

Flixbox targets a global GitHub audience but the maintainer and many home-lab users are Spanish-speaking. We need EN-first docs without a painful restructure when Spanish lands before the first public release. Screenshots must not block translation.

## Decision

### Canonical language

- **English** is canonical for all documentation that ships in-repo today.
- User-facing guides live at **`docs/user/`** (English).
- Engineering docs stay at **`docs/00–09`**, **`docs/adr/`** — **English only** unless a future ADR says otherwise (translating ADRs has low ROI).

### Spanish (before first public release)

When the stack is functional and EN user docs are stable enough:

| Artifact | Spanish location |
| --- | --- |
| Landing | `README.es.md` (root) |
| User guide | `docs/es/user/` — **same filenames** as `docs/user/` (`01-overview.md`, …) |
| User guide index | `docs/es/user/INDEX.md` |
| UI screenshots | `docs/images/es/` (same basenames as `docs/images/en/`) |
| Shared diagrams | `docs/images/shared/` (one set, linked from both languages) |

Do **not** move English to `docs/user/en/` later. Keeping `docs/user/` as EN avoids churn.

### Process

1. Write and update **English first**.
2. Translate Spanish as a mirror; note the EN revision/date in `docs/es/user/INDEX.md` when useful.
3. Prefer short PRs: content change in EN, follow-up PR for ES (or same PR if small).
4. If EN and ES diverge, **EN wins** until ES is updated.
5. Optional later: GitHub Pages / MkDocs with a language switcher reading these folders — no need to adopt a translation platform (Crowdin, etc.) for v0.1.

### Cross-links

- Root `README.md` links to `README.es.md` when it exists (“También en español”).
- `docs/user/INDEX.md` links to `docs/es/user/INDEX.md` when it exists.
- Spanish pages may link back to English for untranslated engineering deep-dives.

### Out of scope for i18n v0.1

- Translating ADRs, scope, requirements, AGENTS.md, Cursor rules
- Machine-only translation without human review for user-facing pages

## Consequences

- Folder layout is fixed now (`docs/es/` reserved, `images/{shared,en,es}/` ready).
- No doc toolchain dependency yet.
- Spanish work is scheduled for “functional stack → before first release”, not day one of coding.
