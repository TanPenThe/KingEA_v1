param(
    [string]$ConfigurationPath = 'C:\KingEA_v1\config\watchdog.demo2.disabled.json',
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'KingEAWatchdog.psm1') -Force

function Write-Outbox([string]$Directory, [string]$Action, [string]$Reason, $State) {
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }
    $record = [pscustomobject]@{
        Utc = [datetime]::UtcNow.ToString('o')
        Action = $Action
        Reason = $Reason
        EscalationEpoch = $State.EscalationEpoch
        ReconciliationRequired = $State.ReconciliationRequired
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath (Join-Path $Directory 'tier1_outbox.jsonl') -Value $record -Encoding UTF8
}

function Get-ProcessFacts([string]$ExpectedExecutablePath) {
    $processes = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" | ForEach-Object {
        [pscustomobject]@{
            ProcessId = $_.ProcessId
            Path = $_.ExecutablePath
            CommandLine = $_.CommandLine
        }
    })
    return @(Get-KingEAMatchingProcesses -Processes $processes -ExpectedExecutablePath $ExpectedExecutablePath)
}

function Invoke-WatchdogCycle($configuration, $state) {
    $deployment = [string]$configuration.DeploymentId
    $root = [string]$configuration.CommonFilesRoot
    $control = Join-Path $root ('KingEA\control\' + $deployment)
    $heartbeatPath = Join-Path $root ('KingEA\heartbeat\' + $deployment + '\heartbeat.dat')
    $standdownPath = Join-Path $control 'manual_standdown.json'
    $plannedStopPath = Join-Path $control 'planned_stop.json'
    $outbox = Join-Path $root ('KingEA\alerts\' + $deployment)
    $now = [datetime]::UtcNow
    $standdown = Test-KingEAStanddownLatch -Path $standdownPath -DeploymentId $deployment
    $planned = Test-Path -LiteralPath $plannedStopPath
    $heartbeat = Read-KingEAHeartbeat -Path $heartbeatPath `
        -DeploymentId $deployment `
        -ConfigurationHash ([string]$configuration.ExpectedConfigurationHash) `
        -ServerClass ([string]$configuration.ExpectedServerClass) `
        -UtcNow $now `
        -StaleSeconds ([int]$configuration.StaleSeconds)
    $matches = @(Get-ProcessFacts ([string]$configuration.ExpectedExecutablePath))

    $processIdentityValid = $heartbeat.Valid -and $matches.Count -eq 1 -and
        [long]$heartbeat.ProcessId -eq [long]$matches[0].ProcessId -and
        [string]::Equals([string]$heartbeat.ExecutablePath,
                         [string]$configuration.ExpectedExecutablePath,
                         [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]$heartbeat.DataRoot -eq [string]$configuration.ExpectedDataRoot
    $healthy = $processIdentityValid
    $effectiveProcessCount = if ($matches.Count -gt 1 -or
                                 ($matches.Count -eq 1 -and -not $processIdentityValid)) {
        2
    }
    else {
        $matches.Count
    }
    $facts = [pscustomobject]@{
        UtcNow = $now
        Failure = (-not $healthy -and -not $planned -and -not $standdown)
        FailureReason = if ($heartbeat.Valid) { 'PROCESS_OR_IDENTITY_FAILURE' } else { 'HEARTBEAT_' + $heartbeat.Reason }
        StanddownActive = $standdown
        PlannedStop = $planned
        Healthy = $healthy
        Reconciled = (-not $state.ReconciliationRequired)
        IdentityValid = ($heartbeat.Valid -and $effectiveProcessCount -le 1)
        ConfigurationValid = $heartbeat.Valid
        MatchingProcessCount = $effectiveProcessCount
        PreLaunchStanddownActive = $false
    }

    $decision = Invoke-KingEAWatchdogEvaluation -State $state -Facts $facts
    Write-Outbox -Directory $outbox -Action $decision.Action -Reason $decision.Reason -State $decision.State

    if ($decision.Action -eq 'RESTART_ONCE') {
        # Kill-switch race guard: recheck immediately before any process action.
        if (Test-KingEAStanddownLatch -Path $standdownPath -DeploymentId $deployment) {
            Write-Outbox -Directory $outbox -Action 'STANDDOWN' -Reason 'STANDDOWN_APPEARED_BEFORE_LAUNCH' -State $decision.State
            return $decision.State
        }
        if ($matches.Count -gt 1) {
            Write-Outbox -Directory $outbox -Action 'QUARANTINE' -Reason 'PROCESS_IDENTITY_AMBIGUOUS_BEFORE_LAUNCH' -State $decision.State
            return $decision.State
        }
        if ($matches.Count -eq 1) {
            $process = Get-Process -Id $matches[0].ProcessId -ErrorAction SilentlyContinue
            if ($process) {
                [void]$process.CloseMainWindow()
                if (-not $process.WaitForExit([int]$configuration.GracefulCloseSeconds * 1000)) {
                    Stop-Process -Id $process.Id -Force
                }
            }
        }
        # Repeat the independent standdown check after graceful termination.
        if (Test-KingEAStanddownLatch -Path $standdownPath -DeploymentId $deployment) {
            Write-Outbox -Directory $outbox -Action 'STANDDOWN' -Reason 'STANDDOWN_APPEARED_BEFORE_LAUNCH' -State $decision.State
            return $decision.State
        }
        Start-Process -FilePath ([string]$configuration.ExpectedExecutablePath) `
            -ArgumentList ([string]$configuration.TerminalArguments) `
            -WindowStyle Hidden
    }
    return $decision.State
}

if (-not (Test-Path -LiteralPath $ConfigurationPath)) {
    throw "KINGEA_WATCHDOG_CONFIG_MISSING: $ConfigurationPath"
}
$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
if (-not $configuration.Enabled) {
    Write-Output 'KINGEA_WATCHDOG_DISABLED: implementation is not installed or active.'
    exit 0
}

$stateDirectory = Join-Path ([string]$configuration.CommonFilesRoot) ('KingEA\watchdog\' + [string]$configuration.DeploymentId)
$statePath = Join-Path $stateDirectory 'watchdog_state.json'
try {
    $state = Read-KingEAAtomicJson -Path $statePath
}
catch {
    $state = New-KingEAWatchdogState -DeploymentId ([string]$configuration.DeploymentId)
    $state.ReconciliationRequired = $true
    $state.AutoRestartArmed = $false
    $state.ShortReviewLatched = $true
}
if (-not $state) {
    $state = New-KingEAWatchdogState -DeploymentId ([string]$configuration.DeploymentId)
    $state.ReconciliationRequired = $true
    $state.AutoRestartArmed = $false
    $state.ShortReviewLatched = $true
}

do {
    $state = Invoke-WatchdogCycle -configuration $configuration -state $state
    Write-KingEAAtomicJson -Path $statePath -Value $state
    if ($Once) { break }
    Start-Sleep -Seconds ([int]$configuration.PollSeconds)
} while ($true)
