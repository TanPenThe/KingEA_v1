# KingEA v1 Design Plan

Status: Design baseline locked after grilling session  
Last updated: 2026-07-22  
Platform: MetaTrader 5  
Broker baseline: JustMarkets Pro (Raw Spread may replace Pro only after identical cost-adjusted OOS comparison)

## 1. Owner aspiration and non-negotiable priority

- Initial live capital: USD 1,000.
- Compounding horizon: at least four years.
- Owner aspiration: approximately 500% full-period CAGR, with approximately 200% or more in rough calendar years and more than 500% in strong years.
- These figures are explicitly non-binding and are not research targets, optimizer inputs, candidate filters, ranking metrics, tie-breakers, or deployment gates.
- The research process discovers achievable return empirically after all survival and robustness gates; it does not search until it finds a curve matching the aspiration.
- Survival and risk constraints take priority over return targets.
- The aspiration is never a promise or a reason to weaken validation, expand the search space, or prefer an extreme historical equity curve.
- A candidate may be deployed only because it passes the safety and evidence gates, irrespective of whether it reaches the aspiration.

## 2. Account and deployment assumptions

- The trading account is dedicated exclusively to KingEA.
- No manual trades, copy trading, or other EAs are permitted.
- Unknown positions, orders, magic numbers, or unexplained balance operations block new entries.
- JustMarkets Pro is the baseline account type.
- Raw Spread is used only if identical trades produce a persistent OOS net-cost improvement.
- The EA must not depend on nominal 1:3000 leverage.
- High Margin Requirements (HMR) means JustMarkets' temporary increase in required margin/reduction in effective leverage around specified news, rollover, weekend, holiday, or other broker-designated risk periods.
- All sizing and margin decisions use current MT5 symbol/account data and live margin calculations.
- The user PC may host initial development, demo, and early live validation because it can run continuously.
- A low-latency VPS remains the preferred mature-live deployment environment.

## 3. Risk hierarchy

### 3.1 Trade and portfolio risk

- Normal maximum planned stressed loss per trade: 1.10% of current equity.
- A broker day is the JustMarkets trade-server calendar day from `00:00:00` through `23:59:59`, evaluated using `TimeTradeServer`; it is not the PC's local day or UTC day.
- A full-loss event is one completed original trade group, including any partial exits or add-on child trades, whose net result is at or below -0.80 of its entry-time stressed planned R or whose protective stop is executed.
- In live/demo accounting, net result includes realized spread, commission, swap, and execution slippage; in backtest/stress accounting, it includes the active stressed cost and slippage assumptions.
- After two full-loss events in one broker day, at most one subsequent fresh signal may enter across the entire account.
- That final trade uses the ordinary frozen strategy entry rules; there is no discretionary "A-grade" category.
- Maximum risk for the final trade is 50% of that sleeve's current live-tier ceiling, before application of all stricter sleeve, cluster, portfolio, margin, and breaker-headroom limits.
- Therefore the final-trade ceilings at the 0.25%, 0.50%, 0.75%, and 1.10% tiers are 0.125%, 0.25%, 0.375%, and 0.55%, respectively.
- Once the final trade is submitted, no further entries are permitted until the next broker day, regardless of its outcome.
- Maximum stressed risk in one correlation cluster: 1.50%.
- Maximum stressed portfolio risk across genuinely distinct clusters: 2.20%.
- Effective open-risk capacity is the minimum of:
  - the applicable sleeve tier;
  - 1.50% cluster capacity;
  - 2.20% portfolio capacity; and
  - 50% of remaining loss headroom to the nearest active daily, weekly, monthly, or all-time breaker.
- Risk includes stop loss, spread, commission, swap where applicable, and stressed slippage.

### 3.2 Account circuit breakers

- Daily equity loss: 3%.
  - Flatten EA exposure, cancel pending orders, and stop for the rest of the broker day.
  - The daily reset never erases loss accumulated toward the weekly breaker.
  - Resume on the next broker day only after health checks.
- Weekly equity loss: 6%.
  - Stop for the rest of the broker week.
  - Resume only after health checks, initially at half risk.
- Monthly equity loss: 10%.
  - Flatten EA exposure, cancel pending orders, and latch shutdown.
  - No automatic resume; documented manual review is required.
- Drawdown from all-time-high account equity: 20%.
  - Permanent halt, flatten, cancel pending orders, and require full strategy revalidation.
- Absolute acceptance/stress ceiling: drawdown must remain below 30%, including floating losses.

Weekly recovery remains at half the previously earned tier until five consecutive
clean broker days complete. A clean day requires no breaker or two-full-loss
throttle, valid state/configuration, reconciled exposure, confirmed stops, healthy
connection/specification, and compliant spread/margin. Any failure resets the
streak. The first recovery throttle resets the streak; the second in the same
attempt latches manual review and permits resumption only at the 0.25% tier after
approval. The third account or sleeve weekly breaker within rolling 90 broker
calendar days latches cumulative review. A successful cumulative review archives
the reviewed activations, starts a fresh escalation epoch, resumes at half the
previously earned tier, and requires five new clean days. OOS validates this fixed
gate and may not tune it to rescue a candidate.

### 3.3 Sleeve circuit breakers

Each sleeve maintains a virtual equity ledger including realized PnL, floating PnL, commission, swap, slippage, and attributed emergency reductions.

- Weekly sleeve loss: 4%.
  - Pause only that sleeve for the week.
  - Resume at half its prior risk tier after health checks.
- Monthly sleeve loss: 7%.
  - Latched sleeve-only shutdown requiring documented manual review.
- Sleeve drawdown from virtual all-time high: 12%.
  - Retire the sleeve pending complete revalidation.
- Account-wide breakers remain authoritative and stop all sleeves.

## 4. Position sizing invariant

1. The strategy first defines the technically valid stop from market structure or volatility.
2. The risk engine calculates loss at that stop using MT5 symbol-aware calculations.
3. The engine derives volume from the permitted stressed risk.
4. Volume is rounded downward to the broker volume step.
5. Trade, sleeve, cluster, portfolio, margin, and breaker-headroom constraints are rechecked.
6. If the minimum broker volume is too risky or lacks margin headroom, the trade is skipped.

The stop is never moved merely to make a desired lot size fit.

New exposure must retain a stressed margin level of at least 500% and stressed
free margin of at least 80% of equity. Stressed margin uses the greater of the
live broker calculation and the frozen 1:200 HMR proxy. These floors may downsize
or reject exposure and are never weakened for later sleeves.

## 5. Hard strategy prohibitions

- No martingale.
- No grid recovery.
- No averaging down.
- No position without a confirmed broker-side stop loss.
- No same-symbol hedging.
- No cross-market hedging.
- No risk or margin credit for apparent hedges.
- No opaque or machine-learning signal generation in v1.
- No signal evaluation using a forming candle.
- No stop widening.
- No optimization using OOS or holdout results.
- No signal timeframe below M30.

## 6. Stop-loss invariant

- For a long position, a replacement stop must be at or above the current stop.
- For a short position, a replacement stop must be at or below the current stop.
- Stop comparisons use the previous confirmed stop, not current market price.
- A failed tightening request leaves the original valid stop unchanged and triggers bounded retries.
- A retry can never fall back to widening.
- If no valid broker-side stop exists, immediately attempt to flatten and block new entries.
- Manual widening or removal is detected and reversed or flattened.

## 7. Signal and order lifecycle

- Entry signals are evaluated exactly once on fully closed bars.
- Indicators reference bar index 1 or older.
- Execution occurs on a subsequent tick.
- Every signal records its source sleeve, signal-bar timestamp, and decision reason.
- A gate failure permanently discards that bar's signal.
- Signals are never queued across bar boundaries.
- A later entry requires a fresh signal from a later completed bar.
- Entry retry policy:
  - maximum three total attempts;
  - all attempts must occur within five seconds;
  - every gate is revalidated before every retry;
  - only transient execution/connectivity failures are retryable;
  - safety, margin, volume, stop, market-state, and price-deviation failures are not retryable.
- Three consecutive missed entries or more than 10% failed entries over the last 30 valid attempts blocks new entries and triggers execution review.

## 8. Strategy behavior

- Each strategy has no more than eight genuinely tunable parameters.
- Risk thresholds and circuit breakers are fixed and are never optimizer parameters.
- One primary signal timeframe may create entries.
- One higher timeframe may confirm or veto but never create an independent entry.
- M30 is the minimum signal timeframe.
- All referenced timeframe bars must be closed.
- Explicit broker-time or named-session filters are allowed and count toward the parameter cap.
- Session filters remain subordinate to news, maintenance, spread, weekend, and safety gates.
- Every strategy requires:
  - a progress-check bar count;
  - a minimum favorable-progress threshold expressed in R;
  - an absolute maximum holding period; and
  - a full time-stop exit when progress is insufficient.

### 8.1 Partial exits

- Planned strategic scale-outs are allowed.
- Scale-out level and percentage count toward the eight-parameter cap.
- Strategic scale-outs must pass all IS, OOS, walk-forward, and execution gates.
- Emergency reductions are separate fixed risk-engine actions and are never optimized.
- Every partial close records whether it was strategic or safety-driven.
- Neither mechanism may justify widening the remaining stop.

### 8.2 Pyramiding

- At most one add-on is permitted per original position in v1.
- The original position must already be profit-protected.
- The add-on requires a fresh closed-bar structural signal at a predefined positive R multiple.
- After adding, the combined position must be protected at breakeven-plus or better.
- Combined stressed risk must satisfy all trade, cluster, portfolio, margin, and breaker constraints.
- Add-on behavior counts toward the strategy parameter cap and validation burden.

## 9. Regime classifier

- Shared, explainable, rule-based module.
- Uses closed-bar data only.
- Classifies trend state as trending, ranging, or transitional.
- Classifies volatility as normal, high, or extreme.
- Uses normalized/percentile-based inputs so the same logic can operate across symbols.
- Uses hysteresis and a minimum-state duration to prevent rapid flipping.
- Transitional, uncertain, stale, or invalid state means no new entries.
- Every strategy has an explicit regime whitelist.
- The classifier and whitelist are frozen before OOS testing and used identically in research, stress, demo, and live operation.
- No post-hoc filter may be invented from failed OOS periods without invalidating the holdout.

## 10. Correlation clustering

- Use closed daily log returns, never price-level correlation.
- Primary rolling window: 60 trading days.
- Shock window: 20 trading days.
- Treat instruments as one cluster if:
  - absolute 60-day correlation is at least 0.60;
  - absolute 20-day correlation is at least 0.70; or
  - a static structural override applies.
- Clusters are transitive.
- Release a dynamic cluster only after correlation remains below 0.45 for ten trading days.
- Missing, stale, or insufficient data defaults to correlated.
- Dynamic correlation may tighten a static cluster but cannot remove a static safety override.

## 11. Time, spread, weekend, maintenance, and news gates

### 11.1 Spread

- Block new entries above 2.0 times the time-of-week median spread.
- Reduce exposure above 2.5 times the median.
- Emergency flatten above 3.0 times the median if persistent.
- Exact persistence and sampling mechanics must be fixed before OOS testing.

### 11.2 Weekends and closures

- Forex, metals, and indices:
  - no new entries in the final 60 minutes before Friday close;
  - force-flat at least 30 minutes before close.
- Crypto:
  - weekend new-trade and aggregate risk reduced by 50%;
  - scheduled maintenance and abnormal-liquidity rules still apply.

### 11.3 Maintenance

- Flatten before scheduled broker maintenance.
- Resume only after reopening, 15 minutes of normalized spread/tick flow, and successful health checks.
- Maintenance is an operational pause, not a manual-reset circuit breaker.

### 11.4 Scheduled news

- Mandatory source: MT5 native Economic Calendar.
- Block relevant high-impact entries from 30 minutes before through 15 minutes after the event.
- Relevance mapping:
  - FX: high-impact events for either currency;
  - gold, US indices, and USD-quoted crypto: high-impact USD events;
  - explicit coverage of central-bank decisions, CPI/PCE, major employment reports, and GDP.
- Existing positions may remain only if already profit-protected and the 3x-spread plus stressed-slippage test still locks positive net PnL without violating any breaker.
- External crypto news APIs are excluded from v1 core behavior.

## 12. Initial strategy research pool

1. Supertrend/ATR trend-following with pullback or continuation entry.
2. Donchian or session-range breakout.
3. ATR momentum breakout.

- Mean reversion is excluded from the initial pool.
- Sleeve 1 is the M30 `ETHUSD.s` strategy and must complete the pipeline alone.
- No more than three sleeves may be live in v1.

## 13. Historical data and validation

- Forex, metals, and indices require at least ten years of clean historical data.
- Crypto requires at least five years.
- Every candidate requires at least 150 stitched OOS closed trades.
- Partial exits count as one original trade for sample-size purposes.
- Candidates must trade through bull, bear, and ranging regimes.
- Use MT5 `Every tick based on real ticks` for final validation.
- Audit tick history for gaps, duplicates, spread realism, earliest usable tick, and contract-specification changes.
- Use conservative commission, swap, and contract assumptions when history is incomplete.
- Only native `ETHUSD.s` data supplied by the applicable JustMarkets MT5 server may generate candidate signals, trades, returns, optimizer scores, OOS results, or holdout results. Exchange data from Binance, Coinbase, Kraken, or another venue may be used only for gross price-history anomaly checks because venue-specific ticks, candle construction, spreads, and intrabar ordering can change the strategy's actual signals and fills.
- The five-year research/stress history uses unchanged JustMarkets-Demo2 broker-provided real ticks and must be labelled simulated rather than executable live history. JustMarkets-Live2 real ticks from their available start are the authoritative recent execution/holdout layer.
- External exchange ticks may never be substituted into a synthetic MT5 symbol to rescue a JustMarkets candidate. If the broker-native evidence is judged insufficient, the permitted decisions are to reject the candidate, wait for additional live evidence, or separately pre-register a different broker/symbol deployment—not to normalize away the mismatch.
- The unverified high-spread Demo2 regime is retained unchanged as the binding conservative branch because it contains essential 2021–2023 crypto bull/crash/chop coverage. It may not be dropped merely because its spread provenance is uncertain.
- Every candidate must also pass a separately versioned reduced-spread sensitivity branch over the exact pre-registered anomalous window. The branch must preserve the same JustMarkets Demo2 Bid timestamps and price path and may alter only Ask/spread according to one fixed mechanical formula derived before strategy testing from Live2 cost evidence.
- The two spread branches are never averaged and neither may be selected after seeing results. Acceptance requires both to pass all applicable OOS/risk conclusions. A reduced-spread pass cannot rescue failure on unchanged recorded ticks; a reduced-spread failure reveals dependence on the high-spread entry veto and also rejects the candidate.
- Candidate freeze field 10 must state: `Demo2 tick history in the registered anomalous window has unverified spread authenticity; unchanged recorded spreads are the conservative branch; a pre-registered reduced-spread branch tests conclusion sensitivity; neither branch can override a failure in the other.`
- The boundary detector, deterministic quantile-mapping formula, gap treatment, branch invariants, and required hashes are fixed by `governance/NATIVE_SPREAD_BRACKET_PROTOCOL.md`. Changing that protocol after inspecting its outputs requires a new governance record and a documented methodological defect; an inconvenient boundary or result is not a defect.
- The narrow MT5 crossed-tick flag-normalization exception is governed by `governance/NATIVE_SPREAD_BRACKET_PLATFORM_AMENDMENT_2026-07-22.md`. No KingEA module may use `MqlTick.flags` for strategy or acceptance behavior. Exact timestamp/Bid/Ask identity remains mandatory, and only the two explicitly registered post-boundary crossed snapshots are permitted.

### 13.1 Walk-forward and holdout

- Use rolling, not anchored, training windows.
- Crypto starting structure: 18-month training, three-month forward test, three-month step.
- Forex/metals/indices starting structure: 36-60-month training, six-to-twelve-month forward test.
- Preserve the final recent period as a completely untouched holdout.
- The 150-trade minimum applies across stitched OOS folds, not independently to every fold.
- No OOS/holdout result may influence optimization ranking, tie-breaking, or parameter rescue.

### 13.2 Acceptance gates

- OOS profit factor at least 1.30 after all costs.
- Positive expectancy with statistical support.
- OOS drawdown no more than 1.5 times IS drawdown and always below 20%.
- Monte Carlo 95th-percentile drawdown below 30%.
- No catastrophic fold-level failure or hard drawdown breach.
- Headline CAGR never overrides a failed robustness gate.

### 13.3 Parameter robustness

- Perturb each tunable parameter by adjacent steps and approximately plus/minus 10-20%.
- Test parameter interactions, not only one-at-a-time changes.
- At least 80% of the local neighborhood must retain positive expectancy and profit factor at least 1.20.
- Every neighbor must remain below the 20% strategy drawdown ceiling.
- Reject isolated peaks and sharp performance cliffs.
- Select a conservative point near the center of a stable plateau.
- Produce parameter heatmaps before exposing OOS data.

### 13.4 Optimization objective

- Never optimize raw net profit or CAGR directly.
- In-sample ranking uses a bounded composite of:
  - MAR/Calmar;
  - Sortino;
  - profit factor;
  - lower-confidence-bound expectancy; and
  - capped trade-count confidence.
- OOS and stress metrics are independent pass/fail gates, never optimizer inputs.

## 14. Execution stress harness

One unified harness tests:

- fixed 20 ms baseline delay;
- 100 ms delay;
- 250 ms delay;
- 500 ms delay;
- MT5 random-delay severe test;
- asymmetric volatility-linked slippage;
- spread widening up to 2-3 times historical conditions;
- commission and swap increased by 30%;
- a randomized missed-entry rate; and
- combined adverse conditions.

At 250-500 ms and under combined stress, the strategy must retain positive expectancy, profit factor at least 1.30, and drawdown compliance. Latency-dependent short-term scalping is rejected.

## 15. Demo and live graduation

### 15.1 Demo gate

- At least three calendar months and 50 completed trades, whichever takes longer.
- Positive expectancy.
- Profit factor must be at least the greater of 1.15 and the lower bound of the OOS-derived predictive interval.
- The 1.15 value is a small-sample absolute failure floor for the initial 50-trade demo gate, not a relaxation of the 1.30 OOS/stress standard and not a new optimizer target.
- Drawdown no greater than the minimum of 1.5 times OOS drawdown and 20%.
- Execution statistics must remain inside stressed assumptions.

### 15.2 Live risk ramp

Risk tiers: 0.25% -> 0.50% -> 0.75% -> 1.10%.

- Every tier requires both 30 completed trades and 30 calendar days.
- Advancement requires positive expectancy, compliant execution, and no breaker.
- First failure at a tier: step down one tier and reset the full 30-trade/30-day clock.
- Second failure at the same tier: latched manual review.
- Two failures anywhere in the ramp: latched manual review.
- Time at another tier never counts toward advancement.

### 15.3 Sequential sleeve rollout

- Sleeve 1 completes the full live ramp alone.
- Sleeve 2 may be introduced only after Sleeve 1 reaches full risk cleanly and improves combined portfolio OOS.
- Sleeve 3 follows only after Sleeve 2 completes its own validation.
- A new sleeve starts at 0.25%; proven sleeves retain their earned tier.
- Shared risk constraints may still reduce a proven sleeve's actual position size.
- After adding a sleeve, monitor individual and combined statistical behavior for at least 30 clean days before any further addition.
- Before Sleeve 2 or Sleeve 3 is approved, rerun the minimum-lot and stressed-margin feasibility matrix for the proposed combined portfolio using current account equity and broker specifications.
- A sleeve is ineligible if broker minimum volume routinely forces risk above its tier ceiling or if the combined portfolio cannot retain required margin headroom under HMR conditions.

## 16. Configuration immutability

This is a hard operational invariant.

- Strategy parameters and EA inputs must never change while any affected position is open.
- Configuration is immutable and versioned for the duration of a live validation tier.
- Any parameter change during a live validation tier resets that sleeve's complete 30-trade/30-day tier clock and invalidates the accumulated evidence for that tier.
- A material strategy change creates a new deployment version and requires the applicable IS/OOS, stress, demo, and live validation again.
- Parameter changes require the affected sleeve to be flat.
- Safety thresholds may be tightened during an emergency but may never be loosened without documented revalidation and a new approved version.
- Configuration changes, version identifiers, timestamps, operator identity, and reasons are audit logged.

## 17. Persistence, recovery, and manual reset

- Safety state and breaker latches survive terminal and PC restarts.
- Use redundant atomic snapshots with checksums.
- Missing or corrupted persistent state blocks new entries.
- Reconstruction from broker positions, orders, and history is diagnostic/protective only.
- Reconstruction never causes automatic resume.
- Existing stops remain managed while the system is quarantined.
- Any material mismatch requires documented manual restoration and approval.
- Monthly, permanent, and corruption resets can never be simple enable switches.
- Required reset evidence includes cause, diagnostic report, code/config version, validation evidence, approval identity, and timestamp.

## 18. Watchdog and restart policy

- An independent watchdog monitors the EA/MT5 heartbeat.
- It detects stale heartbeat, frozen process, terminal crash, and malformed health output.
- It never places trades or overrides safety state.
- Allow one automatic MT5 restart attempt.
- After restart, entries remain blocked until full broker/state reconciliation succeeds.
- A second failure within 24 hours creates a latched operational halt requiring manual review.
- Never create an endless restart loop.

## 19. Alerting

### Tier 1: immediate

- Any account or sleeve breaker.
- Lost broker connection, terminal/watchdog failure, or failed health monitor.
- Elevated rejection-rate threshold.
- Stop placement/confirmation failure.
- Margin-health breach or margin call.
- Exposure above trade, cluster, or portfolio caps.
- Persistent-state corruption or failed recovery.

### Tier 2: same-day digest

- Live performance outside the OOS-derived range.
- Sleeve risk-tier step-down.
- Spread/volatility protection events.
- News or maintenance flatten/resume activity.
- Failed automatic resume health check.

### Tier 3: periodic report

- Tier advancement.
- Equity and drawdown summaries.
- Trade logs and sleeve attribution.
- Execution-quality and parameter-health summaries.

Alerts must be deduplicated and rate-limited so Tier 1 remains rare and actionable.

## 20. Research and operational governance

### 20.1 Candidate pre-registration and freeze log

Every research attempt must have an immutable, timestamped candidate record before its first optimization or backtest result is viewed.

The record includes:

- unique candidate and hypothesis identifiers;
- creation timestamp and author;
- strategy family and economic/market rationale;
- complete entry, exit, stop, scale-out, pyramiding, time-stop, regime, session, and veto logic;
- symbols and timeframes;
- every parameter name, type, permitted range, grid/step, and fixed default;
- exact IS, rolling-forward, OOS, and final-holdout boundaries;
- data source/version and cost assumptions;
- optimizer score, acceptance gates, sample requirements, and stopping rules;
- source-code revision/hash and configuration hash; and
- the maximum number of optimization/candidate attempts authorized for that hypothesis family.

Rules:

- The freeze log is append-only; a registered candidate is never edited in place.
- Results may mark a candidate passed, rejected, or invalid due to data/execution error, but may not rewrite its hypothesis.
- Any logic, parameter-range, filter, symbol, timeframe, partition, or metric change creates a new candidate ID and an explicit parent/reason link.
- Once a dataset segment has been viewed as OOS or holdout, it is permanently marked exposed for that research lineage and cannot serve as untouched evidence for a revised descendant.
- A descendant requires a still-unseen reserve segment or genuinely new future data for its final untouched test.
- Failed attempts and abandoned candidates remain in the multiple-testing ledger; they are never deleted from the denominator or hidden from reports.
- Research may not expand the search space merely to pursue the Section 1 return aspiration.

### 20.2 Broker and data-provider risk

EA controls cannot protect against broker insolvency, withdrawal restrictions, regulatory changes, account freezes, prolonged venue outages, or materially unreliable data/execution.

- Perform a documented broker/counterparty review at least quarterly and before every increase in committed capital.
- Review the currently applicable legal entity and regulatory status, material client-agreement changes, withdrawal experience, unresolved complaints/support incidents, execution anomalies, outage history, and changes to negative-balance or fund-protection terms.
- Repeated withdrawal delays, unexplained account restrictions, material regulatory/licensing deterioration, prolonged outages, unresolved statement discrepancies, or persistent abnormal execution trigger an immediate pause on new entries and a manual full-withdrawal/venue-change review.
- The EA never initiates withdrawals or transfers automatically.
- Any test withdrawal requires explicit owner approval and is reconciled as an external cash flow, not trading PnL.
- Broker data is versioned and checked against an independent source for material price/history anomalies; disagreement pauses affected research or trading until resolved.

### 20.3 Live symbol and contract-specification monitoring

- Capture a versioned specification snapshot at initialization, on reconnection/restart, once per broker day, and immediately before each order calculation.
- Monitor contract size, tick size, tick-value calculation mode, profit/margin calculation mode, volume minimum/maximum/step, stop/freeze levels, execution/fill modes, quote/profit/margin currencies, trade permissions, and trading sessions.
- Separate expected price/currency-dependent tick-value movement and scheduled HMR changes from structural specification changes.
- Any structural change blocks new entries for the affected symbol and produces a Tier-1 alert.
- Re-run deterministic sizing, stop-validity, minimum-lot, normal-margin, and HMR-margin feasibility checks against the new specification.
- Existing exposure is re-evaluated immediately. If the new terms invalidate its stop, risk, margin, or closure assumptions, reduce or flatten it using the safest executable action.
- Resume only after documented review, a new approved specification version, and any required strategy revalidation.

### 20.4 Independent manual kill switch

An always-available break-glass procedure must bypass the EA, its persistence layer, and the watchdog.

Required sequence:

1. Prevent the automated stack from submitting new orders by disabling/stopping the relevant local or hosted terminal/session through an independent control path.
2. Close all open positions from a separate trusted MT5 terminal/mobile/broker-supported interface.
3. Cancel all pending orders.
4. Confirm directly against the broker account that positions and orders are zero.
5. If electronic access is unavailable, contact the broker through the pre-recorded emergency support/dealing path.
6. Record the incident and leave the EA in persistent quarantine; manual flattening never authorizes automatic restart.

- Keep the procedure and access instructions available outside the trading PC.
- Never store account passwords or recovery secrets in the design repository or EA logs.
- Rehearse the kill switch on demo before first live deployment and at least quarterly thereafter.
- A failed drill blocks live tier advancement until corrected.

### 20.5 Scheduled health reviews and post-mortems

- Run automated daily reconciliation and execution-quality checks.
- Produce a weekly sleeve/account digest.
- Conduct a documented monthly strategy-health review even when no breaker fires.
- Compare live results with OOS predictive ranges for expectancy, profit factor, drawdown, trade frequency, regime distribution, MAE/MFE, holding time, costs, slippage, rejections, missed signals, and time-stop/partial-exit behavior.
- Review virtual-ledger versus broker-statement reconciliation and the behavior of account-wide breakers under the current sleeve mix.
- Slow drift outside warning bands pauses tier advancement and may reduce risk or quarantine a sleeve even before a hard breaker.
- A health review may never tune live parameters in place; proposed changes return to Section 20.1 as a new pre-registered candidate.
- Every breaker, kill-switch event, persistence incident, exposure breach, or material execution anomaly receives a written post-mortem within five business days.
- The post-mortem records timeline, detected/undetected signals, root cause, financial and risk impact, containment, corrective actions, validation evidence, owner, and closure approval.

### 20.6 Tax, accounting, and audit records

- Preserve order-, deal-, position-, and original-trade-group-level records from day one.
- Record broker/server and UTC timestamps, account and deal IDs, symbol, direction, volume, prices, stop/target changes, gross PnL, spread estimate, commission, swap, slippage, net PnL, deposits, withdrawals, and balance adjustments.
- Attach candidate, code, configuration, sleeve, strategy, regime, risk-tier, signal, and exit/emergency reason identifiers.
- Store daily append-only exports separately from terminal logs and reconcile them monthly with official broker statements.
- Record cash flows separately so deposits/withdrawals do not appear as strategy returns or drawdowns.
- Retention period and tax classification must be confirmed with a qualified adviser for the owner's jurisdiction; the system must support durable export rather than attempting to provide tax advice.

## 21. Build sequence

1. Establish the append-only candidate freeze protocol/registry and write the independent kill-switch runbook; performance testing remains unauthorized.
2. Capture live JustMarkets Pro account and `ETHUSD.s` symbol specifications.
3. Build the non-performance minimum-lot and margin-feasibility audit covering realistic stop-distance envelopes, volume steps, normal leverage, HMR leverage, spread/cost stress, and USD 1,000 starting equity.
4. Build the tick-history/data-quality audit and freeze data partitions without viewing strategy OOS/holdout results.
5. Pre-register and freeze the initial Sleeve 1 hypothesis, exact parameter ranges, candidate budget, metrics, data boundaries, and source/configuration hashes.
6. Implement the shared safety kernel and its deterministic tests.
7. Implement persistent state, configuration versioning, and watchdog protocol.
8. Build live structural specification-change detection and the pause/revalidation workflow.
9. Successfully drill the independent kill switch on demo and append the evidence to its runbook.
10. Implement the regime and correlation modules.
11. Implement only the frozen Sleeve 1 strategy candidate behind the common sleeve interface; the other registered families remain unimplemented until separately frozen.
12. Build the MT5 real-tick, walk-forward, Monte Carlo, parameter-surface, and execution-stress pipeline without changing the frozen hypothesis.
13. Build trade/accounting exports, broker-statement reconciliation, and monthly health-review reports.
14. Run the pre-registered Sleeve 1 research pipeline without exposing the final holdout beyond its registered use.
15. Run untouched holdout validation.
16. Run demo graduation and complete the first scheduled health review and another kill-switch drill.
17. Complete the initial documented broker/counterparty review.
18. Begin the sequential live-risk ramp only after every gate passes.
19. Repeat candidate freeze, current-specification minimum-lot, combined HMR-margin, broker, specification, and operational-readiness reviews before implementing or adding each subsequent sleeve.

## 22. Definition of success

KingEA v1 succeeds only if it produces a reproducible, auditable candidate that passes every survival, data-quality, OOS, parameter-robustness, execution-stress, demo, operational-governance, and live-graduation gate. Achieved return is reported as an empirical result after those gates; the 500% CAGR and calendar-year figures in Section 1 do not define success or failure and cannot influence candidate selection. If no candidate passes the gates, the correct result is to report that no acceptable strategy was found rather than deploy an unsafe EA.
