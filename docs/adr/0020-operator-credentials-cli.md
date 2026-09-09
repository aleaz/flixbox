# ADR 0020: Operator credentials CLI

- **Status:** Accepted
- **Date:** 2026-09-04
- **Updated:** 2026-09-04 — Host Config spike validated; remediation: qBit rotate-before-env-write; Arr API key via env only
- **Related:** [0005](0005-cli-bash-first.md), [0015](0015-access-profiles.md), [0016](0016-configure-state-machine.md), [0018](0018-runtime-secrets-and-lan-trust.md), [0019](0019-qbit-webui-runtime-contract.md)

## Context

Day-0 wiring is largely automated: `init` generates API keys and operator passwords into `.env`; `up` / `configure` close the secret loop for Compose consumers and *arr download clients. Day-2 friction remains:

1. Operators must open `.env` to read generated passwords.
2. Rotating a password means hand-editing `.env` plus knowing the correct sync path (`configure`, `--sync-qbit-auth`, UI, or all three).
3. Under access profile **`shared`**, `FLIXBOX_ARR_UI_USER` / `FLIXBOX_ARR_UI_PASSWORD` are documented as **reference values only** — Forms logins for Radarr, Sonarr, and Prowlarr are created and rotated manually in each WebUI. Servarr does not expose username/password via environment variables.

Servarr Host Config APIs (`PUT /api/v3/config/host` for Radarr/Sonarr, `PUT /api/v1/config/host` for Prowlarr) accept `username`, `password`, and `passwordConfirmation` and can be called with the pre-seeded `X-Api-Key`. That makes Forms apply/rotate feasible without inventing env overrides. qBittorrent already has an apply path (`--sync-qbit-auth` / WebUI bootstrap — ADR 0019). Jellyfin admin password changes typically need a **session** token (login), not only a server API key.

Threat model (ADR 0018): anyone who can run `./bin/flixbox` on the host can already read `.env` and often `docker inspect`. A `show` command does not meaningfully enlarge host trust, but it increases accidental leakage via stdout, shell history, and screenshots.

## Decision

### CLI surface

Extend the Bash CLI (ADR 0005; no PowerShell) with:

```text
flixbox credentials show <target>
flixbox credentials set  <target> [--generate | --prompt]
```

`--generate` writes a new random password (same generator as `init`). `--prompt` reads a password from the TTY (no echo). Exactly one of `--generate` or `--prompt` is required for `set` (except where noted). Username fields keep existing `.env` defaults unless a future flag is added.

### Targets (v1)

| Target | `show` | `set` |
| --- | --- | --- |
| `qbit` | Print `QBITTORRENT_USERNAME` and `QBITTORRENT_PASSWORD` | **Rotate:** authenticate with the current `.env` password (or session temp), apply the new password to qBit WebUI, **then** write `.env`, recreate Decluttarr. Does **not** run full `configure`. Use `configure --sync-qbit-auth` only to **align** when `.env` already matches a loginable WebUI password. |
| `arr-ui` | Print `FLIXBOX_ARR_UI_USER` / `FLIXBOX_ARR_UI_PASSWORD` | Only when `FLIXBOX_ACCESS_PROFILE=shared`. Apply Host Config PUT on **Prowlarr, Radarr, and Sonarr** with the new password **first**; write `.env` only on full or partial success (never on 0/3). Report per-app success/failure |
| `admin` | Print `FLIXBOX_ADMIN_USER` / `FLIXBOX_ADMIN_PASSWORD` | Write `.env`; best-effort Jellyfin password change (authenticate with current password → set new); remind operator to run `configure` for Seerr if needed |
| `api` (`radarr` \| `sonarr` \| `prowlarr`) | Print the corresponding `*_API_KEY` from `.env` | **Not supported** — regenerate/heal remains `configure` |

**Out of scope:** Bazarr UI password, Maintainerr UI auth, Homepage auth, Docker secrets files, Authelia/Authentik, WAN remote access.

### When Forms is applied

- **Not** on every `configure` — first-run wiring stays API-key-based (ADR 0005 / 0016).
- **Yes** on `flixbox credentials set arr-ui`.
- **Yes** as opt-in force-push: `flixbox configure --sync-arr-ui` (mirror of `--sync-qbit-auth`).

### Source of truth

- `.env` remains the operator source of truth for `QBITTORRENT_*`, `FLIXBOX_ADMIN_*`, and `FLIXBOX_ARR_UI_*`.
- After this ADR, `FLIXBOX_ARR_UI_*` are **no longer reference-only**: when the operator runs `credentials set arr-ui` or `configure --sync-arr-ui`, Flixbox **MUST** attempt to apply them to all three *arr apps via Host Config.
- Manual first-visit Forms creation remains the **fallback** if Host Config apply fails (document clearly).
- API keys stay managed by `init` / `configure` (config.xml sync + consumer refresh).

### `show` security rules

- One target per invocation (no “dump all” default).
- Secret values on **stdout**; warnings/hints on **stderr**.
- Never print secrets from `flixbox status` or from ordinary `configure` logs (including API key prefixes — confirm discovery without key material).
- Operator docs MUST warn about shell history, CI logs, and screenshots (ADR 0018).

### Failure contract

| Case | Behavior |
| --- | --- |
| `set qbit` cannot authenticate to WebUI | Exit 1; `.env` unchanged; actionable message (runbook / UI reset / temp password) |
| `set qbit` setPreferences OK but re-auth verify fails | Persist new password to `.env` (exit 3 from rotate helper); warn operator to confirm WebUI login |
| `set arr-ui` when profile is `trusted` | Non-zero exit; explain Forms is `shared`-only |
| Host Config succeeds on some apps only | Non-zero exit; write `.env` (SoT for retry); retry with `--sync-arr-ui` |
| Host Config fails on all three apps | Non-zero exit; `.env` unchanged |
| `set admin` Jellyfin rejects password change | `.env` updated + warning of UI desync; operator aligns in Jellyfin UI |

### Implementation notes (normative for implementers)

- Reuse `flixbox_env_file_get` / `flixbox_env_file_set`, `generate_password`, and existing qBit helpers.
- **qBit rotate** must authenticate with the **previous** password (or session temp), apply the new password, then write `.env` on verified success **or** when setPreferences already committed (unverified re-auth). Never call full `configure --sync-qbit-auth` after overwriting `.env` with the new password.
- **arr-ui set** must apply Host Config with the in-memory new password before writing `.env`.
- Arr Host Config: GET full host config → set `username`, `password`, `passwordConfirmation` → PUT. Pass `ARR_API_KEY` and `ARR_HOST_CONFIG_URL` via environment only — never on process argv. Prefer JSON body; redact password/apiKey fields in error dumps.
- Verify Forms login (or equivalent) after apply; restart containers only if validation proves it is required for the shipped images.
- Spike results belong in **Validation** below before status moves to Accepted.

## Consequences

- ADR 0005 command list gains `credentials`; roadmap-style extras remain separate.
- ADR 0015 wording for `FLIXBOX_ARR_UI_*` is amended: SoT + apply via CLI / `--sync-arr-ui`, not reference-only.
- User docs (`REFERENCE`, configuration, access profiles, credential rotation) prefer the CLI over hand-editing `.env` for operator passwords.
- CI SHOULD gate help text / doc mentions (pattern similar to existing credential doc checks).
- Residual risk: partial *arr apply; Servarr API drift across major versions — pin behavior to images Flixbox ships.
- Operators must not assume `configure` alone creates Forms users.

## Non-goals

- Replacing API key rotation with `credentials set`.
- Auto-applying Forms on every `configure`.
- Unifying Bazarr / Maintainerr / Homepage into `FLIXBOX_ARR_UI_*`.
- Migrating Compose env secrets to Docker secret files (still ADR 0018 follow-up).

## Validation

**Before Accepted**, spike against the images Flixbox ships:

1. With pre-seeded API keys and profile `shared`, Host Config PUT sets Forms username/password on Prowlarr, Radarr, and Sonarr (fresh volume / no prior Forms user if possible).
2. A second PUT rotates the password; browser or `/login` confirms the new password and rejects the old.
3. Confirm whether `passwordConfirmation` is required.
4. Confirm whether a container restart is required for login to work.

Record spike outcome in this section (Updated note). If first-seed is unreliable, narrow the MUST to **rotate when Forms already exists** + keep manual first create, before Accepting.

### Spike results

Validated 2026-09-04 against running Flixbox containers (linuxserver *arr images in this install):

| Check | Result |
| --- | --- |
| GET host config exposes `password` + `passwordConfirmation` | Yes (Radarr, Sonarr, Prowlarr) |
| PUT with `username` + `password` + `passwordConfirmation` | HTTP 202 on all three |
| First seed (empty username → Forms credentials) | Login cookie issued (`RadarrAuth` / `SonarrAuth` / `ProwlarrAuth`) without container restart |
| Rotate to a second password | Login with new password succeeds; old password yields no auth cookie |
| Restart required for login | **No** (for these images) |
| `passwordConfirmation` | **Required in practice** — always send it equal to `password` |

**Remediation 2026-09-04:** `credentials set qbit` rotates via `scripts/lib/qbit-password-rotate.sh` (old/temp auth → set new → write `.env` on exit 0/3). Host Config apply uses `ARR_API_KEY` / `ARR_HOST_CONFIG_URL` env only. `arr-ui` applies before `.env` write. Homepage under `shared` drops admin widget blocks (`homepage-sync` on `init`/`up`/`reload`/`configure`).

**Compose auth env note:** Flixbox sets `*__AUTH__METHOD` / `*__AUTH__REQUIRED` from the access profile. After PUT, GET may still report the env-overridden method (e.g. `external` under `trusted`). Implementers MUST still set username/password/passwordConfirmation on PUT; under `shared`, Compose already forces Forms + Enabled. Do not rely on Host Config alone to change auth method while env overrides are present.

## Related

- [ADR 0005](0005-cli-bash-first.md) — Bash CLI
- [ADR 0015](0015-access-profiles.md) — `trusted` / `shared`
- [ADR 0016](0016-configure-state-machine.md) — configure
- [ADR 0018](0018-runtime-secrets-and-lan-trust.md) — secrets threat model
- [ADR 0019](0019-qbit-webui-runtime-contract.md) — qBit WebUI auth
- [docs/user/15-credential-rotation.md](../user/15-credential-rotation.md)
