# Deterministic mapping and limits

Python results: 315 PASS. All observations and control stores in these tests are synthetic temporary fixtures. MQL assertions were compiled only. A source inspection is not a runtime test. IDs refer to retained design matrices; owner adoptions supersede earlier incompatible expectations, without rewriting those records.

Aliases: NI = tests/test_native_integration.py; SW = tests/test_swap_transition.py; VA = tests/test_v3_archive.py; CF = tests/test_combined_foundations.py; E01–E18 = tests/test_successor_evidence.py; MQL Combined/Swap = MQL5/Scripts/KingEA/TestCombinedLifecycle.mq5 and TestSwapTransition.mq5. Exact Python test names and lines are enumerated in TEST_RESULTS.json. Prefix every named Python method with test_.

| Design ID | Concrete evidence and limitation |
|---|---|
| A01 | NI: native_capture_reproduces_archive_exactly; independent_control_build_and_frame_preparation |
| A02 | NI: manual_desktop_mobile_web_not_selectable (invalid capture retained; no accepted projection) |
| A03 | NI: manual_desktop_mobile_web_not_selectable |
| A04 | NI: authenticated_passive_stop_and_gap |
| A05 | NI: stop_cause_without_strategy_intent_rejects; unsupported_entry_and_exit_scalars |
| A06 | SW: T02, T11, T12; MQL Combined: fixed denominator signed oracle |
| A07 | SW: T08; VA: missing_or_failed_zero_property_reads |
| A08 | NI: each_failed_deal_scalar_read_rejects; failed_position_snapshot_read_rejects |
| A09 | NI: duplicate_callback_is_idempotent; MQL Combined: duplicate entry idempotent |
| A10 | NI: conflicting_duplicate_rejects |
| A11 | NI: external_cash_isolation; trading_fact_cannot_be_relabelled_external_cash |
| A12 | NI: foreign_position_rejects; unsupported_entry_and_exit_scalars |
| A13 | MQL Combined: uncommitted residual boundary oracle -> full close components; date-gate ordering regression. Native callback timing NOT EXECUTED |
| A14 | MQL Combined: second projection invalidates; VA: financial_projection_twice. Late sealed-conflict native timing NOT EXECUTED |
| A15 | NI: missing_callback_not_no_fill; prepared_without_committed_is_not_a_financial_receipt |
| A16 | NI: manual_desktop_mobile_web_not_selectable; unsupported_entry_and_exit_scalars |
| A17 | NI: second_financial_projection_rejects; VA: financial_projection_twice |
| A18 | NI: unsupported_entry_and_exit_scalars |
| A19 | NI: partial_execution_rejects; multideal_full_volume_rejects; unsupported_entry_and_exit_scalars (adopted S permits one governed reduction) |
| A20 | NI: stop_cause_without_strategy_intent_rejects; missing_order_terminality_rejects |
| A21 | NI: unsupported_entry_and_exit_scalars; unsupported_financial_event_rejects |
| A22 | MQL Combined: realized plus residual safety equity; non-booking operational components; SW: T13 |
| A23 | MQL Combined: one terminal projection prepared; single terminal commit; NI: native_capture_reproduces_archive_exactly |
| A24 | NI: external_cash_isolation; ResearchEquity independent min(account, component equity) source inspection. Native account-channel reaction NOT EXECUTED |
| A25 | NI: failed_position_snapshot_read_rejects; each_failed_deal_scalar_read_rejects; native getter behavior NOT EXECUTED |
| S01 | VA: full_and_reduced_normal_and_boundary_positive; SW: T02 |
| S02 | CF: long_proof_cannot_authorize_short. SHORT native conformance remains BLOCKED, not a successful short reduction claim |
| S03 | MQL Combined: governed reduction prepare; reduction residual reconciliation |
| S04 | NI: partial_execution_rejects; multideal_full_volume_rejects; MQL Swap: full multi-deal differs from partial |
| S05 | Existing tester minimum/step fallback source preserved; native infeasible-volume behavior NOT EXECUTED |
| S06 | NI: entry_and_residual_state_binding; VA: residual_volume_and_stop_reject |
| S07 | VA: full_and_reduced_normal_and_boundary_positive; MQL Combined: reduction residual reconciliation |
| S08 | NI: entry_and_residual_state_binding; observed_stop_mutation_cannot_be_cleared_by_final_equality |
| S09 | SW: T02, T08, T10 (amendment replaces interval non-accrual claim with B/D/A conservation) |
| S10 | SW: T03, T10; MQL Swap: exact conservation failure |
| S11 | MQL Combined: realized plus residual safety equity; SW: T02 |
| S12 | Existing severe-spread rule source unchanged; full-close residual path NI positive and MQL Swap residual close intent; actual tick-trigger sequence NOT EXECUTED |
| S13 | SW: T13; VA: full_and_reduced_normal_and_boundary_positive |
| S14 | SW: T11, T12; NI: native_capture_reproduces_archive_exactly |
| S15 | VA: original_denominators_cannot_change |
| S16 | MQL Combined: non-booking operational components; single terminal commit; NI: prepared_without_committed_is_not_a_financial_receipt |
| S17 | NI: duplicate_callback_is_idempotent; conflicting_duplicate_rejects; second_financial_projection_rejects |
| S18 | VA: missing_sidecar_fields_and_v2_relabel; E18 |
| S19 | CF: no_fill; MQL Swap: S19 explicit no-fill preserves original position and components |
| S20 | CF: no_callbacks_are_not_rejection_evidence; incomplete_callback_set_waits_for_confirmed_volume; NI: missing_callback_not_no_fill |
| S21 | SW: T01, T03, T16, T17; amendment permits later U replacement, not unsupported corrections |
| S22 | NI: prepared_without_committed_is_not_a_financial_receipt; VA: R_S_A_and_support_tamper; no runtime crash injection |
| SP01 | NI: authenticated_passive_stop_and_gap; CF: exact_long_profile |
| SP02 | NI: stop_cause_without_strategy_intent_rejects |
| SP03 | NI: stop_exit_state_mismatch_rejects |
| SP04 | NI: observed_stop_mutation_cannot_be_cleared_by_final_equality; manual_desktop_mobile_web_not_selectable |
| SP05 | NI: entry_and_residual_state_binding; foreign_position_rejects |
| SP06 | SW: T14; VA: foreign_group; immutable S0 no authorized transition |
| SP07 | NI: authenticated_passive_stop_and_gap |
| SP08 | NI: stop_cause_without_strategy_intent_rejects |
| SP09 | NI: observed_stop_mutation_cannot_be_cleared_by_final_equality |
| SP10 | Controlled-context adoption supersedes complete actor-log prerequisite. CF: profile_mismatch; E07/E13; native isolation NOT EXECUTED |
| SP11 | NI: observed_stop_mutation_cannot_be_cleared_by_final_equality |
| SP12 | NI: each_failed_deal_scalar_read_rejects; stop_exit_state_mismatch_rejects |
| SP13 | E07/E13; VA: foreign_group; NI: altered_independent_artifact_rejects |
| SP14 | VA: residual_volume_and_stop_reject; SW: T10; NI: stop_exit_state_mismatch_rejects |
| SP15 | NI: missing_callback_not_no_fill; missing_order_terminality_rejects |
| SP16 | CF: profile_mismatch; E13; observation completeness is explicitly not authority |
| SS01 | NI: authenticated_passive_stop_and_gap; CF: exact_long_profile |
| SS02 | NI: altered_independent_artifact_rejects; E07/E13. Source no alternate send/SLTP inspected; injected sink execution NOT EXECUTED |
| SS03 | CF: profile_mismatch; E07; NI: altered_independent_artifact_rejects |
| SS04 | CF: profile_mismatch; renderer trust tests. Controlled native isolation NOT EXECUTED |
| SS05 | NI: entry_and_residual_state_binding; failed_position_snapshot_read_rejects |
| SS06 | NI: stop_exit_state_mismatch_rejects |
| SS07 | NI: authenticated_passive_stop_and_gap |
| SS08 | NI: observed_stop_mutation_cannot_be_cleared_by_final_equality |
| SS09 | NI: observed_stop_mutation_cannot_be_cleared_by_final_equality |
| SS10 | CF: incomplete_callback_set_waits_for_confirmed_volume; NI: missing_order_terminality_rejects; native POSITION order NOT EXECUTED |
| SS11 | MQL Combined / Swap: overflow sticky; drain does not clear overflow (COMPILE ONLY) |
| SS12 | Design exclusion: observations never completeness authority; E13 prevents self-asserted context. Upstream loss native injection NOT EXECUTED |
| SS13 | NI: missing_callback_not_no_fill; independent_completion_required_and_valid; finalization source drains rings |
| SS14 | NI: entry_and_residual_state_binding; stop_exit_state_mismatch_rejects |
| SS15 | Later native isolation exercise NOT AUTHORIZED / NOT EXECUTED |
| SS16 | NI: observed_stop_mutation_cannot_be_cleared_by_final_equality; POSITION invalidation production source, NOT runtime executed |
| SS17 | E01/E03/E07; CF: profile_mismatch |
| SS18 | CF: profile_mismatch; tester-only context guard, no demo/live authority |
| SS19 | VA: full_and_reduced_normal_and_boundary_positive; native residual SL conformance remains later readiness requirement |

The 18 FILE_COMMON/rendering cases in tests/test_renderer_input_trust.py cover shared-only rejection, payload path selection, wrong pins, co-tampering, exact same-capture paths/hashes, mutation/hash/parse races, run scope and post-capture metadata. CF adds immutable-buffer parsing and missing-local rejection. E01–E18 retain their exact identifiers and all prospective stages.

Containment: CF full_single/full_multi_is_not_partial/partial/missing_terminality/no_fill/incomplete_callback_set/no_execution_volume_authority/no_callbacks/receipt_callback_conflict; actual_residual_not_requested_volume; no_retry_after_rejection/success; no_speculative_containment; unrelated_invalidation_not_containment_authority; sticky_invalidity_after_later_supported_observation. MQL Swap adds actual residual 1.5, full-multi distinction, single allowance consumed before submission, containment flat observation without research acceptance, and failed-conservation no invented flatten. NI + SW T18 + VA containment_substitution prove evidence isolation.

Historical audit, global-zero/quarantine, archive integrity, date gates and original Stage12/14 regressions run unchanged except the documented prospective stop fixture and normal-pre-end ordering assertion. TEST_RESULTS.json enumerates every executed case; no expected failure or blanket historical denial replaces corruption checks.

Negative side effects: prospective contract helpers assert canonical rejection and unchanged temporary state; renderer negatives assert no SET/INI/bundle; native builder negatives compare the complete temporary file map before/after. Missing completion cannot emit a result frame. No test obtains real successor/root/Gate2 authority. MQL guards for no Candidate financial completion remain compile/source evidence, not runtime proof.
