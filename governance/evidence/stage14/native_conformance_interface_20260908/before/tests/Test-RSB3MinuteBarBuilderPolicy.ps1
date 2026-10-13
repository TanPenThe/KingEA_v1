param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "RSB3_M1_POLICY_FAIL: $Message" }
}

$sourcePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\BuildRSB3MinuteBars.mq5'
$compileLogPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\rsb3_m1_builder_compile.log'
$source = Get-Content -LiteralPath $sourcePath -Raw
$compile = Get-Content -LiteralPath $compileLogPath -Raw

Assert-True ($source.Contains('#property version   "1.03"')) 'builder version must be explicit'
Assert-True ($source.Contains('RSB3-M1-BARS-20260725-D')) 'build identity must be explicit'
Assert-True ($source.Contains('EXPECTED_TOTAL_TICKS = 327417608')) 'accepted tick total must be frozen'
Assert-True ($source.Contains('AUTHORIZE_RSB3_M1_BARS_20260724')) 'bar mutation must require the exact authorization token'
Assert-True ($source.Contains('if(!preflight_ok || !authorized)')) 'full preflight must gate all bar mutation'
Assert-True ($source.IndexOf('if(!preflight_ok || !authorized)') -lt $source.IndexOf('CustomRatesReplace')) 'authorization/preflight gate must precede the mutation call'
Assert-True ($source.Contains('CustomRatesReplace')) 'authorized build must write M1 rates'
Assert-True (-not [regex]::IsMatch($source, '\bCustomTicks(Add|Replace|Delete)\b')) 'builder must not mutate accepted ticks'
Assert-True ($source.Contains('after_fnv==before_fnv && after_mix==before_mix')) 'every written day must prove tick fingerprint preservation'
Assert-True ($source.Contains('CountRateMismatches(expected_m1')) 'every written M1 day must be read back exactly'
Assert-True ($source.Contains('CountRateMismatches(expected_m30')) 'every written day must retain exact M30 aggregation'
Assert-True ($source.Contains('if(spread_points>0 && (bar.spread<=0 || spread_points<bar.spread))')) 'bar metadata must ignore crossed/non-positive spreads and retain the minimum positive spread'
Assert-True ($source.Contains('CopyRatesExpected')) 'series reads must use a bounded expected-count synchronization helper'
Assert-True ($source.Contains('Sleep(100)')) 'series synchronization retry must yield between attempts'
Assert-True ($source.Contains('attempt<300')) '30-second series synchronization retry must be bounded'
Assert-True ($source.Contains('TERMINAL_MAXBARS')) 'full M1 history must be protected by a terminal-bar capacity invariant'
Assert-True (-not [regex]::IsMatch($source, '\b(OrderSend|OrderSendAsync|PositionOpen|CTrade|iATR|iMA|iADX|iCustom)\b')) 'no trading, strategy, or indicator capability may exist'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'builder must compile cleanly'

Write-Output 'RSB3_M1_POLICY_PASS: full preflight before authorization; M1-only mutation; per-day M1/M30 and tick-fingerprint invariants; compile clean.'
