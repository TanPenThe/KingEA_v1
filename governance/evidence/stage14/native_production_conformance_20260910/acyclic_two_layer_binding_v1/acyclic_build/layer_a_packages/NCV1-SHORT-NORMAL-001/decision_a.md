# Decision A adopted specification — controlled Strategy Tester only

Authority: owner's explicit decision in this conversation, recorded 2026-09-07. This file records that decision; its hash is a specification binding, not an execution/freeze receipt or independently signed approval.

DECISION_A_SPECIFICATION = ADOPTED_FOR_CONTROLLED_STRATEGY_TESTER

STRATEGY_TESTER_STATIC_STOP_PROVENANCE = RESOLVED_BY_CONTROLLED_CONTEXT_DESIGN

DEMO_LIVE_STOP_PROVENANCE = UNRESOLVED

DECISION_A_IMPLEMENTATION = NOT_YET_ACCEPTED

DECISION_S = NOT_ADOPTED; SUCCESSOR_FREEZE = NOT_AUTHORIZED; B2 = LOCKED.

## Adopted lifecycle and accounting

Exactly one authenticated entry deal and one authenticated full exit. No partial order fill, safety reduction/partial-position lifecycle, add-on, reversal or multiple exit lifecycle. The safety-reduction caller is unavailable to this lifecycle until Decision S is separately adopted and proven. This does not authorize deletion of the governed safety rule or automatic replacement by full flattening.

```text
gross = exit DEAL_PROFIT
commission = entry commission + exit commission
fee = entry fee + exit fee
swap = exit DEAL_SWAP
group_net = gross + commission + fee + swap
net_return = group_net / authenticated pre-entry accounting equity
net_R = group_net / original approved risk money
```

Signed components first enter the non-financial lifecycle ledger. Exactly one Stage13 schema-v1 TRADE_GROUP_CLOSE financially projects the group. Account/terminal equity delta cannot replace the component sum. Retain the accepted successful-zero/failed-read distinction, identical-callback idempotency, conflicting-duplicate rejection, second-projection rejection, external-cash isolation and immutable normal/boundary precedence. Operational safety consumes the accepted non-booking component valuation; no duplicate financial posting.

## STATIC_PROTECTIVE_STOP_INVARIANT

Entry intent binds canonical S0 and run/candidate/configuration/branch/partition/group/stable position identity. Authenticated effective entry stop must equal S0. Frozen execution source has no authorized post-entry SL mutation path. Independently verified controlled Strategy Tester profile is mandatory. There must be no observed unexplained bound-position modification. An SL exit requires successful DEAL_REASON == DEAL_REASON_SL and exit DEAL_SL == canonical S0.

Final equality is insufficient after context-integrity loss. Any isolation/profile/source violation fails closed. Transaction observations detect violations; they are not the completeness authority. Authenticated manual intervention makes the run research-invalid; unknown modification origin fails closed. Financial truth does not confer selection eligibility.

## Mandatory tester trust profile

Prospective evidence binds exact EA and transitive dependency hashes, exact compiler and terminal/agent build, exact SET/INI/specification inputs, verified MQL_TESTER, local/nonvisual profile, DLL imports disabled, no external command/import bridge, no shared-file input capable of modifying trading state, no alternate order/SL modification sink, and no post-entry SLTP/PositionModify path. FILE_COMMON is allowed only for governed evidence output whose contents cannot alter stop/trading state. The actual profile must be verified, not asserted by the EA payload alone.

## Incorporated review and precedence

The owner's decision above controls any conflict in older proposed drafts. Retained component oracle, safety projection and boundary/duplicate semantics in ../decision_a_source_authority_20260907 remain the accepted design. Static-context feasibility in ../static_stop_feasibility_20260907 replaces a requirement for complete live-style modification attribution in controlled tester research only. Older NOT_ADOPTED labels remain historical. Exact incorporated document hashes are recorded in ADOPTION_RECORD.json.

## Limits

Adoption does not authorize implementation, research execution, successor freezing or demo/live provenance. Current engineering authorization is preparation of a separately scoped implementation plan. No Decision S implementation, housekeeping change, MT5 launch, capacity work, research root or attempt. Actual controlled-context evidence, implementation verification and independent acceptance remain required.
