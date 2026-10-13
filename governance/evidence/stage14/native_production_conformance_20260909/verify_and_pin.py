"""Read-only custodian verification for fixed native-conformance packages.

Receipts are written outside package directories.  The verifier neither edits a
package nor starts a terminal, tester, Candidate, or research root.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

from research_pipeline.native_conformance_control import ConformanceControl, DOMAIN, SCOPE

BASE = Path(__file__).resolve().parent
PACKAGES = BASE / "v2_runtime_packages"
RECEIPTS = BASE / "v2_runtime_pin_receipts"
EXPECTED = {
 "NCV1-LONG-NORMAL-001": ("C666040B2B67CB6C5B62BC73193104F84F99731AD695DF250B9E3B17D5D60F2F", "NCV1-GROUP-LONG-NORMAL-001", "LONG", "0.10", "600.00", 1670327700000, 1670414700000, 1670328000000, 1670414400000, 1670414460000, "NORMAL_CLOSE"),
 "NCV1-SHORT-NORMAL-001": ("7C0F0DDCA6FAB33786C9ABC31B8232A3B45D6942777BC07D1A483CD1AA99DABF", "NCV1-GROUP-SHORT-NORMAL-001", "SHORT", "0.10", "2000.00", 1670328300000, 1670415300000, 1670328600000, 1670415000000, 1670415060000, "NORMAL_CLOSE"),
 "NCV1-LONG-BOUNDARY-001": ("5BFEA0B6C3B2D9E6F05B71FA43DC42EF0FAC20D0FADDC8A978DF8BC1DDB68FCA", "NCV1-GROUP-LONG-BOUNDARY-001", "LONG", "0.10", "600.00", 1670328900000, 1670415660000, 1670329200000, 1670415600000, 0, "EVALUATOR_BOUNDARY"),
}

def sha(raw): return hashlib.sha256(raw).hexdigest().upper()
def load(path): return json.loads(path.read_text(encoding="utf-8"))
def artifact(path):
 raw=path.read_bytes(); return dict(path=path.name, sha256=sha(raw), byte_length=len(raw))

def check(ctx, package):
 f=ctx.fixture; expected=EXPECTED[f["fixture_id"]]
 actual=(f["run_id"],f["group_id"],f["side"],f["volume"],f["S0"],f["start_msc"],f["end_msc"],f["entry_msc"],f["reduction_msc"],f["close_msc"],f["outcome"])
 if actual != expected: raise ValueError("FIXTURE_AUTHORIZATION_MISMATCH")
 if not (f["data_scope"] == "DEVELOPMENT_ONLY" and f["execution_mode"] == 20 and f["optimization"] is False and f["symbol"] == "ETHUSD.s"): raise ValueError("FIXTURE_SCOPE_MISMATCH")
 p=ctx.profile
 if not (p["accepted_proof_sha256"] is None and p["server"] == "JustMarkets-Demo2" and p["symbol"] == "ETHUSD.s" and all(p[k] == 6140 for k in ("terminal_build","compiler_build","agent_build"))): raise ValueError("BOOTSTRAP_PROFILE_MISMATCH")
 if not (p["local"] and not p["visual"] and not p["dll"] and not p["command_bridge"] and not p["shared_trading_input"]): raise ValueError("TESTER_PROFILE_MISMATCH")
 inputs=ctx.prepare_inputs()
 paths={"fixture_specification":"fixture_specification.json","profile":"tester_profile.json","calendar":"calendar.csv","manifest":"manifest.json","conformance_control":"conformance_control.json","SET":"GuardedResearchTester.set","INI":"tester.ini"}
 records={role:artifact(package/name) for role,name in paths.items()}
 if (package/paths["manifest"]).read_bytes()!=inputs["manifest"]: raise ValueError("MANIFEST_CAPTURE_MISMATCH")
 if (package/paths["SET"]).read_bytes()!=inputs["set_bytes"]: raise ValueError("SET_CAPTURE_MISMATCH")
 if sha((package/paths["calendar"]).read_bytes()) != "4E01CE4DB034F9AB49A0D77808178E8933026A514674D2A50A67042BB35442E3": raise ValueError("CONFORMANCE_CALENDAR_AUTHORITY_UNAVAILABLE")
 ini=(package/paths["INI"]).read_text(encoding="utf-8")
 for key,value in inputs["required_ini"].items():
  if f"{key}={value}" not in ini: raise ValueError("INI_REQUIRED_SETTING_MISMATCH")
 if "[Experts]" not in ini or "AllowDllImport=0" not in ini: raise ValueError("INI_DLL_PROFILE_MISMATCH")
 return records

def main():
 RECEIPTS.mkdir(exist_ok=True)
 for fixture_id in EXPECTED:
  package=PACKAGES/fixture_id
  control=artifact(package/"conformance_control.json")
  ctx=ConformanceControl(package, control["path"], control["sha256"])
  records=check(ctx,package)
  f=ctx.fixture
  receipt=dict(kind="CONFORMANCE_FIXTURE_PIN_V2", pin_status="INDEPENDENTLY_PINNED_FOR_NATIVE_CONFORMANCE", authority="READ_ONLY_CUSTODIAN_VERIFICATION", domain=DOMAIN, evidence_scope=SCOPE, control_hash=ctx.control_hash, fixture_id=fixture_id, run_id=f["run_id"], group_id=f["group_id"], side=f["side"], volume=f["volume"], S0=f["S0"], start_msc=f["start_msc"], end_msc=f["end_msc"], entry_msc=f["entry_msc"], reduction_msc=f["reduction_msc"], close_msc=f["close_msc"], development_interval=dict(start="2022-12-05T00:00:00Z",end_exclusive="2022-12-09T00:00:00Z"), execution_mode=20, optimization=False, symbol="ETHUSD.s", environment="JustMarkets-Demo2", artifacts=records)
  raw=json.dumps(receipt,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()
  (RECEIPTS/(fixture_id+".json")).write_bytes(raw)

if __name__ == "__main__": main()
