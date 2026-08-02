# Native Spread-Bracket Platform Amendment

Status: FROZEN PLATFORM-COMPATIBILITY RULE  
Effective: 2026-07-22  
Parent protocol: `governance/NATIVE_SPREAD_BRACKET_PROTOCOL.md`

## Evidence

Demo2 contains exactly two registered post-boundary crossed snapshots found so far:

1. `1709374488223`: Bid `3427.62`; Ask `3427.36`; spread `-0.26`; origin flags `100`.
2. `1709375322820`: Bid `3418.20`; Ask `3418.16`; spread `-0.04`; origin flags `98`.

Both are isolated asynchronous one-sided quote updates. Each is followed by a positive-spread update approximately 0.2 seconds later. The one-day diagnostic found no timestamp disorder or invalid numeric fields.

An authorized local custom-symbol probe proved that MT5 accepts both crossed snapshots and round-trips `time_msc`, `time`, Bid, Ask, spread, last, integer volume, and real volume exactly. A later RSB3 persistence diagnostic sampled one transformed day and one unchanged day: 444,322 ticks retained exact counts and every non-flag field, while MT5 deterministically cleared flag bit `128`. Observed mappings were `4→4`, `130→2`, `134→6`, `96→96`, `226→98`, and `230→102`.

## Persistence rule

- The reduced custom branch must preserve the exact two registered timestamps and every non-flag tick field.
- For persisted RSB3 custom history, the only permitted flag transformation is `stored_flags = origin_flags & 0xFFFFFF7F`: clear bit `128` and preserve every other bit.
- The final full verifier must apply that rule to every tick. Any other flag transformation fails acceptance.
- KingEA strategy, gate, execution, and validation code must never use `MqlTick.flags` as a signal, filter, ordering input, cost input, or acceptance metric.
- Source and persisted flags remain auditable validation metadata.
- The complete five-year preflight must confirm these exact two snapshots and no other reversed spread. Any additional reversed tick, changed timestamp, or changed Bid/Ask blocks construction and requires a new governance review.
- No crossed tick may be dropped, reordered, clamped, swapped, or price-normalized after the registered spread boundary.

This rule is justified by verified MT5 storage behavior discovered before any strategy performance test. It does not authorize weakening any price, timestamp, gap, or branch-identity invariant.
