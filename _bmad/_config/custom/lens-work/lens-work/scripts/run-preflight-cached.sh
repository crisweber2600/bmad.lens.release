#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Run Preflight (Cached)
#
# PURPOSE:
#   Wraps preflight.sh with a simple timestamp cache so repeated calls within
#   the same work session skip redundant re-runs. The cache expires after a
#   configurable TTL (default 300 seconds / 5 minutes).
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/run-preflight-cached.sh [preflight-args...]
#   ./lens.core/_bmad/lens-work/scripts/run-preflight-cached.sh --ttl 600
#   ./lens.core/_bmad/lens-work/scripts/run-preflight-cached.sh --force
#   ./lens.core/_bmad/lens-work/scripts/run-preflight-cached.sh --json
#
# OPTIONS:
#   --ttl <seconds>   Cache validity duration (default: 300)
#   --force           Ignore cache and always run preflight
#   --json            Output result as JSON
#   All other args are forwarded to preflight.sh
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CACHE_FILE="${PROJECT_ROOT}/_bmad-output/lens-work/personal/.preflight-timestamp"

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# -- Defaults -----------------------------------------------------------------
TTL=300
FORCE=false
JSON_OUTPUT=false
PREFLIGHT_ARGS=()

# -- Parse arguments ----------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ttl) TTL="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) PREFLIGHT_ARGS+=("$1"); shift ;;
  esac
done

# =============================================================================
# Cache check
# =============================================================================

NOW=$(date +%s)
CACHE_VALID=false
CACHED_AT=""

if [[ -f "$CACHE_FILE" ]] && ! $FORCE; then
  CACHED_AT=$(cat "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -n "$CACHED_AT" ]]; then
    AGE=$(( NOW - CACHED_AT ))
    if [[ $AGE -lt $TTL ]]; then
      CACHE_VALID=true
    fi
  fi
fi

# =============================================================================
# Execute or skip
# =============================================================================

if $CACHE_VALID; then
  REMAINING=$(( TTL - AGE ))
  if $JSON_OUTPUT; then
    cat <<ENDJSON
{
  "status": "cached",
  "cached_at": $CACHED_AT,
  "age_seconds": $AGE,
  "ttl_remaining": $REMAINING,
  "ran_preflight": false
}
ENDJSON
  else
    echo -e "${GREEN}[preflight-cached]${NC} Valid cache (${AGE}s old, ${REMAINING}s remaining). Skipping re-run."
  fi
  exit 0
fi

# Run the actual preflight
echo -e "${CYAN}[preflight-cached]${NC} Cache expired or forced. Running preflight..."

if "${SCRIPT_DIR}/preflight.sh" "${PREFLIGHT_ARGS[@]+"${PREFLIGHT_ARGS[@]}"}"; then
  # Update the timestamp cache
  mkdir -p "$(dirname "$CACHE_FILE")"
  date +%s > "$CACHE_FILE"

  if $JSON_OUTPUT; then
    cat <<ENDJSON
{
  "status": "passed",
  "cached_at": $(cat "$CACHE_FILE"),
  "age_seconds": 0,
  "ttl_remaining": $TTL,
  "ran_preflight": true
}
ENDJSON
  else
    echo -e "${GREEN}[preflight-cached]${NC} Preflight passed. Cache refreshed (TTL: ${TTL}s)."
  fi
else
  EXIT_CODE=$?
  if $JSON_OUTPUT; then
    cat <<ENDJSON
{
  "status": "failed",
  "cached_at": null,
  "age_seconds": null,
  "ttl_remaining": null,
  "ran_preflight": true,
  "exit_code": $EXIT_CODE
}
ENDJSON
  else
    echo -e "${RED}[preflight-cached]${NC} Preflight failed (exit $EXIT_CODE). Cache NOT updated."
  fi
  exit $EXIT_CODE
fi
