#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Validate Phase Artifacts
#
# PURPOSE:
#   Check that required artifacts for a lifecycle phase exist and are non-empty.
#   Uses lifecycle.yaml as the single source of truth for required artifacts.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/validate-phase-artifacts.sh \
#       --phase <phase-name> \
#       --lifecycle <lifecycle.yaml-path> \
#       --docs-root <planning-artifacts-path> \
#       [--json]
#
# OPTIONS:
#   --phase <name>         Phase name (e.g. preplan, businessplan) (required)
#   --lifecycle <path>     Path to lifecycle.yaml (required)
#   --docs-root <path>     Path to planning artifacts folder (required)
#   --json                 Machine-readable JSON output
#   -h, --help             Show this help message
#
# EXIT CODES:
#   0  All artifacts present
#   1  Missing artifacts or error
#
# =============================================================================

set -euo pipefail

# -- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# -- Defaults ----------------------------------------------------------------
PHASE=""
LIFECYCLE_PATH=""
DOCS_ROOT=""
JSON_OUTPUT=false

# -- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    --lifecycle) LIFECYCLE_PATH="$2"; shift 2 ;;
    --docs-root) DOCS_ROOT="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

for required_arg in PHASE LIFECYCLE_PATH DOCS_ROOT; do
  if [[ -z "${!required_arg}" ]]; then
    echo -e "${RED}ERROR: --$(echo "$required_arg" | tr '[:upper:]' '[:lower:]' | tr '_' '-') is required${NC}" >&2
    exit 1
  fi
done

if [[ ! -f "$LIFECYCLE_PATH" ]]; then
  echo -e "${RED}ERROR: lifecycle.yaml not found: ${LIFECYCLE_PATH}${NC}" >&2
  exit 1
fi

# =============================================================================
# Extract required artifacts from lifecycle.yaml
# =============================================================================

# Parse artifacts list for the given phase from lifecycle.yaml
# Looks for: phases: -> <phase>: -> artifacts: -> list items
in_phases=false
in_phase=false
in_artifacts=false
REQUIRED_ARTIFACTS=()

while IFS= read -r line; do
  # Detect sections
  if [[ "$line" =~ ^phases: ]]; then
    in_phases=true; continue
  fi

  if [[ "$in_phases" == "true" ]]; then
    # Detect our target phase (indented key)
    if [[ "$line" =~ ^[[:space:]]{2}${PHASE}: ]]; then
      in_phase=true; continue
    fi

    # Detect a different phase (exit our phase block)
    if [[ "$in_phase" == "true" && "$line" =~ ^[[:space:]]{2}[a-z] && ! "$line" =~ ^[[:space:]]{4} ]]; then
      in_phase=false; in_artifacts=false; continue
    fi

    if [[ "$in_phase" == "true" ]]; then
      if [[ "$line" =~ ^[[:space:]]*artifacts: ]]; then
        in_artifacts=true; continue
      fi

      if [[ "$in_artifacts" == "true" ]]; then
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
          artifact=$(echo "${BASH_REMATCH[1]}" | tr -d '[:space:]')
          REQUIRED_ARTIFACTS+=("$artifact")
        else
          in_artifacts=false
        fi
      fi
    fi
  fi
done < "$LIFECYCLE_PATH"

if [[ ${#REQUIRED_ARTIFACTS[@]} -eq 0 ]]; then
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo '{"phase":"'"$PHASE"'","required":0,"found":0,"missing":[],"status":"no_artifacts_defined"}'
  else
    echo -e "${YELLOW}⚠ No artifacts defined for phase: ${PHASE}${NC}"
  fi
  exit 0
fi

# =============================================================================
# Check each artifact
# =============================================================================

FOUND=()
MISSING=()

check_artifact() {
  local name="$1"
  local candidates=()

  case "$name" in
    product-brief)
      candidates=("${DOCS_ROOT}/product-brief.md")
      # Also check glob pattern
      for f in "${DOCS_ROOT}"/product-brief-*.md; do
        [[ -f "$f" ]] && candidates+=("$f")
      done
      ;;
    research)
      candidates=("${DOCS_ROOT}/research.md")
      for f in "${DOCS_ROOT}"/research-*.md; do
        [[ -f "$f" ]] && candidates+=("$f")
      done
      ;;
    brainstorm)
      candidates=("${DOCS_ROOT}/brainstorm.md")
      ;;
    prd)
      candidates=("${DOCS_ROOT}/prd.md")
      ;;
    ux-design)
      candidates=("${DOCS_ROOT}/ux-design.md" "${DOCS_ROOT}/ux-design-specification.md")
      ;;
    architecture)
      candidates=("${DOCS_ROOT}/architecture.md")
      for f in "${DOCS_ROOT}"/*architecture*.md; do
        [[ -f "$f" ]] && candidates+=("$f")
      done
      ;;
    epics)
      candidates=("${DOCS_ROOT}/epics.md")
      ;;
    stories)
      candidates=("${DOCS_ROOT}/stories.md")
      ;;
    implementation-readiness)
      candidates=("${DOCS_ROOT}/readiness-checklist.md" "${DOCS_ROOT}/implementation-readiness.md")
      ;;
    sprint-status)
      candidates=("${DOCS_ROOT}/sprint-status.yaml" "${DOCS_ROOT}/sprint-backlog.md")
      ;;
    story-files)
      for f in "${DOCS_ROOT}"/dev-story-*.md; do
        [[ -f "$f" ]] && candidates+=("$f")
      done
      ;;
    review-report)
      candidates=("${DOCS_ROOT}/review-report.md" "${DOCS_ROOT}/adversarial-review.md")
      ;;
    *)
      candidates=("${DOCS_ROOT}/${name}.md")
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" && -s "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
  if check_artifact "$artifact"; then
    FOUND+=("$artifact")
  else
    MISSING+=("$artifact")
  fi
done

# =============================================================================
# Output
# =============================================================================

EXIT_CODE=0
[[ ${#MISSING[@]} -gt 0 ]] && EXIT_CODE=1

if [[ "$JSON_OUTPUT" == "true" ]]; then
  found_json="[$(printf '"%s",' "${FOUND[@]}" | sed 's/,$//' )]"
  missing_json="[$(printf '"%s",' "${MISSING[@]}" | sed 's/,$//' )]"
  [[ ${#FOUND[@]} -eq 0 ]] && found_json="[]"
  [[ ${#MISSING[@]} -eq 0 ]] && missing_json="[]"

  echo "{\"phase\":\"${PHASE}\",\"required\":${#REQUIRED_ARTIFACTS[@]},\"found\":${#FOUND[@]},\"missing\":${missing_json},\"found_list\":${found_json},\"status\":\"$([ $EXIT_CODE -eq 0 ] && echo 'pass' || echo 'fail')\"}"
else
  if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✅ Phase artifacts verified${NC}"
  else
    echo -e "${RED}❌ Phase incomplete${NC}"
  fi
  echo -e "├── Phase:    ${PHASE}"
  echo -e "├── Required: ${#REQUIRED_ARTIFACTS[@]}"
  echo -e "├── Found:    ${#FOUND[@]}"

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "└── Missing:  ${MISSING[*]}"
  else
    echo -e "└── Missing:  none"
  fi
fi

exit $EXIT_CODE
