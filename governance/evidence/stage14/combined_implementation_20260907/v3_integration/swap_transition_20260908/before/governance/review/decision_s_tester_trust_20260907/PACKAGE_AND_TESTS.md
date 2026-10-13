# Proposed S package and test oracle

Contract NATIVE_GROUP_LIFECYCLE_CONTRACT_V3; package NATIVE_GROUP_LIFECYCLE_PACKAGE_V3; semantic PARTIAL_POSITION_COMPONENTS_V1. Proposed only. No revised residual lifecycle may be declared WHOLE_POSITION_V2; V2 consumers reject V3 and V3 consumers reject absent/wrong declarations. Stage13 schema v1 remains unchanged.

## Exact required sidecar field schema

Top-level fields (all required, unknown fields reject): contract_id, package_id, semantic_id, binding, precision, original, entry, exit_portions, residual_snapshots, swap_reconciliations, safety_handoff, terminal, integrity.

- binding: run_id, root_hash, candidate_id, configuration_hash, branch, partition, group_id, symbol, source_manifest_hash, executable_hash, specification_hash, decision_a_hash, decision_s_hash, freeze_receipt_hash, execution_receipt_hash, tester_profile_hash. Independently pinned expected bindings; payload copies are not authority.
- precision: volume_step, volume_digits, price_convention_hash, currency, currency_precision, arithmetic_contract_hash. All positive/grid/type constraints explicit; use A addition order for components, native-time ordered portions only after causal linkage; serialization follows unchanged Stage13. Reject ambiguous precision.
- original: V0, P0, side, R0, E0, S0, position_id, entry_intent_hash, entry_effective_stop_hash.
- entry and each exit_portions element: deal_id, order_id, position_id, request_intent_hash, request_receipt_hash, role, requested_volume, executed_volume, native_time_msc, capture_sequence, price, profit, commission, fee, swap, reason, exit_sl, read_flags, previous_fact_hash, fact_hash. Entry exit_sl is null with flag NOT_APPLICABLE; other required scalar reads must succeed; numeric zero is not missing. role is ENTRY, SAFETY_REDUCTION or FINAL_CLOSE; at most one SAFETY_REDUCTION; one entry; at most two distinct exit deals. Explicit strategy reason binds final normal or severe-spread/fallback close. No partial/split fill.
- residual_snapshots elements: snapshot_id, predecessor_deal_id, position_id, position_ticket, native_or_observation_time, time_source, Vr, P0, S0, bid, ask, mark, position_swap, read_flags, snapshot_hash. Retain observation-time provenance; never label local timestamp as native causal time.
- swap_reconciliations elements: deal_id, before_snapshot_hash, after_snapshot_hash, before_swap, realized_swap, after_swap, interval_accrual, interval_authority_hash, native_swap_profile_hash, status. Require status RECONCILED and zero authenticated interval accrual for initial profile. Full close uses explicit flat-state after receipt, not invented POSITION_SWAP read on absent position.
- safety_handoff: lifecycle_close_id, base_before, contribution_before, base_after, contribution_after, prior_checkpoint_hash, new_checkpoint_hash, stage13_event_hash, commit_receipt_hash. Terminal package requires atomic single commit; open working ledger has no terminal package/receipt.
- terminal: outcome, time_msc, aggregate_gross, aggregate_commission, aggregate_fee, aggregate_swap, group_net, net_return, net_R, stage13_event_id, stage13_sequence, stage13_root, financial_projection_count, boundary_snapshot_hash. outcome NORMAL_CLOSE or EVALUATOR_BOUNDARY; projection count exactly one. Normal boundary_snapshot_hash null; boundary requires sealed residual snapshot and zero fictitious terminal order/deal IDs in Stage13.
- integrity: lifecycle_root, archive_inventory_hash, sidecar_hash_algorithm. SHA256 hash scope excludes a self-hash; archive inventory hashes sidecar bytes externally. Every referenced evidence hash must resolve in exact inventory; missing/altered/foreign evidence rejects.

Exact strings/IDs/hashes must be nonempty (hashes 64 uppercase hex); volumes/prices finite under bound grid; signed components finite; count/sequence nonnegative integers; optional values only at explicitly stated null positions. Known nonterminal partial/failed evidence is retained separately as rejected audit evidence, never packaged as a valid terminal result. No broad history or new receipt authority follows from this schema.

## Required deterministic cases

| ID | Case | Oracle |
|---|---|---|
| S01 | Long 50% reduction | Exact governed q/Vr; realized + residual accounting |
| S02 | Short 50% reduction | Same, Ask-side mark |
| S03 | One FOK full q fill | One realized component, no Stage13 projection |
| S04 | Partial/split multi-deal, even total q | Reject unsupported execution; no completion/retry |
| S05 | Minimum/step infeasible | Existing full-close fallback; no reduction component |
| S06 | Wrong residual Vr/basis/position | Reject |
| S07 | Residual stop equals S0 | Static invariant retained |
| S08 | Residual stop differs or round-trip mutation observed | Fail closed; no automatic SL restoration |
| S09 | Positive/negative/zero swap conservation with authenticated interval | Sp updated once, U replaced |
| S10 | Cumulative post-reduction swap overlaps realized swap | RESIDUAL_SWAP_RECONCILIATION_BLOCKER |
| S11 | Nonzero signed reduction commission/fees | Costs visible immediately and posted once finally |
| S12 | Subsequent >=3 severe-spread observations spanning >=10s | Existing flatten; no second reduction |
| S13 | Residual boundary | Realized sums + sealed pre-end residual; no hypothetical exit cost |
| S14 | Normal full close after reduction | Sum both exit portions and original entry costs once |
| S15 | Changed residual equity/risk denominators | Reject; E0/R0 invariant |
| S16 | Safety transition and terminal handoff | Economic changes legitimate, no duplicated contribution |
| S17 | Duplicate callback, conflict, second Stage13 close | Idempotent callback; conflict/second projection reject |
| S18 | V2 downgrade/relabel/missing sidecar field | Reject; no historical fallback |
| S19 | Authenticated FOK no-fill rejection | Existing full-close fallback only; no q component |
| S20 | Ambiguous receipt/missing callback | No no-fill inference; fail acceptance pending exposure reconciliation |
| S21 | Accrual/correction in swap interval or no authority | Reject; no inferred balancing amount |
| S22 | Interrupted terminal handoff/archive tamper | Quarantine/no second projection; detailed integrity error |

Numeric sanity fixture (synthetic, not native proof): V0=2, q=1, Vr=1, E0=1000, R0=100; Ce=-2, Fe=-1; pre-mark=-20, pre-swap=-4. Reduction profit=-10, commission=-0.5, fee=-0.25, realized swap=-2; post-mark=-10, residual swap=-2. L_before=-27; L_after=-27.75: exactly -0.75 new charges. Final residual profit=5, commission=-0.5, fee=-0.25, swap=-2: gross=-5, commission=-3, fee=-1.5, swap=-4, G=-13.5, return=-0.0135, R=-0.135. Boundary instead at unchanged post-mark has G=-27.75. No interim Stage13 projection.

No tests executed or MT5 launched. Native conformance later must demonstrate disjoint nonzero swap semantics and residual stop/volume retention; successful synthetic fixtures cannot close these blockers.
