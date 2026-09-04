# Plan: Remediation — ADR 0020 credentials review

- **Status:** Implemented (2026-09-04)
- **Date:** 2026-09-04
- **Scope default:** Phases A + B + C (credentials CLI + Homepage `shared` + docs)
- **Related review:** Bugbot / Security Review on uncommitted ADR 0020 work
- **Do not edit** the older ADR-authoring plan; this supersedes remediation sequencing only.

## Problem

Audit of the ADR 0020 credentials CLI found defects that make operator rotation unreliable or weaken `shared` isolation:

| ID | Severity | Summary |
| --- | --- | --- |
| R1 | High | `credentials set qbit` writes the **new** password to `.env` then runs `configure --sync-qbit-auth`, which authenticates with `.env` while qBit still has the **old** password → desync |
| R2 | Medium | Servarr API key passed on Python **argv** in `arr-host-config-auth.py` (`ps` / `/proc` visible) |
| R3 | Medium | `homepage-sync.py` injects admin widget secrets; under `shared`, Homepage stays LAN-open without auth |
| R4 | Low | Host Config error dumps may leak sensitive JSON fields on stderr |
| R5 | Low | qBit rotate invokes full `configure-apps.sh` (broad side effects) |

## Validated root causes

- `--sync-qbit-auth` is an **align** tool: login with current `.env` or session temp password, then push that value into qBit + consumers ([`scripts/configure/qbittorrent.sh`](scripts/configure/qbittorrent.sh)).
- `credentials set qbit` needs a **rotate** tool: authenticate with **old**, set **new**, then persist `.env`. Reusing align after mutating `.env` cannot work.
- Passwords for Host Config already use env; API key incorrectly used argv ([`scripts/lib/arr-host-config-auth.py`](scripts/lib/arr-host-config-auth.py)).
- Homepage is explicitly not an admin auth boundary (ADR 0015/0018); syncing admin keys under `shared` undermines localhost admin bind.

## Principles

1. Separate **rotate** (`credentials set qbit`) from **align** (`configure --sync-qbit-auth`).
2. Secrets only via env/stdin — never argv (same spirit as C-61).
3. Under `shared`, do not auto-inject admin credentials into Homepage widgets.
4. One behavioral change ⇒ docs + CI gate.

```mermaid
sequenceDiagram
  participant CLI as credentials_set_qbit
  participant Env as env_file
  participant QBit as qBit_WebUI_API
  participant Hyg as Decluttarr

  CLI->>CLI: old from env, new generate or prompt
  CLI->>QBit: auth old or temp from logs
  alt auth OK
    CLI->>QBit: setPreferences new
    CLI->>QBit: auth new
    CLI->>Env: write QBITTORRENT_PASSWORD
    CLI->>Hyg: force recreate Decluttarr
  else auth fail
    CLI-->>CLI: abort; env unchanged
  end
```

---

## Phase A — Credentials CLI (blocking)

### A1. R1 + R5 — Correct narrow qBit rotate

**Implement** `flixbox_apply_qbit_password_rotate` (in [`scripts/lib/credentials.sh`](scripts/lib/credentials.sh) or a small dedicated lib) that reuses `qbit_auth` / `qbit_set_webui_password` from [`scripts/lib/configure-helpers.sh`](scripts/lib/configure-helpers.sh).

**Normative steps:**

1. Read `old` from `.env` **before** any write.
2. Obtain `new` via `--generate` / `--prompt`.
3. Set minimal qBit context (container, cookie path, internal API URL) — mirror configure preflight vars as needed.
4. Authenticate with `old`; on failure try temp password from `docker logs` (same pattern as configure preflight).
5. `qbit_set_webui_password(new)` → re-auth with `new`.
6. **Only then** `flixbox_env_file_set` `QBITTORRENT_PASSWORD` (ensure username present).
7. `docker compose up -d --force-recreate --no-deps decluttarr`.
8. Do **not** call full `configure-apps.sh` for this path.
9. *arr download clients: leave alone when they use API key; docs say run `configure` / `--sync-qbit-auth` if Test fails after rotate.

**On auth failure:** leave `.env` unchanged; actionable error (show current `.env` via `credentials show` is operator choice; do not print secret in the error).

**Do not:** pass `PREV_PASSWORD` into `--sync-qbit-auth` while still running full configure.

### A2. R2 — API key via env

- [`arr-host-config-auth.py`](scripts/lib/arr-host-config-auth.py): read `ARR_API_KEY` from env; prefer URL from env `ARR_HOST_CONFIG_URL` or single non-secret argv URL only — **no** key in argv.
- [`credentials.sh`](scripts/lib/credentials.sh): invoke with env only for secrets.
- Extend CI (C-87 or sibling): fail if key is passed positionally or script still requires argv key.

### A3. R4 — Redact Host Config errors

- Before printing truncated error bodies, mask JSON fields matching `password`, `passwordConfirmation`, `apiKey` (case-insensitive).
- Do not dump bodies on success.

### A4. QA / CI for Phase A

Manual or scripted checklist:

1. Stable qBit password set; `credentials set qbit --generate` → WebUI accepts **new**; Decluttarr not idle; `.env` matches.
2. Wrong/stale auth scenario → `.env` **unchanged**.
3. `credentials set arr-ui` under `trusted` → non-zero exit.
4. Under `shared` (or Host Config spike): apply works; `ps` during apply shows no API key.
5. `shellcheck` + `ci-validate` (updated C-87).

---

## Phase B — Homepage vs `shared` (R3)

In [`scripts/lib/homepage-sync.py`](scripts/lib/homepage-sync.py), when `FLIXBOX_ACCESS_PROFILE=shared`:

- Do **not** write `username` / `password` / `key` for admin surfaces: qBittorrent, Prowlarr, Radarr, Sonarr, Maintainerr, Byparr, Bazarr.
- **Do** sync ports/href and consumer widgets: Jellyfin, Seerr; VPN/Direct card unchanged.
- Clear existing admin widget credentials already present in `services.yaml` (strip fields / drop admin widget blocks so old secrets do not linger).
- When profile is `trusted`, keep current credential sync behavior.

Docs: one threat-model sentence in [`docs/user/13-access-profiles.md`](docs/user/13-access-profiles.md).

CI: fixture test or validate gate — with `shared`, synced output must not contain fixture admin passwords/keys for qBit/Radarr.

---

## Phase C — Documentation consistency

- [`docs/adr/0020-operator-credentials-cli.md`](docs/adr/0020-operator-credentials-cli.md): Updated note — qBit **rotate** vs **align**; Arr API key via env.
- [`docs/user/15-credential-rotation.md`](docs/user/15-credential-rotation.md) + [`docs/user/REFERENCE.md`](docs/user/REFERENCE.md): stop implying `set qbit` → full configure.
- ADR 0015 / 0018 or §13: Homepage under `shared` (Phase B).

---

## Implementation order

1. A1 (P0)
2. A2 + A3
3. A4
4. B
5. C

## Out of scope

- Deeper Jellyfin/Seerr rotation beyond current best-effort
- Docker secrets / Authelia
- Changing `--sync-qbit-auth` into a rotate command (remains **align** only)

## Second-pass findings (post R1–R5) — remediated

| ID | Severity | Summary | Fix |
| --- | --- | --- | --- |
| R6 | High | After `setPreferences` OK, re-auth fail left `.env` unchanged while qBit had NEW | Exit **3**; caller persists `.env`; best-effort rollback when possible |
| R7 | Medium | `set -e` + `[[ attempt -lt N ]] && sleep` could abort early | Explicit `if`/`sleep` in rotate loop |
| R8 | Medium | Homepage only blanked fields; widget blocks remained under `shared` | Drop entire admin widget blocks in `homepage-sync.py` |
| R9 | Medium | `06-configuration.md` still preferred `--sync-qbit-auth` for inventing passwords | Document **rotate** vs **align** |
| R10 | Medium | `arr-ui` wrote `.env` before Host Config apply | Apply with `FLIXBOX_ARR_UI_PASSWORD_OVERRIDE`; write on success/partial only |
| R11 | Low | Forms login cookie check too loose; dry-run `--sync-arr-ui` ignored profile | Require `*Auth` cookie; dry-run message when not `shared` |
| R12 | Medium | `configure --dry-run` aborted after qBit (`$SYNC_QBIT_AUTH && dry` → `return` status 1 under `set -e`) so `--sync-arr-ui` never ran | `if $SYNC_QBIT_AUTH; then dry …; fi; return 0` |
| R13 | Medium | Dry-run preflight left `QBIT_API_KEY` unset → `set -u` abort before `--sync-arr-ui` | Export empty qBit placeholders in `configure_dry_run_preflight` |
| R14 | High | `configure` alone did not run `homepage-sync` → stale admin widgets under `shared` | `configure_entry_sync_homepage` in `configure_entry_prepare` |
| R15 | Medium | `06-configuration` Homepage credentials row said “no secrets” | Document trusted vs shared widget sync |

## Acceptance

- [x] R1 fixed: rotate does not desync `.env` / qBit
- [x] R2 fixed: no API key on argv; CI guards
- [x] R3 fixed: no admin widget secret sync under `shared`
- [x] R4 fixed: redacted error bodies
- [x] R5 fixed: no full configure on `set qbit`
- [x] R6–R15 fixed (second + final pass)
- [x] Docs state rotate vs align clearly
- [x] A4 checklist / ci-validate (run verify after implement)
