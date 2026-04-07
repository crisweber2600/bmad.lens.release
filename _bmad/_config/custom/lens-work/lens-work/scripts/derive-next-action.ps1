# =============================================================================
# LENS Workbench — Derive Next Action
#
# PURPOSE:
#   Apply lifecycle decision rules to determine the single next command or
#   hard gate for the current initiative. Mirrors the logic in
#   workflows/utility/next/steps/step-02-derive-action.md.
#
# USAGE:
#   .\lens.core\_bmad\lens-work\scripts\derive-next-action.ps1 -InitiativeRoot path [-Json]
#
# OUTPUT FIELDS:
#   next_command  - The command to run (null when gated)
#   gate_message  - Human-readable gate or info message (null when no gate)
#   hard_gate     - true when a blocking condition exists
#
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InitiativeRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$stateFile = Join-Path $InitiativeRoot "initiative-state.yaml"
if (-not (Test-Path $stateFile)) {
    Write-Host "ERROR: initiative-state.yaml not found in $InitiativeRoot" -ForegroundColor Red
    exit 1
}

# =============================================================================
# Read state fields
# =============================================================================

function Read-YamlField {
    param([string]$Field, [string]$File)
    $match = Select-String -Path $File -Pattern "^${Field}:\s*(.+)" | Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value.Trim() }
    return ""
}

$milestone = Read-YamlField -Field "milestone" -File $stateFile
$phase     = Read-YamlField -Field "phase"     -File $stateFile
$action    = Read-YamlField -Field "action"    -File $stateFile
$scope     = Read-YamlField -Field "scope"     -File $stateFile

# =============================================================================
# Decision tree (mirrors step-02-derive-action.md)
# =============================================================================

$nextCommand = $null
$gateMessage = $null
$hardGate    = $false

if ([string]::IsNullOrEmpty($milestone) -and [string]::IsNullOrEmpty($phase) -and [string]::IsNullOrEmpty($action)) {
    $gateMessage = "Not currently on an initiative branch. Run /status or /switch."
} elseif ([string]::IsNullOrEmpty($milestone) -and $scope -eq "domain") {
    $nextCommand = "/new-service"
} elseif ([string]::IsNullOrEmpty($milestone) -and $scope -eq "service") {
    $nextCommand = "/new-feature"
} elseif ($action -match "(?i)awaiting review|awaiting merge") {
    $hardGate = $true
    $gateMessage = "A PR is still open for the active lifecycle step. Merge it, then run /next again."
} elseif ($action -match "(?i)address review feedback") {
    $hardGate = $true
    $gateMessage = "Review feedback is blocking progress. Resolve the requested changes, then run /next again."
} elseif ($action -eq "Ready to promote") {
    $nextCommand = "/promote"
} elseif ($action -match "(?i)promotion in review") {
    $hardGate = $true
    $gateMessage = "Promotion PR is open. Merge it, then run /next again."
} elseif (-not [string]::IsNullOrEmpty($phase) -and ($action -match "(?i)complete phase|start next phase")) {
    $nextCommand = "/$phase"
} elseif ($action -match "(?i)ready for execution") {
    $gateMessage = "All caught up. The initiative is ready for execution."
} else {
    $gateMessage = "No deterministic next action was found. Run /status for the full picture."
}

# =============================================================================
# Output
# =============================================================================

if ($Json) {
    @{
        next_command = $nextCommand
        gate_message = $gateMessage
        hard_gate    = $hardGate
    } | ConvertTo-Json -Depth 2
} else {
    Write-Host ""
    if ($nextCommand) {
        Write-Host "Next action: " -ForegroundColor Green -NoNewline
        Write-Host $nextCommand -ForegroundColor Cyan
    } elseif ($hardGate) {
        Write-Host "BLOCKED: " -ForegroundColor Red -NoNewline
        Write-Host $gateMessage
    } elseif ($gateMessage) {
        Write-Host "Info: " -ForegroundColor Yellow -NoNewline
        Write-Host $gateMessage
    }
    Write-Host ""
}
