# Decision S revised adoption-review packet

PROPOSED_NOT_ADOPTED. Design submitted for review; not unconditionally adoption-ready while the swap authority blocker below remains. Decision A's adopted controlled-tester component authority is the foundation (specification SHA256 13F2CDDD2D58864ECE033A2041B0B4885A4501B3ED0CD869D003235BD9E1E23E). S would explicitly extend A's full-position lifecycle only after separate adoption. B2 = LOCKED.

## Preserved safety rules and volume

GuardedResearchTester.mq5:1641-1646 requests reduction when spread ratio >2.5 and !g_spread_reduced; persistent ratio >3 is counted at 780-790 and flattens at count >=3 and elapsed >=10000 ms. It is not a second 50% reduction. Preserve ordering and existing minimum/step fallback at 1280-1296. One governed reduction maximum, followed by normal full close, governed severe-spread flatten or evaluator boundary; no new reduction trigger, add-on or reversal.

Bind original volume V0, side, actual entry price/basis P0, entry stable position ID, S0, original approved risk R0 and pre-entry accounting equity E0. R0/E0 remain fixed. With current volume V (V0 at the sole reduction), preserve the existing computation:

```text
Vr_target = NormalizeDouble(floor((V*0.5 + 1e-12)/step)*step, 8)
q = NormalizeDouble(V - Vr_target, 8)
```

Current <=0, invalid step/minimum, Vr_target < minimum or q < minimum invokes existing ResearchClose fallback. Bind broker lot precision and validate resulting lot units exactly; do not redesign rounding. Retain raw computed volumes as well as exact normalized units. Feasible q must be >0 and <V. Request one FOK order for q; accept exactly one matching OUT deal fully executing q. Vr=V0-q; residual snapshot must prove volume Vr, stable ID, side, basis P0 and S0. Native basis change or unresolved mapping fails closed. Actual residual SL retention is deferred native proof; reduction does not authorize stop modification.

## Reduction outcomes

| Outcome | State/accounting | Safety rule |
|---|---|---|
| FOK DONE, one exact q deal, authenticated residual | Commit one non-financial realized component, latch reduced state | Continue existing triggers; severe-spread close may follow |
| Authenticated rejected/no-fill, native volume unchanged | No component; original exposure remains | Existing send-failure/non-DONE fallback at 1332-1333 invokes one full-close request. No reduction retry |
| Partial fill or multiple deals for one request | Unsupported execution; retain all facts, invalidate research, no accepted aggregate | Do not relabel as no-fill or invent completion/retry. Exposure/emergency operational reconciliation is a blocker; no new accounting-driven flatten trigger |
| Ambiguous send result or missing callbacks | Pending/unresolved; no volume assumption or accepted aggregate | Do not treat as authenticated no-fill. Preserve failure evidence; operational resolution needs separate authority |
| Minimum/step infeasible | No reduction component | Existing full-close fallback only |

Partial/multi-deal behavior conflicts with the supported FOK single-deal profile even if aggregate volume equals q. An identical callback redelivery is not a second deal. No second request while first execution is unresolved. A fallback close must itself authenticate a single full FOK fill; failures are not auto-retried. Existing production IOC is not accepted prospective FOK proof and is not edited here.

## Component ledger and aggregation

Each exit portion uses adopted A callback-bound successful scalar reads: DEAL_PROFIT, DEAL_COMMISSION, DEAL_FEE, DEAL_SWAP and linkage/origin. Entry profit/swap authenticate zero; entry commission/fee are recorded once in full. Each portion binds request intent, one deal/order, requested/executed q, read flags, native time and stable ID. No broad history access. Entry basis P0 does not reset after reduction. Entry-cost allocations q/V0 may be display-only; never add them to financial totals already carrying full entry charges.

Let Rp,Cp,Fp,Sp be sums of accepted exit portions' signed profit, commission, fee and disjoint realized swap. Ce,Fe are original entry charges. Let M be authenticated residual OrderCalcProfit at eligible long/Bid or short/Ask for Vr,P0; U is authenticated disjoint residual swap.

```text
gross = Rp + M
commission = Ce + Cp
fee = Fe + Fp
swap = Sp + U
G = gross + commission + fee + swap
net_R = G/R0; net_return = G/E0
```

At normal full close M=U=0 and all actual exit portions are included once. At boundary use immutable pre-end residual mark/swap, no hypothetical exit fee, no post-end quote, no fictitious close deal. Preserve A normal-pre-end precedence and immutable conflict rejection. Only terminal full close/boundary produces one Stage13 schema-v1 TRADE_GROUP_CLOSE, increments completed group count once and financially posts G. Reductions and interim safety events are non-financial. Financial fields already represent the aggregate; residual sidecar gives its unambiguous decomposition. No historical reinterpretation.

## Residual swap reconciliation

Supported proposed profile REALIZED_PORTION_SWAP_V1 requires native evidence that each deal swap is incremental for that realized portion and post-reduction POSITION_SWAP is disjoint residual accrual. Do not assume this behavior. Before/after values Ub,Ua and reduction Ds must satisfy, at independently bound signed currency precision:

`Ub + authenticated_interval_accrual_or_correction = Ds + Ua`.

Initial supported interval has authenticated accrual/correction zero. A calendar schedule or a difference chosen to force equality is not authentication. If nonzero interval accrual is observed, this initial profile rejects until exact additional authority is separately reviewed. Bind pre/post native snapshots and deal to the same stable ID/request/volume transition and independently verified broker/tester swap profile. Successful zero must be distinguished from failed reads. Native documentation describes DEAL_SWAP as cumulative on close; it does not establish this partial-position allocation: https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties .

After accepted reconciliation: Sp_next=Sp+Ds; U=Ua. Later snapshots replace U, never add successive snapshots. At final close the last realized swap must reconcile against prior residual accrual under the same supported interval rule, and residual exposure is zero. At boundary use Sp+sealed U. No volume-proportional swap estimate. No subtraction heuristic for a broker's cumulative value without separately adopted native authority.

Current classification: RESIDUAL_SWAP_RECONCILIATION_BLOCKER. Exact authenticated interval/no-accrual authority and native realized/residual profile proof are not yet established. This packet specifies the rejection contract but cannot claim that conservation has been demonstrated. Zero-swap fixtures alone cannot prove a nonzero swap profile.

## Safety-equity transition proof

Unposted open contribution L=Rp+M+Ce+Cp+Fe+Fp+Sp+U. Component-state safety equity=B+L, where B is authenticated accounting base excluding this unposted group. Keep A's independent conservative account guard and separate external-flow treatment.

FULL_POSITION: Rp=Cp=Fp=Sp=0; M marks V0 and U is original open swap; entry charges already visible. REDUCED_POSITION: add authenticated reduction profit/charges/swap once, replace M with Vr mark and U with reconciled residual swap. FULL_CLOSE: add final portion, M=U=0. BOUNDARY: use final eligible sealed residual values.

At a common valuation price with unchanged basis and no interval accrual, M_before=realized_reduction_profit+M_after and U_before=Ds+U_after. Thus L_after-L_before equals actual new exit charges; execution slippage or quote movement produces its legitimate measured economic difference, not a required artificial equality. Never force continuity by dropping losses/costs. Safety sees new realized losses/charges immediately plus remaining exposure, before Stage13 posting. Missing residual valuation/swap makes component state unavailable and research fail closed; native account protection is not a substitute for group accounting.

Terminal handoff is atomic: before B+G, after (B+G)+0. Bind lifecycle-close ID and prior/new accounting checkpoint roots; never permit both contribution and posted group to remain active. Crash ambiguity quarantines; duplicate identical deal is idempotent, conflicting duplicate fails; second financial projection rejects.

## Remaining decisions/evidence

Swap profile and interval authority remain blockers. Residual S0/basis/volume retention, failure-path native behavior, nonzero signed costs, safety continuity, profile compliance and archive recovery require later authorized conformance. Ambiguous/partial execution emergency behavior must be separately resolved; accounting cannot invent it. New package semantics below require adoption and consumer validation. Candidate sources and old A/S artifacts remain untouched; S remains NOT_ADOPTED.
