#Requires -Version 5.1
<#
.SYNOPSIS
    LENS Workbench — GitHub PAT Setup Script

.DESCRIPTION
    Securely collects GitHub Personal Access Tokens outside of any LLM/AI chat context.
    PATs are NEVER entered into Copilot, Claude, or any other AI assistant.
    Sets environment variables only — no files are written.

.USAGE
    cd <project-root>
    .\lens.core\_bmad\lens-work\scripts\store-github-pat.ps1

.OUTPUTS
    Environment variables only: GITHUB_PAT, GH_ENTERPRISE_TOKEN
    (set in current session + persisted to User scope)
    No files are written.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InventoryFile = Join-Path (Get-Location) '_bmad-output\lens-work\repo-inventory.yaml'

# -- Banner ---------------------------------------------------
Write-Host ""
Write-Host "LENS Workbench -- GitHub PAT Setup" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "[SECURITY] " -ForegroundColor Yellow -NoNewline
Write-Host "PATs are set as environment variables only."
Write-Host "  No files are written. Variables are persisted to User scope."
Write-Host ""

# -- Check for already-set environment variables --------------
$EnvVarsFound = @()
if ($env:GITHUB_PAT)          { $EnvVarsFound += 'GITHUB_PAT (github.com)' }
if ($env:GH_ENTERPRISE_TOKEN) { $EnvVarsFound += 'GH_ENTERPRISE_TOKEN (enterprise)' }
if ($env:GH_TOKEN)            { $EnvVarsFound += 'GH_TOKEN (fallback)' }

if ($EnvVarsFound.Count -gt 0) {
    Write-Host "[OK] PAT environment variable(s) already set:" -ForegroundColor Green
    foreach ($ev in $EnvVarsFound) { Write-Host "   - $ev" }
    Write-Host ""
    $Overwrite = Read-Host "  Overwrite existing values? (y/N)"
    if ($Overwrite -notmatch '^[yY]') {
        Write-Host ""
        Write-Host "[OK] Using existing environment variables. Nothing changed." -ForegroundColor Green
        Write-Host ""
        return
    }
    Write-Host ""
}

# -- Detect GitHub domains from repo inventory ----------------
$GithubDomains = @()

if (Test-Path $InventoryFile) {
    $InventoryContent = Get-Content $InventoryFile -Raw -ErrorAction SilentlyContinue
    $RegexMatches = [regex]::Matches($InventoryContent, 'https://([a-zA-Z0-9._-]*github[a-zA-Z0-9._-]*)/')
    $Detected = $RegexMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($d in $Detected) {
        if ($d -notin $GithubDomains) { $GithubDomains += $d }
    }
}

if ('github.com' -notin $GithubDomains) {
    $GithubDomains = @('github.com') + $GithubDomains
}

Write-Host "Detected GitHub domain(s):" -ForegroundColor White
foreach ($d in $GithubDomains) { Write-Host "  - $d" -ForegroundColor Cyan }
Write-Host ""

$ExtraDomain = Read-Host "Add additional GitHub Enterprise domain? (press Enter to skip)"
if ($ExtraDomain.Trim()) { $GithubDomains += $ExtraDomain.Trim() }
Write-Host ""

# -- Collect and export PATs ----------------------------------
$Stored  = 0
$Skipped = 0

foreach ($Domain in $GithubDomains) {
    Write-Host (("--- {0} " -f $Domain) + ("-" * [Math]::Max(0, 40 - $Domain.Length))) -ForegroundColor DarkGray

    if ($Domain -eq 'github.com') {
        $PatUrl  = 'https://github.com/settings/tokens'
        $EnvVar  = 'GITHUB_PAT'
    } else {
        $PatUrl  = "https://$Domain/settings/tokens"
        $EnvVar  = 'GH_ENTERPRISE_TOKEN'
    }

    Write-Host "  Generate token at: " -NoNewline
    Write-Host $PatUrl -ForegroundColor Cyan
    Write-Host "  Required scopes:   " -NoNewline
    Write-Host "repo, read:org" -ForegroundColor Yellow
    Write-Host ""

    $SecurePat = Read-Host "  Enter PAT for $Domain (press Enter to skip)" -AsSecureString
    Write-Host ""

    if ($SecurePat.Length -eq 0) {
        Write-Host "  [SKIP]  Skipped" -ForegroundColor Yellow
        $Skipped++
    } else {
        $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePat)
        try {
            $PatPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
        }

        if ([string]::IsNullOrWhiteSpace($PatPlain)) {
            Write-Host "  [SKIP]  Skipped" -ForegroundColor Yellow
            $Skipped++
        } else {
            Set-Item -Path "Env:\$EnvVar" -Value $PatPlain
            [System.Environment]::SetEnvironmentVariable($EnvVar, $PatPlain, 'User')
            Write-Host "  [OK] $EnvVar set" -ForegroundColor Green
            $Stored++
        }
    }
    Write-Host ""
}

# -- Verify ---------------------------------------------------
Write-Host "Verifying environment variables..." -ForegroundColor White
$VerifyPass = 0
$VerifyFail = 0

foreach ($Domain in $GithubDomains) {
    if ($Domain -eq 'github.com') {
        if ($env:GITHUB_PAT) {
            Write-Host "  [OK] GITHUB_PAT is set (github.com)" -ForegroundColor Green
            $VerifyPass++
        } else {
            Write-Host "  [FAIL] GITHUB_PAT is NOT set" -ForegroundColor Red
            $VerifyFail++
        }
    } else {
        if ($env:GH_ENTERPRISE_TOKEN) {
            Write-Host "  [OK] GH_ENTERPRISE_TOKEN is set ($Domain)" -ForegroundColor Green
            $VerifyPass++
        } else {
            Write-Host "  [FAIL] GH_ENTERPRISE_TOKEN is NOT set" -ForegroundColor Red
            $VerifyFail++
        }
    }
}
Write-Host ""

# -- Summary --------------------------------------------------
Write-Host "====================================" -ForegroundColor DarkGray
Write-Host "Summary" -ForegroundColor White
Write-Host "  Env vars set:      $Stored"
Write-Host "  Env vars verified: $VerifyPass"
if ($VerifyFail -gt 0) { Write-Host "  Env vars failed:   $VerifyFail" -ForegroundColor Red }
Write-Host "  Skipped:           $Skipped"
Write-Host ""

if ($Stored -gt 0) {
    Write-Host "[OK] PAT setup complete! Variables persisted to User scope." -ForegroundColor Green
    Write-Host "  New terminal windows will pick them up automatically." -ForegroundColor DarkGray
} else {
    Write-Host "No PATs were set. Run this script again when ready." -ForegroundColor Yellow
}
Write-Host ""
