# KingEA Candidate Registry — Append Only

Do not edit or delete existing records. Corrections are appended as new records referencing the original record ID.

## GOV-20260721-001

- Timestamp: 2026-07-21T11:43:49+08:00
- Type: Governance freeze
- Status: ACTIVE
- Decision: Candidate pre-registration is mandatory under `CANDIDATE_FREEZE_PROTOCOL.md`.
- Performance-test authorization: DENIED until a complete candidate record is appended with status `FROZEN`.
- Permitted pre-freeze work: broker/symbol specification capture, minimum-lot and margin feasibility, data-quality inspection, infrastructure, safety-kernel, persistence, watchdog, and kill-switch drills that do not evaluate strategy profitability.
- First reserved candidate namespace: `CAND-ETH-ST-001`
- Reserved concept: M30 `ETHUSD.s` Supertrend/ATR trend-family Sleeve 1.
- Candidate status: NOT FROZEN; logic and parameter ranges remain unregistered.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.

- Reason: Prevent hypothesis drift and optimizer/OOS leakage before research starts.

## GOV-20260721-002

- Timestamp: 2026-07-21T11:51:17+08:00
- Type: Pre-freeze tooling event
- Status: COMPLETE
- Artifact: `MQL5/Scripts/KingEA/ExportSymbolFeasibility.mq5`
- Scope: Read-only/non-trading export of live symbol, account, session, margin, history-availability, minimum-lot, and neutral stop-distance feasibility properties.
- Boundary: No indicators, signals, historical return calculations, expectancy, win rate, ATR-multiplier comparison, parameter ranking, optimizer, or order submission.
- Static verification: MetaEditor build completed with 0 errors and 0 warnings.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-003

- Timestamp: 2026-07-21T12:02:00+08:00
- Type: Pre-freeze tooling revision
- Status: COMPLETE
- Artifact: `MQL5/Scripts/KingEA/ExportSymbolFeasibility.mq5`
- Change: Increased the defensive per-day session scan ceiling from 20 to 64, exported the discovered session count, and added an explicit truncation warning if the ceiling is reached.
- Source SHA-256: `12C8B36469585F7B1AA80E18789DE023436E25BFB2FF75B9BA202DFFBB8E75FA`
- Static verification: MetaEditor build completed with 0 errors and 0 warnings.
- Trading/strategy capability change: NONE.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-004

- Timestamp: 2026-07-21T12:26:35+08:00
- Type: Pre-freeze feasibility snapshot
- Status: NORMAL SNAPSHOT CAPTURED; HMR SNAPSHOT PENDING
- Broker/server: JustMarkets-Demo2 / Just Global Markets Ltd.
- Exact symbol: `ETHUSD.s` (replaces the provisional `ETHUSD.m` name in project documents).
- Source file: `feasibility_ETHUSD.s_NORMAL_2026.07.21_04-25-00.csv`
- Source SHA-256: `FC04688A83052B738F16ED345B5570A2DB7FB8D7B04747B617A4777A09C1B219`
- Scope: Non-performance account, symbol, session, margin, local-history availability, and neutral stop-distance feasibility.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE; locally cached history boundaries were read without strategy evaluation.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-005

- Timestamp: 2026-07-21T14:22:13+08:00
- Type: Pre-freeze HMR capture attempt
- Status: INCONCLUSIVE — LABELLED HMR BUT LIVE MARGIN REMAINED NORMAL
- Source file: `feasibility_ETHUSD.s_HMR_2026.07.21_06-20-47.csv`
- Source SHA-256: `DF88D170CA56642D3048495BED892E778665DCB1A48BD02E9181C3982C66C133`
- Evidence: Buy/sell margin rate remained 0.002 (1:500) and 0.01-lot `OrderCalcMargin` remained USD 0.04, matching the NORMAL snapshot rather than the expected approximately USD 0.096 at 1:200.
- Interpretation: HMR was not active, was not applied to this demo symbol/account, or was not reflected by the server calculator at capture time. The input label is not evidence of HMR.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.

## GOV-20260721-006

- Timestamp: 2026-07-21T14:23:05+08:00
- Type: Pre-freeze tooling revision
- Status: COMPLETE
- Artifact/version: `ExportSymbolFeasibility.mq5` v1.02
- Change: Added live effective-leverage proxy and automatic HMR-reference consistency verdict for HMR-labelled captures.
- Source SHA-256: `75590149A4CC56A25B1BD23537834D0439A9F1E45E67D114F30A41198A26F4ED`
- Static verification: MetaEditor build completed with 0 errors and 0 warnings.
- Trading/strategy capability change: NONE.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.

## GOV-20260721-007

- Timestamp: 2026-07-21T20:13:55+08:00
- Type: Pre-freeze history-availability tooling event
- Status: BUILT, VERIFIED, AND INSTALLED; BROKER-SERVER RUN PENDING
- Artifact/version: `MQL5/Scripts/KingEA/AuditHistoryAvailability.mq5` v1.00
- Scope: Five-year M30/H4/D1 timestamp-boundary scan plus one fixed one-hour real-tick presence sample per month for `ETHUSD.s`.
- Boundary: Availability smoke test only. No orders, indicators, signals, OHLC analysis, historical returns, expectancy, win rate, strategy parameters, ranking, or optimization.
- Interpretation: A pass establishes only that the requested history appears available. It does not establish complete tick continuity, data quality, or strategy performance.
- Source SHA-256: `CE737F0EEFE2BC9F86F40ADD875F92122B38B5C72D6C40F23D25033E999C0139`
- Static verification: MetaEditor build completed with 0 errors and 0 warnings; no order-submission or strategy APIs found.
- Installation: Compiled source and executable placed in the active MT5 terminal's `MQL5/Scripts/` directory.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE; only timestamp availability will be inspected.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-008

- Timestamp: 2026-07-21T20:15:30+08:00
- Type: Pre-freeze HMR capture attempt
- Status: CONCLUSIVE NORMAL-MARGIN OBSERVATION; NOT HMR EVIDENCE
- Source file: `feasibility_ETHUSD.s_HMR_2026.07.21_12-15-30.csv`
- Source SHA-256: `1EF726D64CA5464242F8D118BA942550552EACC64927F49F89B3CCC59D855237`
- Evidence: Buy/sell margin rate remained 0.002, 0.01-lot `OrderCalcMargin` remained USD 0.04, effective leverage proxy was approximately 1:484, and the automated verdict was `NOT_CONSISTENT_WITH_HMR_REFERENCE`.
- Interpretation: HMR was not active, was not applied to `ETHUSD.s` on this demo account, or was not reflected by the server calculator at capture time. The `HMR` input label is not broker evidence.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-009

- Timestamp: 2026-07-21T20:20:07+08:00
- Type: Pre-freeze history-availability smoke-test result
- Status: PASS WITH DATA-QUALITY FOLLOW-UP REQUIRED
- Source file: `history_smoke_ETHUSD.s_5Y_2026.07.21_12-15-54.csv`
- Source SHA-256: `99E5F61EC2DACFFE094B02FD80569345925DF602C269C5084FBEEC964185940C`
- Boundary evidence: M30, H4, and D1 timestamps reached the requested 2021-07-21 boundary; broker server-first date reported as 2019-05-16; all four inspected series reported synchronized after download.
- Tick evidence: 60/60 fixed monthly one-hour real-tick samples contained data, totaling 400,437 ticks; sample range was 1,401 to 19,085 ticks per hour.
- Follow-up: M30 contained 45 gaps longer than one hour, maximum eight hours. Map and classify exact gaps during the full tick-history/data-quality audit before candidate freeze.
- Interpretation: Five-year apparent data availability passes. Complete continuity, spread realism, duplicates, contract-history consistency, and research fitness are not yet accepted.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE; timestamps and tick presence only were inspected.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-010

- Timestamp: 2026-07-21T20:31:00+08:00
- Type: Pre-freeze targeted history-quality tooling event
- Status: BUILT, VERIFIED, AND INSTALLED; BROKER-SERVER RUN PENDING
- Artifact/version: `MQL5/Scripts/KingEA/AuditHistoryQuality.mq5` v1.00
- Scope: Maps large M30 timestamp gaps; queries real ticks inside each missing-bar interval; and audits 60 fixed monthly tick windows for invalid quotes, reversed spreads, ordering anomalies, exact consecutive duplicates, and spread percentiles.
- Boundary: Targeted quote and timestamp quality only. No orders, indicators, signals, OHLC analysis, returns, expectancy, win rate, strategy parameters, ranking, or optimization.
- Source SHA-256: `72BCD49F3A2E3C87AF9A62550088ACA5031CF4856426311A365F8599E6729283`
- Static verification: MetaEditor build completed with 0 errors and 0 warnings; no order-submission or strategy APIs found.
- Installation: Compiled source and executable placed in the active MT5 terminal's `MQL5/Scripts/` directory.
- Limitation: This targeted audit does not establish complete five-year tick continuity; full Strategy Tester synchronization and real-tick validation remain mandatory.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-011

- Timestamp: 2026-07-21T21:28:01+08:00
- Type: Pre-freeze targeted history-quality result
- Status: PASS TARGETED TECHNICAL CHECKS; MANUAL BROKER-HISTORY REVIEW REQUIRED
- Source file: `history_quality_ETHUSD.s_5Y_2026.07.21_13-28-01.csv`
- Source SHA-256: `96AD33D6F51D61FF9411E0E1BB6012132B0FD4BC534FD7B596E91B32ABA6FA9B`
- Clean evidence: 87,488 ordered M30 timestamps; 60/60 monthly tick samples; 400,437 valid sampled spreads; zero invalid quotes, reversed spreads, ordering errors, exact consecutive duplicates, or gap-query errors.
- Gap evidence: 45 no-tick quote gaps totaling 127 missing M30 slots; no gap contained real ticks; 28 used the recurring Friday 23:30 to Saturday 01:00 server-time pattern.
- Material obstacle: Monthly median sampled spread was approximately USD 23.5–26.5 from July 2021 through May 2023; it abruptly fell to USD 0.46 in June 2023 and remained materially lower afterward. Broker confirmation or independent reconciliation is required before treating both regimes as comparable executable Pro-account history.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-012

- Timestamp: 2026-07-21T21:40:00+08:00
- Type: External broker-data clarification
- Status: DEMO HISTORY LIMITATION CONFIRMED; RESOLUTION REQUIRED
- Source: JustMarkets support response supplied by the owner.
- Confirmed: `.s` denotes Pro-account instruments; Demo2 uses simulated liquidity and internally processed trades; quotes are only intended to be as close as possible to real conditions; historical demo spreads are not guaranteed executable Pro-account history.
- Unresolved: Support could not confirm a June 2023 ETHUSD feed/spread/specification change and could not classify the 2022–2023 historical gaps.
- Decision: Demo2 history alone cannot satisfy executable-cost data acceptance. Preferred next evidence is the same read-only audit on a live Pro server. A versioned custom-symbol dataset with conservative documented costs is a fallback only if live-server history is unavailable or inadequate.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-013

- Timestamp: 2026-07-21T21:46:43+08:00
- Type: Live Pro server specification and history reconciliation
- Status: LIVE SPECIFICATION CONFIRMED; RECENT TICKS VALIDATED; FIVE-YEAR LIVE TICKS INCOMPLETE
- Server/account: `JustMarkets-Live2`; real Pro account; zero balance; leverage 1:500.
- Source hashes: feasibility `7D7134EFB4A4ADDB5AE0EF44D4C4E87C59F68C1B8611D2511F15462F5D2DE041`; smoke `809F9E804D3FB6B06E3EA2B40F7226EDF305BD33D779237C4E9C90B42B370AE8`; quality `22978522FCC6CF12C6B2E5BB3F6B2EFE7EE3BE67E4D7A16F899530A02804B50F`.
- Specification evidence: Contract size, volume floor/step, tick value, swaps, 0.002 margin rate, and USD 0.04 minimum-lot margin match Demo2.
- History evidence: Five-year bar boundary passed but only 19/60 monthly real-tick samples were available; first successful fixed sample was 2024-12-16.
- Cross-server evidence: All 19 overlapping Live2/Demo2 samples have exactly matching median, P99, and maximum spreads. This validates the recent Demo2 regime but not pre-December-2024 history.
- Anomaly: 14 real ticks occur inside one missing M30 interval on 2026-02-22; final manifest/tester reconciliation must exclude or explicitly handle it.
- Decision: Live2 recent real ticks are authoritative; older Demo2 ticks are stress evidence only. Independent five-year price-path reconciliation and a frozen conservative cost model are required before candidate freeze.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-014

- Timestamp: 2026-07-21T22:00:00+08:00
- Type: Independent data-source selection and tooling preparation
- Status: DRAFT MANIFEST AND IMPORT PIPELINE VERIFIED; RAW DOWNLOAD PENDING
- Source decision: Binance Spot `ETHUSDT` aggregate trades primary; Coinbase Exchange `ETH-USD` 15-minute candles secondary; Kraken `ETH/USD` optional tertiary; JustMarkets-Live2 recent ticks authoritative broker evidence; Demo2 retained only as unchanged adverse simulation.
- Fixed draft coverage: 2021-07-01 UTC inclusive through 2026-07-01 UTC exclusive; 60 completed calendar months.
- Draft partitions: development/walk-forward through 2023-12-31; formal OOS calendar 2024; untouched holdout 2025-01-01 through 2026-06-30.
- Manifest SHA-256: `858E2583F3D36EBC9143CC654A2DBDC91B6B391F101AEC07CEFA42B6FFFB3BD4`.
- Downloader/normalizer SHA-256: `A28C496B0BECCB8631806175E78B3415DC710A490FB60C03CD15BB9A3ED233A5`.
- MT5 importer SHA-256: `98A7495C63E5012446F687DA9CCCEA61FED346C61A5A605552019A2C558679B1`.
- Verification: Offline plan generated 60 monthly targets; Python compile and four deterministic tests passed; MT5 importer compiled with 0 errors and 0 warnings; static prohibited-capability scan clean.
- Obstacle: Network authorization was declined; no raw exchange artifact has been downloaded or accepted. Cost model remains draft pending live relative-spread audit.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-015

- Timestamp: 2026-07-21T22:10:00+08:00
- Type: Data-source architecture decision
- Status: EXTERNAL-VENUE STRATEGY DATASET REJECTED
- Owner rationale: Binance, Coinbase, Kraken, and JustMarkets have different prices, tick ordering, candle extremes, spreads, and liquidity. Applying the JustMarkets strategy to another venue can create mismatched signals and fills.
- Decision: Only native JustMarkets `ETHUSD.s` server data may generate candidate signals, trades, returns, optimizer scores, OOS results, holdout results, or acceptance metrics.
- Demo role: Unchanged JustMarkets-Demo2 five-year history may be used as simulated long-horizon research/adverse stress and must not be represented as executable live history.
- Live role: Available JustMarkets-Live2 real ticks are authoritative recent execution and final-holdout evidence.
- External role: Exchange data is optional gross anomaly reference only and may never rescue or validate the candidate through a synthetic/custom symbol.
- Prepared external manifest/importer: Retained as an abandoned auditable record; no raw exchange files were downloaded; execution is not authorized.
- Superseding reference-only manifest SHA-256: `E03ED29F9F6EB6DFE2497BAEB24EEAC08384A8B8887B8FFA05AC08DBB050DDF5`.
- Disabled-by-default importer SHA-256: `EB433806314B522BEFF97EDBAA07239D5E9B48340C8D669CA5D02655C94B3F45`; MetaEditor verification remains 0 errors and 0 warnings.
- If broker-native evidence is insufficient: Reject the candidate, wait for more live evidence, or separately register a different broker/symbol deployment.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260721-016

- Timestamp: 2026-07-21T22:25:00+08:00
- Type: Broker-native history acceptance decision
- Status: OPTION 1 ACCEPTED WITH MANDATORY TWO-BRANCH SPREAD SENSITIVITY
- Decision: Unchanged JustMarkets-Demo2 five-year ticks are sufficient for long-horizon edge research when combined with authoritative recent Live2 evidence and all existing stress/demo/live gates.
- Regime rationale: The uncertain 2021–2023 segment contains essential bull, crash, and chop coverage and may not be removed because of spread uncertainty.
- Branch A: Unchanged recorded Demo2 Bid/Ask ticks; binding punitive-cost evidence.
- Branch B: Same Demo2 Bid timestamps and price path; Ask/spread alone reduced within one exact pre-registered anomalous window using a fixed formula derived from Live2 cost evidence.
- Decision rule: Both branches must pass; results are never averaged; Branch B cannot rescue Branch A; failure only in Branch B also rejects because it reveals dependence on the high-spread veto.
- Required freeze caveat: Demo2 anomalous-window spread authenticity is unverified; recorded spreads are conservative; the reduced branch tests conclusion sensitivity.
- Pending non-performance work: Determine the exact tick-level spread discontinuity; measure Live2 relative spread; freeze the transformation formula; hash the derived sensitivity dataset/configuration.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-017

- Timestamp: 2026-07-22T09:03:41+08:00
- Type: Native spread-bracket method pre-registration
- Status: METHOD FROZEN; EVIDENCE EXPORT AND MANIFEST PENDING
- Boundary method: Demo2 search from 2023-05-01 through 2023-06-30 broker time; trailing 1,001-valid-tick median; threshold is the geometric midpoint of the fixed Demo2 old-regime median and audited Live2 median USD 1.26; require 1,001 consecutive qualifying rolling medians; register the first tick of the confirmed sequence.
- Transformation: Deterministic monotonic quantile mapping from fixed Demo2 2021-07 through 2023-05 monthly samples to fixed Live2 2024-12 through 2026-06 monthly samples; nearest-rank quantiles; mapped spread rounded upward to the symbol point; Bid/timestamp path unchanged.
- Fixed sample: One 60-minute window beginning at 12:00 broker time on day 15 of each month, moved forward to Monday when day 15 is a weekend.
- Decision rule: Both unchanged and reduced branches must pass independently; no averaging and no rescue.
- Governing protocol: `governance/NATIVE_SPREAD_BRACKET_PROTOCOL.md`.
- Protocol SHA-256: `8804CFC52D9169A33FE235B4898C6C9F8C53C75CE5839A314ECDBFDCF484B014`.
- Read-only evidence exporter: `MQL5/Scripts/KingEA/AuditSpreadBracketEvidence.mq5`; SHA-256 `ED86D6498C79D207748B6769677068E101337BEAE5BF43C6F6F81454DE3F2013`; MetaEditor result 0 errors and 0 warnings.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-018

- Timestamp: 2026-07-22T09:11:55+08:00
- Type: Native spread-bracket evidence acceptance
- Status: EVIDENCE PASSED; DERIVED DATASET AND INVARIANTS PENDING
- Live2 evidence: PASS; 19 fixed monthly windows; 156,919 valid raw spreads; median USD 1.26 reproduced; source SHA-256 `E734D060C0F78EED706ED373B2B8DD1252A9CA547A8935F8733C5C44146CE2DA`.
- Demo2 evidence: PASS; 23 fixed monthly windows; 128,479 valid raw spreads; old-regime median USD 23.76; source SHA-256 `6037C428FA8A80EA4A9F60662DEDFA294FBC624AE9E0DED5986CDD85665A32CD`.
- Boundary result: PASS after 5,524,493 valid search ticks and zero invalid ticks; geometric threshold USD 5.47; registered boundary `2023-06-03 14:10:08.062` broker time / `1685801408062` epoch milliseconds.
- Registered native dataset coverage: 2021-07-01 inclusive through 2026-07-01 exclusive; development/rolling walk-forward through 2023-12-31; formal OOS calendar 2024; untouched holdout 2025-01-01 through 2026-06-30.
- Evidence manifest: `data/manifest/KINGEA_ETH_NATIVE_SPREAD_BRACKET_EVIDENCE_V1.json`; SHA-256 `D533082D934940BBE94B7C1F8025E4CA83E1C990D2C25F3CB275E6A5C1C0EFD9`.
- Pending: Build and hash the reduced native dataset; prove timestamp/Bid identity and Ask-only transformation; preserve registered gaps; reconcile both branches in Strategy Tester.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-019

- Timestamp: 2026-07-22T09:15:13+08:00
- Type: Native reduced-spread dataset tooling
- Status: BUILDER VERIFIED; OWNER EXECUTION PENDING
- Builder: `MQL5/Scripts/KingEA/BuildNativeReducedSpreadSymbol.mq5`; SHA-256 `7F59FE4200D2A98E71293A813B6630421A3D9A382FB8A6B90A6B7E5BF60767E1`; MetaEditor result 0 errors and 0 warnings.
- Safety: No trading, signal, indicator, return, optimizer, delete, or overwrite capability. It refuses non-Demo2 servers, requires explicit local-build authorization, validates both accepted evidence distributions, and refuses a populated target symbol.
- Fixed target: Local custom symbol `KINGEA_ETHUSD_S_RSB1`, cloned from Demo2 `ETHUSD.s` specifications.
- Fixed transformation: 2021-07-01 through 2026-06-30 native ticks; timestamp/Bid unchanged; deterministic Ask quantile mapping strictly before boundary epoch milliseconds `1685801408062`; recorded Ask unchanged thereafter.
- Same-millisecond tick ordering is explicitly preserved; only backward timestamps fail the build.
- Performance-test authorization: REMAINS DENIED pending completed build report, independent branch-invariant verification, dataset fingerprints/hashes, and Strategy Tester reconciliation.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-020

- Timestamp: 2026-07-22T09:22:43+08:00
- Type: Native reduced-spread dataset build failure and diagnostic freeze
- Status: RSB1 PARTIAL AND PROHIBITED; READ-ONLY REPRODUCTION PENDING
- Failed report: `native_reduced_build_KINGEA_ETHUSD_S_RSB1_2026.07.22_01-20-51.csv`; 61,400,668 ticks successfully added before failure; builder counted 61,423,372 transformed attempts, zero post-boundary unchanged ticks, and one invariant violation during the 2022-11-27 broker-day batch.
- Interpretation: The larger transformed counter includes the not-added failing daily batch and is not a completed-dataset count.
- Safety disposition: Do not rerun, use, test, or casually delete `KINGEA_ETHUSD_S_RSB1`. It is an incomplete local artifact.
- Diagnostic: `MQL5/Scripts/KingEA/DiagnoseNativeBuildFailure.mq5`; SHA-256 `2AC3A8D58B1F8BC98D203D62A11173FD5D4097B69B02F06BE50B8080CF369765`; MetaEditor result 0 errors and 0 warnings. It scans only the exact failing day and cannot mutate custom symbols or trade.
- Builder changes and any RSB2 build remain prohibited until the exact violated invariant is reproduced and classified.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-021

- Timestamp: 2026-07-22T09:32:26+08:00
- Type: RSB1 root cause and RSB2 corrective build authorization
- Status: ROOT CAUSE CONFIRMED; RSB2 TOOL VERIFIED
- Reproduction evidence: 44,169 ticks scanned on the exact 2022-11-27 failing broker day; 541/541 violations were `Ask == Bid` zero-spread ticks; zero invalid numbers, reversed spreads, backward timestamps, out-of-range ticks, or nonpositive Bid values. Diagnostic SHA-256 `41D30467DA9410B7D1A387E491163C0AE5DF91B592AF2E1EBB18BE965138F59C`.
- Root cause: Builder v1.00 rejected zero spreads before applying the frozen below-range clamp. This contradicted the registered quantile policy, which maps any pre-boundary spread below the Demo reference minimum to the Live2 minimum USD 0.98.
- Correction: Builder v1.01 accepts zero-spread source events, maps them before the boundary, preserves them at/after the boundary, continues to hard-fail reversed spreads, performs a complete five-year read-only preflight before target creation, logs exact invalid-source reasons, and updates counters only after successful batch insertion.
- Corrected builder: `MQL5/Scripts/KingEA/BuildNativeReducedSpreadSymbol.mq5`; target `KINGEA_ETHUSD_S_RSB2`; SHA-256 `70CD5C1A60EDE8DAE9E982C33936BBC64A89F8E5BAE3BDC401FDE72752F31655`; MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-RSB2Policy.ps1`; SHA-256 `DC76C291478F3FA793654927A55A173F815657EB312231F653D4E64B662E006C`; PASS against all 541 captured violations, frozen USD 0.98 floor, reversed-spread rejection, and preflight-before-mutation ordering.
- RSB1 disposition: Remains partial and prohibited. RSB2 is a distinct versioned target; no overwrite or deletion is authorized.
- Performance-test authorization: REMAINS DENIED pending RSB2 PASS, independent branch invariants/fingerprints, and Strategy Tester reconciliation.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-022

- Timestamp: 2026-07-22T09:34:32+08:00
- Type: RSB2 source-preflight failure
- Status: REVERSED-SPREAD REPRODUCTION PENDING; BUILD REMAINS BLOCKED
- Preflight finding: First hard failure at epoch milliseconds `1709374488223` / `2024-03-02 10:14:48.223` broker time, Bid USD 3427.62 and Ask USD 3427.36, recorded spread USD -0.26.
- Safety result: Failure occurred during the complete read-only source preflight before `PrepareTarget`; RSB2 construction did not begin.
- Policy: Unlike zero spread, negative/reversed spread is not authorized by the frozen mapping rule and may not be silently clamped, swapped, deleted, or normalized.
- Tight reproduction: `MQL5/Scripts/KingEA/DiagnoseReversedSpread.mq5`; SHA-256 `DB9DD15233B37A2B3322DB5F0FDDFD88991DCED1AD379E13C50962FB6DD41054`; MetaEditor result 0 errors and 0 warnings. It scans only 2024-03-02 and records every reversed quote with three neighboring ticks on each side.
- Builder changes and further RSB2 execution remain prohibited pending classification.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-023

- Timestamp: 2026-07-22T09:40:34+08:00
- Type: Reversed-spread source classification and storage probe
- Status: SOURCE BEHAVIOR CLASSIFIED; CUSTOM-SYMBOL ROUND-TRIP PENDING
- Diagnostic evidence: 140,438 native Demo2 ticks on 2024-03-02; exactly two reversed snapshots; diagnostic SHA-256 `2BA1E090AB98A36E44999A1FA7C683B6855AE0E086D42D2A6EF98FA8A06FC4AE`.
- First event: Ask-only update (`flags=100`) at `10:14:48.223` crossed the stale Bid by USD 0.26; a Bid update 202 milliseconds later restored a positive USD 1.18 spread.
- Second event: Bid-only update (`flags=98`) at `10:28:42.820` crossed the stale Ask by USD 0.04; a two-sided update 201 milliseconds later restored a positive USD 1.29 spread.
- Classification: Isolated asynchronous one-sided quote-update artifacts are strongly supported; broad timestamp or quote corruption is not supported. This classification alone does not authorize modification or omission.
- Storage question: The post-boundary reduced branch is required to preserve these native ticks exactly. Official documentation was insufficiently explicit about whether custom-symbol history round-trips crossed snapshots unchanged.
- Probe: `MQL5/Scripts/KingEA/ProbeCrossedTickRoundTrip.mq5`; SHA-256 `FF0FA0454EAC125D996FF74EB1BF2DC9CC17A61F75A6A54369E35DA7C8EBC0D5`; MetaEditor result 0 errors and 0 warnings. It requires explicit authorization, creates only `KINGEA_DIAG_CROSSED_V1`, and tests exact storage/readback of the two captured ticks without touching RSB1/RSB2.
- Builder changes and RSB2 execution remain prohibited until the round-trip result is reviewed.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-024

- Timestamp: 2026-07-22T17:55:56+08:00
- Type: Crossed-tick custom-symbol round-trip result
- Status: PRICE/TIMESTAMP STORAGE PASSED; NON-PRICE FIELD CLASSIFICATION PENDING
- Probe evidence SHA-256: `D4E5C6CB0EC28CDE0F013E1780FCFB2C1F0E81131160DDD9C5293FA6FA67B599`.
- Storage result: `CustomTicksAdd` accepted both crossed snapshots with no error and `CopyTicksRange` returned both. Exact `time_msc`, Bid, and Ask shown in the report were preserved.
- Aggregate result: FAIL because origin flags `100` and `98` were returned as normalized flags `6`. The original probe also compared time, last, and volume fields but did not report each separately, so flags-only normalization is not yet proven.
- Read-only comparator: `MQL5/Scripts/KingEA/CompareCrossedTickFields.mq5`; SHA-256 `E27B9C1DB540ACC2503A651AA6B968DB614C07E4B3F2D6BCF26048834B52760B`; MetaEditor result 0 errors and 0 warnings.
- No builder or data-policy change is authorized until the comparator proves whether any non-flag field changed.
- Diagnostic symbol `KINGEA_DIAG_CROSSED_V1` remains a local probe artifact and is prohibited for strategy testing.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-025

- Timestamp: 2026-07-22T18:01:29+08:00
- Type: MT5 flag-normalization amendment and RSB2 v1.02 authorization
- Status: PLATFORM EXCEPTION FROZEN; RSB2 BUILD AUTHORIZED
- Field-comparison evidence: `FLAGS_ONLY`; exactly two differences and zero non-flag differences. `time_msc`, `time`, Bid, Ask, spread, last, integer volume, and real volume round-trip exactly. Evidence SHA-256 `959B2D5812E3100032CB17A4282E8680B82F8C051B9BE9F45096EAEDB5499987`.
- Amendment: `governance/NATIVE_SPREAD_BRACKET_PLATFORM_AMENDMENT_2026-07-22.md`; SHA-256 `E9D52FE02CF8788D58811FC22FAC0A412BDF4677C8CA1D533DF7A0349B924FD4`.
- Exception: MT5 normalization of flags `100/98` to `6` is accepted only for the two exact registered crossed snapshots. No KingEA strategy, gate, or acceptance code may use `MqlTick.flags`.
- Corrected builder: version 1.02; target `KINGEA_ETHUSD_S_RSB2`; SHA-256 `7624E223B4E9FEDD4B3579F2878E5A95BB3F54931FE4D924E47D997E270C96AE`; MetaEditor result 0 errors and 0 warnings.
- Preflight rule: Require both exact registered timestamps/Bid/Ask pairs and zero additional reversed spreads across the complete five-year source. Any change or additional reversal blocks construction.
- Regression: `tests/Test-RSB2Policy.ps1`; SHA-256 `860E61FCC6EF84EC8F97B4A6FA294CFCBEC9AC6279B729EB297E79404E7C875A`; PASS.
- RSB2 build execution is authorized as non-performance dataset construction. Strategy/performance testing remains unauthorized afterward pending branch-invariant verification and dataset fingerprints.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-026

- Timestamp: 2026-07-22T18:12:22+08:00
- Type: Native reduced-spread custom-symbol construction
- Status: RSB2 BUILD PASSED; INDEPENDENT INVARIANT VERIFICATION PENDING
- Target: Local MT5 custom symbol `KINGEA_ETHUSD_S_RSB2` built from native JustMarkets-Demo2 `ETHUSD.s` ticks covering 2021-07-01 inclusive through 2026-07-01 exclusive.
- Build report SHA-256: `40B6511E6B2206FEF0E325B1D66FFEE40DDF5C1137C04B6DEA6D67FAE2873CB6`.
- Preflight: 327,417,608 source ticks; 759 zero-spread events; exactly two registered crossed snapshots; zero unexpected reversed spreads; PASS.
- Construction: 327,417,608 ticks added; 96,218,891 transformed before the registered boundary; 231,198,717 unchanged at/after it; transformed plus unchanged equals total; zero invalid ticks; final tick epoch milliseconds `1782863998902`; PASS.
- Interpretation: This proves successful dataset construction only. It does not prove branch identity, mapping correctness after storage, Strategy Tester synchronization, strategy edge, execution viability, or live safety.
- Live/demo authorization: Live trading remains prohibited. Strategy performance testing remains prohibited pending independent full-dataset invariants/fingerprints and Strategy Tester reconciliation.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-027

- Timestamp: 2026-07-22T21:35:45+08:00
- Type: Full RSB2 branch-invariant verification tooling
- Status: READ-ONLY VERIFIER COMPILED; OWNER EXECUTION PENDING
- Verifier: `MQL5/Scripts/KingEA/VerifyNativeReducedSpreadSymbol.mq5`; SHA-256 `E62BF82565EBF2A6508292F048AF894AFAC2AF52B72C19E305F55FEF353D1070`; MetaEditor result 0 errors and 0 warnings.
- Scope: Compare all 327,417,608 origin/custom ticks in daily chunks; independently recalculate the frozen pre-boundary Ask map; require exact post-boundary Ask plus timestamp/Bid/last/volume identity; compare daily counts/gaps; enforce only the two registered flag normalizations; verify fixed totals; emit two independent 64-bit canonical field fingerprints.
- Safety: Refuses non-Demo2 servers and non-custom targets; read-only APIs only; no orders, strategy logic, custom-symbol mutation, deletion, or performance calculation.
- Performance-test authorization: REMAINS DENIED pending verifier PASS and report hashing/review.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-028

- Timestamp: 2026-07-22T22:16:05+08:00
- Type: RSB2 verifier v1.00 failure and partial-read diagnosis
- Status: VERIFICATION INVALIDATED BY STRUCTURAL READ MISMATCH; RETENTION/CACHE PROBE PENDING
- Failed verifier report SHA-256: `5212C9B21E5AF207103B9A9A108159CD07B9087FFC441FB35AD4A38251627A6E`.
- Observed aligned count: 110,526,308 versus expected 327,417,608; 130,944 non-flag mismatches; 91,717,495 flag mismatches; zero recognized registered flag exceptions due index misalignment.
- Daily pattern: Through 2023-09-10 each custom daily read returned exactly origin count minus 128; from 2023-09-11 onward 1,023 days returned exactly 128 custom ticks. All 1,825 populated comparison days had count mismatches.
- Interpretation: Index-based mismatch and fingerprint outputs are not valid branch-quality evidence after daily counts diverge. The report is retained as diagnostic evidence only and cannot reject or accept the dataset until the custom read/storage mechanism is classified.
- RSB2 disposition: Preserve unchanged; do not rebuild, delete, or use for performance testing.
- Tight probe: `MQL5/Scripts/KingEA/DiagnoseCustomTickRetention.mq5`; SHA-256 `0B134CA435000A4A503FB07BC51C271B48C548417A0218CAC4073F3D726D49BC`; MetaEditor result 0 errors and 0 warnings. It repeats full-day reads and compares half-day/hourly subranges for one early and one transition day.
- Verifier changes remain prohibited pending the probe result.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260722-029

- Timestamp: 2026-07-22T22:24:44+08:00
- Type: RSB2 storage-loss confirmation and historical API probe
- Status: CUSTOMTICKSADD BULK BUILD REJECTED; CUSTOMTICKSREPLACE PROBE PENDING
- Retention evidence SHA-256: `61F884752072D2AF5F30178CD0C2320AE43A1C800993897CF3746A68C1DFB439`.
- Finding: Repeated full-day reads are stable; half-day/hourly subdivision does not recover missing ticks. On 2021-07-01 the stored day permanently lacks its final 128 source ticks. On 2023-09-11 the first 23 hours contain zero stored ticks and only the final 128 ticks remain. This is storage loss, not verifier cache behavior.
- Root-cause direction: `CustomTicksAdd` is rejected for bulk historical construction. Its streaming/buffer semantics are consistent with the exact 128-event pattern, but the corrective API must be empirically proven before RSB3.
- Probe: `MQL5/Scripts/KingEA/ProbeCustomTicksReplace.mq5`; SHA-256 `59FE23B1334EF57E729F74ADA156ED87309267C89E371B6C1D2D8DC5AEF1DFDC`; MetaEditor result 0 errors and 0 warnings. It uses `CustomTicksReplace` on two complete native days and verifies counts, boundaries, and every non-flag field in a new diagnostic symbol only.
- RSB1 and RSB2 remain incomplete/prohibited and must not be deleted until storage and disk-space disposition is reviewed.
- RSB3 construction and performance testing remain prohibited pending probe PASS.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260723-030

- Timestamp: 2026-07-23T09:35:12+08:00
- Type: Bulk custom-history root cause and RSB3 corrective build authorization
- Status: ROOT CAUSE CONFIRMED; RSB3 BUILDER VERIFIED
- Replace-probe evidence SHA-256: `FF9AFD7EF4F6E1D1F1A111168BCA4D42B5991CCB2F829D1CB38DF77A8F158B73`.
- Probe result: `CustomTicksReplace` wrote and returned exact counts for both 2021-07-01 (173,712 ticks) and 2023-09-11 (102,582 ticks), with matching first/last boundaries, zero non-flag mismatches, zero flag mismatches, and no API errors.
- Root cause: `CustomTicksAdd` was the wrong API for bulk historical construction and produced persistent 128-event streaming/buffer data loss. It is prohibited for RSB historical datasets.
- Corrective builder: version 1.03; target `KINGEA_ETHUSD_S_RSB3`; uses daily `CustomTicksReplace`, followed immediately by exact daily count and non-flag field readback before continuing. SHA-256 `392A5C6A09305AC60A82128AC1C855B48DA842CBFFAF56D90B4716EAD979A4A4`; MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-RSB2Policy.ps1`; SHA-256 `782C335D1A83AD0A0832B29DA1988394250CC088349CA16F9E66BBD54607284E`; PASS for RSB3 policy and storage API.
- Disk review: Approximately 68 GiB free; RSB1 occupies about 0.37 GiB and RSB2 about 1.69 GiB. Both may remain preserved as prohibited audit artifacts during RSB3 construction; no deletion is authorized or required.
- RSB3 non-performance construction is authorized on Demo2 only. Performance testing remains prohibited after construction pending independent full-dataset verification and report hashing.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260723-031

- Timestamp: 2026-07-23T09:37:59+08:00
- Type: RSB3 source identity clarification
- Status: EXPLICIT BUILD STAMP ADDED; COMPILE AND REGRESSION PASS
- Reason: Owner correctly questioned an apparently stale modification time. Functional source was already RSB3 v1.03, but an explicit build identity was added to prevent copying ambiguity.
- Build identity: `RSB3-REPLACE-20260723-A`; version 1.03; target `KINGEA_ETHUSD_S_RSB3`; daily `CustomTicksReplace` plus immediate count/non-flag readback.
- Current source SHA-256: `5D7E8714A6BAF5B5D1667F38B7473E66CD7ABFE342D5EC130F747556661368BA`; modification time `2026-07-23 09:37:39.450` local; MetaEditor result 0 errors and 0 warnings; RSB3 policy regression PASS.
- This identity-only source clarification supersedes the v1.03 source hash in GOV-20260723-030; behavior is unchanged.
- Performance-test authorization: REMAINS DENIED pending RSB3 build and independent verification.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260723-032

- Timestamp: 2026-07-23T09:49:37+08:00
- Type: RSB3 construction PASS and independent verifier preparation
- Status: RSB3 BUILD PASSED; FULL INVARIANT VERIFICATION PENDING
- Build report SHA-256: `F7D8FAC87B0A6F8785715351DE75AC9E2E878EA0495214E3F79352942AA5AE43`.
- Build result: 327,417,608 total ticks; 96,218,891 transformed; 231,198,717 unchanged; zero invalid ticks; zero daily readback non-flag mismatches; exact registered crossed-tick preflight; no failure rows; PASS.
- Interpretation: Daily `CustomTicksReplace` and immediate readback succeeded across the complete five-year dataset. This is construction evidence, not independent acceptance.
- Independent verifier: version 1.01; Build ID `RSB3-VERIFY-20260723-A`; target `KINGEA_ETHUSD_S_RSB3`; SHA-256 `DF82F998538691CD6F33F5EBF868DF3B55B6CD22FBFB13CFC35FF97FB522E6BB`; MetaEditor result 0 errors and 0 warnings.
- Flag policy: Exact preservation is preferred; the only permitted alternative is the already registered normalization of both crossed snapshots. Zero or two registered normalizations pass; one or any unregistered flag mismatch fails.
- Live account: Builder and verifier remain Demo2-only. No equivalent live-account run is required or authorized.
- Performance-test authorization: REMAINS DENIED pending verifier PASS and report hashing/review.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260723-033

- Timestamp: 2026-07-23T21:17:19+08:00
- Type: RSB3 full verifier 1.01 result and persisted-flag diagnosis
- Status: ECONOMIC/TICK IDENTITY PASSED; FLAG-METADATA POLICY PENDING
- Verifier report SHA-256: `03326BEB5820EC274BB58C440D1B0510503C2B7C40914EC7FAA8E8A83C27FE21`.
- Passed invariants: Exact 327,417,608 origin/stored counts; zero daily count mismatches; zero non-flag mismatches; exact transformed/unchanged totals; exact first/last timestamps; both independent expected fingerprints equal stored fingerprints; counts and fingerprint gates PASS.
- Failing invariant: 272,867,308 flag mismatches, zero recognized two-tick exceptions. MT5 persisted custom history rewrites flags broadly even though immediate per-day readback after `CustomTicksReplace` had preserved them.
- Interpretation: The RSB3 price/timestamp/last/volume dataset is exact. Acceptance remains blocked only on whether persisted `MqlTick.flags` normalization is deterministic platform metadata and safe to exclude. No strategy may use flags.
- Diagnostic: `MQL5/Scripts/KingEA/DiagnosePersistedFlagNormalization.mq5`; SHA-256 `CC8E47C9C88C51A1A77E30145FBDF27C28CC146560B70B4D17F5DD46386C9F09`; MetaEditor result 0 errors and 0 warnings. It maps origin-to-stored flags on one transformed and one unchanged day while rechecking non-flag alignment.
- Note: The journal text says `RSB2 verification report`; this is a cosmetic stale label. The filename, configured target, and report contents prove the run was RSB3. The label will be corrected with the final flag-policy verifier revision.
- Performance-test authorization: REMAINS DENIED pending flag classification and final verifier PASS.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260723-034

- Timestamp: 2026-07-23T22:21:51+08:00
- Type: Persisted-flag normalization diagnosis and final verifier rule
- Status: DETERMINISTIC RULE CONFIRMED; FINAL FULL VERIFIER READY
- Diagnostic result: PASS across one transformed day and one unchanged day, totaling 444,322 ticks; exact per-day counts; zero non-flag mismatches.
- Observed flag mappings: `4→4`, `130→2`, `134→6`, `96→96`, `226→98`, and `230→102`.
- Finding: MT5 custom-history persistence deterministically clears flag bit `128`; flags without that bit remain unchanged in both sampled regimes. This is platform metadata normalization, not a market-field transformation.
- Final acceptance rule: `stored_flags = origin_flags & 0xFFFFFF7F` for every tick. Clearing bit `128` is permitted; any change to another bit fails. `MqlTick.flags` remains prohibited from all strategy, gate, execution, cost, ordering, and performance logic.
- Diagnostic evidence file: `persisted_flag_normalization_2026.07.23_14-21-50.csv`; SHA-256 `ABEC9F5A82BA40B171ECD54AAEFF4EDD9665A5B9F97CBB7E3DFD7C45A5251B46`.
- Final verifier: version 1.02; Build ID `RSB3-VERIFY-20260723-B`; corrects the stale RSB2 journal label and enforces the exact bit rule across the complete dataset. Source SHA-256 `21234DF52860515BFC78D547ED59461A765457C73C6D401EC3281741A438D8C3`; MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-RSB2Policy.ps1`; SHA-256 `19C7B840B702163501EB9086BA36776CD36214256D09E9A6F352593A8DCB3394`; PASS.
- Performance-test authorization: REMAINS DENIED pending final full-verifier PASS and report hashing/review.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-035

- Timestamp: 2026-07-24T00:05:00+08:00
- Type: RSB3 final full-dataset acceptance
- Status: PASS; REDUCED-SPREAD SENSITIVITY DATASET ACCEPTED
- Verification report: `native_reduced_verify_KINGEA_ETHUSD_S_RSB3_2026.07.23_15-48-05.csv`; SHA-256 `311F232414C5EC7AF898826F0C834DA091B8DD7A2BB9C427467A7B777C37BCE8`.
- Exact invariants: 327,417,608 origin and stored ticks; 96,218,891 transformed; 231,198,717 unchanged; zero count-mismatch days; zero non-flag mismatches; 272,867,308 raw flag changes; all 272,867,308 match the frozen bit-128 normalization; zero invalid flag normalizations.
- Fingerprints: expected/stored fieldhash64 both `12331204907777062548`; expected/stored mix64 both `2622223847145114891`.
- Root cause closed: `CustomTicksAdd` is a streaming API whose bulk historical use silently retained only a 128-tick buffer pattern. Daily `CustomTicksReplace` is the required historical-construction API. Persisted custom history clears `MqlTick.flags` bit `128`; every other flag bit and all market fields remain enforced.
- Regression: `tests/Test-RSB2Policy.ps1` PASS; no temporary debug instrumentation remains.
- Dataset manifest updated to `DERIVED_DATASET_ACCEPTED_TESTER_RECONCILIATION_PENDING`; SHA-256 `498514189FEE0C3EF84DD338F4120474CE600DFA7964CB834624D339DBC254BC`.
- Construction authorization: CLOSED. Do not rebuild RSB3 unless its frozen inputs or implementation change under a new governed version.
- Performance-test authorization: REMAINS DENIED. The remaining data gate is Strategy Tester synchronization/real-tick reconciliation; after that, `CAND-ETH-ST-001` must be formally pre-registered and frozen before any performance run.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-036

- Timestamp: 2026-07-24T00:13:03+08:00
- Type: Strategy Tester real-tick reconciliation harness
- Status: FIRST SMOKE PAIR READY
- Artifact: `MQL5/Experts/KingEA/ReconcileTesterRealTicks.mq5`; version 1.00; Build ID `TESTER-RECON-20260724-A`; SHA-256 `00AA91CFA53E848D91B8B2095071F9790E461FA898D512CB4BB080CAEC29777D`.
- Scope: Tester-only, non-trading comparison of `OnTick` replay against `CopyTicksRange` for a frozen half-open window. It requires exact tick count, first/last timestamps, monotonic ordering, canonical market-field fingerprints, and selected-symbol flag-stream fingerprint.
- Safety: The EA refuses to initialize outside Strategy Tester and contains no order-submission, position, strategy, or indicator API.
- Static verification: MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-TesterTickReconciliationPolicy.ps1`; SHA-256 `157EBEFC9A10C9D8081C50A99589287DB664712B4DD85D3B9F5D194AFAE4838C`; PASS.
- Authorized smoke pair: `ETHUSD.s` and `KINGEA_ETHUSD_S_RSB3`, separately, over 2021-07-01 inclusive through 2021-07-02 exclusive, M30, `Every tick based on real ticks`, expected 173,712 ticks each.
- Performance-test authorization: REMAINS DENIED. These runs are infrastructure reconciliation only.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-037

- Timestamp: 2026-07-24T00:19:43+08:00
- Type: Strategy Tester native first-smoke result
- Status: REPLAY-INTERNAL IDENTITY PASSED; REGISTERED SOURCE COUNT FAILED BY TWO
- Report: `tester_tick_reconciliation_DEMO2_ORIGIN_20210701_ETHUSD.s_2021.07.01_23-59-57.csv`; SHA-256 `B12FAAB6483C9EAACF87F9B1E68F3404315A18F4460CEAD126EBB5D3D41570C5`.
- Tester context: JustMarkets-Demo2; native `ETHUSD.s`; M30; `Every tick based on real ticks`; target window 2021-07-01 inclusive through 2021-07-02 exclusive.
- Exact result: Tester `OnTick` replay and tester-side `CopyTicksRange` both returned 173,710 ticks, identical first/last timestamps, identical market-field and flag fingerprints, and zero out-of-order events.
- Failed external invariant: The previously verified direct Demo2 source contains 173,712 ticks for the same day. The tester sandbox exposed two fewer ticks, so the registered expected-count gate correctly returned FAIL.
- Leading hypothesis: With the test itself starting at 2021-07-01, MT5 consumes two initial quote updates to initialize symbol state before exposing the replay. A one-day pre-window warm-up rerun is authorized to test this without changing the frozen target window or expected count.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-038

- Timestamp: 2026-07-24T00:29:01+08:00
- Type: RSB3 Strategy Tester zero-replay diagnosis
- Status: TIGHT REPRODUCER CAPTURED; BAR-READINESS PROBE READY
- Failed report: `tester_tick_reconciliation_DEMO2_ORIGIN_20210701_WARMUP_KINGEA_ETHUSD_S_RSB3_2021.07.03_00-00-00.csv`; SHA-256 `9402D13E1D81209291153A581FA392B916D7DD79BBB920E4E90FE195CB0285A3`.
- Clarification: The run label said native warm-up, but the selected tester symbol was the custom `KINGEA_ETHUSD_S_RSB3`.
- Exact symptom: Tester-side `CopyTicksRange` exposed all 173,712 registered RSB3 ticks with correct boundaries, while `OnTick` replay produced zero events.
- Leading hypothesis: The custom tick database is intact, but the corresponding tester-visible M1/M30 series is absent or unsynchronized. MT5 Strategy Tester requires minute history to frame a test even in real-tick mode.
- Read-only diagnostic: `MQL5/Scripts/KingEA/DiagnoseCustomTesterReadiness.mq5`; version 1.00; Build ID `TESTER-READINESS-20260724-A`; SHA-256 `6E6E042EF5F22B8F1216E105848FBB60A277211FC73B3480D25B48C649102101`; MetaEditor result 0 errors and 0 warnings.
- Safety: No trading, strategy, indicator, custom-tick mutation, or custom-rate mutation APIs exist in the diagnostic.
- RSB3 status: Accepted tick dataset remains untouched. No rebuild or bar mutation is authorized until the read-only diagnostic classifies the series state.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-039

- Timestamp: 2026-07-24T00:30:51+08:00
- Type: Mandatory Strategy Tester input-set control
- Status: ACTIVE
- Decision: Every governed Strategy Tester run must be issued with a named `.set` file. Manual input transcription is prohibited.
- Native warm-up set: `MQL5/Profiles/Tester/KingEA/tester_recon_demo2_origin_20210701_warmup.set`; SHA-256 `DCB8CC0148D01BD84B607A13FF56A51C1300917837A86BF20F55885A549733B2`.
- RSB3 warm-up set: `MQL5/Profiles/Tester/KingEA/tester_recon_rsb3_reduced_20210701_warmup.set`; SHA-256 `C1E22DF14E813159D6F05D6E7EBAEA4618C0FFD3A29E87F348DA557B930B8E3D`; remains blocked pending custom-bar readiness.
- UI companion matrix: `MQL5/Profiles/Tester/KingEA/tester_recon_run_matrix.csv`; SHA-256 `4CACBED9428A7A907912CC280787BEB1AD91810021105771A55F6E21BF45B998`.
- Boundary: MT5 `.set` files control EA inputs but not the selected symbol, timeframe, modeling mode, tester dates, or account. Those settings are mandatory fields in the hashed companion matrix.
- Regression: `tests/Test-TesterSetFiles.ps1`; SHA-256 `F49D946E3FA5085E0A50DAD58475A455ABD754DBC4A105DCC69DF6F81FFDDE61`; PASS.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-040

- Timestamp: 2026-07-24T09:10:28+08:00
- Type: Custom-symbol tester-readiness classification
- Status: ROOT CAUSE NARROWED TO MISSING HISTORICAL M1 SERIES
- Evidence report: `custom_tester_readiness_2026.07.24_01-07-21.csv`; SHA-256 `A07BA8DB3742FAD0B23AAE50BDFAAE268B6873F9C468A04C4A42330C4384F201`.
- Exact evidence: Native and RSB3 each contain 173,712 ticks with identical target-day boundaries. Native and RSB3 each expose 48 M30 bars. Historical M1 `CopyRates` fails with error 4401 for both terminal series, while the custom symbol cannot ask a broker server to fill that missing base series.
- Interpretation: RSB3 tick integrity remains accepted. The zero-event tester run is caused by absent tester-usable M1 framing history, not missing custom ticks.
- Diagnostic correction: Tester-readiness version 1.01 now treats missing M1 or M30 history as FAIL instead of reporting tick readability alone as PASS; source SHA-256 `0EF63F77A8DDDE67F07D0CCE9B22C1C72F0CCF9DC663F129B39B8DB4BD1EB130`; MetaEditor result 0 errors and 0 warnings. The original evidence remains valid and is interpreted field-by-field.
- Next read-only probe: `MQL5/Scripts/KingEA/DiagnoseMinuteBarDerivation.mq5`; version 1.00; Build ID `M1-DERIVATION-DIAG-20260724-A`; SHA-256 `48A2B63C0AF6BA1986B9C06019BF7D23E6B745B8ECBFD1ED8F7934A6D6162441`; MetaEditor result 0 errors and 0 warnings.
- Probe purpose: Aggregate the accepted RSB3 ticks deterministically into candidate M1/M30 bars and compare the derived M30 time/OHLC/tick-volume/spread/real-volume fields with the 48 stored M30 bars before authorizing any bar-history write.
- RSB3 tick dataset: UNCHANGED and ACCEPTED.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-041

- Timestamp: 2026-07-24T09:22:26+08:00
- Type: RSB3 minute-bar derivation first result and spread-rule correction
- Status: PRICE/VOLUME AGGREGATION PROVED; MINIMUM-SPREAD CONFIRMATION PENDING
- Evidence report: `minute_bar_derivation_2026.07.24_01-11-42.csv`; SHA-256 `114DF17FBE6B0ECAC9624A1FBAEE65BA1BD5AC903D637DB867E534CF7044BA6F`.
- Exact first result: 173,712 accepted ticks produced 1,440 non-empty M1 bars and 48 M30 bars; stored M30 count 48; zero time, OHLC, tick-volume, and real-volume mismatches; seven spread-field mismatches.
- Root-cause hypothesis: The first diagnostic assigned each bar the final tick spread. MT5 bar history records the minimum tick spread within the bar; only intervals whose final spread exceeded their minimum therefore differed.
- Corrected read-only probe: version 1.01; Build ID `M1-DERIVATION-DIAG-20260724-B`; accumulates the minimum tick spread and changes no other field or rule; SHA-256 `C1A2A5A495D844DECDD89CABEB04895E1C3CC033D13FE8DAF0417A7BBB9FF839`; MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-MinuteBarDerivationPolicy.ps1`; SHA-256 `5F773243BB8E6FAC7F2C446BCBC559BF165AFC7A529F2D3430BBD664B7E754EE`; red on version 1.00, PASS on version 1.01.
- RSB3 tick dataset: UNCHANGED and ACCEPTED. No bar-history write is authorized until the corrected read-only probe returns zero mismatches.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-042

- Timestamp: 2026-07-24T09:35:56+08:00
- Type: Minimum-spread hypothesis falsification and targeted instrumentation
- Status: MINIMUM-SPREAD RULE REJECTED; SEVEN-BAR CANDIDATE MAP PENDING
- Evidence report: `minute_bar_derivation_2026.07.24_01-33-23.csv`; SHA-256 `97546EC61753AB74BE0A6429EC762A5B02FB3C6F8D1A43D75A25455F2B6AE5D5`.
- Build identity confirmed: `M1-DERIVATION-DIAG-20260724-B` actually ran; stale source execution is ruled out.
- Result: Changing only the bar-spread accumulator from final tick to minimum tick left exactly seven spread mismatches. The minimum-spread hypothesis is falsified for this stored RSB3 M30 series.
- Instrumented diagnostic: version 1.02; Build ID `M1-DERIVATION-DIAG-20260724-C`; SHA-256 `D9BE208B752BA835725910A92C1799E3C826F95B4323DC260EBFC7D6CB381FBC`; MetaEditor result 0 errors and 0 warnings.
- Instrumentation scope: For only the mismatching M30 bars, record stored spread beside first, last, minimum, maximum, floor/round/ceiling average, median, mode, and integer-price-unit minimum candidates. No history mutation occurs.
- Regression: `tests/Test-MinuteBarDerivationPolicy.ps1`; SHA-256 `09474F946E836A2C174AC12109FB54931D5FBC406167908B0D1B0360F4881256`; red before instrumentation and PASS afterward.
- RSB3 tick dataset: UNCHANGED and ACCEPTED.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-043

- Timestamp: 2026-07-24T09:39:32+08:00
- Type: Minute-bar spread root cause and regression hardening
- Status: IMPLEMENTATION BUG CONFIRMED AND CORRECTED; FINAL READ-ONLY CONFIRMATION PENDING
- Evidence report: `minute_bar_derivation_2026.07.24_01-37-26.csv`; SHA-256 `BBA37F43A1C23A15533361D71E3D3865C8EFFF88F422E529FC4F5096CA3195AB`.
- Seven-bar finding: Every stored mismatching M30 spread equals 307, and every independently computed minimum and exact-point minimum also equals 307. This confirms the minimum-spread convention.
- Root cause: Version 1.01 accidentally placed `MathMin` in `StartBar` against newly allocated rate storage, while `UpdateBar` continued overwriting spread with each final tick. Version 1.02 instrumentation exposed the discrepancy.
- Corrected probe: version 1.03; Build ID `M1-DERIVATION-DIAG-20260724-D`; `StartBar` initializes from the first tick and `UpdateBar` retains the minimum; SHA-256 `2C2862C6CFCF1103A6CD990BBA7EE55951D24CDBE4974619257054B9ACDAC2C7`; MetaEditor result 0 errors and 0 warnings.
- Regression hardening: The prior test only searched globally for the minimum expression and failed to prove its function placement. `tests/Test-MinuteBarDerivationPolicy.ps1` now parses `StartBar` and `UpdateBar` separately and enforces both responsibilities; SHA-256 `6D8B1ACBBE9C0752C9747B701561C3EA84D92CA45A42E3EC2B0868FB91C7E363`; red before correction and PASS afterward.
- RSB3 tick dataset: UNCHANGED and ACCEPTED. Bar-history mutation remains unauthorized pending final zero-mismatch diagnostic.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-044

- Timestamp: 2026-07-24T09:43:50+08:00
- Type: RSB3 five-year M1 preflight/builder preparation
- Status: READ-ONLY PREFLIGHT READY; BAR MUTATION NOT AUTHORIZED
- Final derivation evidence: `minute_bar_derivation_2026.07.24_01-40-48.csv`; SHA-256 `2C8B2D347E0895D599C2349B09C0DF316C51C7F73AC6E269D9A36ABC1624E59E`; PASS with 173,712 ticks, 1,440 derived M1 bars, 48 derived/stored M30 bars, and zero time/OHLC/tick-volume/spread/real-volume mismatches.
- Tool: `MQL5/Scripts/KingEA/BuildRSB3MinuteBars.mq5`; version 1.00; Build ID `RSB3-M1-BARS-20260724-A`; SHA-256 `5D9B9DF8FBA77935816A126AD0BDEE2B81D6BBF96AE25CB77C36A1BCF4FC8719`; MetaEditor result 0 errors and 0 warnings.
- Default behavior: Blank authorization token performs a complete five-year read-only preflight. It requires exactly 327,417,608 ticks and exact derived-versus-stored M30 rate identity before any future write can be authorized.
- Guarded build behavior: Only exact token `AUTHORIZE_RSB3_M1_BARS_20260724` can reach `CustomRatesReplace`, and only after the same complete preflight passes. Each written M1 day must read back exactly, retain exact M30 aggregation, and preserve the day's tick count plus two independent tick fingerprints.
- Safety: No `CustomTicks*`, order, position, strategy, indicator, return, or optimizer API exists.
- Regression: `tests/Test-RSB3MinuteBarBuilderPolicy.ps1`; SHA-256 `F1E6156094187B57A5855EF1BD67EBE5EB7EDFF8B733C334450A54585C6007DE`; PASS.
- RSB3 tick dataset: UNCHANGED and ACCEPTED.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-045

- Timestamp: 2026-07-24T14:41:01+08:00
- Type: Five-year M1 preflight result and crossed-day isolation
- Status: 1,826 DAYS PASS; REGISTERED CROSSED-QUOTE DAY PENDING
- Preflight report: `rsb3_m1_PREFLIGHT_2026.07.24_01-45-17.csv`; SHA-256 `DB9976EBB2FC8E165B7784381D73B2F74B672CD981D2D7DB5E91BF0ECF20E104`.
- Exact totals: 327,417,608 ticks; 2,610,467 derived M1 bars; 87,434 derived M30 bars; zero copy failures; exactly one rate mismatch.
- Isolated day: 2024-03-02 (`day_start_msc=1709337600000`), containing the two already registered asynchronous crossed quotes. All other days and bars match exactly.
- Interpretation: The general aggregation algorithm is accepted. The remaining decision is how MT5 converts the two negative instantaneous spreads into non-negative bar spread metadata; tick-level Bid/Ask remains unchanged and authoritative.
- Targeted diagnostic: `MQL5/Scripts/KingEA/DiagnoseMinuteBarDerivation.mq5`; version 1.04; Build ID `M1-DERIVATION-DIAG-20260724-E`; defaults to 2024-03-02 and records stored spread, minimum positive/non-negative spread, and negative-tick count; SHA-256 `4F084B5FB06B18415D0BB70C35FF246DD4B965C33DBAB77E5EFC5D55566BC04B`; MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-MinuteBarDerivationPolicy.ps1`; SHA-256 `3070B29D620D223A21D03DC4EF0FE7D08539AEB16863082548E91C0BF6D0BFCD`; PASS.
- M1 bar mutation: REMAINS UNAUTHORIZED. Preflight correctly left RSB3 untouched.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-046

- Timestamp: 2026-07-24T14:58:52+08:00
- Type: Crossed-quote bar-spread rule resolution
- Status: MINIMUM-POSITIVE-SPREAD RULE CONFIRMED; FULL PREFLIGHT READY
- Evidence report: `minute_bar_derivation_2026.07.24_06-50-12.csv`; SHA-256 `215894B5B61A6D79C903B177E40920076D6C2CC13C8E20ED01BEA75C92202A1E`.
- Exact crossed bar: 2024-03-02 10:00 M30; stored spread 53 points; minimum positive and minimum non-negative spread both 53; raw minimum and exact-point minimum both -26; exactly two negative-spread ticks.
- Rule: Preserve every accepted tick Bid/Ask, including both registered crossed snapshots. For `MqlRates.spread` only, retain the minimum strictly positive tick spread within the bar; use zero only if no positive spread exists.
- Corrected diagnostic: version 1.05; Build ID `M1-DERIVATION-DIAG-20260724-F`; SHA-256 `17386EC153B2AEC35428D932717594D7F8438571D7220D285FC5D42A5447D040`; MetaEditor result 0 errors and 0 warnings.
- Corrected five-year tool: version 1.01; Build ID `RSB3-M1-BARS-20260724-B`; SHA-256 `14EFDDC7BA2D614AF7DF50FA64A8B07A5BB5FB1EC2EA55E98F864E49C8074853`; MetaEditor result 0 errors and 0 warnings.
- Regressions: `tests/Test-MinuteBarDerivationPolicy.ps1` SHA-256 `B576A077153B48E4624FD0F417864695FC16FF0CF842F87E79EB2C6AFF642C74`; `tests/Test-RSB3MinuteBarBuilderPolicy.ps1` SHA-256 `F896F6CCA458125021C5AB9B5FB7C1F87B07AF9F8D4BFFC48E0CF76A87DDDFC8`; both PASS.
- M1 bar mutation: REMAINS UNAUTHORIZED pending a clean full blank-token preflight.
- RSB3 tick dataset: UNCHANGED and ACCEPTED.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260724-047

- Timestamp: 2026-07-24T19:49:37+08:00
- Type: Five-year M1 preflight second result and series-synchronization correction
- Status: RATE RULE PASSED; FIRST-CALL M30 WARM-UP RETRY READY
- Preflight report: `rsb3_m1_PREFLIGHT_2026.07.24_11-45-13.csv`; SHA-256 `B67EB351665D073109F5E4B1001ADF102ED206CE95CCD5B236BB18D9FBBBF3DD`.
- Exact result: Tick/M1/M30 totals remained 327,417,608 / 2,610,467 / 87,434. All reported mismatches came from the first dataset day only: 48 derived M30 bars versus a transient zero-bar `CopyRates` response, encoded as 48 missing bars plus one count mismatch. Every subsequent day passed, including the registered crossed-quote day.
- Root cause: The first custom-series `CopyRates` request can initiate asynchronous history construction and return before the expected bars are ready. This is series-cache warm-up, not a bar-value mismatch or data loss.
- Corrected tool: version 1.02; Build ID `RSB3-M1-BARS-20260724-C`; bounded `CopyRatesExpected` retries up to 50 attempts with 100 ms yields for preflight and post-write M1/M30 reads; SHA-256 `253A91859AC897E884FCB16DFD5B1C05C39BD99E1C2F8908180330045D3755F7`; MetaEditor result 0 errors and 0 warnings.
- Regression: `tests/Test-RSB3MinuteBarBuilderPolicy.ps1`; SHA-256 `9C87D076CEA0A10CDB9B0D1B71BD2CEFA140D4D21083528C60411F5C99FB853A`; red before retry support and PASS afterward.
- M1 bar mutation: REMAINS UNAUTHORIZED pending clean blank-token preflight.
- RSB3 tick dataset: UNCHANGED and ACCEPTED.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260726-048

- Timestamp: 2026-07-26T11:53:35+08:00
- Type: RSB3 five-year M1 construction and independent readiness result
- Status: M1 HISTORY BUILT AND VERIFIED; TESTER RECONCILIATION PENDING
- Initial blank-token preflight: `rsb3_m1_PREFLIGHT_2026.07.25_05-18-22.csv`; SHA-256 `9ED40E3E62A3691554E79696B9B0918B5E06B7205872BA125542FF4DA403C207`; PASS with 327,417,608 ticks, 2,610,467 M1 bars, 87,434 M30 bars, zero mismatches, and zero copy failures.
- First guarded build: `rsb3_m1_BUILD_2026.07.25_05-31-14.csv`; SHA-256 `E808FC232D692E881A3E2FE62E7E686B06D89F5AD92FEC358739C665F688E879`; safely stopped after the first 1,440 M1 bars because `CopyRates` returned data outside the terminal's 100,000-bar limit.
- Root cause: MetaQuotes documents that `CopyRates` returns `-1` outside `TERMINAL_MAXBARS`. A 100,000-bar limit reaches 2021 on M30 but not on M1.
- Corrected builder: version 1.03; Build ID `RSB3-M1-BARS-20260725-D`; requires `TERMINAL_MAXBARS >= derived M1 count`, records the active limit, and uses a bounded 30-second series warm-up. MetaEditor result: 0 errors and 0 warnings.
- Corrected blank-token preflight: `rsb3_m1_PREFLIGHT_2026.07.25_06-54-29.csv`; SHA-256 `6E46C521DACAE2BA704B07D633FE610D759523603B692906BB05A9328499F610`; PASS with `max_bars=3,000,000`, required bars 2,610,467, and zero mismatches/copy failures.
- Final guarded build: `rsb3_m1_BUILD_2026.07.25_06-56-37.csv`; SHA-256 `5375051A2EBBB0ECC7487BFD78547E01DD5CAD15E5CB20A9651A87C65E1BCBDD`; PASS with 2,610,467 M1 bars written/read back, 87,434 M30 bars matched, and zero tick-integrity failures across 327,417,608 ticks.
- Independent readiness: `custom_tester_readiness_2026.07.25_07-18-32.csv`; SHA-256 `45A413FAE30981DC789DAADDB0C092C2F0242D8CAF7B56E5EB10267104A23EE6`; PASS with matching native/custom counts of 173,712 ticks, 1,440 M1 bars, and 48 M30 bars for 2021-07-01.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260726-049

- Timestamp: 2026-07-26T11:53:35+08:00
- Type: RSB3 Strategy Tester reconciliation window correction
- Status: REPLACEMENT NON-PERFORMANCE RUN AUTHORIZED
- Original run `RSB3_REDUCED_20210701_WARMUP` is retained as `INFEASIBLE_MT5_MANDATORY_WARMUP`. Since RSB3 history begins on 2021-07-01, MT5 moved actual tester execution to 2021-07-03 to provide mandatory preceding bars, leaving the original 2021-07-01 measurement window with zero replay ticks.
- Replacement run: `RSB3_REDUCED_20210703_WARMUP`; tester range 2021-07-01 through 2021-07-04; measurement window 2021-07-03 00:00:00 inclusive through 2021-07-04 00:00:00 exclusive; exact accepted source count 88,490 ticks.
- Mandatory set: `tester_recon_rsb3_reduced_20210703_warmup.set`; symbol `KINGEA_ETHUSD_S_RSB3`; timeframe M30; model `Every tick based on real ticks`; Demo2 only.
- This is a data-mechanics reconciliation, not a strategy test. No entry/exit logic, returns, optimization, OOS/holdout data, or candidate-budget consumption is involved.
- Performance-test authorization: REMAINS DENIED.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260726-050

- Timestamp: 2026-07-26T12:03:01+08:00
- Type: First replacement tester reconciliation result and observed warm-up boundary
- Status: 2021-07-03 WINDOW INFEASIBLE; 2021-07-04 REPLACEMENT AUTHORIZED
- Evidence report: `tester_tick_reconciliation_RSB3_REDUCED_20210703_WARMUP_KINGEA_ETHUSD_S_RSB3_2021.07.04_00-00-00.csv`; SHA-256 `25AF6E64B547B4F72B27B5C5EDD675F48FD96C0BBA7753AE9A17EE86619F9294`.
- Inputs loaded correctly: label `RSB3_REDUCED_20210703_WARMUP`; symbol `KINGEA_ETHUSD_S_RSB3`; M30; real-tick model; measurement window 2021-07-03; exact source count 88,490.
- MT5 synchronized 144 M30 bars and 1.43 MB of ticks for 2021-07-01 through 2021-07-03, then explicitly changed execution start to 2021-07-04 00:00 to provide mandatory beginning data. The requested test ended at that same timestamp, so zero ticks and zero bars were replayed.
- Replacement run: `RSB3_REDUCED_20210704_WARMUP`; tester range 2021-07-01 through 2021-07-05; measurement window 2021-07-04 00:00:00 inclusive through 2021-07-05 00:00:00 exclusive; exact accepted source count 42,787 ticks.
- Mandatory set: `tester_recon_rsb3_reduced_20210704_warmup.set`. The reconciliation gate remains exact replay/source count and fingerprint identity with zero out-of-order ticks.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260726-051

- Timestamp: 2026-07-26T12:09:04+08:00
- Type: RSB3 Strategy Tester real-tick reconciliation final result
- Status: PASS; DATA-READINESS RECONCILIATION COMPLETE
- Evidence report: `tester_tick_reconciliation_RSB3_REDUCED_20210704_WARMUP_KINGEA_ETHUSD_S_RSB3_2021.07.04_23-59-46.csv`; SHA-256 `2D5D74450DA079B43B68871C043D4727AB355D71C3B4AD3A47359249EE2E9BE0`.
- Registered run: `RSB3_REDUCED_20210704_WARMUP`; `KINGEA_ETHUSD_S_RSB3`; M30; Every tick based on real ticks; tester range 2021-07-01 through 2021-07-05; measurement window 2021-07-04 inclusive through 2021-07-05 exclusive; Demo2 account context; 20 ms execution delay.
- Exact reconciliation: 42,787 replay ticks equal 42,787 source ticks; first timestamp `1625356800520`; last timestamp `1625443186943`; zero out-of-order ticks.
- Exact field identity: replay/source field hash `6161356104117499042`; mix hash `1740263659142147888`; flag hash `5931705584541031751`.
- Tester result: 42,787 ticks and 48 M30 bars generated; final balance unchanged at USD 1,000; no orders or positions.
- Data-readiness conclusion: The accepted RSB3 custom tick history and constructed M1/M30 history replay identically inside MT5 Strategy Tester for the registered window.
- Performance-test authorization: REMAINS DENIED pending the next explicit pre-registration/freeze stage.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260726-052

- Timestamp: 2026-07-26T16:39:15+08:00
- Type: Final RSB3 manifest-gate and Candidate 001 DRAFT tooling preparation
- Status: TOOLING VERIFIED; OWNER MT5 EVIDENCE RUN PENDING
- Read-only MT5 validator: `MQL5/Scripts/KingEA/ValidateRSB3ManifestGate.mq5`; Build ID `RSB3-MANIFEST-GATE-20260726-A`; source SHA-256 `BCD1D5653EF4C811DDF254FB15D2AB3AE11BDA3A89E64F6D5310C104BCD74649`; EX5 SHA-256 `2932EB367748805BC9CD85F051C17DBEFAE76C62A46163CDFE09D63AEDABC387`; MetaEditor result 0 errors and 0 warnings.
- Validator scope: full native/custom population of 327,417,608 ticks; exact two-quote crossed whitelist; timestamp/order and non-flag identity; deterministic `origin_flags & 0xFFFFFF7F` validation on every persisted tick; native Demo2 warm-up export for `[2021-04-01,2021-07-01)`; no custom-history mutation, trading, indicator, return, optimizer, OOS, or holdout APIs.
- Fail-closed finalizer: `data_pipeline/manifest_gate.py`; SHA-256 `FC10B4D24279589E3385EFD8C2AB990CDADCF7F8AD3A9A341F47DC0C24C8F920`. It independently verifies the registered sampled-audit SHA-256, all 60 half-open windows, 400,437 sampled quotes, and names the applicable March 2024 window for each crossed timestamp.
- Registered sampled audit: `history_quality_ETHUSD.s_5Y_2026.07.21_13-28-01.csv`; SHA-256 `96AD33D6F51D61FF9411E0E1BB6012132B0FD4BC534FD7B596E91B32ABA6FA9B`. Automated reconciliation currently confirms both crossed timestamps have `contained_window_count=0`; the applicable interval is `sample_33`, `[2024.03.15 12:00:00,2024.03.15 13:00:00)`.
- Negative regression suite: `tests/test_manifest_gate.py`; SHA-256 `EFB77F57E2B5F84FA5E6C8AEE309485F8520E1A54A9FD2B325DD24D58D386253`. It rejects an extra crossed quote, a missing/altered registered quote, false sample-window non-containment, invalid flag transformation, wrong tick count, non-flag mismatch, backward timestamp, bad audit hash, and failed warm-up; it also parses the exact MT5 report contract.
- Candidate contract: `governance/candidates/CAND-ETH-ST-001_DRAFT.json`; preparation SHA-256 `57E5978FC71AAA45F0AF17063FBAF2060AA0760C3491BE2744CBBDC665BB2074`; status remains DRAFT with data-manifest/configuration hashes pending the final gate.
- Pure signal module: `MQL5/Include/KingEA/CandidateEthSt001.mqh`; SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`. It emits intent only and has no volume, risk approval, order, position, or `MqlTick.flags` capability.
- Candidate contract test: `MQL5/Scripts/KingEA/TestCandidateEthSt001.mq5`; source SHA-256 `F2C60631629AC3EFC2CC485824AF6447D834CC90C6ABF06EEB1BF6AFBF61045C`; EX5 SHA-256 `A3BC243A3B506E50A2E60D798615D5E35B08FF9EA893662F6F5AF7946C42921D`; MetaEditor result 0 errors and 0 warnings.
- Local verification: 15 Python unit tests and seven PowerShell policy suites PASS.
- Operational obstacle: Windows screen capture for the sole verified Demo2 MT5 window failed with `0x80004002`; no blind GUI action was attempted. The owner will run the two non-trading scripts manually.
- V2 data manifest: NOT YET ISSUED. Candidate 001 has not been appended as a formal review DRAFT and cannot become FROZEN until the MT5 gate report passes, hashes are finalized, and the owner explicitly approves.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.
- Reserved candidate status: `CAND-ETH-ST-001` remains NOT FROZEN.

## GOV-20260726-053

- Timestamp: 2026-07-26T16:43:27+08:00
- Type: Final automated RSB3 evidence gate and Candidate 001 DRAFT registration
- Status: DATA MANIFEST ACCEPTED; CANDIDATE DRAFT AWAITS EXPLICIT OWNER FREEZE APPROVAL
- Full-population report: `rsb3_manifest_gate_2026.07.26_08-38-01.csv`; SHA-256 `3E535B43B8B937A62ECA017DAAF1B6D23D3BC5C2577934807427671D21BB0357`; PASS.
- Exact tick result: 327,417,608 compared ticks; 96,218,891 transformed; 231,198,717 unchanged; zero backward timestamps, invalid quotes, count-mismatch days, non-flag mismatches, and invalid flag normalizations.
- Crossed-quote result: both registered native counts equal one; both registered custom counts equal one; unexpected crossed count zero.
- Warm-up artifact: `rsb3_warmup_m30_2026.07.26_08-38-01.csv`; SHA-256 `873D59AB200C9D54EF87075958A678FEC098C8A3CD28ED303278F57AF22D0BD5`; 4,340 of 4,368 expected M30 slots (99.358974%); 545 mechanically derived H4 buckets; no unexplained terminal gap; signal eligibility remains prohibited before 2021-07-01.
- Sampled-audit reconciliation: registered audit SHA-256 `96AD33D6F51D61FF9411E0E1BB6012132B0FD4BC534FD7B596E91B32ABA6FA9B`; 60 half-open windows and 400,437 sampled valid quotes parsed. Each crossed timestamp has `contained_window_count=0`; both name the applicable monthly interval `sample_33`, `[2024.03.15 12:00:00,2024.03.15 13:00:00)`.
- Accepted V2 non-performance manifest: `data/manifest/KINGEA_ETH_NATIVE_SPREAD_BRACKET_EVIDENCE_V2.json`; SHA-256 `0C6FE1ECD3C7B8A491F726A19AD22FFB2DD51DFE44040ACCB1F476ABB0413957`; status `ACCEPTED_NON_PERFORMANCE_DATASET`; performance authorization false.
- Candidate DRAFT: `governance/candidates/CAND-ETH-ST-001_DRAFT.json`; file SHA-256 `6287978BE066360E5C02C24AE3F5BB892C693F21943B1F0EBB800C7F6BE15540`; canonical configuration SHA-256 `D472F7DE4BE9F8D5C64AF5FF9590D6C3E8326BE53CBB12EFF24E9A03C5F8C9F5`.
- Bound source: `MQL5/Include/KingEA/CandidateEthSt001.mqh`; SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`.
- Compilation: full-population validator and deterministic candidate contract test both compile with zero errors and zero warnings.
- Regression result: 16 Python tests and seven PowerShell policy suites PASS, including final manifest/configuration hash binding.
- Candidate state: formally registered as DRAFT. Owner and reviewer remain PENDING; freeze timestamp is null.
- Performance-test authorization: REMAINS DENIED. No result-bearing job may start before explicit owner approval changes this DRAFT to FROZEN and the shared safety kernel is implemented and tested.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.

## GOV-20260726-054

- Timestamp: 2026-07-26T16:54:22+08:00
- Type: Owner-review documentation clarification
- Status: V2.1 DOCUMENTATION REVISION ACCEPTED; CANDIDATE DRAFT HASH SUPERSEDED
- Scope: Documentation only. No native tick, RSB3 tick, M1/M30 bar, mapping boundary, transformed/unchanged count, gate result, partition, strategy rule, parameter, or acceptance criterion changed.
- Superseded immutable manifest: `data/manifest/KINGEA_ETH_NATIVE_SPREAD_BRACKET_EVIDENCE_V2.json`; SHA-256 `0C6FE1ECD3C7B8A491F726A19AD22FFB2DD51DFE44040ACCB1F476ABB0413957`.
- Current manifest: `data/manifest/KINGEA_ETH_NATIVE_SPREAD_BRACKET_EVIDENCE_V2_1.json`; SHA-256 `2C64105609D143C20420B9E33D8A458DFFF7158CEA894C41D31EE16474147206`.
- Sampling-window clarification: `applicable_month_window` identifies the fixed sampling interval assigned to the crossed quote's calendar month for reference. It does not imply containment or identify the crossed event time. Both March 2 events remain outside all 60 sampled intervals; `sample_33` is the March reference interval `[2024.03.15 12:00:00,2024.03.15 13:00:00)`.
- Flag-normalization sanity evidence: `persisted_flag_normalization_2026.07.23_14-21-50.csv`; SHA-256 `ABEC9F5A82BA40B171ECD54AAEFF4EDD9665A5B9F97CBB7E3DFD7C45A5251B46`. The full-population changed-flag rate is 272,867,308 / 327,417,608 = 83.339228%; it is bracketed by the transformed-day reference sample 146,415 / 173,712 = 84.286060% and unchanged-day reference sample 221,862 / 270,610 = 81.985884%. Both samples had zero non-flag mismatches and every flag change was exactly bit 128 clearing.
- Current Candidate 001 DRAFT: `governance/candidates/CAND-ETH-ST-001_DRAFT.json`; file SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; canonical configuration SHA-256 `A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE`.
- Binding: Candidate 001 now references V2.1 SHA-256 `2C64105609D143C20420B9E33D8A458DFFF7158CEA894C41D31EE16474147206`; the prior configuration hash `D472F7DE4BE9F8D5C64AF5FF9590D6C3E8326BE53CBB12EFF24E9A03C5F8C9F5` is superseded and must not be approved.
- Regression: `tests/test_candidate_draft.py`; SHA-256 `EB417630AE013E1486633CE94C06020855C89934996D44B6A80366BDEAF1BD39`; verifies the manifest hash, canonical configuration hash, containment clarification, and registered normalization evidence. All 16 Python tests PASS.
- Candidate status: DRAFT; explicit owner approval remains pending.
- Performance-test authorization: REMAINS DENIED.
- OOS/holdout exposure: NONE.
- Candidate-budget consumption: 0.

## GOV-20260726-055

- Timestamp: 2026-07-26T18:50:59+08:00
- Type: Candidate 001 explicit owner approval and immutable freeze
- Status: `CAND-ETH-ST-001` FROZEN
- Owner approval received verbatim: `I explicitly approve CAND-ETH-ST-001 configuration A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE for FROZEN status.`
- Approved configuration SHA-256: `A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE`.
- Immutable reviewed DRAFT: `governance/candidates/CAND-ETH-ST-001_DRAFT.json`; SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`.
- Freeze certificate: `governance/candidates/CAND-ETH-ST-001_FREEZE.json`; SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Data manifest binding: `data/manifest/KINGEA_ETH_NATIVE_SPREAD_BRACKET_EVIDENCE_V2_1.json`; SHA-256 `2C64105609D143C20420B9E33D8A458DFFF7158CEA894C41D31EE16474147206`.
- Signal source binding: `MQL5/Include/KingEA/CandidateEthSt001.mqh`; SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`.
- Transition rule: The reviewed DRAFT remains byte-for-byte unchanged. The separate certificate records the governance-state transition without recomputing or replacing the owner-approved configuration hash.
- Authorized next work: shared safety-kernel implementation and non-performance contract testing.
- Still prohibited: performance testing, optimization, formal OOS exposure, untouched holdout access, and live or demo order placement.
- Regression: 17 Python tests and seven PowerShell policy suites PASS after freeze binding.
- Candidate-budget consumption: 0; consumption begins only when a separately authorized first result-bearing run changes the frozen candidate to RUNNING.

## GOV-20260726-056

- Timestamp: 2026-07-26T19:34:57+08:00
- Type: Shared safety-kernel implementation and deterministic non-performance validation
- Status: PASS; SAFETY KERNEL COMPLETE; PERSISTENCE/WATCHDOG STAGE AUTHORIZED
- Interface: `KingEAEvaluateSafety(request, facts, prior_state, decision)` is the sole public evaluation interface. It is pure and returns an action plan plus next in-memory state.
- Kernel source: `MQL5/Include/KingEA/SafetyKernel.mqh`; SHA-256 `9408695C19DD52F1B663BE3DEC35A2885EFD6FC83948B1166F7E4A08F6216767`.
- Frozen safety contract: `governance/SAFETY_KERNEL_CONTRACT.md`; SHA-256 `435F2994B259B222A827818CAC6BCF9DD63E28EF8D426CDC93323DC15EB81F75`.
- Fixed policy: 3% account daily breaker; 6%/10%/20% account weekly/monthly/all-time; 4%/7%/12% sleeve weekly/monthly/all-time; 1.50% cluster and 2.20% portfolio caps; 50% breaker-headroom limit; 500% stressed margin-level floor; 80% stressed free-margin/equity floor; internally calculated 1:200 HMR proxy.
- Recovery policy: five consecutive clean broker days at half risk; throttle activation disqualifies the day; first recovery throttle resets the streak; second latches review and forces an approved restart to 0.25%; third weekly breaker within rolling 90 broker days latches cumulative review; successful review archives the active set and starts a fresh escalation epoch.
- Kernel hardening: non-finite facts and inconsistent state fail closed; intraday health failures persist through the broker-day boundary; protected profit receives zero risk-cap credit; unknown clustering defaults portfolio exposure to correlated; infeasible 50% emergency reductions flatten rather than weaken broker volume rules; daily resets never erase weekly loss.
- Test source: `MQL5/Scripts/KingEA/TestSafetyKernel.mq5`; SHA-256 `6D727DAF6AD655D67B1E745BE51FB3B06806F3E4323114DDE167970843C75B49`.
- Compiled EX5: SHA-256 `A3E2E28186C4352590EB9E7E9C1B151C4A51099FDA8B191E7C9AA639736981D9`.
- Compile evidence: `MQL5/Scripts/KingEA/safety_kernel_test_compile.log`; SHA-256 `D83C51358355727DE3A72649BEC3B76B35C60A2348E3E25A2B8697F749B5B4EA`; MetaEditor result 0 errors and 0 warnings.
- Runtime configuration: `config/safety_kernel_contract_run.ini`; SHA-256 `599E24D860CAF19E65FDBE818F1978254262C66EFB1D63726C07F6C240024CDA`; `AllowLiveTrading=0`; automatic terminal shutdown enabled.
- Runtime evidence: `safety_kernel_contract_2026.07.26_11-33-22.csv`; SHA-256 `8A3282C1C0B435885CEF2011D32254F818C90F4EA9F9F50DDAE71962EA024CFF`; PASS with 44 checks and zero failures; order capability `PROHIBITED_AND_ABSENT`.
- Static policy: `tests/Test-SafetyKernelPolicy.ps1`; SHA-256 `61394E70DA74FB7955101060D199A45840A9D85F19A0826B84409A569FEEBEB6`; PASS. The kernel contains no order, position, history, indicator, tester-statistics, performance, or `MqlTick.flags` APIs.
- Repository regression: 17 Python tests and eight PowerShell policy suites PASS.
- Candidate immutability proof: `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Next authorized work: persistent safety state, configuration versioning, and watchdog protocol only.
- Performance testing, optimization, formal OOS/holdout access, and live or demo order placement: REMAIN PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260726-057

- Timestamp: 2026-07-26T20:45:39+08:00
- Type: Manual-review bottom-tier persistence clarification and executable regression
- Status: PASS; SAFETY-KERNEL STAGE CLOSED; PERSISTENCE/WATCHDOG STAGE REMAINS AUTHORIZED
- Deliberate invariant: `MANUAL_REVIEW_APPROVED` releases the manual-review halt but does not clear `force_bottom_tier`. The affected sleeve remains capped at the 0.25% bottom tier across broker-day and broker-week transitions.
- Clearing authority: only the separately governed 30-trade/30-day tier-advancement process may clear the bottom-tier pin. Approval itself never restores the previously earned tier.
- Kernel behavior: unchanged. `MQL5/Include/KingEA/SafetyKernel.mqh` remains SHA-256 `9408695C19DD52F1B663BE3DEC35A2885EFD6FC83948B1166F7E4A08F6216767`.
- Contract clarification: `governance/SAFETY_KERNEL_CONTRACT.md`; SHA-256 `E59C45C8CA54429390A95D96FDFDD381475555C8D0891FA92DBC31A88747258B`.
- Executable assertion: `MQL5/Scripts/KingEA/TestSafetyKernel.mq5`; SHA-256 `59FC0C37191F80E9C0BEB0B64019BDF439162F0713F164B14818DB73840FDF67`; explicitly verifies that the bottom-tier pin survives the required broker-day transition after approval.
- Compiled EX5: SHA-256 `AB940E67BE4EB85B09C76E02316836B44951BA67ABCE3E172039069D8ADB84AB`.
- Compile evidence: `MQL5/Scripts/KingEA/safety_kernel_test_compile.log`; SHA-256 `B14AD6E254FBB2C10922AB6A1668D65EDC1249D7C35A96553A56CDA1FCF7AD2B`; MetaEditor result 0 errors and 0 warnings.
- Runtime evidence: `safety_kernel_contract_2026.07.26_12-45-39.csv`; SHA-256 `CBF3A38A6C2E1B42D56F244BB69C6CE8BB1D1BCF0D89C52ED07D4769E813AEBB`; PASS with 45 checks and zero failures; order capability `PROHIBITED_AND_ABSENT`.
- Static policy: `tests/Test-SafetyKernelPolicy.ps1`; SHA-256 `61394E70DA74FB7955101060D199A45840A9D85F19A0826B84409A569FEEBEB6`; PASS.
- Repository regression: 17 Python tests and eight PowerShell policy suites PASS.
- Candidate immutability proof: `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Next authorized work: persistent safety state, configuration versioning, and watchdog protocol only.
- Performance testing, optimization, formal OOS/holdout access, and live or demo order placement: REMAIN PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260727-058

- Timestamp: 2026-07-27T23:59:14+08:00
- Type: Stage 7 persistent state, configuration versioning, broker reconciliation, watchdog, and kill-switch interlock
- Status: PASS; STAGE 7 COMPLETE; STAGE 8 SPECIFICATION-CHANGE DETECTION AUTHORIZED
- Operational contract: `governance/OPERATIONAL_SAFETY_CONTRACT.md`; SHA-256 `DA885E3A6E9D2E7E46D03CDD1891FFFD4CF66F7822A5FB62DC3DCB565CAF8847`.
- Persistence/configuration module: `MQL5/Include/KingEA/OperationalSafety.mqh`; SHA-256 `B6178D0A660523DEFEF67361A04650411AA4B347C6F218F01C4F37C75B719468`. It implements redundant SHA-256 A/B snapshots, temporary-write/flush/readback/move commits, rollback and identity checks, diagnostic-only redundancy, authorized flat genesis, configuration epochs, exact inventory comparison, and canonical heartbeat publication.
- Read-only broker adapter: `MQL5/Include/KingEA/BrokerInventoryAdapter.mqh`; SHA-256 `58D4F30E3DDC7C4070245651025609ACC46F7AA435D652B5E1CC4FA5AD52D3C7`. It captures account identity plus ticket-level positions and pending orders and requires `KINGEA|<sleeve_id>|<trade_group>` ownership; it has no trading capability.
- MQL5 contract harness: `MQL5/Scripts/KingEA/TestOperationalSafety.mq5`; SHA-256 `E9DC24C7D2330DC3A8A8A6948852DE447099B32F4038EE8B452CA0B468D71840`.
- Compiled EX5: SHA-256 `A807513D1A33A6B114AD2FBF33F2D5EF50EABB298A8C43CC54E7184EF2C0B11B`.
- Compile evidence: `MQL5/Scripts/KingEA/operational_safety_test_compile.log`; SHA-256 `3D72416338FF889A21F882ECFB101638F1EA94519C8D75859C82E8D07C5E91A4`; MetaEditor result 0 errors and 0 warnings.
- Runtime evidence: `operational_safety_contract_2026.07.27_15-57-53.csv`; SHA-256 `FB3C7B3D93132D21389C6A42B046856D7628EA02F7BC2E05515D33CF0D1EB333`; PASS with 20 checks and zero failures; order capability `PROHIBITED_AND_ABSENT`.
- Runtime configuration: `config/operational_safety_contract_run.ini`; SHA-256 `16ACEB02155BC101EE125852EB625C4AFE65F321910DD68A91E3CC51A3855706`; `AllowLiveTrading=0`, `AllowDllImport=0`, and automatic terminal shutdown enabled.
- Watchdog policy module: `operations/KingEAWatchdog.psm1`; SHA-256 `9B16BDFC4FDCDECA02C1AEB66FD9832F53748FF11A9E8662978A8705EC2226DC`.
- Watchdog runner: `operations/KingEAWatchdog.ps1`; SHA-256 `06FF8FB5049A12176EF6F1D0FA0B9CDA21E0E9CC8F1339CA51ED86A1B72136E6`. It rechecks standdown before launch, binds any process close to exact executable, heartbeat PID, and data-root identity, and treats missing or corrupt watchdog state as disarmed reconciliation-required review.
- Standdown helper: `operations/Set-KingEAStanddown.ps1`; SHA-256 `5564F26867F745F15D4477551BEBBE41BC92BA19F71AE822A64B3B8DADBAC7EC`.
- Kill-switch runbook: `operations/KILL_SWITCH_RUNBOOK.md`; SHA-256 `E6714374AD7E88ABF7B89692FC00FB0B59AD57968B5EF65A6F95E6465B6A9B93`. The numbered procedure now requires a verified standdown latch or independent watchdog shutdown before MT5 is stopped.
- Disabled watchdog configuration: `config/watchdog.demo2.disabled.json`; SHA-256 `4377B6FCCB83DFB0E69D3A646089035149E0FDAF62E9464E8D2CDD7058AC05E9`; `Enabled=false` and `InstallScheduledTask=false`.
- Watchdog deterministic suite: `tests/Test-KingEAWatchdog.ps1`; SHA-256 `B8A759F7228291E402C661BE4D0E8244E3D86657167313D2DDF1BCBC3AB5B041`; PASS for initial restart, short-window review, retained 30-day evidence, slow cadence, mixed cadence, simultaneous thresholds, cumulative epoch reset, 24-hour rearming, standdown race, malformed latch, atomic state, heartbeat integrity, exact process identity, and the independent helper.
- Static policy suite: `tests/Test-OperationalSafetyPolicy.ps1`; SHA-256 `1B11DEAEB7E43BEEDD17E488880E6B489B66A63690A3000046630BBDBADEE9EA`; PASS.
- Repository regression: 17 Python tests and ten PowerShell policy/contract suites PASS.
- Operational activation proof: no KingEA Windows scheduled task exists; no MT5 process remains running after the contract test; the watchdog exits disabled without monitoring or restart activity.
- Prohibition proof: Stage 7 MQL5 and PowerShell artifacts contain no order-submission, position-modification, strategy-history, indicator, performance, optimizer, OOS/holdout, DLL, network, or `MqlTick.flags` capability.
- Candidate immutability proof: `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Next authorized work: Stage 8 live structural specification-change detection and the pause/revalidation workflow only.
- Performance testing, optimization, formal OOS/holdout access, watchdog activation, scheduled-task installation, and live or demo order placement: REMAIN PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260728-059

- Timestamp: 2026-07-28T09:52:41+08:00
- Type: Stage 8 structural symbol-specification monitor, read-only Demo2 adapter, and pause/revalidation workflow
- Status: PASS; STAGE 8 IMPLEMENTATION COMPLETE; BASELINE ACTIVATION LOCKED; STAGE 9 INDEPENDENT KILL-SWITCH DRILL AUTHORIZED
- Specification contract: `governance/SPECIFICATION_MONITOR_CONTRACT.md`; SHA-256 `186034A2BC7BD90C55D609C52D2AF4579E27BEE05D2B10E4DA947E23B47691F2`.
- Pure monitor module: `MQL5/Include/KingEA/SpecificationMonitor.mqh`; SHA-256 `F702D1958C2F76383FDAAA8D439DEBF96AD4C519BF8CE2881E79D81C2F0EEC9B`. `KingEAEvaluateSpecification(approved, observed, request, prior, decision)` is the sole evaluation interface.
- Read-only broker adapter: `MQL5/Include/KingEA/SymbolSpecificationAdapter.mqh`; SHA-256 `E3494F7940C4361F94C0E69338C9FAB74FFB8089C2246839723D7CB4EFFF7494`. It captures symbol, account, margin, and normalized session facts and uses only `OrderCalcProfit` and `OrderCalcMargin` as calculators.
- Deterministic harness: `MQL5/Scripts/KingEA/TestSpecificationMonitor.mq5`; SHA-256 `F983F8820B66A61B5A749D4197DA3675D6D231C6639E2D274B9959514D1B34FE`; compiled EX5 SHA-256 `BBCECC00D74FB84102FA8AF531D5BF68DE03CE0BE533B3BF86D9D204CE5543E1`.
- Deterministic result: `specification_monitor_contract_2026-07-28_01-50-52.csv`; SHA-256 `9A864FA6E0AF67B5136D5BF693ABE21CC363C7CACB0415709531AA2DC4358C91`; PASS with 27 checks and zero failures.
- Contract compilation: `MQL5/Scripts/KingEA/specification_monitor_test_compile.log`; SHA-256 `4009B23BEE7C1578E6986DE88D33A88801D4E0A4074A75A362EC0BFDAA56E600`; MetaEditor result 0 errors and 0 warnings.
- Demo2 observer: `MQL5/Scripts/KingEA/ObserveSpecificationMonitor.mq5`; SHA-256 `E1BABB2E23647CB1997EE5E321B0A9946AB5135CF01866B3B7792E04A206F101`; compiled EX5 SHA-256 `6011815E2CE3AB97156BACF92B49DCB959BA553B5B1B8BCEC4C55DFE0BD75C55`; compile-log SHA-256 `33DA160E51302A7CA3F071CA1404E3ADF18B52F7FC48488D82E6977F248A9060`; 0 errors and 0 warnings.
- Guarded Demo2 observation: `stage8_spec_observation_ETHUSD.s_2026.07.28_01-46-21.csv`; SHA-256 `5684396DE064843ED30854BCDCA5CA417B42041F00F90707751569F872ACBA6E`; server `JustMarkets-Demo2`; canonical specification SHA-256 `80B1088172CF232B585CBE41B83D5CE932DD31C91227EF1907CDA85698BB8246`; reported/calculated tick values both `0.01`; order capability absent.
- Draft specification manifest: `governance/specifications/ETHUSD.s_DEMO2_DRAFT.json`; SHA-256 `BD2E59CF90308F0693BAF6D520358E97316989053B74C5ABC4A0947C8AB9477D`; status `DRAFT_NON_DEPLOYABLE`; owner approval pending.
- Draft deployment binding: `governance/deployments/KINGEA_DEMO2_STAGE8_DRAFT.json`; SHA-256 `264EC5BB7971C27E796CA6C11D4036FD91CBFFFB84168A2171CD32FD0997DED2`; `approved_specification_sha256` remains null, so it cannot activate or authorize entry.
- Locked classification: every unreviewed change blocks entry; proved administrative changes may preserve the earned tier; ambiguous changes promote to risk-critical; confirmed risk-critical replacement resets the affected sleeve to 0.25% and restarts 30-trade/30-day validation.
- Locked confirmation: a return-to-baseline second capture starts a new 60-second scheduled-poll requirement; an immediate third read cannot clear it; late, missing, invalid, or inconsistent scheduled evidence restarts the timer; differing changed captures quarantine as unstable.
- TDD defects caught and corrected: semantic float equivalence now produces the same canonical hash; the MT5 tick-value calculator probe uses a normalized one-lot diagnostic volume to avoid minimum-lot currency rounding; duplicate approved sessions fail closed; loosened margin terms cannot be classified as HMR; startup readiness waits are bounded and continuously recheck Demo2 identity.
- Static policy: `tests/Test-SpecificationMonitorPolicy.ps1`; SHA-256 `D28F6200912F76689A434FD8CB87DE26C9491EA150774A8F1AE0B2CD9D93FBAD`; PASS.
- Repository regression: 17 Python tests and 11 PowerShell policy/contract suites PASS.
- Candidate immutability proof: `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Runtime safety: both configurations set `AllowLiveTrading=0` and `AllowDllImport=0`; MT5 shut down after each run; no watchdog or scheduled task was activated.
- Next authorized work: Stage 9 independent kill-switch drill only.
- Performance testing, optimization, formal OOS/holdout access, baseline activation, watchdog activation, scheduled-task installation, and live or demo order placement: REMAIN PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260728-060

- Timestamp: 2026-07-28T20:43:02+08:00
- Type: Stage 9 independent Demo2 kill-switch drill
- Status: PASS; STAGE 9 COMPLETE; DEPLOYMENT REMAINS QUARANTINED
- Scope: exactly one manually created `0.01` ETHUSD.s Buy with broker-side SL and one manually created `0.01` ETHUSD.s Buy Limit with broker-side SL and GTC fallback on `JustMarkets-Demo2`. No order-capable code was created or used.
- Identity handling: the governance record contains only account suffix `1768` and SHA-256 fingerprint `5A8ADD88286A10EECC859B5683273841D7DB17DE364C0F0AEF33CFEF5F36E8C2`; no raw account login is stored.
- Fixture proof: read-only inventory captured position ticket `2218842114`, Buy `0.01`, entry `1876.28`, SL `1783.23`, and pending ticket `2218850445`, Buy Limit `0.01`, entry `1501.66`, SL `1426.58`, GTC. Both remained active until the owner acted from the separate mobile device.
- Resolution proof: the owner manually closed the entire position and manually deleted the pending order from MT5 mobile. Mobile and desktop independently showed zero positions and zero orders; the final guarded broker capture confirmed zero/zero.
- Standdown: `KINGEA-DEMO2-001` manual standdown was created before automation shutdown; SHA-256 `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; it remains active.
- Watchdog proof: one foreground `KingEAWatchdog.ps1 -Once` evaluation emitted `STANDDOWN / MANUAL_STANDDOWN_ACTIVE`; hashed outbox SHA-256 `0E80BE51EE0D4A4CC9C12C0A19BF8631F705FB6852DD6D391A902534F11319CF`; no process close, restart, or terminal launch occurred; the ephemeral enabled configuration was hashed and removed.
- Automation shutdown: the toolbar and Tools -> Options -> Expert Advisors controls both showed algorithmic trading disabled; DLL and WebRequest permissions were also off; the owner confirmed no MetaTrader VPS or duplicate terminal.
- Shutdown proof: MT5 remained absent for a measured 76-second observation; final `terminal64.exe` count 0; KingEA scheduled-task count 0; standdown remained hash-valid.
- Evidence record: `governance/drills/DRILL-DEMO-001.json`; SHA-256 `5EE6023591D9C597087422AB1235E45D137063ADAA50B00CF5F5221417482D65`; deterministic verifier result `PASS`.
- Read-only inventory source: `MQL5/Scripts/KingEA/CaptureKillSwitchInventory.mq5`; SHA-256 `DBBD07CF6F29F2CEAD3676E83CDCC7BEADE6E98F538FBD7E4ABE826F4D13E1B0`; compiled EX5 SHA-256 `EF90D6A53F654A54F0FEBA804C8DC30FF46C7FE6BAD86DA831A619C6CBAF257B`; compile-log SHA-256 `F69DDD3011EFF099A0D9E978C5EC34E19313BF146F23C0D92F7DFB52A86AEE4A`; MetaEditor result 0 errors and 0 warnings.
- Evidence verifier: `operations/KillSwitchDrillEvidence.psm1`; SHA-256 `A67CC033A97D4242DB80C9DA6A1CB964A30BBCAACB2EE3D942CC93521DBD74E5`.
- Deterministic negative suite: `tests/Test-KillSwitchDrillEvidence.ps1`; SHA-256 `8BEE304D6C5D45BDA0CC34B533CBB9A9C00F5BE13BAACC9BC5E17E31A7E9C852`; PASS for short expiry, self-resolved fixtures, restart-after-standdown, nonzero final inventory, and raw-login rejection.
- Static policy suite: `tests/Test-KillSwitchDrillPolicy.ps1`; SHA-256 `4C00DE361F56EA0AE399DCB1AD3717E244180E8E8C5309D3D12C419ADCA09ACC`; PASS for Demo2 guarding, exact bounded inventory, disabled watchdog, redacted identity, and absence of automated-order/history/indicator/performance/network/DLL capability.
- Runbook: `operations/KILL_SWITCH_RUNBOOK.md`; SHA-256 `65696739FE4E7683E89E7CC6C436BD5D86E9DC8740CE096FFA874D0B6D950A55`; platform-reference verification date updated to 2026-07-28 and the PASS record appended.
- Repository regression: 17 Python tests and 13 PowerShell policy/contract suites PASS.
- Candidate immutability proof: `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Residual state: MT5 is closed; Algo Trading remains disabled; watchdog remains disabled/uninstalled; the standdown latch remains active. Clearing quarantine requires separate broker reconciliation, documented review, and explicit owner approval.
- Next authorized work: none beyond read-only review and planning until the owner approves a new stage.
- Performance testing, optimization, formal OOS/holdout access, baseline activation, watchdog activation, scheduled-task installation, additional demo orders, and all Live2 access/order activity: PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260729-061

- Timestamp: 2026-07-29T18:44:25+08:00
- Type: Stage 10 deterministic regime classification and correlation clustering
- Status: PASS; STAGE 10 COMPLETE; STAGE 11 FROZEN SLEEVE-1 INTEGRATION AUTHORIZED
- Market-context contract: `governance/MARKET_CONTEXT_CONTRACT.md`; SHA-256 `E7D2D0C9FAA5FEB76EF106EDCAE324F27F4F53EB1C5CB3D80C96C888754E25F8`.
- Pure regime module: `MQL5/Include/KingEA/RegimeClassifier.mqh`; SHA-256 `AF7F2C81C87DDC4CE52A04E052B114515E11B46FF13FC2612C48433F77ECC057`. `KingEAEvaluateRegime(bars, request, prior, decision)` is the sole interface and internally calculates Wilder ATR(14), ADX(14), the strict-less 90-calendar-day normalized-ATR percentile, and two-observation trend/volatility hysteresis.
- Pure correlation module: `MQL5/Include/KingEA/CorrelationClustering.mqh`; SHA-256 `B12EC50DA690AACB792B09C6BE88AB98DBE82FD5AD4D651F25AB5500224CCD43`. `KingEAEvaluateCorrelation(request, prior, decision)` is the sole interface and internally calculates aligned D1 log returns, 60/20-day Pearson correlations, conservative edge state, ten-day release state, and deterministic transitive clusters.
- Operational registration: only `ETHUSD.s`, yielding a healthy singleton. Synthetic `SYNTH-B` and `SYNTH-C` exist only inside deterministic fixtures; no future production symbol or static override is registered.
- Frozen boundaries: volatility normal below 80, high from 80 through 95 inclusive, and extreme above 95; current observation excluded; ties excluded from the strict-less numerator; coverage floor 4,104 of 4,320 ETHUSD.s M30 slots; trend entry/exit thresholds 25/20 with two-observation hysteresis.
- Correlation boundaries: dynamic edge at absolute 60-day correlation at least 0.60 or absolute 20-day correlation at least 0.70; exact 0.45 retains an existing edge; release requires both values strictly below 0.45 for ten distinct closed-day evaluations; invalid facts emit an active conservative edge and `cluster_known=false`.
- Deterministic harness: `MQL5/Scripts/KingEA/TestMarketContext.mq5`; SHA-256 `1B1A281AB0FB8F076FD4602224132E208B1B6D8BD66AD7AE25564D20F635956F`.
- Compiled EX5: SHA-256 `6153C2F7F8BE942385178262D0BF4F25A624494F9558B8BBEE58E7B91166AA08`.
- Compile evidence: `MQL5/Scripts/KingEA/market_context_test_compile.log`; SHA-256 `E5A74CF36649126FA2A87761DFAC7AE7AC4F90DBF687A1E17584938F08B67638`; MetaEditor result 0 errors and 0 warnings.
- Runtime configuration: `config/market_context_contract_run.ini`; SHA-256 `F2712340447404DE3B7F91F41B32C12B7C007625393D5A6573A75A2350F7DB36`; `AllowLiveTrading=0`, `AllowDllImport=0`, and automatic terminal shutdown enabled.
- Runtime evidence: `market_context_contract_2026-07-29_10-43-10.csv`; SHA-256 `42388472088B3FEB56B8A166E304389FF4D4867E82E2A231E268B7261734EC55`; PASS with 46 checks and zero failures; order capability `PROHIBITED_AND_ABSENT`; performance authorization denied.
- TDD defects caught and corrected before acceptance: same-decision state aliasing in the harness; a nominal range fixture whose unchanged highs/lows produced undefined directional movement; floating-point exclusion at the exact positive and negative 0.60 edge; and algebraically equal normalized-ATR values requiring deterministic tie tolerance.
- Static policy: `tests/Test-MarketContextPolicy.ps1`; SHA-256 `764E5DC91C89F221A46B8D9915E7513DF5239610A3028C32A854CE16DC8E6A1E`; PASS for deep-interface count, exact frozen boundaries, fail-safe synthetic symbols, prohibited APIs, Stage 9 quarantine, and frozen-candidate immutability.
- Repository regression: 17 Python `unittest` tests and 14 PowerShell policy/contract suites PASS.
- Candidate immutability proof: `CandidateEthSt001.mqh` remains SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`; `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Residual safety state: MT5 process count 0; KingEA scheduled-task count 0; watchdog disabled/uninstalled; Stage 9 standdown hash remains `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; deployment remains quarantined.
- Next authorized work: Stage 11 implementation of the already-frozen Sleeve 1 strategy behind the common sleeve interface only.
- Optimization, strategy-performance backtests, formal OOS/holdout access, demo orders, Live2 activity, watchdog activation, standdown removal, and new candidate-budget consumption: REMAIN PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260730-062

- Timestamp: 2026-07-30T19:56:48+08:00
- Type: Stage 11 frozen Sleeve 1 deterministic integration
- Status: PASS; STAGE 11 COMPLETE; STAGE 12 PIPELINE IMPLEMENTATION AUTHORIZED
- Sleeve contract: `governance/SLEEVE_ETH_ST_001_CONTRACT.md`; SHA-256 `1AA6EA8906084448865C13E2645A901E8FE6ED569661D22C1E91BBFF613D3404`.
- Deep sleeve module: `MQL5/Include/KingEA/SleeveEthSt001.mqh`; SHA-256 `CC8434DCD0815339DBA5A6816FA2D6635122ED5725D372B9B0206DBB9F623AAA`. `KingEAEvaluateSleeveEthSt001(bars, request, prior, decision)` is the sole interface and hides frozen-grid validation, Wilder ATR, canonical Supertrend, H4 aggregation, breakout windows, Stage 10 mapping, closed-bar position progress, and signal consumption.
- Frozen delegation: final entry/exit/hold intent is delegated to the unchanged `CandidateEthSt001.mqh`; no volume, risk approval, broker history, execution, ranking, or performance field exists in the sleeve interface.
- Frozen conventions: H4 buckets start at server-time 00:00/04:00/08:00/12:00/16:00/20:00; Supertrend and breakout comparisons are strict and symmetric; equality never flips or breaks out; original R never moves; MFE uses only fully closed bars strictly after the entry signal bar.
- Signal expiry: every well-formed new M30 bar is consumed before downstream warm-up, parameter, regime, or other gates; duplicate/backward evaluations cannot emit intent; blocked signals are never queued.
- Deterministic harness: `MQL5/Scripts/KingEA/TestSleeveEthSt001.mq5`; SHA-256 `E92C0CDCE143C4555560FBDFBA2E5B2EE187AAF995516A7E4EE05B89B12C5801`; compiled EX5 SHA-256 `39402A24D789D62F1E37C661EE124E6D72BFC1CF5768E506506D60E505B22736`.
- Compile evidence: `MQL5/Scripts/KingEA/sleeve_eth_st_001_test_compile.log`; SHA-256 `A44D2D9621478BAF5BE9F5A14C63E53B51AC3EB13B43F9FAA55F06E7B28F8C61`; MetaEditor result 0 errors and 0 warnings.
- Runtime configuration: `config/sleeve_eth_st_001_contract_run.ini`; SHA-256 `E55FFB6C1E935083171899FB0F70304A57C3BB8EDC23651993995B77C657C0F1`; `AllowLiveTrading=0`, `AllowDllImport=0`, and automatic terminal shutdown enabled.
- Runtime evidence: `sleeve_eth_st_001_contract_2026-07-30_11-54-28.csv`; SHA-256 `C2E7A41D8579DAA3C6F3A72C19064637BAA0E824FDAEE0037D0D269AABF8E95C`; PASS with 32 checks and zero failures; candidate budget 0; order capability absent; performance authorization denied.
- Grid proof: all 19,440 frozen configurations were accepted as non-performance contract inputs; representative off-grid and non-finite values fail closed.
- Behavioral proof: deterministic long/short intent, Wilder ATR trace, server-aligned H4 confirmation, incomplete-bucket exclusion, breakout-window exclusion, regime observation matching, one-group protection, warm-up isolation, exact checkpoint/max-holding boundaries, fixed-original-R MFE, malformed-input rejection, and consumed-signal expiry all passed.
- Static policy: `tests/Test-SleeveEthSt001Policy.ps1`; SHA-256 `B6B127FC1C2B451D4874BD13AC7D56FAB1970ACB6226E3FBE14049AAA2474614`; PASS for the one-interface seam, frozen conventions, exact grid, no other sleeve family, immutable artifacts, quarantine, and prohibited capabilities.
- Repository regression: 17 Python `unittest` tests and 15 PowerShell policy/contract suites PASS.
- Candidate immutability proof: `CandidateEthSt001.mqh` remains SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`; `CAND-ETH-ST-001_DRAFT.json` remains SHA-256 `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Residual safety state: MT5 process count 0; KingEA scheduled-task count 0; watchdog disabled/uninstalled; Stage 9 standdown remains active with SHA-256 `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; deployment remains quarantined.
- Next authorized work: Stage 12 pipeline implementation only.
- Optimization, performance backtests, formal OOS/holdout access, demo orders, Live2 activity, watchdog activation, standdown removal, and new candidate-budget consumption: REMAIN PROHIBITED.
- Candidate-budget consumption: 0.

## GOV-20260730-063

- Timestamp: 2026-07-30T19:59:10+08:00
- Type: Stage 11 additive verification enhancement; references `GOV-20260730-062`
- Status: PASS; STAGE 11 COMPLETION UNCHANGED
- Reason: the deterministic harness was extended after the initial PASS with an explicit non-finite parameter rejection. The original 32-check evidence remains retained; this record identifies the final 33-check artifacts.
- Final harness: `MQL5/Scripts/KingEA/TestSleeveEthSt001.mq5`; SHA-256 `690E553DEF009E80A9DB53240059D2F7EEDE0B9F36CFC6E0BA78F161D4FE72EC`; compiled EX5 SHA-256 `14561EEC2AA9593B7B55A06A886E84A749879CD6AC1936F2F2CD09240613F155`.
- Final compile evidence: `MQL5/Scripts/KingEA/sleeve_eth_st_001_test_compile.log`; SHA-256 `26F23C20C75E7D47AA49F73FA35771004745A13C82DED33C1A88C647F719722B`; MetaEditor result 0 errors and 0 warnings.
- Final runtime evidence: `sleeve_eth_st_001_contract_2026-07-30_11-59-10.csv`; SHA-256 `D610DB191B9ADF2C6E4D7FAEE215A98A51FDF5C117FE21E997044B6240C69F65`; PASS with 33 checks and zero failures.
- Final static policy: `tests/Test-SleeveEthSt001Policy.ps1`; SHA-256 `C192464C626A9CFC1FD780FE9DEFB225DA5977D806712CBB01CC3F4546013694`; PASS and now requires the 33-check report plus explicit non-finite rejection.
- Repository regression rerun: 17 Python `unittest` tests and all 15 PowerShell policy/contract suites PASS.
- Frozen artifacts, Stage 9 standdown, quarantine, prohibited capabilities, candidate-budget count, and Stage 12-only authorization remain exactly as recorded in `GOV-20260730-062`.

## GOV-20260731-064

- Timestamp: 2026-07-31T20:59:33+08:00
- Type: Stage 12 guarded real-tick research, walk-forward, stress, surface, and Monte Carlo pipeline implementation
- Status: PASS; STAGE 12 IMPLEMENTATION COMPLETE; NO RESULT-BEARING RUN PERFORMED; STAGE 13 ACCOUNTING/EXPORT IMPLEMENTATION AUTHORIZED
- Contract: `governance/STAGE12_RESEARCH_PIPELINE_CONTRACT.md`; SHA-256 `975C590FFF2E1099E6EE6C23C9DDE674F8F3FCEDF58F9056BDEFAD3D3FC2A606`.
- Pure tester-execution seam: `MQL5/Include/KingEA/ResearchExecution.mqh`; SHA-256 `0431A5162DDEE001FD21A5CBFB099C44B33BC4C0D90D749B79930BCACE177D89`. It owns frozen ID decoding, complete authorization facts, deterministic spread/cost/slippage transforms, and seeded missed-entry decisions without terminal I/O or order capability.
- Guarded Strategy Tester EA: `MQL5/Experts/KingEA/GuardedResearchTester.mq5`; SHA-256 `EE48EBB11D24AA3DE7417D4BBBAE018759C78D433A69329528A47005C2AB1621`; compiled EX5 SHA-256 `601F734CCEF15E4D6215482A7902C53D8BC07C6AF5508DAAA3F2CD81716FA362`.
- Tester compile evidence: `MQL5/Experts/KingEA/guarded_research_tester_compile.log`; SHA-256 `BD857836F2225DA212211E6084F38E449E817F26CB0D16CFF7C589DF59C10EFE`; MetaEditor result 0 errors and 0 warnings. The EA was compiled only and never run against broker history.
- Guard proof: the sole Stage 12 `OrderSend` call sits behind immediate tester/model/local-agent, canonical-manifest, physical-file-hash, detached-token, purpose, branch, and partition revalidation. OOS requires immutable selection/surface hashes; holdout requires a Stage 15 authorization hash.
- Adapter behavior: internal Bid M30 construction invokes the frozen Stage 10 classifier, Stage 11 sleeve, and shared safety kernel. Entry carries the broker-side stop in the same request; no fixed TP, partial exit, add-on, averaging, hedge, or stop-widening path exists. Net trade returns, fixed-risk R values, and broker-calendar daily returns are emitted in the single completion frame without `TesterStatistics` or history APIs; delayed frames are drained in `OnTesterPass` and `OnTesterDeinit`.
- Offline pipeline: `research_pipeline/stage12.py`; SHA-256 `FE6291A28D6CCEE160DAB7CFAABF345B2841B146B59A46C1E813B54B7F6617D4`. It implements all 19,440 configurations, fixed partitions, independent per-branch percentiles and 150-trade floors, lower-branch scoring, deterministic tie-breaks, full interacting neighborhoods, spread/news gates, all 15 mandatory stress families with exact seed cardinality, 10,000-path circular-block Monte Carlo, frame completeness, and all 28 pairwise heatmap hashes.
- Guarded CLI: `research_pipeline/cli.py`; SHA-256 `E5B5CBC3F084E0E60E1410156516051AB19F46E6245A55A4CC3FBD622E6DEFF3`. `plan` writes new artifacts only; `verify` checks identity; every `execute-*` command requires matching detached authorization and a generated local-only model-4 non-genetic tester bundle.
- Synthetic MQL5 harness: `MQL5/Scripts/KingEA/TestResearchPipeline.mq5`; SHA-256 `ED5D159796D8FB16B3DA319EC88C5F30F57FF638608463009C6DCC5FE25AA2B6`; compiled EX5 SHA-256 `F8CB9C10E905FAC2F863C85B7FE427852C6192B902250B82674C1599388DEBE3`; compile-log SHA-256 `AF2BA1C517DC216704CD27D9410E669A09CBD938BE456F80C49FBB45B403721A`; 0 errors and 0 warnings.
- Runtime evidence: `stage12_research_contract_2026-07-31_12-51-23.csv`; SHA-256 `77347794F8B6F5A1070681E73466A9B97FBBEB7B980B8945F0F0308FE0C9AFAC`; PASS with seven synthetic checks, zero failures, performance authorization denied, order capability absent, and candidate-budget consumption zero.
- Python contract: `tests/test_stage12_pipeline.py`; SHA-256 `DA8D825BCDEDB9977475D683A1E18AAF30A8BB7BD23DFD86C23178BFE12080F4`. Static policy: `tests/Test-Stage12ResearchPipelinePolicy.ps1`; SHA-256 `A33CD327BEA24D370B1BC99E1C0E755CEBEB869D64AEF6BCA7FB273FE4FC25AF`; PASS.
- Repository regression: 25 Python `unittest` tests and all 16 PowerShell policy/contract suites PASS.
- Candidate immutability proof: `CandidateEthSt001.mqh` remains SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`; DRAFT remains `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Residual safety state: MT5 process count 0; KingEA scheduled-task count 0; watchdog disabled/uninstalled; Stage 9 standdown remains active with SHA-256 `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; deployment remains quarantined.
- No development, optimization, real-tick performance, formal OOS, holdout, demo-order, Live2, watchdog, or standdown-removal action was performed or authorized.
- Candidate-budget consumption: 0.
- Next authorized work: Stage 13 accounting and export implementation only.

## GOV-20260802-065

- Timestamp: 2026-08-02T00:15:00+08:00
- Type: Stage 13 immutable accounting, statement reconciliation, cumulative accounting escalation, governed recovery, health review, and durable export implementation
- Status: PASS; STAGE 13 IMPLEMENTATION COMPLETE; NO RESULT-BEARING RUN PERFORMED; STAGE 14 MANIFEST PREPARATION/OWNER REVIEW AUTHORIZED
- Contract: `governance/STAGE13_ACCOUNTING_CONTRACT.md`; SHA-256 `D72E0041FA165354CC88E536B888A6DA67B5214384855A3E70318843147305AE`. Machine contract: `governance/stage13_accounting_contract.json`; SHA-256 `2DE3F728D6C78BA543F5B39320E51B358EAA2D104C787977DCA20DF8B545947A`.
- Offline accounting pipeline: `accounting_pipeline/stage13.py`; SHA-256 `3C21FB0DD728DDBB92FC10E6AB6B01988813A97792D1AE82D01689E6F0A91640`. It owns canonical SHA-256-linked events, deterministic replay, signed broker-cost accounting, external-cash-flow isolation, account/sleeve ledgers, non-netted statement reconciliation, latest-six/rolling-90-day escalation, isolated/cumulative recovery, OOS-range consumption, and append-only JSONL/CSV/Markdown exports.
- CLI: `accounting_pipeline/cli.py`; SHA-256 `913C2802D412EB3B5F6CF615A9666F90827795C2EF5E1519CE9A79341C3F4FBE`. Python contract: `tests/test_stage13_accounting.py`; SHA-256 `59D895DFE9BF87875F9F4F3C6004C7834753D0B3FF3DAF9BEA55EB9C26D8C211`.
- Pure MQL5 event seam: `MQL5/Include/KingEA/AccountingEvents.mqh`; SHA-256 `2B88475645AC23207D9A4227A676E89E8D6D58C9753FAE12BF1C8496CA839D9D`. It has no terminal I/O, history, network, performance, or order API.
- Read-only MT5 history adapter: `MQL5/Scripts/KingEA/ExportAccountingHistory.mq5`; SHA-256 `9EAF54A90F89597DEE1980FD6B4CD1E92A6B79F650AEBB78FAD576177B0FFE67`; EX5 SHA-256 `D96AC9C243FB7F1A4C281194AF792A26DBEBDC69D7782680E5B5A02B637A631E`; compile evidence SHA-256 `6E9BF689B3F558EC092F67061D4CC9E9849F1E5560580F6AE85AD1DA97EE5EF9`; 0 errors and 0 warnings. It was compiled only and not run.
- Stage 12 tester accounting extension: `MQL5/Experts/KingEA/GuardedResearchTester.mq5`; SHA-256 `A85A879BBC88C0BC92FED005AC17719409B1098063CA1C7A89F36706DBBBB745`; EX5 SHA-256 `8406F32095545D463C78F3CBB973E1D0D578DF1EBE78132F7DDC4004479AC5CB`; compile evidence SHA-256 `A69A7EEF0932D0025232ABEFAB670975476CC88C7A77AF7E0E54E617BA0A7BE6`; 0 errors and 0 warnings. The existing single tester-only order seam is unchanged; Stage 13 adds only versioned accounting frames and an exact legacy-summary cross-check.
- Synthetic harness: `MQL5/Scripts/KingEA/TestAccountingLedger.mq5`; SHA-256 `7E28FE0E321EDE93914E5EE3E7EAC2B8E375D87F8D7AA4364111EE2574AC431B`; EX5 SHA-256 `971CE3BECD79D7C760589C7DFFF3415C0130A5A8FDC18F5FD50FFC7DC6E6623E`; compile evidence SHA-256 `92D43E1F53A5A4275452FA03DD4543DF743650B1C98F97583519EAD9B4116C53`; 0 errors and 0 warnings.
- Runtime evidence: `stage13_accounting_contract_2026.08.02_00-12-49.csv`; SHA-256 `A84906F0D7E77489A0539D1BA2B1CDE21DA4F956DD03211085D7529CAD974972`; PASS with eight synthetic checks, zero failures, candidate-budget consumption zero, and performance authorization denied. MT5 shut down automatically; no broker history, performance, or order action occurred.
- Static policy: `tests/Test-Stage13AccountingPolicy.ps1`; SHA-256 `7CB757F765701AC23D1A0233EBBBB725D055E7DB828564416747E317B742EEC1`; PASS. Repository regression: all 35 Python tests and all 17 PowerShell policy/contract suites PASS.
- Verification incident: a malformed variable-based MetaEditor wrapper overwrote three workspace source files with compile-log text during final compilation. No order, history, performance, or live action occurred. The affected sources were recovered from this task's authoritative successful `apply_patch` history, recompiled independently with source hashes stable across compilation, and every Stage 12/13 plus repository regression passed. The three overwritten log payloads are retained outside `MQL5` under `governance/recovery/GOV-20260802-065` with SHA-256 values `550307F591D9A9B9682175CE5A39746E557DC2B59B92E7F77A74BDE60EF5C9E1`, `D562FF6002E2A73A18BC4EC5FD53E72B50305FADDF2F1C1FC253ADAC59C37FFD`, and `71E5C9313852B78093494920E3F3778CA2BCB83F5FF8FA87DA66D64CBA107039`. The accounting genesis check was also hardened to use zero-length string detection because MQL5 zero-initialized struct strings need not compare equal to a literal empty string.
- Candidate immutability proof: `CandidateEthSt001.mqh` remains SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`; DRAFT remains `3BDCEC73D2F843F3D31227425047BA714BF2C7C157BDD667CD7BF9811AA1F4CC`; freeze certificate remains `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Residual safety state: MT5 process count 0; KingEA scheduled-task count 0; watchdog disabled/uninstalled; Stage 9 standdown remains active and matches SHA-256 `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; deployment remains quarantined.
- Candidate-budget consumption: 0.
- Next authorized work: Stage 14 development-manifest preparation and owner review only.
- Development execution, optimization, formal OOS/holdout access, demo/live orders, Live2 activity, watchdog activation, standdown removal, and new candidate-budget consumption: REMAIN PROHIBITED.

## GOV-20260808-066

- Timestamp: 2026-08-08T14:52:19+08:00
- Type: Stage 14 governed local-agent throughput sweep and two-wave confirmation
- Status: PASS; LOCKED 30-DAY THROUGHPUT CEILING SATISFIED; GATE 1 REMAINS UNAUTHORIZED PENDING EXACT-ROOT OWNER APPROVAL
- Sweep evidence: `governance/evidence/stage14/agent_sweep_20260808_summary/AGENT_SWEEP_RESULT.json`; SHA-256 `197481A963F0A6F755FEE8D998EFDDB5520C9F6321FA4DEFEDD6AD641F8ED695`.
- Final evidence manifest: `governance/evidence/stage14/agent_sweep_20260808_summary/FINAL_EVIDENCE_MANIFEST.json`; SHA-256 `97542E0F17CE87E6BEB6E236924CD049A845441045119B6A7A1E67C54D96E7BF`.
- Method: compare 6, 8, 10, and 12 enabled local agents using the full-workload dry harness, both RECORDED and RSB3 branches, real-tick model 4, withheld result fields, zero signals, zero trades, and zero candidate-budget consumption. Processor topology was verified as six physical cores with paired logical masks `0x3`, `0xC`, `0x30`, `0xC0`, `0x300`, and `0xC00`.
- Result: twelve local agents selected. The unique two-wave confirmation ran 24 passes per branch, 48 valid passes total, at 0.11355 active passes/second and 0.10622 wall passes/second. With the frozen 25% operational allowance, the projected exhaustive-development duration is 24.77 active days and 26.48 wall days, below the locked 30-day ceiling.
- Confirmation root: `governance/evidence/stage14/agent_sweep_20260808_a12_confirm24/WORKLOAD_BENCHMARK_ROOT.json`; file SHA-256 `F379A10399EAB22188E53162F9545A0D059E0EC0B3833D162CAA866F331343F9`; canonical workload root `2930319BBFC31A5BB46932F49FED0154F9690659764D304F0CE1FBD0A573891C`.
- Invalidated evidence retained: the immediate 12-agent rerun using the prior root was served from MT5 optimization cache and is explicitly marked `MT5_OPTIMIZATION_CACHE_HIT_NO_REAL_TICK_REPLAY`; it contributes no throughput evidence.
- Regression evidence: all 52 Python tests PASS; Stage 14 static readiness policy PASS. Candidate source remains SHA-256 `4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83`; freeze certificate remains SHA-256 `1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06`.
- Residual safety state: MT5 and MetaTester process counts 0; all twelve local-agent logs confirm participation in the final run; KingEA scheduled-task count 0; watchdog disabled/uninstalled; Stage 9 standdown remains active with SHA-256 `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; deployment remains quarantined.
- Candidate status remains `FROZEN`; candidate-budget consumption remains 0. No optimization result, strategy return, formal OOS/holdout information, demo order, or Live2 activity was exposed.
- Next action: prepare the exact Gate 1 exhaustive-development root and present its hash for separate explicit owner approval. No gate auto-advances.

## GOV-20260808-067

- Timestamp: 2026-08-08T21:59:18+08:00
- Type: Stage 14 exact Gate 1 exhaustive-development root preparation and owner-approval packet
- Status: PLANNED AND VERIFIED; AWAITING EXPLICIT OWNER APPROVAL; EXECUTION REMAINS PROHIBITED
- Exact Gate 1 canonical root: `BC4D5D84DBF45AAB6628AA0E1D39D984F715217BB1CA1C092DE1EE97385FA889`. Root artifact: `governance/evidence/stage14/gate1_preparation_20260808/GATE1_ROOT.json`; file SHA-256 `CF9E490BBDBBA6773467E8D537C785D1F4D961EB7AA2640D8318B4257F109489`.
- Cardinality: 200 planned local-agent launches and 194,400 configuration passes across RECORDED and RSB3, four rolling training partitions plus FINAL_SELECTION. Each partition/branch independently covers configuration IDs 0-19,439 without gaps or overlaps. Formal OOS and holdout are absent.
- Deterministic child index: `governance/evidence/stage14/gate1_preparation_20260808/CHILD_INDEX.json`; file SHA-256 `BEBE6F86B870C99B03A299060996DE6D4D348ABA9D836808E7EDCB2EA3BFC32B`; 200 unique child manifests materialized under `children/` and bound to the exact root.
- Owner packet: `governance/evidence/stage14/gate1_preparation_20260808/OWNER_APPROVAL_PACKET.json`; file SHA-256 `CA3CBF1031925DEFC135FC1C976B1C1E8B000E7ADEC488DAEA0C603F7EF485FE`; canonical packet SHA-256 `F4B8B542EFE1ADFDA66472D96985D8FFE4E10686F6C6552627FDDE4B06AF26F3`. It records `execution_authorized=false` and requires the exact-root approval statement before any result-bearing pass.
- Calendar pre-gate refresh: the governed website adapter re-fetched all 16 segments and reconciled them against the native MT5 snapshot. All 1,971 events, coverage counts, raw segment hashes, website snapshot SHA-256 `003583A95B26AE2E98B555E701FCC0292B6834233645E0A3E5484FE8852312BF`, native CSV SHA-256 `893BE5A32E37F324B4591104A4F4CA04B197DEDCBD893BDBF9D18E7E05D2AA28`, and native snapshot SHA-256 `DDADA7D5FE7C45BFAB0BFE0B0938EE762760CFE6C13033AFCF6C7DA29028E1CD` remain unchanged. Refresh manifest file SHA-256 `DC4FDA192CF7EDC8B65676303CC0FD97A3C9DC74774EC53B2BF9B94F43077D77`; verification file SHA-256 `002FE1A58AE548ABD1D4928F086D674D553ADB9AA4774E9C3F571BBCDDDF9299`.
- CLI seam repair: `research_pipeline/stage14_cli.py` now forwards the already-required `operational_facts` field to the pure coordinator. A regression invokes the public CLI and proves it creates the exact 200-launch root. No acceptance rule, partition, grid, metric, or execution behavior changed.
- Source provenance: final source writes are bound by `governance/evidence/stage14/PRE_TOOLING_GATE1_PREP_V3_20260808.json`; file SHA-256 `8863DA26F3BB7DA0A5FE379DFA87FDC1716CCFF8D5D7EC60283E051FD263417A`; post-tooling verification PASS. V1/V2 intermediate manifests are retained append-only but are superseded because the static policy pointer/build identity had not yet reached its final provenance state.
- Verification: all 53 Python tests PASS; Stage 14 static readiness policy PASS; no raw account login is present in the new evidence; all root and child hashes/cardinalities were independently rechecked.
- Throughput binding: twelve local agents remain selected; frozen 25% allowance projects 26.48 wall days, below the 30-day ceiling.
- Residual safety state: MT5 and MetaTester process counts 0; scheduled watchdog-task count 0; Stage 9 standdown remains active with SHA-256 `8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7`; no Gate 1 authorization file exists.
- Candidate remains `FROZEN`; candidate-budget consumption remains 0. No result-bearing pass, strategy return, OOS/holdout access, demo order, or Live2 action occurred.

## GOV-20260808-068

- Timestamp: 2026-08-08T23:22:50.5478733+08:00
- Type: Exact-root owner authorization and bounded manual Gate 1 batch launcher
- Status: GATE 1 AUTHORIZED; NO RESULT-BEARING PASS STARTED
- Owner approval: The owner explicitly approved canonical Gate 1 root `BC4D5D84DBF45AAB6628AA0E1D39D984F715217BB1CA1C092DE1EE97385FA889` for exhaustive development execution using the exact required statement. Detached authorization artifact: `governance/evidence/stage14/gate1_preparation_20260808/GATE1_AUTHORIZATION.json`; file SHA-256 `6FF67C9D7AB21DDAF50357E030C62E1FB377DD5EEBCB0B78BCE5FBC8EADACDC4`.
- Execution mode: Manual foreground batches only; no watchdog, scheduled task, service, or background loop. Each batch contains at most two sequential children. Expected duration is approximately 6.36 hours; the hard child limit is 3.75 hours and therefore the hard two-child compute ceiling is 7.5 hours before small preflight/finalization overhead.
- Launcher: `operations/Start-Gate1ManualBatch.ps1`; SHA-256 `16A7A2713AAEAA9E873E2544B4017528AD88164A3AA6FF1DDFFC4D8BE49D765D`. It revalidates the exact root, child index and child files, approval file, Stage 9 standdown, absence of KingEA scheduled tasks, terminal build 6090, and the active Demo2 account title before deriving each child bundle. It stops on gaps, partial evidence, conflicting spools, timeout, nonzero terminal exit, missing frames, duplicate frames, incomplete frames, or any reported hard failure.
- Resume rule: Only a contiguous prefix of independently completed children may resume. The launcher always selects the next one or two children and never skips, overwrites, or auto-retries partial evidence.
- Source provenance: Final launcher sources are bound by `governance/evidence/stage14/PRE_TOOLING_GATE1_MANUAL_BATCH_V6_20260808.json`; file SHA-256 `68A150FC70C5D8F063C196CB1474D1816CF165B62151489C7A0C03250C91C2D2`; canonical manifest SHA-256 `75455DA9A80F4408D3DC34666692826B749CBDFD88E34FF1B548C35C39FC256C`; post-tooling verification PASS. Earlier manual-batch pre-tooling manifests remain retained and superseded.
- Verification: 59 Python tests PASS, including six manual-batch contract tests; all repository PowerShell policy suites PASS. Candidate source and freeze hashes remain unchanged.
- Current state: MT5 and MetaTester process counts 0; Stage 9 standdown remains active; watchdog remains disabled/uninstalled; no Gate 1 child has started. Candidate remains `FROZEN` and candidate-budget consumption remains 0 until the first valid result-bearing pass begins.
- Scope: Gate 1 development only. Formal OOS, stress Gate 3, holdout, demo/live broker orders, Live2 activity, watchdog activation, and standdown removal remain prohibited.
