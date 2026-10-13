# Candidate 001 operational closure and FOK infrastructure review checkpoint

Date: 2026-09-06. Scope: implementation and non-Candidate conformance only.

## Decision and preserved status

The append-only `OWNER_CLOSURE_AND_SCOPE.json` records Candidate 001's Demo2 path as `CLOSED_ENVIRONMENT_INCOMPATIBLE`, binding the confirmed IOC rejection. Scientific status remains `QUARANTINED_PENDING_DIAGNOSTIC`. ORIGINAL_GATE1 remains `RETIRED_UNRESOLVED_PROVENANCE`; its original attempt remains consumed with no refund. No historical cause, scientific rejection, or invalidation is inferred from current IOC incompatibility.

**B2 = LOCKED. Successor = NOT_FROZEN. No new research root or attempt was created.**

## Readiness matrix

| Requirement | Result | Evidence / limitation |
|---|---|---|
| Append-only operational closure | PASS | OWNER_CLOSURE_AND_SCOPE.json |
| Bounded FOK acceptance/full fill | PASS | NC-FOK-09-FINAL; explicit FOK, ExecutionMode 20, one simulated entry, no fallback |
| Shared metadata/ledger/snapshot/projection implementation | PASS for bounded conformance | 95 MQL checks, actual current-run metadata and protective-stop confirmation |
| Callback/no-callback custom-result equivalence | PASS for synthetic handler conformance | Two sealed pairs, long and short; injected callbacks explicitly synthetic |
| Actual runtime housekeeping variant | NO-CALLBACK verified | Build 6140 reported zero exit callbacks; no claim of native callback-exposed proof |
| Production archive consumer / sealed-only verifier | PASS for retained fixtures | Same package validator used by coordinator and streaming finalizer; 47 sealed artifacts |
| Python regressions | PASS | 168 tests, including 9 native-cost archive tests |
| PowerShell regression sweep | 18 PASS / 1 FAIL | Historical Stage14 readiness policy correctly rejects changed tester against old PRE_TOOLING approval; not waived or rewritten |
| Current compilation | PASS | Non-Candidate EA and compile-only production tester: zero errors, zero warnings |
| Source provenance | PASS | 16/16 current PRE_TOOLING/post-tooling hashes equal |
| Candidate and Stage13 schema-v1 hashes | PASS | Original Candidate and AccountingEvents bytes unchanged; canonical/hash regressions passed |
| Capacity / research-scale growth | NOT_READY | C: below 30 GiB; bounded format sample is not a full-pass upper bound |
| B2 / successor authorization | LOCKED / NOT_FROZEN | Independent acceptance remains required; this packet does not authorize research |

## Actual non-Candidate execution proof

Authoritative bounded proof: `NC-FOK-09-FINAL`.

- Terminal and compiler executable metadata: version 5.0.0.6140, retained executable hashes and exact commands.
- Registered JustMarkets-Demo2 identity is fingerprinted, not asserted from an arbitrary account label.
- ETHUSD.s: execution-mode property 2; filling flags 1; order flags 127. Exact retained request uses `ORDER_FILLING_FOK`; tester INI uses `ExecutionMode=20`, Model 4, local agents only, fixed inputs.
- OrderCheck succeeded with retcode 0; simulated execution returned 10009 / Request executed, full requested 0.01 volume. Broker-side protective stop was submitted with the request and independently confirmed on the resulting position.
- Actual deal metadata, zero-valued commission/fee read success, stable position linkage, eligible quote/cost snapshot, one evaluator financial projection, journals and result are retained. No Candidate signal logic or performance comparison ran.
- Fresh EX5 build provenance and source/SET/INI/manifest/authorization/launch/runtime bindings are retained. MetaEditor's observed return code is 1; success is supported by its native zero-error/zero-warning log and a freshly produced EX5, not by pretending the return code was zero.

`SEALED_09/SEALED_VERIFICATION.json` reports sealed-only PASS, 47 artifacts and two synthetic callback-equivalence pairs. Archive SHA-256:

`5616D90EA4F134E3A408CAA792F845DB7ED862CEA20A63CCFC346639A8B75646`

The verifier reads the archive contents, not mutable original sources. Negative tests cover missing/altered sidecar and ledger facts, wrong scope/root/event/sequence/hash, duplicate/missing packages, ambiguous housekeeping, and removal of required callback artifacts even after a test reseals the inventory. Global-zero/broken funnel fixtures quarantine before selection.

## Implementation and review sources

Shared lifecycle handling and package production live in `MQL5/Include/KingEA/NativeCostIntegration.mqh`. Both the non-Candidate harness and `GuardedNativeCostIntegration.mqh` call it. `NativeCostEvidence.mqh` remains the financial-finalization implementation; the evidence ledger itself makes no financial projection. `NativeCostMetadataAdapter.mqh` retains the single-ticket current-run HistoryDealSelect scope.

`research_pipeline/native_cost_archive.py` validates cost roots, pre-end snapshots, boundary sidecars, exact Stage13 event linkage and housekeeping classification. `gate1_finalization.py` and `stage14.py` call this consumer before finalization. `fok_verification.py` performs sealed-only verification and bounded capacity sampling. Tests are in `NativeCostContractTests.mqh`, `NativeCostIntegrationTests.mqh`, `FOKInfrastructureConformance.mq5`, and `tests/test_native_cost_archive.py`.

The new package version is `NATIVE_COST_BOUNDARY_PACKAGE_V2`; this does **not** change Stage13 schema-v1 serialization. Candidate 001's production filling contract remains IOC; FOK exists only in the separately scoped non-Candidate harness. The September 4 implementation baseline remains invalid for the changed tester.

## Deliberately unresolved limitations

1. Capacity sample: W = 29,464,370 bytes; A = 4,372,032 bytes; largest sample child archive = 4,372,032 bytes. The prescribed formula yields 23,081,487,248 bytes. Observed C: free space was 24,134,529,024 bytes (about 22.48 GiB): formula PASS, mandatory 30 GiB floor FAIL.
2. This 1,000-configuration sample measures the final format, fixed runtime/build overhead and synthetic telemetry, not a proven maximum for a full research child. Per-eligible-tick cost snapshots grow with exposure duration. Production storage headroom therefore remains unproven independently of the free-space failure. No evidence was deleted or silently moved to resolve it.
3. The shared handler accepts positively authenticated housekeeping facts in the synthetic test. The production wrapper does not manufacture such proof from an ambiguous native OUT callback; it fails closed. Real callback-exposed native authentication is not claimed. Normal-close precedence is deterministic conformance evidence, not a separate real native normal-exit run in this packet.
4. Independent reviewer acceptance remains outstanding. No successor freeze should be inferred from bounded FOK success.

## Preserved unsuccessful development evidence

NC-FOK-01 failed compilation with warnings before launch. NC-FOK-05/06/07 failed initialization conformance before orders: the newly added housekeeping string was not explicitly initialized. The final implementation initializes it; NC-FOK-08 passed 93 checks and NC-FOK-09 passed 95. These failed/pilot runs remain append-only. The initial PowerShell compile pilot lacked a trustworthy compiler exit/timing receipt; it is superseded by the retained Python subprocess compile-only proofs, most recently NC-FOK-PRODUCTION-COMPILE-03. No pilot is silently promoted to final proof.

## Final controls

FINAL_CONTROLS_20260906.json confirms MT5 and MetaTester stopped, valid persistent standdown, disabled watchdog and zero KingEA scheduled tasks. No Candidate execution, OOS/holdout, ranking, IOC/FOK performance comparison, family-budget reset/refund, new attempt, research root or successor freeze occurred in this work.

Next decision is independent review of this packet and explicit resolution of storage/growth and any remaining integration limitations—not B2 execution.
