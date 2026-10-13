param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TESTER_RECON_POLICY_FAIL: $Message" }
}

$sourcePath = Join-Path $Workspace 'MQL5\Experts\KingEA\ReconcileTesterRealTicks.mq5'
$compileLogPath = Join-Path $Workspace 'MQL5\Experts\KingEA\tester_tick_reconciliation_compile.log'
$source = Get-Content -LiteralPath $sourcePath -Raw
$compile = Get-Content -LiteralPath $compileLogPath -Raw

Assert-True ($source.Contains('#property version   "1.00"')) 'version must remain explicit'
Assert-True ($source.Contains('Build ID: TESTER-RECON-20260724-A')) 'build identity must remain explicit'
Assert-True ($source.Contains('MQLInfoInteger(MQL_TESTER)')) 'harness must refuse execution outside Strategy Tester'
Assert-True ($source.Contains('CopyTicksRange')) 'harness must compare tester replay with source tick history'
Assert-True ($source.Contains('g_replay_count==copied')) 'exact tick-count equality must be enforced'
Assert-True ($source.Contains('g_replay_fieldhash==source_fieldhash')) 'canonical field fingerprint equality must be enforced'
Assert-True ($source.Contains('g_replay_mix==source_mix')) 'independent mix fingerprint equality must be enforced'
Assert-True ($source.Contains('g_replay_flaghash==source_flaghash')) 'tester transport must preserve the selected symbol flag stream'
Assert-True ($source.Contains('g_out_of_order==0')) 'out-of-order replay must fail'
Assert-True (-not [regex]::IsMatch($source, '\b(OrderSend|OrderSendAsync|PositionOpen|trade\.Buy|trade\.Sell|CTrade)\b')) 'no order-submission capability may exist'
Assert-True (-not [regex]::IsMatch($source, '\b(iATR|iMA|iADX|iCustom|Supertrend)\b')) 'no strategy or indicator logic may exist'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'harness must compile cleanly'

Write-Output 'TESTER_RECON_POLICY_PASS: tester-only; no trading/strategy APIs; exact count/order/field/flag replay invariants; compile clean.'
