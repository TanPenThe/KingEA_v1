# Rendering error metadata repair

IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW
SUCCESSOR_FREEZE = NOT_AUTHORIZED
B2 = LOCKED

The exact reviewed one-line Stage14 change is applied. No other Stage14 byte changes occurred. Source baselines were freshly captured and compared with prior POST_TOOLING before editing; unexpected drift was absent. EXACT_APPLIED.diff is the authorized patch. IMPLEMENTATION.diff separates this turn from all previous working-tree edits.

## Required proof

`test_post_capture_control_drift_preserves_rendering_error_metadata` changes control.json after capture and before the existing authorization check. It proves:

1. The post-capture authorization predicate denies the changed control.
2. Exception text is exactly SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED.
3. Exception stage is rendering.
4. Detail is PINNED_CONTROL_HASH_MISMATCH.
5. No return bundle, SET or INI exists; no file or accepted artifact is written by rendering.
6. Manifest/root bindings, supplied authorization, and external control pin remain unchanged. The deliberate test mutation is the only filesystem change. No next_status is returned.
7. Existing successor tests, including E01–E18 renderer negatives, pass in full discovery.
8. Historical audit sources/fixtures are unchanged; existing detailed historical tests pass.
9. Full Python discovery passes: 244 tests, OK. python_suite.log retains the complete run.

DRIFT_REPRODUCTION.json independently records the repaired exception type, canonical reason, rendering stage and diagnostic detail with rendered_bundle=false. Authorization predicates, trusted resolution, immutable input capture and V2/V3 semantics are byte-identical to the previous checkpoint. Candidate and Stage13 sources are unchanged. Rendering eligibility is unchanged.

## Already-authorized combined continuation

Separate from the Stage14 one-line scope, DecisionALifecycle and its MQL test harness were advanced under the existing combined authorization. A failed group cannot clear its invalid latch through Begin for a new group. OperationalContribution calculates non-booking signed current-position deal components and residual mark/swap separately from accepted financial projection. It rejects missing, foreign or pending evidence and returns zero after a completed projection handoff. These remain unintegrated foundations, not implemented production acceptance behavior.

The expanded MQL harness checks the operational component arithmetic and invalid-latch Begin guard. MetaEditor compilation: 0 errors, 0 warnings. The harness was NOT runtime-executed. COMBINED_CONTINUATION.diff isolates these changes. Compiler identity, command, source-copy equality, log and EX5 hashes are retained.

## Remaining combined work

Native production dispatch and completion reconciliation; static-stop evidence/profile integration; operational safety and one-attempt containment wiring; full V3 sidecar and referenced-evidence verification; prospective V3 successor migration; full A/SP/SS/S test mapping; independent implementation review. The prior renderer error-metadata blocker is resolved by this repair. No V3, readiness or implementation acceptance is self-issued.

No MT5/MetaTester execution, capacity work, Candidate run, successor root/freeze/attempt or gate advancement occurred. Protected scope remains byte-identical as recorded in POST_TOOLING.
