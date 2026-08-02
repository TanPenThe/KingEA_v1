param([string]$Workspace = 'C:\KingEA_v1')

$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "STAGE12_RESEARCH_PIPELINE_POLICY_FAIL: $Message" }
}

$purePath = Join-Path $Workspace 'MQL5\Include\KingEA\ResearchExecution.mqh'
$eaPath = Join-Path $Workspace 'MQL5\Experts\KingEA\GuardedResearchTester.mq5'
$harnessPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestResearchPipeline.mq5'
$eaCompilePath = Join-Path $Workspace 'MQL5\Experts\KingEA\guarded_research_tester_compile.log'
$testCompilePath = Join-Path $Workspace 'MQL5\Scripts\KingEA\research_pipeline_contract_compile.log'
$pythonPath = Join-Path $Workspace 'research_pipeline\stage12.py'
$cliPath = Join-Path $Workspace 'research_pipeline\cli.py'
$pythonTestPath = Join-Path $Workspace 'tests\test_stage12_pipeline.py'
$configPath = Join-Path $Workspace 'config\research_pipeline_tester_TEMPLATE.ini'
$contractPath = Join-Path $Workspace 'governance\STAGE12_RESEARCH_PIPELINE_CONTRACT.md'
$contractJsonPath = Join-Path $Workspace 'governance\stage12_pipeline_contract.json'
$drillPath = Join-Path $Workspace 'governance\drills\DRILL-DEMO-001.json'
$watchdogPath = Join-Path $Workspace 'config\watchdog.demo2.disabled.json'

$pure = Get-Content -LiteralPath $purePath -Raw
$ea = Get-Content -LiteralPath $eaPath -Raw
$harness = Get-Content -LiteralPath $harnessPath -Raw
$eaCompile = Get-Content -LiteralPath $eaCompilePath -Raw
$testCompile = Get-Content -LiteralPath $testCompilePath -Raw
$python = Get-Content -LiteralPath $pythonPath -Raw
$cli = Get-Content -LiteralPath $cliPath -Raw
$pythonTest = Get-Content -LiteralPath $pythonTestPath -Raw
$config = Get-Content -LiteralPath $configPath -Raw
$contract = Get-Content -LiteralPath $contractPath -Raw
$contractJson = Get-Content -LiteralPath $contractJsonPath -Raw | ConvertFrom-Json
$drill = Get-Content -LiteralPath $drillPath -Raw | ConvertFrom-Json
$watchdog = Get-Content -LiteralPath $watchdogPath -Raw | ConvertFrom-Json

Assert-True (([regex]::Matches($ea, '\bOrderSend\s*\(')).Count -eq 1) 'the tester EA must have exactly one guarded order seam'
Assert-True ($ea.Contains('if(!g_initialized || !ResearchAuthorizationValid())') -and
             $ea.Contains('return OrderSend(request,result);')) 'authorization must be revalidated immediately before OrderSend'
Assert-True ($ea.Contains('MQLInfoInteger(MQL_TESTER)') -and
             $ea.Contains('InpTesterModel!=4') -and
             $ea.Contains('!InpLocalAgentsOnly') -and
             $ea.Contains('!InpRemoteAgentsDisabled') -and
             $ea.Contains('!InpCloudAgentsDisabled')) 'tester/model/local-only guards must be explicit'
Assert-True ($ea.Contains('KingEAEvaluateRegime') -and
             $ea.Contains('KingEAEvaluateSleeveEthSt001') -and
             $ea.Contains('KingEAEvaluateSafety')) 'tester must invoke the frozen regime, sleeve, and safety modules'
Assert-True ($ea.Contains('FrameAdd("KINGEA_STAGE12_COMPLETE"') -and
             $ea.Contains('while(FrameNext(') -and
             $ea.Contains('void OnTesterDeinit()')) 'complete frames and delayed draining must exist'
Assert-True ($ea.Contains('order.sl=safety.required_stop') -and
             $ea.Contains('order.tp=0.0')) 'entry must submit the protective stop and no fixed TP'
Assert-True (-not [regex]::IsMatch($pure + $harness, '\b(OrderSend|OrderSendAsync|PositionOpen|PositionClose|PositionModify|HistorySelect|CopyRates|CopyTicks|TesterStatistics|WebRequest)\b')) 'pure adapter and harness must contain no trading/history/performance/network capability'
Assert-True (-not [regex]::IsMatch($ea + $pure + $harness, '\b(CopyRates|CopyTicks|CopyTicksRange|HistorySelect|HistoryDealGet|TesterStatistics|iATR|iADX|iCustom|WebRequest)\b')) 'Stage 12 MQL5 must not bypass internal bars or access performance/history/network APIs'
Assert-True (-not ($ea + $pure + $harness).Contains('MqlTick.flags')) 'Stage 12 must not inspect tick flags'
Assert-True (-not [regex]::IsMatch($ea + $pure + $harness, '#import\s+')) 'Stage 12 must not import DLLs'
Assert-True ($eaCompile.Contains('Result: 0 errors, 0 warnings') -and
             $testCompile.Contains('Result: 0 errors, 0 warnings')) 'both MQL5 artifacts must compile without warnings'

Assert-True ($python.Contains('PARAMETER_GRIDS') -and $python.Contains('self.configuration_count') -and
             $python.Contains('mandatory_stress_plan') -and $python.Contains('paths: int = 10_000')) 'offline module must freeze grid and statistical contracts'
Assert-True ($python.Contains('branch_scores') -and $python.Contains('governing_score') -and
             $pythonTest.Contains('uses_the_lower_score')) 'branch-local scoring and lower-branch selection must be exercised'
Assert-True ($python.Contains('validate_branch_trade_floor') -and
             $python.Contains('holdout_excluded') -and
             $pythonTest.Contains('trade_floor_is_per_branch')) 'independent trade-floor semantics must be present'
Assert-True ($python.Contains('build_surface_evidence') -and
             $pythonTest.Contains('hashes_all_parameter_pairs')) 'surface and all pairwise heatmaps must be tested'
Assert-True ($cli.Contains('execute-development') -and $cli.Contains('execute-oos') -and
             $cli.Contains('execute-holdout') -and $cli.Contains('subprocess.run')) 'guarded orchestrator commands must exist'
Assert-True ($config.Contains('Model=4') -and $config.Contains('Optimization=1') -and
             $config.Contains('UseLocal=1') -and $config.Contains('UseRemote=0') -and
             $config.Contains('UseCloud=0') -and $config.Contains('Genetic=0')) 'tester template must be exhaustive and local-only'
Assert-True ($contract.Contains('no result-bearing run performed') -and
             $contract.Contains('Completion authorizes Stage 13 accounting/export implementation only')) 'governance must retain the authorization boundary'
Assert-True ($contractJson.status -eq 'IMPLEMENTED_NON_PERFORMANCE' -and
             $contractJson.candidate_budget_consumed -eq 0 -and
             -not [bool]$contractJson.authorization.development_execution) 'contract JSON must deny result-bearing execution'

$expectedHashes = @{
    (Join-Path $Workspace 'MQL5\Include\KingEA\CandidateEthSt001.mqh') = '4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83'
    (Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_DRAFT.json') = '3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC'
    (Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_FREEZE.json') = '1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06'
}
foreach ($path in $expectedHashes.Keys) {
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -eq $expectedHashes[$path]) "frozen artifact changed: $path"
}
Assert-True ($drill.Status -eq 'PASS_QUARANTINED' -and [bool]$drill.Standdown.Active -and [bool]$drill.Final.StanddownActive) 'Stage 9 standdown must remain active'
Assert-True (-not [bool]$watchdog.Enabled -and -not [bool]$watchdog.InstallScheduledTask) 'watchdog must remain disabled and uninstalled'

$common = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\KingEA'
$report = Get-ChildItem -LiteralPath $common -Filter 'stage12_research_contract_*.csv' | Sort-Object LastWriteTime | Select-Object -Last 1
Assert-True ($null -ne $report) 'synthetic Stage 12 evidence must exist'
$reportText = Get-Content -LiteralPath $report.FullName -Raw
Assert-True ($reportText.Contains('result,PASS') -and $reportText.Contains('checks,7') -and
             $reportText.Contains('failures,0') -and $reportText.Contains('fixture,SYNTHETIC_ONLY') -and
             $reportText.Contains('candidate_budget_consumed,0') -and
             $reportText.Contains('performance_authorization,DENIED')) 'runtime evidence must remain non-performance PASS'

Write-Output 'STAGE12_RESEARCH_PIPELINE_POLICY_PASS: guarded tester seam, immutable manifests, independent branches, complete stresses/surfaces, deterministic Monte Carlo, frozen hashes, and zero performance authorization.'
