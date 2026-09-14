#!/usr/bin/env bash
# Homepage template revision stamps + opt-in refresh (docs/plans/homepage-template-refresh.md).
# Sourced from bin/flixbox — expects ROOT_DIR, CONFIG_DIR, log/ok/warn, and load_env already available.

flixbox_homepage_template_dir() {
  printf '%s\n' "${ROOT_DIR}/templates/homepage"
}

flixbox_homepage_live_dir() {
  printf '%s\n' "${CONFIG_DIR}/homepage"
}

flixbox_homepage_template_rev_file() {
  printf '%s\n' "$(flixbox_homepage_template_dir)/.flixbox-template-rev"
}

flixbox_homepage_applied_rev_file() {
  printf '%s\n' "$(flixbox_homepage_live_dir)/.flixbox-applied-rev"
}

# Managed overwrite set (relative to templates/homepage and live homepage/).
flixbox_homepage_managed_files() {
  cat <<'EOF'
services.yaml
settings.yaml
widgets.yaml
bookmarks.yaml
docker.yaml
custom.css
custom.js
images/logo.png
images/background.jpg
EOF
}

flixbox_homepage_read_rev_file() {
  local path="$1"
  local rev=""
  [[ -f "$path" ]] || return 1
  rev="$(tr -d '[:space:]' <"$path" 2>/dev/null || true)"
  [[ -n "$rev" && "$rev" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$rev"
}

flixbox_homepage_template_rev() {
  flixbox_homepage_read_rev_file "$(flixbox_homepage_template_rev_file)"
}

flixbox_homepage_applied_rev() {
  flixbox_homepage_read_rev_file "$(flixbox_homepage_applied_rev_file)"
}

flixbox_homepage_write_applied_rev() {
  local rev="$1"
  local live dest
  live="$(flixbox_homepage_live_dir)"
  dest="$(flixbox_homepage_applied_rev_file)"
  mkdir -p "$live"
  printf '%s\n' "$rev" >"$dest"
}

# Stamp applied-rev after a true first create of live Homepage (caller decides).
flixbox_homepage_stamp_applied_from_template() {
  local tmpl
  tmpl="$(flixbox_homepage_template_rev 2>/dev/null)" || return 0
  flixbox_homepage_write_applied_rev "$tmpl"
}

# Return 0 if live is stale (needs refresh warning / apply).
flixbox_homepage_templates_stale() {
  local tmpl applied
  tmpl="$(flixbox_homepage_template_rev 2>/dev/null)" || return 1
  if ! applied="$(flixbox_homepage_applied_rev 2>/dev/null)"; then
    # Existing install without stamp → treat as stale vs current templates.
    [[ -f "$(flixbox_homepage_live_dir)/services.yaml" ]] && return 0
    return 1
  fi
  [[ "$applied" -lt "$tmpl" ]]
}

flixbox_homepage_warn_if_stale() {
  local tmpl applied
  flixbox_homepage_templates_stale || return 0
  tmpl="$(flixbox_homepage_template_rev)"
  if ! applied="$(flixbox_homepage_applied_rev 2>/dev/null)"; then
    applied="(none)"
  fi
  warn "Homepage templates are newer than live config (applied=${applied} template=${tmpl})."
  warn "Live files were not overwritten (preserves local edits)."
  warn "Apply:  ./bin/flixbox homepage refresh"
  warn "Or:     ./bin/flixbox reload --reset-homepage"
  warn "Backup will be written under ${CONFIG_DIR}/homepage.bak.<timestamp>"
}

flixbox_homepage_backup_live() {
  local live bak ts
  live="$(flixbox_homepage_live_dir)"
  [[ -d "$live" ]] || return 0
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  bak="${CONFIG_DIR}/homepage.bak.${ts}"
  if [[ -e "$bak" ]]; then
    bak="${bak}.$$"
  fi
  cp -a "$live" "$bak"
  printf '%s\n' "$bak"
}

flixbox_homepage_copy_managed() {
  local tmpl live rel dest_dir
  tmpl="$(flixbox_homepage_template_dir)"
  live="$(flixbox_homepage_live_dir)"
  mkdir -p "${live}/images"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ -f "${tmpl}/${rel}" ]] || {
      warn "Homepage template missing managed file: ${rel}"
      return 1
    }
    dest_dir="$(dirname "${live}/${rel}")"
    mkdir -p "$dest_dir"
    cp -f "${tmpl}/${rel}" "${live}/${rel}"
  done < <(flixbox_homepage_managed_files)
}

flixbox_homepage_run_sync() {
  local live services
  live="$(flixbox_homepage_live_dir)"
  services="${live}/services.yaml"
  [[ -f "$services" ]] || return 1
  python3 "${ROOT_DIR}/scripts/lib/homepage-sync.py" "$services" >/dev/null
}

flixbox_homepage_restart_container() {
  if ! docker inspect flixbox-homepage >/dev/null 2>&1; then
    warn "flixbox-homepage container not found — skip restart (start stack with ./bin/flixbox up)"
    return 0
  fi
  docker restart flixbox-homepage >/dev/null
}

# Opt-in apply. Args: optional --dry-run
# Prints outcome token on stdout last line context via log/ok; returns 0 on success.
flixbox_homepage_refresh() {
  local dry_run=0
  local tmpl applied bak
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      -h|--help)
        cat <<'EOF'
Usage: flixbox homepage refresh [--dry-run]

Backup live ${CONFIG_DIR}/homepage, overwrite managed templates from the repo,
run homepage-sync, stamp applied revision, restart flixbox-homepage.
EOF
        return 0
        ;;
      *)
        warn "Unknown homepage refresh option: $1"
        return 2
        ;;
    esac
  done

  tmpl="$(flixbox_homepage_template_rev)" || {
    warn "Missing or invalid templates/homepage/.flixbox-template-rev"
    return 1
  }

  if applied="$(flixbox_homepage_applied_rev 2>/dev/null)" && [[ "$applied" == "$tmpl" ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      cli_configure_line homepage dry-run "already at rev ${tmpl}"
      return 0
    fi
    cli_configure_line homepage unchanged "templates (applied-rev=${tmpl})"
    return 0
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    cli_configure_line homepage dry-run "backup + template apply to rev ${tmpl}"
    return 0
  fi

  [[ -n "${CONFIG_DIR:-}" ]] || {
    cli_configure_line homepage failed "CONFIG_DIR unset"
    return 1
  }

  mkdir -p "$(flixbox_homepage_live_dir)/images"
  bak="$(flixbox_homepage_backup_live)" || {
    cli_configure_line homepage failed "backup"
    return 1
  }
  [[ -n "$bak" ]] && cli_info "Homepage backup: ${bak}"

  flixbox_homepage_copy_managed || {
    cli_configure_line homepage failed "template copy"
    return 1
  }

  if ! flixbox_homepage_run_sync; then
    cli_configure_line homepage failed "sync after template copy"
    return 1
  fi

  flixbox_homepage_write_applied_rev "$tmpl"
  flixbox_homepage_restart_container || {
    cli_configure_line homepage failed "restart (templates applied — docker restart flixbox-homepage)"
    return 1
  }

  cli_configure_line homepage updated "templates (applied-rev=${tmpl})"
  return 0
}
