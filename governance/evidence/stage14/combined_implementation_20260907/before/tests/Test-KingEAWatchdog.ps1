param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "KINGEA_WATCHDOG_TEST_FAIL: $Message" }
}

function New-Facts([datetime]$UtcNow) {
    [pscustomobject]@{
        UtcNow = $UtcNow
        Failure = $false
        FailureReason = ''
        StanddownActive = $false
        PlannedStop = $false
        Healthy = $false
        Reconciled = $false
        IdentityValid = $true
        ConfigurationValid = $true
        MatchingProcessCount = 1
        PreLaunchStanddownActive = $false
    }
}

function Set-Failure($Facts, [string]$Reason = 'STALE_HEARTBEAT') {
    $Facts.Failure = $true
    $Facts.Healthy = $false
    $Facts.FailureReason = $Reason
    return $Facts
}

function Set-Healthy($Facts) {
    $Facts.Failure = $false
    $Facts.Healthy = $true
    $Facts.Reconciled = $true
    return $Facts
}

function Get-TestSha256([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally { $sha.Dispose() }
}

$modulePath = Join-Path $Workspace 'operations\KingEAWatchdog.psm1'
Import-Module $modulePath -Force

$now = [datetime]'2026-07-27T00:00:00Z'
$state = New-KingEAWatchdogState -DeploymentId 'KINGEA-DEMO2-001'
$facts = Set-Failure (New-Facts $now)

$decision = Invoke-KingEAWatchdogEvaluation -State $state -Facts $facts
Assert-True ($decision.Action -eq 'RESTART_ONCE') 'first eligible failure permits one controlled restart'
Assert-True $decision.State.ReconciliationRequired 'restart must latch reconciliation-required quarantine'

$facts = Set-Failure (New-Facts $now.AddHours(1))
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts $facts
Assert-True ($decision.Action -eq 'MANUAL_REVIEW' -and $decision.State.ShortReviewLatched) 'second failure inside 24h latches short review'
Assert-True ($decision.State.ActiveEvents.Count -eq 2) 'short review retains both events in the 30-day counter'

$slow = New-KingEAWatchdogState -DeploymentId 'KINGEA-DEMO2-001'
$decision = Invoke-KingEAWatchdogEvaluation -State $slow -Facts (Set-Failure (New-Facts $now))
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts (Set-Healthy (New-Facts $now.AddHours(1)))
$facts = Set-Healthy (New-Facts $now.AddHours(25))
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts $facts
Assert-True $decision.State.AutoRestartArmed '24 continuously healthy hours rearms restart'
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts (Set-Failure (New-Facts $now.AddHours(26)))
Assert-True ($decision.Action -eq 'RESTART_ONCE') 'second slow-cadence failure receives a fresh single restart'
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts (Set-Healthy (New-Facts $now.AddHours(27)))
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts (Set-Healthy (New-Facts $now.AddHours(51)))
$decision = Invoke-KingEAWatchdogEvaluation -State $decision.State -Facts (Set-Failure (New-Facts $now.AddHours(52)))
Assert-True ($decision.Action -eq 'MANUAL_REVIEW' -and $decision.Reason -eq 'CUMULATIVE_THREE_IN_THIRTY_DAYS') 'third slow-cadence failure triggers cumulative review'

$mixed = New-KingEAWatchdogState -DeploymentId 'KINGEA-DEMO2-001'
$mixedDecision = Invoke-KingEAWatchdogEvaluation -State $mixed -Facts (Set-Failure (New-Facts $now))
$mixedDecision = Invoke-KingEAWatchdogEvaluation -State $mixedDecision.State -Facts (Set-Failure (New-Facts $now.AddHours(1)))
$mixedState = Approve-KingEAShortReview -State $mixedDecision.State -UtcNow $now.AddHours(2)
Assert-True ($mixedState.ActiveEvents.Count -eq 2) 'short review never clears the cumulative event set'
$mixedDecision = Invoke-KingEAWatchdogEvaluation -State $mixedState -Facts (Set-Healthy (New-Facts $now.AddHours(26)))
$mixedDecision = Invoke-KingEAWatchdogEvaluation -State $mixedDecision.State -Facts (Set-Failure (New-Facts $now.AddHours(27)))
Assert-True ($mixedDecision.Reason -eq 'CUMULATIVE_THREE_IN_THIRTY_DAYS') 'cluster plus isolated failure triggers cumulative review'

$simultaneous = New-KingEAWatchdogState -DeploymentId 'KINGEA-DEMO2-001'
$simultaneous.ActiveEvents = @(
    [pscustomobject]@{ Utc = $now.AddHours(-25).ToString('o'); Reason = 'CRASH'; Epoch = 0 },
    [pscustomobject]@{ Utc = $now.AddMinutes(-30).ToString('o'); Reason = 'STALE'; Epoch = 0 }
)
$simultaneousDecision = Invoke-KingEAWatchdogEvaluation -State $simultaneous -Facts (Set-Failure (New-Facts $now))
Assert-True ($simultaneousDecision.Reason -eq 'CUMULATIVE_THREE_IN_THIRTY_DAYS' -and $simultaneousDecision.State.ShortReviewLatched) 'cumulative review governs simultaneous thresholds'

$reviewed = Approve-KingEACumulativeReview -State $simultaneousDecision.State -UtcNow $now.AddHours(1) -EvidenceId 'INC-001' -Owner 'owner'
Assert-True ($reviewed.ActiveEvents.Count -eq 0 -and $reviewed.ArchivedEpochs.Count -eq 1 -and $reviewed.EscalationEpoch -eq 1) 'cumulative review archives events and starts a fresh epoch'
Assert-True (-not $reviewed.AutoRestartArmed -and $reviewed.ReconciliationRequired) 'post-review restart remains disarmed and quarantined'

$standdownState = New-KingEAWatchdogState -DeploymentId 'KINGEA-DEMO2-001'
$standdownFacts = Set-Failure (New-Facts $now)
$standdownFacts.StanddownActive = $true
$standdownDecision = Invoke-KingEAWatchdogEvaluation -State $standdownState -Facts $standdownFacts
Assert-True ($standdownDecision.Action -eq 'STANDDOWN' -and $standdownDecision.State.ActiveEvents.Count -eq 0) 'standdown excludes intentional stop from both counters'
$standdownFacts.StanddownActive = $false
$standdownFacts.PreLaunchStanddownActive = $true
$standdownDecision = Invoke-KingEAWatchdogEvaluation -State $standdownState -Facts $standdownFacts
Assert-True ($standdownDecision.Action -eq 'STANDDOWN') 'standdown appearing before launch wins the race'

$ambiguousFacts = Set-Failure (New-Facts $now)
$ambiguousFacts.MatchingProcessCount = 2
$ambiguousDecision = Invoke-KingEAWatchdogEvaluation -State (New-KingEAWatchdogState 'KINGEA-DEMO2-001') -Facts $ambiguousFacts
Assert-True ($ambiguousDecision.Action -eq 'QUARANTINE') 'ambiguous process identity never restarts or terminates'

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('kingea-stage7-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporary | Out-Null
try {
    $latch = Join-Path $temporary 'standdown.json'
    Assert-True (-not (Test-KingEAStanddownLatch -Path $latch -DeploymentId 'KINGEA-DEMO2-001')) 'absent standdown latch is inactive'
    [System.IO.File]::WriteAllText($latch, '{"broken":true}', [System.Text.UTF8Encoding]::new($false))
    Assert-True (Test-KingEAStanddownLatch -Path $latch -DeploymentId 'KINGEA-DEMO2-001') 'malformed standdown fails toward standdown'
    $record = [pscustomobject]@{ DeploymentId = 'KINGEA-DEMO2-001'; Operator = 'owner'; Utc = $now.ToString('o'); Reason = 'drill' }
    $record | ConvertTo-Json | Set-Content -LiteralPath $latch -Encoding UTF8
    Assert-True (Test-KingEAStanddownLatch -Path $latch -DeploymentId 'KINGEA-DEMO2-001') 'valid standdown latch is active'

    $helperRoot = Join-Path $temporary 'helper-common'
    $helperOutput = & (Join-Path $Workspace 'operations\Set-KingEAStanddown.ps1') `
        -DeploymentId 'KINGEA-DEMO2-HELPER' -Operator 'owner' -Reason 'test' `
        -CommonFilesRoot $helperRoot
    $helperLatch = Join-Path $helperRoot 'KingEA\control\KINGEA-DEMO2-HELPER\manual_standdown.json'
    Assert-True (($helperOutput -match 'KINGEA_STANDDOWN_ACTIVE').Count -gt 0 -and
                 (Test-KingEAStanddownLatch -Path $helperLatch -DeploymentId 'KINGEA-DEMO2-HELPER')) 'independent helper creates and verifies the standdown latch'

    $heartbeatPath = Join-Path $temporary 'heartbeat.dat'
    $unix = [datetimeoffset]$now
    $payload = @(
        'schema=1'
        'sequence=9'
        ('utc=' + $unix.ToUnixTimeSeconds())
        'deployment_id=KINGEA-DEMO2-001'
        'configuration_hash=CFG_V1'
        'server_class=JustMarkets-Demo2'
        'process_id=1234'
        'executable_path=C:\Program Files\MetaTrader 5\terminal64.exe'
        'data_root=D0E8209F77C8CF37AD8BF550E51FF075'
    ) -join "`n"
    $payload += "`n"
    [System.IO.File]::WriteAllText($heartbeatPath, $payload + 'sha256=' + (Get-TestSha256 $payload) + "`n", [System.Text.UTF8Encoding]::new($false))
    $heartbeat = Read-KingEAHeartbeat -Path $heartbeatPath -DeploymentId 'KINGEA-DEMO2-001' -ConfigurationHash 'CFG_V1' -ServerClass 'JustMarkets-Demo2' -UtcNow $now
    Assert-True $heartbeat.Valid 'canonical heartbeat validates'
    $stale = Read-KingEAHeartbeat -Path $heartbeatPath -DeploymentId 'KINGEA-DEMO2-001' -ConfigurationHash 'CFG_V1' -ServerClass 'JustMarkets-Demo2' -UtcNow $now.AddSeconds(31)
    Assert-True (-not $stale.Valid -and $stale.Reason -eq 'STALE_OR_FUTURE') 'stale heartbeat fails closed'
    Add-Content -LiteralPath $heartbeatPath -Value 'tamper=1'
    $tampered = Read-KingEAHeartbeat -Path $heartbeatPath -DeploymentId 'KINGEA-DEMO2-001' -ConfigurationHash 'CFG_V1' -ServerClass 'JustMarkets-Demo2' -UtcNow $now
    Assert-True (-not $tampered.Valid) 'tampered heartbeat fails closed'

    $atomicPath = Join-Path $temporary 'state.json'
    Write-KingEAAtomicJson -Path $atomicPath -Value ([pscustomobject]@{ Sequence = 1 })
    $atomic = Read-KingEAAtomicJson -Path $atomicPath
    Assert-True ($atomic.Sequence -eq 1) 'watchdog state writes and reloads with checksum'
}
finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force
}

$processes = @(
    [pscustomobject]@{ Path = 'C:\Program Files\MetaTrader 5\terminal64.exe'; CommandLine = 'terminal64.exe /config:kingea.ini' },
    [pscustomobject]@{ Path = 'C:\Program Files\MetaTrader 5\terminal64.exe'; CommandLine = 'terminal64.exe C:\MT5_TradeBot_RC1' }
)
$matches = @(Get-KingEAMatchingProcesses -Processes $processes -ExpectedExecutablePath 'C:\Program Files\MetaTrader 5\terminal64.exe')
Assert-True ($matches.Count -eq 1 -and $matches[0].CommandLine -notmatch 'RC1') 'exact matching excludes the unrelated RC1 deployment'

Write-Output 'KINGEA_WATCHDOG_TEST_PASS: short/long counters, review epochs, standdown race, heartbeat integrity, and exact process identity.'
