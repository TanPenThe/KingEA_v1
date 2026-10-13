param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "MARKET_CONTEXT_POLICY_FAIL: $Message" }
}

$regimePath = Join-Path $Workspace 'MQL5\Include\KingEA\RegimeClassifier.mqh'
$correlationPath = Join-Path $Workspace 'MQL5\Include\KingEA\CorrelationClustering.mqh'
$testPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestMarketContext.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\market_context_test_compile.log'
$configPath = Join-Path $Workspace 'config\market_context_contract_run.ini'
$contractPath = Join-Path $Workspace 'governance\MARKET_CONTEXT_CONTRACT.md'
$candidatePath = Join-Path $Workspace 'MQL5\Include\KingEA\CandidateEthSt001.mqh'
$draftPath = Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_DRAFT.json'
$freezePath = Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_FREEZE.json'
$watchdogPath = Join-Path $Workspace 'config\watchdog.demo2.disabled.json'
$drillPath = Join-Path $Workspace 'governance\drills\DRILL-DEMO-001.json'

$regime = Get-Content -LiteralPath $regimePath -Raw
$correlation = Get-Content -LiteralPath $correlationPath -Raw
$test = Get-Content -LiteralPath $testPath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw
$config = Get-Content -LiteralPath $configPath -Raw
$contract = Get-Content -LiteralPath $contractPath -Raw
$watchdog = Get-Content -LiteralPath $watchdogPath -Raw | ConvertFrom-Json
$drill = Get-Content -LiteralPath $drillPath -Raw | ConvertFrom-Json

Assert-True (([regex]::Matches($regime, 'void\s+KingEAEvaluateRegime\s*\(')).Count -eq 1) 'one regime interface must exist'
Assert-True (([regex]::Matches($correlation, 'void\s+KingEAEvaluateCorrelation\s*\(')).Count -eq 1) 'one correlation interface must exist'
Assert-True ($regime.Contains('KINGEA_REGIME_ATR_PERIOD 14') -and
             $regime.Contains('KINGEA_REGIME_ADX_PERIOD 14')) 'Wilder ATR and ADX periods must remain 14'
Assert-True ($regime.Contains('KINGEA_REGIME_LOOKBACK_SECONDS 7776000')) 'lookback must remain 90 calendar days'
Assert-True ($regime.Contains('historical<current-tolerance')) 'percentile rank must use strict-less tie handling'
Assert-True ($regime.Contains('percentile<80.0') -and
             $regime.Contains('percentile<=95.0')) 'volatility boundaries must remain asymmetric and exact'
Assert-True ($regime.Contains('adx>=25.0') -and
             $regime.Contains('adx<20.0')) 'trend thresholds must remain exact'
Assert-True ($regime.Contains('request.expected_open_slots*0.95')) 'coverage floor must remain 95 percent'
Assert-True ($correlation.Contains('aligned-60,60') -and
             $correlation.Contains('aligned-20,20')) 'correlation windows must remain 60 and 20 returns'
Assert-True ($correlation.Contains('0.60') -and $correlation.Contains('0.70') -and
             $correlation.Contains('0.45')) 'edge and release thresholds must remain present'
Assert-True ($correlation.Contains('pair.release_clean_days<10')) 'edge release must require ten clean evaluations'
Assert-True ($correlation.Contains('pair.edge_active=true') -and
             $correlation.Contains('decision.cluster_known=false')) 'invalid correlation must fail safe as correlated and unknown'
Assert-True ($test.Contains('strict-less percentile excludes an equal historical value')) 'tie behavior must be exercised'
Assert-True ($test.Contains('4103 of 4320') -and $test.Contains('4104 of 4320')) 'coverage boundary must be exercised'
Assert-True ($test.Contains('20-day shock window independently activates an edge') -and
             $test.Contains('60-day primary window independently activates an edge')) 'both correlation triggers must be independently exercised'
Assert-True ($test.Contains('stale synthetic symbol defaults to correlated') -and
             $test.Contains('zero-variance synthetic history defaults to correlated')) 'synthetic fail-safe paths must be exercised'
Assert-True ($test.Contains('Stage 10 enums map exactly to Candidate 001 integer contract')) 'candidate enum mapping must be asserted'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'contract harness must compile cleanly'
Assert-True ($config.Contains('AllowLiveTrading=0') -and
             $config.Contains('AllowDllImport=0') -and
             $config.Contains('ShutdownTerminal=1')) 'runtime must disable trading and DLLs and close MT5'
Assert-True (-not [bool]$watchdog.Enabled -and
             -not [bool]$watchdog.InstallScheduledTask) 'watchdog must remain disabled and uninstalled'
Assert-True ($drill.Status -eq 'PASS_QUARANTINED' -and
             [bool]$drill.Standdown.Active -and
             [bool]$drill.Final.StanddownActive) 'Stage 9 standdown and quarantine must remain active'
Assert-True ($contract.Contains('Only `ETHUSD.s` is operationally registered') -and
             $contract.Contains('No future symbol')) 'operational registration must remain ETH-only'

$expectedHashes = @{
    $draftPath = '3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC'
    $freezePath = '1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06'
    $candidatePath = '4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83'
}
foreach ($path in $expectedHashes.Keys) {
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    Assert-True ($actual -eq $expectedHashes[$path]) "frozen artifact changed: $path"
}

$forbidden = '\b(OrderSend|OrderSendAsync|OrderCalcMargin|OrderCalcProfit|CTrade|PositionOpen|PositionClose|PositionModify|OrderDelete|OrderModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|TesterDeposit|iATR|iADX|iCustom|WebRequest)\b'
foreach ($entry in @(
    @{ Name = 'regime module'; Text = $regime },
    @{ Name = 'correlation module'; Text = $correlation },
    @{ Name = 'contract harness'; Text = $test }
)) {
    Assert-True (-not [regex]::IsMatch($entry.Text, $forbidden)) "$($entry.Name) must contain no trading, history, indicator, performance, or network APIs"
    Assert-True (-not $entry.Text.Contains('MqlTick.flags')) "$($entry.Name) must not inspect tick flags"
    Assert-True (-not [regex]::IsMatch($entry.Text, '#import\s+')) "$($entry.Name) must not import DLLs"
}

$common = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\KingEA'
$report = Get-ChildItem -LiteralPath $common -Filter 'market_context_contract_*.csv' |
    Sort-Object LastWriteTime | Select-Object -Last 1
Assert-True ($null -ne $report) 'deterministic Stage 10 evidence must exist'
$reportText = Get-Content -LiteralPath $report.FullName -Raw
Assert-True ($reportText.Contains('result,PASS') -and
             $reportText.Contains('failures,0') -and
             $reportText.Contains('order_capability,PROHIBITED_AND_ABSENT') -and
             $reportText.Contains('performance_authorization,DENIED')) 'runtime evidence must be non-trading PASS'

Write-Output 'MARKET_CONTEXT_POLICY_PASS: pure deterministic regime/correlation modules, fail-closed boundaries, ETH-only registration, frozen-candidate immutability, and no trading/performance capability.'
