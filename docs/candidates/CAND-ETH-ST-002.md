# CAND-ETH-ST-002 — Supertrend entry, trend-following exits

**Status:** pre-registered 2026-10-14, before any test of these exits.
**Owner approval:** option (c) chosen on 2026-10-14.

## Hypothesis

Candidate 001's entry is roughly breakeven before costs. Its exits cut
trades before trends develop. The "insufficient progress" time stop lost
−0.32R on average, and trades force-closed at 23:55 (which let price run
until then) averaged +0.18R. Replacing the short-horizon exits with a
ratcheting ATR trailing stop and a slower trend-flip exit should let
winners run, and lift expectancy above costs.

This hypothesis was formed from Candidate 001 results on development data
only. 2024 OOS and 2025+ holdout data remain unseen.

## Rules

**Entry: unchanged from Candidate 001.** M30 and derived-H4 Supertrend agree,
there is a fresh close beyond the breakout level plus a buffer, and the regime
is trending with normal or high volatility. Lookback 12, entry buffer 0.1 ATR.

**Initial stop: unchanged.** min(signal-bar low, M30 Supertrend line) −
0.25 ATR for a long, mirrored for a short. Broker-side, never widened.

**Exits: replaced.** These are evaluated on each closed M30 bar, in this
order:
1. **Maximum holding:** exit after `max_holding_bars` bars.
2. **H4 trend flip:** exit when the derived-H4 Supertrend points against the
   position.
3. **Trailing stop:** once maximum favourable excursion ≥ `trail_activation_r`
   × initial risk, move the broker stop to (highest high since entry −
   `trail_atr` × M30 ATR) for a long, mirrored for a short. The stop only
   ever tightens.

The Candidate 001 exits (time stop, opposite-M30-Supertrend exit, 48–96-bar
cap) are not used. Risk kernel, sizing, breakers and calendar entry blocks
are unchanged. There are no forced intraday closes.

## Search grid (243 configurations)

| Parameter | Values |
|---|---|
| Supertrend multiplier | 2.5, 3.0, 3.5 |
| ATR period | 14, 18, 22 |
| `trail_atr` | 2.0, 3.0, 4.0 |
| `trail_activation_r` | 0.0, 1.0, 2.0 |
| `max_holding_bars` | 96, 192, 384 |

## Evaluation (fixed before running)

- **Data:** `KINGEA_ETHUSD_S_RSB3` (reduced spreads), four training folds
  (README), breakers off. Recorded Demo2 spreads are reported for the chosen
  configuration as the adverse-cost case.
- **Pass to forward testing:** at least one configuration where
  - PF ≥ 1.20 and net profit > 0 on **every** fold;
  - plateau: ≥ 50% of its one-step neighbours also meet the line above;
  - ≥ 150 trades in the union of training windows.
- **Choice:** the configuration nearest the centre of the largest passing
  plateau, not the single best pass.
- **If nothing passes,** Candidate 002 is rejected. The grid is not widened.

## Addendum (2026-10-14, before the grid run)

The smoke test showed the spread-spike flatten closing 68 of 173 trades on
`KINGEA_ETHUSD_S_RSB3` and 0 of 193 on recorded `ETHUSD.s` over the same
window. RSB3's ask is a quantile mapping of Demo2 spreads, so the
spread-to-90-day-median ratio is an artefact there. This is a defect in the
test setup, not a strategy result. On RSB3 the relative-spread rules (entry
block above 2×, reduce above 2.5×, flatten above 3×) are therefore off
(`InpSpreadRules=false`). Spread **costs** are still charged on every fill.
On recorded and live data the rules stay on. Rules, grid and pass criteria
are otherwise unchanged.
