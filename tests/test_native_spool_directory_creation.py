"""Static and deterministic model proofs for native spool directory creation."""
import hashlib
import re
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
EA = ROOT / "MQL5/Experts/KingEA/GuardedResearchTester.mq5"
BEFORE = ROOT / "governance/review/repaired_conformance_native_spool_directory_creation_20260920/before/GuardedNativeCostIntegration.mqh"
RUN = "C" * 64


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


def model_persist(root, run_id, configuration, name, payload, create_ok=True):
    folder = root / "KingEA" / "stage14_spool" / run_id
    if create_ok:
        folder.mkdir(parents=True, exist_ok=True)
    evidence_key = hashlib.sha256(name.encode("utf-8")).hexdigest().upper()
    path = folder / f"NATIVE_COST_{configuration}_{evidence_key}.evidence"
    if path.exists():
        return path.read_bytes() == payload, path
    try:
        path.write_bytes(payload)
    except OSError:
        return False, path
    return True, path


class NativeSpoolDirectoryCreation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.current = INTEGRATION.read_text()
        cls.before = BEFORE.read_text()
        cls.persist = function(cls.current, "ResearchNativePersist")
        cls.old_persist = function(cls.before, "ResearchNativePersist")

    def test_missing_parent_is_created_before_first_persistence_open(self):
        ordered = ('string folder="KingEA\\\\stage14_spool\\\\"+InpManifestSha256;',
                   "FolderCreate(folder,FILE_COMMON);", "string evidence_key=ResearchSha256String(name);",
                   'string file=folder+"\\\\NATIVE_COST_"',
                   "FileIsExist(file,FILE_COMMON)", "FileOpen(file,FILE_WRITE")
        positions = [self.persist.index(token) for token in ordered]
        self.assertEqual(positions, sorted(positions))
        with tempfile.TemporaryDirectory() as temp:
            ok, path = model_persist(Path(temp), RUN, 0, "ORIGINAL", b"payload")
            self.assertTrue(ok)
            self.assertTrue(path.is_file())

    def test_existing_directory_preserves_write_behavior(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp) / "KingEA" / "stage14_spool" / RUN
            folder.mkdir(parents=True)
            ok, path = model_persist(Path(temp), RUN, 7, "ORIGINAL", b"payload")
            self.assertTrue(ok)
            self.assertEqual(b"payload", path.read_bytes())

    def test_directory_creation_failure_remains_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            blocker = Path(temp) / "KingEA"
            blocker.write_bytes(b"not-a-directory")
            ok, path = model_persist(Path(temp), RUN, 0, "ORIGINAL", b"payload", create_ok=False)
            self.assertFalse(ok)
            self.assertFalse(path.exists())
        record = function(self.current, "ResearchNativeRecord")
        self.assertIn('g_da.Invalidate("NATIVE_EVIDENCE_PERSIST_FAILED")', record)
        self.assertIn("return false", record)

    def test_no_alternate_or_configurable_root(self):
        self.assertEqual(1, self.persist.count('"KingEA\\\\stage14_spool\\\\"'))
        for forbidden in ("MQLInfoString", "Environment", "InpRunManifest", "InpCalendarIntervalsFile"):
            self.assertNotIn(forbidden, self.persist)
        self.assertIn("+InpManifestSha256", self.persist)
        self.assertEqual(1, self.persist.count("TerminalInfoString(TERMINAL_COMMONDATA_PATH)"))
        self.assertGreater(self.persist.index("TerminalInfoString"), self.persist.index("if(h==INVALID_HANDLE)"))
        path_construction = self.persist[:self.persist.index("if(FileIsExist")]
        self.assertNotIn("TerminalInfoString", path_construction)

    def test_conflicting_existing_evidence_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            ok, path = model_persist(Path(temp), RUN, 0, "ORIGINAL", b"first")
            self.assertTrue(ok)
            ok, same = model_persist(Path(temp), RUN, 0, "ORIGINAL", b"conflict")
            self.assertFalse(ok)
            self.assertEqual(path, same)
            self.assertEqual(b"first", path.read_bytes())
        self.assertLess(self.persist.index("FileIsExist"), self.persist.index("FileOpen(file,FILE_WRITE"))

    def test_matching_existing_evidence_retains_equality_behavior(self):
        with tempfile.TemporaryDirectory() as temp:
            self.assertTrue(model_persist(Path(temp), RUN, 0, "ORIGINAL", b"same")[0])
            self.assertTrue(model_persist(Path(temp), RUN, 0, "ORIGINAL", b"same")[0])
        self.assertIn("return old==value", self.persist)

    def test_payload_and_filename_contract_unchanged(self):
        repaired = self.persist.replace(
            'string evidence_key=ResearchSha256String(name);\n   ',
            '',
        ).replace(
            '(string)InpConfigurationId+"_"+evidence_key+".evidence";',
            '(string)InpConfigurationId+"_"+name+".evidence";',
        ).replace(
            'string folder="KingEA\\\\stage14_spool\\\\"+InpManifestSha256;\n   FolderCreate(folder,FILE_COMMON);\n   string file=folder+"\\\\NATIVE_COST_"+',
            'string file="KingEA\\\\stage14_spool\\\\"+InpManifestSha256+"\\\\NATIVE_COST_"+',
        )
        repaired = repaired.replace(
            'ResetLastError();\n   int h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);\n'
            '   int write_open_error=GetLastError();\n   if(h==INVALID_HANDLE)\n     {\n'
            '      string common_root=TerminalInfoString(TERMINAL_COMMONDATA_PATH);\n'
            '      PrintFormat("KINGEA_NATIVE_PERSIST_WRITE_OPEN_FAIL|error_code=%d|handle=%d|relative_path=%s|relative_path_length=%d|manifest_sha256=%s|configuration_id=%d|terminal_common_data_root=%s",\n'
            '                  write_open_error,h,file,StringLen(file),InpManifestSha256,InpConfigurationId,common_root);\n'
            '      return false;\n     }',
            'int h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);\n   if(h==INVALID_HANDLE) return false;',
        )
        self.assertEqual(self.old_persist, repaired)
        self.assertIn("FileWriteString(h,value)==StringLen(value)", self.persist)

    def test_creation_cannot_affect_authorization_or_trading_predicates(self):
        self.assertNotIn("FolderCreate", function(self.current, "ResearchConformanceValid"))
        self.assertNotIn("FolderCreate", function(self.current, "ResearchActiveNativeContext"))
        self.assertNotIn("FolderCreate", function(EA.read_text(), "ResearchOrderSend"))
        self.assertEqual(function(self.current, "ResearchNativeBegin"), function(self.before, "ResearchNativeBegin"))
        self.assertEqual(function(self.current, "ResearchNativeRecord"), function(self.before, "ResearchNativeRecord"))

    def test_readback_cannot_import_trading_state(self):
        read_branch = self.persist[self.persist.index("if(FileIsExist"):self.persist.index("int h=FileOpen")]
        self.assertIn("return old==value", read_branch)
        for forbidden in ("g_da.", "g_position", "OrderSend", "Position", "authorization", "configuration"):
            self.assertNotIn(forbidden, read_branch)

    def test_lasterror_candidate_and_marker_contracts_unchanged(self):
        all_source = EA.read_text() + "\n" + self.current
        for match in re.finditer(r"ResetLastError\(\)(.*?)GetLastError\(\)", all_source, re.S):
            self.assertNotIn("ResearchConformanceObserve", match.group(1))
            self.assertNotIn("FolderCreate", match.group(1))
        markers = set(re.findall(r'"(OBS_[A-Z0-9_]+)"', all_source))
        self.assertEqual(32, len(markers))
        self.assertRegex(function(EA.read_text(), "OnTick"), r"if\(InpNativeConformance\)\{ResearchConformanceTick\(tick\);return;\}")
        self.assertEqual("8800F008D306347139845E3C0A7FF24D156174ECD22934D32E0484E7B79A11D7", hashlib.sha256(BEFORE.read_bytes()).hexdigest().upper())


if __name__ == "__main__":
    unittest.main()
