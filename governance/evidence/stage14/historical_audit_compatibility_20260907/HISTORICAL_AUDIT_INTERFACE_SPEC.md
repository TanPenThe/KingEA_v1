# RETIRED_HISTORICAL_AUDIT_ONLY interface

## Authority

The sole authority is `READ_ONLY_INTEGRITY_VERIFICATION`. The operation must be selected explicitly by its caller; a failed prospective operation cannot enter it. The caller supplies `HistoricalAuditScope(scope_id, schema_version, record_identity)`. The implementation rejects an unknown scope, wrong schema or target, wildcard/latest-like record identity, record mismatch, and a successor candidate presented to a historical scope.

The reviewed scope registry contains only:

- `CANDIDATE_001_GATE1_RETIRED`, schema 1, Gate 1 archive/lineage audit;
- `RETIRED_GATE1_TEST_FIXTURE`, schema 1, bounded Gate 1 integrity fixtures;
- `RETIRED_STAGE14_FRAME_V2_TEST_FIXTURE`, schema 2, retained frame-integrity fixtures;
- `RETIRED_NATIVE_COST_FRAME_V2`, schema 2, retained native-cost package/frame audit.

Gate 1 record identity is the canonical SHA-256 of the exact prior and continuation root objects plus both exact child-index file hashes. Frame audit record identity is the exact retained `manifest_sha256` or retained run identity supplied independently to the audit operation. The payload cannot request audit mode, select the scope, or select a `latest` record.

## Interfaces

`RetiredHistoricalGate1Audit` exposes only `finalize`, `audit_batch`, `merge_batches`, and `batch_status`. These methods execute the retained parity, root/run, index, completed-inventory, archive membership/hash, frame/cardinality, Stage12/Stage13, ledger sequence, merge, and shard-consistency checks. Batch shards and audit results are non-authoritative audit work papers in the caller's audit workspace; retained source evidence is never changed.

`RetiredHistoricalFrameAudit` exposes only `append_frame` and `finalize_frames` for retained frame sequencing/cardinality and native package integrity. Its output is `HISTORICAL_AUDIT_RESULT.json`, classified `RETIRED_HISTORICAL_AUDIT_PASS`, and cannot be consumed as successor evidence.

Detailed retained-evidence failures keep their original classifications, including `BUILD_PARITY_NOT_ACCEPTABLE`, `BUILD_PARITY_COMPARISON_INVALID`, `CHILD_FILE_HASH_MISMATCH`, `COMPLETED_INVENTORY_ROW_CONFLICT`, `UNEXPLAINED_EXTRA_ARCHIVE`, `ACCOUNTING_NET_RETURN_MISMATCH`, `ACCOUNTING_LEDGER_ROOT_REPEAT`, `ACCOUNTING_EVENT_SCHEMA_INVALID`, `AUDIT_SHARD_HASH_MISMATCH`, `AUDIT_SHARD_CONTENT_CONFLICT`, and native-cost/frame integrity errors.

## Prohibited effects

The capability statement sets authorization, RUNNING eligibility, executable rendering, research-root creation, candidate creation/freeze, selection/ranking, Gate 2 preparation, budget consumption, successor-evidence satisfaction, and production fallback to `false`. Audit summaries explicitly report zero budget consumption and false values for selection, research-root creation, Gate 2 preparation, and successor-evidence satisfaction. The adapters expose no authorization, rendering, root/materialization, selection, or freeze methods.

Prospective `ResearchRunCoordinator` authorization, rendering, ingestion, normal finalization, and boundary finalization continue to require independently pinned successor control context. Ordinary calls to `Gate1Finalizer.finalize`, `audit_batch`, `merge_batches`, and `batch_status` remain default-denied. Their rejection is `SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED`; there is no historical fallback.
