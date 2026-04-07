# =============================================================================
# LENS Workbench — Bootstrap Target Projects
#
# PURPOSE:
#   Clone or verify inventory-listed repositories from a governance
#   repo-inventory.yaml file into TargetProjects.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\bootstrap-target-projects.ps1 -InventoryPath path [-Json]
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InventoryPath,

    [Parameter(Mandatory = $false)]
    [string]$TargetRoot = "TargetProjects",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InventoryPath)) {
    Write-Host "ERROR: Inventory file not found: $InventoryPath" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Parse inventory YAML
# =============================================================================

$lines = Get-Content $InventoryPath
$results = @()

$currentName = ""
$currentUrl = ""
$currentPath = ""

function Flush-Entry {
    if ([string]::IsNullOrEmpty($script:currentName) -and [string]::IsNullOrEmpty($script:currentUrl)) { return }

    $repoName = if ($script:currentName) { $script:currentName } else { "unnamed" }
    $repoPath = $script:currentPath
    $repoUrl = $script:currentUrl

    if ([string]::IsNullOrEmpty($repoPath) -and $script:currentName) {
        $repoPath = Join-Path $TargetRoot $script:currentName
    }

    if ([string]::IsNullOrEmpty($repoPath)) {
        $script:results += [PSCustomObject]@{ Name = $repoName; Action = "skip"; Status = "missing path" }
    } elseif (Test-Path (Join-Path $repoPath ".git")) {
        $script:results += [PSCustomObject]@{ Name = $repoName; Action = "verify"; Status = "present" }
    } elseif (-not [string]::IsNullOrEmpty($repoUrl)) {
        if ($DryRun) {
            $script:results += [PSCustomObject]@{ Name = $repoName; Action = "would-clone"; Status = "planned" }
        } else {
            try {
                git clone $repoUrl $repoPath 2>$null
                $script:results += [PSCustomObject]@{ Name = $repoName; Action = "clone"; Status = "cloned" }
            } catch {
                $script:results += [PSCustomObject]@{ Name = $repoName; Action = "clone"; Status = "failed" }
            }
        }
    } else {
        $script:results += [PSCustomObject]@{ Name = $repoName; Action = "skip"; Status = "missing remote" }
    }

    $script:currentName = ""
    $script:currentUrl = ""
    $script:currentPath = ""
}

foreach ($line in $lines) {
    if ($line -match "^\s*#" -or $line -match "^\s*$") { continue }

    if ($line -match "^\s*-\s") {
        Flush-Entry
    }

    if ($line -match "name:\s*(.+)") {
        $currentName = $Matches[1].Trim().Trim('"', "'")
    } elseif ($line -match "(remote_url|repo_url|remote|url):\s*(.+)") {
        $currentUrl = $Matches[2].Trim().Trim('"', "'")
    } elseif ($line -match "(local_path|clone_path|path):\s*(.+)") {
        $currentPath = $Matches[2].Trim().Trim('"', "'")
    }
}

Flush-Entry

# =============================================================================
# Output
# =============================================================================

if ($Json) {
    $entries = $results | ForEach-Object {
        @{ name = $_.Name; action = $_.Action; status = $_.Status }
    }
    @{ entries = $entries; count = $results.Count; dry_run = $DryRun.IsPresent } | ConvertTo-Json -Depth 3
} else {
    Write-Host "Bootstrap complete" -ForegroundColor Green
    Write-Host "  Entries processed: $($results.Count)"
    Write-Host "  Mode: $(if ($DryRun) { 'dry-run' } else { 'live' })"

    foreach ($r in $results) {
        $icon = switch ($r.Status) {
            "present" { "[OK]" }
            "cloned" { "[OK]" }
            "planned" { "[PLAN]" }
            "failed" { "[FAIL]" }
            default { "[WARN]" }
        }
        Write-Host "    $icon $($r.Name) ($($r.Action): $($r.Status))"
    }
}
