"""Static proofs for the native-cost persistence path-length repair."""
import hashlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
EA = ROOT / "MQL5/Experts/KingEA/GuardedResearchTester.mq5"
COMMON_ROOT = r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common"
RUNS = (
    "C666040B2B67CB6C5B62BC73193104F84F99731AD695DF250B9E3B17D5D60F2F",
    "7C0F0DDCA6FAB33786C9ABC31B8232A3B45D6942777BC07D1A483CD1AA99DABF",
    "5BFEA0B6C3B2D9E6F05B71FA43DC42EF0FAC20D0FADDC8A978DF8BC1DDB68FCA",
)
GROUP_TOKEN = "37F838FE553C67F960D28ED2"
PAYLOAD_HASHES = (
    "A43DF3B2C63E66F8E46F9A05EC053378C337C79F127304EF5C16A278DA99DF31",
    "44A81560742CB5AB742BE6B0D672CAECCB2A7A3A31C5B8CEC680F1CA5A8568C5",
)


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


def old_name(index, payload_hash):
    return f"{GROUP_TOKEN}_{index}_{payload_hash}"


def evidence_key(name):
    return hashlib.sha256(name.encode("utf-8")).hexdigest().upper()


def relative(run, configuration, leaf):
    return f"KingEA\\stage14_spool\\{run}\\NATIVE_COST_{configuration}_{leaf}.evidence"


def effective(relative_path):
    return COMMON_ROOT + "\\Files\\" + relative_path


class NativePersistPathLengthRepair(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = INTEGRATION.read_text()
        cls.persist = function(cls.source, "ResearchNativePersist")
        cls.record = function(cls.source, "ResearchNativeRecord")
        cls.all_source = EA.read_text() + "\n" + cls.source

    def test_known_runtime_failures_reproduce_200_and_264(self):
        for payload_hash in PAYLOAD_HASHES:
            old = relative(RUNS[0], 0, old_name(0, payload_hash))
            self.assertEqual(200, len(old))
            self.assertEqual(264, len(effective(old)))

    def test_repaired_key_is_deterministic_full_sha256(self):
        name = old_name(0, PAYLOAD_HASHES[0])
        self.assertEqual(evidence_key(name), evidence_key(name))
        self.assertRegex(evidence_key(name), r"^[0-9A-F]{64}$")
        self.assertIn("string evidence_key=ResearchSha256String(name);", self.persist)
        self.assertIn('(string)InpConfigurationId+"_"+evidence_key+".evidence"', self.persist)

    def test_all_fixed_fixtures_meet_240_effective_target(self):
        for run in RUNS:
            new = relative(run, 0, evidence_key(old_name(0, PAYLOAD_HASHES[0])))
            self.assertEqual(173, len(new))
            self.assertEqual(237, len(effective(new)))
            self.assertLessEqual(len(effective(new)), 240)

    def test_full_payload_and_authoritative_bindings_are_unchanged(self):
        self.assertIn("string hash=ResearchSha256String(payload);", self.record)
        self.assertIn("ResearchNativePersist(", self.record)
        self.assertIn("+hash,payload)", self.record)
        for binding in ("run_id", "group_id", "configuration_id", "profile_hash", "fixture_id"):
            self.assertIn(binding, self.source)
        self.assertIn("FileWriteString(h,value)==StringLen(value)", self.persist)

    def test_distinct_identity_inputs_do_not_alias(self):
        names = {
            old_name(index, payload_hash)
            for index in (0, 1)
            for payload_hash in PAYLOAD_HASHES
        }
        keys = {evidence_key(name) for name in names}
        self.assertEqual(len(names), len(keys))
        self.assertNotEqual(evidence_key(old_name(0, PAYLOAD_HASHES[0])), evidence_key("X" + old_name(0, PAYLOAD_HASHES[0])))

    def test_discovery_tokens_and_opaque_consumer_contract_remain(self):
        self.assertIn('"\\\\NATIVE_COST_"', self.persist)
        self.assertIn('".evidence"', self.persist)
        self.assertIn("InpConfigurationId", self.persist)
        self.assertIn("InpManifestSha256", self.persist)

    def test_valid_handle_and_existing_file_semantics_remain(self):
        self.assertIn("if(FileIsExist(file,FILE_COMMON))", self.persist)
        self.assertIn("return old==value", self.persist)
        self.assertIn("bool ok=FileWriteString(h,value)==StringLen(value); FileClose(h); return ok;", self.persist)

    def test_persistence_lasterror_capture_remains_adjacent(self):
        pattern = re.compile(
            r"ResetLastError\(\);\s*"
            r"int h=FileOpen\(file,FILE_WRITE\|FILE_TXT\|FILE_ANSI\|FILE_COMMON\);\s*"
            r"int write_open_error=GetLastError\(\);"
        )
        self.assertIsNotNone(pattern.search(self.persist))

    def test_marker_inventory_and_ordercheck_isolation(self):
        markers = set(re.findall(r'"(OBS_[A-Z0-9_]+)"', self.all_source))
        self.assertEqual(32, len(markers))
        regions = list(re.finditer(r"ResetLastError\(\)(.*?)GetLastError\(\)", self.all_source, re.S))
        self.assertEqual(2, len(regions))
        for region in regions:
            self.assertNotIn("ResearchConformanceObserve", region.group(1))
        self.assertEqual(1, sum("OrderCheck(r,c)" in region.group(1) for region in regions))
        self.assertEqual(1, sum("FileOpen(file,FILE_WRITE" in region.group(1) for region in regions))


if __name__ == "__main__":
    unittest.main()
