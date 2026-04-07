# =============================================================================
# LENS Workbench — Derive Initiative Status
#
# PURPOSE:
#   Derive milestone, phase, PR state, and next-action for a given initiative
#   by scanning branch topology. Outputs structured JSON or human-readable text.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\derive-initiative-status.ps1 -Root <initiative-root> -LifecyclePath <path>
#   .\lens.core\_bmad\lens-work\scripts\derive-initiative-status.ps1 -Root <root> -LifecyclePath <path> -Track <t> -Json
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [string]$LifecyclePath,

    [Parameter(Mandatory = $false)]
    [string]$Track = "",

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Test-BranchExists {
    param([string]$BranchName)
    $null = git rev-parse --verify $BranchName 2>$null
    return $LASTEXITCODE -eq 0
}

# =============================================================================
# Milestone scanning
# =============================================================================

$defaultMilestones = @("techplan", "devproposal", "sprintplan", "dev-ready")
$milestones = $defaultMilestones

$currentMilestone = $null
$activeMilestoneBranch = $null
$completedMilestones = @()

for ($i = $milestones.Count - 1; $i -ge 0; $i--) {
    $ms = $milestones[$i]
    $msBranch = "$Root-$ms"
    if (Test-BranchExists $msBranch) {
        if (-not $currentMilestone) {
            $currentMilestone = $ms
            $activeMilestoneBranch = $msBranch
        }
        $completedMilestones += $ms
    }
}

# =============================================================================
# Phase scanning
# =============================================================================

$defaultPhases = @("preplan", "businessplan", "techplan", "devproposal", "sprintplan")
$currentPhase = $null
$phaseBranch = $null
$pendingAction = "Review branch state"
$prSummary = "0"

if ($currentMilestone) {
    foreach ($phase in $defaultPhases) {
        $pBranch = "$Root-$currentMilestone-$phase"
        if (Test-BranchExists $pBranch) {
            $currentPhase = $phase
            $phaseBranch = $pBranch
        }
    }

    if ($currentPhase) {
        $pendingAction = "Complete phase"
    } else {
        $pendingAction = "Start next phase"
    }
}

# =============================================================================
# Output
# =============================================================================

if ($Json) {
    $result = @{
        initiative          = $Root
        milestone           = $currentMilestone
        milestone_branch    = $activeMilestoneBranch
        phase               = $currentPhase
        phase_branch        = $phaseBranch
        pending_action      = $pendingAction
        pr_summary          = $prSummary
        completed_milestones = $completedMilestones
        track               = if ($Track -ne "") { $Track } else { $null }
    }
    $result | ConvertTo-Json -Depth 3
} else {
    Write-Host "Status derived" -ForegroundColor Green
    Write-Host "  Initiative:  $Root"
    Write-Host "  Milestone:   $($currentMilestone ?? 'none')"
    Write-Host "  Phase:       $($currentPhase ?? 'none')"
    Write-Host "  Action:      $pendingAction"
    Write-Host "  PRs:         $prSummary"
    Write-Host "  Completed:   $($completedMilestones -join ', ')"
}
