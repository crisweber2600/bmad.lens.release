#!/usr/bin/env bash
# =============================================================================
# LENS Workbench v3 — Control Repo Setup
#
# PURPOSE:
#   Bootstraps a new control repo by cloning all required authority domains:
#   - bmad.lens.release   → Release module (read-only dependency)
#   - .github             → Copied from bmad.lens.release/.github
#   - governance repo     → Governance repo (constitutional authority)
#
#   Safe to re-run: pulls latest if repos already exist.
#
# USAGE:
#   Interactive wizard (recommended for first-time setup):
#     ./setup-control-repo.sh
#
#   Parameter mode (for scripting/CI):
#     ./setup-control-repo.sh --org <github-org-or-user>
#     ./setup-control-repo.sh --org weberbot --release-repo my-release
#     ./setup-control-repo.sh --release-org myorg --governance-org governance-team
#     ./setup-control-repo.sh --org weberbot --base-url https://github.company.com
#     ./setup-control-repo.sh --help
#
# OPTIONS:
#   --control-dir <path>       Directory to set up as the control repo (default: current git root or script location)
#   --org <name>               Default GitHub org/user for all repos (falls back if specific org not set)
#   --release-org <name>       Release repo owner (default: uses --org)
#   --release-repo <name>      Release repo name (default: bmad.lens.release)
#   --release-branch <name>    Release repo branch (default: beta)
#   --governance-org <name>    Governance repo owner (default: uses --org)
#   --governance-repo <name>   Governance repo name (default: auto-derived from control repo name)
#   --governance-branch <name> Governance repo branch (default: main)
#   --governance-path <path>   Local path for governance repo clone (default: auto-derived)
#   --base-url <url>           Git base URL (default: https://github.com) - supports enterprise GitHub
#   --dry-run                  Show what would be done without making changes
#   -h, --help                 Show this help message
#
# When run with no arguments, the script enters an interactive wizard that
# auto-detects your environment and guides you through configuration.
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
GOVERNANCE_ORG=""
GOVERNANCE_REPO=""
GOVERNANCE_BRANCH="main"
GOVERNANCE_PATH=""
BASE_URL="https://github.com"
CONTROL_DIR=""
DRY_RUN=false
WIZARD_MODE=false
HAS_PARAM_ARGS=false
GOVERNANCE_REPO_EXPLICIT=false
GOVERNANCE_PATH_EXPLICIT=false

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
    --control-dir)
      shift
      CONTROL_DIR="$1"
      HAS_PARAM_ARGS=true
      ;;
    --org)
      shift
      ORG="$1"
      HAS_PARAM_ARGS=true
      ;;
    --release-org)
      shift
      RELEASE_ORG="$1"
      HAS_PARAM_ARGS=true
      ;;
    --release-repo)
      shift
      RELEASE_REPO="$1"
      HAS_PARAM_ARGS=true
      ;;
    --release-branch)
      shift
      RELEASE_BRANCH="$1"
      HAS_PARAM_ARGS=true
      ;;
    --governance-org)
      shift
      GOVERNANCE_ORG="$1"
      HAS_PARAM_ARGS=true
      ;;
    --governance-repo)
      shift
      GOVERNANCE_REPO="$1"
      GOVERNANCE_REPO_EXPLICIT=true
      HAS_PARAM_ARGS=true
      ;;
    --governance-branch)
      shift
      GOVERNANCE_BRANCH="$1"
      HAS_PARAM_ARGS=true
      ;;
    --governance-path)
      shift
      GOVERNANCE_PATH="$1"
      GOVERNANCE_PATH_EXPLICIT=true
      HAS_PARAM_ARGS=true
      ;;
    --base-url)
      shift
      BASE_URL="$1"
      HAS_PARAM_ARGS=true
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

# -- Apply --control-dir override if provided --------------------------------
if [[ -n "$CONTROL_DIR" ]]; then
  # Resolve to absolute path
  if [[ ! "$CONTROL_DIR" = /* ]]; then
    CONTROL_DIR="$(cd "$(pwd)" && cd "$CONTROL_DIR" 2>/dev/null && pwd)" || CONTROL_DIR="$(pwd)/$CONTROL_DIR"
  fi
  PROJECT_ROOT="$CONTROL_DIR"
fi

# -- Derive governance defaults from control repo name ----------------------
CONTROL_REPO_NAME="$(basename "$PROJECT_ROOT")"
DERIVED_CONTROL_NAME="$CONTROL_REPO_NAME"
if [[ "$DERIVED_CONTROL_NAME" =~ \.src$ ]]; then
  DERIVED_CONTROL_NAME="${DERIVED_CONTROL_NAME%.src}.bmad"
fi

if [[ "$GOVERNANCE_REPO_EXPLICIT" != true && -z "$GOVERNANCE_REPO" ]]; then
  GOVERNANCE_REPO="${DERIVED_CONTROL_NAME}.governance"
fi
if [[ "$GOVERNANCE_PATH_EXPLICIT" != true && -z "$GOVERNANCE_PATH" ]]; then
  GOVERNANCE_PATH="TargetProjects/lens/${GOVERNANCE_REPO}"
fi

# -- Helper Functions -------------------------------------------------------
log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${RESET}   $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err()  { echo -e "${RED}[ERR]${RESET}  $1"; }

prompt_with_default() {
  local prompt_text="$1"
  local default_val="$2"
  local var_name="$3"
  local input
  echo -en "  ${prompt_text} ${DIM}[${default_val}]${RESET}: "
  read -r input
  if [[ -z "$input" ]]; then
    eval "$var_name=\"$default_val\""
  else
    eval "$var_name=\"$input\""
  fi
}

prompt_yes_no() {
  local prompt_text="$1"
  local default_val="${2:-y}"
  local input
  if [[ "$default_val" == "y" ]]; then
    echo -en "  ${prompt_text} ${DIM}[Y/n]${RESET}: "
  else
    echo -en "  ${prompt_text} ${DIM}[y/N]${RESET}: "
  fi
  read -r input
  input="${input:-$default_val}"
  [[ "$input" =~ ^[yY] ]]
}

detect_github_username() {
  # Try gh CLI first
  if command -v gh &>/dev/null; then
    local gh_user
    gh_user="$(gh api user --jq '.login' 2>/dev/null || true)"
    if [[ -n "$gh_user" ]]; then
      echo "$gh_user"
      return
    fi
  fi
  # Try git config
  local git_user
  git_user="$(git config user.name 2>/dev/null || true)"
  if [[ -n "$git_user" ]]; then
    echo "$git_user"
    return
  fi
  echo ""
}

clone_or_pull() {
  local remote_url="$1"
  local local_path="$2"
  local branch="$3"
  local repo_label="$4"

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -d "$local_path/.git" ]]; then
      log_info "[DRY-RUN] Would pull latest for ${repo_label} at ${local_path} (branch: ${branch})"
    elif [[ -d "$local_path" ]]; then
      log_info "[DRY-RUN] Would replace existing path and clone ${repo_label} → ${local_path} (branch: ${branch})"
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
    if [[ -d "$local_path" ]]; then
      log_warn "${repo_label} target exists and is not a git repo. Replacing ${local_path}"
      rm -rf "$local_path"
    fi
    log_info "Cloning ${repo_label} → ${local_path} (branch: ${branch})..."
    mkdir -p "$(dirname "$local_path")"
    git clone --branch "$branch" "$remote_url" "$local_path"
    log_ok "${repo_label} cloned (branch: ${branch})"
  fi
}

sync_github_from_release() {
  local release_path="$1"
  local dest_path="$2"
  local source_label="$3"
  local source_github="${release_path}/.github"

  if [[ ! -d "$source_github" ]]; then
    log_err "Missing source .github at ${source_github}"
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -d "$dest_path/.git" ]]; then
      log_info "[DRY-RUN] Would remove existing .github git repo at ${dest_path}"
    elif [[ -d "$dest_path" ]]; then
      log_info "[DRY-RUN] Would replace existing .github at ${dest_path}"
    else
      log_info "[DRY-RUN] Would create .github at ${dest_path}"
    fi
    log_info "[DRY-RUN] Would copy .github from ${source_label}"
    return
  fi

  if [[ -d "$dest_path/.git" ]]; then
    log_warn ".github is a git repo in control repo. Removing before copy"
  elif [[ -d "$dest_path" ]]; then
    log_info "Replacing existing .github at ${dest_path}"
  fi

  if [[ -d "$dest_path" ]]; then
    rm -rf "$dest_path"
  fi

  mkdir -p "$dest_path"
  cp -rf "$source_github/"* "$dest_path/" 2>/dev/null || true
  # Also copy hidden files
  cp -rf "$source_github/".* "$dest_path/" 2>/dev/null || true
  log_ok ".github copied from ${source_label}"
}

ensure_github_repo_exists() {
  local base_url="$1"
  local owner="$2"
  local repo="$3"
  local remote_url="$4"
  local repo_full="${owner}/${repo}"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY-RUN] Would verify ${repo_full} exists"
    log_info "[DRY-RUN] Would create private repository ${repo_full} if missing"
    return
  fi

  if git ls-remote "$remote_url" HEAD &>/dev/null; then
    log_info "${repo_full} is available"
    return
  fi

  log_warn "${repo_full} is missing or inaccessible. Attempting to create it as a private repository."

  if ! command -v gh &>/dev/null; then
    log_err "GitHub CLI (gh) is required to auto-create ${repo_full}. Install gh or create the repo manually."
    exit 1
  fi

  local previous_gh_host="${GH_HOST:-}"
  local base_host
  base_host="$(echo "$base_url" | sed -E 's|https?://||' | sed 's|/.*||')"
  if [[ "$base_host" != "github.com" ]]; then
    export GH_HOST="$base_host"
    log_info "Using GitHub host ${base_host} for repository creation"
  else
    unset GH_HOST 2>/dev/null || true
  fi

  if ! gh repo create "$repo_full" --private --add-readme --description "LENS governance repository" --disable-issues; then
    log_err "Failed to create private repository ${repo_full}"
    if [[ -n "$previous_gh_host" ]]; then export GH_HOST="$previous_gh_host"; else unset GH_HOST 2>/dev/null || true; fi
    exit 1
  fi

  log_ok "Created private repository ${repo_full}"

  if [[ -n "$previous_gh_host" ]]; then export GH_HOST="$previous_gh_host"; else unset GH_HOST 2>/dev/null || true; fi

  if ! git ls-remote "$remote_url" HEAD &>/dev/null; then
    log_err "Repository ${repo_full} was created but is still not reachable at ${remote_url}"
    exit 1
  fi
}

resolve_clone_branch() {
  local remote_url="$1"
  local preferred_branch="$2"
  local repo_label="$3"

  if [[ "$DRY_RUN" == true ]]; then
    echo "$preferred_branch"
    return
  fi

  if git ls-remote --heads "$remote_url" "$preferred_branch" 2>/dev/null | grep -q .; then
    echo "$preferred_branch"
    return
  fi

  local head_ref
  head_ref="$(git ls-remote --symref "$remote_url" HEAD 2>/dev/null | grep 'ref: refs/heads/' | head -1 || true)"
  if [[ -z "$head_ref" ]]; then
    log_err "Unable to resolve default branch for ${repo_label}"
    exit 1
  fi

  local default_branch
  default_branch="$(echo "$head_ref" | sed -E 's|.*refs/heads/([^\t ]+).*|\1|')"
  if [[ -z "$default_branch" ]]; then
    log_err "Unable to parse default branch for ${repo_label}"
    exit 1
  fi

  log_warn "${repo_label} does not have branch '${preferred_branch}'. Using default branch '${default_branch}' instead."
  echo "$default_branch"
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
# WIZARD MODE
# =============================================================================

run_wizard() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║       LENS Workbench v3 — Control Repo Setup Wizard        ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  This wizard will bootstrap your control repo by:"
  echo -e "    ${CYAN}1.${RESET} Cloning the LENS release module (read-only)"
  echo -e "    ${CYAN}2.${RESET} Copying the GitHub Copilot adapter (.github/)"
  echo -e "    ${CYAN}3.${RESET} Cloning (or creating) your governance repo"
  echo -e "    ${CYAN}4.${RESET} Setting up output directories and LENS_VERSION"
  echo ""
  echo -e "  ${DIM}Press Enter to accept defaults shown in [brackets].${RESET}"
  echo ""

  # -- Control Repo Directory ------------------------------------------------
  echo -e "${BOLD}Step 1: Control Repo Directory${RESET}"
  echo ""
  echo -e "  ${DIM}The directory where your control repo will be set up.${RESET}"
  local wizard_dir
  prompt_with_default "Control repo directory" "$PROJECT_ROOT" wizard_dir
  if [[ -n "$wizard_dir" && "$wizard_dir" != "$PROJECT_ROOT" ]]; then
    # Resolve to absolute path
    if [[ ! "$wizard_dir" = /* ]]; then
      wizard_dir="$(cd "$(pwd)" && cd "$wizard_dir" 2>/dev/null && pwd)" || wizard_dir="$(pwd)/$wizard_dir"
    fi
    PROJECT_ROOT="$wizard_dir"
    # Re-derive governance defaults from new directory
    CONTROL_REPO_NAME="$(basename "$PROJECT_ROOT")"
    DERIVED_CONTROL_NAME="$CONTROL_REPO_NAME"
    if [[ "$DERIVED_CONTROL_NAME" =~ \.src$ ]]; then
      DERIVED_CONTROL_NAME="${DERIVED_CONTROL_NAME%.src}.bmad"
    fi
    GOVERNANCE_REPO="${DERIVED_CONTROL_NAME}.governance"
    GOVERNANCE_PATH="TargetProjects/lens/${GOVERNANCE_REPO}"
  fi
  echo ""

  # -- Detect environment ---------------------------------------------------
  echo -e "${BOLD}Step 2: GitHub Account${RESET}"
  echo ""

  local detected_user
  detected_user="$(detect_github_username)"
  if [[ -n "$detected_user" ]]; then
    echo -e "  ${DIM}Detected: ${detected_user}${RESET}"
  fi

  local wizard_org
  prompt_with_default "GitHub org or username" "${detected_user:-your-username}" wizard_org
  ORG="$wizard_org"
  echo ""

  # -- Base URL -------------------------------------------------------------
  echo -e "${BOLD}Step 3: GitHub Server${RESET}"
  echo ""
  if prompt_yes_no "Use github.com?" "y"; then
    BASE_URL="https://github.com"
  else
    prompt_with_default "Enterprise GitHub URL" "https://github.company.com" BASE_URL
  fi
  echo ""

  # -- Release Repo ---------------------------------------------------------
  echo -e "${BOLD}Step 4: Release Repository${RESET}"
  echo ""
  echo -e "  ${DIM}The release repo contains the LENS module (read-only dependency).${RESET}"
  prompt_with_default "Release repo name" "$RELEASE_REPO" RELEASE_REPO
  prompt_with_default "Release repo branch" "$RELEASE_BRANCH" RELEASE_BRANCH
  local wizard_release_org
  prompt_with_default "Release repo owner" "$ORG" wizard_release_org
  RELEASE_ORG="$wizard_release_org"
  echo ""

  # -- Governance Repo ------------------------------------------------------
  echo -e "${BOLD}Step 5: Governance Repository${RESET}"
  echo ""
  echo -e "  ${DIM}The governance repo holds constitutional rules for your organization.${RESET}"
  echo -e "  ${DIM}Auto-derived from control repo name: ${GOVERNANCE_REPO}${RESET}"

  prompt_with_default "Governance repo name" "$GOVERNANCE_REPO" GOVERNANCE_REPO
  prompt_with_default "Governance repo branch" "$GOVERNANCE_BRANCH" GOVERNANCE_BRANCH
  local wizard_gov_org
  prompt_with_default "Governance repo owner" "$ORG" wizard_gov_org
  GOVERNANCE_ORG="$wizard_gov_org"

  # Re-derive path if governance repo name changed
  GOVERNANCE_PATH="TargetProjects/lens/${GOVERNANCE_REPO}"
  prompt_with_default "Local clone path" "$GOVERNANCE_PATH" GOVERNANCE_PATH
  echo ""

  # -- Dry run option -------------------------------------------------------
  echo -e "${BOLD}Step 6: Review & Confirm${RESET}"
  echo ""
  echo -e "  ${BOLD}Configuration summary:${RESET}"
  echo ""
  echo -e "    Base URL:         ${CYAN}${BASE_URL}${RESET}"
  echo -e "    Control repo:     ${CYAN}${PROJECT_ROOT}${RESET}"
  echo ""
  echo -e "    Release repo:     ${GREEN}${RELEASE_ORG}/${RELEASE_REPO}${RESET} (branch: ${RELEASE_BRANCH})"
  echo -e "      → clone to:     ${DIM}${RELEASE_REPO}/${RESET}"
  echo -e "      → .github:      ${DIM}copied from release repo${RESET}"
  echo ""
  echo -e "    Governance repo:  ${GREEN}${GOVERNANCE_ORG}/${GOVERNANCE_REPO}${RESET} (branch: ${GOVERNANCE_BRANCH})"
  echo -e "      → clone to:     ${DIM}${GOVERNANCE_PATH}/${RESET}"
  echo ""

  if ! prompt_yes_no "Proceed with setup?" "y"; then
    echo ""
    echo -e "  ${YELLOW}Setup cancelled.${RESET}"
    exit 0
  fi
  echo ""
}

# =============================================================================
# DETERMINE MODE
# =============================================================================

if [[ "$HAS_PARAM_ARGS" != true ]]; then
  # No org/repo params passed — enter wizard mode
  WIZARD_MODE=true
  run_wizard
else
  # Validate that we have enough info in parameter mode
  if [[ -z "$ORG" && -z "$RELEASE_ORG" && -z "$GOVERNANCE_ORG" ]]; then
    echo -e "${RED}Error: --org is required (or specify --release-org, --governance-org individually)${RESET}"
    echo ""
    show_help
    exit 1
  fi
fi

# -- Apply fallbacks ---------------------------------------------------------
RELEASE_ORG="${RELEASE_ORG:-$ORG}"
GOVERNANCE_ORG="${GOVERNANCE_ORG:-$ORG}"

# =============================================================================
# MAIN EXECUTION
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

# -- 2. Sync .github from Release Repo --------------------------------------
COPILOT_PATH="${PROJECT_ROOT}/.github"
sync_github_from_release "$RELEASE_PATH" "$COPILOT_PATH" "${RELEASE_ORG}/${RELEASE_REPO}/.github"

# -- 3. Governance Repo -----------------------------------------------------
GOVERNANCE_URL="${BASE_URL}/${GOVERNANCE_ORG}/${GOVERNANCE_REPO}.git"
GOVERNANCE_FULL_PATH="${PROJECT_ROOT}/${GOVERNANCE_PATH}"
ensure_github_repo_exists "$BASE_URL" "$GOVERNANCE_ORG" "$GOVERNANCE_REPO" "$GOVERNANCE_URL"
GOVERNANCE_CLONE_BRANCH="$(resolve_clone_branch "$GOVERNANCE_URL" "$GOVERNANCE_BRANCH" "${GOVERNANCE_ORG}/${GOVERNANCE_REPO}")"
clone_or_pull "$GOVERNANCE_URL" "$GOVERNANCE_FULL_PATH" "$GOVERNANCE_CLONE_BRANCH" "${GOVERNANCE_ORG}/${GOVERNANCE_REPO}"

# -- 4. Output directories --------------------------------------------------
if [[ "$DRY_RUN" != true ]]; then
  mkdir -p "${PROJECT_ROOT}/_bmad-output/lens-work/initiatives"
  mkdir -p "${PROJECT_ROOT}/_bmad-output/lens-work/personal"
  log_ok "Output directory structure verified"
else
  log_info "[DRY-RUN] Would create _bmad-output/lens-work/ directories"
fi

# -- 4b. Write governance-setup.yaml ----------------------------------------
GOVERNANCE_SETUP_PATH="${PROJECT_ROOT}/_bmad-output/lens-work/governance-setup.yaml"
if [[ "$DRY_RUN" != true ]]; then
  cat > "$GOVERNANCE_SETUP_PATH" <<GSEOF
# Generated by setup-control-repo.sh — $(date -u +"%Y-%m-%dT%H:%M:%SZ")
governance_repo_path: "${GOVERNANCE_PATH}"
governance_remote_url: "${GOVERNANCE_URL}"
GSEOF
  log_ok "governance-setup.yaml written"
else
  log_info "[DRY-RUN] Would write governance-setup.yaml"
fi

# -- 5. Write LENS_VERSION ---------------------------------------------------
if [[ "$DRY_RUN" != true ]]; then
  LIFECYCLE_PATH="${RELEASE_PATH}/_bmad/lens-work/lifecycle.yaml"
  if [[ ! -f "$LIFECYCLE_PATH" ]]; then
    log_err "Unable to write LENS_VERSION: lifecycle file not found at '${LIFECYCLE_PATH}'"
    exit 1
  fi

  SCHEMA_VERSION=$(grep '^\s*schema_version\s*:' "$LIFECYCLE_PATH" | head -1 | awk -F: '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

  if [[ -z "${SCHEMA_VERSION:-}" ]]; then
    log_err "Failed to determine schema_version from ${LIFECYCLE_PATH}"
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
echo -e "  ${GREEN}.github${RESET}  ← ${RELEASE_REPO}/.github"
echo -e "  ${GREEN}${GOVERNANCE_ORG}/${GOVERNANCE_REPO}${RESET} → ${GOVERNANCE_PATH}/  (branch: ${GOVERNANCE_CLONE_BRANCH:-${GOVERNANCE_BRANCH}})"
echo ""
echo -e "GitHub Copilot adapter is installed from ${RELEASE_REPO}/.github."
echo -e "No further setup is needed if GitHub Copilot is your only IDE."
echo ""
echo -e "For non-Copilot IDEs (cursor, claude, codex), run the module installer:"
echo -e "  ${CYAN}./_bmad/lens-work/scripts/install.sh --ide cursor${RESET}"
echo -e "  ${CYAN}./_bmad/lens-work/scripts/install.sh --all-ides${RESET}"
echo ""
echo -e "${BOLD}Next Steps:${RESET}"
echo -e "  1. Store your GitHub PAT (run in terminal, ${YELLOW}not in AI chat${RESET}):"
echo -e "     ${CYAN}bash ${RELEASE_REPO}/_bmad/lens-work/scripts/store-github-pat.sh${RESET}"
echo -e "  2. Open VS Code + GitHub Copilot Chat and run:"
echo -e "     ${CYAN}/onboard${RESET}"
echo ""
