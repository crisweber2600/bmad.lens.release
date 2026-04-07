# =============================================================================
# LENS Workbench v3 — Control Repo Setup
#
# PURPOSE:
#   Bootstraps a new control repo by cloning all required authority domains:
#   - lens.core   → Release module (read-only dependency)
#   - .github             → Copied from lens.core/.github
#   - governance repo     → Governance repo (constitutional authority)
#
#   Safe to re-run: pulls latest if repos already exist.
#
# USAGE:
#   Interactive wizard (recommended for first-time setup):
#     .\setup-control-repo.ps1
#
#   Parameter mode (for scripting/CI):
#     .\setup-control-repo.ps1 -Org <github-org-or-user>
#     .\setup-control-repo.ps1 -Org weberbot -ReleaseRepo my-release
#     .\setup-control-repo.ps1 -ReleaseOrg myorg -GovernanceOrg governance-team
#     .\setup-control-repo.ps1 -Org weberbot -BaseUrl https://github.company.com
#     .\setup-control-repo.ps1 -Help
#
# When run with no arguments, the script enters an interactive wizard that
# auto-detects your environment and guides you through configuration.
#
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Org = "",

    [string]$ControlDir = "",

    [string]$ReleaseOrg = "",

    [string]$ReleaseRepo = "lens.core",

    [string]$ReleaseBranch = "beta",

    [string]$GovernanceOrg = "",

    [string]$GovernanceRepo = "",

    [string]$GovernanceBranch = "main",

    [string]$GovernancePath = "",

    [string]$BaseUrl = "https://github.com",

    [switch]$DryRun,

    [switch]$Help
)

# -- Help -------------------------------------------------------------------
if ($Help) {
    Get-Content $PSCommandPath | Select-String '^#' | ForEach-Object { $_.Line -replace '^# ?', '' }
    exit 0
}

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

# -- Apply -ControlDir override if provided ----------------------------------
if ($ControlDir -and $ControlDir -ne "") {
    $ControlDir = (Resolve-Path -Path $ControlDir -ErrorAction SilentlyContinue).Path
    if (-not $ControlDir) {
        $ControlDir = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PSBoundParameters['ControlDir']))
    }
    $ProjectRoot = $ControlDir
}

# Derive governance defaults from control repo name unless explicitly provided.
$controlRepoName = Split-Path -Leaf $ProjectRoot
$derivedControlName = $controlRepoName
if ($derivedControlName -match "\.src$") {
    $derivedControlName = $derivedControlName -replace "\.src$", ".bmad"
}
if (-not $PSBoundParameters.ContainsKey("GovernanceRepo") -or [string]::IsNullOrEmpty($GovernanceRepo)) {
    $GovernanceRepo = "$derivedControlName.governance"
}
if (-not $PSBoundParameters.ContainsKey("GovernancePath") -or [string]::IsNullOrEmpty($GovernancePath)) {
    $GovernancePath = Join-Path "TargetProjects\lens" $GovernanceRepo
}

# -- Helper Functions -------------------------------------------------------

function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok { param([string]$Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err { param([string]$Msg) Write-Host "[ERR]  $Msg" -ForegroundColor Red }

function Read-WithDefault {
    param(
        [string]$Prompt,
        [string]$Default
    )
    $input = Read-Host "  $Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
    return $input.Trim()
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [string]$Default = "y"
    )
    if ($Default -eq "y") {
        $input = Read-Host "  $Prompt [Y/n]"
    }
    else {
        $input = Read-Host "  $Prompt [y/N]"
    }
    if ([string]::IsNullOrWhiteSpace($input)) { $input = $Default }
    return $input -match '^[yY]'
}

function Get-DetectedGitHubUsername {
    # Try gh CLI first
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        try {
            $ghUser = (& gh api user --jq '.login' 2>$null)
            if ($LASTEXITCODE -eq 0 -and $ghUser) {
                return $ghUser.Trim()
            }
        }
        catch {}
    }
    # Try git config
    try {
        $gitUser = (git config user.name 2>$null)
        if ($gitUser) { return $gitUser.Trim() }
    }
    catch {}
    return ""
}

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
        "lens.core/",
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
# WIZARD MODE
# =============================================================================

function Invoke-SetupWizard {
    Write-Host ""
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor White
    Write-Host "|       LENS Workbench v3 -- Control Repo Setup Wizard         |" -ForegroundColor White
    Write-Host "+--------------------------------------------------------------+" -ForegroundColor White
    Write-Host ""
    Write-Host "  This wizard will bootstrap your control repo by:"
    Write-Host "    1. " -ForegroundColor Cyan -NoNewline; Write-Host "Cloning the LENS release module (read-only)"
    Write-Host "    2. " -ForegroundColor Cyan -NoNewline; Write-Host "Copying the GitHub Copilot adapter (.github/)"
    Write-Host "    3. " -ForegroundColor Cyan -NoNewline; Write-Host "Cloning (or creating) your governance repo"
    Write-Host "    4. " -ForegroundColor Cyan -NoNewline; Write-Host "Setting up output directories and LENS_VERSION"
    Write-Host ""
    Write-Host "  Press Enter to accept defaults shown in [brackets]." -ForegroundColor DarkGray
    Write-Host ""

    # -- Step 1: Control Repo Directory ----------------------------------------
    Write-Host "Step 1: Control Repo Directory" -ForegroundColor White
    Write-Host ""
    Write-Host "  The directory where your control repo will be set up." -ForegroundColor DarkGray

    $wizardDir = Read-WithDefault -Prompt "Control repo directory" -Default $ProjectRoot
    if ($wizardDir -and $wizardDir -ne $ProjectRoot) {
        $resolved = $null
        try { $resolved = (Resolve-Path -Path $wizardDir -ErrorAction Stop).Path } catch {}
        if (-not $resolved) {
            $resolved = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $wizardDir))
        }
        $script:ProjectRoot = $resolved
        # Re-derive governance defaults from new directory
        $controlRepoName = Split-Path -Leaf $script:ProjectRoot
        $derivedControlName = $controlRepoName
        if ($derivedControlName -match "\.src$") {
            $derivedControlName = $derivedControlName -replace "\.src$", ".bmad"
        }
        $script:GovernanceRepo = "$derivedControlName.governance"
        $script:GovernancePath = Join-Path "TargetProjects\lens" $script:GovernanceRepo
    }
    Write-Host ""

    # -- Step 2: GitHub Account -----------------------------------------------
    Write-Host "Step 2: GitHub Account" -ForegroundColor White
    Write-Host ""

    $detectedUser = Get-DetectedGitHubUsername
    if ($detectedUser) {
        Write-Host "  Detected: $detectedUser" -ForegroundColor DarkGray
    }

    $defaultUser = if ($detectedUser) { $detectedUser } else { "your-username" }
    $script:Org = Read-WithDefault -Prompt "GitHub org or username" -Default $defaultUser
    Write-Host ""

    # -- Step 3: GitHub Server ------------------------------------------------
    Write-Host "Step 3: GitHub Server" -ForegroundColor White
    Write-Host ""

    if (Read-YesNo -Prompt "Use github.com?" -Default "y") {
        $script:BaseUrl = "https://github.com"
    }
    else {
        $script:BaseUrl = Read-WithDefault -Prompt "Enterprise GitHub URL" -Default "https://github.company.com"
    }
    Write-Host ""

    # -- Step 4: Release Repository -------------------------------------------
    Write-Host "Step 4: Release Repository" -ForegroundColor White
    Write-Host ""
    Write-Host "  The release repo contains the LENS module (read-only dependency)." -ForegroundColor DarkGray

    $script:ReleaseRepo = Read-WithDefault -Prompt "Release repo name" -Default $ReleaseRepo
    $script:ReleaseBranch = Read-WithDefault -Prompt "Release repo branch" -Default $ReleaseBranch
    $script:ReleaseOrg = Read-WithDefault -Prompt "Release repo owner" -Default $Org
    Write-Host ""

    # -- Step 5: Governance Repository ----------------------------------------
    Write-Host "Step 5: Governance Repository" -ForegroundColor White
    Write-Host ""
    Write-Host "  The governance repo holds constitutional rules for your organization." -ForegroundColor DarkGray
    Write-Host "  Auto-derived from control repo name: $GovernanceRepo" -ForegroundColor DarkGray

    $script:GovernanceRepo = Read-WithDefault -Prompt "Governance repo name" -Default $GovernanceRepo
    $script:GovernanceBranch = Read-WithDefault -Prompt "Governance repo branch" -Default $GovernanceBranch
    $script:GovernanceOrg = Read-WithDefault -Prompt "Governance repo owner" -Default $Org

    # Re-derive path if governance repo name was customized
    $script:GovernancePath = Join-Path "TargetProjects\lens" $GovernanceRepo
    $script:GovernancePath = Read-WithDefault -Prompt "Local clone path" -Default $GovernancePath
    Write-Host ""

    # -- Step 6: Review & Confirm ---------------------------------------------
    Write-Host "Step 6: Review & Confirm" -ForegroundColor White
    Write-Host ""
    Write-Host "  Configuration summary:" -ForegroundColor White
    Write-Host ""
    Write-Host "    Base URL:         " -NoNewline; Write-Host "$BaseUrl" -ForegroundColor Cyan
    Write-Host "    Control repo:     " -NoNewline; Write-Host "$ProjectRoot" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Release repo:     " -NoNewline; Write-Host "$ReleaseOrg/$ReleaseRepo" -ForegroundColor Green -NoNewline; Write-Host " (branch: $ReleaseBranch)"
    Write-Host "      -> clone to:     $ReleaseRepo/" -ForegroundColor DarkGray
    Write-Host "      -> .github:      copied from release repo" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Governance repo:  " -NoNewline; Write-Host "$GovernanceOrg/$GovernanceRepo" -ForegroundColor Green -NoNewline; Write-Host " (branch: $GovernanceBranch)"
    Write-Host "      -> clone to:     $GovernancePath/" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Read-YesNo -Prompt "Proceed with setup?" -Default "y")) {
        Write-Host ""
        Write-Host "  Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# =============================================================================
# DETERMINE MODE
# =============================================================================

$hasParamArgs = $PSBoundParameters.ContainsKey("Org") -or
$PSBoundParameters.ContainsKey("ControlDir") -or
$PSBoundParameters.ContainsKey("ReleaseOrg") -or
$PSBoundParameters.ContainsKey("GovernanceOrg") -or
$PSBoundParameters.ContainsKey("ReleaseRepo") -or
$PSBoundParameters.ContainsKey("ReleaseBranch") -or
$PSBoundParameters.ContainsKey("GovernanceRepo") -or
$PSBoundParameters.ContainsKey("GovernanceBranch") -or
$PSBoundParameters.ContainsKey("GovernancePath") -or
$PSBoundParameters.ContainsKey("BaseUrl")

if (-not $hasParamArgs) {
    # No org/repo params passed — enter wizard mode
    Invoke-SetupWizard
}
else {
    # Validate that we have enough info in parameter mode
    if (-not $Org -and -not $ReleaseOrg -and -not $GovernanceOrg) {
        Write-Host "Error: -Org is required (or specify -ReleaseOrg, -GovernanceOrg individually)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Usage: .\setup-control-repo.ps1 -Org <github-org-or-user>"
        exit 1
    }
}

# -- Apply fallbacks --------------------------------------------------------
if (-not $ReleaseOrg) { $ReleaseOrg = $Org }
if (-not $GovernanceOrg) { $GovernanceOrg = $Org }

# =============================================================================
# MAIN
# =============================================================================

Write-Host ""
Write-Host "LENS Workbench v3 - Control Repo Setup" -ForegroundColor White
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

# -- 4b. Write governance-setup.yaml ----------------------------------------
$GovernanceSetupPath = Join-Path $ProjectRoot "_bmad-output\lens-work\governance-setup.yaml"
if (-not $DryRun) {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $yamlContent = @"
# Generated by setup-control-repo.ps1 — $timestamp
governance_repo_path: "$GovernancePath"
governance_remote_url: "$GovernanceUrl"
"@
    Set-Content -Path $GovernanceSetupPath -Value $yamlContent
    Write-Ok "governance-setup.yaml written"
}
else {
    Write-Info "[DRY-RUN] Would write governance-setup.yaml"
}

# -- 5. Write LENS_VERSION ---------------------------------------------------
if (-not $DryRun) {
    $lifecyclePath = Join-Path $ReleasePath "_bmad\lens-work\lifecycle.yaml"

    if (-not (Test-Path -Path $lifecyclePath)) {
        throw "Unable to write LENS_VERSION: lifecycle file not found at '$lifecyclePath'. Ensure lens.core is correctly cloned and contains _bmad\lens-work\lifecycle.yaml."
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
Write-Host "  .github  <--  $ReleaseRepo\.github" -ForegroundColor Green
Write-Host "  $GovernanceOrg/$GovernanceRepo -> $GovernancePath\  (branch: $GovernanceCloneBranch)" -ForegroundColor Green
Write-Host ""
Write-Host "GitHub Copilot adapter is installed from $ReleaseRepo/.github."
Write-Host "No further setup is needed if GitHub Copilot is your only IDE."
Write-Host ""
Write-Host "For non-Copilot IDEs, run the module installer:"
Write-Host "  .\lens.core\_bmad\lens-work\scripts\install.ps1 -IDE cursor" -ForegroundColor Cyan
Write-Host "  .\lens.core\_bmad\lens-work\scripts\install.ps1 -AllIDEs" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "  1. Store your GitHub PAT (run in terminal, " -NoNewline
Write-Host "not in AI chat" -ForegroundColor Yellow -NoNewline
Write-Host "):"
Write-Host "     .\$ReleaseRepo\lens.core\_bmad\lens-work\scripts\store-github-pat.ps1" -ForegroundColor Cyan
Write-Host "  2. Open VS Code + GitHub Copilot Chat and run:"
Write-Host "     /onboard" -ForegroundColor Cyan
Write-Host ""
