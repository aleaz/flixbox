# Credential rotation runbook

Step-by-step recovery when passwords or API keys change — accidentally or on purpose. For the credential map, see [Configuration — Credentials](06-configuration.md#credentials-and-api-keys).

**Prefer the CLI (ADR 0020)**

```bash
./bin/flixbox credentials show qbit|arr-ui|admin
./bin/flixbox credentials show api radarr|sonarr|prowlarr
./bin/flixbox credentials set qbit --generate|--prompt
./bin/flixbox credentials set arr-ui --generate|--prompt   # shared only
./bin/flixbox credentials set admin --generate|--prompt
```

**Principles**

1. **Source of truth:** `.env` for qBit WebUI login, `FLIXBOX_ADMIN_*`, `FLIXBOX_ARR_UI_*` (shared Forms), and *arr API keys (after `configure` syncs from `config.xml`); qBit API key lives in qBit config (not `.env`).
2. **`configure` uses API keys** on `127.0.0.1` — Forms apply only via `credentials set arr-ui` or `configure --sync-arr-ui`.
3. After changing secrets in `.env` by hand, recreate hygiene containers when `configure` reports `.env` writes or use `--sync-qbit-auth` / `--sync-arr-ui` as appropriate.

---

## Quick reference

| Credential | Typical trigger | Primary fix |
| --- | --- | --- |
| qBit WebUI password | Manual change or rotation | **Rotate:** `credentials set qbit`. **Align** (`.env` already matches WebUI): `configure --sync-qbit-auth` |
| qBit API key | Regenerate in qBit UI | `configure` (drift heal) or `--sync-qbit-auth` |
| Radarr / Sonarr API key | Regenerate in *arr UI | `configure` → update Maintainerr / Recyclarr YAML if needed |
| Prowlarr API key | Regenerate in Prowlarr UI | `configure` (rewrites `.env` from config) |
| Jellyfin API key | Revoke / new key in Jellyfin | Re-create in Jellyfin UI → update Seerr / Maintainerr manually |
| `FLIXBOX_ADMIN_PASSWORD` | Operator rotation | `credentials set admin` **or** update `.env` → align Jellyfin UI / `configure` |
| `FLIXBOX_ARR_UI_*` (`shared`) | Roommate password policy | `credentials set arr-ui` **or** `configure --sync-arr-ui` |
| Access profile | `trusted` ↔ `shared` | Change `.env` → `up` / `reload` / `configure` (auto-sync + recreate admin services) |

---

## qBittorrent WebUI password

**Rotate** (change the password Flixbox manages):

1. `./bin/flixbox credentials set qbit --generate` (or `--prompt`).
2. CLI authenticates with the **current** `.env` password (or session temp), applies the new password to qBit, **then** writes `.env`, then recreates Decluttarr.
3. If re-auth verify fails after qBit accepted the change, CLI still persists `.env` and warns — confirm WebUI with `credentials show qbit`.
4. Confirm Decluttarr logs show qBit OK (not idle).
5. If *arr download-client Test fails: `./bin/flixbox configure --sync-qbit-auth`.

**Align** (`.env` already matches a loginable WebUI password — e.g. you changed password in the UI and copied it into `.env`):

1. Put the **current** WebUI password in `.env` as `QBITTORRENT_PASSWORD`.
2. `./bin/flixbox configure --sync-qbit-auth`.
3. Confirm Decluttarr / configure idempotent.

If login fails and logs show no temp password: reset in qBit UI or wipe `${CONFIG_DIR}/qbittorrent/` (last resort), align `.env`, then `--sync-qbit-auth`.

---

## qBittorrent API key

1. If you regenerated the key in qBit UI, run `./bin/flixbox configure`.
2. Verify Radarr/Sonarr → Download Clients → qBittorrent **Test** passes.
3. If Test passes but key is stale, run `./bin/flixbox configure --sync-qbit-auth`.

---

## Radarr or Sonarr API key

1. After regenerating in the *arr UI, run `./bin/flixbox configure` (syncs key from `config.xml` into `.env`, refreshes Prowlarr/Bazarr/Seerr clients, recreates Decluttarr/Unpackerr when needed).
2. **Maintainerr:** Settings → update Radarr/Sonarr connection API keys manually.
3. **Recyclarr:** if `${CONFIG_DIR}/recyclarr/recyclarr.yml` no longer has `REPLACE_*` placeholders, edit keys in that file, then `docker compose --profile recyclarr run --rm recyclarr sync`.

Show current key: `./bin/flixbox credentials show api radarr` (or `sonarr` / `prowlarr`).

---

## Prowlarr API key

1. Run `./bin/flixbox configure` after regeneration (syncs `.env` from Prowlarr config).
2. Prowlarr → Apps → Radarr/Sonarr entries are refreshed by `configure` when drift is detected.

---

## Jellyfin API key

1. Jellyfin → Dashboard → **API Keys** → create or copy key.
2. Optional: add to `.env` as `JELLYFIN_API_KEY` if `configure` created one previously.
3. **Seerr:** re-authenticate or update Jellyfin integration if requests fail.
4. **Maintainerr:** Settings → Jellyfin → paste new API key.

---

## Jellyfin / Seerr admin password (`FLIXBOX_ADMIN_*`)

1. Prefer `./bin/flixbox credentials set admin --generate` (updates `.env` + best-effort Jellyfin API change).
2. Or update `FLIXBOX_ADMIN_*` in `.env` and change the matching Jellyfin user password in the UI.
3. Run `./bin/flixbox configure` if Seerr Jellyfin auth wiring needs a refresh.

---

## Shared profile — *arr Forms users (`FLIXBOX_ARR_UI_*`)

Servarr does not read Forms username/password from Compose env. `.env` holds the SoT; apply via Host Config:

1. `./bin/flixbox credentials set arr-ui --generate` — Host Config apply runs **before** `.env` write (no write if all three apps fail).
2. Or edit `.env` then `./bin/flixbox configure --sync-arr-ui` to push existing SoT values.
3. If apply fails, create/change Forms login in **each** of Radarr, Sonarr, and Prowlarr UI separately.
4. `configure` (without `--sync-arr-ui`) still works via API keys — no Forms login required for automation.

---

## Access profile change (`trusted` ↔ `shared`)

1. Set `FLIXBOX_ACCESS_PROFILE` in `.env`.
2. Run `./bin/flixbox init --non-interactive` (optional — ensures `FLIXBOX_ARR_UI_*` when switching to `shared`).
3. Run `./bin/flixbox reload`, `up`, or `configure` — derived bind/auth keys sync, admin-bound services recreate on drift, and Homepage widgets are synced (`shared` drops admin widgets).
4. On `shared`, apply Forms: `./bin/flixbox credentials set arr-ui --generate` — [Access profiles](13-access-profiles.md#create-arr-login-shared).

---

## Post-rotation checklist

- [ ] `./bin/flixbox configure` exits 0
- [ ] `./bin/flixbox status` — mode and access profile sane
- [ ] Radarr/Sonarr download client **Test** OK
- [ ] Decluttarr not idle (qBit creds in `.env`)
- [ ] Prowlarr indexers still work (unchanged by key rotation unless Prowlarr key rotated)
- [ ] Maintainerr / Seerr connections tested if their upstream keys changed
- [ ] Recyclarr sync if YAML keys were edited manually
- [ ] Under `shared`, Forms login works after `credentials set arr-ui` / `--sync-arr-ui`

---

## Related

- [Configuration — Accidental / intentional key changes](06-configuration.md#accidental--intentional-key-changes)
- [Troubleshooting](10-troubleshooting.md)
- [ADR 0015 — Access profiles](../adr/0015-access-profiles.md)
- [ADR 0020 — Operator credentials CLI](../adr/0020-operator-credentials-cli.md)
