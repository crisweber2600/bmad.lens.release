# =============================================================================
# LENS Workbench v3 — Control Repo Setup
#
# PURPOSE:
#   Bootstraps a new control repo by cloning all required authority domains:
#   - bmad.lens.release   → Release module (read-only dependency)
#   - <control-repo>.governance → Governance repo (constitutional authority)
#   - .github             → Copied from bmad.lens.release/.github
#
#   Safe to re-run: pulls latest if repos already exist.
#
# USAGE:
#   .\setup-control-repo.ps1 -Org <github-org-or-user>
#   .\setup-control-repo.ps1 -Org weberbot -ReleaseRepo my-release
#   .\setup-control-repo.ps1 -ReleaseOrg myorg -GovernanceOrg governance-team
#   .\setup-control-repo.ps1 -Org weberbot -BaseUrl https://github.company.com
#   .\setup-control-repo.ps1 -Help
#
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Org = "crisweber2600",

    [string]$ReleaseOrg = "crisweber2600",

    [string]$ReleaseRepo = "bmad.lens.release",

    [string]$ReleaseBranch = "beta",

    [string]$CopilotOrg = "crisweber2600",

    [string]$CopilotRepo = "bmad.lens.copilot",

    [string]$CopilotBranch = "beta",

    [string]$GovernanceOrg = "crisweber2600",

    [string]$GovernanceRepo = "lens-governance",

    [string]$GovernanceBranch = "main",

    [string]$GovernancePath = "TargetProjects\lens\lens-governance",

    [string]$BaseUrl = "https://github.com",

    [switch]$DryRun,

    [switch]$Help
)

# -- Help -------------------------------------------------------------------
if ($Help) {
    Get-Content $PSCommandPath | Select-String '^#' | ForEach-Object { $_.Line -replace '^# ?', '' }
    exit 0
}

# -- Validate ---------------------------------------------------------------
if (-not $Org -and -not $ReleaseOrg -and -not $CopilotOrg -and -not $GovernanceOrg) {
    Write-Host "Error: -Org is required (or specify -ReleaseOrg, -CopilotOrg, -GovernanceOrg individually)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage: .\setup-control-repo.ps1 -Org <github-org-or-user>"
    exit 1
}

# -- Apply fallbacks --------------------------------------------------------
if (-not $ReleaseOrg) { $ReleaseOrg = $Org }
if (-not $CopilotOrg) { $CopilotOrg = $Org }
if (-not $GovernanceOrg) { $GovernanceOrg = $Org }

try {
    $gitRoot = (git -C (Split-Path -Parent $PSCommandPath) rev-parse --show-toplevel 2>$null).Trim()
    if (-not $gitRoot -or $LASTEXITCODE -ne 0) {
        throw "No git root detected"
    }
    $ProjectRoot = $gitRoot
}
catch {
    # Fallback: this script lives at _bmad\lens-work\scripts\
    $scriptDir = Split-Path -Parent $PSCommandPath
    $ProjectRoot = (Resolve-Path (Join-Path $scriptDir "..\..\..")).Path
}

# Derive governance defaults from control repo name unless explicitly provided.
$controlRepoName = Split-Path -Leaf $ProjectRoot
if ($controlRepoName -match "\.src$") {
    $controlRepoName = $controlRepoName -replace "\.src$", ".bmad"
}
if (-not $PSBoundParameters.ContainsKey("GovernanceRepo")) {
    $GovernanceRepo = "$controlRepoName.governance"
}
if (-not $PSBoundParameters.ContainsKey("GovernancePath")) {
    $GovernancePath = Join-Path "TargetProjects\lens" $GovernanceRepo
}

# -- Helper Functions -------------------------------------------------------

function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err { param([string]$Msg) Write-Host "[ERR]  $Msg" -ForegroundColor Red }

function Invoke-CloneOrPull {
    param(
        [string]$RemoteUrl,
        [string]$LocalPath,
        [string]$BranchName,
        [string]$RepoLabel
    )

    $gitDirPath = Join-Path $LocalPath ".git"
    $isGitRepo = Test-Path $gitDirPath
    $targetExists = Test-Path $LocalPath

    if ($DryRun) {
        if ($isGitRepo) {
            Write-Info "[DRY-RUN] Would pull latest for $RepoLabel at $LocalPath (branch: $BranchName)"
        }
        elseif ($targetExists) {
            Write-Info "[DRY-RUN] Would replace existing path and clone $RepoLabel -> $LocalPath (branch: $BranchName)"
        }
        else {
            Write-Info "[DRY-RUN] Would clone $RepoLabel -> $LocalPath (branch: $BranchName)"
        }
        return
    }

    if ($isGitRepo) {
        Write-Info "Pulling latest for $RepoLabel ($LocalPath)..."
        Push-Location $LocalPath
        try {
            git fetch origin
            $null = git checkout $BranchName 2>$null
            if ($LASTEXITCODE -ne 0) {
                git checkout -b $BranchName "origin/$BranchName"
            }
            git pull origin $BranchName
            Write-Ok "$RepoLabel updated (branch: $BranchName)"
        }
        finally {
            Pop-Location
        }
    }
    else {
        if ($targetExists) {
            Write-Warn "$RepoLabel target exists and is not a git repo. Replacing $LocalPath"
            try {
                Remove-Item -Path $LocalPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Err "Failed to replace existing path for ${RepoLabel}: $($_.Exception.Message)"
                exit 1
            }
        }

        Write-Info "Cloning $RepoLabel -> $LocalPath (branch: $BranchName)..."
        $parentDir = Split-Path $LocalPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        git clone --branch $BranchName $RemoteUrl $LocalPath
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to clone $RepoLabel"
            exit 1
        }
        Write-Ok "$RepoLabel cloned (branch: $BranchName)"
    }
}

function Sync-GitHubFromRelease {
    param(
        [string]$ReleaseRepoPath,
        [string]$DestinationPath,
        [string]$SourceLabel
    )

    $sourcePath = Join-Path $ReleaseRepoPath ".github"
    $destinationGitPath = Join-Path $DestinationPath ".git"
    $destinationExists = Test-Path $DestinationPath
    $destinationIsGitRepo = Test-Path $destinationGitPath

    if (-not (Test-Path $sourcePath)) {
        Write-Err "Missing source .github at $sourcePath"
        exit 1
    }

    if ($DryRun) {
        if ($destinationIsGitRepo) {
            Write-Info "[DRY-RUN] Would remove existing .github git repo at $DestinationPath"
        }
        elseif ($destinationExists) {
            Write-Info "[DRY-RUN] Would replace existing .github at $DestinationPath"
        }
        else {
            Write-Info "[DRY-RUN] Would create .github at $DestinationPath"
        }
        Write-Info "[DRY-RUN] Would copy .github from $SourceLabel"
        return
    }

    try {
        if ($destinationIsGitRepo) {
            Write-Warn ".github is a git repo in control repo. Removing before copy"
        }
        elseif ($destinationExists) {
            Write-Info "Replacing existing .github at $DestinationPath"
        }

        if ($destinationExists) {
            Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction Stop
        }

        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        Get-ChildItem -Path $sourcePath -Force | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $DestinationPath -Recurse -Force
        }
        Write-Ok ".github copied from $SourceLabel"
    }
    catch {
        Write-Err "Failed to sync .github from ${SourceLabel}: $($_.Exception.Message)"
        exit 1
    }
}

function Ensure-GitHubRepoExists {
    param(
        [string]$BaseUrl,
        [string]$Owner,
        [string]$Repo,
        [string]$RemoteUrl
    )

    $repoFullName = "$Owner/$Repo"

    if ($DryRun) {
        Write-Info "[DRY-RUN] Would verify $repoFullName exists"
        Write-Info "[DRY-RUN] Would create private repository $repoFullName if missing"
        return
    }

    git ls-remote $RemoteUrl HEAD 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Info "$repoFullName is available"
        return
    }

    Write-Warn "$repoFullName is missing or inaccessible. Attempting to create it as a private repository."

    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        Write-Err "GitHub CLI (gh) is required to auto-create $repoFullName. Install gh or create the repo manually."
        exit 1
    }

    $previousGhHost = $env:GH_HOST
    try {
        $baseUri = [Uri]$BaseUrl
        if ($baseUri.Host -and $baseUri.Host -ne "github.com") {
            $env:GH_HOST = $baseUri.Host
            Write-Info "Using GitHub host $($baseUri.Host) for repository creation"
        }
        else {
            $env:GH_HOST = ""
        }

        & gh repo create $repoFullName --private --add-readme --description "LENS governance repository" --disable-issues
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to create private repository $repoFullName"
            exit 1
        }

        Write-Ok "Created private repository $repoFullName"
    }
    finally {
        $env:GH_HOST = $previousGhHost
    }

    git ls-remote $RemoteUrl HEAD 1>$null 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Repository $repoFullName was created but is still not reachable at $RemoteUrl"
        exit 1
    }
}

function Resolve-CloneBranch {
    param(
        [string]$RemoteUrl,
        [string]$PreferredBranch,
        [string]$RepoLabel
    )

    if ($DryRun) {
        return $PreferredBranch
    }

    $branchHeads = git ls-remote --heads $RemoteUrl $PreferredBranch 2>$null
    if ($LASTEXITCODE -eq 0 -and $branchHeads) {
        return $PreferredBranch
    }

    $headLine = git ls-remote --symref $RemoteUrl HEAD 2>$null | Select-String "ref: refs/heads/" | Select-Object -First 1
    if (-not $headLine) {
        Write-Err "Unable to resolve default branch for $RepoLabel"
        exit 1
    }

    $headText = $headLine.ToString()
    if ($headText -notmatch "refs/heads/([^\t ]+)") {
        Write-Err "Unable to parse default branch for $RepoLabel"
        exit 1
    }

    $defaultBranch = $matches[1]
    Write-Warn "$RepoLabel does not have branch '$PreferredBranch'. Using default branch '$defaultBranch' instead."
    return $defaultBranch
}

function Ensure-GitIgnoreEntries {
    param(
        [string]$RootPath
    )

    $gitIgnorePath = Join-Path $RootPath ".gitignore"
    $entries = @(
        "_bmad-output/lens-work/personal/",
        ".github/",
        "bmad.lens.release/",
        "TargetProjects/"
    )

    $addedCount = 0

    if (-not (Test-Path $gitIgnorePath)) {
        if ($DryRun) {
            Write-Info "[DRY-RUN] Would create $gitIgnorePath"
        }
        else {
            New-Item -ItemType File -Path $gitIgnorePath -Force | Out-Null
            Write-Info "Created $gitIgnorePath"
        }
    }

    $existingEntries = @()
    if (Test-Path $gitIgnorePath) {
        $existingEntries = Get-Content $gitIgnorePath -ErrorAction SilentlyContinue
    }

    foreach ($entry in $entries) {
        if ($existingEntries -contains $entry) {
            continue
        }

        if ($DryRun) {
            Write-Info "[DRY-RUN] Would add '$entry' to .gitignore"
        }
        else {
            Add-Content -Path $gitIgnorePath -Value $entry
            $addedCount++
            Write-Info "Added '$entry' to .gitignore"
        }
    }

    if (-not $DryRun) {
        if ($addedCount -eq 0) {
            Write-Ok ".gitignore already contains required entries"
        }
        else {
            Write-Ok ".gitignore updated with required entries"
        }
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Host ""
Write-Host "LENS Workbench v3 - Control Repo Setup" -ForegroundColor White -NoNewline
Write-Host ""
Write-Host "Base URL: $BaseUrl" -ForegroundColor DarkGray
Write-Host "Root:     $ProjectRoot" -ForegroundColor DarkGray
Write-Host ""

if ($DryRun) {
    Write-Warn "Dry run mode: no changes will be made"
    Write-Host ""
}

# -- 1. Release Repo --------------------------------------------------------
$ReleaseUrl = "${BaseUrl}/${ReleaseOrg}/${ReleaseRepo}.git"
$ReleasePath = Join-Path $ProjectRoot $ReleaseRepo
Invoke-CloneOrPull -RemoteUrl $ReleaseUrl -LocalPath $ReleasePath -BranchName $ReleaseBranch -RepoLabel "${ReleaseOrg}/${ReleaseRepo}"

# -- 2. Sync .github from Release Repo --------------------------------------
$CopilotPath = Join-Path $ProjectRoot ".github"
Sync-GitHubFromRelease -ReleaseRepoPath $ReleasePath -DestinationPath $CopilotPath -SourceLabel "${ReleaseOrg}/${ReleaseRepo}/.github"

# -- 3. Governance Repo -----------------------------------------------------
$GovernanceUrl = "${BaseUrl}/${GovernanceOrg}/${GovernanceRepo}.git"
$GovernanceFullPath = Join-Path $ProjectRoot $GovernancePath
Ensure-GitHubRepoExists -BaseUrl $BaseUrl -Owner $GovernanceOrg -Repo $GovernanceRepo -RemoteUrl $GovernanceUrl
$GovernanceCloneBranch = Resolve-CloneBranch -RemoteUrl $GovernanceUrl -PreferredBranch $GovernanceBranch -RepoLabel "${GovernanceOrg}/${GovernanceRepo}"
Invoke-CloneOrPull -RemoteUrl $GovernanceUrl -LocalPath $GovernanceFullPath -BranchName $GovernanceCloneBranch -RepoLabel "${GovernanceOrg}/${GovernanceRepo}"

# -- 4. Output directories --------------------------------------------------
if (-not $DryRun) {
    $dirs = @(
        (Join-Path $ProjectRoot "_bmad-output\lens-work\initiatives"),
        (Join-Path $ProjectRoot "_bmad-output\lens-work\personal")
    )
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Write-Ok "Output directory structure verified"
}
else {
    Write-Info "[DRY-RUN] Would create _bmad-output\lens-work\ directories"
}

# -- 5. Write LENS_VERSION ---------------------------------------------------
if (-not $DryRun) {
    $lifecyclePath = Join-Path $ReleasePath "_bmad\lens-work\lifecycle.yaml"

    if (-not (Test-Path -Path $lifecyclePath)) {
        throw "Unable to write LENS_VERSION: lifecycle file not found at '$lifecyclePath'. Ensure bmad.lens.release is correctly cloned and contains _bmad\lens-work\lifecycle.yaml."
    }

    $lifecycleContent = Get-Content -Path $lifecyclePath -ErrorAction Stop
    $schemaLine = $lifecycleContent | Where-Object { $_ -match '^\s*schema_version\s*:' } | Select-Object -First 1

    if (-not $schemaLine) {
        throw "Unable to write LENS_VERSION: 'schema_version:' entry not found in lifecycle file '$lifecyclePath'."
    }

    $parts = $schemaLine -split ':', 2
    if ($parts.Count -lt 2) {
        throw "Unable to write LENS_VERSION: could not parse schema_version from line '$schemaLine' in '$lifecyclePath'."
    }

    $schemaVersion = $parts[1].Trim()
    if ([string]::IsNullOrWhiteSpace($schemaVersion)) {
        throw "Unable to write LENS_VERSION: schema_version value is empty or whitespace in '$lifecyclePath'."
    }

    $versionString = "$schemaVersion.0.0"
    Set-Content -Path (Join-Path $ProjectRoot "LENS_VERSION") -Value $versionString -NoNewline
    Write-Ok "LENS_VERSION written: $versionString"
}
else {
    Write-Info "[DRY-RUN] Would write LENS_VERSION"
}

# -- 6. Ensure .gitignore entries -------------------------------------------
Ensure-GitIgnoreEntries -RootPath $ProjectRoot

# -- Summary ----------------------------------------------------------------
Write-Host ""
Write-Host "Setup Complete" -ForegroundColor White
Write-Host ""
Write-Host "  $ReleaseOrg/$ReleaseRepo -> $ReleaseRepo\    (branch: $ReleaseBranch)" -ForegroundColor Green
Write-Host "  .github  ``<--  $ReleaseRepo\.github" -ForegroundColor Green
Write-Host "  $GovernanceOrg/$GovernanceRepo -> $GovernancePath\  (branch: $GovernanceCloneBranch)" -ForegroundColor Green
Write-Host ""
Write-Host "GitHub Copilot adapter is installed from bmad.lens.release/.github."
Write-Host "No further setup is needed if GitHub Copilot is your only IDE."
Write-Host ""
Write-Host 'For non-Copilot IDEs, run the module installer:'
Write-Host '  .\_bmad\lens-work\scripts\install.ps1 -IDE cursor' -ForegroundColor Cyan
Write-Host '  .\_bmad\lens-work\scripts\install.ps1 -AllIDEs' -ForegroundColor Cyan
Write-Host ""
