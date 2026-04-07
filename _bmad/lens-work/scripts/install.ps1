#Requires -Version 5.1
<#
.SYNOPSIS
    LENS Workbench v2 — Module Installer

.DESCRIPTION
    Sets up the control repo workspace for lens-work v2:
    - Creates output directory structure
    - Generates IDE-specific adapter files (agent stubs, prompts, commands)
    - Deploys copilot-instructions.md for Copilot-aware IDEs
    - Safe to re-run: skips existing files unless -Update is passed

.PARAMETER IDE
    IDE adapter(s) to install. Can be specified multiple times.
    Supported: github-copilot, cursor, claude, codex

.PARAMETER AllIDEs
    Install adapters for all supported IDEs.

.PARAMETER Update
    Overwrite existing adapter files (refresh on module update).

.PARAMETER DryRun
    Show what would be created without creating files.

.EXAMPLE
    .\lens.core\_bmad\lens-work\scripts\install.ps1
    .\lens.core\_bmad\lens-work\scripts\install.ps1 -AllIDEs
    .\lens.core\_bmad\lens-work\scripts\install.ps1 -IDE cursor -IDE claude
    .\lens.core\_bmad\lens-work\scripts\install.ps1 -Update
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string[]]$IDE,
    [switch]$AllIDEs,
    [switch]$Update,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Paths -------------------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleDir = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))

$SupportedIDEs = @('github-copilot', 'cursor', 'claude', 'codex')

if ($AllIDEs) {
    $IDE = $SupportedIDEs
}
if (-not $IDE -or $IDE.Count -eq 0) {
    $IDE = @('github-copilot')
}

# -- Counters ----------------------------------------------------------------
$script:Created = 0
$script:Skipped = 0
$script:Errors = 0

# -- Helper Functions --------------------------------------------------------

function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "[SKIP] $Msg" -ForegroundColor DarkGray }
function Write-Warn_ { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err { param([string]$Msg) Write-Host "[ERR]  $Msg" -ForegroundColor Red }

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        if ($DryRun) {
            Write-Info "Would create directory: $Path"
        }
        else {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Ok "Created directory: $Path"
        }
    }
}

function Write-AdapterFile {
    param(
        [string]$FilePath,
        [string]$Content
    )

    $relative = $FilePath.Replace($ProjectRoot, '').TrimStart('\', '/')

    if ((Test-Path $FilePath) -and -not $Update) {
        Write-Skip "$relative (exists, use -Update to overwrite)"
        $script:Skipped++
        return
    }

    if ($DryRun) {
        if (Test-Path $FilePath) {
            Write-Info "Would overwrite: $relative"
        }
        else {
            Write-Info "Would create: $relative"
        }
        return
    }

    Ensure-Directory (Split-Path -Parent $FilePath)
    [System.IO.File]::WriteAllText($FilePath, $Content, [System.Text.UTF8Encoding]::new($false))

    if ($Update -and (Test-Path $FilePath)) {
        Write-Ok "Updated: $relative"
    }
    else {
        Write-Ok "Created: $relative"
    }
    $script:Created++
}

# -- Stub Generators ---------------------------------------------------------

function New-GHStubPrompt {
    param(
        [string]$Name,
        [string]$Description,
        [string]$TargetPrompt,
        [string]$Extra = ''
    )

    $extraBlock = if ($Extra) { "`n$Extra" } else { '' }

    return @"
---
model: Claude Sonnet 4.6 (copilot)
description: '$Description'
---

# $Name (Stub)

> **This is a stub.** Load and execute the full prompt from the release module.
> All ``lens.core/_bmad/`` paths in the full prompt are relative to ``lens.core/`` — do NOT resolve paths against the user's main project repo.

``````
Read and follow all instructions in: lens.core/_bmad/lens-work/prompts/$TargetPrompt
``````
$extraBlock
"@
}

function New-CursorCommand {
    param(
        [string]$Name,
        [string]$Description,
        [string]$WorkflowPath
    )
    return @"
---
name: '$Name'
description: '$Description'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @lens.core/_bmad/lens-work/$WorkflowPath, READ its entire contents and follow its directions exactly!
"@
}

function New-ClaudeCommand {
    param(
        [string]$Name,
        [string]$Description,
        [string]$WorkflowPath
    )
    return @"
---
name: '$Name'
description: '$Description'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @lens.core/_bmad/lens-work/$WorkflowPath, READ its entire contents and follow its directions exactly!
"@
}

function New-CodexCommand {
    param(
        [string]$Name,
        [string]$Description,
        [string]$WorkflowPath
    )
    return @"
---
name: '$Name'
description: '$Description'
---

IT IS CRITICAL THAT YOU FOLLOW THIS COMMAND: LOAD the FULL @lens.core/_bmad/lens-work/$WorkflowPath, READ its entire contents and follow its directions exactly!
"@
}

# =============================================================================
# PHASE 1: Output Directory Structure
# =============================================================================

function Install-OutputDirs {
    Write-Info "Creating output directory structure..."
    Ensure-Directory (Join-Path $ProjectRoot '_bmad-output/lens-work')
    Ensure-Directory (Join-Path $ProjectRoot '_bmad-output/lens-work/initiatives')
    Ensure-Directory (Join-Path $ProjectRoot '_bmad-output/lens-work/personal')
}

# =============================================================================
# PHASE 2: GitHub Copilot Adapter
# =============================================================================

function Install-GitHubCopilot {
    Write-Info "Installing GitHub Copilot adapter..."

    $ghDir = Join-Path $ProjectRoot '.github'
    $agentsDir = Join-Path $ghDir 'agents'
    $promptsDir = Join-Path $ghDir 'prompts'

    if (Test-Path (Join-Path $ghDir '.git')) {
        Write-Skip "GitHub Copilot adapter already installed via cloned copilot repo at .github/; skipping generation"
        return
    }

    Ensure-Directory $agentsDir
    Ensure-Directory $promptsDir

    # -- Agent stub --
    $agentContent = @'
```chatagent
---
description: '@lens — LENS Workbench v2: lifecycle routing, git orchestration, phase-aware branch topology, constitution governance'
tools: ['read', 'edit', 'search', 'execute']
---

You must fully embody this agent's persona and follow all activation instructions exactly as specified.

<agent-activation CRITICAL="TRUE">
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

```
'@
    Write-AdapterFile (Join-Path $agentsDir 'bmad-agent-lens-work-lens.agent.md') $agentContent

    # -- Stub prompts --
    $prompts = @(
        @{ File = 'lens-work.onboard.prompt.md'; Name = 'lens-work.onboard'; Desc = 'Bootstrap control repo — detect provider, validate auth, create profile, auto-clone TargetProjects'; Target = 'lens-work.onboard.prompt.md' }
        @{ File = 'lens-work.new-initiative.prompt.md'; Name = 'lens-work.new-initiative'; Desc = 'Create a new initiative (domain, service, or feature)'; Target = 'lens-work.new-initiative.prompt.md' }
        @{ File = 'lens-work.new-domain.prompt.md'; Name = 'lens-work.new-domain'; Desc = 'Create new domain-level initiative with domain-only branch and folder scaffolding'; Target = 'lens-work.new-initiative.prompt.md'; Extra = "`nInvoke with scope: **domain**" }
        @{ File = 'lens-work.new-service.prompt.md'; Name = 'lens-work.new-service'; Desc = 'Create new service-level initiative within a domain'; Target = 'lens-work.new-initiative.prompt.md'; Extra = "`nInvoke with scope: **service**" }
        @{ File = 'lens-work.new-feature.prompt.md'; Name = 'lens-work.new-feature'; Desc = 'Create new feature-level initiative within a service'; Target = 'lens-work.new-initiative.prompt.md'; Extra = "`nInvoke with scope: **feature**" }
        @{ File = 'lens-work.preplan.prompt.md'; Name = 'lens-work.preplan'; Desc = 'Start PrePlan phase — brainstorm, research, product brief (Mary/Analyst, small audience)'; Target = 'lens-work.preplan.prompt.md' }
        @{ File = 'lens-work.businessplan.prompt.md'; Name = 'lens-work.businessplan'; Desc = 'Start BusinessPlan phase — PRD creation, UX design (John/PM + Sally/UX, small audience)'; Target = 'lens-work.businessplan.prompt.md' }
        @{ File = 'lens-work.techplan.prompt.md'; Name = 'lens-work.techplan'; Desc = 'Start TechPlan phase — architecture document, technical decisions (Winston/Architect)'; Target = 'lens-work.techplan.prompt.md' }
        @{ File = 'lens-work.devproposal.prompt.md'; Name = 'lens-work.devproposal'; Desc = 'Start DevProposal phase — epics, stories, readiness check (John/PM, medium audience)'; Target = 'lens-work.devproposal.prompt.md' }
        @{ File = 'lens-work.sprintplan.prompt.md'; Name = 'lens-work.sprintplan'; Desc = 'Start SprintPlan phase — sprint-status, story files (Bob/Scrum Master, large audience)'; Target = 'lens-work.sprintplan.prompt.md' }
        @{ File = 'lens-work.status.prompt.md'; Name = 'lens-work.status'; Desc = 'Show consolidated status report across all active initiatives'; Target = 'lens-work.status.prompt.md' }
        @{ File = 'lens-work.next.prompt.md'; Name = 'lens-work.next'; Desc = 'Recommend next action based on lifecycle state'; Target = 'lens-work.next.prompt.md' }
        @{ File = 'lens-work.switch.prompt.md'; Name = 'lens-work.switch'; Desc = 'Switch to a different initiative via git checkout'; Target = 'lens-work.switch.prompt.md' }
        @{ File = 'lens-work.promote.prompt.md'; Name = 'lens-work.promote'; Desc = 'Promote current audience to next level with gate checks'; Target = 'lens-work.promote.prompt.md' }
        @{ File = 'lens-work.constitution.prompt.md'; Name = 'lens-work.constitution'; Desc = 'Resolve and display constitutional governance'; Target = 'lens-work.constitution.prompt.md' }
        @{ File = 'lens-work.help.prompt.md'; Name = 'lens-work.help'; Desc = 'Show available commands and usage'; Target = 'lens-work.help.prompt.md' }
    )

    foreach ($p in $prompts) {
        $extra = if ($p.ContainsKey('Extra')) { $p.Extra } else { '' }
        $content = New-GHStubPrompt -Name $p.Name -Description $p.Desc -TargetPrompt $p.Target -Extra $extra
        Write-AdapterFile (Join-Path $promptsDir $p.File) $content
    }

    # -- Copilot instructions --
    $instructionsContent = @'
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
'@
    Write-AdapterFile (Join-Path $ghDir 'lens-work-instructions.md') $instructionsContent

    Write-Ok "GitHub Copilot adapter complete"
}

# =============================================================================
# PHASE 3: Cursor Adapter
# =============================================================================

function Install-Cursor {
    Write-Info "Installing Cursor adapter..."

    $cursorDir = Join-Path $ProjectRoot '.cursor/commands'
    Ensure-Directory $cursorDir

    $commands = @(
        @{ File = 'bmad-lens-work-onboard.md'; Name = 'onboard'; Desc = 'Create profile + run bootstrap + auto-clone TargetProjects'; WF = 'workflows/utility/onboard/workflow.md' }
        @{ File = 'bmad-lens-work-init-initiative.md'; Name = 'init-initiative'; Desc = 'Create new initiative (domain/service/feature) with branch topology'; WF = 'workflows/router/init-initiative/workflow.md' }
        @{ File = 'bmad-lens-work-preplan.md'; Name = 'preplan'; Desc = 'Launch PrePlan phase (brainstorm/research/product brief)'; WF = 'workflows/router/preplan/workflow.md' }
        @{ File = 'bmad-lens-work-businessplan.md'; Name = 'businessplan'; Desc = 'Launch BusinessPlan phase (PRD/UX design)'; WF = 'workflows/router/businessplan/workflow.md' }
        @{ File = 'bmad-lens-work-techplan.md'; Name = 'techplan'; Desc = 'Launch TechPlan phase (architecture/technical decisions)'; WF = 'workflows/router/techplan/workflow.md' }
        @{ File = 'bmad-lens-work-devproposal.md'; Name = 'devproposal'; Desc = 'Launch DevProposal phase (epics/stories/readiness check)'; WF = 'workflows/router/devproposal/workflow.md' }
        @{ File = 'bmad-lens-work-sprintplan.md'; Name = 'sprintplan'; Desc = 'Launch SprintPlan phase (sprint-status/story files)'; WF = 'workflows/router/sprintplan/workflow.md' }
        @{ File = 'bmad-lens-work-dev.md'; Name = 'dev'; Desc = 'Delegate to implementation agents in target projects'; WF = 'workflows/router/dev/workflow.md' }
        @{ File = 'bmad-lens-work-status.md'; Name = 'status'; Desc = 'Display current state, blocks, topology, next steps'; WF = 'workflows/utility/status/workflow.md' }
        @{ File = 'bmad-lens-work-next.md'; Name = 'next'; Desc = 'Recommend next action based on lifecycle state'; WF = 'workflows/utility/next/workflow.md' }
        @{ File = 'bmad-lens-work-switch.md'; Name = 'switch'; Desc = 'Switch to different initiative branch'; WF = 'workflows/utility/switch/workflow.md' }
        @{ File = 'bmad-lens-work-help.md'; Name = 'help'; Desc = 'Show available commands and usage reference'; WF = 'workflows/utility/help/workflow.md' }
        @{ File = 'bmad-lens-work-promote.md'; Name = 'promote'; Desc = 'Promote current audience to next tier with gate checks'; WF = 'workflows/core/audience-promotion/workflow.md' }
        @{ File = 'bmad-lens-work-constitution.md'; Name = 'constitution'; Desc = 'Resolve and display constitutional governance'; WF = 'workflows/governance/resolve-constitution/workflow.md' }
        @{ File = 'bmad-lens-work-compliance.md'; Name = 'compliance'; Desc = 'Run constitution compliance check on current initiative'; WF = 'workflows/governance/compliance-check/workflow.md' }
        @{ File = 'bmad-lens-work-sense.md'; Name = 'sense'; Desc = 'Cross-initiative overlap detection on demand'; WF = 'workflows/governance/cross-initiative/workflow.md' }
        @{ File = 'bmad-lens-work-module-management.md'; Name = 'module-management'; Desc = 'Check module version and guide self-service updates'; WF = 'workflows/utility/module-management/workflow.md' }
    )

    foreach ($cmd in $commands) {
        $content = New-CursorCommand -Name $cmd.Name -Description $cmd.Desc -WorkflowPath $cmd.WF
        Write-AdapterFile (Join-Path $cursorDir $cmd.File) $content
    }

    Write-Ok "Cursor adapter complete"
}

# =============================================================================
# PHASE 4: Claude Code Adapter
# =============================================================================

function Install-Claude {
    Write-Info "Installing Claude Code adapter..."

    $claudeDir = Join-Path $ProjectRoot '.claude/commands'
    Ensure-Directory $claudeDir

    $commands = @(
        @{ File = 'bmad-lens-work-onboard.md'; Name = 'onboard'; Desc = 'Create profile + run bootstrap + auto-clone TargetProjects'; WF = 'workflows/utility/onboard/workflow.md' }
        @{ File = 'bmad-lens-work-init-initiative.md'; Name = 'init-initiative'; Desc = 'Create new initiative (domain/service/feature) with branch topology'; WF = 'workflows/router/init-initiative/workflow.md' }
        @{ File = 'bmad-lens-work-preplan.md'; Name = 'preplan'; Desc = 'Launch PrePlan phase (brainstorm/research/product brief)'; WF = 'workflows/router/preplan/workflow.md' }
        @{ File = 'bmad-lens-work-businessplan.md'; Name = 'businessplan'; Desc = 'Launch BusinessPlan phase (PRD/UX design)'; WF = 'workflows/router/businessplan/workflow.md' }
        @{ File = 'bmad-lens-work-techplan.md'; Name = 'techplan'; Desc = 'Launch TechPlan phase (architecture/technical decisions)'; WF = 'workflows/router/techplan/workflow.md' }
        @{ File = 'bmad-lens-work-devproposal.md'; Name = 'devproposal'; Desc = 'Launch DevProposal phase (epics/stories/readiness check)'; WF = 'workflows/router/devproposal/workflow.md' }
        @{ File = 'bmad-lens-work-sprintplan.md'; Name = 'sprintplan'; Desc = 'Launch SprintPlan phase (sprint-status/story files)'; WF = 'workflows/router/sprintplan/workflow.md' }
        @{ File = 'bmad-lens-work-dev.md'; Name = 'dev'; Desc = 'Delegate to implementation agents in target projects'; WF = 'workflows/router/dev/workflow.md' }
        @{ File = 'bmad-lens-work-status.md'; Name = 'status'; Desc = 'Display current state, blocks, topology, next steps'; WF = 'workflows/utility/status/workflow.md' }
        @{ File = 'bmad-lens-work-next.md'; Name = 'next'; Desc = 'Recommend next action based on lifecycle state'; WF = 'workflows/utility/next/workflow.md' }
        @{ File = 'bmad-lens-work-switch.md'; Name = 'switch'; Desc = 'Switch to different initiative branch'; WF = 'workflows/utility/switch/workflow.md' }
        @{ File = 'bmad-lens-work-help.md'; Name = 'help'; Desc = 'Show available commands and usage reference'; WF = 'workflows/utility/help/workflow.md' }
        @{ File = 'bmad-lens-work-promote.md'; Name = 'promote'; Desc = 'Promote current audience to next tier with gate checks'; WF = 'workflows/core/audience-promotion/workflow.md' }
        @{ File = 'bmad-lens-work-constitution.md'; Name = 'constitution'; Desc = 'Resolve and display constitutional governance'; WF = 'workflows/governance/resolve-constitution/workflow.md' }
        @{ File = 'bmad-lens-work-compliance.md'; Name = 'compliance'; Desc = 'Run constitution compliance check on current initiative'; WF = 'workflows/governance/compliance-check/workflow.md' }
        @{ File = 'bmad-lens-work-sense.md'; Name = 'sense'; Desc = 'Cross-initiative overlap detection on demand'; WF = 'workflows/governance/cross-initiative/workflow.md' }
        @{ File = 'bmad-lens-work-module-management.md'; Name = 'module-management'; Desc = 'Check module version and guide self-service updates'; WF = 'workflows/utility/module-management/workflow.md' }
    )

    foreach ($cmd in $commands) {
        $content = New-ClaudeCommand -Name $cmd.Name -Description $cmd.Desc -WorkflowPath $cmd.WF
        Write-AdapterFile (Join-Path $claudeDir $cmd.File) $content
    }

    Write-Ok "Claude Code adapter complete"
}

# =============================================================================
# PHASE 5: Codex CLI Adapter
# =============================================================================

function Install-Codex {
    Write-Info "Installing Codex CLI adapter..."

    # -- AGENTS.md in project root --
    $agentsMdContent = @'
# LENS Workbench — Codex Agent

This project uses the LENS Workbench module for lifecycle routing and git orchestration.

## Module Reference

- **Module path:** `lens.core/_bmad/lens-work/`
- **Agent definition:** `lens.core/_bmad/lens-work/agents/lens.agent.md`
- **Lifecycle contract:** `lens.core/_bmad/lens-work/lifecycle.yaml`
- **Module config:** `lens.core/_bmad/lens-work/module.yaml`

## Activation

1. LOAD the module config from `lens.core/_bmad/lens-work/module.yaml`
2. LOAD the FULL agent definition from `lens.core/_bmad/lens-work/agents/lens.agent.md`
3. READ its entire contents — this contains the complete agent persona, skills, lifecycle routing, and phase-to-agent mapping
4. LOAD the lifecycle contract from `lens.core/_bmad/lens-work/lifecycle.yaml`
5. FOLLOW every activation step in the agent definition precisely

## Available Commands

See `lens.core/_bmad/lens-work/module-help.csv` for the complete command list.

## Skills (path references)

| Skill | Path |
|-------|------|
| git-state | `lens.core/_bmad/lens-work/skills/git-state/SKILL.md` |
| git-orchestration | `lens.core/_bmad/lens-work/skills/git-orchestration/SKILL.md` |
| constitution | `lens.core/_bmad/lens-work/skills/constitution/SKILL.md` |
| sensing | `lens.core/_bmad/lens-work/skills/sensing/SKILL.md` |
| checklist | `lens.core/_bmad/lens-work/skills/checklist/SKILL.md` |
'@
    Write-AdapterFile (Join-Path $ProjectRoot 'AGENTS.md') $agentsMdContent

    # -- .codex/commands/ --
    $codexDir = Join-Path $ProjectRoot '.codex/commands'
    Ensure-Directory $codexDir

    $commands = @(
        @{ File = 'bmad-lens-work-onboard.md'; Name = 'onboard'; Desc = 'Create profile + run bootstrap + auto-clone TargetProjects'; WF = 'workflows/utility/onboard/workflow.md' }
        @{ File = 'bmad-lens-work-init-initiative.md'; Name = 'init-initiative'; Desc = 'Create new initiative (domain/service/feature) with branch topology'; WF = 'workflows/router/init-initiative/workflow.md' }
        @{ File = 'bmad-lens-work-preplan.md'; Name = 'preplan'; Desc = 'Launch PrePlan phase (brainstorm/research/product brief)'; WF = 'workflows/router/preplan/workflow.md' }
        @{ File = 'bmad-lens-work-businessplan.md'; Name = 'businessplan'; Desc = 'Launch BusinessPlan phase (PRD/UX design)'; WF = 'workflows/router/businessplan/workflow.md' }
        @{ File = 'bmad-lens-work-techplan.md'; Name = 'techplan'; Desc = 'Launch TechPlan phase (architecture/technical decisions)'; WF = 'workflows/router/techplan/workflow.md' }
        @{ File = 'bmad-lens-work-devproposal.md'; Name = 'devproposal'; Desc = 'Launch DevProposal phase (epics/stories/readiness check)'; WF = 'workflows/router/devproposal/workflow.md' }
        @{ File = 'bmad-lens-work-sprintplan.md'; Name = 'sprintplan'; Desc = 'Launch SprintPlan phase (sprint-status/story files)'; WF = 'workflows/router/sprintplan/workflow.md' }
        @{ File = 'bmad-lens-work-dev.md'; Name = 'dev'; Desc = 'Delegate to implementation agents in target projects'; WF = 'workflows/router/dev/workflow.md' }
        @{ File = 'bmad-lens-work-status.md'; Name = 'status'; Desc = 'Display current state, blocks, topology, next steps'; WF = 'workflows/utility/status/workflow.md' }
        @{ File = 'bmad-lens-work-next.md'; Name = 'next'; Desc = 'Recommend next action based on lifecycle state'; WF = 'workflows/utility/next/workflow.md' }
        @{ File = 'bmad-lens-work-switch.md'; Name = 'switch'; Desc = 'Switch to different initiative branch'; WF = 'workflows/utility/switch/workflow.md' }
        @{ File = 'bmad-lens-work-help.md'; Name = 'help'; Desc = 'Show available commands and usage reference'; WF = 'workflows/utility/help/workflow.md' }
        @{ File = 'bmad-lens-work-promote.md'; Name = 'promote'; Desc = 'Promote current audience to next tier with gate checks'; WF = 'workflows/core/audience-promotion/workflow.md' }
        @{ File = 'bmad-lens-work-constitution.md'; Name = 'constitution'; Desc = 'Resolve and display constitutional governance'; WF = 'workflows/governance/resolve-constitution/workflow.md' }
        @{ File = 'bmad-lens-work-compliance.md'; Name = 'compliance'; Desc = 'Run constitution compliance check on current initiative'; WF = 'workflows/governance/compliance-check/workflow.md' }
        @{ File = 'bmad-lens-work-sense.md'; Name = 'sense'; Desc = 'Cross-initiative overlap detection on demand'; WF = 'workflows/governance/cross-initiative/workflow.md' }
        @{ File = 'bmad-lens-work-module-management.md'; Name = 'module-management'; Desc = 'Check module version and guide self-service updates'; WF = 'workflows/utility/module-management/workflow.md' }
    )

    foreach ($cmd in $commands) {
        $content = New-CodexCommand -Name $cmd.Name -Description $cmd.Desc -WorkflowPath $cmd.WF
        Write-AdapterFile (Join-Path $codexDir $cmd.File) $content
    }

    Write-Ok "Codex CLI adapter complete"
}

# =============================================================================
# MAIN
# =============================================================================

Write-Host ""
Write-Host "LENS Workbench v2 — Module Installer" -ForegroundColor White
Write-Host "Module: $ModuleDir" -ForegroundColor DarkGray
Write-Host "Target: $ProjectRoot" -ForegroundColor DarkGray
Write-Host ""

if ($Update) {
    Write-Warn_ "Update mode: existing adapter files will be overwritten"
}
if ($DryRun) {
    Write-Warn_ "Dry run: no files will be created"
}

# Phase 1: Output directories
Install-OutputDirs

# Phase 2-4: IDE adapters
foreach ($ideName in $IDE) {
    switch ($ideName) {
        'github-copilot' { Install-GitHubCopilot }
        'cursor' { Install-Cursor }
        'claude' { Install-Claude }
        'codex' { Install-Codex }
        default {
            Write-Err "Unknown IDE: $ideName (supported: $($SupportedIDEs -join ', '))"
            $script:Errors++
        }
    }
}

# Summary
Write-Host ""
Write-Host "Summary" -ForegroundColor White
Write-Host "  Created: $($script:Created)" -ForegroundColor Green
Write-Host "  Skipped: $($script:Skipped)" -ForegroundColor DarkGray
if ($script:Errors -gt 0) {
    Write-Host "  Errors:  $($script:Errors)" -ForegroundColor Red
}
Write-Host ""

if ($script:Errors -gt 0) {
    exit 1
}
