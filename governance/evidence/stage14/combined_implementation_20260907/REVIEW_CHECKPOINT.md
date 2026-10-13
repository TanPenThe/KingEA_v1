# Combined implementation checkpoint

IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW
COMBINED_IMPLEMENTATION_COMPLETE = FALSE
SUCCESSOR_READINESS = NOT_READY
SUCCESSOR_FREEZE = NOT_AUTHORIZED
B2 = LOCKED

This is a partial implementation checkpoint, not the requested completed A/S/V3 integration or an acceptance packet. No Terminal, MetaTester, native harness execution, capacity sample, Candidate launch, research root, freeze or attempt occurred.

## Implemented and verified

- Captured FINAL_PRE_TOOLING and immediately rechecked it before editing. Preserved exact before bytes and preexisting working-tree changes.
- GuardedResearchTester now captures calendar/manifest local input bytes once; removed shared fallback. Calendar parsing uses the captured, hashed byte buffer. This does not yet complete independently pinned renderer authority.
- Added separate draft native scalar adapter, lifecycle and static-stop modules; these are not connected to production. Added Python immutable-input, native-profile, exposure-state and draft V3 verification foundations. Production economic behavior has not been replaced by these drafts.
- 222 Python tests PASS: 199 existing tests plus 23 foundation tests. Existing successor and historical audit tests still exercise the existing V2/historical behavior, not a completed prospective V3 migration.
- Migrated one existing concurrent-input source-inspection test to the local capture helper and asserted no shared fallback. No historical expected rejection was changed.
- GuardedResearchTester and TestCombinedLifecycle compiled using MetaEditor: each 0 errors, 0 warnings. MQL harness assertions were compiled, NOT runtime-executed. Production compilation covers the input-loader change; the harness compiles the new modules separately.
- POST_TOOLING records 237 unchanged baselines, two changed existing files, six new files and no missing baseline files. Candidate, SafetyKernel, OperationalSafety, Stage13, adopted governance, historical audit and stage14.py are byte-identical to this turn's pre-edit captures.

## Remaining implementation and review blockers

| ID | Remaining work | Disposition |
|---|---|---|
| INPUT-1 | Active rendering is stage14.py, outside authorized existing-file list; it bypasses Stage12 renderer. | Exact proposed scope diff retained; additional-file authorization required. |
| INPUT-2 | Independently pinned local staging and renderer expectation, same-buffer manifest interpretation, runtime configuration/profile linkage. | Not complete; local caching alone is not trust closure. |
| LIFE-1 | Wire native capture, effective entry/residual S0 reconciliation, terminality/callback synchronization, full close and residual boundary accounting into guarded production. | Not complete; new modules remain draft foundations. |
| LIFE-2 | Strengthen draft sidecar verifier with exact request/receipt authority, full snapshot/precision/temporal validation, native order completion and complete serialization. | Not complete; draft verifier is not production acceptance authority. |
| LIFE-3 | Enforce proof of callback set completeness before classifying aggregate execution; no-fill and flatness authority must remain distinct from missing callbacks/position absence. | Integration blocker; no native claim. |
| CONT-1 | Wire one-shot FOK containment through authenticated existing send seam and isolate retained containment evidence from accepted aggregates. | Not complete; Python state tests are synthetic model checks. |
| CONT-2 | Preserve exact-position monitoring and safety-equity after invalidity; integrate observation ring drain and invalidation rules. | Not complete. |
| V3-1 | Migrate successor authorization/render/ingestion/normal/boundary validators and applicable fixtures from V2 to adopted V3 without historical fallback. | Existing enforcement untouched; migration outstanding. |
| TEST-1 | Full A01–A25, SP/SS, S01–S22 mapping and production integration tests. | Outstanding; foundation mapping below is deliberately partial. |
| NATIVE-1 | Actual changed-production runtime and SHORT conformance. | Later separately authorized readiness proof; no runtime now. |
| REVIEW-1 | Independent implementation acceptance, future freeze, B2 and own Gate 1 authorizations. | Not granted. |

## Foundation test mapping

| Area | Explicit tests | Evidence limits |
|---|---|---|
| FILE_COMMON / immutable inputs | ImmutableCaptureTests: 7 methods, including same-buffer mutation, missing-local failure, path escape, duplicate JSON and malformed calendar. Existing concurrent-reader check retained. | Python behavior plus MQL source check; no native input runtime. |
| S execution classification / containment | ExecutionContainmentTests: 12 methods, including full multi-deal vs partial, missing terminality, actual residual, no retry, sticky invalidity, unrelated invalidation denial. | Pure Python model; production containment not wired. |
| Profile / LONG-only authority | ProfileTests: 4 methods for exact LONG, SHORT rejection, build/profile mismatch and signed swap mismatch. | Pinned profile comparison; no new native conformance. |
| Static seam / ring / projection guard | TestCombinedLifecycle.mq5: assertions on FOK/direction, missing callback, unprepared commit, 256 entries, overflow and sticky overflow after drain. | Compile only; assertions NOT executed. |
| Existing E01–E18/historical/global-zero coverage | Complete unittest discovery retained. | Existing contract only; does not prove V3 migration. |

## Reproduction

Python: `python -m unittest discover -s tests` from C:/KingEA_v1. The final log records 222 tests and OK. Initial log preserves the original helper-name regression (199 tests, one error); it was corrected by migrating the source inspection to the replacement helper.

Compiler: C:/Program Files/MetaTrader 5/metaeditor64.exe. Source copies are retained under compile/. Commands use `/compile:<absolute copy> /inc:C:/KingEA_v1/MQL5 /log:<absolute log>`. MetaEditor was started with a hidden window. Compiler identity, compile-copy/source equality, log and EX5 hashes are in COMPILE_PROVENANCE.json. Original production EX5 was not overwritten.

The proposed stage14 diff is NOT applied and depends on a new verified-input helper described in SCOPE_EXTENSION.md. The implementation diff is relative to this turn's before-byte captures, not the repository's already dirty HEAD.
