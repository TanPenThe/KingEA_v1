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
$preToolingPath = Join-Path $Workspace 'governance\evidence\stage14\PRE_TOOLING_GATE1_REPLACEMENT_PREP_V2_20260809.json'
$manualPreToolingPath = Join-Path $Workspace 'governance\evidence\stage14\PRE_TOOLING_GATE1_MANUAL_BATCH_V7_20260809.json'
$gate1AuthorizationPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_preparation_20260808\GATE1_AUTHORIZATION.json'
$invalidationPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_execution_20260808\INFRASTRUCTURE_INVALIDATION_G1-0000.json'
$replacementRootPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_replacement_20260809\GATE1_ROOT.json'
$replacementIndexPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_replacement_20260809\CHILD_INDEX.json'
$replacementPacketPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_replacement_20260809\OWNER_APPROVAL_PACKET.json'
$replacementStatusPath = Join-Path $Workspace 'governance\evidence\stage14\GATE1_REPLACEMENT_STATUS_20260809.json'
$manualPlannerPath = Join-Path $Workspace 'research_pipeline\gate1_manual_batch.py'
$manualCliPath = Join-Path $Workspace 'research_pipeline\gate1_manual_cli.py'
$manualLauncherPath = Join-Path $Workspace 'operations\Start-Gate1ManualBatch.ps1'
$protectionManifestPath = Join-Path $Workspace 'governance\evidence\stage14\protection_intervals_20260802_v1\PROTECTION_INTERVALS_MANIFEST.json'
$protectionIntervalsPath = Join-Path $Workspace 'governance\evidence\stage14\protection_intervals_20260802_v1\PROTECTION_INTERVALS.csv'
$researchSpecificationPath = Join-Path $Workspace 'governance\evidence\stage14\cost_spec_capture_20260802\RESEARCH_SPECIFICATION.json'
$eaCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\GuardedResearchTester_shared_read_repair_v2.log'
$testCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\TestResearchPipeline_v101_zero_spread_r.log'
$benchmarkCompilePath = Join-Path $Workspace 'governance\evidence\stage14\compile\ResearchThroughputBenchmark_v102_final.log'
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
Assert-True ($ea.Contains('InpWorkloadDryRun') -and
             $ea.Contains('ResearchDryExerciseIntent') -and
             $ea.Contains('FULL_WORKLOAD_DRY_BENCHMARK') -and
             $ea.Contains('PersistDryBenchmarkPayload') -and
             $ea.Contains('if(InpWorkloadDryRun)') -and
             $ea.Contains('DRY_EXECUTION_PROHIBITED')) 'full-workload dry mode must exercise the frozen pipeline, swallow intent, prohibit execution, and persist opaque evidence'
Assert-True ($ea.Contains('#property tester_file "KingEA\\research_inputs\\PROTECTION_INTERVALS_STAGE14_20260802.csv"') -and
             $ea.Contains('ResearchOpenInputFile') -and
             $ea.Contains('FILE_COMMON') -and
             $ea.Contains('flags|FILE_SHARE_READ') -and
             $ea.Contains('flags|FILE_COMMON|FILE_SHARE_READ')) 'immutable manifest and calendar inputs must allow concurrent local-agent readers in both sandboxes'
Assert-True ($ea.Contains('InpExecutionAdapter') -and $ea.Contains('ResearchUsesVirtual') -and
             $ea.Contains('ResearchProcessVirtualPending') -and
             $ea.Contains('KINGEA_STAGE14_FRAME') -and
             $ea.Contains('ResearchLoadMarketIntervals') -and
             $ea.Contains('ResearchSpreadBaseline') -and
             $ea.Contains('ResearchReduceHalf')) 'EA must separate native/virtual state, load market facts, enforce spread tiers, and persist frames'
Assert-True ($ea.Contains('g_spread_baseline_cache') -and
             $ea.Contains('KingEAResearchSpreadBaselineCacheHit') -and
             $ea.Contains('ArrayResize(g_current_bar_spreads,count+1,8192)') -and
             $ea.Contains('g_market_interval_snapshot') -and
             $ea.Contains('ResearchUpdatePeriodsFast')) 'tick hot path must cache spread/calendar facts, reserve the per-bar spread buffer, and avoid repeated period conversion'
Assert-True ($pure.Contains('KingEAResearchRouteEntry') -and
             $pure.Contains('KingEAResearchCompleteDelayedEntry') -and
             $pure.Contains('KingEAResearchSelectMarketInterval') -and
             $pure.Contains('KingEAResearchResolveMarketInterval') -and
             $pure.Contains('KingEAResearchNormalizeProtectionType') -and
             $pure.Contains('KingEAResearchSpreadBaselineCacheHit') -and
             $pure.Contains('KingEAResearchObservedSpreadValid') -and
             $pure.Contains('KINGEA_RESEARCH_SEEDED_MISS') -and
             $pure.Contains('KINGEA_RESEARCH_DELAY_EXPIRY')) 'pure execution seam must own exclusive combined outcomes'
Assert-True ($harness.Contains('virtual sentinel fill reaches position and accounting without native order') -and
             $harness.Contains('native route consumes only tester result price') -and
             $harness.Contains('indexed interval lookup preserves overlapping priority') -and
             $harness.Contains('indexed interval lookup preserves half-open end boundary') -and
             $harness.Contains('calendar snapshot wakes exactly at the next future interval') -and
             $harness.Contains('broker HMR remains margin-only and separate from entry blackout') -and
             $harness.Contains('unavailable early-history baseline is cached for the full slot') -and
             $harness.Contains('zero observed spread is valid data while negative spread distance fails')) 'adapter connection, indexed interval lookup, HMR/blackout separation, and spread-cache boundaries must have dedicated contract tests'
Assert-True (-not [regex]::IsMatch($pure + $harness, '\b(OrderSend|OrderSendAsync|PositionOpen|PositionClose|PositionModify|HistorySelect|CopyRates|CopyTicks|TesterStatistics|WebRequest)\b')) 'pure seam and harness must contain no broker/history/performance/network capability'
Assert-True (-not [regex]::IsMatch($ea + $pure + $harness, '#import\s+|MqlTick\.flags|\bWebRequest\b')) 'MQL5 path must contain no DLL, tick-flag, or network bypass'
Assert-True ($benchmark.Contains('SIGNAL_FREE_BENCHMARK') -and
             $benchmark.Contains('signals=0|trades=0|returns=ABSENT|candidate_budget=0') -and
             $benchmark.Contains('InpExpectedServerFragment') -and
             $benchmark.Contains('AccountInfoString(ACCOUNT_SERVER)') -and
             $benchmark.Contains('InpExpectedTerminalBuild') -and
             $benchmark.Contains('TerminalInfoInteger(TERMINAL_BUILD)') -and
             $benchmark.Contains('PersistBenchmarkPayload') -and
             $benchmark.Contains('FileIsExist(filename,FILE_COMMON)') -and
             $benchmark.Contains('KINGEA_STAGE14_BENCHMARK_RESULT') -and
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
Assert-True ($preTooling.kind -eq 'PRE_TOOLING' -and $preTooling.build_id -eq 'KINGEA-STAGE14-20260809-GATE1-REPLACEMENT-PREP-V2') 'replacement PRE_TOOLING manifest must exist'
foreach ($source in $preTooling.sources) {
    Assert-True ((Test-Path -LiteralPath $source.path) -and
                 ((Get-Item -LiteralPath $source.path).Length -eq [long]$source.size) -and
                 ((Get-FileHash -Algorithm SHA256 -LiteralPath $source.path).Hash -eq $source.sha256)) "source changed after PRE_TOOLING: $($source.path)"
}
$manualPreTooling = Get-Content -LiteralPath $manualPreToolingPath -Raw | ConvertFrom-Json
Assert-True ($manualPreTooling.kind -eq 'PRE_TOOLING' -and $manualPreTooling.build_id -eq 'KINGEA-STAGE14-20260809-GATE1-MANUAL-BATCH-V7') 'historical manual-batch PRE_TOOLING evidence must remain retained'
$gate1Authorization = Get-Content -LiteralPath $gate1AuthorizationPath -Raw | ConvertFrom-Json
$manualPlanner = Get-Content -LiteralPath $manualPlannerPath -Raw
$manualCli = Get-Content -LiteralPath $manualCliPath -Raw
$manualLauncher = Get-Content -LiteralPath $manualLauncherPath -Raw
Assert-True ([bool]$gate1Authorization.owner_approved -and $gate1Authorization.gate -eq 1 -and
             $gate1Authorization.root_sha256 -eq 'BC4D5D84DBF45AAB6628AA0E1D39D984F715217BB1CA1C092DE1EE97385FA889' -and
             -not [bool]$gate1Authorization.oos_authorized -and
             -not [bool]$gate1Authorization.holdout_authorized -and
             $gate1Authorization.maximum_children_per_batch -eq 2) 'authorization must bind only the exact Gate 1 root and two-child manual scope'
$invalidation = Get-Content -LiteralPath $invalidationPath -Raw | ConvertFrom-Json
$replacementRoot = Get-Content -LiteralPath $replacementRootPath -Raw | ConvertFrom-Json
$replacementIndex = Get-Content -LiteralPath $replacementIndexPath -Raw | ConvertFrom-Json
$replacementPacket = Get-Content -LiteralPath $replacementPacketPath -Raw | ConvertFrom-Json
$replacementStatus = Get-Content -LiteralPath $replacementStatusPath -Raw | ConvertFrom-Json
Assert-True ($invalidation.status -eq 'INVALIDATED_PRESERVED_NOT_SELECTION_ELIGIBLE' -and
             -not [bool]$invalidation.replacement_may_reuse_results -and
             $invalidation.complete_frame_count -eq 978 -and
             $invalidation.tester_guard_refusal_count -eq 22 -and
             $invalidation.missing_configuration_ids.Count -eq 22 -and
             $invalidation.hard_failure_configuration_ids.Count -eq 2) 'failed child must remain invalidated, preserved, and unavailable to selection or replacement reuse'
Assert-True ($replacementRoot.root_sha256 -eq '04AB5A4F1F2E078ACAEE0370ED23F22FB3C4FF872309231F69A2BFD5FF8BA795' -and
             $replacementRoot.candidate_budget_before -eq 1 -and
             $replacementRoot.candidate_budget_transition -eq 'ALREADY_CONSUMED' -and
             $replacementRoot.launch_count -eq 200 -and
             $replacementRoot.configuration_pass_count -eq 194400 -and
             -not [bool]$replacementRoot.owner_approved -and
             $replacementIndex.children.Count -eq 200 -and
             $replacementPacket.status -eq 'AWAITING_EXPLICIT_OWNER_APPROVAL' -and
             -not [bool]$replacementPacket.execution_authorized -and
             -not (Test-Path -LiteralPath (Join-Path (Split-Path $replacementRootPath) 'GATE1_AUTHORIZATION.json'))) 'replacement root must preserve the consumed budget and remain unauthorized pending exact-root owner approval'
Assert-True ($replacementStatus.status -eq 'REPLACEMENT_ROOT_VERIFIED_AWAITING_OWNER_APPROVAL' -and
             $replacementStatus.candidate_budget_consumed -eq 1 -and
             -not [bool]$replacementStatus.prior_results_reusable -and
             $replacementStatus.launcher_state -eq 'OLD_ROOT_ONLY_FAIL_CLOSED_DO_NOT_RUN') 'current governance status must expose the invalidation, consumed budget, and launcher prohibition'
Assert-True ($manualPlanner.Contains('MAXIMUM_CHILDREN = 2') -and
             $manualPlanner.Contains('MAXIMUM_CHILD_HOURS = 3.75') -and
             $manualPlanner.Contains('COMPLETION_SEQUENCE_GAP') -and
             $manualPlanner.Contains('RESULT_FRAME_HARD_FAILURE')) 'manual planner must cap batches and fail closed on resume or result defects'
Assert-True ($manualLauncher.Contains('manual foreground batch') -and
             -not [regex]::IsMatch($manualLauncher, '\b(Start-Job|Register-ScheduledTask|New-Service)\b')) 'launcher must remain foreground-only with no task, job, or service installation'
Assert-True ($manualCli.Contains('MT5_OR_TESTER_ALREADY_RUNNING') -and
             $manualCli.Contains('DEMO2_ACCOUNT_IDENTITY_MISMATCH') -and
             $manualCli.Contains('KINGEA_SCHEDULED_TASK_PRESENT') -and
             $manualCli.Contains('TERMINAL_BUILD_MISMATCH') -and
             $manualCli.Contains('PREEXISTING_CHILD_SPOOL_REQUIRES_REVIEW')) 'manual execution adapter must recheck environment and preserve partial evidence'
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
             -not [bool]$contractJson.authorization.holdout) 'historical readiness contract must remain retained and deny all then-unapproved gates'

Write-Output 'STAGE14_RESEARCH_READINESS_POLICY_PASS: prior child invalidated and preserved, concurrent-read repair compiled cleanly, replacement root verified with consumed budget retained, and execution/OOS/holdout denied pending new exact-root approval.'
