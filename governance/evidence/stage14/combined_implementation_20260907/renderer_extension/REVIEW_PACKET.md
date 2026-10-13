# Renderer trust closure and combined implementation continuation

IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW
SUCCESSOR_FREEZE = NOT_AUTHORIZED
SUCCESSOR_READINESS = NOT_READY
B2 = LOCKED

Combined implementation remains incomplete. This packet records the exact authorized Stage14 renderer patch, its read-only capture implementation, and further ledger foundation repairs. It does not imply V3, A/S production integration, native conformance or independent acceptance.

## Renderer implementation

The Stage14 diff matches PROPOSED_STAGE14_SCOPE_EXTENSION.diff exactly. FINAL_PRE_TOOLING/IMMEDIATE_RECHECK precede edits; no drift was detected. The helper revalidates independently pinned control context and compares the supplied resolved expectation against a fresh resolution. Input references are obtained only from control.render_inputs. Payload paths never select files or establish authority.

The independently retained control must contain render_inputs with exactly: storage_scope=AGENT_LOCAL_RUN_SCOPED, agent_files_root (absolute local agent Files directory), child_sha256 (exact execution child), manifest and calendar (each exact basename and SHA256). Local path is agent_files_root/KingEA/runs/<child_sha256>/<basename>. This method neither creates this directory nor stages files. The independent staging step must already have supplied them. UNC, Common directory, traversal, junction/symlink, input aliases and SET-line injection paths reject. Manifest calendar path must match the independently chosen basename or derived run-scoped path. Prefer basename in the child manifest to avoid a self-referential child-hash path.

Windows read-only handles deny write/delete during capture, hashing and parsing. Each input's bytes are read once by ImmutableInput.capture. Manifest interpretation and calendar validation consume those bytes. Failure releases handles. No unlocked non-Windows fallback exists. Returned SET paths are relative to agent Files and include the exact child run. Returned hashes are of captured raw bytes, not reserialized JSON. The helper performs no writes, authorization, acceptance, root creation or budget transition.

A post-return replacement cannot acquire authority from this operation: the downstream native loader must verify the same emitted hash, while the independent execution control must verify the exact SET/INI/profile before any future launch. This renderer work does not make an arbitrary mutable SET authoritative.

## Deterministic mapping

| Requirement | Explicit tests/evidence |
|---|---|
| 1 Shared-only input cannot render | test_shared_only_cannot_render; test_shared_root_cannot_be_pinned_as_local |
| 2 Payload path cannot become authority | test_payload_path_does_not_choose_input; test_payload_cannot_manufacture_verified_expectation; test_local_co_tampering_cannot_repin |
| 3 Wrong independent hash | test_wrong_independent_hash; changed manifest/calendar byte tests |
| 4 Mutation during hash/parse | test_mutation_between_hash_and_parse_cannot_render; test_calendar_mutation_during_parse_cannot_render; test_parse_cannot_substitute_unhashed_manifest |
| 5 Verified local manifest SET path | test_exact_local_paths_and_file_hashes |
| 6 Exact captured manifest hash; no placeholder | test_exact_local_paths_and_file_hashes |
| 7 Same captured calendar path/hash | test_exact_local_paths_and_file_hashes; test_capture_once_per_input |
| 8 Failure produces no artifact | denied helper compares all directory files before/after each negative; helper has no persistence operation |
| 9 Existing rendering E01–E18 negatives retained | Complete test_successor_evidence suite, 29 tests; valid synthetic fixtures now explicitly stage pinned local inputs |
| 10 Historical audit unchanged | Historical source hashes unchanged; complete existing suite retained without historical fixture/error migration |

17 renderer tests PASS. Full Python discovery: 243 tests PASS. Existing V2 successor validation remains the exercised contract; no claim of completed V3 validation.

## Exact-diff limitation requiring one-line scope approval

The existing post-capture authorize call can discover newly changed control and return the canonical rejection. The next existing line raises Stage14Error and drops stage/detail. ERROR_METADATA_REPRODUCTION.json demonstrates canonical rejection, no bundle, but null stage/detail. This is an open reporting gap, not silent acceptance. PROPOSED_ERROR_METADATA_REPAIR.diff proposes replacing this one raise with SuccessorEvidenceError('rendering', detail). The exact-diff restriction prevents applying it without the requested approval. The reproducer is retained separately; the 243-test PASS does not cover a successful repair of this gap.

## Continued combined foundations

- Native ledger receipt now requires independently authenticated actual executed volume. Callback volume below that target remains pending; conflicting excess rejects. Missing callbacks are not rejection evidence. Explicit no-fill receipt is distinct from absent evidence.
- Unsupported execution cannot reconcile a foreign/mixed stable position identity for containment. Excess execution is a separate conflict.
- Static send seam requires a current context-authority argument; a research invalidity latch cannot bypass context loss.
- Added four executable Python foundation tests for incomplete callback sets, absent executed-volume authority, absent no-fill authority, and receipt/callback conflict.
- Expanded MQL synthetic harness for signed entry/reduction/full-close components, residual safety valuation, fixed original denominator, duplicate delivery, static direction/context guards and one terminal commit. Harness compiled: 0 errors, 0 warnings; NOT runtime-executed. MQL assertions are not reported as executed test passes.

The new modules still are not wired into GuardedResearchTester production lifecycle. Remaining work includes native dispatch/reconciliation, immutable manifest/profile linkage at execution, effective-stop evidence, safety-equity and containment integration, complete V3 sidecar/inventory authority, prospective successor V3 migration, full A/SP/SS/S mapping and independent review. No implicit completion or acceptance is asserted.

## Scope and provenance

POST_TOOLING explicitly records stage14.py in the changed allowlist and verifies its exact reviewed diff. Eight existing checkpoint files changed, one test file added, 237 baseline files unchanged. Protected Candidate, Stage13, SafetyKernel/OperationalSafety, adopted A/S governance, historical audit, original NativeCostMetadataAdapter/NativeCostEvidence remain byte-identical. The production tester source is unchanged since the previous local-input-capture checkpoint. Existing working-tree changes are preserved. Diffs compare this checkpoint's exact before bytes; prior evidence is not rewritten.

No Terminal/MetaTester launch, native test execution, capacity work, research root, Candidate attempt, successor freeze or Gate advancement occurred. Compilation used MetaEditor only with a hidden window, isolated source copy and retained EX5/log/compiler hashes.
