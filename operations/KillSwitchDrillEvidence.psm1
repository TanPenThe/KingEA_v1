Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-KingEAKillSwitchResult {
    param([bool]$Pass, [string]$Reason)
    [pscustomobject]@{ Pass = $Pass; Reason = $Reason }
}

function Get-KingEAStringSha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Get-KingEAScreenshotEntry {
    param($Screenshots, [string]$Name)
    if ($Screenshots -is [System.Collections.IDictionary]) {
        return $Screenshots[$Name]
    }
    return $Screenshots.PSObject.Properties[$Name].Value
}

function Read-KingEAInventoryEvidence {
    param(
        [Parameter(Mandatory)]$Reference,
        [Parameter(Mandatory)][string]$ExpectedServer,
        [Parameter(Mandatory)][string]$ExpectedSuffix,
        [Parameter(Mandatory)][string]$ExpectedFingerprint
    )
    $path = [string]$Reference.Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw 'INVENTORY_EVIDENCE_MISSING'
    }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -ne [string]$Reference.Sha256) {
        throw 'INVENTORY_EVIDENCE_HASH_MISMATCH'
    }
    $rows = Import-Csv -LiteralPath $path
    $values = @{}
    foreach ($row in $rows) {
        if ($values.ContainsKey([string]$row.key)) {
            throw ('INVENTORY_DUPLICATE_KEY:' + [string]$row.key)
        }
        $values[[string]$row.key] = [string]$row.value
    }
    if ($values.scope -ne 'READ_ONLY_KILL_SWITCH_EVIDENCE' -or
        $values.drill_id -ne 'DRILL-DEMO-001' -or
        $values.server -ne $ExpectedServer -or
        $values.account_suffix -ne $ExpectedSuffix -or
        $values.account_fingerprint -ne $ExpectedFingerprint -or
        $values.order_capability -ne 'PROHIBITED_AND_ABSENT' -or
        $values.performance_authorization -ne 'DENIED') {
        throw 'INVENTORY_IDENTITY_INVALID'
    }
    return $values
}

function Test-KingEAKillSwitchDrillEvidence {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Evidence)

    try {
        $serialized = $Evidence | ConvertTo-Json -Depth 30 -Compress
        if ($serialized -match '"(AccountLogin|AccountNumber|RawLogin|Login)"\s*:') {
            return New-KingEAKillSwitchResult $false 'RAW_ACCOUNT_IDENTIFIER_PRESENT'
        }
        if ([int]$Evidence.Schema -ne 1 -or
            [string]$Evidence.DrillId -ne 'DRILL-DEMO-001' -or
            [string]$Evidence.DeploymentId -ne 'KINGEA-DEMO2-001') {
            return New-KingEAKillSwitchResult $false 'IDENTITY_INVALID'
        }
        if ([string]$Evidence.ServerClass -ne 'JustMarkets-Demo2' -or
            [string]$Evidence.AccountSuffix -notmatch '^\d{4}$' -or
            [string]$Evidence.AccountFingerprint -notmatch '^[0-9A-F]{64}$') {
            return New-KingEAKillSwitchResult $false 'DEMO2_IDENTITY_INVALID'
        }
        $preflightInventory = Read-KingEAInventoryEvidence `
            -Reference $Evidence.Inventory.Preflight `
            -ExpectedServer ([string]$Evidence.ServerClass) `
            -ExpectedSuffix ([string]$Evidence.AccountSuffix) `
            -ExpectedFingerprint ([string]$Evidence.AccountFingerprint)
        $fixtureInventory = Read-KingEAInventoryEvidence `
            -Reference $Evidence.Inventory.Fixtures `
            -ExpectedServer ([string]$Evidence.ServerClass) `
            -ExpectedSuffix ([string]$Evidence.AccountSuffix) `
            -ExpectedFingerprint ([string]$Evidence.AccountFingerprint)
        $finalInventory = Read-KingEAInventoryEvidence `
            -Reference $Evidence.Inventory.Final `
            -ExpectedServer ([string]$Evidence.ServerClass) `
            -ExpectedSuffix ([string]$Evidence.AccountSuffix) `
            -ExpectedFingerprint ([string]$Evidence.AccountFingerprint)
        if ([int]$preflightInventory.position_count -ne 0 -or
            [int]$preflightInventory.order_count -ne 0) {
            return New-KingEAKillSwitchResult $false 'PREFLIGHT_INVENTORY_NONZERO'
        }

        $start = [datetimeoffset]::Parse([string]$Evidence.StartUtc)
        $fixture = [datetimeoffset]::Parse([string]$Evidence.FixtureCreatedUtc)
        $standdown = [datetimeoffset]::Parse([string]$Evidence.StanddownUtc)
        $automation = [datetimeoffset]::Parse([string]$Evidence.AutomationDisabledUtc)
        $mobile = [datetimeoffset]::Parse([string]$Evidence.MobileActionUtc)
        $flat = [datetimeoffset]::Parse([string]$Evidence.FlatVerifiedUtc)
        $stopped = [datetimeoffset]::Parse([string]$Evidence.TerminalStoppedUtc)
        $complete = [datetimeoffset]::Parse([string]$Evidence.ObservationCompletedUtc)
        if (-not ($start -le $fixture -and $fixture -lt $standdown -and
                  $standdown -le $automation -and $automation -lt $mobile -and
                  $mobile -le $flat -and $flat -le $stopped -and
                  $stopped -lt $complete)) {
            return New-KingEAKillSwitchResult $false 'TIMESTAMP_ORDER_INVALID'
        }

        if ([string]$Evidence.Position.Ticket -notmatch '^\d+$' -or
            [string]$Evidence.Position.Symbol -ne 'ETHUSD.s' -or
            [string]$Evidence.Position.Direction -notin @('BUY','SELL') -or
            [math]::Abs([double]$Evidence.Position.Volume - 0.01) -gt 1e-9 -or
            [double]$Evidence.Position.EntryPrice -le 0 -or
            [double]$Evidence.Position.StopLoss -le 0 -or
            [string]$Evidence.PendingOrder.Ticket -notmatch '^\d+$' -or
            [string]$Evidence.PendingOrder.Symbol -ne 'ETHUSD.s' -or
            [string]$Evidence.PendingOrder.Type -notin @('BUY_LIMIT','SELL_LIMIT') -or
            [math]::Abs([double]$Evidence.PendingOrder.Volume - 0.01) -gt 1e-9 -or
            [double]$Evidence.PendingOrder.ReferencePrice -le 0 -or
            [double]$Evidence.PendingOrder.EntryPrice -le 0 -or
            [double]$Evidence.PendingOrder.StopLoss -le 0) {
            return New-KingEAKillSwitchResult $false 'FIXTURE_INVALID'
        }
        $positionStopFraction = if ([string]$Evidence.Position.Direction -eq 'BUY') {
            ([double]$Evidence.Position.EntryPrice - [double]$Evidence.Position.StopLoss) /
                [double]$Evidence.Position.EntryPrice
        } else {
            ([double]$Evidence.Position.StopLoss - [double]$Evidence.Position.EntryPrice) /
                [double]$Evidence.Position.EntryPrice
        }
        $pendingDistanceFraction = [math]::Abs(
            [double]$Evidence.PendingOrder.ReferencePrice - [double]$Evidence.PendingOrder.EntryPrice
        ) / [double]$Evidence.PendingOrder.ReferencePrice
        $pendingStopFraction = if ([string]$Evidence.PendingOrder.Type -eq 'BUY_LIMIT') {
            ([double]$Evidence.PendingOrder.EntryPrice - [double]$Evidence.PendingOrder.StopLoss) /
                [double]$Evidence.PendingOrder.EntryPrice
        } else {
            ([double]$Evidence.PendingOrder.StopLoss - [double]$Evidence.PendingOrder.EntryPrice) /
                [double]$Evidence.PendingOrder.EntryPrice
        }
        if ($positionStopFraction -lt 0.04 -or $positionStopFraction -gt 0.06 -or
            $pendingDistanceFraction -lt 0.15 -or $pendingDistanceFraction -gt 0.25 -or
            $pendingStopFraction -lt 0.04 -or $pendingStopFraction -gt 0.06) {
            return New-KingEAKillSwitchResult $false 'FIXTURE_DISTANCE_INVALID'
        }
        $expectedPositionType = if ([string]$Evidence.Position.Direction -eq 'BUY') { '0' } else { '1' }
        $expectedOrderType = if ([string]$Evidence.PendingOrder.Type -eq 'BUY_LIMIT') { '2' } else { '3' }
        if ([int]$fixtureInventory.position_count -ne 1 -or
            [int]$fixtureInventory.order_count -ne 1 -or
            $fixtureInventory.position_0_ticket -ne [string]$Evidence.Position.Ticket -or
            $fixtureInventory.position_0_symbol -ne 'ETHUSD.s' -or
            $fixtureInventory.position_0_type -ne $expectedPositionType -or
            [math]::Abs([double]$fixtureInventory.position_0_volume - 0.01) -gt 1e-9 -or
            [double]$fixtureInventory.position_0_stop_loss -le 0 -or
            $fixtureInventory.order_0_ticket -ne [string]$Evidence.PendingOrder.Ticket -or
            $fixtureInventory.order_0_symbol -ne 'ETHUSD.s' -or
            $fixtureInventory.order_0_type -ne $expectedOrderType -or
            [math]::Abs([double]$fixtureInventory.order_0_volume_initial - 0.01) -gt 1e-9 -or
            [double]$fixtureInventory.order_0_stop_loss -le 0) {
            return New-KingEAKillSwitchResult $false 'FIXTURE_INVENTORY_MISMATCH'
        }
        if (-not [bool]$Evidence.Position.ActiveUntilMobileAction -or
            -not [bool]$Evidence.PendingOrder.ActiveUntilMobileAction) {
            return New-KingEAKillSwitchResult $false 'FIXTURE_SELF_RESOLVED'
        }
        if ([string]$Evidence.Position.Resolution -ne 'MANUAL_MOBILE_CLOSE' -or
            [string]$Evidence.PendingOrder.Resolution -ne 'MANUAL_MOBILE_DELETE') {
            return New-KingEAKillSwitchResult $false 'MOBILE_RESOLUTION_NOT_PROVED'
        }
        if ([string]$Evidence.PendingOrder.ExpirationUtc -ne 'GTC') {
            $expiry = [datetimeoffset]::Parse([string]$Evidence.PendingOrder.ExpirationUtc)
            if (($expiry - $fixture).TotalHours -lt 4) {
                return New-KingEAKillSwitchResult $false 'PENDING_EXPIRY_TOO_SHORT'
            }
            if ($mobile -ge $expiry) {
                return New-KingEAKillSwitchResult $false 'PENDING_EXPIRED_BEFORE_DELETE'
            }
        }

        if (-not [bool]$Evidence.Standdown.Active -or
            -not (Test-Path -LiteralPath ([string]$Evidence.Standdown.Path))) {
            return New-KingEAKillSwitchResult $false 'STANDDOWN_MISSING'
        }
        $latchHash = (Get-FileHash -Algorithm SHA256 -LiteralPath ([string]$Evidence.Standdown.Path)).Hash
        if ($latchHash -ne [string]$Evidence.Standdown.Sha256) {
            return New-KingEAKillSwitchResult $false 'STANDDOWN_HASH_MISMATCH'
        }
        if (-not [bool]$Evidence.Watchdog.ForegroundOnce -or
            [string]$Evidence.Watchdog.Command -notmatch '(?i)KingEAWatchdog\.ps1.+-Once' -or
            [string]$Evidence.Watchdog.Action -ne 'STANDDOWN' -or
            -not (Test-Path -LiteralPath ([string]$Evidence.Watchdog.OutboxPath))) {
            return New-KingEAKillSwitchResult $false 'WATCHDOG_STANDDOWN_NOT_PROVED'
        }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath ([string]$Evidence.Watchdog.OutboxPath)).Hash -ne
            [string]$Evidence.Watchdog.OutboxSha256) {
            return New-KingEAKillSwitchResult $false 'WATCHDOG_OUTBOX_HASH_MISMATCH'
        }
        if ([string]$Evidence.Watchdog.ProcessAction -ne 'NONE') {
            return New-KingEAKillSwitchResult $false 'WATCHDOG_PROCESS_ACTION'
        }
        if ((Get-KingEAStringSha256 ([string]$Evidence.Watchdog.EphemeralConfigCanonical)) -ne
            [string]$Evidence.Watchdog.EphemeralConfigSha256) {
            return New-KingEAKillSwitchResult $false 'WATCHDOG_CONFIG_HASH_MISMATCH'
        }
        if (-not [bool]$Evidence.Automation.ToolbarDisabled -or
            -not [bool]$Evidence.Automation.OptionsDisabled -or
            -not [bool]$Evidence.Automation.HostedDuplicateAbsent) {
            return New-KingEAKillSwitchResult $false 'AUTOMATION_NOT_DISABLED'
        }

        foreach ($name in @('preflight_desktop','preflight_mobile','fixtures','algo_disabled',
                             'mobile_flat','desktop_flat','terminal_stopped')) {
            $entry = Get-KingEAScreenshotEntry $Evidence.Screenshots $name
            if (-not $entry -or -not (Test-Path -LiteralPath ([string]$entry.Path))) {
                return New-KingEAKillSwitchResult $false ('SCREENSHOT_MISSING_' + $name.ToUpperInvariant())
            }
            if ((Get-FileHash -Algorithm SHA256 -LiteralPath ([string]$entry.Path)).Hash -ne
                [string]$entry.Sha256) {
                return New-KingEAKillSwitchResult $false ('SCREENSHOT_HASH_MISMATCH_' + $name.ToUpperInvariant())
            }
        }

        if ([int]$Evidence.Final.DesktopPositions -ne 0 -or
            [int]$Evidence.Final.DesktopOrders -ne 0 -or
            [int]$Evidence.Final.MobilePositions -ne 0 -or
            [int]$Evidence.Final.MobileOrders -ne 0) {
            return New-KingEAKillSwitchResult $false 'FINAL_INVENTORY_NONZERO'
        }
        if ([int]$finalInventory.position_count -ne 0 -or
            [int]$finalInventory.order_count -ne 0) {
            return New-KingEAKillSwitchResult $false 'FINAL_BROKER_INVENTORY_NONZERO'
        }
        if ([int]$Evidence.Final.TerminalProcessCount -ne 0 -or
            [int]$Evidence.Final.KingEAScheduledTaskCount -ne 0 -or
            [int]$Evidence.Final.ObservationSeconds -lt 60 -or
            -not [bool]$Evidence.Final.StanddownActive) {
            return New-KingEAKillSwitchResult $false 'FINAL_QUARANTINE_INVALID'
        }
        if ([bool]$Evidence.Authorization.Live2Access -or
            [bool]$Evidence.Authorization.Performance -or
            [bool]$Evidence.Authorization.OosHoldout -or
            [bool]$Evidence.Authorization.AutomatedOrderCode -or
            [bool]$Evidence.Authorization.Dll -or
            [bool]$Evidence.Authorization.Network) {
            return New-KingEAKillSwitchResult $false 'PROHIBITED_CAPABILITY_PRESENT'
        }

        return New-KingEAKillSwitchResult $true 'PASS'
    }
    catch {
        return New-KingEAKillSwitchResult $false ('MALFORMED_EVIDENCE:' + $_.Exception.Message)
    }
}

Export-ModuleMember -Function 'Test-KingEAKillSwitchDrillEvidence'
