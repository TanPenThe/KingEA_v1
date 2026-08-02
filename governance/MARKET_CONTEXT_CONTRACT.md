# KingEA Stage 10 Market-Context Contract

Status: IMPLEMENTED NON-TRADING INFRASTRUCTURE  
Build ID: `KINGEA-STAGE10-20260729-A`

## Pure module interfaces

- `KingEAEvaluateRegime(bars, request, prior, decision)` is the sole
  regime-classifier interface. It accepts ordered, fully closed M30 OHLC
  facts and returns a decision plus the next hysteresis state.
- `KingEAEvaluateCorrelation(request, prior, decision)` is the sole
  correlation-clustering interface. It accepts closed D1 close series and
  returns pair decisions, deterministic cluster membership, and next state.
- Both modules are deterministic and side-effect free. Data collection and
  future MT5 adapters remain outside Stage 10.

## Regime rules

- ATR(14), directional movement, DX, and ADX(14) use Wilder initialization
  and recursive smoothing. Undefined or zero denominators fail closed.
- Normalized volatility is `ATR(14) / close`.
- The percentile history is the preceding half-open 90-calendar-day window.
  The evaluated observation is excluded.
- The rank is `100 * strictly-less historical observations / valid sample
  count`. Numerically equal observations are ties and do not increment the
  rank.
- Normal is below 80; high is 80 through 95 inclusive; extreme is above 95.
- At least 95% of expected broker-open slots is mandatory. For continuously
  traded `ETHUSD.s`, 4,104 of 4,320 M30 slots is the minimum.
- Trending requires two consecutive closed-bar ADX observations at least 25.
  Ranging requires two consecutive observations below 20. An established
  state persists from 20 through below 25.
- Volatility-bin changes also require two consecutive closed-bar
  observations. Repeated or skipped observations cannot complete either
  hysteresis sequence.
- Any malformed, incomplete, stale, non-finite, misaligned, forming,
  duplicated, out-of-order, or gapped input blocks entry.
- Stage 10 regime enum values are independently declared and contract-tested
  against Candidate 001’s existing integer values. The frozen candidate is
  unchanged.

## Correlation rules

- The engine computes log returns and Pearson correlation from aligned closed
  D1 observations.
- Dynamic edges activate when absolute 60-day correlation is at least 0.60 or
  absolute 20-day correlation is at least 0.70.
- An active dynamic edge releases only after both values remain strictly below
  0.45 for ten distinct closed-day evaluations. Exact 0.45 resets the release
  count. Missing, stale, insufficient, conflicting, or zero-variance facts
  also reset the count and retain the edge.
- Static override edges cannot be released dynamically.
- Invalid pair facts conservatively create an edge and publish
  `cluster_known=false`; integration must pass that fact to the safety kernel.
- Active edges form transitive clusters. Members are sorted lexicographically,
  and the smallest `symbol_id` is the stable cluster key.
- Only `ETHUSD.s` is operationally registered in Stage 10. No future symbol
  and no static production override is registered.

## Isolation and authorization

- The deterministic contract harness runs with `AllowLiveTrading=0`,
  `AllowDllImport=0`, and automatic terminal shutdown.
- The Stage 9 manual standdown remains active. The watchdog remains disabled
  and uninstalled.
- Order submission, broker history, indicators, tester-performance access,
  optimization, network calls, DLL imports, and tick-flag inspection are
  absent.
- Runtime evidence contains only fixture identity, classifications, cluster
  membership, check counts, and PASS/FAIL. It contains no returns, scores, or
  strategy-performance statistics.
- Completion authorizes only Stage 11 implementation behind the common sleeve
  interface. It does not authorize optimization, performance backtests,
  formal OOS/holdout access, demo orders, Live2 activity, watchdog activation,
  or standdown removal.
