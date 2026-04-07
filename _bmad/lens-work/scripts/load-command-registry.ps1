# =============================================================================
# LENS Workbench — Load Command Registry
#
# PURPOSE:
#   Read module-help.csv and group commands by category for /help rendering.
#   Optionally resolve a fuzzy command match for invalid-command recovery.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\load-command-registry.ps1 -CsvPath path\to\module-help.csv
#   .\lens.core\_bmad\lens-work\scripts\load-command-registry.ps1 -CsvPath path -Resolve "/bplan"
#   .\lens.core\_bmad\lens-work\scripts\load-command-registry.ps1 -CsvPath path -Json
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $false)]
    [string]$Resolve = "",

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CsvPath)) {
    Write-Host "ERROR: CSV file not found: $CsvPath" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Parse CSV and classify commands
# =============================================================================

$rows = Import-Csv -Path $CsvPath
$commands = @()

foreach ($row in $rows) {
    $displayName = $row.'display-name'
    $menuCode = $row.'menu-code'
    $desc = $row.description
    $phase = $row.phase

    # Determine render group based on phase
    $group = "utility"
    switch -Regex ($phase) {
        "^phase-[1-5]$" { $group = "lifecycle" }
        "^phase-express$" { $group = "lifecycle" }
        "^delegation$" { $group = "lifecycle" }
    }

    # Navigation commands by code
    if ($menuCode -in @("SW", "ST", "NX", "DS", "NI")) {
        $group = "navigation"
    }

    # Derive user command from display name
    $userCmd = "/" + ($displayName.ToLower() -replace ' ', '-')

    $commands += [PSCustomObject]@{
        Command     = $userCmd
        Code        = $menuCode
        Description = $desc
        Group       = $group
        Phase       = $phase
    }
}

if ($commands.Count -eq 0) {
    Write-Host "ERROR: module-help.csv is empty or unparseable" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Resolve fuzzy command match (if requested)
# =============================================================================

$closestMatch = $null
$matchType = ""

if ($Resolve -ne "") {
    $resolveLower = $Resolve.ToLower()
    if (-not $resolveLower.StartsWith("/")) { $resolveLower = "/$resolveLower" }

    # 1. Exact match
    foreach ($cmd in $commands) {
        if ($cmd.Command -eq $resolveLower) {
            $closestMatch = $cmd
            $matchType = "exact"
            break
        }
    }

    # 2. Prefix match
    if (-not $closestMatch) {
        foreach ($cmd in $commands) {
            if ($cmd.Command.StartsWith($resolveLower) -or $resolveLower.StartsWith($cmd.Command)) {
                $closestMatch = $cmd
                $matchType = "prefix"
                break
            }
        }
    }

    # 3. Normalized match (remove hyphens and slashes)
    if (-not $closestMatch) {
        $normRequest = $resolveLower -replace '[/-]', ''
        foreach ($cmd in $commands) {
            $normCmd = $cmd.Command -replace '[/-]', ''
            if ($normCmd -eq $normRequest) {
                $closestMatch = $cmd
                $matchType = "normalized"
                break
            }
        }
    }
}

# =============================================================================
# Output
# =============================================================================

if ($Json) {
    $entries = $commands | ForEach-Object {
        @{ command = $_.Command; code = $_.Code; description = $_.Description; group = $_.Group }
    }

    $matchObj = $null
    if ($closestMatch) {
        $matchObj = @{ command = $closestMatch.Command; group = $closestMatch.Group; type = $matchType }
    }

    @{ commands = $entries; count = $commands.Count; match = $matchObj } | ConvertTo-Json -Depth 3
} else {
    Write-Host "Command registry loaded" -ForegroundColor Green
    Write-Host "  Commands: $($commands.Count)"

    $navCount = ($commands | Where-Object { $_.Group -eq "navigation" }).Count
    $lifeCount = ($commands | Where-Object { $_.Group -eq "lifecycle" }).Count
    $utilCount = ($commands | Where-Object { $_.Group -eq "utility" }).Count

    Write-Host "  Groups: navigation($navCount), lifecycle($lifeCount), utility($utilCount)"

    if ($Resolve -ne "") {
        if ($closestMatch) {
            Write-Host "  Recovery: $($closestMatch.Command) ($matchType match, $($closestMatch.Group))" -ForegroundColor Cyan
        } else {
            Write-Host "  Recovery: no match for '$Resolve'" -ForegroundColor Yellow
        }
    }
}
