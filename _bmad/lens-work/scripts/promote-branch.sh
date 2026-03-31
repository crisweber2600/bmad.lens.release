#!/usr/bin/env bash
# =============================================================================
# LENS Workbench — Branch promotion + cleanup helper
#
# PURPOSE:
#   Promotes a source branch to its next target (audience/phase/workflow),
#   optionally creates a PR, and cleans up merged branches locally/remotely.
#
# USAGE:
#   ./_bmad/lens-work/scripts/promote-branch.sh
#   ./_bmad/lens-work/scripts/promote-branch.sh -s my-initiative-small
#   ./_bmad/lens-work/scripts/promote-branch.sh -s my-initiative-small --cleanup
#   ./_bmad/lens-work/scripts/promote-branch.sh -s my-initiative-small -t my-initiative-medium --cleanup --cleanup-children
#
# OPTIONS:
#   -s, --source              Source branch name (defaults to current branch)
#   -t, --target              Target branch name (auto-inferred if not provided)
#   -r, --remote              Remote name (default: origin)
#   -C, --cleanup             Delete source branch after merging
#   -cc, --cleanup-children   Also delete child branches (e.g., promotion-techplan-*)
#   --url-only                Print URL only, don't create PR
#   --no-pr                   Skip PR creation, don't set GH_TOKEN
#   --skip-clean-check        Skip git status check before promotion
#   -h, --help                Show this help message
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PROFILE_FILE="${PROJECT_ROOT}/_bmad-output/lens-work/personal/profile.yaml"

# -- Colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# -- Defaults ---------------------------------------------------------------
SOURCE_BRANCH=""
TARGET_BRANCH=""
REMOTE="origin"
CLEANUP=false
CLEANUP_CHILDREN=false
SKIP_CLEAN_CHECK=false
CREATE_PR=true
URL_ONLY=false

# -- Helper Functions -------------------------------------------------------

show_help() {
  sed -n '2,/^# =/p' "$0" | sed 's/^# //'
}

invoke_git() {
  local allow_failure=false
  local args=()

  # Parse arguments — last arg can be -allow-failure
  for arg in "$@"; do
    if [[ "$arg" == "-allow-failure" ]]; then
      allow_failure=true
    else
      args+=("$arg")
    fi
  done

  if [[ "$allow_failure" == true ]]; then
    local rc=0
    git "${args[@]}" 2>&1 || rc=$?
    return $rc
  else
    git "${args[@]}"
  fi
}

test_local_branch() {
  local branch="$1"
  invoke_git show-ref --verify "refs/heads/$branch" -allow-failure > /dev/null 2>&1
  return $?
}

test_remote_branch() {
  local branch="$1"
  local result
  result=$(invoke_git ls-remote --heads "$REMOTE" "$branch" -allow-failure)
  [[ -n "$result" ]]
}

get_branch_context() {
  local branch="$1"
  local -a parts
  local audience_idx=-1
  local i

  # Split branch by hyphen
  IFS='-' read -ra parts <<< "$branch"

  # Find audience keyword
  for ((i = ${#parts[@]} - 1; i >= 0; i--)); do
    case "${parts[$i]}" in
      small|medium|large)
        audience_idx=$i
        break
        ;;
    esac
  done

  if [[ $audience_idx -lt 0 ]]; then
    return 1
  fi

  # Extract components
  local root suffix
  if (( audience_idx > 0 )); then
    root=$(IFS='-'; echo "${parts[*]:0:$audience_idx}")
  else
    root=""
  fi

  if (( audience_idx + 1 < ${#parts[@]} )); then
    suffix=$(IFS='-'; echo "${parts[*]:$((audience_idx + 1))}")
  else
    suffix=""
  fi

  echo "$root|${parts[$audience_idx]}|$suffix"
}

get_promotion_plan() {
  local branch="$1"
  local context
  
  context=$(get_branch_context "$branch") || return 1
  
  local root audience suffix
  IFS='|' read -r root audience suffix <<< "$context"

  if [[ -z "$suffix" ]]; then
    # No suffix — promote audience
    case "$audience" in
      small)  echo "audience|${root:+$root-}medium"; return 0 ;;
      medium) echo "audience|${root:+$root-}large"; return 0 ;;
      large)  echo "audience|${root:+$root-}base"; return 0 ;;
    esac
  fi

  if [[ ! "$suffix" =~ - ]]; then
    # Single suffix component (phase) — promote to audience
    echo "phase|${root:+$root-}$audience"
    return 0
  fi

  # Multiple suffix components (workflow) — promote to phase
  local phase
  phase=$(echo "$suffix" | cut -d'-' -f1)
  echo "workflow|${root:+$root-}$audience-$phase"
}

get_remote_url() {
  invoke_git remote get-url "$REMOTE" 2>/dev/null || echo ""
}

parse_remote_url() {
  local url="$1"
  local host org project repo platform

  # Azure DevOps HTTPS
  if [[ "$url" =~ dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+) ]]; then
    host="dev.azure.com"
    org="${BASH_REMATCH[1]}"
    project="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
    platform="azdo"
    echo "$host|$org|$project|$repo|$platform"
    return 0
  fi

  # Azure DevOps SSH
  if [[ "$url" =~ ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/([^/]+) ]]; then
    host="dev.azure.com"
    org="${BASH_REMATCH[1]}"
    project="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
    platform="azdo"
    echo "$host|$org|$project|$repo|$platform"
    return 0
  fi

  # GitHub/GitLab HTTPS
  if [[ "$url" =~ https?://([^/]+)/([^/]+)/([^/]+?)(\.git)?$ ]]; then
    host="${BASH_REMATCH[1]}"
    org="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
    [[ "$host" == *"gitlab"* ]] && platform="gitlab" || platform="github"
    echo "$host|$org||$repo|$platform"
    return 0
  fi

  # GitHub/GitLab SSH
  if [[ "$url" =~ git@([^:]+):([^/]+)/([^/]+?)(\.git)?$ ]]; then
    host="${BASH_REMATCH[1]}"
    org="${BASH_REMATCH[2]}"
    repo="${BASH_REMATCH[3]}"
    [[ "$host" == *"gitlab"* ]] && platform="gitlab" || platform="github"
    echo "$host|$org||$repo|$platform"
    return 0
  fi

  # Unknown format
  echo "||||||unknown"
}

get_pr_url() {
  local host="$1"
  local org="$2"
  local project="$3"
  local repo="$4"
  local platform="$5"
  local source="$6"
  local target="$7"

  case "$platform" in
    github)
      echo "https://${host}/${org}/${repo}/compare/${target}...${source}"
      ;;
    gitlab)
      echo "https://${host}/${org}/${repo}/-/merge_requests/new?source_branch=${source}&target_branch=${target}"
      ;;
    azdo)
      echo "https://dev.azure.com/${org}/$(urlencode "${project}")/_git/${repo}/pullrequestcreate?sourceRef=${source}&targetRef=${target}"
      ;;
    *)
      echo "MANUAL: Create PR from ${source} -> ${target}"
      ;;
  esac
}

get_profile_pat() {
  local host="$1"
  local profile_file="$2"

  if [[ ! -f "$profile_file" ]]; then
    return 1
  fi

  local in_creds=false
  local current_host=""
  local current_pat=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^git_credentials: ]]; then
      in_creds=true
    elif [[ "$in_creds" == true && "$line" =~ ^[[:space:]]{2}-[[:space:]]host:[[:space:]]*(.+) ]]; then
      current_host="${BASH_REMATCH[1]}"
      current_pat=""
    elif [[ "$in_creds" == true && "$current_host" == "$host" && "$line" =~ ^[[:space:]]{4}pat:[[:space:]]*(.+) ]]; then
      current_pat="${BASH_REMATCH[1]}"
      echo "$current_pat"
      return 0
    elif [[ "$in_creds" == true && "$line" =~ ^[a-zA-Z] ]]; then
      in_creds=false
    fi
  done < "$profile_file"

  return 1
}

invoke_github_pr_create() {
  local host="$1"
  local org="$2"
  local repo="$3"
  local source="$4"
  local target="$5"
  local pat="$6"
  local title="${7:-Promote: $source -> $target}"
  local body="${8:-## Branch Promotion\n\nPromoting changes from \`$source\` to \`$target\`\n\n---\n*Generated by promote-branch.sh*}"

  # Check if curl and jq are available
  if ! command -v curl &> /dev/null; then
    echo -e "  ${YELLOW}[WARN]  curl not found. Install curl to create PRs via API.${RESET}"
    return 1
  fi
  if ! command -v jq &> /dev/null; then
    echo -e "  ${YELLOW}[WARN]  jq not found. Install jq to parse API responses.${RESET}"
    return 1
  fi

  # Derive API base URL: github.com → api.github.com, GHE → {host}/api/v3
  local api_base
  if [[ "$host" == "github.com" ]]; then
    api_base="https://api.github.com"
  else
    api_base="https://${host}/api/v3"
  fi

  # Create PR via REST API
  local response http_code
  http_code=$(curl -s -o /tmp/gh_pr_response.json -w '%{http_code}' \
    -X POST "${api_base}/repos/${org}/${repo}/pulls" \
    -H "Authorization: token ${pat}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg head "$source" \
      --arg base "$target" \
      --arg title "$title" \
      --arg body "$body" \
      '{head: $head, base: $base, title: $title, body: $body}')")

  if [ "$http_code" = "201" ]; then
    jq -r '.html_url' /tmp/gh_pr_response.json
    rm -f /tmp/gh_pr_response.json
    return 0
  else
    local err_msg
    err_msg=$(jq -r '.message // "Unknown error"' /tmp/gh_pr_response.json 2>/dev/null)
    echo -e "  ${RED}[ERROR] PR creation failed (HTTP ${http_code}): $err_msg${RESET}"
    rm -f /tmp/gh_pr_response.json
    return 1
  fi
}

ensure_clean_state() {
  local status
  status=$(invoke_git status --porcelain)
  if [[ -n "$status" ]]; then
    echo -e "${RED}[ERROR] Uncommitted changes detected. Commit or stash before promoting.${RESET}"
    exit 1
  fi
}

ensure_target_checkedout() {
  local branch="$1"

  if test_local_branch "$branch"; then
    invoke_git checkout "$branch" > /dev/null
    return 0
  fi

  if test_remote_branch "$branch"; then
    invoke_git checkout -b "$branch" "$REMOTE/$branch" > /dev/null
    return 0
  fi

  echo -e "${RED}[ERROR] Target branch '$branch' not found locally or on '$REMOTE'.${RESET}"
  exit 1
}

urlencode() {
  local string="$1"
  if command -v jq &>/dev/null; then
    echo -n "$string" | jq -sRr @uri
  elif command -v python3 &>/dev/null; then
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$string"
  else
    # POSIX-portable fallback: percent-encode common special chars
    echo -n "$string" | LC_ALL=C sed \
      -e 's/%/%25/g' -e 's/ /%20/g' -e 's/!/%21/g' -e 's/#/%23/g' \
      -e 's/\$/%24/g' -e 's/&/%26/g' -e "s/'/%27/g" -e 's/(/%28/g' \
      -e 's/)/%29/g' -e 's/\*/%2A/g' -e 's/+/%2B/g' -e 's/,/%2C/g' \
      -e 's/:/%3A/g' -e 's/;/%3B/g' -e 's/=/%3D/g' -e 's/?/%3F/g' \
      -e 's/@/%40/g' -e 's/\[/%5B/g' -e 's/\]/%5D/g'
  fi
}

# -- Parse Arguments --------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source)
      SOURCE_BRANCH="$2"
      shift 2
      ;;
    -t|--target)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    -r|--remote)
      REMOTE="$2"
      shift 2
      ;;
    -C|--cleanup)
      CLEANUP=true
      shift
      ;;
    -cc|--cleanup-children)
      CLEANUP=true
      CLEANUP_CHILDREN=true
      shift
      ;;
    --url-only)
      URL_ONLY=true
      CREATE_PR=false
      shift
      ;;
    --no-pr)
      CREATE_PR=false
      shift
      ;;
    --skip-clean-check)
      SKIP_CLEAN_CHECK=true
      shift
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
done

# -- Determine Source Branch ------------------------------------------------

if [[ -z "$SOURCE_BRANCH" ]]; then
  SOURCE_BRANCH=$(invoke_git branch --show-current)
fi

if [[ -z "$SOURCE_BRANCH" ]]; then
  echo -e "${RED}[ERROR] Source branch is required (unable to detect current branch).${RESET}"
  exit 1
fi

# -- Determine Target Branch ------------------------------------------------

if [[ -z "$TARGET_BRANCH" ]]; then
  if ! promotion_plan=$(get_promotion_plan "$SOURCE_BRANCH"); then
    echo -e "${RED}[ERROR] Unable to infer target branch. Provide -t/--target explicitly.${RESET}"
    exit 1
  fi

  IFS='|' read -r promotion_kind target_branch_inferred <<< "$promotion_plan"
  TARGET_BRANCH="$target_branch_inferred"
  PROMOTION_KIND="$promotion_kind"
else
  PROMOTION_KIND="manual"
fi

# -- Preflight Checks -------------------------------------------------------

if [[ "$SKIP_CLEAN_CHECK" != true ]]; then
  ensure_clean_state
fi

invoke_git fetch "$REMOTE" --prune > /dev/null 2>&1

# -- Parse Remote Info -----------------------------------------------------

REMOTE_URL=$(get_remote_url)
if [[ -z "$REMOTE_URL" ]]; then
  echo -e "${RED}[ERROR] Failed to get remote URL for '$REMOTE'.${RESET}"
  exit 1
fi

REMOTE_INFO=$(parse_remote_url "$REMOTE_URL")
IFS='|' read -r remote_host remote_org remote_project remote_repo remote_platform <<< "$REMOTE_INFO"

PR_URL=$(get_pr_url "$remote_host" "$remote_org" "$remote_project" "$remote_repo" "$remote_platform" "$SOURCE_BRANCH" "$TARGET_BRANCH")

# -- Load PAT if GitHub -----------------------------------------------------

PAT=""
PAT_SOURCE=""
PR_CREATED=false

if [[ "$remote_platform" == "github" && "$CREATE_PR" == true && "$URL_ONLY" != true ]]; then
  # Priority 1: Host-specific environment variables
  if [[ "$remote_host" == "github.com" ]]; then
    # github.com: GITHUB_PAT -> GH_TOKEN -> profile.yaml
    if [[ -n "${GITHUB_PAT:-}" ]]; then
      PAT="$GITHUB_PAT"
      PAT_SOURCE="GITHUB_PAT environment variable"
    elif [[ -n "${GH_TOKEN:-}" ]]; then
      PAT="$GH_TOKEN"
      PAT_SOURCE="GH_TOKEN environment variable"
    fi
  else
    # Enterprise: GH_ENTERPRISE_TOKEN -> GH_TOKEN -> profile.yaml
    if [[ -n "${GH_ENTERPRISE_TOKEN:-}" ]]; then
      PAT="$GH_ENTERPRISE_TOKEN"
      PAT_SOURCE="GH_ENTERPRISE_TOKEN environment variable"
    elif [[ -n "${GH_TOKEN:-}" ]]; then
      PAT="$GH_TOKEN"
      PAT_SOURCE="GH_TOKEN environment variable"
    fi
  fi
  # Priority 2: Profile file
  if [[ -z "$PAT" && -f "$PROFILE_FILE" ]]; then
    PAT=$(get_profile_pat "$remote_host" "$PROFILE_FILE") || true
    if [[ -n "$PAT" ]]; then
      PAT_SOURCE="profile.yaml"
    fi
  fi
fi

# -- Display Promotion Plan -------------------------------------------------

echo ""
echo -e "${BOLD}Promotion plan${RESET}"
echo -e "  ${CYAN}Kind:${RESET}   $PROMOTION_KIND"
echo -e "  ${CYAN}Source:${RESET} $SOURCE_BRANCH"
echo -e "  ${CYAN}Target:${RESET} $TARGET_BRANCH"

if [[ -n "$remote_host" ]]; then
  echo -e "  ${CYAN}Remote:${RESET} $remote_host"
fi

if [[ "$remote_platform" == "github" ]]; then
  ENV_HINT="GITHUB_PAT"
  if [[ "$remote_host" != "github.com" ]]; then
    ENV_HINT="GH_ENTERPRISE_TOKEN"
  fi
  if [[ -n "$PAT" && "$CREATE_PR" == true && "$URL_ONLY" != true ]]; then
    echo -e "  ${GREEN}PAT:${RESET}    loaded from ${PAT_SOURCE}"
    echo -e "  ${GREEN}Action:${RESET} Will create PR automatically"
  elif [[ -f "$PROFILE_FILE" ]]; then
    echo -e "  ${YELLOW}PAT:${RESET}    not found for $remote_host"
    echo -e "  ${YELLOW}Action:${RESET} URL-only (set ${ENV_HINT} env var or run store-github-pat.sh)"
  else
    echo -e "  ${YELLOW}PAT:${RESET}    no profile found"
    echo -e "  ${YELLOW}Action:${RESET} URL-only (set ${ENV_HINT} env var or run store-github-pat.sh)"
  fi
fi

if [[ -z "$PAT" || "$URL_ONLY" == true ]]; then
  echo -e "  ${YELLOW}PR URL:${RESET} $PR_URL"
fi

echo ""

# -- Verify Target Branch Exists --------------------------------------------

if ! test_remote_branch "$TARGET_BRANCH" && ! test_local_branch "$TARGET_BRANCH"; then
  echo -e "${RED}[ERROR] Target branch '$TARGET_BRANCH' not found locally or on '$REMOTE'.${RESET}"
  exit 1
fi

# -- Push Source Branch -----------------------------------------------------

if test_local_branch "$SOURCE_BRANCH"; then
  invoke_git push "$REMOTE" "$SOURCE_BRANCH" > /dev/null 2>&1 || true
fi

# -- Create PR if PAT Available ---------------------------------------------

if [[ -n "$PAT" && "$remote_platform" == "github" && "$CREATE_PR" == true && "$URL_ONLY" != true ]]; then
  echo -e "${CYAN}Creating pull request...${RESET}"
  
  if pr_result=$(invoke_github_pr_create "$remote_host" "$remote_org" "$remote_repo" "$SOURCE_BRANCH" "$TARGET_BRANCH" "$PAT"); then
    echo -e "${GREEN}[OK] PR created: $pr_result${RESET}"
    PR_CREATED=true
  else
    echo -e "${YELLOW}[WARN]  PR creation failed. Manual URL: $PR_URL${RESET}"
  fi
  echo ""
fi

# -- Cleanup ----------------------------------------------------------------

if [[ "$CLEANUP" != true ]]; then
  echo -e "${DIM}Cleanup not requested. Use --cleanup to remove merged branches.${RESET}"
  exit 0
fi

# Check if merged
MERGED=false
if test_remote_branch "$SOURCE_BRANCH" && test_remote_branch "$TARGET_BRANCH"; then
  if invoke_git merge-base --is-ancestor "$REMOTE/$SOURCE_BRANCH" "$REMOTE/$TARGET_BRANCH" -allow-failure > /dev/null 2>&1; then
    MERGED=true
  fi
elif test_local_branch "$SOURCE_BRANCH" && test_local_branch "$TARGET_BRANCH"; then
  if invoke_git merge-base --is-ancestor "$SOURCE_BRANCH" "$TARGET_BRANCH" -allow-failure > /dev/null 2>&1; then
    MERGED=true
  fi
fi

if [[ "$MERGED" != true ]]; then
  echo -e "${YELLOW}[WARN]  Source branch '$SOURCE_BRANCH' is not merged into '$TARGET_BRANCH'. Cleanup skipped.${RESET}"
  exit 0
fi

# Checkout target branch before cleanup
ensure_target_checkedout "$TARGET_BRANCH"

# Delete local source branch
if test_local_branch "$SOURCE_BRANCH"; then
  if invoke_git branch -d "$SOURCE_BRANCH" 2> /dev/null; then
    echo -e "${GREEN}[OK] Deleted local branch: $SOURCE_BRANCH${RESET}"
  fi
fi

# Delete remote source branch
if test_remote_branch "$SOURCE_BRANCH"; then
  if invoke_git push "$REMOTE" --delete "$SOURCE_BRANCH" 2> /dev/null; then
    echo -e "${GREEN}[OK] Deleted remote branch: $REMOTE/$SOURCE_BRANCH${RESET}"
  fi
fi

# Delete child branches if requested
if [[ "$CLEANUP_CHILDREN" == true ]]; then
  echo -e "${CYAN}Cleaning up child branches...${RESET}"

  # Local children
  local_branches=$(invoke_git for-each-ref "refs/heads" --format="%(refname:short)")
  while IFS= read -r branch; do
    if [[ "$branch" == "$SOURCE_BRANCH"-* ]]; then
      if invoke_git branch -d "$branch" 2> /dev/null; then
        echo -e "  ${GREEN}[OK]${RESET} Deleted: $branch"
      fi
    fi
  done <<< "$local_branches"

  # Remote children
  remote_branches=$(invoke_git for-each-ref "refs/remotes/$REMOTE" --format="%(refname:short)")
  while IFS= read -r branch; do
    # Strip remote prefix
    branch_name="${branch#$REMOTE/}"
    if [[ "$branch_name" == "$SOURCE_BRANCH"-* ]]; then
      if invoke_git push "$REMOTE" --delete "$branch_name" 2> /dev/null; then
        echo -e "  ${GREEN}[OK]${RESET} Deleted: $REMOTE/$branch_name"
      fi
    fi
  done <<< "$remote_branches"
fi

echo -e "${GREEN}[OK] Cleanup complete.${RESET}"
