"""Construct fixed bootstrap-only native-conformance fixture packages.

This is an evidence-package constructor, not a launcher.  It creates no root,
acceptance, freeze, budget, or Candidate artifact.
"""
from __future__ import annotations

import hashlib
import configparser
import json
import subprocess
from pathlib import Path

from research_pipeline.native_conformance_control import (
    ConformanceControl, DOMAIN, SCOPE, build_layer_a, build_layer_b,
    read_build_authority, read_pinned_loader_binding, BUILD_KEYS, BUILD_HASH_KEYS)
from research_pipeline import decision_a_evidence as v3

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent / "v2_runtime_packages"
CALENDAR = ROOT / "governance/evidence/stage14/protection_intervals_20260802_v1/PROTECTION_INTERVALS.csv"
EX5 = Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\KingEA\GuardedResearchTester.ex5")
EA_SOURCE = ROOT / "MQL5/Experts/KingEA/GuardedResearchTester.mq5"
INTEGRATION_SOURCE = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
CONTROL_SOURCE = ROOT / "research_pipeline/native_conformance_control.py"
VALIDATION_SOURCE = ROOT / "research_pipeline/decision_a_evidence.py"
COMBINED = ROOT / "governance/review/combined_adoption_20260907/CONSOLIDATED_CONTRACT.md"
A = ROOT / "governance/review/decision_a_adoption_plan_20260907/ADOPTED_SPECIFICATION.md"
S = ROOT / "governance/review/decision_s_operational_closure_20260907/DECISION_S_FINAL_SPECIFICATION.md"
PRIOR_LONG = ROOT / "governance/evidence/stage14/decision_s_native_20260907/SEALED_INVENTORY.json"

FIXTURES = (
    dict(fixture_id="NCV1-LONG-NORMAL-001", run_label="NCV1-RUN-LONG-NORMAL-001", run_id="C666040B2B67CB6C5B62BC73193104F84F99731AD695DF250B9E3B17D5D60F2F", group_id="NCV1-GROUP-LONG-NORMAL-001", side="LONG", volume="0.10", S0="600.00", start_msc=1670327700000, end_msc=1670414700000, entry_msc=1670328000000, reduction_msc=1670414400000, close_msc=1670414460000, outcome="NORMAL_CLOSE"),
    dict(fixture_id="NCV1-SHORT-NORMAL-001", run_label="NCV1-RUN-SHORT-NORMAL-001", run_id="7C0F0DDCA6FAB33786C9ABC31B8232A3B45D6942777BC07D1A483CD1AA99DABF", group_id="NCV1-GROUP-SHORT-NORMAL-001", side="SHORT", volume="0.10", S0="2000.00", start_msc=1670328300000, end_msc=1670415300000, entry_msc=1670328600000, reduction_msc=1670415000000, close_msc=1670415060000, outcome="NORMAL_CLOSE"),
    dict(fixture_id="NCV1-LONG-BOUNDARY-001", run_label="NCV1-RUN-LONG-BOUNDARY-001", run_id="5BFEA0B6C3B2D9E6F05B71FA43DC42EF0FAC20D0FADDC8A978DF8BC1DDB68FCA", group_id="NCV1-GROUP-LONG-BOUNDARY-001", side="LONG", volume="0.10", S0="600.00", start_msc=1670328900000, end_msc=1670415660000, entry_msc=1670329200000, reduction_msc=1670415600000, close_msc=0, outcome="EVALUATOR_BOUNDARY"),
)

def raw_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()

def sha(raw): return hashlib.sha256(raw).hexdigest().upper()

def put(directory: Path, name: str, raw: bytes):
    path = directory / name
    path.write_bytes(raw)
    return {"path": name.replace("\\", "/"), "sha256": sha(raw)}

def copied(directory: Path, name: str, source: Path):
    return put(directory, name, source.read_bytes())

def validate_set_ini_binding(directory: Path, context):
    """Require the one governed SET basename and exact captured bytes."""
    name = context.fixture['fixture_id'] + '.set'
    sets = list(directory.glob('*.set'))
    if len(sets) != 1 or sets[0].name != name or not sets[0].is_file():
        raise ValueError('PREPARATION_SET_BASENAME_MISMATCH')
    ini_raw = (directory/'tester.ini').read_bytes()
    if ini_raw.startswith(b'\xef\xbb\xbf'):
        raise ValueError('PREPARATION_INI_BOM_FORBIDDEN')
    ini = configparser.ConfigParser(interpolation=None, strict=True)
    ini.optionxform = str
    ini.read_string(ini_raw.decode('utf-8', errors='strict'))
    if not ini.has_section('Tester') or ini['Tester'].get('ExpertParameters') != name:
        raise ValueError('PREPARATION_INI_SET_REFERENCE_MISMATCH')
    expected = context.prepare_inputs()['set_bytes']
    observed = sets[0].read_bytes()
    if observed != expected or sha(observed) != sha(expected):
        raise ValueError('PREPARATION_SET_BYTES_MISMATCH')
    return dict(set_basename=name, set_sha256=sha(observed), ini_sha256=sha(ini_raw))

def observe_binary(path):
    """Read PE bytes and Windows version resources without executing the binary."""
    path = Path(path).resolve()
    raw = path.read_bytes()
    if len(raw) < 64 or raw[:2] != b'MZ':
        raise ValueError('ACTUAL_BINARY_REQUIRED')
    offset = int.from_bytes(raw[60:64], 'little')
    if raw[offset:offset+4] != b'PE\x00\x00':
        raise ValueError('ACTUAL_BINARY_REQUIRED')
    literal = str(path).replace("'", "''")
    command = "$v=(Get-Item -LiteralPath '"+literal+"').VersionInfo; [string]::Join('.',@($v.FileMajorPart,$v.FileMinorPart,$v.FileBuildPart,$v.FilePrivatePart))"
    result = subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command',command],
                            check=True,capture_output=True,text=True,timeout=30)
    version = result.stdout.strip()
    parts = version.split('.')
    if len(parts) != 4 or parts[:3] != ['5','0','0'] or not parts[3].isdigit():
        raise ValueError('ACTUAL_BINARY_VERSION_INVALID')
    if path.read_bytes() != raw:
        raise ValueError('BINARY_CHANGED_DURING_OBSERVATION')
    return dict(path=str(path),sha256=sha(raw),byte_length=len(raw),version=version,build=int(parts[3]))

def verify_build_binaries(authority, binary_paths):
    if type(binary_paths) is not dict or set(binary_paths) != set(BUILD_HASH_KEYS):
        raise ValueError('ACTUAL_BINARY_PATHS_REQUIRED')
    observations = {}
    for build, digest in zip(BUILD_KEYS, BUILD_HASH_KEYS):
        observed = observe_binary(binary_paths[digest])
        if observed['sha256'] != authority[digest] or observed['build'] != authority[build]:
            raise ValueError('ACTUAL_BUILD_BINARY_MISMATCH:'+digest)
        observations[digest] = observed
    return observations

def source_manifest():
    return dict(kind='CONFORMANCE_COMPILE_STABLE_SOURCE_MANIFEST_V2',files=[
        dict(path=path.relative_to(ROOT).as_posix(),sha256=sha(path.read_bytes()))
        for path in (EA_SOURCE,INTEGRATION_SOURCE,CONTROL_SOURCE,VALIDATION_SOURCE)])

def profile(fixture, hashes, authority):
    return dict(
        evidence_scope=SCOPE, fixture_id=fixture["fixture_id"], side=fixture["side"],
        evaluation_start_msc=fixture["start_msc"], evaluation_end_msc=fixture["end_msc"],
        accepted_proof_sha256=None, server="JustMarkets-Demo2", symbol="ETHUSD.s",
        **{key:authority[key] for key in BUILD_KEYS+BUILD_HASH_KEYS},
        local=True, visual=False, dll=False, command_bridge=False, shared_trading_input=False,
        swap_transition_rule_hash=v3.SWAP_TRANSITION_ADOPTION, facts=v3.SWAP_FACTS,
        source_manifest_hash=hashes["SOURCE_MANIFEST"]["sha256"], executable_hash=hashes["EXECUTABLE"]["sha256"],
        configuration_hash=hashes["CONFIGURATION_SPECIFICATION"]["sha256"], native_swap_profile_hash=hashes["NATIVE_SWAP_PROFILE"]["sha256"],
    )

def construct_layer_a(base: Path, specified: dict):
    d = base / specified["fixture_id"]
    if d.exists():
        raise RuntimeError(f"refusing to overwrite existing fixture package: {d}")
    d.mkdir(parents=True)
    specified = dict(specified)
    run_label = specified.pop("run_label")
    if sha(run_label.encode()) != specified["run_id"]:
        raise RuntimeError("RUN_LABEL_HASH_MISMATCH")
    fixture = dict(specified, data_scope="DEVELOPMENT_ONLY", execution_mode=20, optimization=False, symbol="ETHUSD.s")
    put(d, "run_label_provenance.json", raw_json(dict(kind="RUN_LABEL_PROVENANCE_V1", run_label=run_label, run_id=fixture["run_id"], derivation="SHA256_UTF8_UPPERCASE")))
    configuration = dict(domain=DOMAIN, evidence_scope=SCOPE, fixture_id=fixture["fixture_id"], run_id=fixture["run_id"], group_id=fixture["group_id"], symbol="ETHUSD.s", timeframe="M30", execution_mode=20, optimization=False, local_agents_only=True, dll=False, candidate_execution=False, successor_authority=False)
    fixture_ref=put(d, "fixture_specification.json", raw_json(fixture))
    configuration_ref=put(d, "configuration_specification.json", raw_json(configuration))
    sources=source_manifest()
    source_ref=put(d,"source_manifest.json",raw_json(sources))
    layer_a=build_layer_a(fixture,configuration_ref["sha256"],source_ref["sha256"])
    put(d,"manifest.json",layer_a)
    return d

def complete_layer_b(d: Path, *, build_authority_root, build_authority_reference,
                     binary_paths, ex5_path, compile_receipt_root, compile_receipt_reference):
    # All external authority and real-binary checks precede package mutation.
    if (d/'conformance_control.json').exists():
        raise ValueError('POSTCOMPILE_PACKAGE_ALREADY_EXISTS')
    authority=read_build_authority(build_authority_root,build_authority_reference)
    observations=verify_build_binaries(authority,binary_paths)
    fixture=json.loads((d/"fixture_specification.json").read_bytes())
    if any(authority[k]!=fixture[k] for k in ('fixture_id','run_id')):
        raise ValueError('BUILD_AUTHORITY_FIXTURE_MISMATCH')
    if (d/'source_manifest.json').read_bytes()!=raw_json(source_manifest()):
        raise ValueError('COMPILE_STABLE_SOURCE_DRIFT')
    layer_a=(d/'manifest.json').read_bytes()
    if layer_a!=build_layer_a(fixture,sha((d/'configuration_specification.json').read_bytes()),sha((d/'source_manifest.json').read_bytes())):
        raise ValueError('LAYER_A_MISMATCH')
    compile_receipt=read_pinned_loader_binding(compile_receipt_root,compile_receipt_reference)
    ex5_raw=Path(ex5_path).read_bytes()
    expected_compile=dict(kind='CONFORMANCE_POSTCOMPILE_BINDING_V1',
        layer_a_sha256=sha(layer_a),source_manifest_sha256=sha((d/'source_manifest.json').read_bytes()),
        compiler_build=authority['compiler_build'],compiler_sha256=authority['metaeditor_executable_sha256'],
        ex5_sha256=sha(ex5_raw),ex5_byte_length=len(ex5_raw))
    if not ex5_raw or compile_receipt!=expected_compile:
        raise ValueError('INDEPENDENT_COMPILE_BINDING_MISMATCH')
    fixture_ref={"path":"fixture_specification.json","sha256":sha((d/"fixture_specification.json").read_bytes())}
    configuration_ref={"path":"configuration_specification.json","sha256":sha((d/"configuration_specification.json").read_bytes())}
    source_ref={"path":"source_manifest.json","sha256":sha((d/"source_manifest.json").read_bytes())}
    price = dict(kind="NATIVE_PRICE_CONVENTION_V1", symbol="ETHUSD.s", long_entry="ASK", long_exit="BID", short_entry="BID", short_exit="ASK", point="0.01", source="CONTROLLED_TESTER_NATIVE_TICK")
    arithmetic = dict(kind="STAGE13_COMPONENT_ARITHMETIC_V1", currency_precision=8, component_aggregation="gross+commission+fee+swap", financial_projection="ONE_TERMINAL_STAGE13_EVENT")
    hashes = {
        "FIXTURE_SPECIFICATION": fixture_ref,
        "CONFIGURATION_SPECIFICATION": configuration_ref,
        "SOURCE_MANIFEST": source_ref,
        "EXECUTABLE": put(d, "GuardedResearchTester.ex5", ex5_raw),
        "COMBINED_SPECIFICATION": copied(d, "combined_contract.md", COMBINED),
        "DECISION_A_SPECIFICATION": copied(d, "decision_a.md", A),
        "DECISION_S_SPECIFICATION": copied(d, "decision_s.md", S),
        "PRICE_CONVENTION": put(d, "price_convention.json", raw_json(price)),
        "ARITHMETIC_CONTRACT": put(d, "arithmetic_contract.json", raw_json(arithmetic)),
    }
    bootstrap = dict(kind="UNACCEPTED_NATIVE_SWAP_BOOTSTRAP", side=fixture["side"], fixture_id=fixture["fixture_id"], evidence_scope=SCOPE, expected_environment=dict(server="JustMarkets-Demo2", symbol="ETHUSD.s", build=authority['terminal_build']), accepted_proof_sha256=None)
    hashes["NATIVE_SWAP_PROFILE"] = put(d, "native_swap_bootstrap.json", raw_json(bootstrap))
    prof = put(d, "tester_profile.json", raw_json(profile(fixture, hashes, authority)))
    cal = copied(d, "calendar.csv", CALENDAR)
    local = dict(manifest_path=f"KingEA/conformance/{fixture['fixture_id']}/manifest.json", calendar_path=f"KingEA/conformance/{fixture['fixture_id']}/calendar.csv", calendar=cal)
    embedded={"path":"manifest.json","sha256":sha((d/"manifest.json").read_bytes())}
    environment=dict(**{key:authority[key] for key in BUILD_KEYS+BUILD_HASH_KEYS},
                     server="JustMarkets-Demo2",account_fingerprint="7A48EA06EF0D875778BE072F960AD75678E901FABAB363F82CA8886A6E7D78CD",
                     symbol="ETHUSD.s",execution_mode=20,
                     optimization=False,local=True,visual=False,dll=False,
                     command_bridge=False,shared_trading_input=False)
    control_raw=build_layer_b(fixture=hashes["FIXTURE_SPECIFICATION"],profile=prof,
                              artifacts=hashes,local_inputs=local,
                              embedded_manifest=embedded,ea_source_sha256=sha(EA_SOURCE.read_bytes()),
                              environment=environment,build_authority_reference=build_authority_reference)
    cref = put(d, "conformance_control.json", control_raw)
    ctx = ConformanceControl(d, cref["path"], cref["sha256"],
                             build_authority_root=build_authority_root,
                             build_authority_reference=build_authority_reference)
    inputs = ctx.prepare_inputs()
    if inputs['manifest']!=layer_a:
        raise ValueError('LAYER_A_CHANGED_AFTER_COMPILE')
    put(d, fixture["fixture_id"] + ".set", inputs["set_bytes"])
    ini = "[Tester]\r\n" + "\r\n".join((
        "Expert=KingEA\\GuardedResearchTester.ex5", "Symbol=ETHUSD.s", "Period=M30",
        "FromDate=2022.12.05", "ToDate=2022.12.09", "ExpertParameters="+fixture['fixture_id']+".set",
        "Optimization=0", "ExecutionMode=20", "Model=4", "Visual=0", "UseLocal=1", "UseRemote=0", "UseCloud=0", "ShutdownTerminal=1")) + "\r\n[Experts]\r\nAllowDllImport=0\r\n"
    put(d, "tester.ini", ini.encode('utf-8'))
    validate_set_ini_binding(d, ctx)
    if observations!=verify_build_binaries(authority,binary_paths):
        raise ValueError('ACTUAL_BINARY_DRIFT_DURING_CONSTRUCTION')
    read_build_authority(build_authority_root,build_authority_reference)
    put(d,'PREPARATION_STATUS.json',raw_json(dict(kind='NON_RUNTIME_PREPARATION',
        runtime_authorized=False,launch_authority=False,observations=observations,
        compile_receipt_reference=compile_receipt_reference)))
    # LONG provenance is archival comparison material, deliberately outside artifacts/profile/control.
    if fixture["side"] == "LONG":
        copied(d, "prior_long_proof_provenance.json", PRIOR_LONG)
    return d

def construct(base: Path, specified: dict, **postcompile_authority):
    if not postcompile_authority:
        raise ValueError('EXPLICIT_POSTCOMPILE_AUTHORITY_REQUIRED')
    return complete_layer_b(construct_layer_a(base,specified),**postcompile_authority)

def main():
    if sha(CALENDAR.read_bytes()) != "4E01CE4DB034F9AB49A0D77808178E8933026A514674D2A50A67042BB35442E3":
        raise RuntimeError("CONFORMANCE_CALENDAR_AUTHORITY_UNAVAILABLE")
    raise ValueError('EXPLICIT_POSTCOMPILE_AUTHORITY_REQUIRED_USE_CONSTRUCT_LAYER_A_FOR_PRECOMPILE')

if __name__ == "__main__": main()
