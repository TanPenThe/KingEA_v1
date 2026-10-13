# Conformance Acyclic Two-Layer Binding V1

## Layer A: compile-stable embedded manifest

The Layer-A document is canonical JSON with this exact closed top-level field set:

`S0`, `close_msc`, `configuration_sha256`, `data_scope`, `domain`, `end_msc`, `entry_msc`, `execution_mode`, `fixture_id`, `group_id`, `inventory_protocol_sha256`, `optimization`, `outcome`, `reduction_msc`, `run_id`, `side`, `source_sha256`, `start_msc`, `swap_transition_rule_sha256`, `symbol`, `volume`.

It rejects every undeclared field, including `control_sha256` and `tester_profile_sha256`. It contains no EX5, SET, INI, PRE_NATIVE, launch, or post-compile authority.

## Layer B: independently pinned post-compile control

The Layer-B document is canonical JSON with this exact closed top-level field set:

`artifacts`, `domain`, `ea_source_sha256`, `embedded_manifest`, `environment`, `fixture`, `local_inputs`, `profile`, `set_renderer_contract_sha256`.

Its closed `environment` field set is:

`account_fingerprint`, `agent_build`, `command_bridge`, `compiler_build`, `dll`, `execution_mode`, `local`, `optimization`, `server`, `shared_trading_input`, `symbol`, `terminal_build`, `visual`.

The embedded-manifest reference binds exact Layer-A bytes. The artifacts bind exact configuration and source records plus the final EX5. The profile reference binds exact independently pinned runtime-profile bytes. Recursive construction rejects keys representing final SET bytes/hashes, INI, PRE_NATIVE, and launch receipts.

## SET bindings

The governed SET is generated only after Layer B is final:

- `InpConformanceControlSha256 = SHA256(exact Layer-B bytes)`
- `InpConformanceRuntimeProfileSha256 = SHA256(exact runtime-profile bytes)`
- `InpManifestFileSha256 = SHA256(exact Layer-A bytes)`

## Dependency graph

```text
fixture/config/source/protocol authorities
  -> Layer A
  -> compile
  -> EX5
  -> runtime profile
  -> Layer B
  -> Layer-B hash
  -> SET
  -> PRE_NATIVE / launch receipt
```

Forbidden reverse dependencies are `SET -> Layer A`, `INI -> Layer A`, `PRE_NATIVE -> Layer A`, `launch receipt -> Layer A`, `Layer B -> Layer A construction`, `runtime profile -> Layer A`, and `EX5 -> Layer A`. Layer B cannot contain the final SET hash or bytes, so `Layer B -> final SET -> Layer B` is also rejected.

The generated package records in `ACYCLICITY_PROOF.json` prove Layer A stayed byte-identical across compile, Layer B reconstructed byte-identically, and each SET resolves independently to the exact Layer-A, Layer-B, runtime-profile, and EX5 hashes.

