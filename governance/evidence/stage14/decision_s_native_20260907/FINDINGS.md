# Decision S bounded native semantics proof

Run DS-NATIVE-LONG-01. Scope NON_CANDIDATE_DECISION_S_NATIVE_SEMANTICS_PROOF. Owner directive retained verbatim in OWNER_DIRECTIVE.txt; later owner message confirmed storage cleanup and instructed continuation. No Candidate signal logic or production imports. B2 = LOCKED; Decision S = NOT_ADOPTED; successor freeze/root/attempt absent.

## Observed native outcome

`REALIZED_RESIDUAL_SWAP_DISJOINT_CONFIRMED`

This is the independently verified observed LONG lifecycle on terminal/compiler/agent build 6140, ETHUSD.s, JustMarkets-Demo2. It is evidence submitted for acceptance, not self-issued governance adoption or a universal broker-semantics claim.

| Finding | Retained native observation |
|---|---|
| Entry | 2022-12-05 12:00:08.939 server/native deal time; requested/executed 0.10; order/deal 2; one full FOK deal |
| Pre-reduction | 2022-12-07 12:00:01 tester observation; V0=0.10; Ub=-0.56 |
| Reduction | Requested/executed q=0.05; order/deal 3; one full FOK deal; realized DEAL_SWAP=-0.28 |
| Residual | Vr=0.05; stable position ID=2 and position ticket=2 retained; basis P0=1306.63 retained |
| Static stop | S0=641.46 at entry, before/after reduction, pre-final snapshot and exit deal state; no restoration request |
| Residual swap | Ua=-0.28 after reduction and -0.28 before final close |
| Final close | 2022-12-07 12:01:07; requested/executed 0.05; order/deal 4; one full FOK deal; DEAL_SWAP=-0.28; no residual position |
| Component reads | All required bool getter results successful; commission/fee were successful zeros; profit and other raw properties retained without performance metrics |
| Complete-group swap | Actual entry swap 0 plus reduction -0.28 plus final close -0.28 = -0.56 |

Exact Decimal checks: Ub = reduction DEAL_SWAP + Ua; Ua = pre-final POSITION_SWAP = final-close DEAL_SWAP; sum(actual exit DEAL_SWAP) = Ub. No value was inferred to balance the equation. Residual snapshots are state evidence, not additional group expenses. No account/terminal-equity delta was used.

## Correct FOK terminology

Volume completion and deal cardinality are independent:

- FOK_FULL_SINGLE_DEAL: requested volume completed by one deal (observed for all three requests).
- FOK_FULL_MULTI_DEAL: requested volume completed by several deals; not partial execution. Still UNSUPPORTED_LEDGER_CARDINALITY under the narrow proposed S ledger.
- FOK_REJECTED_NO_FILL: requires authenticated completed rejection and zero executed volume, not mere missing callbacks.
- PARTIAL_ORDER_EXECUTION: completed/reconciled observation has executed volume below requested volume, with nonzero execution.

The independent verifier includes five classification controls covering single, multi, no-fill, partial and incomplete evidence. This corrects terminology without adding production multi-deal accounting. The harness's immediate reconciliation/stop policy is conservative; it is not a generalized assembler for delayed multi-deal requests. Final retained evidence independently reconciles three unique deals against three full-volume receipts, so that limitation does not affect this observed single-deal result.

## Bounded environment and storage

Model 4 real ticks, M30, no optimization, local agents only, nonvisual, DLL permission disabled and checked by harness. Actual symbol swap mode=1, long rate=-280.56, short rate=-184.08, point/tick size=0.01, contract size=1, lot minimum/step=0.01; weekday multipliers retained in native specification output. Source, executable, compiler/terminal/agent hashes, SET/INI, exact command and all changed journals are retained.

Requested range 2022-12-05 inclusive to 2022-12-09 exclusive is inside the earliest training interval 2021-07-01 to 2023-01-01 from retained candidate metadata. No OOS/holdout, research ranking or candidate code was accessed/executed. Test stopped once the residual was closed on December 7. LONG produced useful nonzero observations, so no SHORT run or further expansion was needed.

Before launch, required free space was max(200*64MiB + 2*64MiB + 16GiB, 30GiB)=30GiB; shortfall zero. W=32MiB evidence allowance, A=64MiB copy/archive allowance, 16GiB scratch/cache reserve. The runner rechecked immediately before launching, monitored an 8GiB incremental free-space-drop bound and a 600-second timeout. Run completed in about 18 seconds without resource-stop. Storage receipts contain exact bytes/timestamps. No B2-scale capacity sample, cleanup or relocation occurred.

## Evidence strength and remaining limits

1. The standalone source compiled with 0 errors/0 warnings. Native evidence lines match their agent-journal copies; exact-volume, stable identity, basis, S0, successful reads and Decimal conservation all pass independent verification.
2. The reduction pre/post observations share the same tester second and occur at noon; final close is about one minute later with unchanged residual swap. This directly supports the observed disjoint split. It does not create a general authenticated no-accrual/correction source for arbitrary intervals or establish rollover-race behavior.
3. Only one LONG lifecycle was required to obtain nonzero swap. SHORT, triple-rollover and other symbol/build profiles remain untested; do not widen acceptance beyond proven scope without review.
4. Bounded diagnostic callbacks write evidence/Print; they are not the proposed production constant-work queue implementation. No native transaction-log completeness claim is made beyond reconciled observed lifecycle and receipts. No partial/multi-deal native proof is claimed.
5. Stage13, A/S production integration, FILE_COMMON remediation and operational safety implementation remain untouched. Existing production source baseline compares byte-identically after the run. Existing final production PRE_TOOLING must still be captured only immediately before subsequently authorized edits.
6. Independent reviewer acceptance of this native profile and subsequent Decision S adoption remain separate decisions. FILE_COMMON_PROFILE_BLOCKER remains confirmed. No automatic governance advancement.

The desired next review can assess whether this exact bounded profile closes RESIDUAL_SWAP_RECONCILIATION_BLOCKER for REALIZED_PORTION_SWAP_V1, or whether additional interval/profile evidence is needed. Decision S was not modified to fit the result.
