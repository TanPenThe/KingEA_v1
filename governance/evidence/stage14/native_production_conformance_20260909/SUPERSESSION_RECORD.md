# Supersession before native execution

`reconstructed_packages` and `pin_receipts` remain immutable records of a
successful control construction and read-only pin verification.  They bind the
retained compile artifact `844A97245DC80AA93F4F96F4E2F1BD9CBD7EF2A688DD44D6DD4E45DC2001F886`.

The required fresh deployment compile produced
`C3E6AE0BD47E071CA3454D9FF07968D24EF8FA302EE2B92DCDEABDA03D9B8E81`.
No terminal/tester run occurred before this discovery.  The earlier controls
cannot be altered after pinning, so they are superseded for runtime use.  The
new package root reconstructs the same authorized fixture semantics and binds
the fresh executable before a new independent pin receipt is issued.

The `fresh_executable_packages` and `fresh_executable_pin_receipts` records are
also preserved but superseded before execution: their generated INI omitted the
explicit `[Experts]` / `AllowDllImport=0` control required by the fixed tester
profile. `final_runtime_packages` adds that exact control and no fixture,
profile, executable, calendar, source, or semantic change.
