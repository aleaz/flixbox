# Notifications

Flixbox does **not** ship an interactive Telegram/Discord bot. Use either native Connect in each app (Day-0) or the optional **Apprise** hub (ADR 0012).

## Day-0 — native Connect (no extra container)

| App | Typical path |
| --- | --- |
| Radarr / Sonarr / Bazarr | **Settings → Connect** → Telegram, Discord, etc. |
| Seerr | Built-in notification settings in the Seerr UI |
| Maintainerr | Notification channels in Maintainerr (enable only after reviewing rules) |

This is the supported path with zero extra Compose services.

## Optional — Apprise hub (`notifications` profile)

One internal service fans out to many backends via Apprise URL schemes (`tgram://`, `ntfy://`, Discord, …). *arr apps speak **Connect → Apprise**.

### Enable

```bash
./bin/flixbox up notifications
# or set COMPOSE_PROFILES=notifications in .env, then ./bin/flixbox up
```

| Item | Value |
| --- | --- |
| Service name | `apprise-api` |
| Hostname on `flixbox_net` | `apprise-api` |
| Port (container / overlay only) | `8000` |
| Config volume | `${CONFIG_DIR}/apprise` |
| Image pin | see [14 — Image pins](14-image-pins.md) |

**No host port** is published by default (do not expose the Apprise UI to WAN without Caddy + auth).

`init` / `reload` copy `templates/apprise/` into `${CONFIG_DIR}/apprise` when missing.

### Wire *arr

1. Create a stateful configuration key in Apprise (see `${CONFIG_DIR}/apprise/README.md` and [linuxserver/apprise-api](https://docs.linuxserver.io/images/docker-apprise-api/)).
2. In Radarr / Sonarr / Bazarr → **Settings → Connect → Apprise**:
   - **Server URL:** `http://apprise-api:8000`
   - **Configuration key:** your key
3. Choose which events to notify (grab, import, health, …). Flixbox does **not** auto-wire Connect.

Recyclarr (profile `recyclarr`) can target the same hub when its Apprise options are set.

### Apps without Apprise Connect

Seerr, Maintainerr, Unpackerr: use native channels, or a webhook that posts to Apprise when you configure one yourself. Do not expect zero-config wiring.

### VPN heal alerts

With profile `vpn-heal`, set `VPN_HEAL_APPRISE_URLS` in `.env` (Apprise URL schemes). That path is independent of this hub; you may still use the hub for *arr Connect.

### Secrets

Bot tokens and Apprise destination URLs belong only under `${CONFIG_DIR}/apprise` (or operator secret stores). Never commit them to git.

## Related

- [ADR 0012](../adr/0012-notifications-apprise-hub.md)
- [Configuration — Compose profiles](06-configuration.md#optional-compose-profiles)
- [Image pins](14-image-pins.md)
- Planning note (VPN heal still future): [11-future-notifications-and-vpn-resilience.md](../11-future-notifications-and-vpn-resilience.md)
