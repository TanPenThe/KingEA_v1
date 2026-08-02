param([string]$Workspace = 'C:\KingEA_v1')

$ErrorActionPreference = 'Stop'
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "STAGE14_RESEARCH_READINESS_POLICY_FAIL: $Message" }
}

$eaPath = Join-Path $Workspace 'MQL5\Experts\KingEA\GuardedResearchTester.mq5'
$purePath = Join-Path $Workspace 'MQL5\Include\KingEA\ResearchExecution.mqh'
$harnessPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\TestResearchPipeline.mq5'
$benchmarkPath = Join-Path $Workspace 'MQL5\Experts\KingEA\ResearchThroughputBenchmark.mq5'
$calendarExporterPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\ExportResearchCalendar.mq5'
$feasibilityExporterPath = Join-Path $Workspace 'MQL5\Scripts\KingEA\ExportSymbolFeasibility.mq5'
$pythonPath = Join-Path $Workspace 'research_pipeline\stage14.py'
$cliPath = Join-Path $Workspace 'research_pipeline\stage14_cli.py'
$calendarAdapterPath = Join-Path $Workspace 'research_pipeline\mql5_calendar.py'
$calendarAdapterTestPath = Join-Path $Workspace 'tests\test_mql5_calendar_adapter.py'
$testPath = Join-Path $Workspace 'tests\test_stage14_pipeline.py'
$contractPath = Join-Path $Workspace 'governance\STAGE14_RESEARCH_READINESS_CONTRACT.md'
$contractJsonPath = Join-Path $Workspace 'governance\stage14_research_readiness_contract.json'
$preToolingPath = Join-Path $Workspace 'governance\evidence\stage14\PRE_TOOLING_V5.json'
$protectionManifestPath = Join-Path $Workspace 'governance\evidence\stage14\protection_intervals_20260802_v1\PROTECTION_INTERVALS_MANIFEST.json'
$protectionIntervalsPath = Join-Path $Workspace 'governance\evidence\stage14\protection_intervals_20260802_v1\PROTECTION_INTERVALS.csv'
$researchSpecificationPath = Join-Path $Workspace 'governance\evidence\stage14\cost_spec_capture_20260802\RESEARCH_SPECIFICATION.json'
$eaCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\GuardedResearchTester.log'
$testCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\TestResearchPipeline.log'
$benchmarkCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\ResearchThroughputBenchmark.log'
$calendarCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\ExportResearchCalendar.log'

$ea = Get-Content -LiteralPath $eaPath -Raw
$pure = Get-Content -LiteralPath $purePath -Raw
$harness = Get-Content -LiteralPath $harnessPath -Raw
$benchmark = Get-Content -LiteralPath $benchmarkPath -Raw
$calendarExporter = Get-Content -LiteralPath $calendarExporterPath -Raw
$feasibilityExporter = Get-Content -LiteralPath $feasibilityExporterPath -Raw
$python = Get-Content -LiteralPath $pythonPath -Raw
$cli = Get-Content -LiteralPath $cliPath -Raw
$calendarAdapter = Get-Content -LiteralPath $calendarAdapterPath -Raw
$calendarAdapterTests = Get-Content -LiteralPath $calendarAdapterTestPath -Raw
$tests = Get-Content -LiteralPath $testPath -Raw
$contract = Get-Content -LiteralPath $contractPath -Raw
$contractJson = Get-Content -LiteralPath $contractJsonPath -Raw | ConvertFrom-Json

Assert-True (([regex]::Matches($ea, '\bOrderSend\s*\(')).Count -eq 1) 'exactly one guarded native order seam must remain'
Assert-True ($ea.Contains('InpExecutionAdapter') -and $ea.Contains('ResearchUsesVirtual') -and
             $ea.Contains('ResearchProcessVirtualPending') -and
             $ea.Contains('KINGEA_STAGE14_FRAME') -and
             $ea.Contains('ResearchLoadMarketIntervals') -and
             $ea.Contains('ResearchSpreadBaseline') -and
             $ea.Contains('ResearchReduceHalf')) 'EA must separate native/virtual state, load market facts, enforce spread tiers, and persist frames'
Assert-True ($pure.Contains('KingEAResearchRouteEntry') -and
             $pure.Contains('KingEAResearchCompleteDelayedEntry') -and
             $pure.Contains('KINGEA_RESEARCH_SEEDED_MISS') -and
             $pure.Contains('KINGEA_RESEARCH_DELAY_EXPIRY')) 'pure execution seam must own exclusive combined outcomes'
Assert-True ($harness.Contains('virtual sentinel fill reaches position and accounting without native order') -and
             $harness.Contains('native route consumes only tester result price')) 'adapter connection bug must have a dedicated sentinel test'
Assert-True (-not [regex]::IsMatch($pure + $harness, '\b(OrderSend|OrderSendAsync|PositionOpen|PositionClose|PositionModify|HistorySelect|CopyRates|CopyTicks|TesterStatistics|WebRequest)\b')) 'pure seam and harness must contain no broker/history/performance/network capability'
Assert-True (-not [regex]::IsMatch($ea + $pure + $harness, '#import\s+|MqlTick\.flags|\bWebRequest\b')) 'MQL5 path must contain no DLL, tick-flag, or network bypass'
Assert-True ($benchmark.Contains('SIGNAL_FREE_BENCHMARK') -and
             $benchmark.Contains('signals=0|trades=0|returns=ABSENT|candidate_budget=0') -and
             -not [regex]::IsMatch($benchmark, '\b(OrderSend|PositionOpen|PositionClose|HistorySelect|TesterStatistics|iATR|iADX|iCustom|WebRequest)\b')) 'benchmark must be real-tick throughput only with no research or order capability'
Assert-True ($calendarExporter.Contains('CalendarValueHistory') -and
             $calendarExporter.Contains('CALENDAR_IMPORTANCE_HIGH') -and
             -not [regex]::IsMatch($calendarExporter, '\b(OrderSend|PositionOpen|PositionClose|HistorySelect|CopyRates|CopyTicks|WebRequest)\b')) 'calendar exporter must be read-only and high-impact USD scoped'
Assert-True ($feasibilityExporter.Contains('WaitForCaptureReadiness') -and
             $feasibilityExporter.Contains('InpRequiredServerFragment') -and
             $feasibilityExporter.Contains('ACCOUNT_EQUITY') -and
             $feasibilityExporter.Contains('CAPTURE_NOT_READY') -and
             -not [regex]::IsMatch($feasibilityExporter, '\b(OrderSend|PositionOpen|PositionClose|PositionModify|WebRequest)\b')) 'fresh feasibility evidence must wait for Demo2 identity and synchronized positive account equity without order capability'

foreach ($needle in @('prepare_gate_root','materialize_children','append_frame','finalize_frames','evaluate_benchmark','evaluate_pace','combined_outcome','parse_calendar_export','validate_calendar_snapshot','render_market_intervals','classify_hmr_observation','validate_research_specification','reconcile_research_capture','create_pre_tooling_manifest')) {
    Assert-True ($python.Contains("def $needle")) "deep coordinator behavior missing: $needle"
}
Assert-True ($python.Contains('scenario_runs_per_branch') -and $python.Contains('!= 312') -and
             $tests.Contains('194_400') -and $tests.Contains('launch_count"], 624')) 'all gate cardinalities must be structural and tested'
Assert-True ($tests.Contains('PERSISTENT_THROUGHPUT_DEGRADATION') -and
             $tests.Contains('DELAY_EXPIRY') -and $tests.Contains('SEEDED_MISS') -and
             $tests.Contains('conflicting replay is forbidden')) 'pace, exclusive outcomes, and append-only frames must be tested'
Assert-True ($cli.Contains('execute-child') -and $cli.Contains('verify_pre_tooling_manifest') -and
             $cli.Contains('verify_bundle') -and $cli.Contains('subprocess.run')) 'process adapter must revalidate provenance and exact bundle before launch'
Assert-True ($cli.Contains('fetch-calendar-website') -and
             $calendarAdapter.Contains('https://www.mql5.com/en/economic-calendar/content') -and
             $calendarAdapter.Contains('CALENDAR_NATIVE_ID_SET_MISMATCH') -and
             $calendarAdapter.Contains('CALENDAR_MONTH_COVERAGE_MISSING') -and
             $calendarAdapterTests.Contains('test_cli_writes_append_only_raw_snapshot_and_reconciliation_evidence')) 'approved MQL5 website adapter must be pinned, fail closed, reconciled to native evidence, and tested append-only'
Assert-True (-not [regex]::IsMatch($calendarAdapter, 'cookie|authorization|password|login')) 'public calendar adapter must not depend on session secrets or authentication'

$protectionManifest = Get-Content -LiteralPath $protectionManifestPath -Raw | ConvertFrom-Json
$protectionIntervals = Get-Content -LiteralPath $protectionIntervalsPath -Raw
$researchSpecification = Get-Content -LiteralPath $researchSpecificationPath -Raw | ConvertFrom-Json
Assert-True ($protectionManifest.status -eq 'PASS_SEPARATE_HMR_AND_ENTRY_PROTECTION' -and
             [bool]$protectionManifest.independent_semantics.conflation_prohibited -and
             -not [bool]$protectionManifest.independent_semantics.hmr_schedule_is_hard_end -and
             $protectionManifest.protection_intervals.type_counts.BROKER_HMR_SCHEDULED -eq 1971 -and
             $protectionManifest.protection_intervals.type_counts.KINGEA_ENTRY_BLACKOUT -eq 1971 -and
             $protectionIntervals.Contains('BROKER_HMR_SCHEDULED') -and
             $protectionIntervals.Contains('KINGEA_ENTRY_BLACKOUT')) 'broker HMR and KingEA entry protection must remain separate'
Assert-True ($researchSpecification.hmr.stressed_position_size_assumption_lots -eq 0.01 -and
             $researchSpecification.hmr.stressed_margin_used_usd -eq 0.093463 -and
             [bool]$researchSpecification.hmr.scheduled_window_is_not_a_hard_end -and
             [bool]$researchSpecification.hmr.kingea_entry_blackout_is_separate) 'minimum-lot margin basis and extended-HMR fail-closed rules must be explicit'

$preTooling = Get-Content -LiteralPath $preToolingPath -Raw | ConvertFrom-Json
Assert-True ($preTooling.kind -eq 'PRE_TOOLING' -and $preTooling.build_id -eq 'KINGEA-STAGE14-20260802-E') 'PRE_TOOLING manifest must exist'
foreach ($source in $preTooling.sources) {
    Assert-True ((Test-Path -LiteralPath $source.path) -and
                 ((Get-Item -LiteralPath $source.path).Length -eq [long]$source.size) -and
                 ((Get-FileHash -Algorithm SHA256 -LiteralPath $source.path).Hash -eq $source.sha256)) "source changed after PRE_TOOLING: $($source.path)"
}
Assert-True ((Get-Content -LiteralPath $eaCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'tester EA compile must be clean'
Assert-True ((Get-Content -LiteralPath $testCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'contract harness compile must be clean'
Assert-True ((Get-Content -LiteralPath $benchmarkCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'benchmark compile must be clean'
Assert-True ((Get-Content -LiteralPath $calendarCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'calendar exporter compile must be clean'

$expectedFrozen = @{
    (Join-Path $Workspace 'MQL5\Include\KingEA\CandidateEthSt001.mqh') = '4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83'
    (Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_DRAFT.json') = '3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC'
    (Join-Path $Workspace 'governance\candidates\CAND-ETH-ST-001_FREEZE.json') = '1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06'
}
foreach ($path in $expectedFrozen.Keys) {
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -eq $expectedFrozen[$path]) "frozen artifact changed: $path"
}

$drill = Get-Content -LiteralPath (Join-Path $Workspace 'governance\drills\DRILL-DEMO-001.json') -Raw | ConvertFrom-Json
$watchdog = Get-Content -LiteralPath (Join-Path $Workspace 'config\watchdog.demo2.disabled.json') -Raw | ConvertFrom-Json
Assert-True ($drill.Status -eq 'PASS_QUARANTINED' -and [bool]$drill.Standdown.Active) 'Stage 9 standdown must remain active'
Assert-True (-not [bool]$watchdog.Enabled -and -not [bool]$watchdog.InstallScheduledTask) 'watchdog must remain disabled and uninstalled'
Assert-True ($contract.Contains('no result-bearing research executed') -and
             $contract.Contains('explicit approval of the exact root SHA-256')) 'contract must retain approval boundary'
Assert-True ($contractJson.status -eq 'READINESS_IMPLEMENTED_INPUTS_ACCEPTED_BENCHMARK_NOT_RUN' -and
             $contractJson.candidate_budget_consumed -eq 0 -and
             $contractJson.calendar.status -eq 'ACCEPTED_DUAL_SOURCE' -and
             $contractJson.calendar.matched_events -eq 1971 -and
             $contractJson.cost_and_specification.status -eq 'ACCEPTED_FRESH_RECONCILED_BROKER_FACTS' -and
             $contractJson.protection_intervals.status -eq 'ACCEPTED_SEPARATE_HMR_AND_ENTRY_PROTECTION' -and
             -not [bool]$contractJson.authorization.signal_free_benchmark_preparation -and
             -not [bool]$contractJson.authorization.gate1_execution -and
             -not [bool]$contractJson.authorization.holdout) 'governance must deny all result-bearing gates and holdout'

Write-Output 'STAGE14_RESEARCH_READINESS_POLICY_PASS: schema-v2 roots, exact bundle realization, native/virtual isolation, append-only frames, pace controls, pre-tooling provenance, frozen hashes, and zero research authorization.'
