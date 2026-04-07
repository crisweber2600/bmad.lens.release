#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Load Command Registry
#
# PURPOSE:
#   Read module-help.csv and group commands by category for /help rendering.
#   Optionally resolve a fuzzy command match for invalid-command recovery.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/load-command-registry.sh --csv path/to/module-help.csv
#   ./lens.core/_bmad/lens-work/scripts/load-command-registry.sh --csv path/to/module-help.csv --resolve "/bplan"
#   ./lens.core/_bmad/lens-work/scripts/load-command-registry.sh --csv path/to/module-help.csv --json
#
# OPTIONS:
#   --csv <path>      Path to module-help.csv (required)
#   --resolve <cmd>   Try to resolve an invalid/partial command
#   --json            Output JSON instead of human-readable text
#   -h, --help        Show this help message
#
# EXIT CODES:
#   0  Success
#   1  Error (missing CSV, parse failure)
#
# =============================================================================

set -euo pipefail

# -- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -- Defaults ----------------------------------------------------------------
CSV_PATH=""
RESOLVE_CMD=""
JSON_OUTPUT=false

# -- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv) CSV_PATH="$2"; shift 2 ;;
    --resolve) RESOLVE_CMD="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

if [[ -z "$CSV_PATH" ]]; then
  echo -e "${RED}ERROR: --csv is required${NC}" >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo -e "${RED}ERROR: CSV file not found: ${CSV_PATH}${NC}" >&2
  exit 1
fi

# =============================================================================
# Parse CSV and classify commands
# =============================================================================

declare -a CMD_NAMES=()
declare -a CMD_CODES=()
declare -a CMD_DESCS=()
declare -a CMD_GROUPS=()
declare -a CMD_PHASES=()

LINE_NUM=0
while IFS= read -r line; do
  LINE_NUM=$((LINE_NUM + 1))
  [[ $LINE_NUM -eq 1 ]] && continue  # Skip header

  # Parse CSV fields (handle quoted fields with commas)
  # module,skill,display-name,menu-code,description,action,args,phase,...
  module=$(echo "$line" | awk -F',' '{print $1}')
  display_name=$(echo "$line" | awk -F',' '{print $3}')
  menu_code=$(echo "$line" | awk -F',' '{print $4}')

  # Extract description (may be quoted with commas inside)
  desc=$(echo "$line" | sed 's/^[^,]*,[^,]*,[^,]*,[^,]*,//' | sed 's/^\"//' | sed 's/\",.*$//' | sed 's/,.*//')

  # Extract phase field (field 8)
  phase=$(echo "$line" | awk -F',' '{print $8}')

  # Determine render group based on phase
  group="utility"
  case "$phase" in
    phase-1|phase-2|phase-3|phase-4|phase-5|phase-express) group="lifecycle" ;;
    delegation) group="lifecycle" ;;
  esac

  # Navigation commands by code
  case "$menu_code" in
    SW|ST|NX|DS|NI) group="navigation" ;;
  esac

  # Derive user command from display name
  user_cmd="/"$(echo "$display_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  CMD_NAMES+=("$user_cmd")
  CMD_CODES+=("$menu_code")
  CMD_DESCS+=("$desc")
  CMD_GROUPS+=("$group")
  CMD_PHASES+=("$phase")
done < "$CSV_PATH"

if [[ ${#CMD_NAMES[@]} -eq 0 ]]; then
  echo -e "${RED}ERROR: module-help.csv is empty or unparseable${NC}" >&2
  exit 1
fi

# =============================================================================
# Resolve fuzzy command match (if requested)
# =============================================================================

CLOSEST_MATCH=""
SUGGESTED_GROUP=""
MATCH_TYPE=""

if [[ -n "$RESOLVE_CMD" ]]; then
  # Normalize the requested command
  resolve_lower=$(echo "$RESOLVE_CMD" | tr '[:upper:]' '[:lower:]')
  [[ "$resolve_lower" != /* ]] && resolve_lower="/${resolve_lower}"

  # 1. Exact match
  for i in "${!CMD_NAMES[@]}"; do
    if [[ "${CMD_NAMES[$i]}" == "$resolve_lower" ]]; then
      CLOSEST_MATCH="${CMD_NAMES[$i]}"
      SUGGESTED_GROUP="${CMD_GROUPS[$i]}"
      MATCH_TYPE="exact"
      break
    fi
  done

  # 2. Prefix match
  if [[ -z "$CLOSEST_MATCH" ]]; then
    for i in "${!CMD_NAMES[@]}"; do
      if [[ "${CMD_NAMES[$i]}" == "$resolve_lower"* || "$resolve_lower" == "${CMD_NAMES[$i]}"* ]]; then
        CLOSEST_MATCH="${CMD_NAMES[$i]}"
        SUGGESTED_GROUP="${CMD_GROUPS[$i]}"
        MATCH_TYPE="prefix"
        break
      fi
    done
  fi

  # 3. Normalized match (remove hyphens and slashes)
  if [[ -z "$CLOSEST_MATCH" ]]; then
    norm_request=$(echo "$resolve_lower" | tr -d '/-')
    for i in "${!CMD_NAMES[@]}"; do
      norm_cmd=$(echo "${CMD_NAMES[$i]}" | tr -d '/-')
      if [[ "$norm_cmd" == "$norm_request" ]]; then
        CLOSEST_MATCH="${CMD_NAMES[$i]}"
        SUGGESTED_GROUP="${CMD_GROUPS[$i]}"
        MATCH_TYPE="normalized"
        break
      fi
    done
  fi
fi

# =============================================================================
# Output
# =============================================================================

if [[ "$JSON_OUTPUT" == "true" ]]; then
  # Build JSON output
  entries=""
  for i in "${!CMD_NAMES[@]}"; do
    [[ -n "$entries" ]] && entries="${entries},"
    entries="${entries}{\"command\":\"${CMD_NAMES[$i]}\",\"code\":\"${CMD_CODES[$i]}\",\"description\":\"${CMD_DESCS[$i]}\",\"group\":\"${CMD_GROUPS[$i]}\"}"
  done

  match_json="null"
  if [[ -n "$CLOSEST_MATCH" ]]; then
    match_json="{\"command\":\"${CLOSEST_MATCH}\",\"group\":\"${SUGGESTED_GROUP}\",\"type\":\"${MATCH_TYPE}\"}"
  fi

  echo "{\"commands\":[${entries}],\"count\":${#CMD_NAMES[@]},\"match\":${match_json}}"
else
  echo -e "${GREEN}✅ Command registry loaded${NC}"
  echo -e "├── Commands: ${#CMD_NAMES[@]}"

  # Count groups
  nav_count=0; life_count=0; util_count=0
  for g in "${CMD_GROUPS[@]}"; do
    case "$g" in
      navigation) nav_count=$((nav_count + 1)) ;;
      lifecycle) life_count=$((life_count + 1)) ;;
      utility) util_count=$((util_count + 1)) ;;
    esac
  done

  echo -e "├── Groups: navigation(${nav_count}), lifecycle(${life_count}), utility(${util_count})"

  if [[ -n "$RESOLVE_CMD" ]]; then
    if [[ -n "$CLOSEST_MATCH" ]]; then
      echo -e "└── Recovery: ${CLOSEST_MATCH} (${MATCH_TYPE} match, ${SUGGESTED_GROUP})"
    else
      echo -e "└── Recovery: no match for '${RESOLVE_CMD}'"
    fi
  else
    echo -e "└── Recovery: none requested"
  fi
fi
