param([string]$Workspace = 'C:\KingEA_v1')

$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "STAGE13_ACCOUNTING_POLICY_FAIL: $Message" }
}

$purePath = Join-Path $Workspace 'MQL5\Include\KingEA\AccountingEvents.mqh'
$exporterPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\ExportAccountingHistory.mq5'
$harnessPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestAccountingLedger.mq5'
$eaPath = Join-Path $Workspace 'MQL5\Experts\KingEA\GuardedResearchTester.mq5'
$pythonPath = Join-Path $Workspace 'accounting_pipeline\stage13.py'
$pythonTestPath = Join-Path $Workspace 'tests\test_stage13_accounting.py'
$contractPath = Join-Path $Workspace 'governance\STAGE13_ACCOUNTING_CONTRACT.md'
$contractJsonPath = Join-Path $Workspace 'governance\stage13_accounting_contract.json'
$configPath = Join-Path $Workspace 'config\accounting_contract_run.ini'
$compilePaths = @(
    (Join-Path $Workspace 'MQL5\Scripts\KingEA\accounting_contract_compile.log'),
    (Join-Path $Workspace 'MQL5\Scripts\KingEA\accounting_history_export_compile.log'),
    (Join-Path $Workspace 'MQL5\Experts\KingEA\guarded_research_tester_compile.log')
)

$pure = Get-Content -LiteralPath $purePath -Raw
$exporter = Get-Content -LiteralPath $exporterPath -Raw
$harness = Get-Content -LiteralPath $harnessPath -Raw
$ea = Get-Content -LiteralPath $eaPath -Raw
$python = Get-Content -LiteralPath $pythonPath -Raw
$pythonTest = Get-Content -LiteralPath $pythonTestPath -Raw
$contract = Get-Content -LiteralPath $contractPath -Raw
$contractJson = Get-Content -LiteralPath $contractJsonPath -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath $configPath -Raw

Assert-True ($pure.Contains('KingEAProcessAccountingEvent') -and
             $pure.Contains('KingEAAccountingFramePayload') -and
             $pure.Contains('CRYPT_HASH_SHA256')) 'pure accounting seam and SHA-256 chain must exist'
Assert-True (-not [regex]::IsMatch($pure + $harness, '\b(OrderSend|OrderSendAsync|PositionOpen|PositionClose|PositionModify|HistorySelect|HistoryDealGet|HistoryOrderGet|CopyRates|CopyTicks|TesterStatistics|WebRequest)\b')) 'pure contract and harness must contain no broker/trading/performance/network capability'
Assert-True ($exporter.Contains('HistorySelect') -and $exporter.Contains('HistoryDealGet') -and
             $exporter.Contains('HistoryOrderGet') -and $exporter.Contains('PositionsTotal()') -and
             $exporter.Contains('OrdersTotal()')) 'read-only MT5 adapter must capture broker truth'
Assert-True (-not [regex]::IsMatch($exporter, '\b(OrderSend|OrderSendAsync|PositionOpen|PositionClose|PositionModify|OrderDelete|CTrade)\b')) 'history adapter must not have order capability'
Assert-True (-not [regex]::IsMatch($pure + $exporter + $harness, '#import\s+|\bWebRequest\b|MqlTick\.flags')) 'Stage 13 MQL5 must have no DLL/network/tick-flag bypass'
Assert-True ($ea.Contains('KINGEA_STAGE13_ACCOUNTING_EVENT') -and
             $ea.Contains('KINGEA_STAGE13_ACCOUNTING_COMPLETE') -and
             $ea.Contains('g_accounting_close_count!=ArraySize(g_trade_returns)') -and
             $ea.Contains('MathAbs(legacy_net-g_accounting_checkpoint.strategy_net_pnl)')) 'tester accounting frames must cross-check the legacy summary'
Assert-True (([regex]::Matches($ea, '\bOrderSend\s*\(')).Count -eq 1) 'Stage 13 must not add an order seam'

foreach ($path in $compilePaths) {
    $compile = Get-Content -LiteralPath $path -Raw
    Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) "compile must be warning-free: $path"
}
Assert-True ($config.Contains('AllowLiveTrading=0') -and
             $config.Contains('AllowDllImport=0') -and
             $config.Contains('ShutdownTerminal=1')) 'contract run must be non-trading and self-closing'

foreach ($name in @('process_batch','reconcile_statement','evaluate_controls','review_recovery','build_health_review','parse_mt5_html_statement','render_export_bundle','validate_tester_frames')) {
    Assert-True ($python.Contains("def $name")) "deep accounting behavior missing: $name"
}
Assert-True ($pythonTest.Contains('without_offsetting_errors') -and
             $pythonTest.Contains('latch_cumulative_review') -and
             $pythonTest.Contains('uses_reduced_resume_rules') -and
             $pythonTest.Contains('never_invents_oos_ranges') -and
             $pythonTest.Contains('agree_with_legacy_completion')) 'critical behaviors must be contract-tested'
Assert-True ($contract.IndexOf('three failed month closes',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
             $contract.IndexOf('two quarantine activations',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
             $contract.IndexOf('half the earned tier',[System.StringComparison]::OrdinalIgnoreCase) -ge 0 -and
             $contract.Contains('0.25%')) 'escalation and recovery rules must be governed'
Assert-True ($contractJson.status -eq 'IMPLEMENTED_NON_PERFORMANCE' -and
             $contractJson.candidate_budget_consumed -eq 0 -and
             -not [bool]$contractJson.authorization.development_execution) 'Stage 13 must deny result-bearing execution'

$expectedHashes = @{
    (Join-Path $Workspace 'MQL5\Include\KingEA\CandidateEthSt001.mqh') = '4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83'
    (Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_DRAFT.json') = '3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC'
    (Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_FREEZE.json') = '1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06'
}
foreach ($path in $expectedHashes.Keys) {
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -eq $expectedHashes[$path]) "frozen artifact changed: $path"
}

$drill = Get-Content -LiteralPath (Join-Path $Workspace 'governance\drills\DRILL-DEMO-001.json') -Raw | ConvertFrom-Json
$watchdog = Get-Content -LiteralPath (Join-Path $Workspace 'config\watchdog.demo2.disabled.json') -Raw | ConvertFrom-Json
Assert-True ($drill.Status -eq 'PASS_QUARANTINED' -and [bool]$drill.Standdown.Active -and [bool]$drill.Final.StanddownActive) 'Stage 9 standdown must remain active'
Assert-True (-not [bool]$watchdog.Enabled -and -not [bool]$watchdog.InstallScheduledTask) 'watchdog must remain disabled and uninstalled'

$common = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\KingEA'
$report = Get-ChildItem -LiteralPath $common -Filter 'stage13_accounting_contract_*.csv' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
Assert-True ($null -ne $report) 'synthetic Stage 13 runtime evidence must exist'
$reportText = Get-Content -LiteralPath $report.FullName -Raw
Assert-True ($reportText.Contains('result,PASS') -and $reportText.Contains('checks,8') -and
             $reportText.Contains('failures,0') -and $reportText.Contains('fixture,SYNTHETIC_ONLY') -and
             $reportText.Contains('candidate_budget_consumed,0') -and
             $reportText.Contains('performance_authorization,DENIED')) 'runtime evidence must be non-performance PASS'

Write-Output 'STAGE13_ACCOUNTING_POLICY_PASS: immutable ledger, read-only reconciliation, cumulative escalation, governed recovery, health reporting, frozen hashes, and zero performance authorization.'
