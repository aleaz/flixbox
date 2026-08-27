# Maintainerr rule pack (documentation template).
# Import/configure in the Maintainerr UI against Jellyfin + Radarr/Sonarr.
# Full thresholds: docs/09-hygiene-defaults.md
#
# Rule A — Unwatched movies: never watched, added > 90d → Leaving Soon → delete after 14d
# Rule B — Quiet TV: no watches 180d, added > 90d → Leaving Soon → delete after 21d
# Skip items added in last 30 days
# Rule C (watched movies reclaim): OFF by default
# Keep list / exclusions: configure a Keep collection or tags before enabling deletes
