# KingEA Shared Safety Kernel Contract

Status: IMPLEMENTED NON-PERFORMANCE MODULE  
Build ID: `KINGEA-SAFETY-KERNEL-TEST-20260726-A`

## Interface

`KingEAEvaluateSafety(request, facts, prior_state, decision)` is the sole public
evaluation interface. It is pure: callers supply immutable intent, broker/market
facts, and prior safety state; the kernel returns an action plan and next state.

The kernel never reads MT5 history or account state directly and contains no
order, position, indicator, tester-statistics, OOS, holdout, or `MqlTick.flags`
capability. Collection and future execution are adapters outside this
non-trading implementation stage.

## Fixed policy

- Account breakers: 3% daily, 6% weekly, 10% monthly, 20% from equity high.
- Sleeve breakers: 4% weekly, 7% monthly, 12% from virtual equity high.
- Risk caps: 1.50% cluster, 2.20% portfolio, and 50% of nearest remaining
  account/sleeve breaker headroom.
- Margin floors: 500% stressed margin level and 80% stressed free
  margin/equity, using the greater of live margin and an internally calculated
  1:200 HMR proxy.
- Weekly recovery: half risk and five consecutive clean broker days.
- Recovery throttle: first activation resets the streak; second activation in
  one attempt latches review and forces any approved restart to 0.25%.
- Manual-review approval deliberately preserves `force_bottom_tier`. The pin
  survives broker-day/week transitions and may be cleared only by the separately
  governed 30-trade/30-day tier-advancement process; approval itself never
  restores the previously earned tier.
- Frequency escalation: the third weekly breaker within rolling 90 broker days
  latches cumulative review. Successful review archives the active set and
  begins a fresh escalation epoch.
- Spread actions: above 2× blocks entry; above 2.5× requests a 50% reduction or
  flatten if broker volume rules make it infeasible; persistent above 3×
  requests flatten.
- Protected profit contributes zero open-risk credit.
- Invalid facts, corrupted state, stale safety inputs, unknown exposure, or
  contradictory configuration fail closed.

Daily resets do not erase weekly loss. OOS must validate these fixed rules and
may never tune them to rescue Candidate 001.

## Authorization

The module and its deterministic harness are non-trading. Completion authorizes
only persistent-state, configuration-versioning, and watchdog work. Performance
testing, optimization, OOS/holdout access, and order placement remain prohibited.
