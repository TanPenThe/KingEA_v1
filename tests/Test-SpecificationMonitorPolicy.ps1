param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "SPECIFICATION_MONITOR_POLICY_FAIL: $Message" }
}

$modulePath = Join-Path $Workspace 'MQL5\Include\KingEA\SpecificationMonitor.mqh'
$adapterPath = Join-Path $Workspace 'MQL5\Include\KingEA\SymbolSpecificationAdapter.mqh'
$testPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestSpecificationMonitor.mq5'
$observerPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\ObserveSpecificationMonitor.mq5'
$testCompilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\specification_monitor_test_compile.log'
$observerCompilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\specification_observer_compile.log'
$contractPath = Join-Path $Workspace 'governance\SPECIFICATION_MONITOR_CONTRACT.md'
$draftPath = Join-Path $Workspace 'governance\specifications\ETHUSD.s_DEMO2_DRAFT.json'
$bindingPath = Join-Path $Workspace 'governance\deployments\KINGEA_DEMO2_STAGE8_DRAFT.json'
$runConfigPath = Join-Path $Workspace 'config\specification_monitor_contract_run.ini'
$observationConfigPath = Join-Path $Workspace 'config\specification_observer_demo2_run.ini'

$module = Get-Content -LiteralPath $modulePath -Raw
$adapter = Get-Content -LiteralPath $adapterPath -Raw
$testSource = Get-Content -LiteralPath $testPath -Raw
$observer = Get-Content -LiteralPath $observerPath -Raw
$testCompile = Get-Content -LiteralPath $testCompilePath -Raw
$observerCompile = Get-Content -LiteralPath $observerCompilePath -Raw
$contract = Get-Content -LiteralPath $contractPath -Raw
$draft = Get-Content -LiteralPath $draftPath -Raw | ConvertFrom-Json
$binding = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
$runConfig = Get-Content -LiteralPath $runConfigPath -Raw
$observationConfig = Get-Content -LiteralPath $observationConfigPath -Raw

Assert-True (([regex]::Matches($module, 'void\s+KingEAEvaluateSpecification\s*\(')).Count -eq 1) 'one public evaluation interface must exist'
Assert-True ($module.Contains('KINGEA_MAX_SPEC_SESSIONS 64')) 'session scan must be bounded'
Assert-True ($module.Contains('request.observed_at>=prior.scheduled_confirmation_not_before')) 'scheduled confirmation must enforce not-before time'
Assert-True ($module.Contains('request.event==KINGEA_SPEC_EVENT_PERIODIC')) 'immediate third read must not clear transient state'
Assert-True ($module.Contains('CAPTURES_DISAGREE')) 'capture disagreement must have a stable reason'
Assert-True ($module.Contains('decision.reset_to_bottom_tier=true')) 'risk-critical confirmation must reset tier'
Assert-True ($module.Contains('decision.preserve_earned_tier=true')) 'proved administrative changes must preserve tier'
Assert-True ($testSource.Contains('immediate third read cannot clear transient')) 'scheduled third-capture behavior must be asserted'
Assert-True ($testSource.Contains('disagreeing changed captures quarantine as unstable')) 'unstable-capture behavior must be asserted'
Assert-True ($testSource.Contains('proved administrative change preserves earned tier')) 'administrative tier preservation must be asserted'
Assert-True ($adapter.Contains('OrderCalcProfit')) 'adapter must perform calculator-only tick-value validation'
Assert-True ($adapter.Contains('OrderCalcMargin')) 'adapter must perform calculator-only margin validation'
Assert-True ($observer.Contains('JustMarkets-Demo2')) 'observer must be guarded to Demo2'
Assert-True ($observer.Contains('PENDING_OWNER_REVIEW')) 'observation must not approve its own baseline'
Assert-True ($testCompile.Contains('Result: 0 errors, 0 warnings')) 'contract harness must compile cleanly'
Assert-True ($observerCompile.Contains('Result: 0 errors, 0 warnings')) 'observer must compile cleanly'
Assert-True ($runConfig.Contains('AllowLiveTrading=0') -and $runConfig.Contains('AllowDllImport=0')) 'contract runtime must disable live trading and DLLs'
Assert-True ($observationConfig.Contains('AllowLiveTrading=0') -and $observationConfig.Contains('AllowDllImport=0')) 'observer runtime must disable live trading and DLLs'
Assert-True ($draft.status -eq 'DRAFT_NON_DEPLOYABLE' -and -not $draft.permissions.baseline_activation) 'Demo2 observation must remain a non-deployable draft'
Assert-True ($binding.approved_specification_sha256 -eq $null -and $binding.status -eq 'DRAFT_NOT_ACTIVE') 'deployment binding must remain inactive without owner approval'
Assert-True ([regex]::IsMatch($contract, 'immediate\s+third\s+read\s+cannot\s+substitute')) 'contract must preserve the independent scheduled-poll rule'

$forbiddenEverywhere = '\b(OrderSend|OrderSendAsync|CTrade|PositionOpen|PositionClose|PositionModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|iATR|iADX|iCustom|WebRequest)\b'
foreach ($entry in @(
    @{ Name = 'module'; Text = $module },
    @{ Name = 'test'; Text = $testSource },
    @{ Name = 'observer'; Text = $observer }
)) {
    Assert-True (-not [regex]::IsMatch($entry.Text, $forbiddenEverywhere)) "$($entry.Name) must contain no trading, history, indicator, performance, or network APIs"
    Assert-True (-not $entry.Text.Contains('MqlTick.flags')) "$($entry.Name) must not inspect tick flags"
    Assert-True (-not [regex]::IsMatch($entry.Text, '#import\s+')) "$($entry.Name) must not import DLLs"
}

$forbiddenAdapter = '\b(OrderSend|OrderSendAsync|CTrade|PositionOpen|PositionClose|PositionModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|iATR|iADX|iCustom|WebRequest)\b'
Assert-True (-not [regex]::IsMatch($adapter, $forbiddenAdapter)) 'adapter may use calculators but no trading, history, indicator, performance, or network APIs'
Assert-True (-not $adapter.Contains('MqlTick.flags')) 'adapter must not inspect tick flags'
Assert-True (-not [regex]::IsMatch($adapter, '#import\s+')) 'adapter must not import DLLs'

$common = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\KingEA'
$observation = Get-ChildItem -LiteralPath $common -Filter 'stage8_spec_observation_ETHUSD.s_*.csv' |
    Sort-Object LastWriteTime | Select-Object -Last 1
Assert-True ($null -ne $observation) 'fresh Demo2 observation evidence must exist'
$observationText = Get-Content -LiteralPath $observation.FullName -Raw
Assert-True ($observationText.Contains('server,JustMarkets-Demo2')) 'runtime observation must prove Demo2 server'
Assert-True ($observationText.Contains('tick_probe_reported,0.010000000000') -and
             $observationText.Contains('tick_probe_calculated,0.010000000000')) 'runtime tick-value probe must reconcile'
Assert-True ($observationText.Contains('baseline_approval,PENDING_OWNER_REVIEW')) 'runtime observation must remain unapproved'
Assert-True (Test-Path -LiteralPath $draft.observation_evidence.path) 'draft manifest bound observation must still exist'
Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $draft.observation_evidence.path).Hash -eq
             $draft.observation_evidence.sha256) 'draft manifest must bind the exact observation hash'

Write-Output 'SPECIFICATION_MONITOR_POLICY_PASS: pure fail-closed monitor, calculator-only Demo2 adapter, proof-based tier handling, independent scheduled confirmation, and no trading/performance capability.'
