param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "KILL_SWITCH_DRILL_POLICY_FAIL: $Message" }
}

$capturePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\CaptureKillSwitchInventory.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\kill_switch_inventory_compile.log'
$modulePath = Join-Path $Workspace 'operations\KillSwitchDrillEvidence.psm1'
$testPath = Join-Path $Workspace 'tests\Test-KillSwitchDrillEvidence.ps1'
$runbookPath = Join-Path $Workspace 'operations\KILL_SWITCH_RUNBOOK.md'
$disabledConfigPath = Join-Path $Workspace 'config\watchdog.demo2.disabled.json'

$capture = Get-Content -LiteralPath $capturePath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw
$module = Get-Content -LiteralPath $modulePath -Raw
$test = Get-Content -LiteralPath $testPath -Raw
$runbook = Get-Content -LiteralPath $runbookPath -Raw
$disabledConfig = Get-Content -LiteralPath $disabledConfigPath -Raw | ConvertFrom-Json

Assert-True ($capture.Contains('JustMarkets-Demo2')) 'inventory capture must refuse non-Demo2 servers'
Assert-True ($capture.Contains('READ_ONLY_KILL_SWITCH_EVIDENCE')) 'inventory artifact must declare read-only scope'
Assert-True ($capture.Contains('PositionsTotal()') -and $capture.Contains('OrdersTotal()')) 'capture must independently count broker inventory'
Assert-True ($capture.Contains('account_fingerprint') -and $capture.Contains('account_suffix')) 'capture must redact account identity'
Assert-True (-not $capture.Contains('account_login')) 'capture must never persist a raw-login field'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'inventory capture must compile cleanly'
Assert-True (-not [bool]$disabledConfig.Enabled -and -not [bool]$disabledConfig.InstallScheduledTask) 'installed watchdog configuration must remain disabled'
Assert-True ($module.Contains('PREFLIGHT_INVENTORY_NONZERO')) 'verifier must reject non-flat preflight'
Assert-True ($module.Contains('FIXTURE_INVENTORY_MISMATCH')) 'verifier must require exactly one declared position and one declared order'
Assert-True ($module.Contains('FINAL_BROKER_INVENTORY_NONZERO')) 'verifier must require broker-confirmed flat final state'
Assert-True ($module.Contains('RAW_ACCOUNT_IDENTIFIER_PRESENT')) 'verifier must reject raw account identifiers'
Assert-True ($test.Contains('expiry shorter than four hours fails') -and
             $test.Contains('self-resolved fixture fails') -and
             $test.Contains('restart after standdown fails')) 'negative drill fixtures must exercise core fail-closed checks'
Assert-True ([regex]::IsMatch($runbook, '(?is)standdown.+latch') -and
             [regex]::IsMatch($runbook, '(?i)leave\s+(the\s+)?deployment\s+quarantined')) 'runbook must preserve standdown and quarantine'

$forbidden = '\b(OrderSend|OrderSendAsync|CTrade|PositionOpen|PositionClose|PositionModify|OrderDelete|OrderModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|iATR|iADX|iCustom|WebRequest)\b'
foreach ($entry in @(
    @{ Name = 'inventory capture'; Text = $capture },
    @{ Name = 'evidence verifier'; Text = $module }
)) {
    Assert-True (-not [regex]::IsMatch($entry.Text, $forbidden)) "$($entry.Name) must contain no automated order, history, indicator, performance, or network capability"
    Assert-True (-not $entry.Text.Contains('MqlTick.flags')) "$($entry.Name) must not inspect tick flags"
    Assert-True (-not [regex]::IsMatch($entry.Text, '#import\s+')) "$($entry.Name) must not import DLLs"
}

Write-Output 'KILL_SWITCH_DRILL_POLICY_PASS: guarded read-only inventory, exact bounded evidence, no raw login, disabled watchdog, and no automated-order/performance capability.'
