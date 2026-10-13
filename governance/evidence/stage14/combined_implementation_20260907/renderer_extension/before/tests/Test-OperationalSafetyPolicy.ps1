param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "OPERATIONAL_SAFETY_POLICY_FAIL: $Message" }
}

$modulePath = Join-Path $Workspace 'MQL5\Include\KingEA\OperationalSafety.mqh'
$adapterPath = Join-Path $Workspace 'MQL5\Include\KingEA\BrokerInventoryAdapter.mqh'
$testPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestOperationalSafety.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\operational_safety_test_compile.log'
$watchdogModulePath = Join-Path $Workspace 'operations\KingEAWatchdog.psm1'
$watchdogRunnerPath = Join-Path $Workspace 'operations\KingEAWatchdog.ps1'
$standdownPath = Join-Path $Workspace 'operations\Set-KingEAStanddown.ps1'
$runbookPath = Join-Path $Workspace 'operations\KILL_SWITCH_RUNBOOK.md'
$configPath = Join-Path $Workspace 'config\watchdog.demo2.disabled.json'

$module = Get-Content -LiteralPath $modulePath -Raw
$adapter = Get-Content -LiteralPath $adapterPath -Raw
$testSource = Get-Content -LiteralPath $testPath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw
$watchdog = Get-Content -LiteralPath $watchdogModulePath -Raw
$runner = Get-Content -LiteralPath $watchdogRunnerPath -Raw
$standdown = Get-Content -LiteralPath $standdownPath -Raw
$runbook = Get-Content -LiteralPath $runbookPath -Raw
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

Assert-True (([regex]::Matches($module, 'void\s+KingEALoadPersistentState\s*\(')).Count -eq 1) 'one load interface must exist'
Assert-True (([regex]::Matches($module, 'void\s+KingEACommitPersistentState\s*\(')).Count -eq 1) 'one commit interface must exist'
Assert-True (([regex]::Matches($module, 'void\s+KingEAVerifyConfiguration\s*\(')).Count -eq 1) 'one configuration interface must exist'
Assert-True (([regex]::Matches($module, 'void\s+KingEAReconcileBrokerInventory\s*\(')).Count -eq 1) 'one reconciliation interface must exist'
Assert-True ($module.Contains('CRYPT_HASH_SHA256')) 'snapshots must use SHA-256'
Assert-True ($module.Contains('snapshot_A.dat') -and $module.Contains('snapshot_B.dat')) 'redundant A/B snapshots must exist'
Assert-True ($module.Contains('FileFlush(handle)') -and $module.Contains('FileMove(temp,FILE_COMMON,target')) 'commit must flush then move'
Assert-True ($module.Contains('REDUNDANT_PAIR_INVALID')) 'one invalid redundant member must quarantine'
Assert-True ($module.Contains('ROLLBACK_DETECTED')) 'rollback protection must exist'
Assert-True ($module.Contains('POSITION_MISSING_ALTERED_OR_DUPLICATED')) 'position mismatch must quarantine'
Assert-True ($module.Contains('ORDER_MISSING_ALTERED_OR_DUPLICATED')) 'order mismatch must quarantine'
Assert-True ($adapter.Contains('PositionsTotal()') -and $adapter.Contains('OrdersTotal()')) 'adapter must inspect live broker inventory'
Assert-True ($adapter.Contains('POSITION_IDENTIFIER') -and $adapter.Contains('POSITION_SL')) 'position identifier and broker stop must be captured'
Assert-True ($adapter.Contains('KINGEA|<sleeve_id>|<trade_group>') -or $adapter.Contains('tokens[0]!="KINGEA"')) 'ownership comment must be enforced'
Assert-True ($watchdog.Contains('CUMULATIVE_THREE_IN_THIRTY_DAYS')) '30-day cumulative latch must exist'
Assert-True ($watchdog.Contains('SECOND_FAILURE_IN_TWENTY_FOUR_HOURS')) '24-hour latch must exist'
Assert-True ($watchdog.IndexOf('if ($counts.Long -ge 3)') -lt $watchdog.IndexOf('if ($counts.Short -ge 2)')) 'cumulative review must govern simultaneous thresholds'
Assert-True ($watchdog.Contains('Approve-KingEAShortReview') -and $watchdog.Contains('$next.ActiveEvents = @()')) 'only cumulative review path may clear active events'
Assert-True ($runner.Contains('Kill-switch race guard') -and ([regex]::Matches($runner, 'Test-KingEAStanddownLatch')).Count -ge 2) 'runner must recheck standdown immediately before launch'
Assert-True ($runner.Contains('$processIdentityValid') -and $runner.Contains('$heartbeat.ProcessId') -and $runner.Contains('$heartbeat.DataRoot')) 'process close eligibility must bind PID and data root to the heartbeat'
Assert-True (([regex]::Matches($runner, '\$state\.AutoRestartArmed\s*=\s*\$false')).Count -ge 2 -and
             ([regex]::Matches($runner, '\$state\.ReconciliationRequired\s*=\s*\$true')).Count -ge 2) 'missing and corrupted watchdog state must both start disarmed and quarantined'
Assert-True ($runner.Contains('MT5_TradeBot_RC1') -or $watchdog.Contains('MT5_TradeBot_RC1')) 'unrelated RC1 deployment must be excluded'
Assert-True ($runbook.Contains('If the standdown helper cannot run') -and $runbook.Contains('stop or disable the KingEA watchdog')) 'runbook must contain the independent fallback as a numbered step'
Assert-True (-not [bool]$config.Enabled -and -not [bool]$config.InstallScheduledTask) 'watchdog must remain disabled and uninstalled'
Assert-True (-not [regex]::IsMatch($runner + $watchdog, '\b(Register-ScheduledTask|New-ScheduledTask)\b')) 'implementation must not install a scheduled task'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'operational contract must compile cleanly'

$mqlProhibited = '\b(OrderSend|OrderSendAsync|OrderCalcMargin|OrderCalcProfit|CTrade|PositionOpen|PositionClose|PositionModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|iATR|iADX|iCustom|WebRequest)\b'
Assert-True (-not [regex]::IsMatch($module + $adapter + $testSource, $mqlProhibited)) 'MQL5 stage must contain no trading, history, indicator, network, or performance APIs'
Assert-True (-not ($module + $adapter + $testSource).Contains('MqlTick.flags')) 'MQL5 stage must not reference tick flags'
Assert-True (-not [regex]::IsMatch($module + $adapter + $testSource, '#import')) 'MQL5 stage must not import DLLs'
Assert-True (-not [regex]::IsMatch($runner + $watchdog + $standdown, '\b(OrderSend|PositionOpen|PositionClose|PositionModify|HistorySelect|TesterStatistics)\b')) 'PowerShell stage must contain no trading or performance capability'

Write-Output 'OPERATIONAL_SAFETY_POLICY_PASS: A/B persistence, broker reconciliation, configuration epochs, watchdog escalation, standdown race, and prohibitions verified.'
