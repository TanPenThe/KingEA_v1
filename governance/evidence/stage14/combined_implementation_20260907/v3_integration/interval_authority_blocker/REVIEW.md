# Swap interval source-authority blocker

IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW

SUCCESSOR_FREEZE = NOT_AUTHORIZED; B2 = LOCKED.

Combined production implementation is not materially complete. This packet is a source-authority escalation under the owner's semantic-amendment stop condition, not a request to reauthorize already approved implementation files. No production source was changed in this investigation. The accepted Stage14 finalization change remains intact.

## Finding and reproduction

`SWAP_INTERVAL_SOURCE_AUTHORITY_UNSPECIFIED` blocks truthful production generation of the required `interval_authority_hash` evidence for arbitrary future reduction/full-close intervals.

The adopted Decision S revision requires independently authenticated zero interval accrual/correction. It explicitly rejects both a calendar schedule and a difference chosen to force conservation as authentication. The subsequent accepted native proof establishes realized/residual swap allocation for the bound tested profile. Its own limitations explicitly state that it does not establish a general authenticated no-accrual/correction source for arbitrary intervals. The later consolidation preserves disjoint-swap reconciliation and supplies no additional interval source or access authority.

The implementation currently checks a run/group-bound supporting record with `no_accrual_authenticated == true`, the native profile hash, and before/after snapshot hashes. It does not resolve an independent authority capable of establishing that boolean. The reference inventory and independent final seal authenticate retained bytes and membership; the adopted seal is explicitly `COMPLETED_PACKAGE_INTEGRITY_ONLY`. Its integrity role cannot supply missing native source authority.

`reproduce.py` uses synthetic fixture controls and a signed-swap reduced normal-close package. The production consumer accepts its locally asserted interval records without a native interval source. `REPRODUCTION.json` records that acceptance and the complete records. This is an implementation-gap probe, not a successful production or research test. It does not append/finalize a result, create a successor or execute MQL. The fixture's independent controls are test doubles, not real owner authorization.

The MQL draft has the same missing dependency: `DecisionALifecycle.Reconcile` checks `before_swap - deal.swap - residual.swap == 0` without accepting or validating independent interval authority. Wiring this directly into production would promote conservation arithmetic into the authority the adopted specification expressly requires separately.

## Evidence links

- [Adopted S component and interval rules](C:/KingEA_v1/governance/review/decision_s_tester_trust_20260907/DECISION_S_REVISED.md): residual swap reconciliation requires authenticated interval accrual/correction; initial interval must authenticate zero.
- [Native proof limitations](C:/KingEA_v1/governance/evidence/stage14/decision_s_native_20260907/FINDINGS.md:47): accepted observed split does not establish a general interval source.
- [Reviewer acceptance](C:/KingEA_v1/governance/review/decision_s_operational_closure_20260907/REVIEWER_DIRECTIVE.txt): bound profile and realized-portion semantics remain accepted.
- [Final S specification](C:/KingEA_v1/governance/review/decision_s_operational_closure_20260907/DECISION_S_FINAL_SPECIFICATION.md): incorporates original component rules unchanged.
- [Adopted inventory amendment](C:/KingEA_v1/governance/evidence/stage14/combined_implementation_20260907/inventory_binding_blocker/PROPOSED_AMENDMENT.md): seal has completed-package integrity authority only.
- [Python validation](C:/KingEA_v1/research_pipeline/decision_a_evidence.py:621).
- [MQL lifecycle](C:/KingEA_v1/MQL5/Include/KingEA/DecisionALifecycle.mqh).

This finding does not reopen the accepted LONG realized/residual split or residual S0 observations. It distinguishes that accepted native behavior from the required per-interval proof source.

## Proposed repair sequence

1. Retain the existing accounting formulas, profile limits and fail-closed interval requirement. Do not manufacture interval evidence from time-of-day, equal timestamps, callback ordering, missing transactions, volume allocation, a balanced equation, or an integrity seal.
2. Separately review an exact interval source-authority specification. It must name the observable native property/event or independently controlled execution guarantee, the permitted access, applicable interval limits, identity binding, correction/rollover treatment and failure conditions. The retained files do not establish such a general source, so this packet does not invent one. A prospective reviewer must either supply that authority or explicitly amend the zero-interval evidence requirement. The latter would change adopted S semantics and is not covered by implementation authorization.
3. Once that authority is adopted, resolve its exact rule hash through independent successor control. Require each interval receipt to bind run/group/position/order/deal, exact before/after snapshot hashes, source observations/read flags, the adopted authority rule and explicit zero-accrual result. A payload copy cannot select the rule; an integrity-only seal cannot grant it authority.
4. In the already authorized `DecisionADealAdapter.mqh`, capture only the newly approved source. In `DecisionALifecycle.mqh`, require validated interval authority before applying realized swap or preparing a terminal projection. Continue retaining operational facts when unavailable; do not invent a new flatten trigger.
5. In already authorized `decision_a_evidence.py` and `successor_evidence.py`, verify the same independent rule and per-interval bindings before accepted V3 aggregation. Preserve canonical `SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED`, with stage/detail `SWAP_INTERVAL_UNAUTHENTICATED` or the adopted specific detail.
6. Add negative tests for missing source, assertion-only record, arithmetic-only proof, calendar-only proof, wrong position/interval, stale source rule, co-tampered assertion plus integrity seal, observed correction and rollover ambiguity. Each must prove no accepted V3 result or Candidate Stage13 completion. Positive tests must use an explicitly synthetic implementation of the adopted source, labeled synthetic, until separately authorized native conformance.
7. Resume the remaining native integration and full verification within existing scope. No additional file authorization is presently requested. Native proof, if required to establish the source, needs separate runtime authorization; none is requested or exercised by this packet.

## Other integration finding resolved without amendment

The tester's reduction formula rounds residual volume down; the protected SafetyKernel rounds close volume down. For odd lot-unit counts these differ. The adopted S specification explicitly preserves the tester formula (`Vr_target=floor(V*0.5/step)*step; q=V-Vr_target`), so its production caller must retain that formula. This is not an outstanding blocker and no protected safety source was modified.

## Remaining implementation/readiness matrix

| Item | Disposition |
|---|---|
| Stage14 renderer trust, error metadata and V3 finalization gating | Owner reports independently accepted; unchanged |
| Prospective V3 R/S/A/independent-seal consumer | Implemented, synthetic tests pass; interval source gap prevents implementation acceptance |
| Historical audit-only isolation | Existing regressions retained; no compatibility change |
| FILE_COMMON immutable manifest/calendar capture | Existing implementation retained; no shared trading-input fallback introduced |
| Native DEAL_ADD dispatch, terminality and exact completion | Draft modules exist; production still connected to legacy ledger |
| Effective entry/residual S0 and complete runtime profile binding | Production integration incomplete |
| V3 normal/reduction/boundary ledger and actual supporting evidence production | Incomplete; cannot truthfully create interval authority under current inputs |
| Operational safety equity and atomic single Stage13 handoff | Draft accounting exists; production integration incomplete |
| Sticky research invalidity, independent exposure control and one-attempt containment | Draft models exist; production integration incomplete |
| Containment evidence isolation in actual native output | Production integration incomplete |
| A01–A25, SP/SS, S01–S22 and containment full production mapping | Incomplete; current Python tests do not substitute for this mapping |
| Python suite and MQL compilation | See retained logs/provenance; passing checks do not close the reproduced gap |
| LONG tested native swap profile and S0 retention | Accepted for exact retained profile, unchanged |
| SHORT conformance and actual integrated production runtime | Outstanding; no runtime authorized |
| Protected sources, Candidate parameters and adopted records | Byte-equality report provided |
| Independent implementation acceptance, successor readiness/freeze | Not granted |
| B2 / research execution / Gate 2 | Locked / not executed / no advancement |

## Delivery notes

`CURRENT_IMPLEMENTATION.diff` isolates the combined implementation from the original FINAL_PRE_TOOLING before-bytes, including new authorized modules and test additions. It is a current incomplete diff, not a completion claim. `V3_CONTINUATION.diff` isolates changes since the V3 integration baseline. `POST_TOOLING.json` binds current source bytes and protected equality. `COMPILE_PROVENANCE.json` binds compiler/source/dependency/log/EX5 bytes; both MQL builds are compile-only. `ARTIFACT_HASHES.json` binds this review packet, exact evidence sources and all outputs, excluding itself.
