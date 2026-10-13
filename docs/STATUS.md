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

## What the results already say about the design

- **Daily maintenance flatten makes the strategy intraday.** The protection
  calendar has a daily 23:55–00:05 server close with a force-flat. About 1 in
  4 trades is closed by that rule or by a news blackout, so the 48–96-bar
  holding periods in the grid rarely matter. Decide whether that rule is
  real for `ETHUSD.s` (crypto trades 24/7 at most brokers) or should be an
  entry-block only.
- **The breakers interact badly with a $1,000 account.** After a ~12%
  drawdown, breaker-headroom sizing pushes every trade below the 0.01 lot
  minimum, so the account stops trading for the rest of the window without
  formally halting.

## Next steps

1. Answer the maintenance question above. It changes the strategy more than
   any parameter.
2. Run Gate 1 on development folds. A full 19,440-point grid at ~1 min per
   pass is ~320 agent-hours per fold, so either use MT5's genetic
   optimizer, or shrink the grid to the 3–4 parameters that matter.
3. Pick a configuration from a stable plateau (design plan §13.3), check it
   on the 2023 forward quarters, write it in `DECISIONS.md` and commit.
4. Only then run 2024 OOS once. Regenerate the protection calendar before
   any 2025+ holdout run.
5. If no configuration has a positive edge on development data after costs,
   stop and record that. Don't widen the search to rescue it.
