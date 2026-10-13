# Decision A implementation scope and diff plan

Planning only. Implementation must be separately scoped/authorized. The adopted specification hash in ADOPTION_RECORD.json is the controlling binding. B2 = LOCKED.

## Ordered work and review boundaries

1. Before any source edit, capture a fresh PRE_TOOLING manifest of every proposed edited source, all transitive EA dependencies, tests, governing contracts, Candidate and Decision S artifacts. Bind the adopted specification SHA-256 and exact implementation authorization. Record existing dirty files without resetting them. PLANNING_BASELINE.json is not this future manifest. Recheck immediately before the first edit; source drift requires reconciliation, not silent rebasing.
2. Define independently pinned Decision A tester-profile receipt and consumer validation. Bind exact executable/dependencies/compiler/terminal/agent/SET/INI/specification and local/nonvisual/DLL/bridge facts. A manifest copy is evidence to compare, never root of trust. No directory latest, payload-selected authority or hash-only authorization. Profile missing/mismatch rejects before executable rendering and at downstream ingestion/finalization. Existing successor canonical rejection/state rules remain intact.
3. Implement a pure full-close component lifecycle ledger with immutable deal facts/read flags and fixed pre-entry equity/risk denominators. Exactly two distinct tickets; no multiple-deal normalization. Define explicit terminal failure and one-time projection state. Preserve old evidence/schema consumers; introduce an explicit prospective Decision A evidence semantic discriminator bound to the adopted specification, never relabel old V2 evidence silently. Final discriminator must be reviewed before implementation.
4. Extend callback-bound deal scalars with DEAL_PROFIT, DEAL_REASON and exit DEAL_SL using bool getters. Add exact bound-position effective-entry POSITION_SL reconciliation with successful read flags and stable ID. Do not enumerate history or defer exact deal-property reads outside their callback authority. Cache immutable scalars and defer hashing/persistence/economics.
5. Add static-stop order guard and effective-entry proof. Only entry may carry approved S0; no post-entry SLTP or alternate mutation sink. Verify the actual controlled profile independently. POSITION/REQUEST observer copies bounded facts into a preallocated 256-slot ring, latches overflow/ambiguity, and drains outside capture. Do not claim detection of all loss from MT5's upstream 1024 queue. Isolation/static code remains provenance authority.
6. Integrate the component ledger into full normal-close finalization: replace equity-delta group P&L with the adopted component oracle, populate existing Stage13 signed fields exactly once, and derive summaries from that same projection. Preserve valid-pre-end normal-close precedence and immutable boundary conflicts. Interim audit facts remain non-financial.
7. Connect non-booking operational safety-equity state so entry costs/open mark and authenticated full-close components remain visible before projection. Preserve accepted safety-equity design and continuity. No partial-position ledger or Decision S changes.
8. Disable entry into the reduction caller for the Decision A lifecycle and make any attempted reduction request fail closed. Do not remove the safety trigger, invent flattening fallback, or pretend fail-closed accounting resolves open exposure. Until separately approved operational behavior exists for a reduction trigger, readiness remains blocked for runs reaching it; the trigger must invalidate research and prohibit continued result acceptance.
9. Run deterministic tests and applicable existing regressions under separate implementation authorization. Compare post-tooling source bytes with intended diffs; Candidate, Stage13 schema source and Decision S artifacts must be byte-identical. Produce diff, test counts, semantic-version binding, profile-negative proof and unresolved blockers for independent acceptance. Native work is a later separate phase.

## Exact proposed production file inventory

| File | Proposed diff |
|---|---|
| MQL5/Experts/KingEA/GuardedResearchTester.mq5 | Full-close integration, static send guard, entry stop proof, reduction-path denial, non-booking safety integration and summary source |
| MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh | Thin dispatch into Decision A callbacks/profile/ledger; preserve historical native-cost path |
| MQL5/Include/KingEA/DecisionADealAdapter.mqh (new) | Bool scalar capture and exact effective-entry stop reconciliation under adopted access scope |
| MQL5/Include/KingEA/DecisionALifecycle.mqh (new) | Pure full-close lifecycle, duplicates, component oracle and one-time projection eligibility |
| MQL5/Include/KingEA/DecisionAStaticStop.mqh (new) | S0 binding, static guard, bounded mutation observer and independent-profile comparison |
| research_pipeline/decision_a_evidence.py (new) | Strict prospective profile/evidence validation and oracle audit |
| research_pipeline/successor_evidence.py | Require independently pinned Decision A specification/profile/evidence semantics for applicable successor scope; no historical weakening |

The existing authorization/render/ingest/normal/boundary hooks already call successor validation; reuse that seam rather than modifying all gate implementations. Confirm call coverage before edits; any uncovered entrypoint is a reviewable scope addition, not assumed permission.

Protected unchanged sources: AccountingEvents.mqh (Stage13 schema v1), CandidateEthSt001.mqh, SafetyKernel.mqh, OperationalSafety.mqh, original NativeCostMetadataAdapter.mqh/NativeCostEvidence.mqh and Decision S documents. Put new prospective logic in the new modules. If implementation proves an additional edit necessary, expose the exact proposed diff/scope before changing protected sources.

## Operational conflict requiring explicit resolution

The adopted Decision A cannot execute safety reductions, while the strategy's existing governed spread safety rule can request one. Merely denying that order does not specify adequate exposure management. Do not implement an invented resolution: research validity must fail closed, and operational response must be separately decided before native readiness. This is retained as a blocker without reopening Decision S or changing the accepted accounting oracle.
