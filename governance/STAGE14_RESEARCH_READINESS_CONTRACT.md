# KingEA Stage 14 Research Readiness Contract

## Status

- Build: `KINGEA-STAGE14-20260802-A`
- Candidate: `CAND-ETH-ST-001`
- Status: readiness implementation; no result-bearing research executed
- Calendar status: native MT5 primary plus governed MQL5 website corroboration accepted
- Candidate-family budget consumed: `0`
- Stage 9 standdown: remains active
- Watchdog: disabled and uninstalled

Stage 14 repairs the Stage 12 execution and evidence seams before Gate 1 may
start. The implementation does not create owner approval. Gate 1 requires a
separately prepared root, a successful signal-free benchmark projecting no more
than 30 active calendar days, and explicit approval of the exact root SHA-256.

## Deep coordinator interface

`ResearchRunCoordinator` owns schema-v2 gate roots and children, deterministic
tester bundles, detached authorization, append-only frame ingestion,
deterministic finalization, signal-free benchmark projection, in-flight pace
decisions, calendar/cost/specification validation, and pre-tooling provenance.
The holdout partition is rejected throughout Stage 14.

Gate cardinalities are structural:

- Gate 1: 200 launches and 194,400 configuration passes.
- Gate 2: eight derived single-configuration rolling-forward launches.
- Gate 3: 312 scenario/seed runs per branch and 624 total launches.

Every gate has a distinct root and detached owner approval. No gate
auto-advances.

## Execution adapters

The tester retains exactly one native `OrderSend` seam. Native baseline and
delay scenarios use the tester-reported result price. Virtual scenarios never
request that seam: their stressed fill, virtual position, equity, stop, exit,
breaker facts, and accounting price remain in virtual state.

The sentinel seam contract proves that an adverse virtual fill reaches both the
virtual position and accounting event exactly, while native-order count remains
zero. The corresponding native fixture consumes only the tester result price.

Combined stress assigns one and only one terminal outcome per eligible signal:
`SEEDED_MISS`, `VIRTUAL_FILL`, `DELAY_EXPIRY`,
`GATE_REJECT_AFTER_DELAY`, or `VIRTUAL_EXECUTION_FAILURE`. Seeded misses are
decided before queueing; delay expiry never changes or compensates the 10%
seeded rate.

## Evidence and operational facts

Complete tester-frame payloads are persisted in append-only, manifest-keyed
spools. Identical replay is idempotent. Conflicting duplicates, missing frames,
unexpected frames, malformed frames, and frames arriving after finalization
fail closed.

Calendar snapshots cover high-impact USD central-bank, CPI, PCE, employment,
and GDP events, with half-open entry blackouts from 30 minutes before through 15
minutes after. Missing months, revisions, duplicates, conflicts, or invalid
timestamps block approval. Research cost/specification facts cannot assume zero
commission or swap without broker-side evidence.

The protection-interval artifact keeps two independent facts for each scheduled
event: `KINGEA_ENTRY_BLACKOUT` spans 30 minutes before through 15 minutes after
and controls entry permission; `BROKER_HMR_SCHEDULED` spans 15 minutes before
through five minutes after and marks the documented broker margin window. The
scheduled HMR end is not proof that margin reverted. Any extended, unscheduled,
stale, or unverified HMR observation blocks entry, continues to apply the greater
of fresh live margin and the frozen 1:200 proxy, and requires fresh broker margin
and reversion evidence. Persistence is never interpreted as approval.

Maintenance protection blocks entries 30 minutes before, forces flattening five
minutes before, and requires 15 independently clean minutes after reopening.
Weekend exposure uses the frozen 50% risk limit.

## Pace and provenance

The benchmark and in-flight controller use the slower of cumulative and
trailing-six-hour valid-pass throughput. Three consecutive hourly forecast or
throughput failures pause before another child launch. Disk, memory, local-agent,
or frame health failures pause immediately. The 30-day ceiling cannot be waived
without changing infrastructure and repeating the signal-free benchmark; the
model, grid, partitions, metrics, and gates remain frozen.

Every final Stage 14 source is hashed immediately into an immutable
`PRE_TOOLING` manifest before compilation. Post-compile size and SHA-256 must
match exactly. A mismatch quarantines the stage before any execution.

## Authorization boundary

This readiness build permits only preparation of the signal-free benchmark and
Gate 1 root. It does not authorize Gate 1 execution, OOS, stress, holdout,
Live2 activity, real demo/live orders, watchdog activation, or standdown
removal. Stage 13's provenance caveat remains historical and accepted; it is
not repeated by Stage 14.

## Accepted calendar-source contract

On 2026-08-02 the read-only Demo2 exporter queried the native MT5 Economic
Calendar for `[2021-04-01, 2025-01-01)` twice: once with the USD currency filter
and once with the combined US/​USD filter. Both calls returned `0` values with
API error `0`. The resulting header-only artifacts are retained as failed
evidence. Their root cause was an invalid `.set` datetime representation: MT5
interpreted the human-readable values as Unix-second integers near the 1970
epoch. With Unix timestamps fixed, the read-only Demo2 native query returned
1,971 high-impact US/USD values for the governed range with zero event-lookup
failures.

The owner explicitly approved the governed MQL5 website adapter on 2026-08-02.
It posts only to the public MQL5 Economic Calendar endpoint, uses fixed USD and
high-impact filters, splits the range into at most 90-day requests, retains all
raw responses append-only, and interprets website times as UTC in half-open
partitions. It uses no cookie, login, credential, or authenticated session.

Native MT5 evidence remains the primary source for trade-server event times.
The website source is independent corroboration, not a silent replacement. The
adapter matched all 1,971 website source IDs and names exactly to native MT5
value IDs and names. Every event had the governed three-hour website-UTC to
native-server offset; no missing, extra, duplicate, or conflicting event was
accepted. All 45 months were populated, with 36-51 events per month, and the
frozen macro-family coverage checks passed.

The calendar and deterministic cost/research-specification inputs are accepted,
including separate broker-HMR and KingEA-entry protection intervals. This does
not authorize research. The signal-free throughput benchmark remains pending.
Gate 1 root preparation and all result-bearing execution remain blocked until
that benchmark passes and the exact root receives a separate owner approval.
