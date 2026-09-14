#!/usr/bin/env bash
# flixbox update helpers (ADR 0021 / ADR 0010). Sourced from bin/flixbox.
# Pulls pinned Compose tags and reconciles the stack — never rewrites pins to :latest.

# Args: dry_run(0|1) then optional compose --profile args (same as up).
flixbox_update_run() {
  local dry_run="$1"
  shift
  local -a profiles=("$@")
  local images

  if [[ "$dry_run" -eq 1 ]]; then
    cli_info "Dry-run: listing pinned images (no pull, no recreate)"
    if ! images="$(compose "${profiles[@]}" config --images 2>/dev/null)"; then
      cli_configure_line update failed "compose config --images"
      return 3
    fi
    if [[ -n "$images" ]]; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && printf '  %s\n' "$line"
      done <<<"$images"
    fi
    cli_info "update never rewrites compose pins to :latest — bump tags via docs/user/14-image-pins.md"
    cli_configure_line update dry-run "pull + up -d --remove-orphans skipped"
    return 0
  fi

  cli_info "Pulling pinned images (ADR 0010)..."
  if ! compose "${profiles[@]}" pull; then
    cli_configure_line update failed "compose pull"
    return 3
  fi

  cli_info "Reconciling stack (recreate only when image IDs changed)..."
  if ! compose "${profiles[@]}" up -d --remove-orphans; then
    cli_configure_line update failed "compose up"
    return 3
  fi

  cli_configure_line update updated "pulled pinned tags and reconciled stack"
  cli_info "Pin bumps require editing compose/*.yml — see docs/user/14-image-pins.md"
  flixbox_homepage_warn_if_stale || true
  return 0
}
