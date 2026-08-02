param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "KILL_SWITCH_DRILL_TEST_FAIL: $Message" }
}

function Get-TestSha256([string]$Text) {
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

Import-Module (Join-Path $Workspace 'operations\KillSwitchDrillEvidence.psm1') -Force

$root = Join-Path ([System.IO.Path]::GetTempPath()) ('kingea-stage9-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $screens = @{}
    foreach ($name in @('preflight_desktop','preflight_mobile','fixtures','algo_disabled',
                         'mobile_flat','desktop_flat','terminal_stopped')) {
        $path = Join-Path $root ($name + '.png')
        [System.IO.File]::WriteAllBytes($path, [byte[]](1,2,3,4,[byte]$name.Length))
        $screens[$name] = [pscustomobject]@{
            Path = $path
            Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
        }
    }
    $latchPath = Join-Path $root 'manual_standdown.json'
    [System.IO.File]::WriteAllText($latchPath, '{"DeploymentId":"KINGEA-DEMO2-001","Operator":"tpent","Utc":"2026-07-28T02:02:00Z","Reason":"STAGE9_DEMO_KILL_SWITCH_DRILL"}')
    $outboxPath = Join-Path $root 'watchdog-outbox.json'
    [System.IO.File]::WriteAllText($outboxPath, '{"Decision":"STANDDOWN","ProcessAction":"NONE"}')
    $accountFingerprint = ('A' * 64)
    function New-InventoryFile([string]$Name, [int]$Positions, [int]$Orders) {
        $path = Join-Path $root ($Name + '.csv')
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in @(
            'key,value',
            'scope,READ_ONLY_KILL_SWITCH_EVIDENCE',
            'drill_id,DRILL-DEMO-001',
            'server,JustMarkets-Demo2',
            'account_suffix,1768',
            ('account_fingerprint,' + $accountFingerprint),
            ('position_count,' + $Positions)
        )) { $lines.Add($line) }
        if ($Positions -eq 1) {
            foreach ($line in @(
                'position_0_ticket,900001','position_0_symbol,ETHUSD.s',
                'position_0_type,0','position_0_volume,0.01000000',
                'position_0_open_price,2000.00000000','position_0_stop_loss,1900.00000000',
                'position_0_take_profit,0.00000000'
            )) { $lines.Add($line) }
        }
        $lines.Add('order_count,' + $Orders)
        if ($Orders -eq 1) {
            foreach ($line in @(
                'order_0_ticket,900002','order_0_symbol,ETHUSD.s',
                'order_0_type,2','order_0_volume_initial,0.01000000',
                'order_0_entry_price,1600.00000000','order_0_stop_loss,1520.00000000',
                'order_0_take_profit,0.00000000','order_0_expiration,1785236400'
            )) { $lines.Add($line) }
        }
        $lines.Add('order_capability,PROHIBITED_AND_ABSENT')
        $lines.Add('performance_authorization,DENIED')
        [System.IO.File]::WriteAllLines($path, $lines)
        [pscustomobject]@{ Path = $path; Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }
    }
    $inventory = [pscustomobject]@{
        Preflight = New-InventoryFile 'preflight_inventory' 0 0
        Fixtures = New-InventoryFile 'fixture_inventory' 1 1
        Final = New-InventoryFile 'final_inventory' 0 0
    }
    $watchdogCanonical = '{"Enabled":true,"DeploymentId":"KINGEA-DEMO2-001","InstallScheduledTask":false,"Once":true}'

    $start = [datetime]'2026-07-28T02:00:00Z'
    $evidence = [pscustomobject]@{
        Schema = 1
        DrillId = 'DRILL-DEMO-001'
        DeploymentId = 'KINGEA-DEMO2-001'
        ServerClass = 'JustMarkets-Demo2'
        AccountSuffix = '1768'
        AccountFingerprint = $accountFingerprint
        Inventory = $inventory
        StartUtc = $start.ToString('o')
        FixtureCreatedUtc = $start.AddMinutes(1).ToString('o')
        StanddownUtc = $start.AddMinutes(2).ToString('o')
        AutomationDisabledUtc = $start.AddMinutes(3).ToString('o')
        MobileActionUtc = $start.AddMinutes(4).ToString('o')
        FlatVerifiedUtc = $start.AddMinutes(5).ToString('o')
        TerminalStoppedUtc = $start.AddMinutes(6).ToString('o')
        ObservationCompletedUtc = $start.AddMinutes(7).ToString('o')
        Position = [pscustomobject]@{
            Ticket = '900001'; Symbol = 'ETHUSD.s'; Direction = 'BUY'
            Volume = 0.01; EntryPrice = 2000.0
            StopLoss = 1900.0; Resolution = 'MANUAL_MOBILE_CLOSE'
            ActiveUntilMobileAction = $true
        }
        PendingOrder = [pscustomobject]@{
            Ticket = '900002'; Symbol = 'ETHUSD.s'; Type = 'BUY_LIMIT'
            Volume = 0.01; ReferencePrice = 2000.0; EntryPrice = 1600.0
            StopLoss = 1520.0; ExpirationUtc = $start.AddHours(6).ToString('o')
            Resolution = 'MANUAL_MOBILE_DELETE'
            ActiveUntilMobileAction = $true
        }
        Standdown = [pscustomobject]@{
            Active = $true; Path = $latchPath
            Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $latchPath).Hash
        }
        Watchdog = [pscustomobject]@{
            ForegroundOnce = $true
            Command = 'operations\KingEAWatchdog.ps1 -ConfigPath ephemeral.json -Once'
            Action = 'STANDDOWN'; OutboxPath = $outboxPath
            OutboxSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $outboxPath).Hash
            ProcessAction = 'NONE'; EphemeralConfigCanonical = $watchdogCanonical
            EphemeralConfigSha256 = (Get-TestSha256 $watchdogCanonical)
        }
        Automation = [pscustomobject]@{
            ToolbarDisabled = $true; OptionsDisabled = $true
            HostedDuplicateAbsent = $true
        }
        Screenshots = $screens
        Final = [pscustomobject]@{
            DesktopPositions = 0; DesktopOrders = 0
            MobilePositions = 0; MobileOrders = 0
            TerminalProcessCount = 0; KingEAScheduledTaskCount = 0
            ObservationSeconds = 60; StanddownActive = $true
        }
        Authorization = [pscustomobject]@{
            Live2Access = $false; Performance = $false; OosHoldout = $false
            AutomatedOrderCode = $false; Dll = $false; Network = $false
        }
    }

    $decision = Test-KingEAKillSwitchDrillEvidence -Evidence $evidence
    Assert-True $decision.Pass 'complete bounded Demo2 evidence must pass'
    Assert-True ($decision.Reason -eq 'PASS') 'passing result has stable reason'

    $evidence.PendingOrder.ExpirationUtc = $start.AddHours(2).ToString('o')
    $decision = Test-KingEAKillSwitchDrillEvidence -Evidence $evidence
    Assert-True (-not $decision.Pass -and $decision.Reason -eq 'PENDING_EXPIRY_TOO_SHORT') 'expiry shorter than four hours fails'
    $evidence.PendingOrder.ExpirationUtc = $start.AddHours(6).ToString('o')

    $evidence.Position.ActiveUntilMobileAction = $false
    $decision = Test-KingEAKillSwitchDrillEvidence -Evidence $evidence
    Assert-True (-not $decision.Pass -and $decision.Reason -eq 'FIXTURE_SELF_RESOLVED') 'self-resolved fixture fails'
    $evidence.Position.ActiveUntilMobileAction = $true

    $evidence.Watchdog.ProcessAction = 'RESTART'
    $decision = Test-KingEAKillSwitchDrillEvidence -Evidence $evidence
    Assert-True (-not $decision.Pass -and $decision.Reason -eq 'WATCHDOG_PROCESS_ACTION') 'restart after standdown fails'
    $evidence.Watchdog.ProcessAction = 'NONE'

    $evidence.Final.MobileOrders = 1
    $decision = Test-KingEAKillSwitchDrillEvidence -Evidence $evidence
    Assert-True (-not $decision.Pass -and $decision.Reason -eq 'FINAL_INVENTORY_NONZERO') 'nonzero final inventory fails'
    $evidence.Final.MobileOrders = 0

    $evidence | Add-Member -NotePropertyName AccountLogin -NotePropertyValue '9999999999'
    $decision = Test-KingEAKillSwitchDrillEvidence -Evidence $evidence
    Assert-True (-not $decision.Pass -and $decision.Reason -eq 'RAW_ACCOUNT_IDENTIFIER_PRESENT') 'raw account identifier fails'

    Write-Output 'KILL_SWITCH_DRILL_TEST_PASS: bounded fixtures, ordering, standdown, mobile resolution, screenshot hashes, zero inventory, and prohibitions verified.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
