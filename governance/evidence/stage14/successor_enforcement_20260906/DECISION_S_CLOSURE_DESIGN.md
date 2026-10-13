# Decision S closure design — proposed rules only

PROPOSED_NOT_ADOPTED. Decision S/A implementation is not authorized. B2 = LOCKED.

## 1. Realized versus residual swap

Supported prospective semantic profile: `REALIZED_PORTION_SWAP_V1`. Each authenticated full reduction deal's signed swap represents only the portion realized by that deal; the reconciled native position swap represents only the remaining unrealized position. This is an explicit proposed supported profile, **not an assertion that the current broker/build has proved it**. MQL5 describes DEAL_SWAP as cumulative swap on close, which does not by itself establish partial-position allocation. [Official reference](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties).

Maintain original group basis and cumulative realized swap `S_realized`, initially zero (entry swap must be authenticated zero). Capture pre-reduction native residual swap `S_before`, the reduction's captured `D_swap`, and a post-reduction reconciled residual snapshot `S_after`. Require `S_before = D_swap + S_after` at the bound account-currency precision for an interval proven free of additional swap accrual/correction. Use exact signed decimal component values; do not proportionally estimate swap from volume. Before accepting the transaction, native-profile evidence and current-run event/snapshot linkage must establish that no additional accrual/correction occurred in that transition interval. A calendar schedule alone is not that evidence.

If accrual or correction occurs during the interval, or absence cannot be authenticated, mark reconciliation unresolved and fail accounting finalization; do not infer the missing accrual as the difference needed to force equality. Safety still responds to actual exposure. Separate future authority/proof is required to support such intervals. This conservative unsupported-case rule is visible and must not silently omit a configuration from research.

On acceptance: `S_realized_next = S_realized + D_swap`; residual swap becomes exactly `S_after`. At later eligible observations, capture fresh actual residual swap; newly accrued residual swap remains unrealized and is not added to S_realized. At full close require zero residual volume/swap and use the final deal's attributable realized swap once. At boundary use `S_realized + sealed_residual_swap`. Never sum successive POSITION_SWAP snapshots, never add a previous snapshot again, and never accept cumulative whole-group DEAL_SWAP as if each deal were incremental. Conflicting native semantics block this profile until a separately reviewed adapter/profile exists.

Native acceptance proof must establish realized-portion behavior for two reductions plus a final close and reduction-plus-boundary; signed debit/credit/zero swap; transitions near accrual; volume and stable-ID reconciliation. These proofs are deferred; no native run is performed here.

## 2. Open-group operational safety equity

Keep one non-financial lifecycle balance for the open group, distinct from the eventual financial close. Define:

```
G_open = realized_profit_sum + residual_mark
         + original_entry_commission + original_entry_fee
         + realized_exit_commission_sum + realized_exit_fee_sum
         + S_realized + current_authenticated_residual_swap
operational_safety_equity = authenticated_base_excluding_unposted_group + G_open
```

The base is the authenticated accounting state excluding this unposted group's components; apply external cash flows under the existing separate authority, never as group PnL. Use the original-risk money for R and original pre-entry authenticated equity for group return. Full reduction losses/costs therefore affect safety immediately; residual mark uses an eligible contemporaneous native calculation and reconciled position basis/volume. Missing/stale/unreconciled facts fail closed under existing safety rules; no terminal-equity delta substitutes for group components.

Atomic closure handoff: consume a unique lifecycle-close ID, post the one aggregate group financial event, advance the authenticated base by exactly that group result, then remove the open-group contribution under the same checkpoint transition. Persist a before/after receipt linking lifecycle root and Stage13 root. Crash recovery must replay exactly one transition or remain quarantined; it cannot leave both contributions active or silently drop both. Before the handoff: base + G_open. After: updated base + zero open contribution. These must agree for unchanged quote/cost state. Breaker/high-water inputs use this operational value continuously; realized losses are never deferred until final close.

Existing safety triggers, reduction quantities and broker-minimum/step fallback remain unchanged. This design does not permit extra reductions or partial order fills and does not financially post interim components twice. The actual safety adapter/checkpoint implementation is excluded from the current work.

## 3. Explicit new evidence semantic version

Proposed identifier: `NATIVE_GROUP_LIFECYCLE_CONTRACT_V3`; package: `NATIVE_GROUP_LIFECYCLE_PACKAGE_V3`; semantic tag: `PARTIAL_POSITION_COMPONENTS_V1`. These names are reserved by this proposal only, not adopted/implemented. V2 validators must reject them and must reject residual semantics presented as WHOLE_POSITION_V2.

Required envelope fields: schema, semantic tag, candidate/configuration/source/specification hashes; freeze/execution receipts and run/root/branch/partition/group binding; adopted A/S hashes; volume unit/price/currency precision; original V0/P0/R0/E0 and stable position ID; ordered authenticated entry/exit components with unique deal IDs and causality; each residual reconciliation and swap-profile receipt; current residual snapshot/mark; operational-equity base/contribution and handoff receipt; lifecycle chain root; terminal outcome NORMAL_CLOSE or EVALUATOR_BOUNDARY; aggregate signed components and exact Stage13 event/sequence/root; close/boundary counts; separately classified housekeeping evidence where supported.

Aggregate rules are those in the separately proposed A/S amendments; schema-v1 financial serialization stays unchanged. Add a dedicated future V3 validator after adoption, with exact field/precision/chain tests and no V2 fallback. Open records have no financial-close ID; closed package must have exactly one terminal outcome and financial projection. Unknown fields/versions and incomplete reconciliation reject. The current successor enforcement accepts only the adopted whole-position V2 semantic scope; this proposed V3 is explicitly blocked.

Unresolved before S adoption/implementation: authenticated no-accrual transition source, native realized-portion swap profile proof, exact safety adapter/checkpoint receipt schema and recovery conformance. The equations, exclusion rules and proposed version above are exact; no runtime feasibility is claimed.
