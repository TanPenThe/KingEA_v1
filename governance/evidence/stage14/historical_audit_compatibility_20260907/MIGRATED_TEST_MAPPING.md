# Affected-test migration mapping

The 20 cases that previously stopped at blanket successor denial are mapped below. Historical fixtures and detailed failure reasons remain unchanged. The two prospective rendering cases do not receive historical authority because audit-only scope cannot render an executable.

| # | Previous test | Current route | Preserved assertion |
|---:|---|---|---|
| 1 | `test_all_zero_two_epoch_evidence_is_quarantined_without_selection` | `RetiredHistoricalGate1Audit.finalize` | Two archives/configurations verified; zero activity retained as historical quarantine; no selection/Gate 2/budget |
| 2 | `test_one_digit_stage12_stage13_trade_mismatch_is_rejected` | audit finalize | `ACCOUNTING_NET_RETURN_MISMATCH` |
| 3 | `test_failed_build_parity_cannot_join_the_two_epochs` | audit finalize | `BUILD_PARITY_NOT_ACCEPTABLE` |
| 4 | `test_unexplained_extra_archive_quarantines_finalization` | audit finalize | `UNEXPLAINED_EXTRA_ARCHIVE` |
| 5 | `test_child_manifest_file_hash_is_part_of_lineage` | audit finalize | `CHILD_FILE_HASH_MISMATCH` |
| 6 | `test_completed_inventory_rows_must_match_the_prior_epoch` | audit finalize | `COMPLETED_INVENTORY_ROW_CONFLICT` |
| 7 | `test_failed_nested_parity_comparison_cannot_hide_behind_pass_result` | audit finalize | `BUILD_PARITY_COMPARISON_INVALID` |
| 8 | `test_chunk_local_pass_number_may_differ_from_global_configuration_id` | audit finalize | Local/global pass mapping and exact cardinality |
| 9 | `test_streaming_progress_reports_each_verified_archive` | audit finalize | Ordered per-archive progress |
| 10 | `test_repeated_event_root_breaks_the_ledger_chain` | audit finalize | `ACCOUNTING_LEDGER_ROOT_REPEAT` |
| 11 | `test_partial_accounting_event_is_not_a_complete_sequence` | audit finalize | `ACCOUNTING_EVENT_SCHEMA_INVALID` |
| 12 | `test_batches_resume_without_rewriting_and_merge_to_the_same_quarantine` | audit batch/merge | Append-only/idempotent shards and same historical classification |
| 13 | `test_batch_merge_rejects_tampered_or_missing_shards` | audit batch/merge | `AUDIT_SHARD_SET_INCOMPLETE` and `AUDIT_SHARD_HASH_MISMATCH` |
| 14 | `test_batch_status_discovers_only_the_next_unfinished_batch` | audit batch/status | Exact next unfinished batch |
| 15 | `test_merged_shards_match_the_single_stream_audit_outcome` | audit finalize versus audit merge | Same verified counts/classification, zero budget |
| 16 | `test_merge_rejects_rehashed_wrong_epoch_or_mixed_lineage_shard` | audit merge | `AUDIT_SHARD_CONTENT_CONFLICT` |
| 17 | `test_manifest_v2_drives_exact_native_bundle_and_requires_gate_authorization` | renamed `test_manifest_v2_prepares_but_legacy_authorization_cannot_render` | Manifest preparation remains; old owner object cannot authorize or render without pinned successor context |
| 18 | `test_complete_frames_are_append_only_and_finalize_deterministically` | `RetiredHistoricalFrameAudit` | Append-only ordering, replay, cardinality, late-frame rejection |
| 19 | `test_stage14_renders_explicit_dates_and_rejects_a_virtual_gate1_child` | renamed `test_stage14_prepares_explicit_dates_and_rejects_legacy_render_authority` | Exact date realization and virtual-child rejection remain; legacy render authority fails closed |
| 20 | `test_production_coordinator_consumes_same_package_before_finalizing` | `RetiredHistoricalFrameAudit` | Same native package validation and corrupted-package rejection |

Additional controls prove unknown/mismatched scope rejection, successor-candidate audit rejection, the absence of production capabilities, ordinary-method default denial including `batch_status`, and rejection when an audit-result hash is presented as successor evidence.
