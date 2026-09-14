# Notificaciones

Flixbox **no** incluye un bot interactivo de Telegram/Discord. Usa Connect nativo en cada app (Day-0) o el hub opcional **Apprise** (ADR 0012).

## Day-0 — Connect nativo (sin contenedor extra)

| App | Ruta típica |
| --- | --- |
| Radarr / Sonarr / Bazarr | **Settings → Connect** → Telegram, Discord, etc. |
| Seerr | Ajustes de notificación en la UI de Seerr |
| Maintainerr | Canales en Maintainerr (activa solo tras revisar reglas) |

Camino soportado sin servicios Compose adicionales.

## Opcional — hub Apprise (perfil `notifications`)

Un servicio interno reparte a muchos backends vía esquemas URL de Apprise (`tgram://`, `ntfy://`, Discord, …). Las *arr hablan **Connect → Apprise**.

### Activar

```bash
./bin/flixbox up notifications
# o COMPOSE_PROFILES=notifications en .env, luego ./bin/flixbox up
```

| Ítem | Valor |
| --- | --- |
| Nombre del servicio | `apprise-api` |
| Hostname en `flixbox_net` | `apprise-api` |
| Puerto (solo red overlay) | `8000` |
| Volumen de config | `${CONFIG_DIR}/apprise` |
| Pin de imagen | ver [14 — Image pins](14-image-pins.md) |

**No** se publica puerto en el host por defecto (no expongas la UI de Apprise a WAN sin Caddy + auth).

`init` / `reload` copian `templates/apprise/` a `${CONFIG_DIR}/apprise` si faltan.

### Cablear *arr

1. Crea una configuration key stateful en Apprise (ver `${CONFIG_DIR}/apprise/README.md` y [linuxserver/apprise-api](https://docs.linuxserver.io/images/docker-apprise-api/)).
2. En Radarr / Sonarr / Bazarr → **Settings → Connect → Apprise**:
   - **Server URL:** `http://apprise-api:8000`
   - **Configuration key:** tu key
3. Elige eventos (grab, import, health, …). Flixbox **no** cablea Connect automáticamente.

Recyclarr (perfil `recyclarr`) puede apuntar al mismo hub si configuras sus opciones Apprise.

### Apps sin Apprise Connect

Seerr, Maintainerr, Unpackerr: canales nativos, o un webhook hacia Apprise si lo configuras tú. No esperes cableado zero-config.

### Alertas VPN heal

Con el perfil `vpn-heal`, define `VPN_HEAL_APPRISE_URLS` en `.env` (esquemas URL de Apprise). Es independiente de este hub; el hub sigue sirviendo Connect de *arr.

### Secretos

Tokens y URLs de destino solo en `${CONFIG_DIR}/apprise` (u otro almacén del operador). Nunca en git.

## Relacionado

- [ADR 0012](../../adr/0012-notifications-apprise-hub.md)
- [Configuración — perfiles Compose](06-configuration.md)
- [Image pins](14-image-pins.md)
- Nota de planificación (VPN heal aún futuro): [11-future-notifications-and-vpn-resilience.md](../../11-future-notifications-and-vpn-resilience.md)
