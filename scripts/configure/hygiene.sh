#!/usr/bin/env bash
reload_hygiene_if_needed() {
  if ! $ENV_DIRTY && ! $SYNC_QBIT_AUTH; then
    return
  fi
  if $DRY_RUN; then
    dry "Recreate Decluttarr/Unpackerr after .env key writes"
    return
  fi
  log "Recreating Decluttarr + Unpackerr to pick up .env keys..."
  if docker compose --project-directory "${ROOT_DIR}" up -d --force-recreate decluttarr unpackerr >/dev/null 2>&1; then
    ok "Hygiene containers recreated"
  else
    fail "Could not recreate Decluttarr/Unpackerr — run: ./bin/flixbox reload"
  fi
}
