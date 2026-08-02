# Candidate Pre-registration and Freeze Protocol

Effective: 2026-07-21T11:43:49+08:00  
Authority: KingEA v1 Design Plan, Section 20.1  
Registry: `governance/CANDIDATE_REGISTRY.md`

## Purpose

No optimizer, strategy backtest, parameter search, OOS test, or holdout test may run until the exact candidate being tested has an immutable `FROZEN` registry entry. Feasibility checks that do not evaluate strategy profitability—symbol specifications, lot floors, margin, data completeness, and tooling tests—are permitted before candidate freeze.

## Lifecycle

`DRAFT -> FROZEN -> RUNNING -> PASSED | REJECTED | INVALIDATED`

- `DRAFT`: incomplete and not authorized for performance testing.
- `FROZEN`: complete, timestamped, hashed, and authorized for exactly one pre-registered pipeline run.
- `RUNNING`: the first result-bearing job has started; no field may change.
- `PASSED` or `REJECTED`: terminal evidence outcome.
- `INVALIDATED`: result cannot be interpreted because of a documented data/tooling defect. Invalidation cannot be used to hide an unfavorable valid result.

## Fields required before FROZEN

1. Candidate ID and parent ID, if any.
2. Research rationale and falsifiable hypothesis.
3. Strategy family and complete closed-bar entry/exit pseudocode.
4. Symbol, signal timeframe, confirmation timeframe, and allowed regimes/sessions.
5. Stop, scale-out, add-on, time-stop, news, spread, and veto behavior.
6. All tunable parameters, with types, inclusive ranges, steps/grids, and defaults.
7. All fixed parameters and the reason each is fixed.
8. Source-code revision/hash and configuration hash.
9. Data source/version plus exact IS, walk-forward, OOS, and untouched-holdout boundaries.
10. Cost, spread, slippage, latency, missed-order, margin, and HMR assumptions.
11. Optimizer score, parameter-neighborhood rules, acceptance/rejection gates, and stopping rules.
12. Candidate budget for the hypothesis family and the number already consumed.
13. Expected output artifacts and deterministic reproduction command.
14. Owner/reviewer approval and freeze timestamp.

For `ETHUSD.s`, field 9 must reference the completed and hashed native spread-bracket manifest governed by `governance/NATIVE_SPREAD_BRACKET_PROTOCOL.md`. Field 10 must identify both sibling spread branches and state that either branch can reject while neither can rescue the other.

## Freeze procedure

1. Complete every required field without viewing performance results for that candidate.
2. Export/fingerprint the exact data partitions without opening OOS/holdout results.
3. Calculate the source and configuration hashes.
4. Append the complete record to the registry. Never edit an existing entry.
5. Reviewer checks the record against `EA_DESIGN_PLAN.md` and signs it `FROZEN`.
6. Only then may the registered reproduction command run.

## Change and exposure rules

- Any change to logic, symbols, timeframes, filters, parameter ranges, data boundaries, scoring, or gates creates a new candidate ID.
- The new record links to its parent and states the reason for change before producing results.
- Any segment viewed as OOS or holdout is permanently marked `EXPOSED` for that lineage.
- Descendants may use exposed data for development only; they require a still-unseen reserve or genuinely new future data for final validation.
- Failed and abandoned candidates remain in the registry and consume the family candidate budget.
- The Section 1 return aspiration cannot justify expanding a family budget or candidate search space.

## Current authorization state

As of the effective timestamp, no strategy candidate is frozen and no optimizer or performance backtest is authorized. The first permitted deliverable is the non-performance JustMarkets `ETHUSD.s` symbol/data/margin feasibility audit. Its findings may define only mechanical feasibility bounds—such as broker lot-step constraints, minimum executable volume, stop-distance/risk compatibility, current and HMR margin requirements, trading sessions, and transaction-cost floors. The audit must not evaluate signals, historical returns, win rate, expectancy, ATR-multiplier performance, or rank/select any strategy parameter. After feasible bounds are known, Sleeve 1 must be frozen before any result-bearing strategy test.
