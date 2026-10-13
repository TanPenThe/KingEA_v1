param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "SAFETY_KERNEL_POLICY_FAIL: $Message" }
}

$modulePath = Join-Path $Workspace 'MQL5\Include\KingEA\SafetyKernel.mqh'
$testPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestSafetyKernel.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\safety_kernel_test_compile.log'
$configPath = Join-Path $Workspace 'config\safety_kernel_contract_run.ini'

$module = Get-Content -LiteralPath $modulePath -Raw
$testSource = Get-Content -LiteralPath $testPath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw
$config = Get-Content -LiteralPath $configPath -Raw

Assert-True (([regex]::Matches($module, 'void\s+KingEAEvaluateSafety\s*\(')).Count -eq 1) 'one public evaluation interface must exist'
Assert-True ($module.Contains('const double KINGEA_ACCOUNT_DAILY_BREAKER=0.03;')) 'daily breaker must be exactly three percent'
Assert-True ($module.Contains('const double KINGEA_MIN_MARGIN_LEVEL_PERCENT=500.0;')) 'margin level floor must be 500 percent'
Assert-True ($module.Contains('const double KINGEA_MIN_FREE_MARGIN_EQUITY_RATIO=0.80;')) 'free-margin floor must be 80 percent'
Assert-True ($module.Contains('const double KINGEA_HMR_REFERENCE_LEVERAGE=200.0;')) 'HMR proxy must be frozen at 1:200'
Assert-True ($module.Contains('const int    KINGEA_RECOVERY_CLEAN_DAYS=5;')) 'weekly recovery must require five clean days'
Assert-True ($module.Contains('const int    KINGEA_WEEKLY_BREAKER_LIMIT=3;')) 'cumulative review must trigger at three weekly breakers'
Assert-True ($module.Contains('const int    KINGEA_WEEKLY_BREAKER_WINDOW_DAYS=90;')) 'weekly breaker window must be 90 broker days'
Assert-True ([regex]::IsMatch($module, 'facts\.notional_per_lot\s*/\s*KINGEA_HMR_REFERENCE_LEVERAGE')) 'kernel must calculate the HMR proxy internally'
Assert-True ($module.Contains('MathMax(0.0,facts.cluster_existing_risk)')) 'protected profit must receive zero cluster-risk credit'
Assert-True ($module.Contains('MathMax(0.0,facts.portfolio_existing_risk)')) 'protected profit must receive zero portfolio-risk credit'
Assert-True ($testSource.Contains('throttle allowance is the sole binding constraint')) 'throttle-binding behavior must be tested'
Assert-True ($testSource.Contains('third weekly breaker in ninety days')) '3-in-90 behavior must be tested'
Assert-True ($testSource.Contains('starts a fresh epoch')) 'successful review epoch reset must be tested'
Assert-True ($testSource.Contains('second recovery throttle')) 'repeat-throttle escalation must be tested'
Assert-True ($config.Contains('AllowLiveTrading=0')) 'runtime contract config must disable live trading'
Assert-True ($config.Contains('ShutdownTerminal=1')) 'runtime contract config must close MT5 after the script'

$prohibited = '\b(OrderSend|OrderSendAsync|OrderCalcMargin|OrderCalcProfit|CTrade|PositionOpen|PositionClose|PositionModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|iATR|iADX|iCustom)\b'
Assert-True (-not [regex]::IsMatch($module, $prohibited)) 'kernel must contain no trading, history, indicator, or performance APIs'
Assert-True (-not $module.Contains('MqlTick.flags')) 'kernel must not reference tick flags'
Assert-True (-not [regex]::IsMatch($testSource, '\b(OrderSend|OrderSendAsync|CTrade|PositionOpen|PositionClose|PositionModify)\b')) 'contract harness must contain no order capability'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'kernel contract must compile cleanly'

Write-Output 'SAFETY_KERNEL_POLICY_PASS: one pure interface; frozen risk/margin/recovery thresholds; internal HMR proxy; no trading, history, performance, or tick-flag capability.'
