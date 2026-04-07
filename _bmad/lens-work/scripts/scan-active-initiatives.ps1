# =============================================================================
# LENS Workbench — Scan Active Initiatives (PowerShell)
#
# PURPOSE:
#   Discover active initiatives by scanning committed initiative-state.yaml
#   files under _bmad-output/lens-work/initiatives/. Replaces per-session
#   agent reasoning with deterministic file enumeration.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\scan-active-initiatives.ps1
#   .\lens.core\_bmad\lens-work\scripts\scan-active-initiatives.ps1 -Domain foo
#   .\lens.core\_bmad\lens-work\scripts\scan-active-initiatives.ps1 -Json
#
# =============================================================================

[CmdletBinding()]
param(
    [string]$Domain = "",
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$InitiativesDir = Join-Path $ProjectRoot "_bmad-output/lens-work/initiatives"

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

Set-Location $ProjectRoot

# =============================================================================
# Discover initiative-state.yaml files
# =============================================================================

if (-not (Test-Path $InitiativesDir)) {
    if ($Json) {
        Write-Output '{"initiatives":[],"count":0,"empty":true}'
    } else {
        Write-Host "i  No initiatives directory found." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Get started:"
        Write-Host "  - /new-domain {name}      - Create a domain-level initiative"
        Write-Host "  - /new-service {d}/{s}    - Create a service-level initiative"
        Write-Host "  - /new-feature {d}/{s}/{f} - Create a feature-level initiative"
    }
    exit 0
}

$stateFiles = Get-ChildItem -Path $InitiativesDir -Recurse -Filter "initiative-state.yaml" -ErrorAction SilentlyContinue

if (-not $stateFiles -or $stateFiles.Count -eq 0) {
    $configFiles = Get-ChildItem -Path $InitiativesDir -Recurse -Filter "*.yaml" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "initiative-state.yaml" }

    if (-not $configFiles -or $configFiles.Count -eq 0) {
        if ($Json) {
            Write-Output '{"initiatives":[],"count":0,"empty":true}'
        } else {
            Write-Host "i  No active initiatives." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Get started:"
            Write-Host "  - /new-domain {name}      - Create a domain-level initiative"
            Write-Host "  - /new-service {d}/{s}    - Create a service-level initiative"
            Write-Host "  - /new-feature {d}/{s}/{f} - Create a feature-level initiative"
        }
        exit 0
    }
}

# =============================================================================
# Parse each initiative-state.yaml
# =============================================================================

$initiatives = @()

foreach ($stateFile in $stateFiles) {
    $relPath = $stateFile.FullName.Substring($InitiativesDir.Length + 1).Replace("\", "/")
    $dirPath = Split-Path $relPath -Parent
    $segments = $dirPath -split "/"

    $initDomain = $segments[0]
    $initService = ""
    $initFeature = ""
    $scope = "domain"

    if ($segments.Count -ge 3) {
        $initService = $segments[1]
        $initFeature = $segments[2]
        $scope = "feature"
    } elseif ($segments.Count -ge 2) {
        $initService = $segments[1]
        $scope = "service"
    }

    # Apply domain filter
    if ($Domain -and $initDomain -ne $Domain) { continue }

    # Read lifecycle_status
    $content = Get-Content $stateFile.FullName -Raw -ErrorAction SilentlyContinue
    $lifecycleStatus = "unknown"
    if ($content -match '(?m)^lifecycle_status:\s*(.+)$') {
        $lifecycleStatus = $Matches[1].Trim().Trim('"')
    }

    # Read initiative_root
    $initRoot = ""
    if ($content -match '(?m)^initiative_root:\s*(.+)$') {
        $initRoot = $Matches[1].Trim().Trim('"')
    }
    if (-not $initRoot) {
        if ($scope -eq "feature") { $initRoot = "$initDomain-$initService-$initFeature" }
        elseif ($scope -eq "service") { $initRoot = "$initDomain-$initService" }
        else { $initRoot = $initDomain }
    }

    # Read track
    $track = ""
    if ($content -match '(?m)^track:\s*(.+)$') {
        $track = $Matches[1].Trim().Trim('"')
    }

    # Only include active initiatives
    if ($lifecycleStatus -ne "active" -and $lifecycleStatus -ne "unknown") { continue }

    $initiatives += [PSCustomObject]@{
        Root    = $initRoot
        Domain  = $initDomain
        Service = $initService
        Scope   = $scope
        Track   = $track
    }
}

# =============================================================================
# Output
# =============================================================================

if ($initiatives.Count -eq 0) {
    if ($Json) {
        Write-Output '{"initiatives":[],"count":0,"empty":true}'
    } else {
        Write-Host "i  No active initiatives." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Get started:"
        Write-Host "  - /new-domain {name}      - Create a domain-level initiative"
        Write-Host "  - /new-service {d}/{s}    - Create a service-level initiative"
        Write-Host "  - /new-feature {d}/{s}/{f} - Create a feature-level initiative"
    }
    exit 0
}

if ($Json) {
    $jsonEntries = $initiatives | ForEach-Object {
        $svc = if ($_.Service) { "`"$($_.Service)`"" } else { "null" }
        "{`"root`":`"$($_.Root)`",`"domain`":`"$($_.Domain)`",`"service`":$svc,`"scope`":`"$($_.Scope)`",`"track`":`"$($_.Track)`"}"
    }
    $joined = $jsonEntries -join ","
    Write-Output "{`"initiatives`":[$joined],`"count`":$($initiatives.Count),`"empty`":false}"
} else {
    Write-Host "OK Initiative inventory complete" -ForegroundColor Green
    Write-Host "--- Initiative roots: $($initiatives.Count)"
    Write-Host ""
    "{0,-25} {1,-12} {2,-12} {3,-10} {4}" -f "  ROOT", "DOMAIN", "SERVICE", "SCOPE", "TRACK"
    "{0,-25} {1,-12} {2,-12} {3,-10} {4}" -f "  ----", "------", "-------", "-----", "-----"
    foreach ($init in $initiatives) {
        $svc = if ($init.Service) { $init.Service } else { "-" }
        $trk = if ($init.Track) { $init.Track } else { "-" }
        "{0,-25} {1,-12} {2,-12} {3,-10} {4}" -f "  $($init.Root)", $init.Domain, $svc, $init.Scope, $trk
    }
}
