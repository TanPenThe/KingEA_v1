# Decision A revision — protective-stop exit causality

PROPOSED_NOT_ADOPTED. Decision A implementation is not authorized. B2 = LOCKED.

This supplements the separately retained proposed Decision A; it neither implements its component accounting nor changes its unresolved adoption status.

## Exact proposed property/source/access authority

Add `HistoryDealGetInteger(trans.deal, DEAL_REASON, reason)` and `HistoryDealGetDouble(trans.deal, DEAL_SL, stop_level)` to the proposed callback-bound property allowance, in addition to the previously proposed DEAL_PROFIT and existing linkage/component reads. Selection remains solely `HistoryDealSelect(trans.deal)` inside the active authorized run's `TRADE_TRANSACTION_DEAL_ADD` callback. Each operation and property read must report success; capture the scalar facts and success flags immutably at that callback. No HistorySelect, enumeration, HistoryOrder operation, older ticket query or post-hoc history search is added.

MQL5 defines DEAL_REASON as execution cause, DEAL_REASON_SL as stop-loss activation, and an exit deal's DEAL_SL as the position stop at closing. These native properties, not a deal comment or a price comparison, are the proposed source for stop causality. [Official deal-property reference](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties). Selection affects the selected history list, so capture must be self-contained. [Official HistoryDealSelect reference](https://www.mql5.com/en/docs/trading/historydealselect).

## Acceptance predicate

Accept `PROTECTIVE_STOP_EXIT_AUTHENTICATED` only if all are proven:

1. Active authorized run/group/context and native DEAL_ADD origin; positive callback deal/order and stable position ID, exact symbol/magic and opposing deal direction, normal DEAL_ENTRY_OUT, valid native time and expected full residual exit volume under the separately adopted lifecycle scope.
2. Successful `DEAL_REASON == DEAL_REASON_SL` read; successful finite positive DEAL_SL read.
3. Captured stop matches the last independently confirmed native protective-stop value for that stable position, with its retained confirmation preceding the stop activation and no unresolved stop modification. Compare normalized integer symbol-price units using the bound symbol digits/point; do not invent an epsilon.
4. No unresolved competing manual exit, reversal, partial execution, foreign position or boundary/housekeeping attribution. A normal stop activation before the exclusive end has precedence; conflicting later observation fails finalization acceptance.

Exit price need not equal stop price: execution-price slippage does not negate native SL causality. A stop-price touch alone never proves causality. No explicit close-request receipt is required for the native SL path, but the retained stop confirmation and native reason/linkage are required. EXPERT/CLIENT/MOBILE/WEB/TP/SO/rollover reasons are not accepted as SL; existing separately authenticated explicit-exit handling remains a distinct path.

## Rejection and pending evidence

Missing/failed reason or stop-level read, unknown reason, missing stop confirmation, ambiguous intervening modification, foreign identity, absent callback, unexplained volume or unproven time yields `PROTECTIVE_STOP_CAUSALITY_UNAUTHENTICATED` internally and fail-closed accounting acceptance. At successor public evidence gates retain canonical `SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED` with that detail. Never use terminal equity, comment text, matching price, position absence or an OUT label as replacement evidence. Missing reconciliation remains pending only within a separately specified bounded queue; no final projection may proceed pending proof.

Required later native conformance: long/short SL, gapped fill, tightened stop and conflicting modification, SO/TP/expert false positives, failed native read, delayed callback, correct and wrong stable ID. These are proposed tests only. The current adapter, economic calculation and Stage13 financial booking are unchanged.
