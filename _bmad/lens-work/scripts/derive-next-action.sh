#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Derive Next Action
#
# PURPOSE:
#   Apply lifecycle decision rules to determine the single next command or
#   hard gate for the current initiative. Mirrors the logic in
#   workflows/utility/next/steps/step-02-derive-action.md.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/derive-next-action.sh <initiative-root>
#   ./lens.core/_bmad/lens-work/scripts/derive-next-action.sh <initiative-root> --json
#
# INPUTS:
#   initiative-root   Path to a directory containing initiative-state.yaml
#   --json            Output machine-readable JSON (default: human-readable)
#
# OUTPUT FIELDS:
#   next_command  - The command to run (null when gated)
#   gate_message  - Human-readable gate or info message (null when no gate)
#   hard_gate     - true when a blocking condition exists
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -- Defaults -----------------------------------------------------------------
JSON_OUTPUT=false
INITIATIVE_ROOT=""

# -- Parse arguments ----------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$INITIATIVE_ROOT" ]]; then
        INITIATIVE_ROOT="$1"; shift
      else
        echo -e "${RED}Unknown argument: $1${NC}"; exit 1
      fi
      ;;
  esac
done

if [[ -z "$INITIATIVE_ROOT" ]]; then
  echo -e "${RED}ERROR: initiative-root argument required${NC}" >&2
  exit 1
fi

STATE_FILE="${INITIATIVE_ROOT}/initiative-state.yaml"
if [[ ! -f "$STATE_FILE" ]]; then
  echo -e "${RED}ERROR: initiative-state.yaml not found in ${INITIATIVE_ROOT}${NC}" >&2
  exit 1
fi

# =============================================================================
# Read state fields
# =============================================================================

read_yaml_field() {
  local field="$1"
  awk -v f="$field" '$1 == f":" { $1=""; sub(/^[[:space:]]+/, ""); print; exit }' "$STATE_FILE"
}

MILESTONE="$(read_yaml_field milestone)"
PHASE="$(read_yaml_field phase)"
ACTION="$(read_yaml_field action)"
SCOPE="$(read_yaml_field scope)"

# =============================================================================
# Decision tree (mirrors step-02-derive-action.md)
# =============================================================================

next_command=""
gate_message=""
hard_gate=false

if [[ -z "$MILESTONE" && -z "$PHASE" && -z "$ACTION" ]]; then
  gate_message="Not currently on an initiative branch. Run /status or /switch."
elif [[ -z "$MILESTONE" && "$SCOPE" == "domain" ]]; then
  next_command="/new-service"
elif [[ -z "$MILESTONE" && "$SCOPE" == "service" ]]; then
  next_command="/new-feature"
elif echo "$ACTION" | grep -qi "awaiting review\|awaiting merge"; then
  hard_gate=true
  gate_message="A PR is still open for the active lifecycle step. Merge it, then run /next again."
elif echo "$ACTION" | grep -qi "address review feedback"; then
  hard_gate=true
  gate_message="Review feedback is blocking progress. Resolve the requested changes, then run /next again."
elif [[ "$ACTION" == "Ready to promote" ]]; then
  next_command="/promote"
elif echo "$ACTION" | grep -qi "promotion in review"; then
  hard_gate=true
  gate_message="Promotion PR is open. Merge it, then run /next again."
elif [[ -n "$PHASE" ]] && echo "$ACTION" | grep -qi "complete phase\|start next phase"; then
  next_command="/${PHASE}"
elif echo "$ACTION" | grep -qi "ready for execution"; then
  gate_message="All caught up. The initiative is ready for execution."
else
  gate_message="No deterministic next action was found. Run /status for the full picture."
fi

# =============================================================================
# Output
# =============================================================================

if $JSON_OUTPUT; then
  cat <<ENDJSON
{
  "next_command": $(if [[ -n "$next_command" ]]; then echo "\"$next_command\""; else echo "null"; fi),
  "gate_message": $(if [[ -n "$gate_message" ]]; then echo "\"$gate_message\""; else echo "null"; fi),
  "hard_gate": $hard_gate
}
ENDJSON
else
  echo ""
  if [[ -n "$next_command" ]]; then
    echo -e "${GREEN}${BOLD}Next action:${NC} ${CYAN}${next_command}${NC}"
  elif $hard_gate; then
    echo -e "${RED}${BOLD}BLOCKED:${NC} ${gate_message}"
  elif [[ -n "$gate_message" ]]; then
    echo -e "${YELLOW}${BOLD}Info:${NC} ${gate_message}"
  fi
  echo ""
fi
