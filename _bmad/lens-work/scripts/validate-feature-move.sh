#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Validate Feature Move
#
# PURPOSE:
#   Validate that a feature can be safely moved to a new domain/service.
#   Checks for conflicts, uncommitted changes, and current scope.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/validate-feature-move.sh \
#       --feature <name> --old-domain <d> --old-service <s> \
#       --new-domain <d> --new-service <s> \
#       --initiatives-root <path> [--json]
#
# OPTIONS:
#   --feature <name>            Feature name (required)
#   --old-domain <domain>       Current domain (required)
#   --old-service <service>     Current service (required)
#   --new-domain <domain>       Target domain (required)
#   --new-service <service>     Target service (required)
#   --initiatives-root <path>   Root path for initiatives (required)
#   --json                      Machine-readable JSON output
#   -h, --help                  Show this help message
#
# EXIT CODES:
#   0  Move is safe
#   1  Move is blocked
#
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FEATURE="" OLD_DOMAIN="" OLD_SERVICE="" NEW_DOMAIN="" NEW_SERVICE=""
INITIATIVES_ROOT=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature) FEATURE="$2"; shift 2 ;;
    --old-domain) OLD_DOMAIN="$2"; shift 2 ;;
    --old-service) OLD_SERVICE="$2"; shift 2 ;;
    --new-domain) NEW_DOMAIN="$2"; shift 2 ;;
    --new-service) NEW_SERVICE="$2"; shift 2 ;;
    --initiatives-root) INITIATIVES_ROOT="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

# Validate required args
for arg_name in FEATURE OLD_DOMAIN OLD_SERVICE NEW_DOMAIN NEW_SERVICE INITIATIVES_ROOT; do
  if [[ -z "${!arg_name}" ]]; then
    echo -e "${RED}ERROR: --$(echo "$arg_name" | tr '[:upper:]' '[:lower:]' | tr '_' '-') is required${NC}" >&2
    exit 1
  fi
done

# Sanitize inputs
NEW_DOMAIN=$(echo "$NEW_DOMAIN" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
NEW_SERVICE=$(echo "$NEW_SERVICE" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')

# =============================================================================
# Validation checks
# =============================================================================

ERRORS=()
WARNINGS=()

# 1. Check source exists
OLD_PATH="${INITIATIVES_ROOT}/${OLD_DOMAIN}/${OLD_SERVICE}"
if [[ ! -d "$OLD_PATH" ]]; then
  ERRORS+=("Source path does not exist: ${OLD_PATH}")
fi

# 2. Check target does not already have this feature
NEW_PATH="${INITIATIVES_ROOT}/${NEW_DOMAIN}/${NEW_SERVICE}"
if [[ -f "${NEW_PATH}/${FEATURE}.yaml" ]]; then
  ERRORS+=("Feature '${FEATURE}' already exists at ${NEW_DOMAIN}/${NEW_SERVICE}")
fi

# 3. Check for uncommitted changes
if ! git diff --quiet 2>/dev/null; then
  WARNINGS+=("Uncommitted changes detected — commit or stash before moving")
fi

# 4. Check feature config exists at source
if [[ ! -f "${OLD_PATH}/${FEATURE}.yaml" ]]; then
  ERRORS+=("Feature config not found: ${OLD_PATH}/${FEATURE}.yaml")
fi

# 5. Same location check
if [[ "$OLD_DOMAIN" == "$NEW_DOMAIN" && "$OLD_SERVICE" == "$NEW_SERVICE" ]]; then
  ERRORS+=("Source and target are the same (${OLD_DOMAIN}/${OLD_SERVICE})")
fi

# =============================================================================
# Build result
# =============================================================================

SAFE=true
[[ ${#ERRORS[@]} -gt 0 ]] && SAFE=false

FILES_TO_MOVE=()
if [[ -f "${OLD_PATH}/${FEATURE}.yaml" ]]; then
  FILES_TO_MOVE+=("${OLD_PATH}/${FEATURE}.yaml → ${NEW_PATH}/${FEATURE}.yaml")
fi
if [[ -d "${OLD_PATH}/${FEATURE}/" ]]; then
  FILES_TO_MOVE+=("${OLD_PATH}/${FEATURE}/ → ${NEW_PATH}/${FEATURE}/")
fi

# =============================================================================
# Output
# =============================================================================

if [[ "$JSON_OUTPUT" == "true" ]]; then
  errors_json="[$(printf '"%s",' "${ERRORS[@]}" | sed 's/,$//' )]"
  warnings_json="[$(printf '"%s",' "${WARNINGS[@]}" | sed 's/,$//' )]"
  files_json="[$(printf '"%s",' "${FILES_TO_MOVE[@]}" | sed 's/,$//' )]"
  [[ ${#ERRORS[@]} -eq 0 ]] && errors_json="[]"
  [[ ${#WARNINGS[@]} -eq 0 ]] && warnings_json="[]"
  [[ ${#FILES_TO_MOVE[@]} -eq 0 ]] && files_json="[]"

  echo "{\"safe\":${SAFE},\"feature\":\"${FEATURE}\",\"from\":\"${OLD_DOMAIN}/${OLD_SERVICE}\",\"to\":\"${NEW_DOMAIN}/${NEW_SERVICE}\",\"errors\":${errors_json},\"warnings\":${warnings_json},\"files\":${files_json}}"
else
  if [[ "$SAFE" == "true" ]]; then
    echo -e "${GREEN}✅ Move is safe${NC}"
  else
    echo -e "${RED}❌ Move is blocked${NC}"
  fi

  echo -e "├── Feature: ${FEATURE}"
  echo -e "├── From:    ${OLD_DOMAIN}/${OLD_SERVICE}"
  echo -e "├── To:      ${NEW_DOMAIN}/${NEW_SERVICE}"

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "├── Errors:"
    for err in "${ERRORS[@]}"; do
      echo -e "│   ❌ ${err}"
    done
  fi

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "├── Warnings:"
    for warn in "${WARNINGS[@]}"; do
      echo -e "│   ⚠ ${warn}"
    done
  fi

  echo -e "└── Files: ${#FILES_TO_MOVE[@]} to relocate"
fi

[[ "$SAFE" == "true" ]] && exit 0 || exit 1
