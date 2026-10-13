# Status

**Updated:** 2026-10-13

## Where things stand

- `KingEA.mq5` runs end to end in the Strategy Tester on real ticks. It
  produces trades, a funnel of why signals did or did not trade, a trade
  list and a summary row. MT5's own report agrees with the EA's numbers
  (Fold 1 default: net −119.12, 59 trades, PF 0.26, max DD 11.97% in both).
- An 18-month backtest takes about one minute.
- The end-of-window problem is fixed: open exposure at `InpEvalEnd` is closed
  as `EVAL_END`, and a position open when the test stops is recorded as
  `TEST_END_CLOSE`. Neither invalidates the run.
- The likely cause of the all-zero Gate 1 result is found and fixed: broker
  quote gaps broke the contiguous-bar requirement of the sleeve and regime
  modules, and the rolling window broke the H4 alignment. See
  [DECISIONS.md](DECISIONS.md).
- Candidate 001 has **no profitability conclusion**. Only development data
  (2021-07 → 2024-01) has been touched. OOS (2024) and holdout (2025+) are
  untouched.

## First development results (Fold 1 train, 2021-07-01 → 2023-01-01, default config 7168)

| Run | Trades | Net (USD, $1,000 start) | PF | Mean R | Win | Max DD |
|---|---:|---:|---:|---:|---:|---:|
| Breakers on (account view) | 59 | −119 | 0.26 | −0.35 | 24% | 12.0% |
| Breakers off (signal edge) | 293 | −464 | 0.44 | −0.23 | 25% | 46.9% |
| Breakers off, gap fill off | 17 | +16 | 1.32 | +0.07 | 47% | 3.3% |

- **The gap-fill-off run confirms the zero-entry cause.** Without gap filling,
  the regime module reports `DATA_GAP` on 24,215 of 26,263 bars, so the
  strategy can trade only about 8% of the time.
- **The default configuration loses on Fold 1 training data.** This is one
  grid point, not a verdict on the candidate.
- **The losses come from the exit rules.** Mean R by exit reason (breakers
  off):

  | Exit | Trades | Mean R |
  |---|---:|---:|
  | Insufficient progress (time stop) | 99 | −0.32 |
  | Maintenance flat 23:55 | 81 | +0.18 |
  | News flat | 53 | −0.01 |
  | Stop loss | 43 | −1.01 |
  | Opposite M30 Supertrend | 17 | −0.39 |

  The "insufficient progress" exit is the biggest drag.

## Sensitivity scan (all four training folds, breakers off, recorded Demo2 ticks)

Each parameter was swept across its registered values with the others at
the grid centre (`tools/Sweep.ps1`, ~30 passes per fold, ~15 min per fold).

- **Every setting loses on every fold:** PF 0.22–0.57, about 190–310 trades
  per fold. No parameter gets close to PF 1.0.
- **Supertrend multiplier matters most.** 2.0–2.5 is much worse, and 3.0
  is about the best. The other parameters move fold-mean PF by only
  0.02–0.05.
- Fold 4 (2022-04 → 2023-10) is the worst at PF ~0.30.

## The deciding factor is spread data, not parameters

- Demo2 recorded spreads are ~$23–27 from July 2021 to May 2023, then fall
  to ~$1–3 (see `docs/audits/ETHUSD_s_HISTORY_QUALITY_2026-07-21.md`).
  Live2 spreads are ~$1.26 median.
- The median stop is ~3.8% from entry, so a $25 spread costs ~0.2R per
  trade. The default configuration loses −0.20R per trade on fill-to-fill
  prices, so before spread it is roughly breakeven.
- On the reduced-spread symbol `KINGEA_ETHUSD_S_RSB3` (same Bid path, Ask
  rebuilt from Live2 cost evidence), the same default configuration on
  Fold 1 gives **201 trades, PF 1.19, +0.03R mean, 5.6% max DD**. That is
  marginally positive, but the lower confidence bound (−0.08R) is still
  below zero.
- Live2 tick history only starts in November 2024 (OOS/holdout time), so it
  cannot replace Demo2 for development.

## Focused grid on reduced spreads (RSB3), all four training folds

180 configurations (Supertrend multiplier × ATR period × stop buffer ×
required progress, other parameters at the grid centre), breakers off.
Run with `tools/Grid.ps1 -Label grid_rsb3`, analyse with
`python tools/analyze_grid.py grid_rsb3`.

| Folds included | Configs PF > 1.0 on every fold | PF ≥ 1.2 and profitable on every fold |
|---|---:|---:|
| Fold 1 | 114 | 39 |
| Folds 1–2 | 83 | 9 |
| Folds 1–3 | 23 | 0 |
| Folds 1–4 | 5 | 0 |

- **Best worst-fold PF is 1.07** (multiplier 2.5, ATR 10, stop buffer 0,
  progress 0.25). Its neighbours are all below the bar (plateau score 0).
- **The edge decays through time.** Multiplier 3 / ATR 18–22 is PF ~1.3 on
  2021–2022, ~1.1 on fold 3 and ~1.0 on fold 4 (Apr 2022 → Sep 2023).
- **Verdict for Candidate 001 as specified:** no configuration meets the
  design plan's robustness bar (§13.2–13.3), even on optimistic spreads and
  training data. Per the plan, the search is not widened to rescue it.

## What the results already say about the design

- **Forced intraday closes are now off (owner decision).** Maintenance and
  news windows block new entries only. With trades allowed to run, the
  default configuration on Fold 1 (breakers off) gives 246 trades, PF 0.54
  and mean −0.21R (it was PF 0.44 with the forced closes).
- **The breakers interact badly with a $1,000 account.** After a ~12%
  drawdown, breaker-headroom sizing pushes every trade below the 0.01 lot
  minimum, so the account stops trading for the rest of the window without
  formally halting.

## Next steps

1. **Owner decision:** reject Candidate 001 and pre-register the next
   hypothesis. Plan §12 pool: Donchian/session breakout, ATR momentum
   breakout, or a revised exit design for the Supertrend sleeve (the
   time-stop exit is the largest measured drag).
2. Use the same loop for the next candidate: sensitivity scan, focused grid
   on RSB3, plateau check across four folds.
3. Pick a configuration from a stable plateau (design plan §13.3), check it
   on the 2023 forward quarters, write it in `DECISIONS.md` and commit.
4. Only then run 2024 OOS once. Regenerate the protection calendar before
   any 2025+ holdout run.
5. If no configuration has a positive edge on development data after costs,
   stop and record that. Don't widen the search to rescue it.
