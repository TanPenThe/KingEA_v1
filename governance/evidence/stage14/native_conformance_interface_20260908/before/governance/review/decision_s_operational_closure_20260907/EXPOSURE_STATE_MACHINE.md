# Research validity and exposure control

Two independent state variables, with independently retained transition reasons:

RESEARCH_ACCEPTANCE_STATE: PENDING -> ELIGIBLE only with every accepted lifecycle proof, or -> INVALID_LATCHED. INVALID_LATCHED never returns to eligibility, including after flattening or a corrected snapshot.

EXPOSURE_CONTROL_STATE: FULL_POSITION -> REDUCTION_PENDING -> REDUCED_POSITION / FULL_POSITION_NO_FILL / RECONCILIATION_REQUIRED. Reconciled unsupported states enter QUARANTINED_MONITORED_POSITION. An independently authorized close trigger may enter AUTHORIZED_CLOSE_PENDING -> FLAT_CONFIRMED. Unauthenticated exposure enters AMBIGUOUS_EXPOSURE_FAIL_CLOSED. No state name by itself authorizes an order.

## Submission and outcome transitions

On reduction submission block new strategy entries and further reduction requests. Retain q, request identity, current stable position ID and pre-state. Keep quote, position, stop, connection and independently valid safety/breaker monitoring active. Keep raw callback capture active even if research acceptance is invalid. No automatic retry.

| Outcome | Research state | Exposure response |
|---|---|---|
| FOK_FULL_SINGLE_DEAL, exact q, residual authenticated | Remains pending/eligible subject to remaining gates | REDUCED_POSITION; accept component once; continue governed safety logic |
| FOK_FULL_MULTI_DEAL, sum=q, terminal completion proven | INVALID_LATCHED; unsupported cardinality | Reconcile actual residual; QUARANTINED_MONITORED_POSITION; block entries/reductions. Existing independently satisfied safety triggers may authorize close. No unconditional flatten; MULTI_DEAL_EXPOSURE_RESPONSE_BLOCKER remains |
| PARTIAL_ORDER_EXECUTION | INVALID_LATCHED immediately | Reconcile actual volume, never use V0-q. QUARANTINED_MONITORED_POSITION only if order terminality and position identity known; otherwise reconciliation required. No manufacture of completion; PARTIAL_EXECUTION_EXPOSURE_RESPONSE_BLOCKER |
| Authenticated FOK_REJECTED_NO_FILL | No reduction component; retain failure evidence | Native unchanged volume plus final rejection permits existing ResearchReduceHalf send-failure full-close fallback; full-close request independently guarded. No repeat reduction |
| Ambiguous/incomplete | Block strategy orders immediately; invalidate at unresolved finalization; unsupported facts latch invalid immediately | RECONCILIATION_REQUIRED; do not assume no-fill/old volume. If actual exposure cannot authenticate, AMBIGUOUS_EXPOSURE_FAIL_CLOSED. No automatic speculative close while prior request may remain live |

Research invalid must not disable monitoring or suppress independently authorized risk actions. Conversely a safety close must never repair acceptance or produce a valid S package from unsupported components. All observed economics remain raw audit evidence; no accepted aggregate is invented.

## Exact narrow current-position reconciliation proposal

Use retained current-run ticket plus PositionSelectByTicket(ticket); successful bool getters for POSITION_IDENTIFIER, POSITION_TICKET, POSITION_TYPE, POSITION_MAGIC, POSITION_VOLUME, POSITION_PRICE_OPEN, POSITION_SL and POSITION_SWAP, and successful symbol string read. Compare against independently retained run/group/stable-ID bindings. A ticket is not the stable identifier. If a ticket lookup fails, do not enumerate other positions or infer flatness. An optional exact-symbol selection may only be adopted for a separately proven single-position profile, with stable-ID equality; it is not a fallback authority in this packet.

Capture current quote and observation time/read flags separately from native deal time. Already captured current-run DEAL_ADD facts, outbound receipt and relevant REQUEST completion facts may reconcile the request. No HistorySelect, history enumeration, order-history query or replay/backfill. Missing terminality remains unknown even when present position volume is readable. Position absence plus a missing callback does not prove completed closure. Exact property access for this adapter must be included in eventual implementation scope; existence of broad restart inventory does not authorize importing it.

## Existing-authority mapping (paths relative to C:/KingEA_v1)

| Source | Existing authority | Limit |
|---|---|---|
| governance/SAFETY_KERNEL_CONTRACT.md, fixed policy | Unknown exposure/invalid facts fail closed; named spread and breaker controls | No blanket flatten for ledger cardinality/partial execution |
| SafetyKernel.mqh KingEAProcessPositionReview, 751-777 | Failed stop -> FLATTEN; persistent severe spread -> FLATTEN; maintenance/unsafe-news -> FLATTEN; unknown exposure/state -> QUARANTINE | Kernel is a pure planner; caller must supply true facts and authorized exact-position execution. Never fabricate stop failure to obtain flatten |
| SafetyKernel.mqh 612-680 | Named account/sleeve breakers can request flatten | Requires independently valid threshold facts, not missing P&L filled with zeros |
| GuardedResearchTester.mq5 1288-1296,1332-1333 | Infeasible reduction and send-failure/non-DONE fallback call ResearchClose | Does not establish that successful multi-deal execution is a send failure. Ambiguous completion cannot safely be called authenticated no-fill |
| same 1641-1653 | Existing spread/maintenance/news monitoring and close callers | Must remain active in redesigned exposure-control path despite invalid research |
| same 793-810 ResearchOrderSend | Existing execution authorization guard | Safety action must not bypass identity/profile authorization. If authority is lost, no fabricated emergency bypass |
| same g_hard_failures / OnTester | Failure contributes to result rejection | Not an exposure-control state machine or guaranteed entry latch; cannot be cited as complete response |
| OperationalSafety.mqh; governance/OPERATIONAL_SAFETY_CONTRACT.md | Quarantine/persistence/identity-aware watchdog policy | Explicitly non-trading infrastructure; no automatic flatten authority. Shared-state restoration prohibited by controlled profile |

These mappings support quarantine, entry blocking and continued valid safety monitoring as the proposed adapter behavior, but do not close the unspecified residual-management policy for every unsupported execution. Preserve both exact blockers rather than asserting an unconditional safe response.

## Required deterministic controls

Assert full multi-deal volume is not partial; invalidity sticky after flatten; invalid research still receives safety observations; no new entries/reduction retries; native residual != requested residual is retained; unknown order terminality blocks duplicate orders; no history fallback; failed stop/severe spread triggers evaluated on valid facts only; generic ledger failure cannot masquerade as those triggers; profile mismatch permanently invalidates acceptance; SHORT cannot consume LONG-only conformance receipt.
