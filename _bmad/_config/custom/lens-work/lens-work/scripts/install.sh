#!/usr/bin/env bash
# =============================================================================
# LENS Workbench v2 — Module Installer
#
# PURPOSE:
#   Sets up the control repo workspace for lens-work v2:
#   - Creates output directory structure
#   - Generates IDE-specific adapter files (agent stubs, prompts, commands)
#   - Deploys copilot-instructions.md for Copilot-aware IDEs
#   - Safe to re-run: skips existing files unless --update is passed
#
# USAGE:
#   ./lens.core/_bmad/lens-work/scripts/install.sh
#   ./lens.core/_bmad/lens-work/scripts/install.sh --update
#   ./lens.core/_bmad/lens-work/scripts/install.sh --ide github-copilot
#   ./lens.core/_bmad/lens-work/scripts/install.sh --ide cursor --ide claude
#   ./lens.core/_bmad/lens-work/scripts/install.sh --all-ides
#
# OPTIONS:
#   --ide <name>    Install adapter for specific IDE (github-copilot, cursor, claude, codex)
#                   Can be specified multiple times
#   --all-ides      Install adapters for all supported IDEs
#   --update        Overwrite existing adapter files (refresh on module update)
#   --dry-run       Show what would be created without creating files
#   -h, --help      Show this help message
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${MODULE_DIR}/../../.." && pwd)"

# -- Colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# -- Defaults ---------------------------------------------------------------
IDES=()
ALL_IDES=false
UPDATE_MODE=false
DRY_RUN=false
SUPPORTED_IDES=("github-copilot" "cursor" "claude" "codex")

# -- Parse Arguments --------------------------------------------------------
show_help() {
  sed -n '2,/^# =/p' "$0" | sed 's/^# //'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ide)
      shift
      IDES+=("$1")
      ;;
    --all-ides)
      ALL_IDES=true
      ;;
    --update)
      UPDATE_MODE=true
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

if [[ "$ALL_IDES" == true ]]; then
  IDES=("${SUPPORTED_IDES[@]}")
fi

# Default: github-copilot if no IDE specified
if [[ ${#IDES[@]} -eq 0 ]]; then
  IDES=("github-copilot")
fi

# -- Counters ---------------------------------------------------------------
CREATED=0
SKIPPED=0
ERRORS=0

# -- Helper Functions -------------------------------------------------------

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${RESET}   $1"; }
log_skip() { echo -e "${DIM}[SKIP]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err()  { echo -e "${RED}[ERR]${RESET}  $1"; }

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log_info "Would create directory: $dir"
    else
      mkdir -p "$dir"
      log_ok "Created directory: $dir"
    fi
  fi
}

write_file() {
  local filepath="$1"
  local content="$2"
  local relative="${filepath#"$PROJECT_ROOT"/}"

  if [[ -f "$filepath" && "$UPDATE_MODE" != true ]]; then
    log_skip "$relative (exists, use --update to overwrite)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  if [[ "$DRY_RUN" == true ]]; then
    if [[ -f "$filepath" ]]; then
      log_info "Would overwrite: $relative"
    else
      log_info "Would create: $relative"
    fi
    return
  fi

  ensure_dir "$(dirname "$filepath")"
  echo "$content" > "$filepath"

  if [[ -f "$filepath" && "$UPDATE_MODE" == true ]]; then
    log_ok "Updated: $relative"
  else
    log_ok "Created: $relative"
  fi
  CREATED=$((CREATED + 1))
}

# -- Stub generators -------------------------------------------------------

# Generate a GitHub Copilot stub prompt
gh_stub_prompt() {
  local name="$1"
  local description="$2"
  local target_prompt="$3"
  local extra="${4:-}"

  cat <<EOF
---
model: Claude Sonnet 4.6 (copilot)
description: '${description}'
---

# ${name} (Stub)

> **This is a stub.** Load and execute the full prompt from the release module.
> All \`lens.core/_bmad/\` paths in the full prompt are relative to \`lens.core/\` — do NOT resolve paths against the user's main project repo.

\`\`\`
Read and follow all instructions in: lens.core/_bmad/lens-work/prompts/${target_prompt}
\`\`\`
${extra}
EOF
}

# Generate a Cursor command stub
cursor_command() {
  local name="$1"
  local description="$2"
  local workflow_path="$3"

  cat <<EOF
---
name: '${name}'
description: '${description}'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @lens.core/_bmad/lens-work/${workflow_path}, READ its entire contents and follow its directions exactly!
EOF
}

# Generate a Claude command stub
claude_command() {
  local name="$1"
  local description="$2"
  local workflow_path="$3"

  cat <<EOF
---
name: '${name}'
description: '${description}'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @lens.core/_bmad/lens-work/${workflow_path}, READ its entire contents and follow its directions exactly!
EOF
}

# Generate a Codex command stub (same format)
codex_command() {
  local name="$1"
  local description="$2"
  local workflow_path="$3"

  cat <<EOF
---
name: '${name}'
description: '${description}'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @lens.core/_bmad/lens-work/${workflow_path}, READ its entire contents and follow its directions exactly!
EOF
}

# =============================================================================
# PHASE 1: Output Directory Structure
# =============================================================================

install_output_dirs() {
  log_info "Creating output directory structure..."

  ensure_dir "${PROJECT_ROOT}/_bmad-output/lens-work"
  ensure_dir "${PROJECT_ROOT}/_bmad-output/lens-work/initiatives"
  ensure_dir "${PROJECT_ROOT}/_bmad-output/lens-work/personal"
}

# =============================================================================
# PHASE 2: GitHub Copilot Adapter
# =============================================================================

install_github_copilot() {
  log_info "Installing GitHub Copilot adapter..."

  local gh_dir="${PROJECT_ROOT}/.github"
  local agents_dir="${gh_dir}/agents"
  local prompts_dir="${gh_dir}/prompts"

  if [[ -d "${gh_dir}/.git" ]]; then
    log_skip "GitHub Copilot adapter already installed via cloned copilot repo at .github/; skipping generation"
    return
  fi

  ensure_dir "$agents_dir"
  ensure_dir "$prompts_dir"

  # -- Agent stub --
  write_file "${agents_dir}/bmad-agent-lens-work-lens.agent.md" "\`\`\`chatagent
---
description: '@lens — LENS Workbench v2: lifecycle routing, git orchestration, phase-aware branch topology, constitution governance'
tools: ['read', 'edit', 'search', 'execute']
---

You must fully embody this agent's persona and follow all activation instructions exactly as specified.

<agent-activation CRITICAL=\"TRUE\">
1. LOAD the module config from lens.core/_bmad/lens-work/module.yaml
2. LOAD the FULL agent definition from lens.core/_bmad/lens-work/agents/lens.agent.md
3. READ its entire contents - this contains the complete agent persona, skills, lifecycle routing, and phase-to-agent mapping
4. LOAD the lifecycle contract from lens.core/_bmad/lens-work/lifecycle.yaml
5. LOAD the module help index from lens.core/_bmad/lens-work/module-help.csv
6. FOLLOW every activation step in the agent definition precisely
7. DISPLAY the welcome/greeting as instructed
8. PRESENT the numbered menu from module-help.csv
9. WAIT for user input before proceeding
</agent-activation>

\`\`\`"

  # -- Stub prompts --
  # Each maps to a module prompt or workflow path

  write_file "${prompts_dir}/lens-work.onboard.prompt.md" \
    "$(gh_stub_prompt "lens-work.onboard" \
       "Bootstrap control repo — detect provider, validate auth, create profile, auto-clone TargetProjects" \
       "lens-work.onboard.prompt.md")"

  write_file "${prompts_dir}/lens-work.new-initiative.prompt.md" \
    "$(gh_stub_prompt "lens-work.new-initiative" \
       "Create a new initiative (domain, service, or feature)" \
       "lens-work.new-initiative.prompt.md")"

  write_file "${prompts_dir}/lens-work.new-domain.prompt.md" \
    "$(gh_stub_prompt "lens-work.new-domain" \
       "Create new domain-level initiative with domain-only branch and folder scaffolding" \
       "lens-work.new-initiative.prompt.md" \
       $'\nInvoke with scope: **domain**')"

  write_file "${prompts_dir}/lens-work.new-service.prompt.md" \
    "$(gh_stub_prompt "lens-work.new-service" \
       "Create new service-level initiative within a domain" \
       "lens-work.new-initiative.prompt.md" \
       $'\nInvoke with scope: **service**')"

  write_file "${prompts_dir}/lens-work.new-feature.prompt.md" \
    "$(gh_stub_prompt "lens-work.new-feature" \
       "Create new feature-level initiative within a service" \
       "lens-work.new-initiative.prompt.md" \
       $'\nInvoke with scope: **feature**')"

  write_file "${prompts_dir}/lens-work.preplan.prompt.md" \
    "$(gh_stub_prompt "lens-work.preplan" \
       "Start PrePlan phase — brainstorm, research, product brief (Mary/Analyst, small audience)" \
       "lens-work.preplan.prompt.md")"

  write_file "${prompts_dir}/lens-work.businessplan.prompt.md" \
    "$(gh_stub_prompt "lens-work.businessplan" \
       "Start BusinessPlan phase — PRD creation, UX design (John/PM + Sally/UX, small audience)" \
       "lens-work.businessplan.prompt.md")"

  write_file "${prompts_dir}/lens-work.techplan.prompt.md" \
    "$(gh_stub_prompt "lens-work.techplan" \
       "Start TechPlan phase — architecture document, technical decisions (Winston/Architect, small audience)" \
       "lens-work.techplan.prompt.md")"

  write_file "${prompts_dir}/lens-work.devproposal.prompt.md" \
    "$(gh_stub_prompt "lens-work.devproposal" \
       "Start DevProposal phase — epics, stories, readiness check (John/PM, medium audience)" \
       "lens-work.devproposal.prompt.md")"

  write_file "${prompts_dir}/lens-work.sprintplan.prompt.md" \
    "$(gh_stub_prompt "lens-work.sprintplan" \
       "Start SprintPlan phase — sprint-status, story files (Bob/Scrum Master, large audience)" \
       "lens-work.sprintplan.prompt.md")"

  write_file "${prompts_dir}/lens-work.status.prompt.md" \
    "$(gh_stub_prompt "lens-work.status" \
       "Show consolidated status report across all active initiatives" \
       "lens-work.status.prompt.md")"

  write_file "${prompts_dir}/lens-work.next.prompt.md" \
    "$(gh_stub_prompt "lens-work.next" \
       "Recommend next action based on lifecycle state" \
       "lens-work.next.prompt.md")"

  write_file "${prompts_dir}/lens-work.switch.prompt.md" \
    "$(gh_stub_prompt "lens-work.switch" \
       "Switch to a different initiative via git checkout" \
       "lens-work.switch.prompt.md")"

  write_file "${prompts_dir}/lens-work.promote.prompt.md" \
    "$(gh_stub_prompt "lens-work.promote" \
       "Promote current audience to next level with gate checks" \
       "lens-work.promote.prompt.md")"

  write_file "${prompts_dir}/lens-work.constitution.prompt.md" \
    "$(gh_stub_prompt "lens-work.constitution" \
       "Resolve and display constitutional governance" \
       "lens-work.constitution.prompt.md")"

  write_file "${prompts_dir}/lens-work.help.prompt.md" \
    "$(gh_stub_prompt "lens-work.help" \
       "Show available commands and usage" \
       "lens-work.help.prompt.md")"

  # -- Copilot instructions --
  write_file "${gh_dir}/lens-work-instructions.md" "$(cat <<'INSTEOF'
<!-- LENS-WORK ADAPTER -->
# LENS Workbench — Copilot Instructions

## Module Reference

This control repo uses the LENS Workbench module from the release payload:

- **Module path:** `lens.core/_bmad/lens-work/`
- **Lifecycle contract:** `lens.core/_bmad/lens-work/lifecycle.yaml`
- **Module version:** See `lens.core/_bmad/lens-work/module.yaml`

## Agent

The `@lens` agent is defined at `.github/agents/bmad-agent-lens-work-lens.agent.md` and references
the module agent at `lens.core/_bmad/lens-work/agents/lens.agent.md`.

## Skills (by path reference)

| Skill | Path |
|-------|------|
| git-state | `lens.core/_bmad/lens-work/skills/git-state/SKILL.md` |
| git-orchestration | `lens.core/_bmad/lens-work/skills/git-orchestration/SKILL.md` |
| constitution | `lens.core/_bmad/lens-work/skills/constitution/SKILL.md` |
| sensing | `lens.core/_bmad/lens-work/skills/sensing/SKILL.md` |
| checklist | `lens.core/_bmad/lens-work/skills/checklist/SKILL.md` |

## Important

- This adapter references module content by path — it NEVER duplicates it
- Do not copy skills, workflows, or lifecycle definitions into `.github/`
- Module updates propagate automatically through path references
<!-- /LENS-WORK ADAPTER -->
INSTEOF
)"

  log_ok "GitHub Copilot adapter complete"
}

# =============================================================================
# PHASE 3: Cursor Adapter
# =============================================================================

install_cursor() {
  log_info "Installing Cursor adapter..."

  local cursor_dir="${PROJECT_ROOT}/.cursor/commands"
  ensure_dir "$cursor_dir"

  # Command stubs — one per user-facing command
  # Format: cursor_command <name> <description> <workflow-path>

  write_file "${cursor_dir}/bmad-lens-work-onboard.md" \
    "$(cursor_command "onboard" \
       "Create profile + run bootstrap + auto-clone TargetProjects" \
       "workflows/utility/onboard/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-init-initiative.md" \
    "$(cursor_command "init-initiative" \
       "Create new initiative (domain/service/feature) with branch topology" \
       "workflows/router/init-initiative/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-preplan.md" \
    "$(cursor_command "preplan" \
       "Launch PrePlan phase (brainstorm/research/product brief)" \
       "workflows/router/preplan/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-businessplan.md" \
    "$(cursor_command "businessplan" \
       "Launch BusinessPlan phase (PRD/UX design)" \
       "workflows/router/businessplan/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-techplan.md" \
    "$(cursor_command "techplan" \
       "Launch TechPlan phase (architecture/technical decisions)" \
       "workflows/router/techplan/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-devproposal.md" \
    "$(cursor_command "devproposal" \
       "Launch DevProposal phase (epics/stories/readiness check)" \
       "workflows/router/devproposal/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-sprintplan.md" \
    "$(cursor_command "sprintplan" \
       "Launch SprintPlan phase (sprint-status/story files)" \
       "workflows/router/sprintplan/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-dev.md" \
    "$(cursor_command "dev" \
       "Delegate to implementation agents in target projects" \
       "workflows/router/dev/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-status.md" \
    "$(cursor_command "status" \
       "Display current state, blocks, topology, next steps" \
       "workflows/utility/status/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-next.md" \
    "$(cursor_command "next" \
       "Recommend next action based on lifecycle state" \
       "workflows/utility/next/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-switch.md" \
    "$(cursor_command "switch" \
       "Switch to different initiative branch" \
       "workflows/utility/switch/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-help.md" \
    "$(cursor_command "help" \
       "Show available commands and usage reference" \
       "workflows/utility/help/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-promote.md" \
    "$(cursor_command "promote" \
       "Promote current audience to next tier with gate checks" \
       "workflows/core/audience-promotion/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-constitution.md" \
    "$(cursor_command "constitution" \
       "Resolve and display constitutional governance" \
       "workflows/governance/resolve-constitution/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-compliance.md" \
    "$(cursor_command "compliance" \
       "Run constitution compliance check on current initiative" \
       "workflows/governance/compliance-check/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-sense.md" \
    "$(cursor_command "sense" \
       "Cross-initiative overlap detection on demand" \
       "workflows/governance/cross-initiative/workflow.md")"

  write_file "${cursor_dir}/bmad-lens-work-module-management.md" \
    "$(cursor_command "module-management" \
       "Check module version and guide self-service updates" \
       "workflows/utility/module-management/workflow.md")"

  log_ok "Cursor adapter complete"
}

# =============================================================================
# PHASE 4: Claude Code Adapter
# =============================================================================

install_claude() {
  log_info "Installing Claude Code adapter..."

  local claude_dir="${PROJECT_ROOT}/.claude/commands"
  ensure_dir "$claude_dir"

  # Claude uses the same command stub format as Cursor

  write_file "${claude_dir}/bmad-lens-work-onboard.md" \
    "$(claude_command "onboard" \
       "Create profile + run bootstrap + auto-clone TargetProjects" \
       "workflows/utility/onboard/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-init-initiative.md" \
    "$(claude_command "init-initiative" \
       "Create new initiative (domain/service/feature) with branch topology" \
       "workflows/router/init-initiative/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-preplan.md" \
    "$(claude_command "preplan" \
       "Launch PrePlan phase (brainstorm/research/product brief)" \
       "workflows/router/preplan/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-businessplan.md" \
    "$(claude_command "businessplan" \
       "Launch BusinessPlan phase (PRD/UX design)" \
       "workflows/router/businessplan/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-techplan.md" \
    "$(claude_command "techplan" \
       "Launch TechPlan phase (architecture/technical decisions)" \
       "workflows/router/techplan/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-devproposal.md" \
    "$(claude_command "devproposal" \
       "Launch DevProposal phase (epics/stories/readiness check)" \
       "workflows/router/devproposal/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-sprintplan.md" \
    "$(claude_command "sprintplan" \
       "Launch SprintPlan phase (sprint-status/story files)" \
       "workflows/router/sprintplan/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-dev.md" \
    "$(claude_command "dev" \
       "Delegate to implementation agents in target projects" \
       "workflows/router/dev/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-status.md" \
    "$(claude_command "status" \
       "Display current state, blocks, topology, next steps" \
       "workflows/utility/status/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-next.md" \
    "$(claude_command "next" \
       "Recommend next action based on lifecycle state" \
       "workflows/utility/next/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-switch.md" \
    "$(claude_command "switch" \
       "Switch to different initiative branch" \
       "workflows/utility/switch/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-help.md" \
    "$(claude_command "help" \
       "Show available commands and usage reference" \
       "workflows/utility/help/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-promote.md" \
    "$(claude_command "promote" \
       "Promote current audience to next tier with gate checks" \
       "workflows/core/audience-promotion/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-constitution.md" \
    "$(claude_command "constitution" \
       "Resolve and display constitutional governance" \
       "workflows/governance/resolve-constitution/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-compliance.md" \
    "$(claude_command "compliance" \
       "Run constitution compliance check on current initiative" \
       "workflows/governance/compliance-check/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-sense.md" \
    "$(claude_command "sense" \
       "Cross-initiative overlap detection on demand" \
       "workflows/governance/cross-initiative/workflow.md")"

  write_file "${claude_dir}/bmad-lens-work-module-management.md" \
    "$(claude_command "module-management" \
       "Check module version and guide self-service updates" \
       "workflows/utility/module-management/workflow.md")"

  log_ok "Claude Code adapter complete"
}

# =============================================================================
# PHASE 5: Codex CLI Adapter
# =============================================================================

install_codex() {
  log_info "Installing Codex CLI adapter..."

  # -- AGENTS.md in project root --
  write_file "${PROJECT_ROOT}/AGENTS.md" "$(cat <<'AGENTSEOF'
# LENS Workbench — Codex Agent

This project uses the LENS Workbench module for lifecycle routing and git orchestration.

## Module Reference

- **Module path:** \`lens.core/_bmad/lens-work/\`
- **Agent definition:** \`lens.core/_bmad/lens-work/agents/lens.agent.md\`
- **Lifecycle contract:** \`lens.core/_bmad/lens-work/lifecycle.yaml\`
- **Module config:** \`lens.core/_bmad/lens-work/module.yaml\`

## Activation

1. LOAD the module config from \`lens.core/_bmad/lens-work/module.yaml\`
2. LOAD the FULL agent definition from \`lens.core/_bmad/lens-work/agents/lens.agent.md\`
3. READ its entire contents — this contains the complete agent persona, skills, lifecycle routing, and phase-to-agent mapping
4. LOAD the lifecycle contract from \`lens.core/_bmad/lens-work/lifecycle.yaml\`
5. FOLLOW every activation step in the agent definition precisely

## Available Commands

See \`lens.core/_bmad/lens-work/module-help.csv\` for the complete command list.

## Skills (path references)

| Skill | Path |
|-------|------|
| git-state | \`lens.core/_bmad/lens-work/skills/git-state/SKILL.md\` |
| git-orchestration | \`lens.core/_bmad/lens-work/skills/git-orchestration/SKILL.md\` |
| constitution | \`lens.core/_bmad/lens-work/skills/constitution/SKILL.md\` |
| sensing | \`lens.core/_bmad/lens-work/skills/sensing/SKILL.md\` |
| checklist | \`lens.core/_bmad/lens-work/skills/checklist/SKILL.md\` |
AGENTSEOF
)"

  # -- .codex/commands/ --
  local codex_dir="${PROJECT_ROOT}/.codex/commands"
  ensure_dir "$codex_dir"

  write_file "${codex_dir}/bmad-lens-work-onboard.md" \
    "$(codex_command "onboard" \
       "Create profile + run bootstrap + auto-clone TargetProjects" \
       "workflows/utility/onboard/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-init-initiative.md" \
    "$(codex_command "init-initiative" \
       "Create new initiative (domain/service/feature) with branch topology" \
       "workflows/router/init-initiative/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-preplan.md" \
    "$(codex_command "preplan" \
       "Launch PrePlan phase (brainstorm/research/product brief)" \
       "workflows/router/preplan/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-businessplan.md" \
    "$(codex_command "businessplan" \
       "Launch BusinessPlan phase (PRD/UX design)" \
       "workflows/router/businessplan/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-techplan.md" \
    "$(codex_command "techplan" \
       "Launch TechPlan phase (architecture/technical decisions)" \
       "workflows/router/techplan/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-devproposal.md" \
    "$(codex_command "devproposal" \
       "Launch DevProposal phase (epics/stories/readiness check)" \
       "workflows/router/devproposal/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-sprintplan.md" \
    "$(codex_command "sprintplan" \
       "Launch SprintPlan phase (sprint-status/story files)" \
       "workflows/router/sprintplan/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-dev.md" \
    "$(codex_command "dev" \
       "Delegate to implementation agents in target projects" \
       "workflows/router/dev/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-status.md" \
    "$(codex_command "status" \
       "Display current state, blocks, topology, next steps" \
       "workflows/utility/status/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-next.md" \
    "$(codex_command "next" \
       "Recommend next action based on lifecycle state" \
       "workflows/utility/next/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-switch.md" \
    "$(codex_command "switch" \
       "Switch to different initiative branch" \
       "workflows/utility/switch/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-help.md" \
    "$(codex_command "help" \
       "Show available commands and usage reference" \
       "workflows/utility/help/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-promote.md" \
    "$(codex_command "promote" \
       "Promote current audience to next tier with gate checks" \
       "workflows/core/audience-promotion/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-constitution.md" \
    "$(codex_command "constitution" \
       "Resolve and display constitutional governance" \
       "workflows/governance/resolve-constitution/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-compliance.md" \
    "$(codex_command "compliance" \
       "Run constitution compliance check on current initiative" \
       "workflows/governance/compliance-check/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-sense.md" \
    "$(codex_command "sense" \
       "Cross-initiative overlap detection on demand" \
       "workflows/governance/cross-initiative/workflow.md")"

  write_file "${codex_dir}/bmad-lens-work-module-management.md" \
    "$(codex_command "module-management" \
       "Check module version and guide self-service updates" \
       "workflows/utility/module-management/workflow.md")"

  log_ok "Codex CLI adapter complete"
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo -e "${BOLD}LENS Workbench v2 — Module Installer${RESET}"
echo -e "${DIM}Module: ${MODULE_DIR}${RESET}"
echo -e "${DIM}Target: ${PROJECT_ROOT}${RESET}"
echo ""

if [[ "$UPDATE_MODE" == true ]]; then
  log_warn "Update mode: existing adapter files will be overwritten"
fi
if [[ "$DRY_RUN" == true ]]; then
  log_warn "Dry run: no files will be created"
fi

# Phase 1: Output directories
install_output_dirs

# Phase 2-4: IDE adapters
for ide in "${IDES[@]}"; do
  case "$ide" in
    github-copilot)
      install_github_copilot
      ;;
    cursor)
      install_cursor
      ;;
    claude)
      install_claude
      ;;
    codex)
      install_codex
      ;;
    *)
      log_err "Unknown IDE: $ide (supported: ${SUPPORTED_IDES[*]})"
      ERRORS=$((ERRORS + 1))
      ;;
  esac
done

# Summary
echo ""
echo -e "${BOLD}Summary${RESET}"
echo -e "  Created: ${GREEN}${CREATED}${RESET}"
echo -e "  Skipped: ${DIM}${SKIPPED}${RESET}"
if [[ "$ERRORS" -gt 0 ]]; then
  echo -e "  Errors:  ${RED}${ERRORS}${RESET}"
fi
echo ""

if [[ "$ERRORS" -gt 0 ]]; then
  exit 1
fi
