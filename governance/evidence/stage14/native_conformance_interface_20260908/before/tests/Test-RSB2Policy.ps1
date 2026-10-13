param(
    [string]$Workspace = 'C:\KingEA_v1',
    [string]$CommonKingEA = 'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files\KingEA'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "RSB2_POLICY_FAIL: $Message" }
}

$builderPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\BuildNativeReducedSpreadSymbol.mq5'
$compileLog = Join-Path $Workspace 'MQL5\Scripts\KingEA\native_reduced_build_compile.log'
$diagnosticPath = Join-Path $CommonKingEA 'native_build_failure_diagnostic_ETHUSD.s_2026.07.22_01-28-10.csv'
$liveEvidencePath = Join-Path $CommonKingEA 'spread_bracket_evidence_ETHUSD.s_LIVE2_REFERENCE_2026.07.22_01-07-55.csv'
$fieldComparisonPath = Join-Path $CommonKingEA 'crossed_tick_field_comparison_2026.07.22_09-59-00.csv'
$flagDiagnosticPath = Join-Path $CommonKingEA 'persisted_flag_normalization_2026.07.23_14-21-50.csv'
$verifierPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\VerifyNativeReducedSpreadSymbol.mq5'

$source = Get-Content -LiteralPath $builderPath -Raw
$compile = Get-Content -LiteralPath $compileLog -Raw
$violations = Import-Csv -LiteralPath $diagnosticPath | Where-Object { $_.section -eq 'violation' }
$liveRows = Import-Csv -LiteralPath $liveEvidencePath
$liveMin = [double](($liveRows | Where-Object { $_.section -eq 'reference' -and $_.key -eq 'live_reference_min' }).value)
$fieldRows = Import-Csv -LiteralPath $fieldComparisonPath
$flagRows = Import-Csv -LiteralPath $flagDiagnosticPath
$verifierSource = Get-Content -LiteralPath $verifierPath -Raw

Assert-True ($violations.Count -eq 541) 'captured regression fixture must contain 541 violations'
Assert-True ((@($violations | Where-Object { $_.reason -ne 'ZERO_SPREAD' })).Count -eq 0) 'every captured violation must be zero spread'
Assert-True ((@($violations | Where-Object { [double]$_.spread -ne 0.0 })).Count -eq 0) 'captured spreads must equal zero'
Assert-True ($liveMin -eq 0.98) 'frozen Live2 minimum must remain USD 0.98'
Assert-True ($source.Contains('#property version   "1.03"')) 'builder version must be 1.03'
Assert-True ($source.Contains('InpCustomSymbol = "KINGEA_ETHUSD_S_RSB3"')) 'builder must target RSB3'
Assert-True ($source.Contains('IsRegisteredCrossedTick')) 'exact crossed-tick whitelist must exist'
Assert-True ($source.Contains('ticks[i].ask<ticks[i].bid && !IsRegisteredCrossedTick(ticks[i])')) 'unregistered reversed spreads must hard-fail'
Assert-True (-not $source.Contains('ticks[i].ask<=ticks[i].bid')) 'zero spreads must not be rejected before mapping'
Assert-True ($source.Contains('demo_index=MathMax(0,MathMin(demo_index,demo_count-1))')) 'below-range rank must clamp to index zero'
Assert-True ($source.Contains('if(ticks[i].time_msc<BOUNDARY_MSC)')) 'mapping must be limited to pre-boundary ticks'
Assert-True ($source.IndexOf('if(!PreflightSource') -lt $source.IndexOf('if(!PrepareTarget())')) 'preflight must run before target creation'
Assert-True ($source.Contains('CustomTicksReplace')) 'bulk historical construction must use CustomTicksReplace'
Assert-True (-not $source.Contains('CustomTicksAdd')) 'CustomTicksAdd must remain prohibited for bulk history'
Assert-True ($source.Contains('READBACK_COUNT_FAILED')) 'every replaced day must have count readback verification'
Assert-True ($source.Contains('READBACK_FIELDS_FAILED')) 'every replaced day must have non-flag field readback verification'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'current builder must compile cleanly'
Assert-True ((@($fieldRows | Where-Object { $_.field -notin @('flags','summary_differences','result') -and $_.result -eq 'DIFF' })).Count -eq 0) 'crossed-tick non-flag fields must round-trip exactly'
Assert-True ((@($fieldRows | Where-Object { $_.field -eq 'flags' -and $_.result -eq 'DIFF' })).Count -eq 2) 'exactly two flag normalizations must be evidenced'
Assert-True ((@($flagRows | Where-Object { $_.section -eq 'day_summary' -and $_.notes -ne 'PASS' })).Count -eq 0) 'sampled persisted days must retain exact counts and non-flag fields'
Assert-True ((@($flagRows | Where-Object { $_.section -eq 'flag_map' -and (([int]$_.origin_flag -band 0xFFFFFF7F) -ne [int]$_.stored_flag) })).Count -eq 0) 'every sampled persisted flag must equal the origin flag with bit 128 cleared'
Assert-True ($verifierSource.Contains('#property version   "1.02"')) 'verifier version must be 1.02'
Assert-True ($verifierSource.Contains('ExpectedPersistedFlags')) 'verifier must encode deterministic persisted-flag normalization'
Assert-True ($verifierSource.Contains('origin_flags & 0xFFFFFF7F')) 'verifier must clear only flag bit 128'
Assert-True (-not $verifierSource.Contains('AllowedFlagNormalization')) 'obsolete two-tick-only flag exception must be removed'

Write-Output 'RSB3_POLICY_PASS: zero-spread mapping floor=0.98; exact crossed whitelist; CustomTicksReplace only; per-day count/field readback; unknown reversals blocked; deterministic persisted flags clear bit 128 only.'
