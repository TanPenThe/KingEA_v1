import copy
import json
import hashlib
import math
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CANDIDATE = ROOT / "governance" / "candidates" / "CAND-ETH-ST-001_DRAFT.json"
FREEZE = ROOT / "governance" / "candidates" / "CAND-ETH-ST-001_FREEZE.json"
SOURCE = ROOT / "MQL5" / "Include" / "KingEA" / "CandidateEthSt001.mqh"


class CandidateDraftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.candidate = json.loads(CANDIDATE.read_text(encoding="utf-8"))
        cls.source = SOURCE.read_text(encoding="utf-8")

    def test_candidate_is_draft_and_performance_remains_locked(self):
        self.assertEqual(self.candidate["status"], "DRAFT")
        self.assertFalse(self.candidate["performance_authorized"])
        self.assertEqual(self.candidate["candidate_budget"]["family_max"], 3)
        self.assertEqual(self.candidate["candidate_budget"]["consumed"], 0)

    def test_grid_has_exactly_eight_parameters_and_19440_combinations(self):
        parameters = self.candidate["strategy"]["tunable_parameters"]
        self.assertEqual(len(parameters), 8)
        combinations = math.prod(len(parameter["grid"]) for parameter in parameters)
        self.assertEqual(combinations, 19440)
        self.assertEqual(self.candidate["strategy"]["maximum_grid_combinations"], combinations)

    def test_partitions_are_half_open_and_holdout_does_not_count_toward_150(self):
        validation = self.candidate["validation"]
        self.assertEqual(len(validation["rolling_folds"]), 4)
        self.assertEqual(
            validation["rolling_folds"][-1]["test"]["end_exclusive"],
            validation["formal_oos"]["start_inclusive"],
        )
        self.assertFalse(validation["untouched_holdout"]["counts_toward_150"])
        self.assertEqual(validation["minimum_stitched_oos_trade_groups"], 150)

    def test_signal_module_has_no_risk_sizing_or_trading_capability(self):
        prohibited = (
            "OrderSend",
            "OrderSendAsync",
            "CTrade",
            "PositionOpen",
            "OrderCalcMargin",
            "OrderCalcProfit",
            "MqlTick.flags",
        )
        for token in prohibited:
            self.assertNotIn(token, self.source)
        self.assertIn("struct KingEASignalIntent", self.source)
        self.assertIn("technical_stop", self.source)
        self.assertIn("exit_intent", self.source)
        actual_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest().upper()
        self.assertEqual(
            self.candidate["source_and_configuration"]["signal_source_sha256"],
            actual_hash,
        )

    def test_configuration_and_data_manifest_hashes_are_finalized(self):
        binding = self.candidate["source_and_configuration"]
        manifest_path = ROOT / binding["data_manifest"]
        self.assertTrue(manifest_path.is_file())
        self.assertEqual(
            hashlib.sha256(manifest_path.read_bytes()).hexdigest().upper(),
            binding["data_manifest_sha256"],
        )
        canonical = copy.deepcopy(self.candidate)
        canonical["source_and_configuration"]["configuration_sha256"] = ""
        payload = json.dumps(
            canonical, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        self.assertEqual(
            hashlib.sha256(payload).hexdigest().upper(),
            binding["configuration_sha256"],
        )

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        containment_note = manifest["final_manifest_gate"][
            "applicable_month_window_definition"
        ]
        self.assertIn("does not imply containment", containment_note)
        flag_check = manifest["derived_reduced_dataset"]["platform_flag_rule"][
            "normalization_sanity_check"
        ]
        self.assertEqual(flag_check["full_population_changed_ticks"], 272867308)
        self.assertEqual(flag_check["full_population_percent"], 83.339228)
        self.assertEqual(flag_check["diagnostic_sha256"], (
            "ABEC9F5A82BA40B171ECD54AAEFF4EDD9665A5B9F97CBB7E3DFD7C45A5251B46"
        ))

    def test_freeze_certificate_binds_the_exact_owner_approved_artifacts(self):
        certificate = json.loads(FREEZE.read_text(encoding="utf-8"))
        self.assertEqual(certificate["status"], "FROZEN")
        self.assertEqual(
            certificate["approved_configuration_sha256"],
            "A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE",
        )
        self.assertEqual(
            certificate["draft_artifact_sha256"],
            hashlib.sha256(CANDIDATE.read_bytes()).hexdigest().upper(),
        )
        self.assertFalse(certificate["authorization"]["performance_testing"])
        self.assertTrue(certificate["authorization"]["safety_kernel_implementation"])


if __name__ == "__main__":
    unittest.main()
