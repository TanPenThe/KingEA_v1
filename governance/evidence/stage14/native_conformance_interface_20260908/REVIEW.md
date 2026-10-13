# Non-Candidate native conformance interface — implementation review

IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW
NATIVE_PRODUCTION_PATH_CONFORMANCE = NOT_YET_EXECUTED
SUCCESSOR_FREEZE = NOT_AUTHORIZED
B2 = LOCKED

The interface is implemented within the three authorized existing production files and one new conformance-control module. No additional existing production file was changed. No MT5/MetaTester runtime occurred.

Deliverables

- FINAL_PRE_TOOLING.json and before/: exact pre-edit bytes for all 252 checkpoint artifacts, owner directive hash and new-module declaration.
- IMPLEMENTATION.diff: exact unified diffs against those retained bytes, including all new source/test files.
- POST_TOOLING.json: six changed/new files, complete current hashes and equality for all 249 baseline artifacts outside the three authorized production edits. This includes unchanged successor_evidence.py, Stage14, historical audit, Candidate, Stage13, Decision A modules and protected safety sources.
- TEST_RESULTS.json and PYTHON_SEALED.log: 339 Python tests PASS. E01–E18, historical audit, archive integrity, global-zero/quarantine and prior renderer tests remain green. New tests include 19 conformance-control cases and five static production control-flow/equality proofs.
- COMPILE_PROVENANCE.json and compile_release/: all three MQL compile controls PASS with zero errors/warnings. Compiler 5.0.0.6140, exact command/source-copy/log/EX5 hashes and original EX5 state retained. Production EX5 files were not overwritten. The release directory was newly created, with no pre-existing EX5. Intermediate compile/test logs remain retained.
- ARTIFACT_HASHES.json: exact hashes of the review artifacts.

Authority and interfaces

research_pipeline/native_conformance_control.py defines NON_CANDIDATE_NATIVE_CONFORMANCE_V1 and evidence_scope NON_CANDIDATE_NATIVE_CONFORMANCE. ConformanceControl(directory, explicit_control_path, independently_pinned_hash) reads exact control/fixture/profile/artifact bytes. No latest lookup, payload-selected control store, source of successor receipts, historical fallback, launcher, root creation, ranking or budget transition exists.

The control has exact fields domain, fixture, profile, artifacts and local_inputs. Each file reference is an exact relative path plus SHA-256. The fixed fixture has fixture_id, run_id, group_id, side, volume, S0, start_msc, end_msc, entry_msc, reduction_msc, close_msc, outcome, data_scope, execution_mode, optimization and symbol. Actions use whole-second timestamps, DEVELOPMENT_ONLY, ExecutionMode 20 and no optimization. Entry/reduction/close windows are fixed before execution; no date or action adaptation is implemented. Boundary uses close_msc=0. A missing eligible quote or unsupported early outcome does not create a retry or a replacement fixture.

prepare_inputs() returns the captured calendar, immutable manifest bytes, exact UTF-8 SET bytes/values and mandatory INI settings without writing files. Agent-local target paths are independently pinned under KingEA/conformance/<fixture_id>/. It creates no run eligibility or execution permission. A future authorized operator must stage exactly these bytes and independently bind the actual complete SET/INI, source, EX5 and environment before launch. Direct self-asserted EA inputs do not constitute independent conformance evidence.

After a separately authorized native run, with_launch_record(explicit_pinned_reference) validates an independently retained launch record and returns a bound context. The record pins consumed SET/INI/manifest/calendar bytes, source/EX5/profile, build, account fingerprint and isolation/exit facts. Exact SET bytes must match prepare_inputs(); INI must satisfy the governed non-optimized local 20 ms profile. This is an explicit custodian-supplied record, not a claim synthesized from the archive. No actual record was issued in this phase; test records are synthetic.

bound.build(explicit_pinned_capture_reference) invokes the shared production V3 builder. bound.verify(files, explicit_pinned_seal_reference, explicit_pinned_capture_reference, launch_record_reference=...) verifies the complete archive and reproduces its exact bytes. It returns CONFORMANCE_EVIDENCE_FOR_INDEPENDENT_REVIEW with successor_eligible=false. It cannot return Candidate acceptance or native review acceptance.

Conformance sidecars retain Stage13 schema v1 and V3 financial structure but carry a distinct binding. The schema's candidate_id slot contains the NON_CANDIDATE_NATIVE_CONFORMANCE_V1 domain marker, not a Candidate identity. Conformance bindings exclude root_hash, freeze_receipt_hash and execution_receipt_hash; they include evidence_scope, fixture_id, conformance_control_hash, fixture_specification_hash and launch_record_hash. No substitute/fake successor receipt is created.

The existing R -> S -> A -> independent seal construction is reused. R includes the independently pinned control, fixture, launch record and exact consumed SET/INI/manifest/calendar bytes, plus existing native/financial supporting evidence. S binds H(R). A covers complete R/S/support bytes, and the externally selected final seal pins A. The launch record is upstream evidence, so this construction has no SET/control/seal hashing cycle. Rebuilding from the pinned native capture must yield byte-identical artifacts. All these operations are read/validation or byte construction only.

Production dispatch and SHORT

GuardedResearchTester has an explicit InpNativeConformance branch. OnTick dispatches to ResearchConformanceTick and returns before Candidate closed-bar evaluation. OnInit skips Candidate configuration decoding for that branch, and OnTester returns from a conformance-only completion path before Candidate result generation. The static transitive call graph confirms the fixture dispatcher cannot reach KingEAEvaluateSleeveEthSt001 or ResearchEvaluateClosedBar.

The fixture uses existing ResearchOrderSend, ResearchNativePoll, ResearchReduceHalf, ResearchClose, static-stop guard, component lifecycle, safety-equity projection, Stage13 projection and native capture. Original risk is obtained from native OrderCalcProfit for the fixed volume/S0 and entry quote; the original denominator is retained thereafter. There is no duplicated financial implementation. Action allowance flags are consumed before submission. Actual no-fill safety fallback uses the existing fallback condition; OrderCheck instrumentation cannot create a fallback.

The shared DecisionA lifecycle/adapter/static-stop sources already supported both directions and remain byte-identical. The approved integration and shared Python builder now parameterize native entry/exit types and position side under explicit conformance context. LONG is BUY with Bid-side exit marking; SHORT is SELL with Ask-side marking in the unchanged DAReadPosition native adapter. S0 must be below the LONG entry or above the SHORT entry. The same residual S0/basis, component, swap-transition and one-time financial validation applies.

The bootstrap profile explicitly has no accepted_proof_sha256. Its NATIVE_SWAP_PROFILE is an UNACCEPTED_NATIVE_SWAP_BOOTSTRAP record bound to the exact fixture and side. It cannot use retained LONG proof as SHORT authority. Default prospective validation still requires its original accepted LONG proof and rejects SHORT. successor_evidence.py is byte-identical, including freeze/Gate1 requirements and all prospective stages. Conformance archives fail actual successor ingestion canonically before any output/acceptance write. Historical audit remains separate and unchanged.

OrderCheck policy and provenance

The guarded native send performs OrderCheck immediately before OrderSend. The narrowly defined policy is bool_return=true AND check retcode=0. All other check outcomes stop before OrderSend. MetaQuotes' official example distinguishes successful check retcode 0 from subsequent send retcode 10009; it also explains that a successful check does not guarantee execution: [OrderCheck documentation](https://www.mql5.com/en/docs/trading/ordercheck). Unexpected native check behavior must be reported, not adapted into acceptance.

Evidence retains the complete MqlTradeRequest fields, exact serialized request hash, bool return, retcode, native error, comment, balance/equity/profit/margin/free-margin/margin-level, timestamp and run/group/context. Request volume, direction, stop and filling are linked to the later result/deal. Rejected checks latch invalidity and create no send, fill, completion, retry or new fallback. ORDER_SEND_NOT_ATTEMPTED distinguishes an unsent request from an actual native result; an uninitialized result is never presented as native OrderSend evidence. Accepted OrderCheck only permits the existing guarded send; native result/order/callback reconciliation remains mandatory.

Static control-flow tests prove the check-rejection branch dominates the sole OrderSend call and that the check function cannot book or mark a fill. These are static proofs, not claims of native execution. Python tests reject missing, foreign, malformed, failed and inconsistent checks and show that successful checks without deals cannot form a package.

Required negative-test mapping

| Directive item | Evidence |
|---|---|
| 1. Freeze/Gate1 still mandatory | Existing E14/E15/E16 and full prospective regression suite; unchanged successor source |
| 2. Conformance identity not successor | Actual successor-ingestion substitution test; default validate_package rejection |
| 3. Successor receipt cannot select fixture | test_successor_receipt_cannot_select_fixture; strict domain/control fields |
| 4. Candidate evaluation unreachable | Static transitive call-graph and early-return tests |
| 5. Exact development interval | test_action_schedule_and_interval_enforced; native dispatcher end guard |
| 6. Side/volume/S0/schedule cannot change | Pinned-control co-tamper, immutable context, fixture payload and schedule tests |
| 7. LONG cannot claim SHORT | test_long_cannot_claim_short; bootstrap side binding |
| 8. SHORT without prior acceptance | test_long_and_short_bootstrap; no accepted proof field |
| 9. SHORT conformance-only label | Positive SHORT archive/verification result assertions |
| 10. No successor archive acceptance | Actual append_frame rejection, canonical stage/detail, unchanged files, no spool |
| 11. Check rejection sends zero orders | Static rejection-dominance proof plus failed-check reconstruction tests |
| 12. Check success is not a fill | test_accepted_check_does_not_prove_fill |
| 13. No retries from rejection | Static consumed-before-submit flags/no loop; unchanged adopted callback tests |
| 14. Malformed/foreign check rejection | Missing/rejected and malformed-request/context tests |
| 15. R/S/A/seal tampering | Every archive member mutation rejects under independent seal; existing full V3 tamper suite |
| 16. Historical audit unchanged | Full historical regression suite and exact source equality |
| 17. Stage13 unchanged | POST_TOOLING protected hashes and equality test |
| 18. Candidate/safety unchanged | POST_TOOLING protected hashes and equality test |

Exact Python test names and lines are enumerated in TEST_RESULTS.json. Static tests and synthetic injected records do not stand in for native callback, broker, isolation or stop/swap proof.

Remaining prerequisites and limits

- Independent review of this interface implementation remains required; no self-issued implementation acceptance.
- No development interval, account, actual launch SET/INI or native fixture has been approved/executed by this packet. The non-runtime tests use synthetic temporary controls and native observations.
- Native LONG, SHORT, boundary, OrderCheck/terminality, residual-stop/swap and actual operational safety conformance remain NOT_YET_EXECUTED. SHORT bootstrap permission is evidence collection only, not semantic acceptance.
- A fixture that misses its prescribed action window, experiences an unsupported/unscheduled outcome, loses context or cannot reconstruct must report that conformance limitation. No adaptive dates, retries or strategy interpretation is provided.
- Native profile remains the exact existing build/server/symbol specification; changed facts require review. No broker/environment shopping is implemented.
- Before any future separately authorized native launch, create PRE_NATIVE_PRODUCTION_CONFORMANCE with current source/EX5/inputs/environment, report/recheck governed storage requirements and preserve independent launch/capture/seal custody.
- No Terminal/MetaTester process was launched, no capacity work occurred, and process inspection found none active. Only MetaEditor compilation and deterministic Python verification were performed.
- Candidate/successor execution, freeze/root/budget, Gate1, selection/ranking, OOS/holdout and readiness remain unauthorized. B2 stays locked.

The returned launch_record_hash is the exact retained-byte SHA-256, not a reserialization hash; test_launch_receipt_hash_uses_exact_bytes covers noncanonical retained formatting.
