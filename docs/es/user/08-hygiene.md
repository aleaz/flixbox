<a id="hygiene-decluttarr-maintainerr"></a>
# Higiene (Decluttarr + Maintainerr)

**Idiomas:** [English](../../user/08-hygiene.md) · Español (esta página)

Flixbox incluye dos ayudas para que el stack no se degrade en silencio.

<a id="decluttarr-download-queue"></a>
## Decluttarr — cola de descargas

Quita descargas atascadas o inútiles y puede pedir a Radarr/Sonarr que busquen de nuevo.

Idea por defecto:

- Stalled / failed / orphan / missing files → eliminar tras la gracia
- **Slow (KiB/s absolutos)** → **apagado** por defecto (amigable con VPN)
- Tag **`flixbox-keep`** en un torrent → nunca auto-eliminar
- Por defecto **no** elimina ítems “unmonitored”

**Gracia:** ~`REMOVE_TIMER × STRIKES` minutos (defaults **15 × 12 ≈ 3 horas** para stalled). No son “unas pocas horas” salvo que tus números multipliquen a eso.

**Consejo VPN:** deja `DECLUTTARR_REMOVE_SLOW=False`. Si activas la eliminación por lentitud bajo VPN, `flixbox up|reload|status` avisa — prefiere `flixbox-keep` en torrents importantes.

Usa el host del cliente de descarga **`qbittorrent`** (puerto `8080`) en ambos modos ([ADR 0014](../../adr/0014-stable-qbit-download-hostname.md)). La auth de Decluttarr usa **username/password** de qBit en `.env`, no la API key de qBit — [Credenciales](06-configuration.md#credentials-and-api-keys). Hasta que `QBITTORRENT_PASSWORD` esté definido, Decluttarr permanece idle a propósito.

<a id="maintainerr-library-cleanup"></a>
## Maintainerr — limpieza de biblioteca

Usa el estado de reproducción de **Jellyfin** más Radarr/Sonarr para limpiar medios olvidados.

Paquete estándar (resumen):

| Regla | Comportamiento |
| --- | --- |
| Películas sin ver | Tras **90 días** → Leaving Soon → borrar tras **14** días más |
| Series quietas | Sin reproducciones durante **180 días** → Leaving Soon → borrar tras **21** días más |
| Ítems recién agregados | Nunca tocar si se agregaron en los últimos **30 días** |
| Películas ya vistas | No se auto-borran por defecto |

Revisa siempre las reglas antes de la primera ejecución destructiva. Prefiere una lista Keep / exclusión para favoritos.

Tras `./bin/flixbox init`, abre **`${CONFIG_DIR}/maintainerr/rule-pack.md`** para el setup paso a paso en la UI (Rules A/B/C). Los mismos umbrales que [09-hygiene-defaults.md](../../09-hygiene-defaults.md).

<a id="hardlinks-and-free-space"></a>
## Hardlinks y espacio libre

Borrar un archivo de la biblioteca que aún está hardlinkeado a un torrent activo **no libera disco** hasta que también desaparezca la copia del torrent. Planifica seeding y limpieza juntos.

<a id="full-thresholds"></a>
## Umbrales completos

Detalle de ingeniería: [09-hygiene-defaults.md](../../09-hygiene-defaults.md)

<a id="next"></a>
## Siguiente

[Operación día a día](09-operations.md)
