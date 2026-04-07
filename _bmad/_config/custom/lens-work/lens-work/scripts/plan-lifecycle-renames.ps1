# =============================================================================
# LENS Workbench — Plan Lifecycle Renames
#
# PURPOSE:
#   Scan local branches for v2 audience-based naming, compute a v3 milestone
#   rename plan. Outputs rename map, phase branch advisories, and initiative roots.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\plan-lifecycle-renames.ps1 [-Apply] [-Json]
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Apply,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# =============================================================================
# Audience-to-Milestone mapping (v2 -> v3)
# =============================================================================

$audienceMap = @{
    "small"  = "techplan"
    "medium" = "devproposal"
    "large"  = "sprintplan"
    "base"   = "dev-ready"
}
$audienceTokens = @("small", "medium", "large", "base")

# =============================================================================
# Scan branches
# =============================================================================

$branches = git branch --format='%(refname:short)' 2>$null
if (-not $branches) {
    Write-Host "No local branches found" -ForegroundColor Yellow
    exit 0
}

$renames = @()
$advisories = @()
$initRoots = @()

foreach ($branch in $branches) {
    $branch = $branch.Trim()
    if ([string]::IsNullOrEmpty($branch)) { continue }

    $segments = $branch -split '-'

    # Find last occurrence of an audience token
    $audienceIdx = -1
    for ($i = $segments.Count - 1; $i -ge 0; $i--) {
        if ($audienceTokens -contains $segments[$i]) {
            $audienceIdx = $i
            break
        }
    }

    if ($audienceIdx -eq -1) { continue }

    $audienceToken = $segments[$audienceIdx]
    $milestoneToken = $audienceMap[$audienceToken]

    # Extract initiative root
    $initRoot = ($segments[0..($audienceIdx - 1)]) -join '-'

    if ($initRoots -notcontains $initRoot) {
        $initRoots += $initRoot
    }

    # Determine if phase branch
    $trailingCount = $segments.Count - $audienceIdx - 1

    if ($trailingCount -eq 0) {
        $newName = "$initRoot-$milestoneToken"
        $renames += [PSCustomObject]@{
            From = $branch
            To   = $newName
            Type = "milestone-root"
        }
    } else {
        $advisories += "$branch - v2 phase branch. Verify merged, then delete."
    }
}

# =============================================================================
# Apply renames (if -Apply)
# =============================================================================

$applied = 0
if ($Apply -and $renames.Count -gt 0) {
    foreach ($rename in $renames) {
        $exists = git rev-parse --verify $rename.To 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Target branch already exists: $($rename.To) (skipping $($rename.From))" -ForegroundColor Yellow
            continue
        }
        git branch -m $rename.From $rename.To 2>$null
        if ($LASTEXITCODE -eq 0) { $applied++ }
    }
}

# =============================================================================
# Output
# =============================================================================

if ($Json) {
    $result = @{
        renames          = $renames | ForEach-Object { @{ from = $_.From; to = $_.To; type = $_.Type } }
        advisories       = $advisories
        initiative_roots = $initRoots
        applied          = $applied
        dry_run          = -not $Apply.IsPresent
    }
    $result | ConvertTo-Json -Depth 3
} else {
    Write-Host "Migration plan complete" -ForegroundColor Green
    Write-Host "  Branch renames: $($renames.Count)"
    Write-Host "  Phase advisories: $($advisories.Count)"
    Write-Host "  Initiative roots: $($initRoots.Count)"

    if ($renames.Count -gt 0) {
        Write-Host ""
        Write-Host "Renames:" -ForegroundColor Cyan
        foreach ($r in $renames) {
            Write-Host "  $($r.From) -> $($r.To) ($($r.Type))"
        }
    }

    if ($advisories.Count -gt 0) {
        Write-Host ""
        Write-Host "Phase advisories:" -ForegroundColor Yellow
        foreach ($adv in $advisories) {
            Write-Host "  $adv"
        }
    }

    if ($Apply) {
        Write-Host ""
        Write-Host "  Applied: $applied"
    } else {
        Write-Host ""
        Write-Host "  Mode: dry-run (use -Apply to execute)"
    }
}
