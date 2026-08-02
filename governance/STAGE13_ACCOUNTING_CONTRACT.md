# KingEA Stage 13 Accounting, Reconciliation, and Health Contract

## Status and authorization

- Build ID: `KINGEA-STAGE13-20260801-A`
- Candidate: `CAND-ETH-ST-001`
- Status: implementation and synthetic contract verification only
- Candidate-budget consumption: `0`
- Result-bearing development, OOS, holdout, demo/live order, Live2, watchdog,
  and standdown-removal authorization: denied

Stage 13 installs one deep accounting interface with pure ledger,
reconciliation, recovery, health-review, and export behavior.  Tester facts,
read-only MT5 history, and English MT5 HTML statements are adapters at that
seam.  The raw account login is not a ledger or governance field.

## Immutable accounting

Events are ordered deterministically, assigned monotonic sequences, and linked
with canonical SHA-256 hashes.  Duplicate IDs, gaps, corruption, conflicting
events, invalid decimal values, unknown schemas, or identity mismatches fail
closed.  Healthy catch-up appends to a valid checkpoint; a missing or corrupt
ledger cannot reconstruct itself or authorize resume.

Broker profit, commission, swap, and fee are summed once using their signed
values.  Spread and slippage remain execution-quality attribution because
their price effects are already embedded in realized PnL.  Deposits,
withdrawals, credits, charges, and corrections remain external cash flows and
adjust performance high-water marks dollar-for-dollar.  Account and virtual
sleeve ledgers remain separate.  Valuation facts are required at material
events, closed M30 bars, and broker-day close for the future runtime adapter.

The Stage 12 tester retains its legacy completion frame and additionally emits
versioned Stage 13 event frames plus a final event-count/root frame.  Ledger
trade count, net amount, net return, and fixed-risk R must agree exactly with
the legacy completion facts.  A mismatch invalidates the pass.

## Reconciliation and escalation

The initial statement adapter accepts only a recognized English MT5 HTML
deals table.  Tickets/cardinality match exactly; time tolerance is one second,
volume tolerance is governed by lot step, price tolerance by tick size, and
money is compared per component at account-currency precision.  Opposing
errors may not net away.

- Missing/invalid/unresolved statement: `NOT_RECONCILED`; monthly sign-off,
  tier advancement, capital increase, and new-sleeve rollout are blocked.
- Material mismatch: `RECONCILIATION_QUARANTINE`; all new account entries are
  blocked while independently safe exposure remains managed.
- Three failed month closes among the latest six required broker months, or
  two quarantine activations inside rolling 90 broker days, latch
  `CUMULATIVE_ACCOUNTING_REVIEW`.
- An isolated review does not erase its cumulative-counter event.  When gates
  overlap, cumulative review governs.

Isolated recovery requires preserved originals, append-only corrections,
documented root cause, fresh broker evidence, exact replay, regression proof,
and explicit owner approval.  It resumes at half the earned tier and requires
five consecutive clean broker days.  Cumulative recovery additionally
reconciles every outstanding month, archives the active event set, starts a
new epoch, and resumes only at 0.25% with a fresh 30-trade/30-day ramp.

## Health and durable export

Canonical evidence is hash-chained JSONL with derived CSV and Markdown.  The
monthly report covers the completed broker month and trailing 90 broker days.
It consumes only a separately authorized, content-addressed OOS expected-range
manifest; Stage 13 cannot create or tune one.  Missing ranges are
`NOT_EVALUABLE`.  A range breach is `OUTSIDE_RANGE`, pauses tier advancement
and capital/sleeve expansion, and requires review without automatically
flattening or changing parameters.

The raw MT5 report stays outside the repository.  Governance records only its
hash, parser version, period, account fingerprint, and redacted suffix.  A
JustMarkets-specific statement adapter remains unimplemented until a genuine
sample is separately supplied and reviewed.

Completion authorizes preparation and owner review of a Stage 14 development
manifest only.  It does not authorize execution.
