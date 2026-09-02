# Credential rotation runbook

Step-by-step recovery when passwords or API keys change — accidentally or on purpose. For the credential map, see [Configuration — Credentials](06-configuration.md#credentials-and-api-keys).

**Principles**

1. **Source of truth:** `.env` for qBit WebUI login and *arr API keys (after `configure` syncs from `config.xml`); qBit API key lives in qBit config (not `.env`).
2. **`configure` uses API keys** on `127.0.0.1` — it does not create *arr Forms users (`shared` profile).
3. After changing secrets in `.env`, **recreate** hygiene containers when `configure` reports `.env` writes or use `--sync-qbit-auth` for qBit.

---

## Quick reference

| Credential | Typical trigger | Primary fix |
| --- | --- | --- |
| qBit WebUI password | Manual change in qBit UI | Update `.env` → `configure --sync-qbit-auth` |
| qBit API key | Regenerate in qBit UI | `configure` (drift heal) or `--sync-qbit-auth` |
| Radarr / Sonarr API key | Regenerate in *arr UI | `configure` → update Maintainerr / Recyclarr YAML if needed |
| Prowlarr API key | Regenerate in Prowlarr UI | `configure` (rewrites `.env` from config) |
| Jellyfin API key | Revoke / new key in Jellyfin | Re-create in Jellyfin UI → update Seerr / Maintainerr manually |
| `FLIXBOX_ADMIN_PASSWORD` | Operator rotation | Update `.env` → `configure` (Jellyfin/Seerr login paths) |
| `FLIXBOX_ARR_UI_*` (`shared`) | Roommate password policy | Update `.env` **and** change Forms user in each *arr UI |
| Access profile | `trusted` ↔ `shared` | Change `.env` → `up` / `reload` / `configure` (auto-sync + recreate admin services) |

---

## qBittorrent WebUI password

1. Set the **current** WebUI password in `.env` as `QBITTORRENT_PASSWORD` (and `QBITTORRENT_USERNAME` if changed).
2. Run `./bin/flixbox configure --sync-qbit-auth`.
3. Confirm: `./bin/flixbox configure` idempotent; Decluttarr logs show qBit OK (not idle).
4. If login fails and logs show no temp password: reset in qBit UI or wipe `${CONFIG_DIR}/qbittorrent/` (last resort), align `.env`, `--sync-qbit-auth`.

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

1. Update `FLIXBOX_ADMIN_USER` / `FLIXBOX_ADMIN_PASSWORD` in `.env`.
2. Change the matching Jellyfin user password in Jellyfin UI (or complete startup wizard on fresh install).
3. Run `./bin/flixbox configure` for Seerr Jellyfin auth wiring.

---

## Shared profile — *arr Forms users (`FLIXBOX_ARR_UI_*`)

Servarr does not read `FLIXBOX_ARR_UI_*` from Compose. These are **reference values** only.

1. Update `.env` if you rotate the reference password (`up` / `configure` on `shared` generates placeholders when empty).
2. Change the Forms login in **each** of Radarr, Sonarr, and Prowlarr UI separately.
3. `configure` still works via API keys — no Forms login required for automation.

---

## Access profile change (`trusted` ↔ `shared`)

1. Set `FLIXBOX_ACCESS_PROFILE` in `.env`.
2. Run `./bin/flixbox init --non-interactive` (optional — ensures `FLIXBOX_ARR_UI_*` when switching to `shared`).
3. Run `./bin/flixbox reload` or `./bin/flixbox up` — derived bind/auth keys sync and admin-bound services recreate when drift is detected.
4. On `shared`, create *arr Forms users from `FLIXBOX_ARR_UI_*` — [Access profiles](13-access-profiles.md#create-arr-login-shared).

---

## Post-rotation checklist

- [ ] `./bin/flixbox configure` exits 0
- [ ] `./bin/flixbox status` — mode and access profile sane
- [ ] Radarr/Sonarr download client **Test** OK
- [ ] Decluttarr not idle (qBit creds in `.env`)
- [ ] Prowlarr indexers still work (unchanged by key rotation unless Prowlarr key rotated)
- [ ] Maintainerr / Seerr connections tested if their upstream keys changed
- [ ] Recyclarr sync if YAML keys were edited manually

---

## Related

- [Configuration — Accidental / intentional key changes](06-configuration.md#accidental--intentional-key-changes)
- [Troubleshooting](10-troubleshooting.md)
- [ADR 0015 — Access profiles](../adr/0015-access-profiles.md)
