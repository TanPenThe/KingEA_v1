# MT5_BUILD_6182_CONFORMANCE_TRANSITION_V1

Status: BLOCKED_PENDING_COMPATIBILITY_SCOPE_AND_MAINTENANCE_ACCESS.

The installed terminal, MetaTester and MetaEditor remain 5.0.0.6140. Maintenance was not initiated: this session is not elevated, and the accepted validation code deterministically rejects 6182. No update, compilation or tester execution occurred.

## Compatibility findings

- research_pipeline/native_conformance_control.py:178 requires terminal pins to declare 6140.
- research_pipeline/native_conformance_control.py:236-237 requires all three Layer-B build fields to equal 6140.
- research_pipeline/native_conformance_control.py:410 requires launch records to declare 6140.
- research_pipeline/decision_a_evidence.py:142 requires runtime-profile builds to equal 6140. A retained synthetic check with 6182 returns SWAP_PROFILE_NOT_AUTHORIZED.

The directive prohibits production repair. Fresh valid 6182 runtime profile, Layer B and SET cannot be produced with these predicates unchanged. Merely writing a JSON record with 6182 would not establish valid authority.

## Proposed separately reviewed repair

Define explicit, independently pinned conformance-only build authority for terminal, agent and compiler, with their exact executable hashes. Preserve historical 6140 semantics and prospective successor default denial. Review changes to both Python modules above before implementation; do not broadly replace 6140 literals or relax predicates. Reconcile resulting Python-source identity changes with the compile-stable source manifest and Layer A before compiling. No such repair is implemented here.

## Required continuation

1. Resolve the build-authority compatibility amendment and authorized source scope.
2. Perform separately recorded exact-6182 maintenance with suitable administrator access, without carrying a conformance config into the updater.
3. Capture actual installed identities and environment; stop on any build other than 6182.
4. Bind Layer A resources before compilation; compile with verified 6182 MetaEditor and check resource equality afterward.
5. Complete regressions and construct fresh profile, Layer B, SET and BOM-free INI under the reviewed authority.
6. Obtain the separately required zero-order capability-run approval. Its result is NOT_EXECUTED in this packet.
7. Seek independent review before separately authorized LONG.

## Limits and retained status

No live server/symbol/account facts were freshly acquired. No native behavior equivalence, offline capability, compilation, or 6182 runtime claim is made. Existing 6140 evidence remains unchanged historical provenance. The prior current-host isolation closure remains in force.

Candidate001 = QUARANTINED
NATIVE_LONG_CONFORMANCE = NOT_OBTAINED
SUCCESSOR_FREEZE = NOT_AUTHORIZED
B2 = LOCKED
