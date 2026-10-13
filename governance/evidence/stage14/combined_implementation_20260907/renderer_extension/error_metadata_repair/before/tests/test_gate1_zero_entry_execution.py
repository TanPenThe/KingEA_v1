import json
import tempfile
import unittest
from pathlib import Path

from research_pipeline.gate1_zero_entry_execution import Gate1ZeroEntryExecution


class Gate1ZeroEntryExecutionTests(unittest.TestCase):
    def test_plans_two_development_only_virtual_children(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            reference = {
                "artifact_hashes": {"calendar": "A" * 64, "cost": "B" * 64, "research_specification": "C" * 64},
                "account_fingerprint": "D" * 64,
                "mt5_build": 6140,
                "operational_facts": {"calendar_intervals_file": "KingEA\\research_inputs\\PROTECTION.csv", "calendar_file_sha256": "A" * 64, "commission_per_lot_round_turn": 0.0, "swap_per_lot_stress": 1.0, "weekend_risk_multiplier": 0.5, "maintenance_entry_block_minutes": 30, "maintenance_force_flat_minutes": 5, "maintenance_clean_minutes": 15},
            }
            plan = Gate1ZeroEntryExecution().build_plan(reference, root)
            self.assertEqual({"RECORDED", "RSB3"}, {child["branch"] for child in plan["children"]})
            for child in plan["children"]:
                self.assertFalse(child["orders_authorized"])
                self.assertFalse(child["returns_authorized"])
                self.assertEqual("VIRTUAL", child["execution_adapter"])
                self.assertEqual(7168, child["configuration_id"])
                self.assertTrue(child["authorization_token"])

    def test_rendered_bundle_never_enables_native_execution_or_optimization(self):
        reference = {
            "artifact_hashes": {"calendar": "A" * 64, "cost": "B" * 64, "research_specification": "C" * 64},
            "account_fingerprint": "D" * 64,
            "mt5_build": 6140,
            "operational_facts": {"calendar_intervals_file": "KingEA\\research_inputs\\PROTECTION.csv", "calendar_file_sha256": "A" * 64, "commission_per_lot_round_turn": 0.0, "swap_per_lot_stress": 1.0, "weekend_risk_multiplier": 0.5, "maintenance_entry_block_minutes": 30, "maintenance_force_flat_minutes": 5, "maintenance_clean_minutes": 15},
        }
        with tempfile.TemporaryDirectory() as raw:
            child = Gate1ZeroEntryExecution().build_plan(reference, Path(raw))["children"][0]
        bundle = Gate1ZeroEntryExecution().render_bundle(child)
        self.assertIn("Optimization=0", bundle["ini"])
        self.assertIn("InpZeroEntryDiagnostic=true", bundle["set"])
        self.assertIn("InpExecutionAdapter=VIRTUAL", bundle["set"])
        self.assertNotIn("InpExecutionAdapter=NATIVE", bundle["set"])
        self.assertIn("InpConfigurationId=7168", bundle["set"])
        self.assertNotIn("||", bundle["set"])


if __name__ == "__main__":
    unittest.main()
