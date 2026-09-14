# ADR 0021: CLI UX contract (professional Bash surface)

- **Status:** Accepted (post-MVP — target ~v0.2; Phase A slices MAY land before public v0.1 if low risk)
- **Date:** 2026-09-06
- **Updated:** 2026-09-14 — implementation progress vs contract; doc path `17-cli.md`; help MUST be side-effect free; globals deferral table; JSON type-change rule; lifecycle help stubs + DATA_DIR operator-owned
- **Related:** [0005](0005-cli-bash-first.md), [0007](0007-platform-support-tiers.md), [0010](0010-mit-and-image-tags.md), [0011](0011-documentation-i18n.md), [0015](0015-access-profiles.md), [0016](0016-configure-state-machine.md), [0018](0018-runtime-secrets-and-lan-trust.md), [0020](0020-operator-credentials-cli.md)

## Implementation progress (2026-09-14)

Honest snapshot against this contract (does **not** reopen decisions):

| Area | State |
| --- | --- |
| `version` / `--version`, `doctor`, `status --json`/`-q`/`-v`, exit 2/3 on touched paths | **Landed** |
| Human presentation (`cli-msg`: PASS/FAIL/INFO/OK, fixed-width tokens, `configure` outcomes + `summary:`) | **Landed** (extends §6) |
| Operator doc | **Landed** as [`docs/user/17-cli.md`](../user/17-cli.md) (not `16-cli.md`) + ES mirror |
| `logs` / `vpn-test` dispatch | **Landed** (regression from Phase A insert fixed) |
| Per-command `--help` for **all** shipped commands | **Landed** (A2 help safety — no Compose/env side effects; no false success lines) |
| Global `-q`/`-v`/`--json`/`--no-color` | **Partial** — `--no-color` + command-scoped `-q`/`--json` where documented; global `-q`/`-v` deferred (see table) |
| `--env-file` / `--project-dir` | **Deferred** (explicit) |
| Phase B lifecycle (`backup`/`restore`/`update`/`recyclarr`/`completion`) | **Landed** (CONFIG-only backup; DATA_DIR operator-owned; update pin-safe; recyclarr + bash/zsh completions) |
| Phase C full `die`→taxonomy + `configure --json` | **Partial** — high-traffic paths + `configure --json` landed; remaining legacy `die`→1 OK where unclassified |

### Global flags — implement vs defer

| Flag | Requirement |
| --- | --- |
| `-h` / `--help`, `--version` | MUST keep working (top-level done) |
| Command `--json` / `-q` / `-v` where documented | MUST (status/doctor today) |
| `NO_COLOR` + non-TTY plain text | MUST (landed via `cli-msg`) |
| Global `--no-color` | **Landed** (`./bin/flixbox --no-color …`; also honors `NO_COLOR` / non-TTY) |
| Global `-q`/`-v`, `--env-file`, `--project-dir` | **Deferred** until a dedicated polish slice; MUST NOT be advertised as implemented in `17-cli.md` until shipped |

### Help safety (normative addition)

`flixbox <cmd> --help` / `-h` MUST:

1. Exit **0**
2. Print synopsis to stdout (or stderr only if that command’s contract says so — prefer stdout for help text)
3. **Not** mutate host state (no Compose up/down/restart, no `.env` writes, no template copies, no `ensure_access_profile` side effects)
4. **Not** print success/outcome lines that imply work ran (e.g. must not print `Stack stopped` after forwarding `--help` to `docker compose down`)

Unknown flags on mutating commands MUST exit **2** via usage taxonomy once those paths are migrated (today some still `die` → 1).

## Context

`bin/flixbox` already covers operator domain work: `init`, `up`/`down`/`reload`/`restart`, `configure`, `credentials`, `status`, `logs`, `vpn-test` (ADR 0005 / 0020). That is a strong **ops wrapper** around Compose and Servarr APIs.

It is not yet a **professional CLI product surface**. Gaps observed in audit (2026-09-06):

| Gap | Impact |
| --- | --- |
| No `version` / `--version` | Support and bug reports lack build identity |
| Top-level help only; no `flixbox <cmd> --help` | Flags for `configure` / `credentials` are hard to discover |
| Nearly all failures `exit 1` | Automation cannot branch on Docker vs config vs VPN |
| Human-only `status` (no `--json` / `-q`) | Poor scriptability |
| No single `doctor` entrypoint | Preflight logic is scattered; operators invent checklists |
| Lifecycle commands deferred (`backup`, `update`) | Day-2 ops still require raw Compose / tribal knowledge |
| No shell completions / PATH install story | Always `./bin/flixbox` from repo root |
| Recyclarr invoked via raw `docker compose` in usage text | Breaks “one binary” mental model |
| No idempotent outcome vocabulary | Humans and scripts cannot tell noop vs change vs fail |
| No explicit security rules for CLI I/O | Risk of secret leakage via JSON, logs, completions, CI |

Industry baselines for mature CLIs (Docker CLI, GitHub `gh`, kubectl, systemd/`systemctl`, Fly):

1. Stable **command tree** + per-command help + examples.
2. Documented **exit status** taxonomy used by scripts.
3. **Machine-readable** output opt-in (`--json`) without breaking humans.
4. **Diagnostics** command (`doctor`).
5. **Completions** and a clear install/PATH story.
6. Stay thin: orchestrate Compose/APIs; do not reimplement them.
7. Predictable **stdout vs stderr**; secrets never appear unless explicitly requested.
8. **Idempotent** verbs with clear “unchanged / updated / failed” outcomes.

Constraints Flixbox MUST keep:

- Bash-only until ADR 0005 revisits PowerShell (v0.4-ish).
- No false “zero-touch” claims (indexers remain manual — ADR 0005).
- Secrets and LAN trust: ADR 0018 / 0020.
- English canonical CLI docs and messages (ADR 0011); Spanish user mirror MAY follow.
- Image pins: ADR 0010 (`update` must not drift to `:latest`).

## Decision

### 1. Scope

This ADR defines the **full CLI UX contract** for `bin/flixbox`: discoverability, scriptability, diagnostics, lifecycle command names, packaging, output/exit rules, QA expectations, and security I/O rules.

**Out of this ADR’s ownership (but linked):**

- Domain wiring semantics → ADR 0016 (`configure`).
- Credential rotate/show semantics → ADR 0020.
- Access profile bind/auth → ADR 0015.

### 2. Design principles (normative)

1. **One entrypoint:** operators prefer `flixbox …` over memorizing Compose/profile incantations.
2. **Safe by default:** destructive or secret-revealing actions require explicit subcommands/flags.
3. **Script-friendly:** stable exit codes; optional `--json`; no prompts unless TTY + explicit (`--prompt`) or documented interactive mode.
4. **Idempotent verbs:** re-running success paths MUST be safe; say when nothing changed.
5. **Honest UX:** never claim full automation where indexers/Maintainerr rules stay manual.
6. **Thin orchestration:** wrap Docker Compose and existing libs; do not fork Compose files at runtime.
7. **Fail closed on ambiguity:** unknown flags/commands → usage error (exit 2), not silent ignore.
8. **Linux-first:** completions/PATH documented for Linux; macOS/WSL best-effort (ADR 0007).

### 3. Command tree (stable names)

**Shipped (keep; extend with contract flags/help):**

```text
flixbox init | up | down | restart | reload | configure | credentials | status | logs | vpn-test
```

**Add (phased):**

| Command | Purpose | Phase |
| --- | --- | --- |
| `version` (also global `--version`) | CLI identity: semver tag if present, else `git describe --always --dirty`, plus `COMPOSE_PROJECT_NAME` / mode hint (no secrets) | A |
| `doctor` | Aggregate readiness: Docker, Compose, `.env`, paths, ports, `FLIXBOX_MODE`/`VPN_ENABLED`, access profile, Gluetun health (if VPN), key presence (boolean only) | A |
| `help` / `<cmd> --help` / `-h` | Per-command usage, flags, examples, doc links | A |
| `status` enhancements | Human summary + optional `--json`; includes service health glance (no separate `ps`/`health` command) | A |
| `backup` | Archive **config** under `${CONFIG_DIR}` (+ optional `.env` copy behind explicit flag) using SQLite-safe guidance | B |
| `restore` | Restore a `backup` archive; refuse to overwrite without `--force`; never silently wipe `${DATA_DIR}` media | B |
| `update` | `docker compose pull` of **pinned** tags + recreate; print pin table / migration notes; never rewrite pins to `:latest` | B |
| `recyclarr sync` (alias: `sync-profiles`) | First-class wrap of Recyclarr profile one-shot | B |
| `completion bash\|zsh` (fish optional) | Print or install completion script | B |

**Aliases (optional, documented):**

| Alias | Canonical |
| --- | --- |
| `flixbox --version` | `version` |
| `flixbox sync-profiles` | `recyclarr sync` |
| `flixbox doctor --json` | JSON diagnostics (Phase A/B) |

**Do not add:** plugin system, full TUI framework, Go rewrite, remote multi-host agent, separate `ps`/`health` commands (fold into `status` + `doctor`).

### 4. Global flags (contract)

Parsed before the subcommand when present in argv (order: globals MAY appear before or after subcommand **only if** implementation documents one rule — prefer **globals before subcommand** for predictability, matching `docker`/`gh` common patterns; if both are accepted, tests MUST lock behavior).

| Flag | Behavior |
| --- | --- |
| `-h` / `--help` | Help for current command context; exit 0 |
| `--version` | Same as `version`; exit 0 |
| `-q` / `--quiet` | Suppress info/ok on stdout; warnings/errors still on stderr |
| `-v` / `--verbose` | Extra diagnostics on stderr (does not dump secrets) |
| `--json` | Structured stdout where implemented; human banners forbidden on stdout |
| `--no-color` | Force plain text (also honor `NO_COLOR` and non-TTY) |
| `--env-file PATH` | Load/override env from file instead of default `${ROOT}/.env` (must not print file contents) |
| `--project-dir DIR` | Override repo/project directory (default: parent of `bin/`) |

Unknown global or command flags → exit **2** + hint to `--help`.

Command-specific flags (`configure --dry-run`, `credentials set --generate`, `backup --include-env`, `restore --force`, `update --dry-run`) remain owned by those commands but MUST appear in `<cmd> --help`.

### 5. Exit code taxonomy (normative)

| Code | Meaning | Examples |
| --- | --- | --- |
| `0` | Success, including intentional noop (“already configured”) | `configure` nothing to do; `help`; `version` |
| `1` | Unexpected / unclassified error (legacy `die` fallback during migration) | Bug paths only long-term |
| `2` | Usage error | Unknown command/flag; missing required arg |
| `3` | Docker / Compose unreachable or compose op failed | Daemon down; `up`/`reload` compose error |
| `4` | Configuration invalid | Bad `.env`; path validation; mode/VPN_ENABLED mismatch treated as config when blocking |
| `5` | Dependency not ready | Gluetun unhealthy; required container not running for `configure`/`vpn-test` |
| `6` | Partial success | `credentials set arr-ui` applied 2/3 apps — caller MUST inspect stderr/JSON |

Rules:

- New code paths MUST use 2–6 where applicable.
- Migrating legacy `die`→`1` to taxonomy is incremental; Phase A MUST at least map usage→2 and Docker→3 for touched entrypoints.
- Exit `6` MUST NOT be used for “success with warnings”; warnings + exit 0 if overall goal met.
- CI SHOULD assert taxonomy for `version`/`help`/unknown command before claiming Phase A done.

### 6. Output and messaging contract

#### Streams

| Stream | Content |
| --- | --- |
| **stdout** | Primary result: human summary, `--json` payload, `credentials show` secrets, completion scripts |
| **stderr** | `log`/`warn`/`die`, progress, `--verbose` diagnostics |

#### Human vocabulary (MUST)

Long-running or mutating commands SHOULD emit outcome lines using a stable vocabulary:

| Token | Meaning |
| --- | --- |
| `unchanged` | Idempotent noop |
| `updated` / `created` / `removed` | Mutation applied |
| `failed` | Action did not complete |
| `skipped` | Intentionally not attempted (with reason) |

`configure` and `credentials` are in scope for this vocabulary when refactored; new lifecycle commands MUST use it from day one.

#### `--json`

- Single JSON **object** on stdout (default). NDJSON only if a command documents streaming events.
- Top-level `"schemaVersion": 1` required for current payloads.
- Breaking key removals/renames **or JSON type changes** (e.g. string → boolean for `vpnEnabled`) require `schemaVersion` bump + release note.
- On `--json`, do not print human banners to stdout.
- `doctor` / `status` JSON includes booleans like `apiKeysPresent` — **never** key values.
- Prefer native JSON booleans for flag-like fields in new schema versions (today `status.vpnEnabled` may still be a string until bumped).

#### Idempotence

Re-running `configure`, `credentials set` with same desired state, `doctor`, `status`, `backup` (new archive name each time is OK) MUST NOT corrupt state. `restore` / `down --volumes` are destructive and require explicit flags + help warnings.

### 7. `status` vs `doctor` (no duplicate `ps`)

| Command | Operator question |
| --- | --- |
| `status` | “What is running right now?” — Compose ps summary, mode, access profile, download-client URL, health glance |
| `doctor` | “Can I operate / what is wrong?” — deeper checks, actionable fix hints, exit non-zero on hard failures |

`vpn-test` remains the VPN **egress IP** probe; `doctor` MAY call or summarize it but MUST NOT replace detailed leak audits in privacy docs.

### 8. Help and documentation

- `flixbox` / `flixbox help` → command list + one-line purpose (grouped: lifecycle / config / diagnostics).
- `flixbox <cmd> --help` → synopsis, flags, examples, related doc path, exit codes that command commonly returns.
- Usage errors suggest `flixbox <cmd> --help`.
- **Help safety:** see Implementation progress — help MUST be side-effect free and MUST NOT lie about work completed.
- Ship **`docs/user/17-cli.md`** (canonical CLI reference; historically sketched as `16-cli.md` in early drafts of this ADR): install/PATH, flags (implemented vs deferred), exit taxonomy, streams, JSON notes, security warnings, command catalog.
- Update REFERENCE cheat sheet to point at `17-cli.md`.
- CLI **user-visible** strings remain English (ADR 0011).

### 9. Packaging and completions

| Item | Requirement |
| --- | --- |
| Run from clone | `./bin/flixbox` remains supported forever |
| PATH install | Document symlink/copy to `~/.local/bin/flixbox` (Linux); macOS/Homebrew optional note |
| Completions | `flixbox completion bash` / `zsh` print script; docs show how to source |
| Shebang / shell | `#!/usr/bin/env bash`; require Bash 4+ (document); `set -euo pipefail` retained |
| Man page | Optional; not required for ADR acceptance |

### 10. Security I/O rules (CLI-specific; extends ADR 0018 / 0020)

1. **Secret reveal:** only `credentials show` (and documented restore of operator-owned backup that includes `.env`). Never `status`/`doctor`/`version`/`logs` wrappers printing env secrets.
2. **Argv:** do not accept passwords as positional CLI args; use `--prompt` (TTY) or `--generate`. API keys are not passed on argv to child Python helpers (ADR 0020).
3. **Process list:** prefer env/`--env-file` over embedding secrets in `docker compose` command strings that land in `ps`.
4. **JSON redaction:** schemas MUST NOT include password or raw API key fields.
5. **Completions:** MUST NOT shell-out to `credentials show` or interpolate secrets into completion results.
6. **`--include-env` on backup:** off by default; help text MUST warn the archive is sensitive and should be stored like `.env`.
7. **Trusted LAN banner:** keep ADR 0018 `up` warning behavior; `doctor` SHOULD surface access-profile risk summary.
8. **Dry-run:** `configure --dry-run`, and Phase B `update --dry-run` / `backup` preview where applicable, MUST not write secrets to world-readable temp files.
9. **Exit codes** MUST NOT encode secret material.

### 11. Bash / Linux implementation standards

1. `set -euo pipefail` at entry; libraries MUST NOT disable nounset casually.
2. Prefer `printf` over `echo` for portable output.
3. Quote variables; ShellCheck clean at CI severity already used by the repo.
4. Long options in help; short options only where listed in this ADR or long-established (`-f` for logs follow).
5. Signals: Compose child processes remain Compose’s concern; CLI SHOULD not trap in ways that leave containers undefined mid-`up` without documenting it.
6. Avoid `eval` on operator input; parse flags with explicit loops/`case`.
7. Root check: do not require root; if Docker needs group perms, fail with exit 3 + actionable stderr (existing daemon message pattern).

### 12. Testing / QA contract

Phase A minimum automated checks (no full stack required):

| ID | Check |
| --- | --- |
| Q-01 | Unknown command → exit 2 |
| Q-02 | `version` / `--version` → exit 0; stdout non-empty |
| Q-03 | `help` and `status --help` → exit 0 |
| Q-04 | `status --json` (Docker optional): if Docker down → exit 3 **or** JSON with error field + exit 3 (pick one; test locks it) |
| Q-05 | `--json` on `status` when healthy includes `schemaVersion` |
| Q-06 | ShellCheck on CLI scripts |

Phase B adds:

| ID | Check |
| --- | --- |
| Q-10 | `backup --help` documents include/exclude |
| Q-11 | `restore` without `--force` refuses overwrite |
| Q-12 | `update` dry-run does not recreate |
| Q-13 | completion scripts are valid bash/zsh syntax smoke |

Manual QA (operator checklist in smoke test or `17-cli.md`):

- First-run path: `init` → `up` → `doctor` → `configure` → `status`
- VPN path: `doctor` + `vpn-test` exit codes
- Credentials: `show` only on stdout; `set --generate` does not echo password unless `show`
- Idempotence: second `configure` reports unchanged / exit 0

### 13. Phasing

| Phase | Goal | Blocks public v0.1? |
| --- | --- | --- |
| **A — UX contract** | version, help on diagnostics, exit taxonomy on touched paths, doctor, status --json/-q, docs `17-cli.md`, Q-01–Q-06 | No (MAY ship earlier as polish) |
| **A2 — Help + globals polish** | Per-command `--help` for **all** shipped commands (side-effect free); command-scoped completeness; optional global `--no-color`; document remaining deferrals | No — finish before claiming “Phase A done” in operator docs |
| **B — Lifecycle** | backup/restore, update, recyclarr sync, completions, PATH docs | No — v0.2 |
| **C — Hardening** | Finish die→taxonomy migration; expand JSON for configure summary; `status` JSON schemaVersion bump if types change; optional man page; fish completions | No — ongoing |

Phase A (core diagnostics) is largely landed as of 2026-09-14. **Do not** mark operator docs “Phase A complete” until **A2** help parity + honest flag deferrals are done.

### 14. Relationship to ADR 0005

ADR 0005 remains Bash-first + MVP command set. This ADR **extends** day-2 UX quality and locks roadmap command names. It does not reopen PowerShell, inventory, or zero-touch claims.

## Consequences

### Positive

- Single normative contract for humans, CI, and AI agents implementing CLI work.
- Operators get diagnostics and lifecycle verbs without learning Compose profiles by heart.
- Security I/O rules reduce accidental secret leakage as JSON/completions land.
- QA gains an explicit test matrix instead of ad-hoc greps only.

### Trade-offs / risks

- Taxonomy migration is gradual; document “best effort” until Phase C.
- JSON schemas are a compatibility surface — discipline required.
- `backup`/`restore` false safety if scope is unclear — MUST document CONFIG vs DATA and `.env` opt-in.
- `--env-file` + multiple env sources can confuse operators — help MUST state precedence (explicit file overrides default `.env`).
- Completions/PATH are best-effort on macOS/WSL.

### Non-goals

- Replacing Docker Compose.
- Interactive wizard framework beyond `init` / `credentials --prompt`.
- PowerShell parity (future ADR).
- Fleet/remote multi-host management.
- Guaranteeing bit-identical output across Bash 3 vs 4 (require Bash 4+).
- Localizing CLI stderr/stdout strings in Phase A/B.

## Acceptance sketch

### Phase A (diagnostics core — largely landed 2026-09-14)

- [x] `flixbox version` / `--version`
- [x] `flixbox doctor` (+ optional `--json`)
- [x] `status --json` / `-q` with health glance + `schemaVersion`
- [x] Usage → exit 2 on unknown top-level command; Docker → exit 3 on touched compose/status paths
- [x] `docs/user/17-cli.md` + REFERENCE link (+ ES mirror)
- [x] CI Q-01–Q-06 (extended with presentation guards)

### Phase A2 (help + honesty — landed)

- [x] Per-command `--help` for **all** shipped commands, exit 0, **no side effects**, no false success lines
- [x] `init`/`up`/`reload` unknown flags → exit 2 (not opaque `die`/Compose passthrough for profiles)
- [x] Global `--no-color` (`FLIXBOX_NO_COLOR` / `NO_COLOR`); remaining globals deferred honestly in `17-cli.md`
- [x] `--env-file` / `--project-dir` still deferred (listed in `17-cli.md`)
- [x] CI: every command in top-level help responds to `--help` with exit 0; `down --help` must not print `Stack stopped`

### Phase B

- [x] Help stubs + flag parse for `backup`/`restore`/`update`/`recyclarr sync`/`sync-profiles`/`completion`; CONFIG-only scope + DATA_DIR operator-owned documented; `scripts/backup.sh` → thin CLI wrapper (decision locked)
- [x] `backup` / `restore` bodies with documented scope + `--include-env` / `--force`
- [x] `update` respects ADR 0010 pins; `--dry-run`
- [x] `recyclarr sync` (alias `sync-profiles`)
- [x] bash/zsh completions + install notes
- [x] QA Q-10–Q-13 + manual checklist items

### Phase C

- [x] Remaining high-traffic `die` paths classified into 2–6 (`die_usage`/`die_config`/`die_partial` on credentials, preflight, init/up/reload)
- [x] `configure --json` summary without secrets
- [x] `homepage` / `credentials set` emit ADR §6 outcome vocabulary via `cli-msg`
- [x] JSON type cleanups (`vpnEnabled` boolean) behind `schemaVersion` bump (`status` → 2)
- [x] Smoke-test doc cross-links CLI doctor path

## Alternatives considered

| Alternative | Why rejected |
| --- | --- |
| Rewrite CLI in Go/Cobra | High cost; domain logic is shell+Python; UX contract does not require new language |
| Keep raw Compose for day-2 forever | Fragments “one tool” story |
| Docs-only improvement | Cannot fix exit codes / JSON / completions |
| Full POSIX 0–255 semantic table | Overkill for operators |
| Separate `flixbox ps` / `health` | Duplicates Compose; fold into `status`/`doctor` |
| Always-on JSON | Breaks human operators; opt-in is enough |

## Multi-role validation (review record)

Recorded at expansion (2026-09-06); **Accepted** same day as contract (implementation remains phased A/B/C). Re-run checks after Phase A lands.

| Role | Focus | Result |
| --- | --- | --- |
| Maintainer / architect | ADR alignment, phasing, non-goals | Pass — does not reopen 0005/0010/0018 |
| Homelab operator (user) | Discoverability, doctor, backup honesty | Pass with MUST on backup scope docs |
| QA | Exit codes, idempotence, automated matrix | Pass — Q-01+ required for Phase A done |
| Bash/Linux CLI expert | `set -euo`, streams, flags, Bash 4+ | Pass — §11 normative |
| Security | Secret I/O, argv, completions, backup --include-env | Pass — §10; Accept only if §10 stays MUST |
| Automation / CI | `--json`, taxonomy, non-interactive | Pass |
| Support / docs | version + 17-cli.md + help examples | Pass |
| Accessibility / terminal | NO_COLOR, stderr/stdout, quiet | Pass |
| Release manager | v0.1 not blocked by Phase B | Pass |
