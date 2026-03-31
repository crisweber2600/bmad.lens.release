#!/usr/bin/env bash
# =============================================================================
# LENS Workbench v3 — Control Repo Setup
#
# PURPOSE:
#   Bootstraps a new control repo by cloning all required authority domains:
#   - bmad.lens.release   → Release module (read-only dependency)
#   - bmad.lens.copilot   → Copilot adapter (.github/ content)
#   - lens-governance     → Governance repo (constitutional authority)
#
#   Safe to re-run: pulls latest if repos already exist.
#
# USAGE:
#   ./setup-control-repo.sh --org <github-org-or-user>
#   ./setup-control-repo.sh --org weberbot --release-repo my-release --copilot-repo my-copilot
#   ./setup-control-repo.sh --release-org myorg --copilot-org otherorg --governance-org governance-team
#   ./setup-control-repo.sh --org weberbot --base-url https://github.company.com
#   ./setup-control-repo.sh --help
#
# OPTIONS:
#   --org <name>               Default GitHub org/user for all repos (falls back if specific org not set)
#   --release-org <name>       Release repo owner (default: uses --org)
#   --release-repo <name>      Release repo name (default: bmad.lens.release)
#   --release-branch <name>    Release repo branch (default: beta)
#   --copilot-org <name>       Copilot repo owner (default: uses --org)
#   --copilot-repo <name>      Copilot repo name (default: bmad.lens.copilot)
#   --copilot-branch <name>    Copilot repo branch (default: beta)
#   --governance-org <name>    Governance repo owner (default: uses --org)
#   --governance-repo <name>   Governance repo name (default: lens-governance)
#   --governance-branch <name> Governance repo branch (default: main)
#   --governance-path <path>   Local path for governance repo clone (default: TargetProjects/lens/lens-governance)
#   --base-url <url>           Git base URL (default: https://github.com) - supports enterprise GitHub
#   --dry-run                  Show what would be done without making changes
#   -h, --help                 Show this help message
#
# =============================================================================

set -euo pipefail

# -- Colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# -- Defaults ---------------------------------------------------------------
ORG=""
RELEASE_ORG=""
RELEASE_REPO="bmad.lens.release"
RELEASE_BRANCH="beta"
COPILOT_ORG=""
COPILOT_REPO="bmad.lens.copilot"
COPILOT_BRANCH="beta"
GOVERNANCE_ORG=""
GOVERNANCE_REPO="lens-governance"
GOVERNANCE_BRANCH="main"
GOVERNANCE_PATH="TargetProjects/lens/lens-governance"
BASE_URL="https://github.com"
DRY_RUN=false

# -- Project root (prefer git to avoid cwd-dependent behavior) -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if GIT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  PROJECT_ROOT="$GIT_ROOT"
else
  # Fallback: this script lives at _bmad/lens-work/scripts/
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# -- Parse Arguments --------------------------------------------------------
show_help() {
  sed -n '2,/^# =/p' "$0" | sed 's/^# //'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)
      shift
      ORG="$1"
      ;;
    --release-org)
      shift
      RELEASE_ORG="$1"
      ;;
    --release-repo)
      shift
      RELEASE_REPO="$1"
      ;;
    --release-branch)
      shift
      RELEASE_BRANCH="$1"
      ;;
    --copilot-org)
      shift
      COPILOT_ORG="$1"
      ;;
    --copilot-repo)
      shift
      COPILOT_REPO="$1"
      ;;
    --copilot-branch)
      shift
      COPILOT_BRANCH="$1"
      ;;
    --governance-org)
      shift
      GOVERNANCE_ORG="$1"
      ;;
    --governance-repo)
      shift
      GOVERNANCE_REPO="$1"
      ;;
    --governance-branch)
      shift
      GOVERNANCE_BRANCH="$1"
      ;;
    --governance-path)
      shift
      GOVERNANCE_PATH="$1"
      ;;
    --base-url)
      shift
      BASE_URL="$1"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"
      show_help
      exit 1
      ;;
  esac
  shift
done

# -- Validate required args --------------------------------------------------
if [[ -z "$ORG" && -z "$RELEASE_ORG" && -z "$COPILOT_ORG" && -z "$GOVERNANCE_ORG" ]]; then
  echo -e "${RED}Error: --org is required (or specify --release-org, --copilot-org, --governance-org individually)${RESET}"
  echo ""
  show_help
  exit 1
fi

# -- Apply fallbacks ---------------------------------------------------------
RELEASE_ORG="${RELEASE_ORG:-$ORG}"
COPILOT_ORG="${COPILOT_ORG:-$ORG}"
GOVERNANCE_ORG="${GOVERNANCE_ORG:-$ORG}"

# -- Helper Functions -------------------------------------------------------
log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${RESET}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err()  { echo -e "${RED}[ERR]${RESET}  $1"; }

clone_or_pull() {
  local remote_url="$1"
  local local_path="$2"
  local branch="$3"
  local repo_label="$4"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -d "$local_path/.git" ]]; then
      log_info "[DRY-RUN] Would pull latest for ${repo_label} at ${local_path} (branch: ${branch})"
    else
      log_info "[DRY-RUN] Would clone ${repo_label} → ${local_path} (branch: ${branch})"
    fi
    return
  fi

  if [[ -d "$local_path/.git" ]]; then
    log_info "Pulling latest for ${repo_label} (${local_path})..."
    (
      cd "$local_path"
      git fetch origin
      git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch"
      git pull origin "$branch"
    )
    log_ok "${repo_label} updated (branch: ${branch})"
  else
    log_info "Cloning ${repo_label} → ${local_path} (branch: ${branch})..."
    mkdir -p "$(dirname "$local_path")"
    git clone --branch "$branch" "$remote_url" "$local_path"
    log_ok "${repo_label} cloned (branch: ${branch})"
  fi
}

ensure_gitignore_entries() {
  local gitignore_file="${PROJECT_ROOT}/.gitignore"
  local entries=(
    "_bmad-output/lens-work/personal/"
    ".github/"
    "bmad.lens.release/"
    "TargetProjects/"
  )

  local added_count=0

  if [[ ! -f "$gitignore_file" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY-RUN] Would create ${gitignore_file}"
    else
      : > "$gitignore_file"
      log_info "Created ${gitignore_file}"
    fi
  fi

  for entry in "${entries[@]}"; do
    if [[ -f "$gitignore_file" ]] && grep -Fxq "$entry" "$gitignore_file"; then
      continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY-RUN] Would add '${entry}' to .gitignore"
    else
      printf '%s\n' "$entry" >> "$gitignore_file"
      added_count=$((added_count + 1))
      log_info "Added '${entry}' to .gitignore"
    fi
  done

  if [[ "$DRY_RUN" != true ]]; then
    if [[ "$added_count" -eq 0 ]]; then
      log_ok ".gitignore already contains required entries"
    else
      log_ok ".gitignore updated with required entries"
    fi
  fi
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo -e "${BOLD}LENS Workbench v3 — Control Repo Setup${RESET}"
echo -e "${DIM}Base URL: ${BASE_URL}${RESET}"
echo -e "${DIM}Root:     ${PROJECT_ROOT}${RESET}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  log_warn "Dry run mode: no changes will be made"
  echo ""
fi

# -- 1. Release Repo --------------------------------------------------------
RELEASE_URL="${BASE_URL}/${RELEASE_ORG}/${RELEASE_REPO}.git"
RELEASE_PATH="${PROJECT_ROOT}/${RELEASE_REPO}"
clone_or_pull "$RELEASE_URL" "$RELEASE_PATH" "$RELEASE_BRANCH" "${RELEASE_ORG}/${RELEASE_REPO}"

# -- 2. Copilot Adapter Repo ------------------------------------------------
COPILOT_URL="${BASE_URL}/${COPILOT_ORG}/${COPILOT_REPO}.git"
COPILOT_PATH="${PROJECT_ROOT}/.github"
clone_or_pull "$COPILOT_URL" "$COPILOT_PATH" "$COPILOT_BRANCH" "${COPILOT_ORG}/${COPILOT_REPO} (.github)"

# -- 3. Governance Repo -----------------------------------------------------
GOVERNANCE_URL="${BASE_URL}/${GOVERNANCE_ORG}/${GOVERNANCE_REPO}.git"
GOVERNANCE_FULL_PATH="${PROJECT_ROOT}/${GOVERNANCE_PATH}"
clone_or_pull "$GOVERNANCE_URL" "$GOVERNANCE_FULL_PATH" "$GOVERNANCE_BRANCH" "${GOVERNANCE_ORG}/${GOVERNANCE_REPO}"

# -- 4. Output directories --------------------------------------------------
if [[ "$DRY_RUN" != true ]]; then
  mkdir -p "${PROJECT_ROOT}/_bmad-output/lens-work/initiatives"
  mkdir -p "${PROJECT_ROOT}/_bmad-output/lens-work/personal"
  log_ok "Output directory structure verified"
else
  log_info "[DRY-RUN] Would create _bmad-output/lens-work/ directories"
fi

# -- 5. Write LENS_VERSION ---------------------------------------------------
if [[ "$DRY_RUN" != true ]]; then
  SCHEMA_VERSION=$(grep '^schema_version:' "${RELEASE_PATH}/_bmad/lens-work/lifecycle.yaml" | awk '{print $2}')

  # Validate that SCHEMA_VERSION was successfully parsed and is numeric
  if [[ -z "${SCHEMA_VERSION:-}" ]]; then
    log_error "Failed to determine schema_version from ${RELEASE_PATH}/_bmad/lens-work/lifecycle.yaml"
    exit 1
  fi

  if ! [[ "${SCHEMA_VERSION}" =~ ^[0-9]+$ ]]; then
    log_error "Invalid schema_version '${SCHEMA_VERSION}' in ${RELEASE_PATH}/_bmad/lens-work/lifecycle.yaml (expected numeric)"
    exit 1
  fi

  printf '%s.0.0\n' "${SCHEMA_VERSION}" > "${PROJECT_ROOT}/LENS_VERSION"
  log_ok "LENS_VERSION written: ${SCHEMA_VERSION}.0.0"
else
  log_info "[DRY-RUN] Would write LENS_VERSION"
fi

# -- 6. Ensure .gitignore entries -------------------------------------------
ensure_gitignore_entries

# -- Summary ----------------------------------------------------------------
echo ""
echo -e "${BOLD}Setup Complete${RESET}"
echo ""
echo -e "  ${GREEN}${RELEASE_ORG}/${RELEASE_REPO}${RESET} → ${RELEASE_REPO}/    (branch: ${RELEASE_BRANCH})"
echo -e "  ${GREEN}${COPILOT_ORG}/${COPILOT_REPO}${RESET} → .github/               (branch: ${COPILOT_BRANCH})"
echo -e "  ${GREEN}${GOVERNANCE_ORG}/${GOVERNANCE_REPO}${RESET} → ${GOVERNANCE_PATH}/  (branch: ${GOVERNANCE_BRANCH})"
echo ""
echo -e "GitHub Copilot adapter is already installed via the copilot repo (.github/)."
echo -e "No further setup is needed if GitHub Copilot is your only IDE."
echo ""
echo -e "For non-Copilot IDEs (cursor, claude, codex), run the module installer:"
echo -e "  ${CYAN}./_bmad/lens-work/scripts/install.sh --ide cursor${RESET}"
echo -e "  ${CYAN}./_bmad/lens-work/scripts/install.sh --all-ides${RESET}"
echo ""
