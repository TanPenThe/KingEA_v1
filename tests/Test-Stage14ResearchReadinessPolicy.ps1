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
$preToolingPath = Join-Path $Workspace 'governance\evidence\stage14\PRE_TOOLING_GATE1_REPLACEMENT_PREP_V1_20260809.json'
$zeroEntryPreToolingPath = (Get-ChildItem -LiteralPath (Join-Path $Workspace 'governance\evidence\stage14') -Filter 'PRE_TOOLING_ZERO_ENTRY_DIAGNOSTIC_20260903_EXECUTION_V*.json' |
    Sort-Object Name -Descending | Select-Object -First 1).FullName
$manualPreToolingPath = Join-Path $Workspace 'governance\evidence\stage14\PRE_TOOLING_GATE1_CONTINUATION_MANUAL_V3_20260824.json'
$gate1AuthorizationPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_continuation_20260824_v2\GATE1_AUTHORIZATION.json'
$historicalAuthorizationPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_replacement_20260809\GATE1_AUTHORIZATION.json'
$invalidationPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_execution_20260808\INFRASTRUCTURE_INVALIDATION_G1-0000.json'
$replacementRootPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_continuation_20260824_v2\GATE1_ROOT.json'
$replacementIndexPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_continuation_20260824_v2\CHILD_INDEX.json'
$replacementPacketPath = Join-Path $Workspace 'governance\evidence\stage14\gate1_continuation_20260824_v2\OWNER_APPROVAL_PACKET.json'
$replacementStatusPath = Join-Path $Workspace 'governance\evidence\stage14\GATE1_REPLACEMENT_STATUS_20260809.json'
$replacementAuthorizedStatusPath = Join-Path $Workspace 'governance\evidence\stage14\GATE1_REPLACEMENT_AUTHORIZED_20260809.json'
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
$dateGatePreToolingPath = (Get-ChildItem -LiteralPath (Join-Path $Workspace 'governance\evidence\stage14') -Filter 'PRE_TOOLING_B2_*_20260904.json' |
    Sort-Object LastWriteTimeUtc, Name | Select-Object -Last 1).FullName
$dateGateCompilePath = (Get-ChildItem -LiteralPath (Join-Path $Workspace 'governance\evidence\stage14\b2_readiness_20260904') -Filter 'GuardedResearchTester_B2*_compile.log' |
    Sort-Object LastWriteTimeUtc, Name | Select-Object -Last 1).FullName
$dateGateReportPath = Join-Path $Workspace 'governance\review\B2_DATE_GATE_REPAIR_REPORT_20260904.md'
$conformanceRoutingReceiptPath = Join-Path $Workspace 'governance\evidence\stage14\native_production_conformance_20260909\oninit_authority_routing_repair_v1\POST_IMPLEMENTATION_REVIEW_RECEIPT.json'

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
             $ea.Contains('ResearchCaptureLocalInput') -and
             $ea.Contains('FileOpen(filename,FILE_READ|FILE_BIN|FILE_SHARE_READ)') -and
             $ea.Contains('// No shared fallback. A missing staged local artifact fails closed.') -and
             -not $ea.Contains('flags|FILE_COMMON|FILE_SHARE_READ')) 'immutable manifest and calendar inputs must be captured once from the local-agent sandbox without shared fallback'
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
$zeroEntryPreTooling = Get-Content -LiteralPath $zeroEntryPreToolingPath -Raw | ConvertFrom-Json
$dateGatePreTooling = Get-Content -LiteralPath $dateGatePreToolingPath -Raw | ConvertFrom-Json
$conformanceRoutingReceipt = Get-Content -LiteralPath $conformanceRoutingReceiptPath -Raw | ConvertFrom-Json
Assert-True ($conformanceRoutingReceipt.scope -eq 'CONFORMANCE_ONINIT_AUTHORITY_ROUTING_REPAIR_V1' -and
             $conformanceRoutingReceipt.status -eq 'IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW' -and
             $conformanceRoutingReceipt.b2 -eq 'LOCKED') 'later conformance routing provenance must remain review-pending with B2 locked'
$conformanceRoutingEA = $conformanceRoutingReceipt.files | Where-Object { $_.path -eq $eaPath } | Select-Object -First 1
Assert-True ($null -ne $conformanceRoutingEA -and
             (Get-FileHash -Algorithm SHA256 -LiteralPath $eaPath).Hash -eq $conformanceRoutingEA.sha256 -and
             (Get-Item -LiteralPath $eaPath).Length -eq [long]$conformanceRoutingEA.byte_length) 'current tester EA must equal its scoped conformance-routing receipt'
Assert-True ($dateGatePreTooling.kind -eq 'PRE_TOOLING_SOURCE_MANIFEST' -and
             $dateGatePreTooling.build_id -match '^KINGEA-B2-(DATE-GATE-REPAIR|END-BOUNDARY-CLOSURE|NATIVE-ROUTING-AUDIT|BOUNDARY-VALUATION-AUDIT|NATIVE-PER-GROUP-COST-EVIDENCE-AUDIT)-20260904-V[0-9]+$' -and
             $dateGatePreTooling.b2_status -eq 'LOCKED') 'date-gate source provenance must be sealed while B2 remains locked'
$dateGateHashes = @{}
foreach ($source in $dateGatePreTooling.sources) {
    $currentHash = if(Test-Path -LiteralPath $source.path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $source.path).Hash } else { '' }
    $sourceResolved = if(Test-Path -LiteralPath $source.path) { (Resolve-Path -LiteralPath $source.path).Path } else { '' }
    $scopedRoutingReplacement = $sourceResolved -eq (Resolve-Path -LiteralPath $eaPath).Path -and $currentHash -eq $conformanceRoutingEA.sha256
    Assert-True ($scopedRoutingReplacement -or
                 ((Test-Path -LiteralPath $source.path) -and
                  ((Get-Item -LiteralPath $source.path).Length -eq [long]$source.size) -and
                  ($currentHash -eq $source.sha256))) "date-gate source changed after PRE_TOOLING: $($source.path)"
    $dateGateHashes[$source.path] = $source.sha256
}
$dateGateHashes[$eaPath] = $conformanceRoutingEA.sha256
Assert-True ($zeroEntryPreTooling.kind -eq 'PRE_TOOLING_SOURCE_MANIFEST' -and
             $zeroEntryPreTooling.build_id -match '^STAGE14_GATE1_ZERO_ENTRY_DIAGNOSTIC_EXECUTION_20260903_V[0-9]+$' -and
             $zeroEntryPreTooling.status -eq 'PRE_TOOLING') 'zero-entry diagnostic source provenance must be sealed before verification'
$zeroEntryHashes = @{}
foreach ($source in $zeroEntryPreTooling.sources) {
    $currentHash = if(Test-Path -LiteralPath $source.path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $source.path).Hash } else { '' }
    Assert-True ((Test-Path -LiteralPath $source.path) -and
                 (((Get-Item -LiteralPath $source.path).Length -eq [long]$source.size -and $currentHash -eq $source.sha256) -or
                  ($dateGateHashes.Values -contains $currentHash))) "zero-entry source changed without later governed date-gate provenance: $($source.path)"
    $zeroEntryHashes[$source.path] = $source.sha256
}
Assert-True ($preTooling.kind -eq 'PRE_TOOLING' -and $preTooling.build_id -eq 'KINGEA-STAGE14-20260809-GATE1-REPLACEMENT-PREP-V1') 'root-bound replacement PRE_TOOLING manifest must exist'
foreach ($source in $preTooling.sources) {
    $currentHash = if(Test-Path -LiteralPath $source.path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $source.path).Hash } else { '' }
    $stage14Replacement = (($zeroEntryHashes.Values -contains $currentHash) -or
                            ($dateGateHashes.Values -contains $currentHash))
    Assert-True ($stage14Replacement -or
                 ((Test-Path -LiteralPath $source.path) -and
                  ((Get-Item -LiteralPath $source.path).Length -eq [long]$source.size) -and
                  ($currentHash -eq $source.sha256))) "source changed after PRE_TOOLING without a governed replacement: $($source.path)"
}
$manualPreTooling = Get-Content -LiteralPath $manualPreToolingPath -Raw | ConvertFrom-Json
Assert-True ($manualPreTooling.kind -eq 'PRE_TOOLING' -and $manualPreTooling.build_id -eq 'KINGEA-STAGE14-20260824-GATE1-CONTINUATION-MANUAL-V3') 'continuation manual-batch PRE_TOOLING manifest must exist'
foreach ($source in $manualPreTooling.sources) {
    $currentHash = if(Test-Path -LiteralPath $source.path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $source.path).Hash } else { '' }
    $diagnosticPolicyReplacement = $source.path -eq (Join-Path $Workspace 'tests\Test-Stage14ResearchReadinessPolicy.ps1') -and
                                   (($zeroEntryHashes.Values -contains $currentHash) -or ($dateGateHashes.Values -contains $currentHash))
    Assert-True ($diagnosticPolicyReplacement -or
                 ((Test-Path -LiteralPath $source.path) -and
                  ((Get-Item -LiteralPath $source.path).Length -eq [long]$source.size) -and
                  ($currentHash -eq $source.sha256))) "replacement manual-batch source changed after PRE_TOOLING without a governed replacement: $($source.path)"
}
$gate1Authorization = Get-Content -LiteralPath $gate1AuthorizationPath -Raw | ConvertFrom-Json
$manualPlanner = Get-Content -LiteralPath $manualPlannerPath -Raw
$manualCli = Get-Content -LiteralPath $manualCliPath -Raw
$manualLauncher = Get-Content -LiteralPath $manualLauncherPath -Raw
Assert-True ([bool]$gate1Authorization.owner_approved -and $gate1Authorization.gate -eq 1 -and
             $gate1Authorization.root_sha256 -eq 'B59D8052C11D732503147210703C2DA0402106B0012A6DE5E7FC5346E099E6EF' -and
             $gate1Authorization.resume_run_id -eq 'G1-0120' -and
             $gate1Authorization.accepted_completed_count -eq 120 -and
             $gate1Authorization.candidate_budget_before -eq 1 -and
             $gate1Authorization.candidate_budget_transition -eq 'ALREADY_CONSUMED' -and
             -not [bool]$gate1Authorization.oos_authorized -and
             -not [bool]$gate1Authorization.holdout_authorized -and
             $gate1Authorization.maximum_children_per_batch -eq 2) 'authorization must bind only the exact Gate 1 root and two-child manual scope'
$invalidation = Get-Content -LiteralPath $invalidationPath -Raw | ConvertFrom-Json
$replacementRoot = Get-Content -LiteralPath $replacementRootPath -Raw | ConvertFrom-Json
$replacementIndex = Get-Content -LiteralPath $replacementIndexPath -Raw | ConvertFrom-Json
$replacementPacket = Get-Content -LiteralPath $replacementPacketPath -Raw | ConvertFrom-Json
$replacementStatus = Get-Content -LiteralPath $replacementStatusPath -Raw | ConvertFrom-Json
$replacementAuthorizedStatus = Get-Content -LiteralPath $replacementAuthorizedStatusPath -Raw | ConvertFrom-Json
Assert-True ($invalidation.status -eq 'INVALIDATED_PRESERVED_NOT_SELECTION_ELIGIBLE' -and
             -not [bool]$invalidation.replacement_may_reuse_results -and
             $invalidation.complete_frame_count -eq 978 -and
             $invalidation.tester_guard_refusal_count -eq 22 -and
             $invalidation.missing_configuration_ids.Count -eq 22 -and
             $invalidation.hard_failure_configuration_ids.Count -eq 2) 'failed child must remain invalidated, preserved, and unavailable to selection or replacement reuse'
Assert-True ($replacementRoot.root_sha256 -eq 'B59D8052C11D732503147210703C2DA0402106B0012A6DE5E7FC5346E099E6EF' -and
             $replacementRoot.candidate_budget_before -eq 1 -and
             $replacementRoot.candidate_budget_transition -eq 'ALREADY_CONSUMED' -and
             $replacementRoot.mt5_build -eq 6140 -and
             $replacementRoot.build_transition.parity_result_sha256 -eq '462B8DB87D53CD072360D21333ED33E5DC71053378E560F04BEB1891ABE5F7B6' -and
             $replacementRoot.build_transition.accepted_completed_count -eq 120 -and
             $replacementRoot.build_transition.resume_run_id -eq 'G1-0120' -and
             $replacementRoot.launch_count -eq 200 -and
             $replacementRoot.configuration_pass_count -eq 194400 -and
             -not [bool]$replacementRoot.owner_approved -and
             $replacementIndex.children.Count -eq 200 -and
             -not [bool]$replacementPacket.owner_approved -and
             $replacementPacket.resume_run_id -eq 'G1-0120') 'continuation root and approval packet must preserve the consumed budget and exact approved scope'
Assert-True ($replacementStatus.status -eq 'REPLACEMENT_ROOT_VERIFIED_AWAITING_OWNER_APPROVAL' -and
             $replacementStatus.candidate_budget_consumed -eq 1 -and
             -not [bool]$replacementStatus.prior_results_reusable -and
             $replacementStatus.launcher_state -eq 'OLD_ROOT_ONLY_FAIL_CLOSED_DO_NOT_RUN') 'pre-approval status must retain the invalidation, consumed budget, and historical launcher prohibition'
Assert-True ($replacementAuthorizedStatus.status -eq 'REPLACEMENT_GATE1_AUTHORIZED_MANUAL_FOREGROUND_ONLY' -and
             $replacementAuthorizedStatus.root_sha256 -eq '04AB5A4F1F2E078ACAEE0370ED23F22FB3C4FF872309231F69A2BFD5FF8BA795' -and
             $replacementAuthorizedStatus.authorization_file_sha256 -eq (Get-FileHash -Algorithm SHA256 -LiteralPath $historicalAuthorizationPath).Hash -and
             $replacementAuthorizedStatus.candidate_budget_before -eq 1 -and
             -not [bool]$replacementAuthorizedStatus.oos_authorized -and
             -not [bool]$replacementAuthorizedStatus.holdout_authorized) 'current governance status must bind the exact replacement authorization without broadening scope'
Assert-True ($manualPlanner.Contains('MAXIMUM_CHILDREN = 2') -and
             $manualPlanner.Contains('MAXIMUM_CHILD_HOURS = 3.75') -and
             $manualPlanner.Contains('COMPLETION_SEQUENCE_GAP') -and
             $manualPlanner.Contains('RESULT_FRAME_HARD_FAILURE')) 'manual planner must cap batches and fail closed on resume or result defects'
Assert-True ($manualLauncher.Contains('manual foreground batch') -and
             $manualLauncher.Contains('B59D8052C11D732503147210703C2DA0402106B0012A6DE5E7FC5346E099E6EF') -and
             -not [regex]::IsMatch($manualLauncher, '\b(Start-Job|Register-ScheduledTask|New-Service)\b')) 'launcher must remain foreground-only with no task, job, or service installation'
Assert-True ($manualCli.Contains('MT5_OR_TESTER_ALREADY_RUNNING') -and
             $manualCli.Contains('gate1_continuation_20260824_v2') -and
             $manualCli.Contains('gate1_execution_20260809_v2') -and
             $manualCli.Contains('ALREADY_CONSUMED_BUILD_CONTINUATION_AFTER_PARITY_PASS') -and
             $manualCli.Contains('DEMO2_ACCOUNT_IDENTITY_MISMATCH') -and
             $manualCli.Contains('KINGEA_SCHEDULED_TASK_PRESENT') -and
             $manualCli.Contains('TERMINAL_BUILD_MISMATCH') -and
             $manualCli.Contains('PREEXISTING_CHILD_SPOOL_REQUIRES_REVIEW')) 'manual execution adapter must recheck environment and preserve partial evidence'
Assert-True ((Get-Content -LiteralPath $eaCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'tester EA compile must be clean'
Assert-True ((Get-Content -LiteralPath $testCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'contract harness compile must be clean'
Assert-True ((Get-Content -LiteralPath $benchmarkCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'benchmark compile must be clean'
Assert-True ((Get-Content -LiteralPath $calendarCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'calendar exporter compile must be clean'
Assert-True ((Get-Content -LiteralPath $dateGateCompilePath -Raw).Contains('Result: 0 errors, 0 warnings')) 'date-gate tester compile must be clean'
Assert-True ($ea.Contains('InpEvaluationStart') -and $ea.Contains('InpEvaluationEndExclusive') -and
             $ea.Contains('if(!ResearchEvaluationEligible(evaluation_time))') -and
             $ea.Contains('g_evaluation_end_unresolved')) 'B2 tester must enforce explicit half-open evaluation gates and fail closed for unresolved end exposure'
Assert-True ($python.Contains('realize_partition_dates') -and
             $python.Contains('InpEvaluationStart') -and $python.Contains('InpEvaluationEndExclusive')) 'Stage 14 bundle must derive explicit date inputs from the immutable realization table'
Assert-True ((Get-Content -LiteralPath $dateGateReportPath -Raw).Contains('B2 = LOCKED')) 'date-gate report must retain the B2 lock'

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

Write-Output 'STAGE14_RESEARCH_READINESS_POLICY_PASS: build-6140 parity and 120-run archive inventory retained, continuation root exactly authorized from G1-0120 for bounded manual execution, consumed budget retained, and OOS/holdout denied.'
