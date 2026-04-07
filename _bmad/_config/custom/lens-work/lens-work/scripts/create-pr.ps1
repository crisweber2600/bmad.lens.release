#Requires -Version 5.1
<#
.SYNOPSIS
    LENS Workbench — Generic PR creation helper

.DESCRIPTION
    Creates a PR between any two branches using GitHub API + PAT or manual URL.
    Supports both GitHub and Azure DevOps.
    Never relies on 'gh' CLI — always uses API via PAT or provides manual instructions.

.USAGE
    .\lens.core\_bmad\lens-work\scripts\create-pr.ps1 -SourceBranch my-feature -TargetBranch main -Title "My PR" -Body "PR description"
    .\lens.core\_bmad\lens-work\scripts\create-pr.ps1 -SourceBranch preplan-phase -TargetBranch small-audience -Title "[PHASE] PrePlan complete"

.PARAMETER SourceBranch
    The source branch to merge from (required)

.PARAMETER TargetBranch
    The target branch to merge into (required)

.PARAMETER Title
    PR title (required)

.PARAMETER Body
    PR body/description (optional)

.PARAMETER Remote
    Git remote name (default: origin)

.PARAMETER UrlOnly
    Only print the PR creation URL, don't actually create PR

.PARAMETER Timeout
    Timeout in seconds for API calls (default: 30)

#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceBranch,

    [Parameter(Mandatory = $true)]
    [string]$TargetBranch,

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$Body = "",

    [string]$Remote = 'origin',

    [switch]$UrlOnly,

    [int]$Timeout = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [switch]$AllowFailure
    )

    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & git @Args 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prev

    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "git $($Args -join ' ') failed: $output"
    }
    return $output
}

function Get-RemoteUrl {
    param([string]$RemoteName)
    return (Invoke-Git -Args @('remote', 'get-url', $RemoteName)).Trim()
}

function Parse-RemoteUrl {
    param([string]$RemoteUrl)

    $info = [ordered]@{
        Host = $null
        Org = $null
        Project = $null
        Repo = $null
        Platform = 'unknown'
    }

    # GitHub HTTPS: https://github.com/org/repo or https://github-enterprise-host/org/repo
    if ($RemoteUrl -match '^https?://([^/]+)/([^/]+)/([^/]+?)(\.git)?$') {
        $info.Host = $Matches[1]
        $info.Org = $Matches[2]
        $info.Repo = $Matches[3]
        $info.Platform = if ($info.Host -match 'github\.com' -or $info.Host -match 'github') { 'github' } else { 'unknown' }
        return $info
    }

    # GitHub SSH: git@github.com:org/repo
    if ($RemoteUrl -match '^git@([^:]+):([^/]+)/([^/]+?)(\.git)?$') {
        $info.Host = $Matches[1]
        $info.Org = $Matches[2]
        $info.Repo = $Matches[3]
        $info.Platform = if ($info.Host -match 'github\.com' -or $info.Host -match 'github') { 'github' } else { 'unknown' }
        return $info
    }

    # Azure DevOps HTTPS: https://dev.azure.com/org/project/_git/repo
    if ($RemoteUrl -match '^https?://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+?)(\.git)?$') {
        $info.Host = 'dev.azure.com'
        $info.Org = $Matches[1]
        $info.Project = $Matches[2]
        $info.Repo = $Matches[3]
        $info.Platform = 'azdo'
        return $info
    }

    # Azure DevOps SSH: git@ssh.dev.azure.com:v3/org/project/repo
    if ($RemoteUrl -match '^git@ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/([^/]+?)(\.git)?$') {
        $info.Host = 'dev.azure.com'
        $info.Org = $Matches[1]
        $info.Project = $Matches[2]
        $info.Repo = $Matches[3]
        $info.Platform = 'azdo'
        return $info
    }

    return $info
}

function Get-PrUrl {
    param(
        [hashtable]$RemoteInfo,
        [string]$Source,
        [string]$Target
    )

    if ($RemoteInfo.Platform -eq 'github' -and $RemoteInfo.Host -and $RemoteInfo.Org -and $RemoteInfo.Repo) {
        return "https://$($RemoteInfo.Host)/$($RemoteInfo.Org)/$($RemoteInfo.Repo)/compare/$Target...$Source"
    }

    if ($RemoteInfo.Platform -eq 'azdo' -and $RemoteInfo.Org -and $RemoteInfo.Project -and $RemoteInfo.Repo) {
        return "https://dev.azure.com/$($RemoteInfo.Org)/$($RemoteInfo.Project)/_git/$($RemoteInfo.Repo)/pullrequestcreate?sourceRef=$Source&targetRef=$Target"
    }

    return "MANUAL: Create PR from $Source -> $Target"
}

function Get-ProfileFile {
    $repoRoot = (Invoke-Git -Args @('rev-parse', '--show-toplevel')).Trim()
    return Join-Path $repoRoot '_bmad-output\lens-work\personal\profile.yaml'
}

function Get-ProfilePat {
    param(
        [string]$Host,
        [string]$ProfileFile
    )

    if (-not $Host -or -not (Test-Path $ProfileFile)) {
        return $null
    }

    $ProfileContent = Get-Content $ProfileFile -Raw -ErrorAction SilentlyContinue
    if (-not $ProfileContent) {
        return $null
    }

    $InCredentials = $false
    $CurrentHost = $null
    $CurrentPat = $null

    foreach ($Line in $ProfileContent -split "`n") {
        $Line = $Line.Trim()

        if ($Line -eq 'git_credentials:') {
            $InCredentials = $true
            continue
        }

        if ($InCredentials) {
            if ($Line -match '^\s*-\s+host:\s*(.+)$') {
                $CurrentHost = $Matches[1]
                $CurrentPat = $null
            } elseif ($Line -match '^\s*pat:\s*(.+)$') {
                $CurrentPat = $Matches[1]
                if ($CurrentHost -eq $Host) {
                    return $CurrentPat
                }
            }
        }
    }

    return $null
}

function Invoke-GitHubPrCreate {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$RemoteInfo,
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [string]$Body = "",
        [string]$Pat = $null,
        [int]$Timeout = 30
    )

    # Attempt API creation if PAT is available
    if ($Pat) {
        try {
            $ApiBase = if ($RemoteInfo.Host -eq 'github.com') { 'https://api.github.com' } else { "https://$($RemoteInfo.Host)/api/v3" }
            $RepoName = "$($RemoteInfo.Org)/$($RemoteInfo.Repo)"

            $Headers = @{
                Authorization  = "token $Pat"
                'Content-Type' = 'application/json'
                Accept         = 'application/vnd.github+json'
            }

            $Payload = @{
                head  = $Source
                base  = $Target
                title = $Title
                body  = $Body
            } | ConvertTo-Json -Compress

            $Result = Invoke-RestMethod -Uri "$ApiBase/repos/$RepoName/pulls" `
                -Method Post `
                -Headers $Headers `
                -Body $Payload `
                -TimeoutSec $Timeout `
                -ErrorAction Stop

            return @{
                Success = $true
                Url     = $Result.html_url
                Number  = $Result.number
                Id      = $Result.id
            }
        } catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            if ($StatusCode -eq 422) {
                Write-Host "  [WARN]  PR may already exist — HTTP 422" -ForegroundColor Yellow

                try {
                    $Head = [uri]::EscapeDataString("$($RemoteInfo.Org):$Source")
                    $Base = [uri]::EscapeDataString($Target)
                    $ExistingPulls = Invoke-RestMethod -Uri "$ApiBase/repos/$RepoName/pulls?head=$Head&base=$Base&state=open" `
                        -Method Get `
                        -Headers $Headers `
                        -TimeoutSec $Timeout `
                        -ErrorAction Stop

                    if ($ExistingPulls -is [System.Array]) {
                        $ExistingPull = $ExistingPulls | Select-Object -First 1
                    } else {
                        $ExistingPull = $ExistingPulls
                    }

                    if ($ExistingPull -and $ExistingPull.html_url) {
                        Write-Host "  [INFO]  Existing PR found: $($ExistingPull.html_url)" -ForegroundColor Cyan
                        return @{
                            Success  = $true
                            Url      = $ExistingPull.html_url
                            Number   = $ExistingPull.number
                            Id       = $ExistingPull.id
                            Existing = $true
                        }
                    }
                } catch {
                    Write-Host "  [WARN]  Unable to resolve existing PR after HTTP 422" -ForegroundColor Yellow
                }

                return @{
                    Success  = $false
                    Url      = Get-PrUrl -RemoteInfo $RemoteInfo -Source $Source -Target $Target
                    Existing = $true
                    Fallback = $true
                    Error    = $_.Exception.Message
                }
            } else {
                Write-Host "  [ERROR] PR creation failed — HTTP $StatusCode" -ForegroundColor Red
                Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            }
            return @{
                Success = $false
                Url     = $null
                Error   = $_.Exception.Message
            }
        }
    }

    # Fall back to manual URL
    Write-Host "  [INFO]  No PAT available — providing manual PR URL" -ForegroundColor Cyan
    return @{
        Success = $false
        Url     = Get-PrUrl -RemoteInfo $RemoteInfo -Source $Source -Target $Target
        Manual  = $true
    }
}

# ============================================================================
# MAIN
# ============================================================================

try {
    # Get remote URL and parse
    $RemoteUrl = Get-RemoteUrl -RemoteName $Remote
    $RemoteInfo = Parse-RemoteUrl -RemoteUrl $RemoteUrl

    if ($RemoteInfo.Platform -eq 'unknown' -or -not $RemoteInfo.Host) {
        throw "Unable to parse remote URL: $RemoteUrl"
    }

    Write-Host "📋 LENS PR Creation" -ForegroundColor Cyan
    Write-Host "  Source:  $SourceBranch" -ForegroundColor White
    Write-Host "  Target:  $TargetBranch" -ForegroundColor White
    Write-Host "  Title:   $Title" -ForegroundColor White
    Write-Host "  Platform: $($RemoteInfo.Platform)" -ForegroundColor Cyan
    Write-Host ""

    # If UrlOnly, just show the comparison URL
    if ($UrlOnly) {
        $Url = Get-PrUrl -RemoteInfo $RemoteInfo -Source $SourceBranch -Target $TargetBranch
        Write-Host "🔗 PR URL:" -ForegroundColor Green
        Write-Host "   $Url" -ForegroundColor Cyan
        return $Url
    }

    # Try to get PAT from profile or environment
    $Pat = $null
    if ($RemoteInfo.Host) {
        $ProfileFile = Get-ProfileFile
        $Pat = Get-ProfilePat -Host $RemoteInfo.Host -ProfileFile $ProfileFile

        if (-not $Pat) {
            $PatEnvVar = "GITHUB_TOKEN", "GH_TOKEN" | Where-Object { [Environment]::GetEnvironmentVariable($_) } | Select-Object -First 1
            if ($PatEnvVar) {
                $Pat = [Environment]::GetEnvironmentVariable($PatEnvVar)
                Write-Host "  [INFO]  PAT loaded from environment: $PatEnvVar" -ForegroundColor Cyan
            }
        }
    }

    # Create PR based on platform
    if ($RemoteInfo.Platform -eq 'github') {
        $Result = Invoke-GitHubPrCreate -RemoteInfo $RemoteInfo `
            -Source $SourceBranch `
            -Target $TargetBranch `
            -Title $Title `
            -Body $Body `
            -Pat $Pat `
            -Timeout $Timeout

        if ($Result.Success) {
            Write-Host "✅ PR created successfully" -ForegroundColor Green
            Write-Host "   URL: $($Result.Url)" -ForegroundColor Cyan
            Write-Host "   Number: #$($Result.Number)" -ForegroundColor Cyan
            Write-Host ""
            return @{
                Url    = $Result.Url
                Number = $Result.Number
            }
        } else {
            if ($Result.Manual) {
                Write-Host "📝 Manual PR creation required:" -ForegroundColor Yellow
                Write-Host "   $($Result.Url)" -ForegroundColor Cyan
            } else {
                Write-Host "❌ PR creation failed: $($Result.Error)" -ForegroundColor Red
            }
            Write-Host ""
            return $Result
        }
    } else {
        Write-Host "ℹ️  PR creation via API not yet implemented for $($RemoteInfo.Platform)" -ForegroundColor Yellow
        $ManualUrl = Get-PrUrl -RemoteInfo $RemoteInfo -Source $SourceBranch -Target $TargetBranch
        Write-Host "   Visit: $ManualUrl" -ForegroundColor Cyan
        return @{
            Success = $false
            Url     = $ManualUrl
            Manual  = $true
        }
    }
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
