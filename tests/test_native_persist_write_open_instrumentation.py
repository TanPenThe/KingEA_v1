"""Static proofs for isolated native persistence write-open diagnostics."""
import hashlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
EA = ROOT / "MQL5/Experts/KingEA/GuardedResearchTester.mq5"
BEFORE = ROOT / "governance/review/native_persist_write_open_error_instrumentation_20260921/before/GuardedNativeCostIntegration.mqh"


def function(text, name):
    match = re.search(r"\b(?:bool|void|double|int|string|datetime|long)\s+" + re.escape(name) + r"\s*\([^;{}]*\)\s*\{", text)
    if not match:
        raise AssertionError(name)
    start = match.end()
    depth = 1
    index = start
    while depth:
        depth += (text[index] == "{") - (text[index] == "}")
        index += 1
    return text[start:index - 1]


class NativePersistWriteOpenInstrumentation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.current = INTEGRATION.read_text()
        cls.before = BEFORE.read_text()
        cls.persist = function(cls.current, "ResearchNativePersist")
        cls.old_persist = function(cls.before, "ResearchNativePersist")
        cls.all_source = EA.read_text() + "\n" + cls.current

    def test_capture_interval_is_exact_and_isolated(self):
        pattern = re.compile(
            r"ResetLastError\(\);\s*"
            r"int h=FileOpen\(file,FILE_WRITE\|FILE_TXT\|FILE_ANSI\|FILE_COMMON\);\s*"
            r"int write_open_error=GetLastError\(\);"
        )
        match = pattern.search(self.persist)
        self.assertIsNotNone(match)
        interval = match.group(0)
        self.assertEqual(1, interval.count("ResetLastError()"))
        self.assertEqual(1, interval.count("FileOpen("))
        self.assertEqual(1, interval.count("GetLastError()"))
        calls = re.findall(r"\b[A-Za-z_]\w*\s*\(", interval)
        self.assertEqual(["ResetLastError(", "FileOpen(", "GetLastError("], calls)

    def test_invalid_handle_still_returns_false_after_journal_record(self):
        branch = self.persist[self.persist.index("if(h==INVALID_HANDLE)"):self.persist.index("bool ok=FileWriteString")]
        self.assertIn("KINGEA_NATIVE_PERSIST_WRITE_OPEN_FAIL", branch)
        self.assertIn("write_open_error", branch)
        self.assertIn("return false;", branch)
        self.assertNotIn("GetLastError", branch)

    def test_diagnostic_fields_and_journal_only_output(self):
        branch = self.persist[self.persist.index("if(h==INVALID_HANDLE)"):self.persist.index("bool ok=FileWriteString")]
        for field in ("error_code=%d", "handle=%d", "relative_path=%s", "relative_path_length=%d",
                      "manifest_sha256=%s", "configuration_id=%d", "terminal_common_data_root=%s"):
            self.assertIn(field, branch)
        self.assertIn("PrintFormat", branch)
        for forbidden in ("FileOpen", "FileWrite", "ResearchConformanceObserve", "OBS_"):
            self.assertNotIn(forbidden, branch)

    def test_valid_handle_write_behavior_is_byte_for_byte_unchanged(self):
        suffix = "bool ok=FileWriteString(h,value)==StringLen(value); FileClose(h); return ok;"
        self.assertIn(suffix, self.persist)
        self.assertIn(suffix, self.old_persist)

    def test_instrumentation_does_not_control_persistence_result(self):
        self.assertEqual(2, self.persist.count("write_open_error"))
        self.assertNotRegex(self.persist, r"if\s*\([^)]*write_open_error")
        self.assertNotRegex(self.persist, r"return\s+write_open_error")
        self.assertRegex(self.persist, r"if\(h==INVALID_HANDLE\)[\s\S]*?return false;")

    def test_path_construction_is_exactly_unchanged(self):
        historical_path_lines = (
            'string folder="KingEA\\\\stage14_spool\\\\"+InpManifestSha256;\n'
            '   FolderCreate(folder,FILE_COMMON);\n'
            '   string file=folder+"\\\\NATIVE_COST_"+\n'
            '      (string)InpConfigurationId+"_"+name+".evidence";'
        )
        repaired_path_lines = (
            'string folder="KingEA\\\\stage14_spool\\\\"+InpManifestSha256;\n'
            '   FolderCreate(folder,FILE_COMMON);\n'
            '   string evidence_key=ResearchSha256String(name);\n'
            '   string file=folder+"\\\\NATIVE_COST_"+\n'
            '      (string)InpConfigurationId+"_"+evidence_key+".evidence";'
        )
        self.assertIn(historical_path_lines, self.old_persist)
        self.assertNotIn("evidence_key", self.old_persist)
        self.assertIn(repaired_path_lines, self.persist)
        self.assertNotIn('(string)InpConfigurationId+"_"+name+".evidence"', self.persist)
        self.assertEqual(1, self.persist.count('"KingEA\\\\stage14_spool\\\\"'))
        for forbidden in ("fallback", "alternate", "MQLInfoString", "InpRunManifest"):
            self.assertNotIn(forbidden, self.persist)

    def test_observability_inventory_remains_closed_at_32(self):
        markers = set(re.findall(r'"(OBS_[A-Z0-9_]+)"', self.all_source))
        self.assertEqual(32, len(markers))
        self.assertNotIn("OBS_NATIVE_PERSIST_WRITE_OPEN_FAIL", markers)

    def test_ordercheck_and_persist_lasterror_regions_are_independent(self):
        regions = list(re.finditer(r"ResetLastError\(\)(.*?)GetLastError\(\)", self.all_source, re.S))
        self.assertEqual(2, len(regions))
        contents = [m.group(1) for m in regions]
        ordercheck = next(x for x in contents if "OrderCheck(r,c)" in x)
        persist = next(x for x in contents if "FileOpen(file,FILE_WRITE" in x)
        self.assertNotIn("FileOpen", ordercheck)
        self.assertNotIn("OrderCheck", persist)
        self.assertNotIn("ResearchConformanceObserve", ordercheck)
        self.assertNotIn("ResearchConformanceObserve", persist)

    def test_ea_candidate_routing_source_is_unchanged(self):
        self.assertEqual(
            "F57AB193489F3A61EDB63F4600680DC01DE18FDF63752EE60B06AD94CC5D6C2E",
            hashlib.sha256(EA.read_bytes()).hexdigest().upper(),
        )


if __name__ == "__main__":
    unittest.main()
