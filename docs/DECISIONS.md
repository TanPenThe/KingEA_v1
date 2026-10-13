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

## 2026-10-13 — Owner decisions

- **No intraday rules: trades run until the strategy exits them.** The daily
  23:55 maintenance force-close and the news force-close are off
  (`InpFlattenForMaintenance=false`, `InpFlattenForNews=false`). Both windows
  still block new entries. Stops, strategy exits and risk breakers still apply.
- **Search method (delegated):** the full 19,440-point grid costs ~160 hours
  per fold with 4 local agents. Instead:
  1. One-at-a-time sensitivity per parameter on each training fold
     (`tools/Sweep.ps1`, ~30 passes per fold).
  2. A full factorial grid over only the 3–4 parameters that move the
     results, with the rest fixed at the centre of the registered grid.
  3. Choose from a stable plateau across folds (design plan §13.3), never
     from a single best pass.
- **PnL and drawdown targets** will be discussed with the owner once a
  configuration shows a positive edge on development data.
- **Repo:** pushed to GitHub (`archive/governed-v1`, tag
  `governed-v1-final`, `lean-reset`).

## 2026-10-14 — Cost branch and Candidate 001 grid

- **Owner decision:** development results are judged on the reduced-spread
  symbol `KINGEA_ETHUSD_S_RSB3`. Recorded Demo2 spreads are reported
  alongside as the adverse-cost case.
- **Candidate 001 focused grid (RSB3, 180 configs × 4 folds):** zero
  configurations reach PF ≥ 1.2 on every fold. The best worst-fold PF is 1.07
  and has no plateau. The candidate does not meet the robustness bar.
  Rejection is pending owner confirmation.
