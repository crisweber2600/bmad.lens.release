#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Bootstrap Target Projects
#
# PURPOSE:
#   Clone or verify inventory-listed repositories from a governance
#   repo-inventory.yaml file into TargetProjects.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/bootstrap-target-projects.sh \
#       --inventory <repo-inventory.yaml-path> [--json]
#
# OPTIONS:
#   --inventory <path>     Path to repo-inventory.yaml (required)
#   --target-root <path>   Root folder for clones (default: TargetProjects)
#   --dry-run              Only check, don't clone
#   --json                 Machine-readable JSON output
#   -h, --help             Show this help message
#
# EXIT CODES:
#   0  Success
#   1  Error (missing inventory, clone failure)
#
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INVENTORY_PATH=""
TARGET_ROOT="TargetProjects"
DRY_RUN=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --inventory) INVENTORY_PATH="$2"; shift 2 ;;
    --target-root) TARGET_ROOT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

if [[ -z "$INVENTORY_PATH" ]]; then
  echo -e "${RED}ERROR: --inventory is required${NC}" >&2
  exit 1
fi

if [[ ! -f "$INVENTORY_PATH" ]]; then
  echo -e "${RED}ERROR: Inventory file not found: ${INVENTORY_PATH}${NC}" >&2
  exit 1
fi

# =============================================================================
# Parse inventory YAML (minimal parser for repo entries)
# =============================================================================
# Expects entries like:
#   repositories:
#     - name: my-repo
#       remote_url: https://github.com/org/my-repo.git
#       local_path: TargetProjects/my-repo
# Or flat:
#     - name: my-repo
#       url: https://github.com/org/my-repo.git
#       path: my-repo

declare -a RESULT_NAMES=()
declare -a RESULT_ACTIONS=()
declare -a RESULT_STATUS=()

current_name=""
current_url=""
current_path=""

flush_entry() {
  if [[ -z "$current_name" && -z "$current_url" ]]; then
    return
  fi

  local repo_name="${current_name:-unnamed}"
  local repo_path="${current_path}"
  local repo_url="${current_url}"

  # Default path from name
  if [[ -z "$repo_path" && -n "$current_name" ]]; then
    repo_path="${TARGET_ROOT}/${current_name}"
  fi

  if [[ -z "$repo_path" ]]; then
    RESULT_NAMES+=("$repo_name")
    RESULT_ACTIONS+=("skip")
    RESULT_STATUS+=("missing path")
  elif [[ -d "${repo_path}/.git" ]]; then
    RESULT_NAMES+=("$repo_name")
    RESULT_ACTIONS+=("verify")
    RESULT_STATUS+=("present")
  elif [[ -n "$repo_url" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      RESULT_NAMES+=("$repo_name")
      RESULT_ACTIONS+=("would-clone")
      RESULT_STATUS+=("planned")
    else
      if git clone "$repo_url" "$repo_path" 2>/dev/null; then
        RESULT_NAMES+=("$repo_name")
        RESULT_ACTIONS+=("clone")
        RESULT_STATUS+=("cloned")
      else
        RESULT_NAMES+=("$repo_name")
        RESULT_ACTIONS+=("clone")
        RESULT_STATUS+=("failed")
      fi
    fi
  else
    RESULT_NAMES+=("$repo_name")
    RESULT_ACTIONS+=("skip")
    RESULT_STATUS+=("missing remote")
  fi

  current_name=""
  current_url=""
  current_path=""
}

while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  # New list item
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
    flush_entry
  fi

  # Parse key: value pairs
  if [[ "$line" =~ name:[[:space:]]*(.*) ]]; then
    current_name=$(echo "${BASH_REMATCH[1]}" | tr -d '"' | tr -d "'")
  elif [[ "$line" =~ (remote_url|repo_url|remote|url):[[:space:]]*(.*) ]]; then
    current_url=$(echo "${BASH_REMATCH[2]}" | tr -d '"' | tr -d "'")
  elif [[ "$line" =~ (local_path|clone_path|path):[[:space:]]*(.*) ]]; then
    current_path=$(echo "${BASH_REMATCH[2]}" | tr -d '"' | tr -d "'")
  fi
done < "$INVENTORY_PATH"

# Flush last entry
flush_entry

# =============================================================================
# Output
# =============================================================================

if [[ "$JSON_OUTPUT" == "true" ]]; then
  entries_json="["
  first=true
  for (( i=0; i<${#RESULT_NAMES[@]}; i++ )); do
    [[ "$first" == "true" ]] && first=false || entries_json="${entries_json},"
    entries_json="${entries_json}{\"name\":\"${RESULT_NAMES[$i]}\",\"action\":\"${RESULT_ACTIONS[$i]}\",\"status\":\"${RESULT_STATUS[$i]}\"}"
  done
  entries_json="${entries_json}]"

  echo "{\"entries\":${entries_json},\"count\":${#RESULT_NAMES[@]},\"dry_run\":${DRY_RUN}}"
else
  echo -e "${GREEN}✅ Bootstrap complete${NC}"
  echo -e "├── Entries processed: ${#RESULT_NAMES[@]}"
  echo -e "├── Mode: $([ "$DRY_RUN" == "true" ] && echo "dry-run" || echo "live")"

  for (( i=0; i<${#RESULT_NAMES[@]}; i++ )); do
    status_icon="✅"
    [[ "${RESULT_STATUS[$i]}" == "failed" ]] && status_icon="❌"
    [[ "${RESULT_STATUS[$i]}" == "missing"* ]] && status_icon="⚠"
    [[ "${RESULT_STATUS[$i]}" == "planned" ]] && status_icon="📋"
    echo -e "│   ${status_icon} ${RESULT_NAMES[$i]} (${RESULT_ACTIONS[$i]}: ${RESULT_STATUS[$i]})"
  done
  echo -e "└── Done"
fi
