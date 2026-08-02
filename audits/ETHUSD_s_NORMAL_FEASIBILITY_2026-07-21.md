# ETHUSD.s NORMAL Feasibility Audit

Status: NORMAL snapshot assessed; first HMR-labelled attempt remained at normal margin, so actual HMR evidence is pending  
Snapshot UTC: 2026-07-21 04:25:00  
Server time: 2026-07-21 07:25:00  
Broker/server: Just Global Markets Ltd. / JustMarkets-Demo2  
Source SHA-256: `FC04688A83052B738F16ED345B5570A2DB7FB8D7B04747B617A4777A09C1B219`

## Scope boundary

This is a non-performance mechanical feasibility assessment. It does not evaluate signals, historical returns, win rate, expectancy, indicator parameters, or strategy quality. `CAND-ETH-ST-001` remains unfrozen and optimizer/performance testing remains unauthorized.

## Account snapshot

- Currency: USD
- Reference balance/equity: USD 1,000
- Account leverage: 1:500
- Broker margin call: 40%
- Broker stop-out: 20%
- No open exposure at capture

## Confirmed symbol specification

- Exact name: `ETHUSD.s`
- Description: Ethereum vs US Dollar
- Price at snapshot: Bid 1922.07 / Ask 1923.05
- Floating spread: USD 0.98, or 98 points (approximately 0.051% of price)
- Digits/point/tick size: 2 / 0.01 / 0.01
- Contract size: 1 ETH per lot
- Minimum volume and step: 0.01 lot (0.01 ETH)
- Maximum volume: 100 lots
- Tick value: USD 0.01 per tick per lot
- Broker stops/freeze levels reported as zero points; the EA must still validate every requested price at order time.
- Swap mode: points; long -280.56 and short -184.08 symbol units, with triple rollover reported for Wednesday. Exact monetary holding-cost conversion will be verified separately before candidate freeze.

## Normal-margin feasibility

At the snapshot, `OrderCalcMargin` reported:

| Volume | Approx. notional | Normal margin | % of $1,000 equity |
|---:|---:|---:|---:|
| 0.01 | $19.23 | $0.04 | 0.004% |
| 0.02 | $38.46 | $0.08 | 0.008% |
| 0.05 | $96.15 | $0.19 | 0.019% |
| 0.10 | $192.31 | $0.38 | 0.038% |

Conclusion: at 1:500, normal margin is not a binding constraint for the intended risk tiers. Risk-at-stop and execution costs will bind before margin at these volumes.

## HMR proxy — not final evidence

Using the informational 1:200 notional/leverage proxy:

| Volume | HMR margin proxy |
|---:|---:|
| 0.01 | $0.10 |
| 0.02 | $0.19 |
| 0.05 | $0.48 |
| 0.10 | $0.96 |

This suggests HMR margin is also unlikely to bind, but the result is provisional. A second capture while JustMarkets HMR is actually active is required; its live `OrderCalcMargin` values are authoritative.

The 2026-07-21 06:20:47 UTC HMR-labelled attempt did not qualify as HMR evidence: its margin rate remained 0.002 and its 0.01-lot margin remained USD 0.04, both matching the normal 1:500 snapshot. It is retained as an inconclusive audit event.

The second HMR-labelled capture at 2026-07-21 12:15:30 UTC (20:15:30 local terminal-log time) also did not qualify. Buy/sell margin rates again remained 0.002, 0.01-lot live margin remained USD 0.04, and the derived effective leverage was approximately 1:484 rather than the 1:200 HMR reference. The exporter's mechanical verdict was `NOT_CONSISTENT_WITH_HMR_REFERENCE`. Therefore there is no evidence that HMR applied to `ETHUSD.s` on this demo account at that time.

## Minimum-lot stop-risk feasibility

Gross loss for the 0.01-lot minimum, excluding commission, swap, and added slippage stress:

| Adverse price distance | Approx. gross loss | % of $1,000 equity |
|---:|---:|---:|
| 0.5% | $0.10 | 0.010% |
| 1% | $0.19 | 0.019% |
| 2% | $0.38 | 0.038% |
| 3% | $0.58 | 0.058% |
| 5% | $0.96 | 0.096% |
| 10% | $1.92 | 0.192% |

At the initial 0.25% live tier, the gross risk budget is $2.50. The minimum lot remains below that budget for an adverse price distance up to approximately 13% before added costs. At the half-tier final-trade ceiling of 0.125% ($1.25), the mechanical boundary is approximately 6.5% before added costs. Therefore the 0.01-lot floor does not structurally prevent early-tier `ETHUSD.s` trading, although the final stressed sizing engine must reserve costs and round volume downward.

Illustrative maximum volumes rounded downward to the 0.01 step, before cost reserves:

| Stop distance | 0.25% tier | 0.50% tier | 0.75% tier | 1.10% tier |
|---:|---:|---:|---:|---:|
| 1% | 0.13 | 0.26 | 0.39 | 0.57 |
| 2% | 0.06 | 0.13 | 0.19 | 0.28 |
| 3% | 0.04 | 0.08 | 0.13 | 0.19 |
| 5% | 0.02 | 0.05 | 0.07 | 0.11 |
| 10% | 0.01 | 0.02 | 0.03 | 0.05 |

These are feasibility ceilings, not recommended sizes and not strategy parameters.

## Trading sessions observed

- Normal daily maintenance gap appears around server 00:00-00:05.
- Sunday additionally reports 00:09-00:19 as a non-trading interval.
- Session metadata must be recaptured and monitored live because broker schedules may change.

## History finding

The initial terminal cache began only on 2026-06-07, but the controlled server-download smoke test subsequently reached the requested five-year boundary on M30, H4, and D1. The broker reports history beginning 2019-05-16, and all 60 fixed monthly one-hour real-tick samples from July 2021 through June 2026 contained data. The samples contained 400,437 ticks in total, ranging from 1,401 to 19,085 ticks per sampled hour.

The availability smoke test therefore passes. This proves apparent availability, not complete continuity or fitness for research. The M30 timestamp scan found 45 gaps longer than one hour, with a maximum gap of eight hours. Their exact dates and explanations must be audited under the full tick-history/data-quality step before candidate freeze; scheduled maintenance may explain them, but that cannot be assumed. Full Strategy Tester synchronization and “Every tick based on real ticks” validation remain mandatory.

## Provisional decision

- Exact symbol and 1:500 account setup: confirmed.
- Normal minimum-lot feasibility: pass.
- Normal margin feasibility: pass.
- Actual HMR margin feasibility: pending live HMR snapshot.
- Five-year history availability: smoke-test pass.
- Five-year clean-history eligibility: pending full gap, duplicate, spread, and contract-history quality audit.
- Candidate freeze/performance-test authorization: not granted.
