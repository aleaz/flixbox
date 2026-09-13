# CLI reference (Phase A)

**Status:** Implemented (ADR 0021 Phase A)  
**Audience:** Operators and automation  
**Related:** [ADR 0021](../adr/0021-cli-ux-contract.md) · [REFERENCE](REFERENCE.md)

`./bin/flixbox` is the single operator entrypoint. Phase A adds discoverability (`version`, per-command `--help`), diagnostics (`doctor`), and scriptable `status --json`, plus a stable exit-code taxonomy on those paths.

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

Requires **Bash 4+**. Completions land in Phase B.

## Global flags

| Flag | Behavior |
| --- | --- |
| `-h` / `--help` | Top-level command list |
| `--version` | Same as `version` |
| Per-command `-h` / `--help` | Command-specific usage (`status`, `doctor`, `version`, …) |

`--json`, `-q` / `--quiet` apply to commands that document them (`status`, `doctor`).

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

`--json` emits a single object with `schemaVersion: 1`. Never includes key values.

### `flixbox status [--json] [-q|--quiet]`

Human: `docker compose ps` plus mode / access profile / paths.  
`--json`: service glance + context; if Docker is down, still prints JSON with `error` and exits **3**.  
`-q`: suppress human info lines; warnings stay on stderr.

## Security I/O

- `version`, `doctor`, and `status` never print passwords or API key values.
- Use `credentials show` when you intentionally need a secret on stdout.
- Do not pass secrets as CLI argv to helpers.

## Manual checklist

1. `./bin/flixbox version` → exit 0  
2. `./bin/flixbox nosuch` → exit 2  
3. `./bin/flixbox status --help` → exit 0  
4. `./bin/flixbox doctor` on a configured host → actionable hints; exit 0 when ready  
5. `./bin/flixbox status --json | jq .schemaVersion` → `1` when Docker works  

## Deferred (Phase B+)

`backup` / `restore` / `update` / `recyclarr sync` / shell completions / full `die`→taxonomy migration — see [08-roadmap.md](../08-roadmap.md).
