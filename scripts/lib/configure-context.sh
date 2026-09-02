#!/usr/bin/env bash
#
# Documented configure wiring context (ADR 0016).
# Bash dynamic scope is intentional; this file centralizes reset and inventory.

# Reset counters and flags at configure start (preflight sets API keys after).
configure_context_reset() {
  CONFIGURED=0
  SKIPPED=0
  FAILED=0
  ENV_DIRTY=false
  configure_state_init
}

# Inventory for operators and agents (not executed):
#   Counters: CONFIGURED, SKIPPED, FAILED, ENV_DIRTY
#   State:    CONFIGURE_PREFLIGHT_PASSED, CONFIGURE_SOFT_WAIT
#   Keys:     SONARR_API_KEY, RADARR_API_KEY, PROWLARR_API_KEY, BAZARR_API_KEY
#   qBit:     QBIT_API_KEY, QBIT_USERNAME, QBIT_PASSWORD, QBIT_ARR_HOST, QBIT_URL
#   Flags:    DRY_RUN, VERBOSE, SYNC_QBIT_AUTH
