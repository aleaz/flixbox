# Apprise (optional `notifications` profile)

Stateful config for [linuxserver/apprise-api](https://docs.linuxserver.io/images/docker-apprise-api/).  
Flixbox mounts this directory at `/config` inside the container. **Do not commit bot tokens or URLs to git.**

## Enable

```bash
./bin/flixbox up notifications
# or: COMPOSE_PROFILES=notifications in .env, then ./bin/flixbox up
```

Service hostname on `flixbox_net`: **`apprise-api`** (port **8000** inside the network only — no host publish by default).

## Configure destinations

1. Copy `urls.conf.example` → a stateful key file per [Apprise API stateful mode](https://github.com/caronc/apprise-api#stateless-vs-persistent-storage) (typically under this volume after first start).
2. Or create configurations via the API from another container on `flixbox_net`.

Example Telegram URL scheme (replace with your bot token and chat id):

```text
tgram://BOT_TOKEN/CHAT_ID
```

## Wire *arr Connect

In Radarr / Sonarr / Bazarr → **Settings → Connect → Apprise**:

| Field | Value |
| --- | --- |
| Server URL | `http://apprise-api:8000` |
| Configuration key | the key you created in Apprise |
| Notification type | On grab / import / health as you prefer |

Recyclarr (optional profile) can also target the same hub — see Recyclarr Apprise docs.

## Day-0 without this profile

Use each app’s native Connect (Telegram, Discord, etc.). See Flixbox docs: `docs/user/18-notifications.md`.

## Security

- Hub is **internal-only**. Do not publish port 8000 to WAN without Caddy and an auth story.
- Keep tokens only under `${CONFIG_DIR}/apprise` (permissions `600` where practical).
