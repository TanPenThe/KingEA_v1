# ETHUSD.s Feasibility Capture

This script is pre-freeze-authorized non-performance tooling. It cannot place, modify, or close trades and contains no signal, indicator, backtest-return, or optimizer logic.

## Install and run

1. In MT5, choose **File -> Open Data Folder**.
2. Copy `ExportSymbolFeasibility.mq5` into `MQL5\Scripts\KingEA\` under that data folder.
3. Open the file in MetaEditor and press **F7**. Compilation must complete with zero errors.
4. In MT5, refresh **Navigator -> Scripts**, then attach `ExportSymbolFeasibility` to any chart while logged into the dedicated JustMarkets account.
5. Set:
   - `InpSymbol = ETHUSD.s` (confirmed exact JustMarkets-Demo2 symbol);
   - `InpSnapshotLabel = NORMAL` for the first run;
   - `InpReferenceEquityUSD = 1000`;
   - `InpHMRLeverageReference = 200` only as an informational proxy.
6. Read the **Experts** journal for the exported path. The CSV is written under the terminal common folder: `Terminal\Common\Files\KingEA\`.
7. Run it again during an actual JustMarkets High Margin Requirements window with `InpSnapshotLabel = HMR`. The live `OrderCalcMargin` results from that run are authoritative; the theoretical HMR proxy is not.
8. Provide both CSV files for the feasibility audit.

Version 1.02 also writes `audit,hmr_snapshot_verification`. An HMR-labelled file is acceptable only when it reports `CONSISTENT_WITH_HMR_REFERENCE`; changing the input label alone does not activate HMR.

## Output scope

- Account currency, leverage, margin-call/stop-out configuration, and margin snapshot
- Contract, tick, volume, stops/freeze, swap, execution, and margin properties
- Current Bid/Ask and spread
- Buy/sell margin-rate factors
- Trading sessions by broker weekday/server time
- Available M1/M30/H4/D1 history boundaries
- Live `OrderCalcMargin` matrix for mechanically selected lot sizes
- Minimum-lot gross-loss matrix across neutral percentage price distances

The stop-risk matrix excludes commission, swap, and added slippage stress and is labelled accordingly. Those costs are layered into the subsequent feasibility report; the matrix must not be used as strategy performance evidence.

## Five-year history smoke test

`AuditHistoryAvailability.mq5` is a second read-only script. It checks whether the broker server appears to provide the five years required for crypto research. It inspects timestamps only and does not evaluate price movement or strategy performance.

1. Copy `AuditHistoryAvailability.mq5` into the same `MQL5\Scripts\KingEA\` data-folder directory.
2. Open it in MetaEditor and press **F7**. Compilation must complete with zero errors.
3. In MT5, refresh **Navigator -> Scripts** and attach `AuditHistoryAvailability` to the `ETHUSD.s` chart.
4. Keep the defaults: `InpSymbol = ETHUSD.s`, `InpYears = 5`, and `InpTickSampleMinutes = 60`.
5. Leave MT5 connected while it downloads history. The Experts tab prints progress for 60 monthly tick samples.
6. When complete, send the generated `history_smoke_ETHUSD.s_5Y_*.csv` from `Terminal\Common\Files\KingEA\` for review.

The script scans M30, H4, and D1 bar timestamps to the five-year boundary and samples one fixed one-hour real-tick window in each month. A pass means the required history appears available. It does **not** prove that every tick is continuous or suitable; full synchronization, gap checks, and “Every tick based on real ticks” validation remain mandatory before any candidate can pass the research pipeline.

## Targeted history-quality audit

Run `AuditHistoryQuality.mq5` after the availability smoke test passes. It maps every large M30 timestamp gap; queries the broker for real ticks inside each missing-bar interval; and checks the 60 fixed monthly tick samples for invalid quotes, reversed spreads, ordering errors, exact consecutive duplicates, and spread percentiles.

1. Copy and compile `AuditHistoryQuality.mq5` in the same Scripts directory.
2. Refresh **Navigator -> Scripts** and attach `AuditHistoryQuality` to the `ETHUSD.s` chart.
3. Keep the defaults: five years, M30, a gap threshold of two nominal bars, and 60-minute monthly samples.
4. Leave MT5 connected until the Experts tab reports completion.
5. Send the generated `history_quality_ETHUSD.s_5Y_*.csv` for classification.

`TICKS_PRESENT_BAR_GAP` is treated as a hard data anomaly. `NO_TICKS_QUOTE_GAP` requires manual comparison with maintenance or outage information. This is still a targeted audit rather than proof of complete five-year tick continuity; final Strategy Tester synchronization and full real-tick validation remain separate mandatory gates.

## Native spread-bracket evidence export

`AuditSpreadBracketEvidence.mq5` implements the strategy-blind method frozen in `governance/NATIVE_SPREAD_BRACKET_PROTOCOL.md`. It contains no trading or strategy-performance capability. It automatically refuses any server other than `JustMarkets-Live2` or `JustMarkets-Demo2`.

Run it twice with `InpSymbol = ETHUSD.s` and `InpExportRawReferenceSpreads = true`:

1. Log into the real Pro account on `JustMarkets-Live2`, attach the script to any chart, and wait for `Result: PASS`. This exports the fixed December 2024 through June 2026 Live2 reference distribution and verifies the previously audited USD 1.26 median.
2. Log into `JustMarkets-Demo2`, attach the same unchanged compiled script, and wait for `Result: PASS`. This exports the fixed July 2021 through May 2023 old-spread distribution and mechanically detects the May-June 2023 tick-level transition.
3. Send both generated `spread_bracket_evidence_ETHUSD.s_*.csv` files from `Terminal\Common\Files\KingEA\` to Codex.

The files may be larger than the earlier summaries because the raw sorted reference spreads are included for exact deterministic quantile mapping. Do not turn that input off for the manifest run. A failure or median mismatch is a review stop; do not change the frozen window sizes or threshold to force a pass.

## Build the native reduced-spread custom symbol

Run `BuildNativeReducedSpreadSymbol.mq5` only after both spread-evidence exports have passed and been accepted into the evidence manifest.

1. Copy and compile the script in the same `MQL5\Scripts\KingEA\` directory.
2. Log into `JustMarkets-Demo2`. The script refuses Live2 and unknown servers.
3. Keep the two accepted evidence CSV files in `Terminal\Common\Files\KingEA\` under their unchanged names.
4. Attach the script to any chart and set `InpAuthorizeLocalCustomSymbolBuild = true`. Keep every other input unchanged.
5. Leave MT5 connected. It copies the native Demo2 ticks from 2021-07-01 through 2026-06-30 in daily chunks, preserves every timestamp and Bid, and changes only Ask before the frozen `2023-06-03 14:10:08.062` boundary.
6. Send the resulting `native_reduced_build_KINGEA_ETHUSD_S_RSB1_*.csv` report to Codex.

Version 1.03 targets the new local custom symbol `KINGEA_ETHUSD_S_RSB3`. It first performs a complete read-only five-year source preflight before creating the target. Zero-spread native source ticks are accepted: before the frozen boundary they map mechanically to the Live2 minimum spread, as the registered below-range clamping rule requires; at and after the boundary they remain unchanged. The two exact registered asynchronous crossed snapshots are preserved; MT5 has been proven to normalize only their flags. Any additional or changed reversed spread and every other invalid-source condition hard-fails.

RSB3 uses `CustomTicksReplace` for each historical day. `CustomTicksAdd` is prohibited for bulk history after RSB2 proved that it silently lost data with a 128-tick buffer pattern. Every replaced day is immediately read back; its count and all non-flag fields must match before the builder proceeds to the next day.

The script never deletes or overwrites an existing populated symbol. `KINGEA_ETHUSD_S_RSB1` and `KINGEA_ETHUSD_S_RSB2` are known failed artifacts and are prohibited. This build may take additional time because it scans five years once for preflight, constructs it, and immediately verifies every daily replacement. It cannot place trades and does not run strategy logic.

### Failed RSB1 diagnostic

The first RSB1 build stopped during the 2022-11-27 broker-day batch after 61,400,668 ticks had already been added. Do not rerun RSB1 or delete it. Run `DiagnoseNativeBuildFailure.mq5` on `JustMarkets-Demo2` with its unchanged default symbol. It scans only the exact failing day, does not create or modify a custom symbol, and writes `native_build_failure_diagnostic_ETHUSD.s_*.csv`. Send that report to Codex before any builder correction or RSB2 attempt.

### RSB2 reversed-spread preflight diagnostic

RSB2 preflight correctly stopped before target creation on a crossed quote at epoch milliseconds `1709374488223` (`2024-03-02 10:14:48.223` broker time). Do not weaken the reversed-spread invariant or rerun the full builder yet. Run `DiagnoseReversedSpread.mq5` unchanged on `JustMarkets-Demo2`; it scans only 2024-03-02 and exports every reversed quote with three neighboring ticks on both sides. Send the resulting `reversed_spread_diagnostic_ETHUSD.s_*.csv` for classification.

The focused diagnostic found two isolated one-sided crossed updates, each restored to a positive spread about 0.2 seconds later. Before changing the builder, run `ProbeCrossedTickRoundTrip.mq5` on Demo2 with `InpAuthorizeLocalProbe=true`. It creates only `KINGEA_DIAG_CROSSED_V1`, attempts to store the two exact captured ticks, reads them back, and compares every material tick field. It never touches RSB1/RSB2 and cannot trade or delete data. Send `crossed_tick_roundtrip_KINGEA_DIAG_CROSSED_V1_*.csv` to Codex.

The probe accepted both ticks and preserved their timestamp, Bid, and Ask, but its aggregate exact comparison failed after MT5 normalized flags to `6`. Run `CompareCrossedTickFields.mq5` unchanged on Demo2. It is read-only and compares `time_msc`, `time`, Bid, Ask, last, integer volume, real volume, flags, and spread for both stored ticks. Send `crossed_tick_field_comparison_*.csv` before any governance change or RSB2 rerun.

## Verify the completed RSB2 dataset

After an RSB3 build PASS, run verifier version 1.02 (`Build ID: RSB3-VERIFY-20260723-B`) on `JustMarkets-Demo2` with all defaults unchanged. It targets `KINGEA_ETHUSD_S_RSB3` and compares the complete 327,417,608-tick origin/custom datasets in daily chunks. It independently recalculates every pre-boundary mapped Ask, requires exact post-boundary Ask and all timestamp/Bid/last/volume fields, verifies daily counts, requires the deterministic MT5 persistence rule `stored_flags = origin_flags with bit 128 cleared`, and produces two independent canonical 64-bit field fingerprints. Any other flag change fails. Send `native_reduced_verify_KINGEA_ETHUSD_S_RSB3_*.csv` to Codex. Do not switch to Live2 and do not run strategy tests yet.

The accepted RSB3 verification report is `native_reduced_verify_KINGEA_ETHUSD_S_RSB3_2026.07.23_15-48-05.csv`, SHA-256 `311F232414C5EC7AF898826F0C834DA091B8DD7A2BB9C427467A7B777C37BCE8`. It passed all 327,417,608 ticks with zero non-flag mismatches and zero invalid flag normalizations. RSB3 construction is complete; do not rebuild it. Candidate performance testing remains locked until Strategy Tester reconciliation is completed and `CAND-ETH-ST-001` is formally frozen.

## Strategy Tester real-tick reconciliation

`MQL5/Experts/KingEA/ReconcileTesterRealTicks.mq5` is a non-trading Expert Advisor used only to prove that Strategy Tester replays the registered tick stream exactly. It refuses to initialize outside Strategy Tester, contains no order or indicator APIs, and compares the `OnTick` replay against `CopyTicksRange` using exact counts, boundaries, ordering, and two independent market-field fingerprints.

For the first smoke pair, select **Every tick based on real ticks**, M30, and the custom date range 2021.07.01 through 2021.07.02:

1. Native run: symbol `ETHUSD.s`; label `DEMO2_ORIGIN_20210701`; expected symbol `ETHUSD.s`; expected ticks `173712`.
2. Reduced run: symbol `KINGEA_ETHUSD_S_RSB3`; label `RSB3_REDUCED_20210701`; expected symbol `KINGEA_ETHUSD_S_RSB3`; expected ticks `173712`.

Keep the input window exactly `2021.07.01 00:00:00` inclusive through `2021.07.02 00:00:00` exclusive. Run on JustMarkets-Demo2 and send both `tester_tick_reconciliation_*.csv` reports to Codex. These are infrastructure checks, not strategy backtests, and do not consume the candidate budget or authorize performance testing.

Do not type tester inputs manually. Load the matching file from `MQL5/Profiles/Tester/KingEA`:

- `tester_recon_demo2_origin_20210701_warmup.set`
- `tester_recon_rsb3_reduced_20210701_warmup.set`

The `.set` file controls Expert Advisor inputs only. Symbol, timeframe, modeling mode, tester date range, and account remain Strategy Tester UI settings; use `tester_recon_run_matrix.csv` as the authoritative companion checklist. The RSB3 set remains blocked until custom-bar readiness is diagnosed and corrected.

## Final RSB3 manifest gate

Run `ValidateRSB3ManifestGate.mq5` only on `JustMarkets-Demo2`, with its defaults unchanged. It is read-only and performs a fresh full-population comparison of native `ETHUSD.s` and `KINGEA_ETHUSD_S_RSB3`, so it may take several minutes.

The gate requires all 327,417,608 ticks, the two exact registered crossed quotes and no others, deterministic pre-boundary Ask mapping, unchanged post-boundary Ask, exact non-flag fields, and `stored_flags = origin_flags & 0xFFFFFF7F` on every persisted tick. It also exports native Demo2 M30 Bid bars from `[2021-04-01, 2021-07-01)` for indicator warm-up and requires at least 95% coverage with both terminal boundaries present. The validator never mutates custom history and contains no order, signal, indicator, return, or optimizer capability.

Send both final Journal lines and the generated `rsb3_manifest_gate_*.csv` path to Codex. Candidate performance testing remains prohibited. The Python finalizer in `data_pipeline/manifest_gate.py` independently hashes the original 400,437-quote sampled audit, parses all 60 half-open sample windows, proves both crossed timestamps are outside them, and refuses to create the accepted V2 manifest unless every MT5 and sampling gate passes.

## Candidate 001 contract test

`TestCandidateEthSt001.mq5` is a deterministic, history-free test of the pure `CandidateEthSt001.mqh` intent module. Run it on Demo2 with no inputs. The required Journal result is `CANDIDATE_CONTRACT_TEST_PASS: failures=0`. It does not access history, calculate performance, size volume, or submit orders.

## Stage 11 frozen Sleeve 1 contract

`TestSleeveEthSt001.mq5` exercises the public `SleeveEthSt001.mqh` interface
using generated closed-bar fixtures only. Load
`config/sleeve_eth_st_001_contract_run.ini` or run the script with Algo
Trading and DLL imports disabled. The required result is
`SLEEVE_ETH_ST_001_TEST_PASS` with 33 checks and zero failures.

This contract run validates the frozen parameter grid, internal M30/H4
Supertrend and breakout derivation, Stage 10 regime mapping, closed-bar
position progress, signal expiry, and fail-closed input handling. It reads no
broker history, calculates no returns, sizes no volume, and cannot place or
modify orders.

## Stage 12 guarded research pipeline

`TestResearchPipeline.mq5` exercises only the pure `ResearchExecution.mqh`
contract with synthetic facts. Run it through
`config/research_pipeline_contract_run.ini`; live trading and DLL imports are
disabled and MT5 closes automatically. The required result is
`STAGE12_RESEARCH_CONTRACT_PASS` with seven checks and zero failures.

`GuardedResearchTester.mq5` is compiled but must not be run until a separate
governance action creates an authorized content-addressed development
manifest. It refuses non-tester execution and revalidates the manifest and
detached token before its sole order seam. The offline commands live in
`python -m research_pipeline.cli`; the checked-in tester INI is a placeholder
template and is intentionally non-runnable. Stage 12 construction authorizes
no development, OOS, holdout, demo-order, or Live2 run.

## Stage 13 accounting and reconciliation

`TestAccountingLedger.mq5` exercises the pure `AccountingEvents.mqh` contract
with synthetic facts. Run it through `config/accounting_contract_run.ini`;
live trading and DLL imports are disabled and MT5 closes automatically. The
required result is `KINGEA_STAGE13_ACCOUNTING_CONTRACT: result=PASS` with eight
checks and zero failures.

`ExportAccountingHistory.mq5` is a separate read-only Demo2 adapter. It may
read orders, deals, and current inventory but cannot submit, modify, close, or
cancel anything. Its output contains an account fingerprint, never the raw
login. Do not run it on Live2 or use it to authorize trading.

The guarded research tester now emits versioned accounting event frames and a
completion root while retaining the Stage 12 legacy summary as an exact
cross-check. No Stage 14 result-bearing run is authorized by this change.

## Shared safety-kernel contract test

`TestSafetyKernel.mq5` exercises the sole pure interface in
`MQL5\Include\KingEA\SafetyKernel.mqh`. It uses synthetic account, sleeve,
broker, margin, spread, and recovery facts; it does not read market history,
calculate returns, expose OOS/holdout data, or submit orders.

The governed automated run uses `config\safety_kernel_contract_run.ini`, which
sets `AllowLiveTrading=0`, starts the script on `ETHUSD.s` M30, and closes MT5
when the script completes. The required Journal result is
`SAFETY_KERNEL_TEST_PASS` with zero failures. The script also writes
`Terminal\Common\Files\KingEA\safety_kernel_contract_*.csv`.

This test authorizes no strategy or performance run. It validates only
deterministic safety-policy behavior.

## Stage 7 operational safety contract

`TestOperationalSafety.mq5` exercises the non-trading persistence,
configuration-versioning, broker-reconciliation, and heartbeat interfaces. Run
it with `config\operational_safety_contract_run.ini`; live trading and DLL
imports are disabled and MT5 closes after the script.

The independent watchdog implementation is in `operations\KingEAWatchdog.ps1`
with its policy module in `operations\KingEAWatchdog.psm1`. Its governed Demo2
configuration is `config\watchdog.demo2.disabled.json`: `Enabled=false` and
`InstallScheduledTask=false`. Do not enable or install it until the integrated
Demo2 EA heartbeat exists and a later governance gate authorizes activation.

`operations\Set-KingEAStanddown.ps1` is the independent kill-switch interlock.
It creates a persistent manual-standdown latch that the watchdog checks on every
poll and immediately before any restart. The EA and watchdog may never clear
that latch.

## RSB3 M1 bar readiness

`BuildRSB3MinuteBars.mq5` derives M1 bars solely from the already accepted RSB3 ticks. Its default blank authorization token is read-only: it scans the complete five-year dataset, derives M1 and M30 bars, and requires the derived M30 time/OHLC/tick-volume/minimum-positive-spread/real-volume fields to match the existing M30 series exactly. Crossed or zero instantaneous spreads remain preserved in tick Bid/Ask data but are excluded from bar spread metadata, matching MT5's observed aggregation. The expected tick total remains fixed at 327,417,608.

Only the exact authorization token documented in governance permits M1 `CustomRatesReplace`. Even then, full preflight runs before the first write. Each written day is immediately read back, its M30 aggregation is rechecked, and the tick count plus two market-field fingerprints must remain unchanged. The tool contains no `CustomTicks*`, trading, strategy, or indicator API.

Verifier 1.01 proved exact counts, zero non-flag mismatches, and matching expected/stored fingerprints, but failed because persisted MT5 custom history rewrote flags broadly. Run `DiagnosePersistedFlagNormalization.mq5` unchanged on Demo2. It maps every origin-to-stored flag pair on one transformed day and one unchanged day while rechecking count and non-flag alignment. Send `persisted_flag_normalization_*.csv`; do not rerun the full verifier yet.

### Partial-read diagnostic after verifier v1.00

Verifier v1.00 exposed a sharp read transition: origin-minus-128 daily counts through 2023-09-10 and exactly 128 custom ticks per day afterward. Do not rebuild or delete RSB2. Run `DiagnoseCustomTickRetention.mq5` unchanged on Demo2. It repeatedly reads one early day and the first affected day as full-day, half-day, and hourly ranges, recording counts, errors, latency, and returned boundaries. Send `custom_tick_retention_diagnostic_*.csv` before any verifier or dataset-policy change.

The retention diagnostic proved the missing ranges are not a read-cache artifact. To test the correct historical API, run `ProbeCustomTicksReplace.mq5` on Demo2 with `InpAuthorizeLocalProbe=true`. It creates only `KINGEA_DIAG_REPLACE_V1`, writes the complete native ticks for 2021-07-01 and 2023-09-11 using `CustomTicksReplace`, and checks exact counts, boundaries, and all non-flag fields. Send `custom_ticks_replace_probe_KINGEA_DIAG_REPLACE_V1_*.csv`. Do not delete or rebuild RSB1/RSB2 yet.

## Stage 8 specification monitor

`TestSpecificationMonitor.mq5` exercises the pure, deterministic
`SpecificationMonitor.mqh` interface. It uses synthetic specifications and
contains no broker calculators or order capability. Run it only with
`config\specification_monitor_contract_run.ini`; the required result is
`KINGEA_STAGE8_TEST_RESULT=PASS`.

`ObserveSpecificationMonitor.mq5` is the separate read-only MT5 adapter
exercise. Its configuration requires `JustMarkets-Demo2`, disables live
trading and DLL imports, and closes MT5 afterward. The script uses
`OrderCalcProfit` and `OrderCalcMargin` only as calculators and writes a
non-deployable `stage8_spec_observation_*.csv`.

The resulting Demo2 manifest remains `PENDING_OWNER_REVIEW`. Do not rename it
as approved, copy it to Live2, or use it to authorize entries. A Live2 baseline
must be captured and approved separately at a later live-deployment gate.
