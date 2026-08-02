# KingEA Stage 7 Operational Safety Contract

Status: IMPLEMENTED NON-PERFORMANCE INFRASTRUCTURE  
Build ID: `KINGEA-STAGE7-20260727-A`

## Persistence and configuration

- `KingEALoadPersistentState(context, result)` and
  `KingEACommitPersistentState(context, state, result)` are the persistence
  interface.
- Safety state uses redundant A/B SHA-256 snapshots in the MT5 common-files
  sandbox. Writes use a temporary file, flush, readback verification, and move.
- A missing or damaged member of the redundant pair quarantines the deployment.
  A surviving member is diagnostic evidence and never authorizes automatic
  resumption.
- Genesis requires explicit authorization, flat exposure, and reconciliation.
- Configuration identity binds the deployment, Candidate 001 hash, safety
  contract, build, symbol, and server class. An approved flat-state change
  starts a new validation epoch and resets the 30-trade/30-day clock.

## Broker truth

- Restart reconciliation compares every expected position and pending order
  against read-only MT5 broker truth.
- Position ownership requires `KINGEA|<sleeve_id>|<trade_group>` in the broker
  comment plus matching ticket, stable identifier, symbol, direction, volume,
  prices, stop, target, and magic number.
- Account login, server, trade mode, and margin mode must also match.
- Missing, unexpected, duplicated, altered, unprotected, or unowned exposure
  quarantines the deployment. History reconstruction is never a resume path.

## Watchdog and kill switch

- Heartbeat and watchdog polling interval: five seconds. Stale threshold:
  thirty seconds.
- One controlled restart is available only while armed. A second eligible
  failure in rolling 24 hours latches short review.
- All eligible failures also remain active in the rolling 30-day counter.
  The third latches cumulative review before launch. Cumulative review governs
  when both thresholds trigger.
- Short review never clears 30-day evidence. Only approved cumulative review
  archives the active set and begins a new epoch.
- Restart rearming requires 24 continuous healthy, reconciled hours; elapsed
  time alone is insufficient.
- Planned stops and valid manual standdown are excluded from both counters.
- The watchdog checks standdown every poll and immediately before launch.
  Missing fields or unreadable latch content means standdown is active.
- Exact process identity is required; ambiguity quarantines without termination.
- `MT5_TradeBot_RC1_Supervisor` is explicitly excluded.
- The watchdog configuration is disabled. No scheduled task is installed.

## Prohibitions

This stage has no order-submission, position-modification, strategy-history,
indicator, performance, optimizer, OOS, holdout, DLL, or `MqlTick.flags`
capability. Completion authorizes only Stage 8 specification-change detection.
