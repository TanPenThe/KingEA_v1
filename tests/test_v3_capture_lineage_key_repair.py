"""Focused proofs for lineage-scoped immutable V3 capture persistence."""
import hashlib
import json
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
EA = ROOT / "MQL5/Experts/KingEA/GuardedResearchTester.mq5"
REVIEW = ROOT / "governance/review/v3_capture_lineage_key_repair_20260926"
PRE_INTEGRATION = REVIEW / "inputs/pre_source/GuardedNativeCostIntegration.mqh"
PRE_PROTECTED = REVIEW / "inputs/pre_source"
RUNTIME_REFERENCE = REVIEW / "inputs/runtime_reference"
RUN_ID = "C666040B2B67CB6C5B62BC73193104F84F99731AD695DF250B9E3B17D5D60F2F"
GROUP = "NCV1-GROUP-LONG-NORMAL-001"
CONTROL = "70AEEFCD26FF7CD381B37399C57018B61AA52321B56DD46BF1E9FD549D499949"
OLD_KEY = "391B9C952747365B42B39C26C8B0DEC8C20A0422D0E0A7082821C680BC82D2F8"
OLD_TARGET = f"NATIVE_COST_0_{OLD_KEY}.evidence"
HISTORICAL_TARGET_SHA = "55349EB65FA04A71A0CD452B890BB51ED95F75D18ED6A4C4CA1A62C3F5C8A452"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def capture_name(group: str, control: str) -> str:
    return "V3_CAPTURE_" + sha256(group.encode("utf-8")) + "_" + control


def evidence_key(name: str) -> str:
    return sha256(name.encode("utf-8"))


def persist_model(directory: Path, configuration: int, name: str, payload: bytes) -> tuple[bool, Path]:
    path = directory / f"NATIVE_COST_{configuration}_{evidence_key(name)}.evidence"
    if path.exists():
        return path.read_bytes() == payload, path
    path.write_bytes(payload)
    return True, path


def mql_function(source: str, name: str) -> str:
    match = re.search(r"\b(?:bool|void|double|int|string|datetime|long)\s+" + re.escape(name) + r"\s*\([^;{}]*\)\s*\{", source)
    if not match:
        raise AssertionError(f"MQL function not found: {name}")
    start = match.end()
    depth = 1
    index = start
    while depth:
        depth += (source[index] == "{") - (source[index] == "}")
        index += 1
    return source[start:index - 1]


class V3CaptureLineageKeyRepair(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = INTEGRATION.read_text(encoding="utf-8")
        cls.before = PRE_INTEGRATION.read_text(encoding="utf-8")
        cls.persist = mql_function(cls.source, "ResearchNativePersist")
        cls.old_persist = mql_function(cls.before, "ResearchNativePersist")
        cls.project = mql_function(cls.source, "ResearchNativeProject")
        cls.old_project = mql_function(cls.before, "ResearchNativeProject")

    def test_old_semantic_name_reproduces_historical_key(self):
        self.assertEqual(OLD_KEY, evidence_key("V3_CAPTURE_" + sha256(GROUP.encode("utf-8"))))

    def test_old_semantic_name_reproduces_historical_filename(self):
        name = "V3_CAPTURE_" + sha256(GROUP.encode("utf-8"))
        self.assertEqual(OLD_TARGET, f"NATIVE_COST_0_{evidence_key(name)}.evidence")

    def test_new_semantic_name_contains_current_control_identity(self):
        self.assertEqual("V3_CAPTURE_" + sha256(GROUP.encode("utf-8")) + "_" + CONTROL, capture_name(GROUP, CONTROL))

    def test_production_capture_name_uses_group_and_layer_b_control(self):
        self.assertIn('string capture_name="V3_CAPTURE_"+ResearchSha256String(g_da.group)+"_"+InpConformanceControlSha256;', self.project)
        self.assertIn("ResearchNativePersist(capture_name,capture)", self.project)

    def test_current_lineage_key_differs_from_historical_key(self):
        self.assertNotEqual(OLD_KEY, evidence_key(capture_name(GROUP, CONTROL)))

    def test_different_layer_b_controls_do_not_alias(self):
        self.assertNotEqual(evidence_key(capture_name(GROUP, CONTROL)), evidence_key(capture_name(GROUP, "A" * 64)))

    def test_same_group_and_control_key_is_deterministic(self):
        self.assertEqual(evidence_key(capture_name(GROUP, CONTROL)), evidence_key(capture_name(GROUP, CONTROL)))

    def test_same_lineage_same_payload_uses_existing_equality_branch(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertTrue(persist_model(Path(temp), 0, capture_name(GROUP, CONTROL), b"immutable capture")[0])
            self.assertTrue(persist_model(Path(temp), 0, capture_name(GROUP, CONTROL), b"immutable capture")[0])

    def test_same_lineage_conflicting_payload_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            name = capture_name(GROUP, CONTROL)
            ok, target = persist_model(Path(temp), 0, name, b"original")
            self.assertTrue(ok)
            ok, same = persist_model(Path(temp), 0, name, b"conflict")
            self.assertFalse(ok)
            self.assertEqual(target, same)
            self.assertEqual(b"original", target.read_bytes())

    def test_historical_collision_target_is_not_an_overwrite_destination(self):
        files = json.loads((REVIEW / "inputs/SPOOL_PREFLIGHT.json").read_text(encoding="utf-8"))["files"]
        item = next(x for x in files if x["relative_path"].endswith(OLD_TARGET))
        self.assertEqual(10546, item["byte_length"])
        self.assertEqual(HISTORICAL_TARGET_SHA, item["sha256"])
        new_leaf = f"NATIVE_COST_0_{evidence_key(capture_name(GROUP, CONTROL))}.evidence"
        self.assertNotEqual(OLD_TARGET, new_leaf)

    def test_capture_semantic_name_has_no_random_time_or_guid_suffix(self):
        name_line = next(line for line in self.project.splitlines() if "string capture_name=" in line)
        self.assertRegex(name_line, r'capture_name="V3_CAPTURE_"\+ResearchSha256String\(g_da\.group\)\+"_"\+InpConformanceControlSha256;')
        for token in ("TimeLocal", "GetTickCount", "MathRand", "GUID", "UUID", "TimeCurrent"):
            self.assertNotIn(token, name_line)
    def test_persistence_hashes_the_full_semantic_name_to_sha256(self):
        self.assertIn("string evidence_key=ResearchSha256String(name);", self.persist)
        self.assertIn('(string)InpConfigurationId+"_"+evidence_key+".evidence"', self.persist)
        self.assertRegex(evidence_key(capture_name(GROUP, CONTROL)), r"^[0-9A-F]{64}$")

    def test_physical_filename_shape_remains_fixed_width(self):
        leaf = f"NATIVE_COST_0_{evidence_key(capture_name(GROUP, CONTROL))}.evidence"
        self.assertEqual(87, len(leaf))

    def test_repaired_path_bound_remains_173_relative_and_237_effective(self):
        relative = f"KingEA\\stage14_spool\\{RUN_ID}\\NATIVE_COST_0_{evidence_key(capture_name(GROUP, CONTROL))}.evidence"
        effective = "C:\\Users\\tpent\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files\\" + relative
        self.assertEqual(173, len(relative))
        self.assertEqual(237, len(effective))

    def test_v3_capture_payload_and_projection_body_are_unchanged(self):
        repaired = self.project.replace(
            ' string capture_name="V3_CAPTURE_"+ResearchSha256String(g_da.group)+"_"+InpConformanceControlSha256;\n'
            ' if(!ResearchNativePersist(capture_name,capture))',
            ' if(!ResearchNativePersist("V3_CAPTURE_"+ResearchSha256String(g_da.group),capture))', 1)
        self.assertEqual(self.old_project, repaired)

    def test_order_check_json_serialization_remains_unchanged(self):
        self.assertEqual(mql_function(self.before, "ResearchNativeOrderCheck"), mql_function(self.source, "ResearchNativeOrderCheck"))
        self.assertIn('"ORDER_CHECK"', mql_function(self.source, "ResearchNativeOrderCheck"))

    def test_stage13_commit_keeps_quoted_eight_decimal_values(self):
        self.assertIn("string DAAccountingNumber(double n){return DAQuote(DoubleToString(n,8));}", self.source)
        self.assertIn('"base_before\\":"+DAAccountingNumber(base_before)', self.source)
        self.assertIn('"base_after\\":"+DAAccountingNumber(g_da_base)', self.source)
    def test_valid_history_add_only_policy_is_unchanged(self):
        self.assertEqual(self.old_project, self.project.replace(
            ' string capture_name="V3_CAPTURE_"+ResearchSha256String(g_da.group)+"_"+InpConformanceControlSha256;\n'
            ' if(!ResearchNativePersist(capture_name,capture))',
            ' if(!ResearchNativePersist("V3_CAPTURE_"+ResearchSha256String(g_da.group),capture))', 1))
        self.assertIn("g_da.Commit()", self.project)

    def test_observability_marker_count_remains_32(self):
        source = EA.read_text(encoding="utf-8") + "\n" + self.source
        self.assertEqual(32, len(set(re.findall(r'"(OBS_[A-Z0-9_]+)"', source))))

    def test_persistence_last_error_capture_remains_adjacent(self):
        self.assertRegex(self.persist, r"ResetLastError\(\);\s*int h=FileOpen\(file,FILE_WRITE\|FILE_TXT\|FILE_ANSI\|FILE_COMMON\);\s*int write_open_error=GetLastError\(\);")

    def test_persistence_lasterror_pair_has_no_observer_interposition(self):
        match = re.search(r"ResetLastError\(\)(.*?)GetLastError\(\)", self.persist, re.S)
        self.assertIsNotNone(match)
        self.assertNotIn("ResearchConformanceObserve", match.group(1))

    def test_ordercheck_lasterror_pair_has_no_observer_interposition(self):
        all_source = EA.read_text(encoding="utf-8") + "\n" + self.source
        regions = list(re.finditer(r"ResetLastError\(\)(.*?)GetLastError\(\)", all_source, re.S))
        self.assertEqual(2, len(regions))
        order = [m.group(1) for m in regions if "OrderCheck(r,c)" in m.group(1)]
        self.assertEqual(1, len(order))
        self.assertNotIn("ResearchConformanceObserve", order[0])

    def test_decision_a_evidence_source_remains_pre_edit_identical(self):
        self.assertEqual((PRE_PROTECTED / "research_pipeline__decision_a_evidence.py").read_bytes(), (ROOT / "research_pipeline/decision_a_evidence.py").read_bytes())

    def test_decision_a_deal_adapter_remains_pre_edit_identical(self):
        self.assertEqual((PRE_PROTECTED / "MQL5__Include__KingEA__DecisionADealAdapter.mqh").read_bytes(), (ROOT / "MQL5/Include/KingEA/DecisionADealAdapter.mqh").read_bytes())

    def test_decision_a_lifecycle_remains_pre_edit_identical(self):
        self.assertEqual((PRE_PROTECTED / "MQL5__Include__KingEA__DecisionALifecycle.mqh").read_bytes(), (ROOT / "MQL5/Include/KingEA/DecisionALifecycle.mqh").read_bytes())

    def test_guarded_research_tester_remains_pre_edit_identical(self):
        self.assertEqual((PRE_PROTECTED / "MQL5__Experts__KingEA__GuardedResearchTester.mq5").read_bytes(), EA.read_bytes())

    def test_verifier_source_remains_pre_edit_identical(self):
        self.assertEqual((PRE_PROTECTED / "research_pipeline__native_conformance_control.py").read_bytes(), (ROOT / "research_pipeline/native_conformance_control.py").read_bytes())

    def test_historical_runtime_final_result_remains_original_bytes(self):
        source = ROOT / "governance/review/order_check_stage13_serialization_repair_long_runtime_review_bundle_20260926/FINAL_RESULT.json"
        self.assertEqual((RUNTIME_REFERENCE / "FINAL_RESULT.json").read_bytes(), source.read_bytes())

    def test_research_native_persist_function_is_byte_identical(self):
        self.assertEqual(self.old_persist, self.persist)


if __name__ == "__main__":
    unittest.main()