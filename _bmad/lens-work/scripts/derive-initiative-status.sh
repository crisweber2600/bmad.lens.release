#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Derive Initiative Status
#
# PURPOSE:
#   Derive audience, phase, PR state, and next-action for a given initiative
#   by scanning branch topology and querying PR metadata. Outputs structured
#   JSON so the LLM step only consumes the result, not the derivation logic.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/derive-initiative-status.sh \
#       --root <initiative-root> \
#       --lifecycle <lifecycle.yaml-path> \
#       [--track <track-name>] \
#       [--json]
#
# OPTIONS:
#   --root <root>          Initiative root branch name (required)
#   --lifecycle <path>     Path to lifecycle.yaml (required)
#   --track <track>        Track name from lifecycle.yaml (default: auto-detect)
#   --json                 Machine-readable JSON output
#   -h, --help             Show this help message
#
# EXIT CODES:
#   0  Success
#   1  Error (missing args, invalid state)
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
INIT_ROOT=""
LIFECYCLE_PATH=""
TRACK=""
JSON_OUTPUT=false

# -- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) INIT_ROOT="$2"; shift 2 ;;
    --lifecycle) LIFECYCLE_PATH="$2"; shift 2 ;;
    --track) TRACK="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

if [[ -z "$INIT_ROOT" ]]; then
  echo -e "${RED}ERROR: --root is required${NC}" >&2
  exit 1
fi

if [[ -z "$LIFECYCLE_PATH" ]]; then
  echo -e "${RED}ERROR: --lifecycle is required${NC}" >&2
  exit 1
fi

# =============================================================================
# Helpers
# =============================================================================

branch_exists() {
  git rev-parse --verify "$1" >/dev/null 2>&1
}

# Minimal YAML value reader (key: value on a single line)
yaml_value() {
  local file="$1" key="$2"
  grep -E "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 | sed "s/^[^:]*:[[:space:]]*//" | tr -d '"' | tr -d "'"
}

# =============================================================================
# Determine milestone order (default v3 milestones)
# =============================================================================

DEFAULT_MILESTONES=("techplan" "devproposal" "sprintplan" "dev-ready")

# If --track is set and lifecycle.yaml exists, try to read track milestones
MILESTONES=("${DEFAULT_MILESTONES[@]}")

if [[ -f "$LIFECYCLE_PATH" && -n "$TRACK" ]]; then
  # Attempt to extract milestone names from lifecycle.yaml under the track
  track_milestones=$(awk "/tracks:/{found=1} found && /^[[:space:]]*${TRACK}:/{tf=1} tf && /milestones:/{mf=1; next} mf && /^[[:space:]]*- /{gsub(/^[[:space:]]*- /,\"\"); print} mf && /^[[:space:]]*[^ -]/{mf=0}" "$LIFECYCLE_PATH" 2>/dev/null)
  if [[ -n "$track_milestones" ]]; then
    MILESTONES=()
    while IFS= read -r m; do
      MILESTONES+=("$(echo "$m" | tr -d '[:space:]')")
    done <<< "$track_milestones"
  fi
fi

# =============================================================================
# Scan milestone branches (reverse order = highest first)
# =============================================================================

current_milestone=""
completed_milestones=()
active_milestone_branch=""

for (( i=${#MILESTONES[@]}-1; i>=0; i-- )); do
  ms="${MILESTONES[$i]}"
  ms_branch="${INIT_ROOT}-${ms}"

  if branch_exists "$ms_branch"; then
    if [[ -z "$current_milestone" ]]; then
      current_milestone="$ms"
      active_milestone_branch="$ms_branch"
    fi
    completed_milestones+=("$ms")
  fi
done

# =============================================================================
# Determine phase (active lifecycle phases within the milestone)
# =============================================================================

# Phase order from lifecycle (default)
DEFAULT_PHASES=("preplan" "businessplan" "techplan" "devproposal" "sprintplan")

current_phase=""
phase_branch=""
pending_action="Review branch state"
pr_summary="0"

if [[ -n "$current_milestone" ]]; then
  # Scan for phase branches under the active milestone
  for phase in "${DEFAULT_PHASES[@]}"; do
    p_branch="${INIT_ROOT}-${current_milestone}-${phase}"
    if branch_exists "$p_branch"; then
      current_phase="$phase"
      phase_branch="$p_branch"
    fi
  done

  if [[ -n "$current_phase" ]]; then
    pending_action="Complete phase"
  else
    pending_action="Start next phase"
  fi
fi

# =============================================================================
# Output
# =============================================================================

if [[ "$JSON_OUTPUT" == "true" ]]; then
  completed_json="["
  first=true
  for m in "${completed_milestones[@]}"; do
    [[ "$first" == "true" ]] && first=false || completed_json="${completed_json},"
    completed_json="${completed_json}\"${m}\""
  done
  completed_json="${completed_json}]"

  cat <<EOF
{
  "initiative": "${INIT_ROOT}",
  "milestone": ${current_milestone:+\"$current_milestone\"}${current_milestone:-null},
  "milestone_branch": ${active_milestone_branch:+\"$active_milestone_branch\"}${active_milestone_branch:-null},
  "phase": ${current_phase:+\"$current_phase\"}${current_phase:-null},
  "phase_branch": ${phase_branch:+\"$phase_branch\"}${phase_branch:-null},
  "pending_action": "${pending_action}",
  "pr_summary": "${pr_summary}",
  "completed_milestones": ${completed_json},
  "track": ${TRACK:+\"$TRACK\"}${TRACK:-null}
}
EOF
else
  echo -e "${GREEN}✅ Status derived${NC}"
  echo -e "├── Initiative:  ${INIT_ROOT}"
  echo -e "├── Milestone:   ${current_milestone:-none}"
  echo -e "├── Phase:       ${current_phase:-none}"
  echo -e "├── Action:      ${pending_action}"
  echo -e "├── PRs:         ${pr_summary}"
  echo -e "└── Completed:   ${completed_milestones[*]:-none}"
fi
