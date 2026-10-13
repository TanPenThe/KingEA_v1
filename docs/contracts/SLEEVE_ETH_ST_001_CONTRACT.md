# KingEA Stage 11 Frozen Sleeve 1 Contract

## Status

- Candidate: `CAND-ETH-ST-001`
- Approved configuration: `A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE`
- Scope: deterministic intent integration only
- Performance authorization: denied
- Order capability: prohibited and absent

## Interface

`KingEAEvaluateSleeveEthSt001(bars, request, prior, decision)` is the sole
Sleeve 1 interface. It accepts fully closed M30 OHLC bars, Stage 10 regime
facts, frozen-grid parameters, optional reconciled position context, and the
last consumed M30 bar. It returns an immutable entry, exit, hold, or no-action
decision with a technical stop, deterministic signal identity, position
progress, trace facts, reason codes, and updated consumption state.

The interface contains no volume, lot, margin, order, fill, account-PnL,
ranking, optimizer, or tester-performance fields. The shared safety kernel
continues to own all risk approval and future execution.

## Frozen Calculations

- M30 ATR uses Wilder seed and recursive smoothing for the selected frozen
  ATR period.
- Supertrend uses `HL2 ± multiplier × ATR`, canonical final-band carry,
  close-based flips, and equality-never-flips behavior.
- The first ATR-valid bar seeds long when `close >= HL2`; otherwise it seeds
  short.
- H4 is derived only from eight consecutive M30 bars in server-time buckets
  beginning at 00:00, 04:00, 08:00, 12:00, 16:00, and 20:00. An incomplete
  current bucket is ignored; a malformed completed bucket fails closed.
- Current breakout levels use the preceding `N` bars excluding the signal
  bar. Previous levels use the preceding `N` bars as seen from the previous
  bar. Long and short comparisons remain strict and symmetric.
- Stage 10 must be healthy, entry-eligible, and refer to the identical M30
  observation. Only trending normal/high-volatility states permit entries.
- Bars before `2021-07-01T00:00:00` are consumed for initialization but can
  never emit a signal.

## Position Progress and Signal Expiry

- Original R is fixed from actual entry price to the original confirmed
  broker-side stop. Later stop tightening cannot change it.
- Bars held and MFE use only fully closed M30 bars strictly after the entry
  signal bar. The evaluated closed bar is included; the entry signal bar and
  all intrabar movement are excluded.
- Opposite M30 Supertrend, maximum holding period, and insufficient progress
  retain the priority in the frozen candidate source.
- Every well-formed new bar is consumed before warm-up, parameter, regime, or
  other downstream gates. A blocked signal is never queued or reconsidered.
- Repeated or backward evaluation cannot emit intent.

## Immutability and Authorization

`CandidateEthSt001.mqh`, the approved DRAFT artifact, the freeze certificate,
and the approved configuration hash remain byte-for-byte unchanged. Stage 11
adds no other strategy family and consumes no candidate budget.

Completion permits Stage 12 pipeline implementation only. Optimization,
performance backtests, formal OOS/holdout access, demo or live orders,
watchdog activation, standdown removal, and Live2 activity remain prohibited.
