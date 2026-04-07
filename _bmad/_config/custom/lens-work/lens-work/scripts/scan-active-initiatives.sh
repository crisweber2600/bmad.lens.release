#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Scan Active Initiatives
#
# PURPOSE:
#   Discover active initiatives by scanning committed initiative-state.yaml
#   files under _bmad-output/lens-work/initiatives/. Replaces per-session
#   agent reasoning with deterministic file enumeration.
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/scan-active-initiatives.sh
#   ./lens.core/_bmad/lens-work/scripts/scan-active-initiatives.sh --domain foo
#   ./lens.core/_bmad/lens-work/scripts/scan-active-initiatives.sh --json
#
# OPTIONS:
#   --domain <name>   Filter initiatives by domain
#   --json            Output JSON instead of human-readable table
#   -h, --help        Show this help message
#
# EXIT CODES:
#   0  Success (initiatives found or empty state reported)
#   1  Error (missing directory, parse failure)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
INITIATIVES_DIR="${PROJECT_ROOT}/_bmad-output/lens-work/initiatives"

# -- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# -- Defaults ----------------------------------------------------------------
DOMAIN_FILTER=""
JSON_OUTPUT=false

# -- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN_FILTER="$2"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    -h|--help)
      sed -n '2,/^# =====/{ /^# =====/d; s/^# \?//; p }' "$0"
      exit 0
      ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; exit 1 ;;
  esac
done

cd "$PROJECT_ROOT"

# =============================================================================
# Discover initiative-state.yaml files
# =============================================================================

if [[ ! -d "$INITIATIVES_DIR" ]]; then
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo '{"initiatives":[],"count":0,"empty":true}'
  else
    echo -e "${CYAN}ℹ️  No initiatives directory found.${NC}"
    echo ""
    echo "  Get started:"
    echo "  - /new-domain {name}      — Create a domain-level initiative"
    echo "  - /new-service {d}/{s}    — Create a service-level initiative"
    echo "  - /new-feature {d}/{s}/{f} — Create a feature-level initiative"
  fi
  exit 0
fi

# Find all initiative-state.yaml files
STATE_FILES=()
while IFS= read -r -d '' file; do
  STATE_FILES+=("$file")
done < <(find "$INITIATIVES_DIR" -name "initiative-state.yaml" -print0 2>/dev/null)

if [[ ${#STATE_FILES[@]} -eq 0 ]]; then
  # Fall back: check for initiative config files (*.yaml) that aren't initiative-state.yaml
  CONFIG_FILES=()
  while IFS= read -r -d '' file; do
    CONFIG_FILES+=("$file")
  done < <(find "$INITIATIVES_DIR" -name "*.yaml" ! -name "initiative-state.yaml" -print0 2>/dev/null)

  if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
    if [[ "$JSON_OUTPUT" == "true" ]]; then
      echo '{"initiatives":[],"count":0,"empty":true}'
    else
      echo -e "${CYAN}ℹ️  No active initiatives.${NC}"
      echo ""
      echo "  Get started:"
      echo "  - /new-domain {name}      — Create a domain-level initiative"
      echo "  - /new-service {d}/{s}    — Create a service-level initiative"
      echo "  - /new-feature {d}/{s}/{f} — Create a feature-level initiative"
    fi
    exit 0
  fi
fi

# =============================================================================
# Parse each initiative-state.yaml
# =============================================================================

INITIATIVES=()
JSON_ENTRIES=()

for state_file in "${STATE_FILES[@]}"; do
  # Extract path relative to initiatives dir
  rel_path="${state_file#"$INITIATIVES_DIR/"}"

  # Derive domain/service/feature from directory structure
  dir_path="$(dirname "$rel_path")"
  IFS='/' read -ra segments <<< "$dir_path"

  domain="${segments[0]:-}"
  service=""
  feature=""
  scope="domain"

  if [[ ${#segments[@]} -ge 3 ]]; then
    service="${segments[1]}"
    feature="${segments[2]}"
    scope="feature"
  elif [[ ${#segments[@]} -ge 2 ]]; then
    service="${segments[1]}"
    scope="service"
  fi

  # Apply domain filter
  if [[ -n "$DOMAIN_FILTER" && "$domain" != "$DOMAIN_FILTER" ]]; then
    continue
  fi

  # Read lifecycle_status from the state file
  lifecycle_status=$(grep -m1 '^lifecycle_status:' "$state_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "unknown")

  # Read initiative_root
  init_root=$(grep -m1 '^initiative_root:' "$state_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
  if [[ -z "$init_root" ]]; then
    # Derive from path segments
    if [[ "$scope" == "feature" ]]; then
      init_root="${domain}-${service}-${feature}"
    elif [[ "$scope" == "service" ]]; then
      init_root="${domain}-${service}"
    else
      init_root="${domain}"
    fi
  fi

  # Read track
  track=$(grep -m1 '^track:' "$state_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")

  # Only include active initiatives
  if [[ "$lifecycle_status" != "active" && "$lifecycle_status" != "unknown" ]]; then
    continue
  fi

  INITIATIVES+=("${init_root}|${domain}|${service}|${scope}|${track}")

  if [[ "$JSON_OUTPUT" == "true" ]]; then
    svc_json="null"
    [[ -n "$service" ]] && svc_json="\"${service}\""
    JSON_ENTRIES+=("{\"root\":\"${init_root}\",\"domain\":\"${domain}\",\"service\":${svc_json},\"scope\":\"${scope}\",\"track\":\"${track}\"}")
  fi
done

# =============================================================================
# Output
# =============================================================================

if [[ ${#INITIATIVES[@]} -eq 0 ]]; then
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo '{"initiatives":[],"count":0,"empty":true}'
  else
    echo -e "${CYAN}ℹ️  No active initiatives.${NC}"
    echo ""
    echo "  Get started:"
    echo "  - /new-domain {name}      — Create a domain-level initiative"
    echo "  - /new-service {d}/{s}    — Create a service-level initiative"
    echo "  - /new-feature {d}/{s}/{f} — Create a feature-level initiative"
  fi
  exit 0
fi

if [[ "$JSON_OUTPUT" == "true" ]]; then
  joined=$(printf ",%s" "${JSON_ENTRIES[@]}")
  joined="${joined:1}"
  echo "{\"initiatives\":[${joined}],\"count\":${#INITIATIVES[@]},\"empty\":false}"
else
  echo -e "${GREEN}✅ Initiative inventory complete${NC}"
  echo -e "├── Initiative roots: ${#INITIATIVES[@]}"
  echo ""
  printf "  %-25s %-12s %-12s %-10s %s\n" "ROOT" "DOMAIN" "SERVICE" "SCOPE" "TRACK"
  printf "  %-25s %-12s %-12s %-10s %s\n" "────" "──────" "───────" "─────" "─────"
  for entry in "${INITIATIVES[@]}"; do
    IFS='|' read -r root domain service scope track <<< "$entry"
    printf "  %-25s %-12s %-12s %-10s %s\n" "$root" "$domain" "${service:--}" "$scope" "${track:--}"
  done
fi
