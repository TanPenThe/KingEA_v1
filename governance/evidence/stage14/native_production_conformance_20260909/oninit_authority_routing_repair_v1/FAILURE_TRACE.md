# Conformance OnInit authority-routing failure trace

Classification: `LONG_V3 = BLOCKED_CONFORMANCE_ONINIT_AUTHORITY_ROUTING`

The stopped LONG V3 run remains separately classified as `NATIVE_SET_INPUT_CONSUMPTION_PROOF = PASS`. It submitted no orders and is not a native conformance result.

## Exact pre-edit path

`OnInit()` selected `ResearchConformanceAuthorizationValidate()` when `InpNativeConformance` was true. That validator checked the dedicated purpose/profile fields, then evaluated the local manifest file hash before calling `ResearchConformanceValid()` and validating parsed manifest fields.

The exact rejecting predicate was:

`ResearchFileSha256(InpRunManifest) != InpManifestFileSha256`

`ResearchFileSha256()` delegated to `ResearchCaptureLocalInput()`. That function opened only the agent-local sandbox with `FILE_READ | FILE_BIN | FILE_SHARE_READ`. The fixed conformance manifest was not declared by a `#property tester_file`, so MT5 did not copy it into the tester-agent sandbox. The open failed, the returned hash was empty, and the comparison rejected.

The observed failure was therefore an unavailable local manifest, before parsed manifest-field validation. It was not caused by the conformance purpose, gate, root, detached token, or Candidate authorization. The normal Candidate validator did not authorize the stopped initialization.

## Repair routing

The three fixed fixture manifests are now explicit tester resources. OnInit calls the dedicated conformance validator before the ordinary Candidate branch. The sole guarded order seam revalidates through `ResearchActiveAuthorizationValid()`, which selects the same dedicated validator for conformance and retains `ResearchAuthorizationValid()` for every ordinary research operation. A failed conformance validation has no fallback to Candidate authorization.
