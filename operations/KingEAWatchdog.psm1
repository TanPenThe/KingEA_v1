Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ShortWindow = [timespan]::FromHours(24)
$script:LongWindow = [timespan]::FromDays(30)
$script:HealthyRearmWindow = [timespan]::FromHours(24)

function Copy-KingEAObject {
    param([Parameter(Mandatory)]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
}

function New-KingEAWatchdogState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DeploymentId)

    [pscustomobject]@{
        Schema = 1
        DeploymentId = $DeploymentId
        EscalationEpoch = 0
        AutoRestartArmed = $true
        ReconciliationRequired = $false
        ShortReviewLatched = $false
        CumulativeReviewLatched = $false
        HealthySinceUtc = $null
        ActiveEvents = @()
        ArchivedEpochs = @()
    }
}

function Get-KingEAEventCounts {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][datetime]$UtcNow
    )

    $shortFloor = $UtcNow.Subtract($script:ShortWindow)
    $longFloor = $UtcNow.Subtract($script:LongWindow)
    $events = @($State.ActiveEvents | Where-Object {
        $eventUtc = [datetimeoffset]::Parse([string]$_.Utc).UtcDateTime
        $eventUtc -gt $longFloor -and $eventUtc -le $UtcNow
    })
    [pscustomobject]@{
        Active = $events
        Short = @($events | Where-Object {
            [datetimeoffset]::Parse([string]$_.Utc).UtcDateTime -gt $shortFloor
        }).Count
        Long = $events.Count
    }
}

function New-KingEADecision {
    param($State, [string]$Action, [string]$Reason)
    [pscustomobject]@{
        Action = $Action
        Reason = $Reason
        Tier = if ($Action -in @('RESTART_ONCE', 'HEALTHY', 'PLANNED_STOP', 'STANDDOWN')) { 2 } else { 1 }
        State = $State
    }
}

function Invoke-KingEAWatchdogEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)]$Facts
    )

    $next = Copy-KingEAObject $State
    $now = ([datetime]$Facts.UtcNow).ToUniversalTime()

    if ($Facts.StanddownActive -or $Facts.PreLaunchStanddownActive) {
        return New-KingEADecision $next 'STANDDOWN' 'MANUAL_STANDDOWN_ACTIVE'
    }
    if ($Facts.PlannedStop) {
        return New-KingEADecision $next 'PLANNED_STOP' 'INTENTIONAL_STOP_EXCLUDED'
    }

    if ($Facts.Healthy) {
        if (-not $next.HealthySinceUtc) {
            $next.HealthySinceUtc = $now.ToString('o')
        }
        $continuous = $now - ([datetime]$next.HealthySinceUtc).ToUniversalTime()
        if ($continuous -ge $script:HealthyRearmWindow -and
            $Facts.Reconciled -and $Facts.IdentityValid -and
            $Facts.ConfigurationValid -and
            -not $next.ShortReviewLatched -and
            -not $next.CumulativeReviewLatched) {
            $next.AutoRestartArmed = $true
            $next.ReconciliationRequired = $false
        }
        return New-KingEADecision $next 'HEALTHY' 'HEARTBEAT_HEALTHY'
    }

    if (-not $Facts.Failure) {
        return New-KingEADecision $next 'QUARANTINE' 'INDETERMINATE_WATCHDOG_FACTS'
    }

    $next.HealthySinceUtc = $null
    $event = [pscustomobject]@{
        Utc = $now.ToString('o')
        Reason = [string]$Facts.FailureReason
        Epoch = [int]$next.EscalationEpoch
    }
    $existingEvents = @($next.ActiveEvents)
    $next.ActiveEvents = @($existingEvents) + @($event)
    $counts = Get-KingEAEventCounts -State $next -UtcNow $now
    $next.ReconciliationRequired = $true

    if ([int]$Facts.MatchingProcessCount -gt 1 -or [int]$Facts.MatchingProcessCount -lt 0) {
        return New-KingEADecision $next 'QUARANTINE' 'PROCESS_IDENTITY_AMBIGUOUS'
    }

    # The cumulative gate is the stricter governing latch whenever both match.
    if ($counts.Long -ge 3) {
        $next.CumulativeReviewLatched = $true
        $next.ShortReviewLatched = ($counts.Short -ge 2)
        $next.AutoRestartArmed = $false
        return New-KingEADecision $next 'MANUAL_REVIEW' 'CUMULATIVE_THREE_IN_THIRTY_DAYS'
    }
    if ($counts.Short -ge 2) {
        $next.ShortReviewLatched = $true
        $next.AutoRestartArmed = $false
        return New-KingEADecision $next 'MANUAL_REVIEW' 'SECOND_FAILURE_IN_TWENTY_FOUR_HOURS'
    }
    if (-not $next.AutoRestartArmed) {
        return New-KingEADecision $next 'MANUAL_REVIEW' 'AUTOMATIC_RESTART_NOT_REARMED'
    }
    if ($Facts.PreLaunchStanddownActive) {
        return New-KingEADecision $next 'STANDDOWN' 'STANDDOWN_APPEARED_BEFORE_LAUNCH'
    }

    $next.AutoRestartArmed = $false
    return New-KingEADecision $next 'RESTART_ONCE' 'FIRST_ELIGIBLE_FAILURE'
}

function Approve-KingEAShortReview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][datetime]$UtcNow
    )
    $next = Copy-KingEAObject $State
    $next.ShortReviewLatched = $false
    $next.AutoRestartArmed = $false
    $next.ReconciliationRequired = $true
    $next.HealthySinceUtc = $UtcNow.ToUniversalTime().ToString('o')
    return $next
}

function Approve-KingEACumulativeReview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][datetime]$UtcNow,
        [Parameter(Mandatory)][string]$EvidenceId,
        [Parameter(Mandatory)][string]$Owner
    )
    $next = Copy-KingEAObject $State
    $archive = [pscustomobject]@{
        Epoch = [int]$next.EscalationEpoch
        ApprovedUtc = $UtcNow.ToUniversalTime().ToString('o')
        EvidenceId = $EvidenceId
        Owner = $Owner
        Events = @($next.ActiveEvents)
    }
    $next.ArchivedEpochs = @($next.ArchivedEpochs) + @($archive)
    $next.ActiveEvents = @()
    $next.EscalationEpoch = [int]$next.EscalationEpoch + 1
    $next.ShortReviewLatched = $false
    $next.CumulativeReviewLatched = $false
    $next.AutoRestartArmed = $false
    $next.ReconciliationRequired = $true
    $next.HealthySinceUtc = $UtcNow.ToUniversalTime().ToString('o')
    return $next
}

function Get-KingEASha256 {
    param([Parameter(Mandatory)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Write-KingEAAtomicJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $temporary = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 20
    $payload = [pscustomobject]@{
        PayloadJson = $json
        Sha256 = Get-KingEASha256 ($json + "`n")
    } | ConvertTo-Json -Depth 25
    [System.IO.File]::WriteAllText($temporary, $payload, [System.Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.bak"
        [System.IO.File]::Replace($temporary, $Path, $backup, $true)
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Force
        }
    }
    else {
        [System.IO.File]::Move($temporary, $Path)
    }
}

function Read-KingEAAtomicJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $wrapper = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $wrapper.PayloadJson -or -not $wrapper.Sha256) {
            throw 'MALFORMED_ATOMIC_JSON'
        }
        if ((Get-KingEASha256 ([string]$wrapper.PayloadJson + "`n")) -ne [string]$wrapper.Sha256) {
            throw 'ATOMIC_JSON_CHECKSUM_FAILURE'
        }
        return ([string]$wrapper.PayloadJson | ConvertFrom-Json)
    }
    catch {
        throw "KINGEA_ATOMIC_STATE_INVALID: $($_.Exception.Message)"
    }
}

function Test-KingEAStanddownLatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$DeploymentId
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $record.DeploymentId -or -not $record.Operator -or
            -not $record.Utc -or -not $record.Reason) { return $true }
        if ([string]$record.DeploymentId -ne $DeploymentId) { return $true }
        [void][datetime]::Parse([string]$record.Utc)
        return $true
    }
    catch {
        return $true
    }
}

function Read-KingEAHeartbeat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$DeploymentId,
        [Parameter(Mandatory)][string]$ConfigurationHash,
        [Parameter(Mandatory)][string]$ServerClass,
        [Parameter(Mandatory)][datetime]$UtcNow,
        [int]$StaleSeconds = 30
    )
    $bad = { param($reason) [pscustomobject]@{ Valid = $false; Reason = $reason } }
    if (-not (Test-Path -LiteralPath $Path)) { return & $bad 'MISSING' }
    try {
        $text = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
        $normalized = $text.Replace("`r`n", "`n")
        $lines = @($normalized.Split("`n") | Where-Object { $_ -ne '' })
        if ($lines.Count -ne 10 -or $lines[-1] -notmatch '^sha256=([0-9A-F]{64})$') {
            return & $bad 'MALFORMED'
        }
        $expectedHash = $Matches[1]
        $payload = (($lines[0..8] -join "`n") + "`n")
        if ((Get-KingEASha256 $payload) -ne $expectedHash) { return & $bad 'CHECKSUM' }
        $fields = @{}
        foreach ($line in $lines[0..8]) {
            $parts = $line.Split('=', 2)
            if ($parts.Count -ne 2 -or $fields.ContainsKey($parts[0])) { return & $bad 'FIELDS' }
            $fields[$parts[0]] = $parts[1]
        }
        if ($fields.deployment_id -ne $DeploymentId -or
            $fields.configuration_hash -ne $ConfigurationHash -or
            $fields.server_class -ne $ServerClass) { return & $bad 'IDENTITY' }
        $utc = [datetimeOffset]::FromUnixTimeSeconds([long]$fields.utc).UtcDateTime
        if (($UtcNow.ToUniversalTime() - $utc).TotalSeconds -gt $StaleSeconds -or
            $utc -gt $UtcNow.ToUniversalTime().AddSeconds(5)) { return & $bad 'STALE_OR_FUTURE' }
        [pscustomobject]@{
            Valid = $true
            Reason = 'OK'
            Sequence = [long]$fields.sequence
            Utc = $utc
            ProcessId = [long]$fields.process_id
            ExecutablePath = $fields.executable_path
            DataRoot = $fields.data_root
        }
    }
    catch {
        return & $bad 'UNREADABLE'
    }
}

function Get-KingEAMatchingProcesses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Processes,
        [Parameter(Mandatory)][string]$ExpectedExecutablePath
    )
    @($Processes | Where-Object {
        $_.Path -and
        [string]::Equals([System.IO.Path]::GetFullPath([string]$_.Path),
                         [System.IO.Path]::GetFullPath($ExpectedExecutablePath),
                         [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]$_.CommandLine -notmatch 'MT5_TradeBot_RC1'
    })
}

Export-ModuleMember -Function @(
    'New-KingEAWatchdogState',
    'Invoke-KingEAWatchdogEvaluation',
    'Approve-KingEAShortReview',
    'Approve-KingEACumulativeReview',
    'Write-KingEAAtomicJson',
    'Read-KingEAAtomicJson',
    'Test-KingEAStanddownLatch',
    'Read-KingEAHeartbeat',
    'Get-KingEAMatchingProcesses'
)
