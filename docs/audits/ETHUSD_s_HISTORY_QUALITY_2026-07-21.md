# ETHUSD.s Targeted History-Quality Audit — 2026-07-21

## Decision

**Targeted technical checks pass with manual broker-history review required.** Five-year apparent availability remains accepted. Complete data-quality acceptance and candidate freeze remain pending.

This audit is non-performance work. It does not inspect signals, returns, expectancy, win rate, strategy parameters, or candidate results.

## Source

- File: `history_quality_ETHUSD.s_5Y_2026.07.21_13-28-01.csv`
- SHA-256: `96AD33D6F51D61FF9411E0E1BB6012132B0FD4BC534FD7B596E91B32ABA6FA9B`
- Server: JustMarkets-Demo2
- Symbol: `ETHUSD.s`
- Period: 2021-07-21 through 2026-07-21

## Clean technical checks

- M30 timestamps copied: 87,488
- Duplicate M30 timestamps: 0
- Out-of-order M30 timestamps: 0
- Monthly real-tick windows present: 60/60
- Sampled valid spreads: 400,437
- Invalid Bid/Ask quotes: 0
- Reversed spreads: 0
- Out-of-order ticks: 0
- Exact consecutive duplicate ticks: 0
- Tick-query errors inside detected gaps: 0

## M30 quote gaps

- Large gaps: 45
- Missing M30 bar slots: 127 (63.5 hours)
- Maximum timestamp gap: 8 hours
- Gaps containing real ticks: 0
- Gaps containing no real ticks: 45

The absence of ticks inside every missing-bar interval indicates quote unavailability rather than missing M30 aggregation over available ticks. The pattern is strongly maintenance-like but cannot be conclusively labelled without historical broker notices:

- 36 gaps begin on Friday; 7 on Saturday; 1 on Sunday; and 1 on Tuesday.
- 28 gaps follow the same Friday 23:30 to Saturday 01:00 server-time pattern.
- 42 of 45 gaps occur during 2022–2023.
- Isolated daytime or longer outages remain and require broker or archived-maintenance confirmation.

The current JustMarkets specification documents ETHUSD as generally continuous apart from a daily 00:00–00:05 break and scheduled server maintenance. Current hours cannot prove what historical maintenance schedules were.

## Spread-regime discontinuity

The combined sample distribution is not representative because it mixes two sharply different historical regimes:

- July 2021 through May 2023: monthly median sampled spreads are approximately USD 23.5–26.5.
- June 2023: median sampled spread abruptly falls to USD 0.46.
- July 2023 through December 2025: monthly medians are generally approximately USD 1.26–3.07.
- January through June 2026: monthly median is USD 0.98.

This discontinuity may reflect a real historical change in liquidity or pricing; a symbol/account specification change; or reconstructed demo data that is not representative of live Pro execution. It is material because transaction costs affect every strategy result. The old segment must not be normalized or discarded merely because it is unfavorable.

## Required broker clarification

Ask JustMarkets support to confirm:

1. Whether `ETHUSD.s` real-tick Bid/Ask history on `JustMarkets-Demo2` is intended to represent historical Pro-account executable spreads.
2. Whether ETHUSD pricing, liquidity feed, contract specification, account suffix, or spread methodology changed around June 2023.
3. Whether the recurring Friday/Saturday quote gaps in 2022–2023 were scheduled maintenance, and whether a historical maintenance archive is available.
4. Whether demo historical ticks may be reconstructed or differ materially from live Pro historical ticks.

## Current gate state

- Five-year apparent availability: PASS.
- Timestamp ordering and sampled quote validity: PASS.
- Gap classification: PROVISIONALLY MAINTENANCE-LIKE; BROKER CONFIRMATION PENDING.
- Historical spread/contract consistency: BLOCKED PENDING BROKER CLARIFICATION OR INDEPENDENT DATA RECONCILIATION.
- Complete five-year tick continuity: NOT YET ACCEPTED.
- Candidate freeze and performance testing: NOT AUTHORIZED.

## JustMarkets support response

Support confirmed that `.s` denotes the Pro-account instrument and that demo accounts reproduce real-account conditions only in a simulated environment. Quotes are described as being as close as possible to real quotes; liquidity is simulated; trades are processed internally; and demo history cannot be guaranteed as fully executable historical Pro spreads. Support could not confirm a June 2023 feed/specification change or explain the 2022–2023 gaps.

This response confirms the dataset limitation. `JustMarkets-Demo2` history may remain useful for tooling and preliminary structural checks, but it is not sufficient by itself for executable-cost acceptance.

## Superseded resolution path — rejected

This path was considered before the owner rejected external-exchange data for candidate performance testing. It is retained only as an audit trail and is not authorized work.

1. Preferred: connect to an actual JustMarkets live Pro server and rerun the same read-only specification, availability, and quality audits without placing trades. Compare history hashes, gap dates, and monthly spread regimes with Demo2.
2. Historical proposal, rejected: if live-server history were unavailable or materially incomplete, obtain an independent five-year ETH reference dataset and construct a versioned MT5 custom test symbol.
3. Preserve the unmodified Demo2 real-tick run as an additional adverse-cost sensitivity case rather than silently normalizing or deleting the old high-spread segment.

MT5 technically supports imported tick history and custom symbols, but a different venue's price path or ticks are not authorized to generate candidate signals, trades, PnL, or acceptance metrics. External data may be retained only as non-binding gross-anomaly context.

## Live Pro server reconciliation

The owner reran all three read-only scripts while connected to an unfunded real Pro account on `JustMarkets-Live2`.

### Sources

- `feasibility_ETHUSD.s_NORMAL_2026.07.21_13-43-38.csv` — SHA-256 `7D7134EFB4A4ADDB5AE0EF44D4C4E87C59F68C1B8611D2511F15462F5D2DE041`
- `history_smoke_ETHUSD.s_5Y_2026.07.21_13-44-20.csv` — SHA-256 `809F9E804D3FB6B06E3EA2B40F7226EDF305BD33D779237C4E9C90B42B370AE8`
- `history_quality_ETHUSD.s_5Y_2026.07.21_13-46-43.csv` — SHA-256 `22978522FCC6CF12C6B2E5BB3F6B2EFE7EE3BE67E4D7A16F899530A02804B50F`

### Live specification result

- Server: `JustMarkets-Live2`
- Account type evidence: Pro suffix `.s`; zero-balance live account
- Leverage: 1:500
- Contract size: 1 ETH per lot
- Minimum/step volume: 0.01 lot
- Margin rate: 0.002
- Minimum-lot margin at snapshot: USD 0.04
- Tick value and swap properties match Demo2.

### Live history result

- Five-year M30/H4/D1 bar boundary: PASS.
- Monthly real-tick presence: 19/60; first successful fixed sample was 2024-12-16.
- Live five-year real-tick requirement: FAIL due to 41 missing sampled months.
- Available sampled quotes: 156,919 with zero invalid quotes, reversed spreads, ordering errors, or exact consecutive duplicates.
- Available live spread distribution: median USD 1.26; P95 USD 3.07; P99 USD 3.30; maximum USD 4.69.

For all 19 overlapping monthly sample windows from December 2024 through June 2026, Live2 and Demo2 have exactly matching median, P99, and maximum spreads. Tick counts are identical in 12 windows and differ slightly in 7. This strongly validates the recent Demo2 cost regime but does not validate the July 2021–November 2024 segment.

### Live anomaly

One 2026-02-22 M30 gap contains 14 real ticks from 00:54:18 through 00:54:33 server time even though the interval has no corresponding M30 bar. MT5 may ignore real ticks where authoritative minute-bar history is absent. This interval must be excluded or explicitly handled in the final data manifest and tester reconciliation; it is not evidence of broad corruption.

### Revised evidence hierarchy

1. `JustMarkets-Live2` real ticks from December 2024 onward are authoritative broker-native evidence.
2. Matching Demo2 ticks over the same period are corroborated recent demo evidence.
3. Demo2 ticks before December 2024 remain unverified simulated history. Their high-spread segment may be retained unchanged as an adverse-cost stress case but cannot be labelled executable Pro history.
4. External exchange data is optional, non-binding gross-anomaly context only. It is not required and must not substitute for native JustMarkets history or generate strategy performance.

Candidate freeze remains unauthorized until the native Demo2 two-branch spread transformation, exact anomalous-period boundary, Live2 relative-spread evidence, anomaly treatment, cost regimes, and data partitions are frozen and hashed.

## Owner decision — native two-branch spread bracket

The owner accepts layered native JustMarkets evidence as sufficient. The 2021–2023 segment must remain because it contains essential crypto crash and regime-diversity evidence; uncertainty about its high spreads cuts conservatively when those spreads are preserved.

Two mandatory native-data branches will be registered before testing:

1. **Recorded branch:** Unchanged JustMarkets-Demo2 Bid/Ask ticks. This remains the binding punitive-cost history.
2. **Reduced-spread sensitivity branch:** Identical Demo2 Bid timestamps and price path; only Ask/spread is transformed during the exact registered anomalous window by one frozen mechanical formula derived from Live2 cost evidence.

Both branches must independently preserve the candidate's acceptance conclusions. Results are not averaged. The reduced branch cannot rescue failure under recorded spreads. Conversely, failure only under reduced spreads indicates that lower costs admit harmful trades previously blocked by the spread gate and is also grounds for rejection.

The high-spread window currently evidenced by monthly samples is July 2021 through May 2023 with the discontinuity appearing in June 2023. Exact tick-level transition boundaries and the reduced-spread formula must be established without strategy evaluation before candidate freeze.

On 2026-07-22 the method was frozen in `governance/NATIVE_SPREAD_BRACKET_PROTOCOL.md`: a trailing 1,001-valid-tick median, geometric midpoint between the fixed old-regime median and audited Live2 median USD 1.26, and 1,001 consecutive qualifying rolling medians. The reduced branch uses deterministic monotonic quantile mapping rather than random resampling. Evidence exports remain pending; no strategy or performance test is authorized.

### Spread-bracket evidence result — 2026-07-22

- Live2: PASS; 19/19 fixed monthly windows; 156,919 valid raw distribution ticks; median USD 1.26 reproduced; P95 USD 3.07; P99 USD 3.30; maximum USD 4.69; no invalid sample ticks.
- Demo2 old reference: PASS; 23/23 fixed monthly windows; 128,479 valid raw distribution ticks; median USD 23.76; P95 USD 26.52; P99 USD 27.77; maximum USD 30.51; no invalid sample ticks.
- Boundary search: PASS over 5,524,493 valid ticks with zero invalid ticks.
- Frozen geometric threshold: USD 5.47 as reported (unrounded calculation retained in the evidence manifest).
- Registered transition: `2023-06-03 14:10:08.062` broker-server time; epoch milliseconds `1685801408062`.
- Evidence manifest: `data/manifest/KINGEA_ETH_NATIVE_SPREAD_BRACKET_EVIDENCE_V1.json`.
- Derived reduced dataset, branch invariants, and dataset hashes remain pending. Performance testing remains unauthorized.

### RSB1 build defect classification — 2026-07-22

The first reduced-symbol build stopped on 2022-11-27 after rejecting native ticks where `Ask == Bid`. A focused reproduction scanned 44,169 ticks and found 541 zero-spread events, with no reversed spreads, invalid numbers, nonpositive Bid, out-of-range ticks, or backward timestamps. This was a builder defect rather than grounds to alter the frozen dataset: the registered transformation already requires values below the Demo reference range to clamp to the Live2 minimum USD 0.98. RSB1 remains partial and prohibited. Corrected builder v1.01 targets RSB2, preflights the complete source before mutation, accepts zero as transformable input, and continues to reject negative/reversed spread.

The subsequent full preflight identified two isolated post-boundary crossed snapshots on 2024-03-02. Neighbor analysis classified them as asynchronous one-sided updates corrected after approximately 0.2 seconds. An MT5 custom-symbol probe accepted and preserved both timestamps, Bid, Ask, spread, last, and volume fields exactly while normalizing only origin flags `100/98` to `6`. The platform amendment registers this unavoidable metadata normalization, prohibits KingEA from using tick flags, and whitelists only those two exact timestamp/Bid/Ask pairs. Builder v1.02 requires both and blocks any additional or changed reversed snapshot.

### RSB2 construction result — 2026-07-22

The version 1.02 build passed: 327,417,608 native ticks were added to `KINGEA_ETHUSD_S_RSB2`; 96,218,891 were spread-transformed before the registered boundary and 231,198,717 were preserved afterward. Preflight found 759 zero-spread inputs, exactly the two registered crossed snapshots, zero unexpected reversals, and zero invalid ticks. Construction PASS does not authorize performance testing or live trading; independent stored-branch invariant verification, fingerprints, and Strategy Tester reconciliation remain mandatory.

RSB2 subsequently failed stored-history verification. `CustomTicksAdd` persistently omitted the final 128 ticks from early daily batches and, after 2023-09-10, retained only the final 128 ticks per day. Repeated, half-day, and hourly reads proved this was storage loss rather than caching. A two-day `CustomTicksReplace` probe round-tripped 173,712 and 102,582 ticks exactly with zero non-flag or flag mismatches. Therefore `CustomTicksAdd` is prohibited for bulk history. Builder v1.03 targets RSB3, uses daily `CustomTicksReplace`, and immediately verifies every replaced day's count and non-flag fields.

RSB3 construction passed on 2026-07-23: all 327,417,608 ticks were replaced daily and immediately read back with zero non-flag mismatches. Transformed and unchanged counts reconcile exactly to the total, with no invalid ticks or failure rows. Independent RSB3 verifier v1.01 remains mandatory before any performance test.
