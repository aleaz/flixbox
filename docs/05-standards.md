# Engineering standards

**Status:** Working Draft  
These standards apply to all Flixbox contributions and AI-assisted edits.

## 1. Documentation

- Canonical docs language: **English**.
- User guide: `docs/user/`. Spanish mirror later: `docs/es/user/` + `README.es.md` ([ADR 0011](adr/0011-documentation-i18n.md)).
- Prefer short, concrete sentences; avoid “enterprise / IEEE” theater.
- Status labels: use **Working Draft**, **Accepted** (ADRs), or **Implemented**.
- Links must be **relative** (no `file:///home/...` paths).
- Do not promise features outside [01-scope.md](01-scope.md).
- When a decision changes architecture, add or update an ADR first.

## 2. Repository layout (target)

```
flixbox/
├── AGENTS.md
├── README.md
├── bin/flixbox
├── compose/*.yml
├── scripts/
├── docs/
├── .cursor/rules/
├── .env.example
├── .editorconfig
├── .gitattributes
└── .gitignore
```

Runtime data and configs live on the host (e.g. `/srv/flixbox/{data,config}`), not in git.

## 3. Docker Compose

- Use Compose v2 `include:` and profiles.
- One concern per file; **max 150 lines** per YAML file.
- Pin image tags to explicit versions **before public v0.1**; during early development, `:latest` (or vendor rolling default) is allowed per [ADR 0010](adr/0010-mit-and-image-tags.md).
- Always set `restart` policy and `stop_grace_period: 60s` on stateful services.
- VPN mode: healthcheck gate Gluetun before qBittorrent; publish qBit ports on Gluetun.
- Honor the `/data` mount contract; include `torrents/incomplete`.
- Optional features (Plex, proxy, socket-proxy, recyclarr) use Compose **profiles**. VPN vs Direct uses `FLIXBOX_MODE` + exclusive include.
- Seerr: `image: ghcr.io/seerr-team/seerr`, `init: true`.
- Byparr is the default CF bypass; do not default to FlareSolverr.

## 4. Environment and secrets

- Ship `.env.example` only; real `.env` is gitignored.
- Never commit VPN keys, API tokens, passwords, or provider credentials.
- Defaults: `PUID=1000`, `PGID=1000`, `UMASK=002`, timezone configurable.

## 5. Permissions model (frozen)

**Flixbox simpler model** (not TRaSH per-app UIDs):

- One shared UID/GID for media apps (`PUID`/`PGID`).
- `UMASK=002`.
- `init` applies SGID on `${DATA_DIR}` trees.

Document clearly; do not silently switch to per-app UIDs without an ADR.

## 6. Shell (`bin/`, `scripts/`)

- Bash scripts: `set -euo pipefail`.
- Trap `EXIT`/`INT`/`TERM` for cleanup when mutating terminal state or temp files.
- Prefer coreutils; optional `jq` enhancements must degrade gracefully.
- Respect `NO_COLOR` and non-TTY stdout.
- Force LF endings (`.gitattributes` / `.editorconfig`).
- No PowerShell in MVP.

## 7. Naming

- Project: `flixbox`
- Network: `flixbox_net`
- CLI: `bin/flixbox`
- Compose files: kebab-case under `compose/`
- Docs: numbered `0N-name.md` plus `adr/NNNN-title.md`
- Prefer spellings **Decluttarr**, **Maintainerr**, **Seerr**, **Byparr**

## 8. Git hygiene (when versioning starts)

- Conventional, imperative commit subjects.
- Do not commit `.env`, VPN configs, or host data.
- Future CI: gitleaks + trivy — roadmap.
- License: **MIT** (root `LICENSE`).

## 9. AI-assisted development

- Read `AGENTS.md` and `docs/01-scope.md` before implementing.
- Do not add out-of-scope services “for completeness”.
- Do not weaken hardlink or VPN contracts.
- Prefer updating docs/ADRs when behavior changes.
- Keep diffs focused; no drive-by refactors unrelated to the task.
