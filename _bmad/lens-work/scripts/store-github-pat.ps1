# store-github-pat.ps1 — Securely store GitHub PATs as environment variables outside of LLM context
# Run this script in a terminal window (NOT inside Copilot/Claude/LLM chat)

$ErrorActionPreference = "Stop"

$InventoryFile = "_bmad-output/lens-work/repo-inventory.yaml"

Write-Host ""
Write-Host "🔐 GitHub PAT Storage (Secure Terminal)" -ForegroundColor Cyan
Write-Host "========================================"
Write-Host ""
Write-Host "⚠️  This script runs outside of LLM context for security." -ForegroundColor Yellow
Write-Host "   Your PAT will NOT be visible to any AI assistant."
Write-Host ""

# Detect GitHub domains from repo inventory
$domains = @()
if (Test-Path $InventoryFile) {
    $content = Get-Content $InventoryFile -Raw
    $matches = [regex]::Matches($content, 'https?://([^/]+)')
    foreach ($m in $matches) {
        $host = $m.Groups[1].Value
        if ($host -match "github" -and $domains -notcontains $host) {
            $domains += $host
        }
    }
}

# Default to github.com if no domains detected
if ($domains.Count -eq 0) {
    $domains = @("github.com")
}

Write-Host "Detected GitHub domain(s):"
foreach ($d in $domains) {
    Write-Host "  • $d"
}
Write-Host ""

$storedCount = 0

foreach ($domain in $domains) {
    Write-Host ""
    Write-Host "──────────────────────────────────────"
    Write-Host "Domain: $domain"
    Write-Host ""

    if ($domain -eq "github.com") {
        Write-Host "  Generate a token at: https://github.com/settings/tokens"
        $envVar = "GITHUB_PAT"
    } else {
        Write-Host "  Generate a token at: https://$domain/settings/tokens"
        $envVar = "GH_ENTERPRISE_TOKEN"
    }
    Write-Host "  Required scopes: repo, read:org"
    Write-Host "  Will be stored as: `$$envVar"
    Write-Host ""

    $secPat = Read-Host "  Enter PAT for $domain (input hidden)" -AsSecureString
    $pat = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPat)
    )

    if ([string]::IsNullOrWhiteSpace($pat)) {
        Write-Host "  ⏭️  Skipped $domain"
        continue
    }

    # Persist as a user-level environment variable (survives reboots)
    [System.Environment]::SetEnvironmentVariable($envVar, $pat, "User")

    # Also set in the current session immediately
    Set-Item -Path "Env:$envVar" -Value $pat

    Write-Host "  ✅ Stored `$$envVar in environment" -ForegroundColor Green
    $storedCount++
}

Write-Host ""
Write-Host "========================================"
Write-Host ""
Write-Host "✅ PATs stored as environment variables" -ForegroundColor Green
Write-Host ""
Write-Host "Verifying stored variables:"

foreach ($domain in $domains) {
    if ($domain -eq "github.com") {
        $envVar = "GITHUB_PAT"
    } else {
        $envVar = "GH_ENTERPRISE_TOKEN"
    }

    $val = [System.Environment]::GetEnvironmentVariable($envVar, "User")
    if (-not [string]::IsNullOrWhiteSpace($val)) {
        if ($val.Length -ge 8) {
            $masked = $val.Substring(0, 4) + "****" + $val.Substring($val.Length - 4)
        } else {
            $masked = "****"
        }
        Write-Host "  ✅ `$$envVar = $masked" -ForegroundColor Green
    } else {
        Write-Host "  ❌ `$$envVar not set" -ForegroundColor Red
    }
}

Write-Host ""
if ($storedCount -gt 0) {
    Write-Host "✅ $storedCount PAT(s) verified." -ForegroundColor Green
    Write-Host ""
    Write-Host "📌 Stored as User-level environment variables."
    Write-Host "   New terminal sessions will have these variables available automatically."
} else {
    Write-Host "⚠️  No PATs were stored." -ForegroundColor Yellow
}
