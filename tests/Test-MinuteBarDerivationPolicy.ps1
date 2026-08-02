param(
    [string]$Workspace = 'C:\KingEA_v1',
    [string]$CommonKingEA = 'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files\KingEA'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "M1_DERIVATION_POLICY_FAIL: $Message" }
}

$sourcePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\DiagnoseMinuteBarDerivation.mq5'
$compileLogPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\minute_bar_derivation_compile.log'
$evidencePath = Join-Path $CommonKingEA 'minute_bar_derivation_2026.07.24_01-11-42.csv'
$source = Get-Content -LiteralPath $sourcePath -Raw
$compile = Get-Content -LiteralPath $compileLogPath -Raw
$evidence = Import-Csv -LiteralPath $evidencePath

function EvidenceValue([string]$Section,[string]$Key) {
    return ($evidence | Where-Object { $_.section -eq $Section -and $_.key -eq $Key } | Select-Object -First 1).value
}

Assert-True ((EvidenceValue 'source' 'ticks') -eq '173712') 'fixture tick count must remain exact'
Assert-True ((EvidenceValue 'derived' 'm1_bars') -eq '1440') 'fixture must derive 1,440 M1 bars'
Assert-True ((EvidenceValue 'comparison' 'time_mismatches') -eq '0') 'time aggregation must already match'
Assert-True ((EvidenceValue 'comparison' 'ohlc_mismatches') -eq '0') 'OHLC aggregation must already match'
Assert-True ((EvidenceValue 'comparison' 'tick_volume_mismatches') -eq '0') 'tick-volume aggregation must already match'
Assert-True ((EvidenceValue 'comparison' 'real_volume_mismatches') -eq '0') 'real-volume aggregation must already match'
Assert-True ((EvidenceValue 'comparison' 'spread_mismatches') -eq '7') 'fixture must preserve the seven last-spread mismatches'
Assert-True ($source.Contains('#property version   "1.05"')) 'positive-spread diagnostic must be version 1.05'
$startBar = [regex]::Match($source, 'void StartBar[\s\S]*?\n  \}').Value
$updateBar = [regex]::Match($source, 'void UpdateBar[\s\S]*?\n  \}').Value
Assert-True ($startBar.Contains('bar.spread=(spread_points>0 ? spread_points : 0);')) 'StartBar must initialize only a positive spread'
Assert-True ($updateBar.Contains('if(spread_points>0 && (bar.spread<=0 || spread_points<bar.spread))')) 'UpdateBar must retain the minimum positive spread'
Assert-True ($source.Contains('"spread_detail"')) 'spread mismatches must expose mechanical candidate values'
Assert-True ($source.Contains('exact_point_min')) 'integer-price-unit minimum must be instrumented separately'
Assert-True ($source.Contains('minimum_positive')) 'crossed-day minimum-positive candidate must be instrumented'
Assert-True ($source.Contains('negative_spread_ticks')) 'crossed-day negative tick count must be instrumented'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'corrected diagnostic must compile cleanly'

Write-Output 'M1_DERIVATION_POLICY_PASS: exact fixture; bar metadata retains minimum positive spread; instrumentation and compile clean.'
