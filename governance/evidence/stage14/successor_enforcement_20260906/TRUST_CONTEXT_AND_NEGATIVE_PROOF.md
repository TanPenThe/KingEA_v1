# Trust-context design and negative proof

Scope: SUCCESSOR_EVIDENCE_ENFORCEMENT_IMPLEMENTATION_AND_NON_RUNTIME_TESTS_ONLY. B2 = LOCKED. No real successor control/receipt store, freeze, root or attempt was registered.

## Implemented interface

`PinnedControlContext(directory, control_sha256)` is injected at coordinator/finalizer construction by the independent control plane. Nothing in the manifest, SET/INI, frame, result or sidecar selects this directory or pin. There is no default production pin and no CLI option added to supply one from research payloads. Existing callers without a context reject. The typed object is not magic authentication: independently provisioning its arguments is the trusted caller's responsibility. A future deployment/control-plane integration must demonstrate that isolation before runtime readiness.

The exact control.json bytes are rehashed against the externally supplied pin on every resolution. Only explicit single-file references within that store are resolved; no search/latest, symlink target, arbitrary path or default schema fallback. The pinned control record recognizes exact independently reviewed specification, review, freeze and execution records. All referenced bytes are verified and their semantic links checked. Owner-approved booleans alone cannot bypass the external control pin.

Design-only validation resolves the independently reviewed specification and cannot authorize execution. Execution-phase checks require both freeze and distinct Gate1 execution receipts, with exact candidate/spec/freeze/root/child linkage. Missing/inactive/unrecognized controls or stale/replaced receipt copies reject. Supplied copies are compared, not treated as authority. General shared dependency/policy hashes remain allowed in their defined roles.

`validate` supplies one canonical failure, with separate `stage` and `detail`. `validate_frame` enforces receipt/binding copies and uses the unchanged native package consumer for economic/linkage checks. It additionally requires whole-position V2 semantics and exact successor financial identity, rejects unknown/residual package fields, and rejects missing collections even for zero boundary count. It does not authenticate housekeeping differently or implement revised A/S economics.

Coordinator gates: authorize, render/verify bundle, append_frame before directory/valid-frame creation, and finalize_frames before COMPLETE. Gate1Finalizer exposes `finalize_successor_frames` for the same guarded evidence-only path. Retired epoch finalize/audit/merge/status APIs default-deny; the old lower-level configuration finalizer also gates before its existing calculations. Historical bodies remain retained in source but unreachable through those denied public methods. No generic historical compatibility facility was added.

## Negative proof and positive controls

`tests/test_successor_evidence.py` has 28 passing tests covering E01–E18 plus boundary/tamper controls. Cross-stage cases check canonical failure and no next_status, executable result, valid-inventory write or finalization output on failure. In-memory/temporary fixtures exercise the actual public Python coordinator/finalizer methods; no terminal is mocked into reporting success because no terminal is invoked.

E13 rewrites specification/declaration and local control hashes while retaining the independent pin: rejected. E14 and E05 substitute execution receipt hashes: rejected at authorization/rendering and frame consumption. E15 removes the execution receipt while retaining freeze: rejected. E16 introduces an unrecognized self-asserted receipt and reseals local control: rejected. E17 attempts payload store selection and design-as-execution: rejected. E18 attempts residual semantics under V2: rejected. E04/E06 cover parent identity and evidence-role reuse; all supply-side manifest changes must still match the independent child receipt.

Positive controls use only temporary synthetic control records: valid authorization and text rendering, ingestion, normal evidence finalization, a fully rebound synthetic V2 boundary package and design-only specification validation. These establish interface behavior, not real authorization, native execution, accounting-policy adoption, source-to-EX5 consumption or production readiness. Temporary synthetic approval-looking records have no authority outside their test fixture and are not operational roots/attempts.

## Regression disposition

Full run: 196 tests; 176 successful; 9 failures + 12 errors across 20 legacy tests (one has two failing subcases). All recorded problems contain the new canonical denial because those fixtures expect unpinned/historical acceptance or a later legacy error. Raw traces/names are retained in TEST_RESULTS.json and PYTHON_REGRESSIONS.log. **Full suite is not green.** The 176 successes include 28 new tests and 148 existing tests.

The old test files were not rewritten, skipped, decorated as expected failures or weakened to suppress this incompatibility. Historical finalizer regression coverage cannot exercise its acceptance path under default-deny. Review must disposition replacement/migration of those tests without introducing the forbidden historical fallback. The existing readiness policy still reports its historical changed-tester/PRE_TOOLING failure. Neither result is waived here.
