param([string]$Workspace = 'C:\KingEA_v1')

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "ZERO_ENTRY_DIAGNOSTIC_POLICY_FAIL: $Message" }
}

$modulePath = Join-Path $Workspace 'MQL5\Include\KingEA\ZeroEntryDiagnostic.mqh'
$testPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestZeroEntryDiagnostic.mq5'
$eaPath = Join-Path $Workspace 'MQL5\Experts\KingEA\GuardedResearchTester.mq5'
$resultPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_finalization_20260901_v1\FINALIZATION_RESULT.json'
$rootPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_finalization_20260901_v1\DIAGNOSTIC_ROOT.json'
$contractPath = Join-Path $Workspace 'governance\stage14_gate1_zero_entry_diagnostic_contract.json'
$cliPath = Join-Path $Workspace 'research_pipeline\gate1_zero_entry_diagnostic_cli.py'

$module = Get-Content -LiteralPath $modulePath -Raw
$test = Get-Content -LiteralPath $testPath -Raw
$ea = Get-Content -LiteralPath $eaPath -Raw
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
$root = Get-Content -LiteralPath $rootPath -Raw | ConvertFrom-Json
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$cli = Get-Content -LiteralPath $cliPath -Raw

Assert-True ($result.status -eq 'QUARANTINED_PENDING_DIAGNOSTIC' -and
             $result.evaluated_configuration_count -eq 194400 -and
             $result.entry_count -eq 0 -and $result.trade_group_count -eq 0) 'diagnostic must remain bound to the actual all-zero Gate 1 outcome'
Assert-True ($root.root_sha256 -eq 'B17EA4E5AA3A6D823B522252D5997F63BC8C0A6CD620C0DDDBA26851E194185D' -and
             -not [bool]$root.owner_approved -and -not [bool]$root.orders_authorized -and
             -not [bool]$root.oos_authorized -and -not [bool]$root.holdout_authorized) 'root must remain planned, non-order, and development-only'
Assert-True ($contract.status -eq 'IMPLEMENTED_PENDING_OWNER_AUTHORIZATION' -and
             $contract.historical_execution -eq 'REQUIRES_SEPARATE_EXPLICIT_OWNER_APPROVAL' -and
             $contract.native_order_submission -eq 'PROHIBITED') 'contract must preserve approval and no-order boundaries'
Assert-True ($cli.Contains('only --prepare is implemented') -and -not $cli.Contains('subprocess')) 'preparation CLI must not implement execution or process launch'
Assert-True ($module.Contains('KingEAZeroEntryFirstZeroStage') -and
             $module.Contains('KingEAZeroEntryPayload') -and
             $module.Contains('native_order_calls')) 'funnel module must expose the public counter, classification, and no-order proof interfaces'
Assert-True ($test.Contains('complete synthetic funnel reaches accounting without an order') -and
             $test.Contains('unhealthy regime is identified before sleeve processing') -and
             $test.Contains('safety rejection is identified after a valid sleeve intent')) 'synthetic contract must cover the first three diagnostic failure boundaries'
Assert-True ($ea.Contains('InpZeroEntryDiagnostic') -and
             $ea.Contains('ResearchZeroEntryDiagnosticAuthorizationValid') -and
             $ea.Contains('KINGEA_ZERO_ENTRY_DIAGNOSTIC_ROOT') -and
             $ea.Contains('PersistZeroEntryDiagnosticPayload') -and
             $ea.Contains('ZERO_ENTRY_DIAGNOSTIC_%06d.frame')) 'tester diagnostic mode must be independently gated and persist dedicated append-only evidence'
Assert-True ($ea.Contains('if(InpWorkloadDryRun || InpZeroEntryDiagnostic)') -and
             $ea.Contains('g_zero_entry_funnel.native_order_calls++')) 'unexpected order paths must fail closed and be visible in evidence'

$forbidden = '\b(OrderSend|OrderSendAsync|PositionOpen|PositionClose|PositionModify|HistorySelect|CopyRates|CopyTicks|TesterStatistics|WebRequest)\b'
foreach ($entry in @(
    @{ Name = 'funnel module'; Text = $module },
    @{ Name = 'synthetic diagnostic contract'; Text = $test }
)) {
    Assert-True (-not [regex]::IsMatch($entry.Text,$forbidden)) "$($entry.Name) must contain no order, history, performance, or network capability"
    Assert-True (-not $entry.Text.Contains('MqlTick.flags')) "$($entry.Name) must not inspect tick flags"
    Assert-True (-not [regex]::IsMatch($entry.Text,'#import\s+')) "$($entry.Name) must not import DLLs"
}

Write-Output 'ZERO_ENTRY_DIAGNOSTIC_POLICY_PASS: immutable all-zero lineage, non-order funnel instrumentation, synthetic boundary tests, and isolated tester authorization are present.'
