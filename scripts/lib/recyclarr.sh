#!/usr/bin/env bash
# Recyclarr sync wrapper (ADR 0021). Sourced from bin/flixbox.

# Args: dry_run(0|1)
flixbox_recyclarr_sync() {
  local dry_run="$1"
  local cfg="${CONFIG_DIR:-}/recyclarr/recyclarr.yml"
  local -a run_args=(--profile recyclarr run --rm recyclarr sync)

  [[ -n "${CONFIG_DIR:-}" ]] || {
    cli_configure_line recyclarr failed "CONFIG_DIR unset"
    return 4
  }
  if [[ ! -f "$cfg" ]]; then
    cli_configure_line recyclarr failed "missing ${cfg} — copy templates or run init"
    return 4
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    run_args+=( --dry-run )
    cli_info "Recyclarr sync --dry-run (no profile writes)"
  else
    cli_info "Recyclarr sync (explicit one-shot)"
  fi

  if ! compose "${run_args[@]}"; then
    cli_configure_line recyclarr failed "compose run recyclarr sync"
    return 3
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    cli_configure_line recyclarr dry-run "sync preview complete"
  else
    cli_configure_line recyclarr updated "sync complete"
  fi
  return 0
}
