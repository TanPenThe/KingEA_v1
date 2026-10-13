# KingEA Stage 8 Specification Monitor Contract

Status: IMPLEMENTED NON-TRADING INFRASTRUCTURE  
Build ID: `KINGEA-STAGE8-20260728-A`

## Interface and capture

- `KingEAEvaluateSpecification(approved, observed, request, prior, decision)`
  is the sole public evaluation interface.
- The module is pure. Broker reads and the calculator-only
  `OrderCalcProfit`/`OrderCalcMargin` calls live in the read-only adapter.
- Manifests and state are keyed by `symbol_id`. Stage 8 registers only
  `ETHUSD.s`; future symbols require independent manifests.
- Captures are required at initialization, reconnect/restart, broker-day
  transition, each normal 60-second poll, and immediately before sizing.
- Demo2 and Live2 observations and approvals are never interchangeable.

## Change policy

- Unreviewed changes always block entry.
- Risk-critical changes include any change affecting price/volume
  normalization, contract value, currency conversion, margin, supported
  execution, stops, or effective strategy/closure sessions.
- A confirmed risk-critical baseline replacement resets the affected sleeve to
  0.25% and the normal 30-trade/30-day advancement clock.
- Administrative tier preservation requires affirmative proof that sizing,
  stops, margin, execution, sessions, and strategy assumptions are unchanged.
  Missing proof promotes the change to risk-critical.
- Temporary permission or access restrictions block entry but are not written
  into the approved baseline.
- Tick-value movement is expected only when the one-tick profit probe agrees
  within the greater of 0.01 account-currency units and 0.1%.
- Scheduled HMR requires an authoritative active calendar context, no other
  structural change, margin inside the frozen 1:200 envelope, margin level of
  at least 500%, and free margin of at least 80% of equity.

## Confirmation and action precedence

- A non-immediate risk change requires a matching independent second capture
  after approximately two seconds.
- If that capture returns to baseline, entry remains blocked until the next
  normal 60-second scheduled poll also matches baseline. An immediate third
  read cannot substitute for the scheduled poll.
- A late, missing, invalid, or inconsistent scheduled poll restarts the full
  60-second confirmation requirement.
- Two different changed captures classify the source as unstable and
  quarantine unresolved exposure. The monitor never selects one arbitrarily.
- Proven stop, volume, margin, or closure danger overrides the confirmation
  delay. Safe exposure may remain managed; infeasible reduction requests
  flatten, and unavailable closure capability quarantines.

## Baseline governance

- Specifications are immutable, content-addressed records. Superseded versions
  remain append-only.
- The approved specification hash is a field of the Stage 7 deployment
  configuration, so a baseline update creates a new configuration hash and
  validation epoch.
- Replacement requires feasibility evidence, documented classification, and
  explicit owner approval of the new specification hash.
- The current Demo2 capture is a non-deployable DRAFT observation. It is not an
  approved baseline and cannot authorize entries.

## Prohibitions

No Stage 8 artifact can submit, modify, or close orders. Strategy history,
indicators, performance statistics, optimization, OOS/holdout access, network
calls, DLL imports, and tick-flag inspection are prohibited.
