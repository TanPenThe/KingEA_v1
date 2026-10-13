# Default-denial and historical reachability proof

## Prospective path

`ResearchRunCoordinator.authorize`, `render_bundle`, `append_frame`, and `finalize_frames` still call the independently pinned successor validator before any acceptance transition, executable rendering, inventory write, or finalization write. Normal and boundary finalization use distinct stage labels. `Gate1Finalizer.finalize_successor_frames` delegates to that same prospective path.

Ordinary calls to legacy-named `Gate1Finalizer.finalize`, `audit_batch`, `merge_batches`, and `batch_status` have no audit capability token and reject immediately with `SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED`. Test `test_E11_historical_default_deny` covers all four. E01–E18 plus positive controls remain green: 29 tests PASS in `SUCCESSOR_CONTRACT_REGRESSION.log`.

No prospective failure calls either audit adapter. A payload field cannot select historical mode. A successor candidate is rejected by the audit binding, and an audit result reports `successor_evidence_satisfied=false`; presenting its hash as successor evidence fails the prospective contract.

## Historical path

An explicit audit adapter validates the known scope before reading evidence and binds the exact supplied record identity before running detailed checks. The retained Gate 1 code again executes parity, child-index, completed-inventory, archive/hash, frame/cardinality, Stage12/Stage13, accounting-event, shard, and merge consistency checks.

Reachability is demonstrated by the restored specific-error tests in `HISTORICAL_AUDIT_TESTS.log`. In particular, a tampered or extra archive reaches `UNEXPLAINED_EXTRA_ARCHIVE`; altered archive-derived accounting reaches `ACCOUNTING_NET_RETURN_MISMATCH`; ledger and frame corruption reach their original detailed classifications; tampered/rehashed shards reach hash/content conflict classifications. The 23-test focused proof passes.

Audit finalization writes no production finalization packet, selection, diagnostic research root, or Gate 2 root. It consumes zero candidate budget. Only audit work papers may be written to the caller-supplied audit workspace.
