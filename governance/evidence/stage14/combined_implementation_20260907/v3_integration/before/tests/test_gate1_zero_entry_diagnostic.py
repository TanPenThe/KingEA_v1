import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from research_pipeline.gate1_zero_entry_diagnostic import (
    Gate1ZeroEntryDiagnostic,
    Gate1ZeroEntryDiagnosticError,
)


def canonical_hash(value: dict) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest().upper()


class Gate1ZeroEntryDiagnosticTests(unittest.TestCase):
    def root(self, directory: Path) -> Path:
        value = {
            "schema": 1,
            "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_ROOT",
            "candidate_id": "CAND-ETH-ST-001",
            "configuration_id": 7168,
            "owner_approved": False,
            "orders_authorized": False,
            "oos_authorized": False,
            "holdout_authorized": False,
            "children": [
                {"diagnostic": "SYNTHETIC_TREND", "branch": "SYNTHETIC", "partition": "NONE"},
                {"diagnostic": "FOLD_1_TRAIN_RECORDED", "branch": "RECORDED", "partition": "FOLD_1_TRAIN"},
                {"diagnostic": "FOLD_1_TRAIN_RSB3", "branch": "RSB3", "partition": "FOLD_1_TRAIN"},
            ],
        }
        value["root_sha256"] = canonical_hash(value)
        path = directory / "DIAGNOSTIC_ROOT.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_prepare_is_append_only_and_preserves_non_order_boundaries(self):
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            root = self.root(directory)
            output = directory / "prepared"
            controller = Gate1ZeroEntryDiagnostic(allow_test_fixture=True)
            first = controller.prepare(root, output)
            repeated = controller.prepare(root, output)

            self.assertEqual("PLANNED", first["status"])
            self.assertEqual(3, len(first["children"]))
            self.assertEqual(first, repeated)
            for child in first["children"]:
                self.assertFalse(child["owner_approved"])
                self.assertFalse(child["orders_authorized"])
                self.assertFalse(child["returns_authorized"])
            self.assertTrue((output / "PREPARED_ROOT.json").is_file())

    def test_rejects_tampered_root_and_non_diagnostic_frame(self):
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            root = self.root(directory)
            value = json.loads(root.read_text(encoding="utf-8"))
            value["configuration_id"] = 0
            root.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaisesRegex(Gate1ZeroEntryDiagnosticError, "ROOT_HASH_MISMATCH"):
                Gate1ZeroEntryDiagnostic(allow_test_fixture=True).prepare(root, directory / "prepared")

        with self.assertRaisesRegex(Gate1ZeroEntryDiagnosticError, "FRAME_RETURNS_FORBIDDEN"):
            Gate1ZeroEntryDiagnostic().parse_frame(
                "schema=1|kind=GATE1_ZERO_ENTRY_DIAGNOSTIC|returns=0.1|native_order_calls=0|complete=1"
            )

    def test_synthetic_pass_and_historical_gap_are_classified_without_rejection(self):
        controller = Gate1ZeroEntryDiagnostic()
        synthetic = controller.parse_frame(
            "schema=1|kind=GATE1_ZERO_ENTRY_DIAGNOSTIC|source=SYNTHETIC|config=7168|"
            "closed_bars=1|regime_healthy=1|regime_entry_eligible=1|sleeve_healthy=1|"
            "breakout_intents=1|safety_approvals=1|safety_rejections=0|virtual_order_attempts=1|"
            "virtual_fills=1|virtual_execution_failures=0|accounting_completions=1|native_order_calls=0|"
            "first_zero_stage=0|returns=ABSENT|complete=1"
        )
        historical = controller.parse_frame(
            "schema=1|kind=GATE1_ZERO_ENTRY_DIAGNOSTIC|source=RECORDED|config=7168|"
            "closed_bars=4320|regime_healthy=0|regime_entry_eligible=0|sleeve_healthy=0|"
            "breakout_intents=0|safety_approvals=0|safety_rejections=0|virtual_order_attempts=0|"
            "virtual_fills=0|virtual_execution_failures=0|accounting_completions=0|native_order_calls=0|"
            "first_zero_stage=2|regime_reasons=4:4320|returns=ABSENT|complete=1"
        )
        result = controller.classify(synthetic, [historical, {**historical, "source": "RSB3"}])

        self.assertEqual("QUARANTINED_PENDING_DIAGNOSTIC", result["status"])
        self.assertEqual("REGIME_HEALTH", result["earliest_failed_stage"])
        self.assertFalse(result["candidate_rejected"])

    def test_non_matching_historical_funnels_remain_inconclusive(self):
        controller = Gate1ZeroEntryDiagnostic()
        synthetic = {"source": "SYNTHETIC", "first_zero_stage": 0}
        result = controller.classify(
            synthetic,
            [
                {"source": "RECORDED", "first_zero_stage": 2},
                {"source": "RSB3", "first_zero_stage": 5},
            ],
        )
        self.assertEqual("QUARANTINED_PENDING_DIAGNOSTIC", result["status"])
        self.assertEqual("INCONCLUSIVE", result["earliest_failed_stage"])


if __name__ == "__main__":
    unittest.main()
