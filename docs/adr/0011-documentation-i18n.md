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

### ES scope (explicit inventory — R5)

**In scope for Spanish before first public release**

| Artifact | Path | Notes |
| --- | --- | --- |
| Root landing | `README.es.md` | Link from `README.md` when present |
| User guide pages | `docs/es/user/*.md` | Same basenames as `docs/user/` (`01-overview.md`, …) |
| User guide index | `docs/es/user/INDEX.md` | Tracks EN revision when useful |
| Quick reference | `docs/es/user/REFERENCE.md` | **Currently the only translated user page besides INDEX** |
| UI screenshots | `docs/images/es/` | Same basenames as `docs/images/en/` |
| Shared diagrams | `docs/images/shared/` | Language-neutral; linked from both |

**Out of scope (English only until a future ADR)**

| Artifact | Path | Rationale |
| --- | --- | --- |
| Engineering docs | `docs/00–09`, `docs/10-ci-plan.md`, `docs/08-roadmap.md` | Low ROI for operators; EN canonical |
| ADRs | `docs/adr/` | Decision record, not operator-facing |
| Agent / contributor | `AGENTS.md`, `.cursor/rules/` | Tooling and contributor contracts |
| Operator runbooks added after v0.1 EN freeze | e.g. `docs/user/15-credential-rotation.md` | Translate in a follow-up ES PR after EN stabilizes |
| In-container templates | `templates/maintainerr/rule-pack.md`, etc. | Copied to `${CONFIG_DIR}`; EN only in MVP |

**Process boundary:** Spanish mirrors **user guide pages** under `docs/es/user/` only. Do not create `docs/es/adr/` or duplicate engineering trees. Untranslated EN pages remain the source of truth; ES INDEX may link to EN for deep dives.

**Current mirror state (2026-09):** `docs/es/user/INDEX.md` + `docs/es/user/REFERENCE.md` exist; full page mirror (`01`–`14`) is scheduled before first public release, not required for MVP CI.

## Consequences

- Folder layout is fixed now (`docs/es/` reserved, `images/{shared,en,es}/` ready).
- No doc toolchain dependency yet.
- Spanish work is scheduled for “functional stack → before first release”, not day one of coding.
