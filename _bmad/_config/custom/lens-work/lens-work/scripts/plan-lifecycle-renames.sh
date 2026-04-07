#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Plan Lifecycle Renames
#
# PURPOSE:
#   Scan local branches for v2 audience-based naming, compute a v3 milestone
#   rename plan. Outputs the rename map, phase branch advisories, and YAML
#   field changes required for migration.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/plan-lifecycle-renames.sh [--dry-run] [--json]
#
# OPTIONS:
#   --dry-run              Only compute the plan, don't apply (default)
#   --apply                Apply the renames (creates branches, does not delete old)
#   --json                 Machine-readable JSON output
#   -h, --help             Show this help message
#
# EXIT CODES:
#   0  Success
#   1  Error
#
# =============================================================================

set -euo pipefail

# -- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# -- Defaults ----------------------------------------------------------------
DRY_RUN=true
JSON_OUTPUT=false

# -- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --apply) DRY_RUN=false; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

# =============================================================================
# Audience-to-Milestone mapping (v2 → v3)
# =============================================================================

declare -A AUDIENCE_MAP
AUDIENCE_MAP[small]="techplan"
AUDIENCE_MAP[medium]="devproposal"
AUDIENCE_MAP[large]="sprintplan"
AUDIENCE_MAP[base]="dev-ready"

AUDIENCE_TOKENS=("small" "medium" "large" "base")

# =============================================================================
# Scan branches
# =============================================================================

BRANCHES=$(git branch --format='%(refname:short)' 2>/dev/null)
if [[ -z "$BRANCHES" ]]; then
  echo -e "${YELLOW}⚠ No local branches found${NC}" >&2
  exit 0
fi

# Arrays to collect results
declare -a RENAMES_FROM=()
declare -a RENAMES_TO=()
declare -a RENAMES_TYPE=()
declare -a PHASE_ADVISORIES=()
declare -a INIT_ROOTS=()

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue

  IFS='-' read -ra segments <<< "$branch"

  # Find last occurrence of an audience token
  audience_idx=-1
  for (( i=${#segments[@]}-1; i>=0; i-- )); do
    for token in "${AUDIENCE_TOKENS[@]}"; do
      if [[ "${segments[$i]}" == "$token" ]]; then
        audience_idx=$i
        break 2
      fi
    done
  done

  [[ $audience_idx -eq -1 ]] && continue

  audience_token="${segments[$audience_idx]}"
  milestone_token="${AUDIENCE_MAP[$audience_token]}"

  # Extract initiative root (everything before the audience token)
  init_root=""
  for (( i=0; i<audience_idx; i++ )); do
    [[ -n "$init_root" ]] && init_root="${init_root}-"
    init_root="${init_root}${segments[$i]}"
  done

  # Track unique initiative roots
  found_root=false
  for r in "${INIT_ROOTS[@]+"${INIT_ROOTS[@]}"}"; do
    [[ "$r" == "$init_root" ]] && found_root=true && break
  done
  [[ "$found_root" == "false" ]] && INIT_ROOTS+=("$init_root")

  # Determine if this is a phase branch (has segments after the audience token)
  trailing_count=$(( ${#segments[@]} - audience_idx - 1 ))

  if [[ $trailing_count -eq 0 ]]; then
    # Pure audience-root branch: {root}-{audience} → {root}-{milestone}
    new_name="${init_root}-${milestone_token}"
    RENAMES_FROM+=("$branch")
    RENAMES_TO+=("$new_name")
    RENAMES_TYPE+=("milestone-root")
  else
    # Phase branch: no v3 equivalent
    PHASE_ADVISORIES+=("${branch} — v2 phase branch. Verify merged, then delete.")
  fi

done <<< "$BRANCHES"

# =============================================================================
# Apply renames (if --apply)
# =============================================================================

APPLIED=0
if [[ "$DRY_RUN" == "false" && ${#RENAMES_FROM[@]} -gt 0 ]]; then
  for (( i=0; i<${#RENAMES_FROM[@]}; i++ )); do
    from="${RENAMES_FROM[$i]}"
    to="${RENAMES_TO[$i]}"

    if git rev-parse --verify "$to" >/dev/null 2>&1; then
      echo -e "${YELLOW}⚠ Target branch already exists: ${to} (skipping ${from})${NC}" >&2
      continue
    fi

    git branch -m "$from" "$to" 2>/dev/null && APPLIED=$((APPLIED + 1))
  done
fi

# =============================================================================
# Output
# =============================================================================

if [[ "$JSON_OUTPUT" == "true" ]]; then
  renames_json="["
  first=true
  for (( i=0; i<${#RENAMES_FROM[@]}; i++ )); do
    [[ "$first" == "true" ]] && first=false || renames_json="${renames_json},"
    renames_json="${renames_json}{\"from\":\"${RENAMES_FROM[$i]}\",\"to\":\"${RENAMES_TO[$i]}\",\"type\":\"${RENAMES_TYPE[$i]}\"}"
  done
  renames_json="${renames_json}]"

  advisories_json="["
  first=true
  for adv in "${PHASE_ADVISORIES[@]+"${PHASE_ADVISORIES[@]}"}"; do
    [[ "$first" == "true" ]] && first=false || advisories_json="${advisories_json},"
    advisories_json="${advisories_json}\"${adv}\""
  done
  advisories_json="${advisories_json}]"

  roots_json="["
  first=true
  for r in "${INIT_ROOTS[@]+"${INIT_ROOTS[@]}"}"; do
    [[ "$first" == "true" ]] && first=false || roots_json="${roots_json},"
    roots_json="${roots_json}\"${r}\""
  done
  roots_json="${roots_json}]"

  echo "{\"renames\":${renames_json},\"advisories\":${advisories_json},\"initiative_roots\":${roots_json},\"applied\":${APPLIED},\"dry_run\":${DRY_RUN}}"
else
  echo -e "${GREEN}📋 Migration plan complete${NC}"
  echo -e "├── Branch renames: ${#RENAMES_FROM[@]}"
  echo -e "├── Phase advisories: ${#PHASE_ADVISORIES[@]}"
  echo -e "├── Initiative roots: ${#INIT_ROOTS[@]}"

  if [[ ${#RENAMES_FROM[@]} -gt 0 ]]; then
    echo ""
    echo -e "${CYAN}Renames:${NC}"
    for (( i=0; i<${#RENAMES_FROM[@]}; i++ )); do
      echo "  ${RENAMES_FROM[$i]} → ${RENAMES_TO[$i]} (${RENAMES_TYPE[$i]})"
    done
  fi

  if [[ ${#PHASE_ADVISORIES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Phase advisories:${NC}"
    for adv in "${PHASE_ADVISORIES[@]}"; do
      echo "  $adv"
    done
  fi

  if [[ "$DRY_RUN" == "false" ]]; then
    echo -e "\n└── Applied: ${APPLIED}"
  else
    echo -e "\n└── Mode: dry-run (use --apply to execute)"
  fi
fi
