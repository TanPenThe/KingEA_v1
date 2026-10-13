param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "RSB3_MANIFEST_GATE_POLICY_FAIL: $Message" }
}

$sourcePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\ValidateRSB3ManifestGate.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\rsb3_manifest_gate_compile.log'
$source = Get-Content -LiteralPath $sourcePath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw

Assert-True ($source.Contains('Build ID: RSB3-MANIFEST-GATE-20260726-A')) 'build identity must be explicit'
Assert-True ($source.Contains('const long EXPECTED_TOTAL = 327417608;')) 'full population count must be fixed'
Assert-True ($source.Contains('REGISTERED_1_MSC = 1709374488223')) 'first crossed timestamp must be exact'
Assert-True ($source.Contains('REGISTERED_2_MSC = 1709375322820')) 'second crossed timestamp must be exact'
Assert-True ($source.Contains('unexpected_crossed==0')) 'unexpected crossed quotes must hard-fail'
Assert-True ($source.Contains('stored[i].flags!=ExpectedPersistedFlags(origin[i].flags)')) 'flag rule must apply to every tick'
Assert-True ($source.Contains('return (origin_flags & 0xFFFFFF7F)')) 'only flag bit 128 may be cleared'
Assert-True ($source.Contains('nonflag_mismatches==0')) 'non-flag mismatches must hard-fail'
Assert-True ($source.Contains('MIN_WARMUP_COVERAGE = 0.95')) 'warm-up coverage floor must be fixed'
Assert-True ($source.Contains('WARMUP_START_MSC = 1617235200000')) 'warm-up start must be 2021-04-01'
Assert-True ($source.Contains('WARMUP_END_MSC = 1625097600000')) 'warm-up end must be 2021-07-01 exclusive'
Assert-True (-not [regex]::IsMatch($source, '\b(CustomTicksAdd|CustomTicksReplace|CustomRatesReplace|CustomRatesUpdate)\b')) 'validator must not mutate custom history'
Assert-True (-not [regex]::IsMatch($source, '\b(OrderSend|OrderSendAsync|PositionOpen|trade\.Buy|trade\.Sell|CTrade)\b')) 'validator must not submit orders'
Assert-True (-not [regex]::IsMatch($source, '\b(iATR|iMA|iADX|iCustom|Supertrend)\b')) 'validator must not contain strategy logic'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'validator must compile cleanly'

Write-Output 'RSB3_MANIFEST_GATE_POLICY_PASS: full-population read-only scan; exact crossed whitelist; all-tick flag rule; pre-dataset warm-up; no trading or mutation APIs.'
