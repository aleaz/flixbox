# CLI reference (ADR 0021)

**Status:** Phase A diagnostics **landed**; Phase **A2** help safety + global `--no-color` **landed**; `backup`/`restore` **landed** (CONFIG-only); remaining lifecycle stubs next — see [ADR 0021](../adr/0021-cli-ux-contract.md)
**Audience:** Operators and automation  
**Related:** [ADR 0021](../adr/0021-cli-ux-contract.md) · [REFERENCE](REFERENCE.md)

`./bin/flixbox` is the single operator entrypoint. Phase A delivered discoverability (`version`, top-level help), diagnostics (`doctor`), scriptable `status --json`, presentation via `cli-msg`, and exit taxonomy on those paths. Per-command `--help` is side-effect free for all shipped commands (A2).

## Install / PATH

From a clone (supported forever):

```bash
./bin/flixbox --help
```

Optional Linux PATH install:

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/flixbox" ~/.local/bin/flixbox
# ensure ~/.local/bin is on PATH
flixbox version
```

Requires **Bash 4+**. Completions: `flixbox completion bash|zsh` (help available now; scripts land with completions work).

## Global flags

| Flag | Behavior | Status |
| --- | --- | --- |
| `-h` / `--help` | Top-level command list | Landed |
| `--version` | Same as `version` | Landed |
| Per-command `-h` / `--help` | Command-specific usage | Landed (lifecycle included; side-effect free) |
| `--json`, `-q` / `--quiet`, `-v` / `--verbose` | As documented per command (`status`, `doctor`, …) | Landed where documented |
| `NO_COLOR` / non-TTY | Plain tokens (no ANSI) | Landed |
| `--no-color`, global `-q`/`-v`, `--env-file`, `--project-dir` | ADR 0021 globals | `--no-color` landed; `--env-file` / `--project-dir` / global `-q`/`-v` still deferred |

## Streams (stdout vs stderr)

| Stream | Content |
| --- | --- |
| **stdout** | Primary result: `version` identity, `doctor`/`status` reports, `configure` outcome lines + `summary:`, `credentials show` secrets, `--json` payloads |
| **stderr** | Progress and tips (`INFO` / `OK` from `init`/`up`/`reload`), `WARN` / `FAIL` diagnostics, `Next:` hints |

Do not rely on color alone — tokens (`PASS` / `FAIL` / `WARN` / `INFO` / `OK`) remain in plain text when `NO_COLOR` is set or stdout is not a TTY.

`configure` outcome vocabulary on stdout: `updated` / `unchanged` / `failed` / `dry-run`, then `summary: N updated, M unchanged, K failed`.

## Exit codes (touched paths)

| Code | Meaning |
| --- | --- |
| `0` | Success (including help/version) |
| `2` | Usage error (unknown command/flag, missing args) |
| `3` | Docker / Compose unreachable or compose op failed |
| `4` | Configuration invalid (missing `.env`, bad paths/profile, mode/VPN mismatch as blocker) |
| `5` | Dependency not ready (e.g. Gluetun unhealthy in VPN mode) |

Legacy commands may still exit `1` until Phase C finishes taxonomy migration.

## Commands (Phase A additions)

### `flixbox version` / `--version`

Prints CLI identity from `VERSION` (or `git describe`), compose project name, and mode if `.env` exists. **No secrets.**

### `flixbox doctor [--json]`

Aggregate readiness: Docker CLI/daemon, Compose plugin, `.env`, `DATA_DIR`/`CONFIG_DIR`, `FLIXBOX_MODE`↔`VPN_ENABLED`, access profile, API key **presence** (booleans only), Gluetun health when `mode=vpn`.

Human output uses `PASS` / `FAIL` / `INFO` / `OK` text tokens (color is optional chrome on the token only).

`--json` emits a single object with `schemaVersion: 2` (`vpnEnabled` is a JSON boolean). Never includes key values.

### `flixbox status [--json] [-q|--quiet] [-v|--verbose]`

Human default: narrow `SERVICE` / `STATE` / `HEALTH` glance, then `key: value` context (mode, profile, paths).  
`-v`: also print full `docker compose ps`.  
`--json`: service glance + context; if Docker is down, still prints JSON with `error` and exits **3**.  
`-q`: glance only (skip context block); warnings stay on stderr.

## Security I/O

- `version`, `doctor`, and `status` never print passwords or API key values.
- Use `credentials show` when you intentionally need a secret on stdout.
- Do not pass secrets as CLI argv to helpers.

## Manual checklist

1. `./bin/flixbox version` → exit 0  
2. `./bin/flixbox nosuch` → exit 2  
3. `./bin/flixbox status --help` → exit 0  
4. `./bin/flixbox doctor` on a configured host → actionable hints; exit 0 when ready  
5. `./bin/flixbox status --json | jq .schemaVersion` → `2` when Docker works  

## Lifecycle commands (in progress)

| Command | Status | Notes |
| --- | --- | --- |
| `backup` / `restore` | Landed | Archives **`${CONFIG_DIR}`** only. **`${DATA_DIR}`** (media/torrents) is **operator-owned** — back it up yourself. Optional `.env` via `--include-env`. Restore refuses overwrite without `--force`. |
| `update` | Help stub | Pulls pinned tags (ADR 0010); never rewrites to `:latest` |
| `recyclarr sync` / `sync-profiles` | Help stub | Will replace raw Compose as the primary operator path |
| `completion bash\|zsh` | Help stub | Fish deferred |

`scripts/backup.sh` is a thin wrapper around `./bin/flixbox backup` (same CONFIG-only scope).

## Deferred (later)

Global `-q`/`-v`, `--env-file`, `--project-dir`; full `die`→taxonomy (Phase C); fish completions; optional Apprise / VPN-heal profiles — see [08-roadmap.md](../08-roadmap.md).
