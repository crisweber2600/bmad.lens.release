# =============================================================================
# LENS Workbench — Validate Phase Artifacts
#
# PURPOSE:
#   Check that required artifacts for a lifecycle phase exist and are non-empty.
#   Uses lifecycle.yaml as the single source of truth for required artifacts.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\validate-phase-artifacts.ps1 -Phase preplan -LifecyclePath lifecycle.yaml -DocsRoot path
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Phase,

    [Parameter(Mandatory = $true)]
    [string]$LifecyclePath,

    [Parameter(Mandatory = $true)]
    [string]$DocsRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $LifecyclePath)) {
    Write-Host "ERROR: lifecycle.yaml not found: $LifecyclePath" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Extract required artifacts from lifecycle.yaml
# =============================================================================

$lines = Get-Content $LifecyclePath
$inPhases = $false
$inPhase = $false
$inArtifacts = $false
$requiredArtifacts = @()

foreach ($line in $lines) {
    if ($line -match "^phases:") { $inPhases = $true; continue }

    if ($inPhases) {
        if ($line -match "^\s{2}${Phase}:") { $inPhase = $true; continue }

        if ($inPhase -and $line -match "^\s{2}[a-z]" -and $line -notmatch "^\s{4}") {
            $inPhase = $false; $inArtifacts = $false; continue
        }

        if ($inPhase) {
            if ($line -match "^\s*artifacts:") { $inArtifacts = $true; continue }

            if ($inArtifacts) {
                if ($line -match "^\s*-\s+(.+)") {
                    $requiredArtifacts += $Matches[1].Trim()
                } else {
                    $inArtifacts = $false
                }
            }
        }
    }
}

if ($requiredArtifacts.Count -eq 0) {
    if ($Json) {
        Write-Output "{`"phase`":`"$Phase`",`"required`":0,`"found`":0,`"missing`":[],`"status`":`"no_artifacts_defined`"}"
    } else {
        Write-Host "No artifacts defined for phase: $Phase" -ForegroundColor Yellow
    }
    exit 0
}

# =============================================================================
# Check each artifact
# =============================================================================

function Test-Artifact {
    param([string]$Name)

    $candidates = @()
    switch ($Name) {
        "product-brief" {
            $candidates = @("$DocsRoot/product-brief.md")
            $candidates += (Get-ChildItem "$DocsRoot/product-brief-*.md" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
        "research" {
            $candidates = @("$DocsRoot/research.md")
            $candidates += (Get-ChildItem "$DocsRoot/research-*.md" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
        "brainstorm" { $candidates = @("$DocsRoot/brainstorm.md") }
        "prd" { $candidates = @("$DocsRoot/prd.md") }
        "ux-design" { $candidates = @("$DocsRoot/ux-design.md", "$DocsRoot/ux-design-specification.md") }
        "architecture" {
            $candidates = @("$DocsRoot/architecture.md")
            $candidates += (Get-ChildItem "$DocsRoot/*architecture*.md" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
        "epics" { $candidates = @("$DocsRoot/epics.md") }
        "stories" { $candidates = @("$DocsRoot/stories.md") }
        "implementation-readiness" { $candidates = @("$DocsRoot/readiness-checklist.md", "$DocsRoot/implementation-readiness.md") }
        "sprint-status" { $candidates = @("$DocsRoot/sprint-status.yaml", "$DocsRoot/sprint-backlog.md") }
        "story-files" {
            $candidates = (Get-ChildItem "$DocsRoot/dev-story-*.md" -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        }
        "review-report" { $candidates = @("$DocsRoot/review-report.md", "$DocsRoot/adversarial-review.md") }
        default { $candidates = @("$DocsRoot/$Name.md") }
    }

    foreach ($candidate in $candidates) {
        if ((Test-Path $candidate) -and (Get-Item $candidate).Length -gt 0) {
            return $true
        }
    }
    return $false
}

$found = @()
$missing = @()

foreach ($artifact in $requiredArtifacts) {
    if (Test-Artifact $artifact) {
        $found += $artifact
    } else {
        $missing += $artifact
    }
}

# =============================================================================
# Output
# =============================================================================

$exitCode = if ($missing.Count -gt 0) { 1 } else { 0 }

if ($Json) {
    $result = @{
        phase      = $Phase
        required   = $requiredArtifacts.Count
        found      = $found.Count
        missing    = $missing
        found_list = $found
        status     = if ($exitCode -eq 0) { "pass" } else { "fail" }
    }
    $result | ConvertTo-Json -Depth 3
} else {
    if ($exitCode -eq 0) {
        Write-Host "Phase artifacts verified" -ForegroundColor Green
    } else {
        Write-Host "Phase incomplete" -ForegroundColor Red
    }
    Write-Host "  Phase:    $Phase"
    Write-Host "  Required: $($requiredArtifacts.Count)"
    Write-Host "  Found:    $($found.Count)"
    Write-Host "  Missing:  $(if ($missing.Count -gt 0) { $missing -join ', ' } else { 'none' })"
}

exit $exitCode
