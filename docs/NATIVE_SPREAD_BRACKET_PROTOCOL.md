# Native Spread-Bracket Pre-registration Protocol

Status: PRE-REGISTERED; NOT YET EXECUTED  
Effective: 2026-07-22 (Asia/Singapore)  
Scope: JustMarkets `ETHUSD.s`; non-performance data work only

## Purpose

This protocol determines the old Demo2 spread-regime boundary and the deterministic reduced-spread sensitivity transformation without consulting any strategy signal, trade, return, optimizer score, OOS result, or holdout result.

## Authorized evidence

- Price path and anomalous-regime evidence: native `JustMarkets-Demo2` `ETHUSD.s` Bid/Ask ticks.
- Verified reduced-cost reference: native `JustMarkets-Live2` `ETHUSD.s` ticks from the fixed monthly sample windows below.
- No external exchange price or tick may enter either branch.

## Fixed sampling windows

Each monthly sample starts at 12:00:00 broker-server time on calendar day 15. If day 15 is Saturday, it moves to Monday day 17; if Sunday, it moves to Monday day 16. Each sample is exactly 60 minutes.

- Old/high-spread reference: Demo2 samples from 2021-07 through 2023-05 inclusive.
- Verified/live reference: Live2 samples from 2024-12 through 2026-06 inclusive.
- Valid observation: finite `Bid > 0`, finite `Ask > 0`, and `Ask - Bid > 0`.
- Observations are tick-weighted within the fixed windows. No month or tick may be selected or removed based on its spread value.
- Quantiles use the nearest-rank index `floor(p * (n - 1))` after ascending sort.

## Boundary detector

These rules are frozen before computing the result:

1. Search Demo2 ticks from 2023-05-01 00:00:00 inclusive through 2023-07-01 00:00:00 exclusive, in broker-server time.
2. Calculate `high_median` from the fixed old/high-spread reference observations.
3. Use the already audited Live2 reference median of USD 1.26 as `live_median`. The evidence export will independently reproduce and verify this value; a mismatch does not permit substitution and instead blocks the manifest for review.
4. Set `crossing_threshold = sqrt(high_median * live_median)`. The geometric midpoint is fixed because the regimes differ multiplicatively.
5. For every valid search tick, compute the median of the current trailing 1,001 valid tick spreads, including that tick.
6. A candidate crossing begins at the first tick whose rolling median is less than or equal to the threshold.
7. Confirm the boundary only if 1,001 consecutive rolling medians remain less than or equal to the threshold.
8. The registered boundary timestamp is the first tick of that confirmed sequence. The future observations confirm the crossing; they do not move the boundary forward.
9. If there is no confirmed crossing, more than one implementation interpretation, insufficient history, or a Live2 median mismatch, stop. Do not adjust windows, threshold, or confirmation length after seeing the result.

The anomalous transformation interval begins at the earliest accepted five-year Demo2 tick used by the final dataset and ends immediately before the registered boundary tick. Bid data remains unchanged everywhere.

## Reduced-spread transformation

The reduced branch uses deterministic monotonic quantile mapping:

1. Build an empirical CDF from the fixed Demo2 old/high-spread observations.
2. Build an empirical inverse CDF from the fixed Live2 reference observations.
3. For each recorded spread in the anomalous interval, find its right-continuous percentile rank in the Demo2 reference CDF.
4. Replace it with the Live2 spread at the same percentile using the frozen nearest-rank rule.
5. Clamp ranks below/above the Demo2 reference range to the Live2 minimum/maximum respectively.
6. Round the mapped spread upward to the next valid `ETHUSD.s` point so rounding cannot make the assumed cost smaller.
7. Set `Ask_reduced = Bid_recorded + mapped_spread`; preserve Bid, timestamp, flags, last, and volume fields unchanged.
8. Outside the anomalous interval, preserve the complete recorded tick unchanged.

No randomness, interpolation chosen after inspection, smoothing, deletion, synthesized tick, or strategy-dependent adjustment is allowed.

## Branch and acceptance rules

- Branch A is the unchanged recorded Demo2 dataset.
- Branch B differs only by the registered Ask/spread transformation inside the anomalous interval.
- Gaps are never interpolated. The 45 classified Demo2 no-tick gaps remain gaps in both branches.
- The 2026-02-22 Live2 ticks-without-M30-bar interval is quarantined from Live2 validation evidence until tester reconciliation is complete.
- Both branches must independently pass every applicable candidate gate. Results are never averaged, and neither branch may rescue the other.

## Required manifest artifacts

The final manifest must record:

- exact boundary timestamp and detector outputs;
- source server, symbol, fixed sample timestamps, counts, quantiles, and source-file SHA-256 hashes;
- exact dataset start/end and IS/walk-forward/OOS/holdout boundaries;
- gap and anomaly dispositions;
- transformation implementation/configuration hashes;
- unchanged-branch and reduced-branch hashes;
- an invariant check proving identical Bid/timestamp sequences between branches;
- a statement that no strategy or performance result was used.

The completed manifest receives its own `GOV-` registry entry. `CAND-ETH-ST-001` must reference that manifest hash in freeze field 9.

