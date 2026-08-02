# KingEA Stage 12 Guarded Research Pipeline Contract

## Status and authorization

- Build ID: `KINGEA-STAGE12-20260731-A`
- Candidate: `CAND-ETH-ST-001`
- Status: implemented and contract-tested; no result-bearing run performed
- Candidate-budget consumption: `0`
- Performance, OOS, holdout, demo-order, Live2, watchdog, and standdown-removal authorization: denied

Stage 12 introduces a guarded Strategy Tester adapter and one offline research-pipeline interface. The Stage 9 standdown remains active. No `RUNNING` research manifest or detached execution authorization is created by this stage.

## Guarded execution seam

`GuardedResearchTester.mq5` is the only Stage 12 artifact with `OrderSend`. It is an EA for the MT5 Strategy Tester and refuses chart, demo, and live execution. Immediately before its single order seam it revalidates tester mode, model 4, local-only declarations, the manifest file SHA-256, the detached authorization token, branch, purpose, and frozen partition prerequisites.

The adapter builds Bid M30 bars from `OnTick`, invokes the Stage 10 regime classifier, Stage 11 frozen sleeve, and shared safety kernel, submits a broker-side stop in the entry operation, permits one group only, and emits one `FrameAdd` completion payload per pass. `OnTesterPass` and `OnTesterDeinit` drain delayed frames. It contains no partial exit, add-on, averaging, hedge, fixed TP, or stop-widening path.

`ResearchExecution.mqh` is the pure seam shared by the native tester adapter and deterministic virtual stress adapter. It owns frozen configuration-ID decoding, authorization facts, spread/slippage/cost transformations, and seeded missed-entry decisions. It contains no terminal I/O or order capability.

## Offline pipeline

`Stage12Pipeline` hides the grid, frozen partitions, manifest hashing, independent branch scoring, deterministic selection, neighborhood robustness, spread/news gates, mandatory stress matrix, Monte Carlo, frame completeness, and surface evidence behind one interface.

- IDs `0–19,439` form an exact bijection; maximum holding varies fastest and ATR period slowest.
- Branch percentile ranks and the 150-trade floor are independent. Branches are never pooled or summed; the lower score governs.
- Neighborhoods include every simultaneous ±1 grid-index interaction. At least 80% must retain positive expectancy and PF ≥1.20 in both branches; any neighbor above 20% drawdown vetoes the center.
- Every parameter surface and all 28 pairwise heatmaps are content-addressed before OOS can be authorized.
- The mandatory stress matrix includes deterministic delay/spread/cost/slippage cases plus 100 seeds each for 5% missed entries, 10% missed entries, and combined stress. Missing scenarios or seeds fail closed.
- Monte Carlo uses 10,000 paths by default, five-trade circular blocks, SHA-256-derived seeds, nearest-rank percentiles, and an independent sub-30% p95 drawdown gate per branch.

## Immutable governance

Commands are `plan`, `verify`, `execute-development`, `execute-oos`, and `execute-holdout`. Planning writes a new file only. Execution requires an exact manifest hash and detached owner authorization; OOS additionally requires immutable selection and surface hashes, and holdout requires a Stage 15 authorization hash. The CLI independently verifies model 4, exhaustive non-genetic optimization, local agents only, remote/cloud disabled, USD 1,000 deposit, and the guarded EA identity before launching MT5.

Completion authorizes Stage 13 accounting/export implementation only. It does not authorize any result-bearing job.

