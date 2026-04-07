# =============================================================================
# LENS Workbench — Validate Feature Move
#
# PURPOSE:
#   Validate that a feature can be safely moved to a new domain/service.
#   Checks for conflicts, uncommitted changes, and current scope.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\validate-feature-move.ps1 `
#       -Feature <name> -OldDomain <d> -OldService <s> `
#       -NewDomain <d> -NewService <s> -InitiativesRoot <path> [-Json]
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Feature,
    [Parameter(Mandatory = $true)][string]$OldDomain,
    [Parameter(Mandatory = $true)][string]$OldService,
    [Parameter(Mandatory = $true)][string]$NewDomain,
    [Parameter(Mandatory = $true)][string]$NewService,
    [Parameter(Mandatory = $true)][string]$InitiativesRoot,
    [Parameter(Mandatory = $false)][switch]$Json
)

$ErrorActionPreference = "Stop"

# Sanitize inputs
$NewDomain = ($NewDomain.ToLower() -replace '[^a-z0-9-]', '')
$NewService = ($NewService.ToLower() -replace '[^a-z0-9-]', '')

# =============================================================================
# Validation checks
# =============================================================================

$errors = @()
$warnings = @()

# 1. Check source exists
$oldPath = Join-Path $InitiativesRoot "$OldDomain/$OldService"
if (-not (Test-Path $oldPath)) {
    $errors += "Source path does not exist: $oldPath"
}

# 2. Check target conflict
$newPath = Join-Path $InitiativesRoot "$NewDomain/$NewService"
$targetConfig = Join-Path $newPath "$Feature.yaml"
if (Test-Path $targetConfig) {
    $errors += "Feature '$Feature' already exists at $NewDomain/$NewService"
}

# 3. Check uncommitted changes
$gitStatus = git diff --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
    $warnings += "Uncommitted changes detected - commit or stash before moving"
}

# 4. Check feature config exists
$sourceConfig = Join-Path $oldPath "$Feature.yaml"
if (-not (Test-Path $sourceConfig)) {
    $errors += "Feature config not found: $sourceConfig"
}

# 5. Same location check
if ($OldDomain -eq $NewDomain -and $OldService -eq $NewService) {
    $errors += "Source and target are the same ($OldDomain/$OldService)"
}

# =============================================================================
# Build result
# =============================================================================

$safe = $errors.Count -eq 0
$filesToMove = @()

if (Test-Path (Join-Path $oldPath "$Feature.yaml")) {
    $filesToMove += "$oldPath/$Feature.yaml -> $newPath/$Feature.yaml"
}
$featureDir = Join-Path $oldPath $Feature
if (Test-Path $featureDir -PathType Container) {
    $filesToMove += "$featureDir/ -> $newPath/$Feature/"
}

# =============================================================================
# Output
# =============================================================================

if ($Json) {
    @{
        safe     = $safe
        feature  = $Feature
        from     = "$OldDomain/$OldService"
        to       = "$NewDomain/$NewService"
        errors   = $errors
        warnings = $warnings
        files    = $filesToMove
    } | ConvertTo-Json -Depth 3
} else {
    if ($safe) {
        Write-Host "Move is safe" -ForegroundColor Green
    } else {
        Write-Host "Move is blocked" -ForegroundColor Red
    }
    Write-Host "  Feature: $Feature"
    Write-Host "  From:    $OldDomain/$OldService"
    Write-Host "  To:      $NewDomain/$NewService"

    if ($errors.Count -gt 0) {
        Write-Host "  Errors:" -ForegroundColor Red
        foreach ($err in $errors) { Write-Host "    $err" }
    }
    if ($warnings.Count -gt 0) {
        Write-Host "  Warnings:" -ForegroundColor Yellow
        foreach ($warn in $warnings) { Write-Host "    $warn" }
    }
    Write-Host "  Files: $($filesToMove.Count) to relocate"
}

if ($safe) { exit 0 } else { exit 1 }
