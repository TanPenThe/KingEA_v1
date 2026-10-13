# Native production conformance preflight — blocked before launch

Owner authorization: NON_CANDIDATE_NATIVE_PRODUCTION_PATH_CONFORMANCE_ONLY. Combined implementation is review-accepted per this directive. B2 = LOCKED; SUCCESSOR_FREEZE = NOT_AUTHORIZED.

Primary result: NON_CANDIDATE_PRODUCTION_FIXTURE_INTERFACE_ABSENT.
Additional blockers: SHORT_PRODUCTION_PROFILE_PATH_UNAVAILABLE; NON_CANDIDATE_V3_CONTROL_CONTEXT_ABSENT; NATIVE_ORDER_CHECK_EVIDENCE_ABSENT.

No MT5/MetaTester launch, source change, compilation, capacity sample, cleanup, Candidate execution or research root occurred. All 252 inventoried artifacts match the previous implementation checkpoint. Terminal/MetaTester process inspection returned an empty list. No PRE_NATIVE_PRODUCTION_CONFORMANCE is issued: exact launch fixtures, SET/INI and a permitted runnable route do not yet exist. This report is an integrity preflight, not a launch freeze or native result.

| Required proof | Exact source evidence | Consequence |
|---|---|---|
| Non-Candidate fixed fixture via actual EA | GuardedResearchTester.mq5:430-446 accepts research development/Gate1, forward/Gate2, OOS or holdout scopes. :1496-1504 constructs and calls KingEAEvaluateSleeveEthSt001. Inputs :18-66 contain no native fixed-fixture dispatch. Dry benchmark and zero-entry diagnostic paths cannot execute the required lifecycle. | Current native lifecycle would require Candidate signal logic/research authorization. Renaming a manifest or selecting dates does not make that a non-Candidate fixture. |
| Non-Candidate native context | GuardedNativeCostIntegration.mqh:47-60 requires candidate_id CAND-ETH-ST-002. | A conformance identity is rejected; supplying successor identity would conceal the authority mismatch. |
| Independent SHORT native evidence | GuardedNativeCostIntegration.mqh:76 rejects side != 1. decision_a_evidence.py:151-152 rejects non-LONG; :335 constructs original side LONG, with LONG snapshot assumptions downstream. | No SET override can exercise and reconstruct SHORT. Reusing LONG authority is explicitly prohibited. |
| Independent conformance R/S/A/seal without successor freeze/Gate1 | successor_evidence.py:61-80 builds through prospective control context with freeze/execution receipts; :194 requires successor identity and :221-226 binds Gate1 execution/freeze. | Production successor consumer cannot supply audit-only conformance authority. Fake successor receipts would weaken the accepted trust boundary. |
| Entry request/check/result evidence | GuardedResearchTester.mq5:840-859 guarded seam calls OrderSend; source has no OrderCheck call. | Actual OrderCheck result cannot be proved from the current integrated path; receipt or standalone harness cannot substitute. |

LONG: NOT_RUN — fixed non-Candidate route absent.
SHORT: NOT_RUN — fixed route absent and hard-coded LONG authority/builder.
BOUNDARY: NOT_RUN — fixed route absent; no approved way to deterministically create residual exposure without Candidate execution.
These are infrastructure conformance blockers, not strategy failures. No performance output was produced or interpreted.

Proposed smallest next scope, for separate review and source-edit authorization

1. Add an explicit fixed-fixture dispatcher inside GuardedResearchTester that bypasses Candidate signal evaluation entirely while using the exact existing guarded request, callbacks, lifecycle, safety, Stage13 and native capture functions. Bind immutable predeclared times/actions/side/volume/S0, zero optimization and development-only data. No copied accounting implementation, no externally mutable commands, no synthetic deal/property authority.
2. Introduce an independently pinned conformance-only control identity, distinct from successor freeze/root/Gate1. It may authorize only the fixed infrastructure fixture and produce conformance-labelled native archives. It must not become a successor acceptance fallback or selectable result. Reuse the R/S/A/lifecycle validators; keep production successor predicates unchanged.
3. Specify a SHORT conformance bootstrap scope that permits collecting SHORT evidence without claiming prior SHORT acceptance. Parameterize actual side/mark validation in the shared builder and native context for this scope, then require independent acceptance of obtained SHORT proof before any prospective successor SHORT use. Do not relabel LONG proof.
4. Retain exact native OrderCheck results at the existing guarded send seam if still required. Define its observation/rejection semantics explicitly; no automatic retry or new fallback. This is a source change, not launch preparation.
5. Recompile and rerun deterministic isolation/negative tests after those changes, independently review the scope, then resume native conformance. Immediately before the first authorized launch bind fresh source/EX5/profile/SET/INI/account/symbol facts, calculate required capacity including temporary copies and independent 30 GiB floor, report free space/shortfall and recheck. Do not select/adapt development dates after observing outcomes.

Likely existing files requiring explicit scoped changes: MQL5/Experts/KingEA/GuardedResearchTester.mq5, MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh, research_pipeline/decision_a_evidence.py. A separate conformance control module is preferable to relaxing successor_evidence.py; exact API/schema needs review first. No protected Candidate, Stage13, safety source or adopted economic rule needs to change merely to provide the fixture route. This is a proposed scope, not an applied diff or implementation authorization.

The current directive states: “No source repair is authorized inside this phase.” Therefore these blockers are reported without implementing a bypass or attempting a launch known to violate the permitted path. A failed initialization run would not prove the requested lifecycle and would add no evidence that resolves these source-level constraints.
