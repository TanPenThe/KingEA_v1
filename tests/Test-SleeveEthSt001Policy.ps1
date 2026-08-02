param(
    [string]$Workspace = 'C:\KingEA_v1'
)

$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "SLEEVE_ETH_ST_001_POLICY_FAIL: $Message" }
}

$modulePath = Join-Path $Workspace 'MQL5\Include\KingEA\SleeveEthSt001.mqh'
$harnessPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestSleeveEthSt001.mq5'
$compilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\sleeve_eth_st_001_test_compile.log'
$configPath = Join-Path $Workspace 'config\sleeve_eth_st_001_contract_run.ini'
$contractPath = Join-Path $Workspace 'governance\SLEEVE_ETH_ST_001_CONTRACT.md'
$candidatePath = Join-Path $Workspace 'MQL5\Include\KingEA\CandidateEthSt001.mqh'
$draftPath = Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_DRAFT.json'
$freezePath = Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_FREEZE.json'
$watchdogPath = Join-Path $Workspace 'config\watchdog.demo2.disabled.json'
$drillPath = Join-Path $Workspace 'governance\drills\DRILL-DEMO-001.json'

$module = Get-Content -LiteralPath $modulePath -Raw
$harness = Get-Content -LiteralPath $harnessPath -Raw
$compile = Get-Content -LiteralPath $compilePath -Raw
$config = Get-Content -LiteralPath $configPath -Raw
$contract = Get-Content -LiteralPath $contractPath -Raw
$watchdog = Get-Content -LiteralPath $watchdogPath -Raw | ConvertFrom-Json
$drill = Get-Content -LiteralPath $drillPath -Raw | ConvertFrom-Json

Assert-True (([regex]::Matches($module, 'void\s+KingEAEvaluateSleeveEthSt001\s*\(')).Count -eq 1) 'one deep sleeve interface must exist'
Assert-True ($module.Contains('KingEAEvaluateCandidateEthSt001(facts,position')) 'final intent must delegate to the frozen candidate'
Assert-True ($module.Contains('KingEAEvaluateRegime') -eq $false) 'the sleeve must consume Stage 10 output rather than recalculate the regime'
Assert-True ($module.Contains('KINGEA_SLEEVE_H4_SECONDS 14400') -and
             $module.Contains('start+7') -and
             $module.Contains('j<8')) 'H4 must derive from eight server-aligned M30 bars'
Assert-True ($module.Contains('bars[i].close<final_lower[i]') -and
             $module.Contains('bars[i].close>final_upper[i]')) 'Supertrend flips must remain strict'
Assert-True (-not $module.Contains('bars[i].close<=final_lower[i]') -and
             -not $module.Contains('bars[i].close>=final_upper[i]')) 'Supertrend equality must never flip'
Assert-True ($module.Contains('current-1') -and
             $module.Contains('current-2')) 'current and previous breakout windows must exclude their signal bars'
Assert-True ($module.Contains('original_confirmed_stop') -and
             $module.Contains('bars[i].open_time<=context.entry_signal_bar_time')) 'MFE must use original R and exclude the entry signal bar'
Assert-True ($module.Contains('A well-formed newly closed bar is consumed before downstream gates')) 'valid blocked bars must be consumed before gates'
Assert-True ($harness.Contains('accepted==19440')) 'all frozen grid configurations must be exercised'
Assert-True ($harness.Contains('non-finite parameters fail closed')) 'non-finite parameters must be rejected'
Assert-True ($harness.Contains('a consumed breakout is not queued onto the next bar')) 'signal expiry must be exercised'
Assert-True ($harness.Contains('server H4 boundaries 00 04 08 12 16 and 20')) 'every H4 boundary must be exercised'
Assert-True ($harness.Contains('progress exactly equal to required R does not exit')) 'exact progress boundary must be exercised'
Assert-True ($harness.Contains('entry signal-bar high is excluded from closed-bar MFE')) 'closed-bar MFE exclusion must be exercised'
Assert-True ($compile.Contains('Result: 0 errors, 0 warnings')) 'contract harness must compile cleanly'
Assert-True ($config.Contains('AllowLiveTrading=0') -and
             $config.Contains('AllowDllImport=0') -and
             $config.Contains('ShutdownTerminal=1')) 'runtime must disable trading/DLL and close MT5'
Assert-True ($contract.Contains('Performance authorization: denied') -and
             $contract.Contains('Order capability: prohibited and absent')) 'governance must retain non-performance isolation'
Assert-True (-not [bool]$watchdog.Enabled -and
             -not [bool]$watchdog.InstallScheduledTask) 'watchdog must remain disabled and uninstalled'
Assert-True ($drill.Status -eq 'PASS_QUARANTINED' -and
             [bool]$drill.Standdown.Active -and
             [bool]$drill.Final.StanddownActive) 'Stage 9 standdown and quarantine must remain active'

$expectedHashes = @{
    $candidatePath = '4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83'
    $draftPath = '3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC'
    $freezePath = '1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06'
}
foreach ($path in $expectedHashes.Keys) {
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    Assert-True ($actual -eq $expectedHashes[$path]) "frozen artifact changed: $path"
}

$sleeveModules = @(Get-ChildItem (Join-Path $Workspace 'MQL5\Include\KingEA') -Filter 'Sleeve*.mqh')
Assert-True ($sleeveModules.Count -eq 1 -and
             $sleeveModules[0].Name -eq 'SleeveEthSt001.mqh') 'no other strategy family may be implemented or registered'

$forbidden = '\b(OrderSend|OrderSendAsync|OrderCalcMargin|OrderCalcProfit|CTrade|PositionOpen|PositionClose|PositionModify|OrderDelete|OrderModify|HistorySelect|HistoryDealGet|CopyRates|CopyTicks|CopyTicksRange|TesterStatistics|TesterDeposit|iATR|iADX|iCustom|WebRequest)\b'
foreach ($entry in @(
    @{ Name = 'sleeve module'; Text = $module },
    @{ Name = 'contract harness'; Text = $harness }
)) {
    Assert-True (-not [regex]::IsMatch($entry.Text, $forbidden)) "$($entry.Name) must contain no trading, history, native-indicator, performance, or network APIs"
    Assert-True (-not $entry.Text.Contains('MqlTick.flags')) "$($entry.Name) must not inspect tick flags"
    Assert-True (-not [regex]::IsMatch($entry.Text, '#import\s+')) "$($entry.Name) must not import DLLs"
}

$common = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\KingEA'
$report = Get-ChildItem -LiteralPath $common -Filter 'sleeve_eth_st_001_contract_*.csv' |
    Sort-Object LastWriteTime | Select-Object -Last 1
Assert-True ($null -ne $report) 'deterministic Stage 11 evidence must exist'
$reportText = Get-Content -LiteralPath $report.FullName -Raw
Assert-True ($reportText.Contains('result,PASS') -and
             $reportText.Contains('checks,33') -and
             $reportText.Contains('failures,0') -and
             $reportText.Contains('candidate_budget_consumed,0') -and
             $reportText.Contains('order_capability,PROHIBITED_AND_ABSENT') -and
             $reportText.Contains('performance_authorization,DENIED')) 'runtime evidence must be a 33-check non-trading PASS'

Write-Output 'SLEEVE_ETH_ST_001_POLICY_PASS: frozen Candidate 001 integration, exact grid, closed-bar indicators/progress, signal expiry, immutable artifacts, and no trading/performance capability.'
