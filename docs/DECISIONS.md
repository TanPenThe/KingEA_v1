# Decisions

Append-only. One entry per decision: date, what, why. Keep it short.

## 2026-10-13 — Lean reset

- **Retired the governed pipeline.** After ~10 weeks it had not produced one
  valid backtest. Archived on branch `archive/governed-v1` (tag
  `governed-v1-final`). Review bundles moved to `C:\KingEA_archive\`.
- **New EA `KingEA.mq5`** replaces `GuardedResearchTester.mq5`. It keeps the
  pure strategy, regime and safety modules unchanged and drops manifests,
  authorization tokens and hash custody.
- **Evaluation-window end.** Any open position is closed at market at
  `InpEvalEnd` and recorded as `EVAL_END`. If the test ends first, the
  tester's own final close is recorded as `TEST_END_CLOSE`. Neither
  invalidates the run. (The old EA counted any open exposure at the
  boundary as a hard failure.)
- **Data gaps are filled with flat bars.** The broker history has at least
  42 multi-bar quote gaps (mostly 2022–2023). The sleeve and regime modules
  require a contiguous M30 window, so one gap disabled entries for the
  following ~90 days. This is the most likely cause of the all-zero Gate 1
  result. Disable with `InpFillDataGaps=false` to compare.
- **H4-aligned window start.** The sleeve's H4 derivation requires the first
  bar of the window to sit on an H4 boundary. The old rolling 5,000-bar
  buffer met that on only 1 bar in 8 once full.
- **Spread baselines are seeded** from the 90 days of tick history before
  the test start, so the spread gate does not block every entry for the
  first eight weeks.
- **`InpApplyBreakers=false` exists for development only.** With breakers
  on, an early drawdown near the 12% sleeve breaker shrinks sizing below the
  minimum lot, and the rest of the window goes untraded (Fold 1 default:
  346 of 438 signals rejected). Turning breakers off measures the signal's
  own edge across the full window. Acceptance runs keep breakers on.
- **Protection calendar is optional** in development runs and loads from
  `data/protection_intervals.csv`. It covers 2021-04-01 → 2025-01-01 and must
  be regenerated before any holdout run.
