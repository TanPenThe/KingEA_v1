param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "CANDIDATE_ETH_ST_001_CONTRACT_FAIL: $Message" }
}

$modulePath = Join-Path $Workspace 'MQL5\Include\KingEA\CandidateEthSt001.mqh'
$testPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestCandidateEthSt001.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\candidate_contract_test_compile.log'
$module = Get-Content -LiteralPath $modulePath -Raw
$testSource = Get-Content -LiteralPath $testPath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw

Assert-True ($module.Contains('struct KingEASignalIntent')) 'small signal-intent interface must exist'
Assert-True ($module.Contains('technical_stop')) 'technical stop must be emitted'
Assert-True ($module.Contains('exit_intent')) 'exit intent must be emitted'
Assert-True ($module.Contains('KingEAFreshLongBreakout')) 'fresh long continuation rule must exist'
Assert-True ($module.Contains('KingEAFreshShortBreakout')) 'fresh short continuation rule must exist'
Assert-True ($module.Contains('MathMin(facts.signal_bar_low,facts.m30_supertrend_line)')) 'long stop must use farther structure'
Assert-True ($module.Contains('MathMax(facts.signal_bar_high,facts.m30_supertrend_line)')) 'short stop must use farther structure'
Assert-True ($module.Contains('INSUFFICIENT_PROGRESS')) 'progress time stop must exist'
Assert-True ($module.Contains('MAXIMUM_HOLDING_PERIOD')) 'absolute time stop must exist'
Assert-True (-not [regex]::IsMatch($module, '\b(OrderSend|OrderSendAsync|OrderCalcMargin|OrderCalcProfit|PositionOpen|CTrade)\b')) 'signal module must not size or trade'
Assert-True (-not $module.Contains('MqlTick.flags')) 'signal module must not use tick flags'
Assert-True ($testSource.Contains('fresh long breakout')) 'long behavior test must exist'
Assert-True ($testSource.Contains('fresh short breakout')) 'short behavior test must exist'
Assert-True ($testSource.Contains('stale breakout expires')) 'non-lingering signal test must exist'
Assert-True ($testSource.Contains('extreme volatility blocks')) 'regime veto test must exist'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'contract test must compile cleanly'

Write-Output 'CANDIDATE_ETH_ST_001_CONTRACT_PASS: pure intent module; symmetric fresh breakouts; structural stops; time exits; no sizing or trading capability.'
