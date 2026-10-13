# CONFORMANCE_ACYCLIC_TWO_LAYER_BINDING_V1 — protected dependency

Status: `SOURCE_SCOPE_EXTENSION_REQUIRED`

No production source has been edited and no MT5/MetaTester process has been launched.

## Dependency

`MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh`

Current SHA-256:

`5181E4D65DEAD8C7561E210BED48C9CF1E815E7579AA5624609D93C870B595F0`

The current conformance implementation in this protected include independently recreates the cycle:

- `ResearchConformanceValid()` requires embedded `control_sha256 == InpConformanceControlSha256`.
- `ResearchNativeContext()` reads embedded `tester_profile_sha256` into `g_da_profile`.
- `ResearchNativeBegin()` writes `g_da_profile` into original lifecycle evidence.
- `ResearchConformanceTick()` re-runs `ResearchConformanceValid()` throughout the fixture.

Removing those fields only in `GuardedResearchTester.mq5` or Python would therefore fail during initialization, native-context construction, or the first conformance tick.

## Proposed narrow extension

Authorize `GuardedNativeCostIntegration.mqh` only for conformance authority separation:

1. Remove the conformance-only requirement that Layer A contain `control_sha256`.
2. Remove the conformance-only read of embedded `tester_profile_sha256`.
3. Source the externally pinned runtime-profile identity from a new closed SET input, proposed as `InpConformanceRuntimeProfileSha256`.
4. Require that input to be an exact SHA-256 in the dedicated conformance validator and `ResearchNativeContext()`.
5. Continue using it as `g_da_profile` in lifecycle evidence so downstream V3 profile binding remains unchanged.
6. Preserve `DABoundNativeProfile()`, the adopted inventory/swap constants, fixed fixture scheduling, native lifecycle logic, and every non-conformance branch byte-for-byte.
7. Update `ResearchConformanceValid()` to validate only the captured closed Layer-A schema plus the independently supplied runtime-profile hash. It must not compare any external-control or EX5-derived value to a Layer-A field.

The corresponding authorized EA/Python changes would add the new SET field to the closed type map and bind it in Layer B. This is a post-compile field and introduces no Layer-A dependency.

## Resulting graph

`fixed fixture + configuration/source/protocol identities -> Layer A -> EA compile -> EX5`

`Layer A hash + EX5 hash + EA source hash + runtime profile + SET/INI/calendar/environment -> Layer B`

`Layer B hash -> InpConformanceControlSha256 in SET`

`runtime profile hash -> InpConformanceRuntimeProfileSha256 in SET -> lifecycle evidence`

There is no edge from EX5, Layer B, runtime profile, SET, or PRE_NATIVE back into Layer A.
