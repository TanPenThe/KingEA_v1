import copy
import json
import unittest
from pathlib import Path

from research_pipeline.gate1_build_continuation import (
    BuildContinuationError,
    Gate1BuildContinuation,
)
from research_pipeline.gate1_manual_batch import Gate1BatchError, Gate1ManualBatch


class Gate1BuildContinuationTests(unittest.TestCase):
    def setUp(self):
        self.workspace = Path(__file__).resolve().parents[1]
        evidence = self.workspace / "governance" / "evidence" / "stage14"
        self.prior_root = json.loads(
            (evidence / "gate1_replacement_20260809" / "GATE1_ROOT.json").read_text()
        )
        self.parity_result = json.loads(
            (
                evidence
                / "gate1_build_transition_20260823_v2"
                / "PARITY_RESULT.json"
            ).read_text()
        )
        self.completed = [f"G1-{number:04d}" for number in range(120)]
        self.inventory_sha256 = "A" * 64

    def test_passed_parity_prepares_a_continuation_at_g1_0120(self):
        continuation = Gate1BuildContinuation()
        prepared = continuation.prepare(
            prior_root=self.prior_root,
            parity_result=self.parity_result,
            completed_run_ids=self.completed,
            completed_evidence_inventory_sha256=self.inventory_sha256,
            continuation_pre_tooling_sha256="B" * 64,
        )

        root = prepared["root"]
        self.assertEqual(root["mt5_build"], 6140)
        self.assertEqual(root["candidate_budget_before"], 1)
        self.assertEqual(root["candidate_budget_transition"], "ALREADY_CONSUMED")
        self.assertEqual(root["build_transition"]["resume_run_id"], "G1-0120")
        self.assertEqual(root["build_transition"]["accepted_completed_count"], 120)
        self.assertEqual(root["build_transition"]["parity_result_sha256"], self.parity_result["result_sha256"])
        self.assertEqual(root["build_transition"]["continuation_pre_tooling_sha256"], "B" * 64)
        self.assertEqual(len(prepared["children"]), 200)
        self.assertEqual(prepared["children"][120]["run_id"], "G1-0120")
        self.assertEqual(prepared["children"][120]["mt5_build"], 6140)
        self.assertFalse(prepared["approval_packet"]["owner_approved"])

    def test_failed_or_changed_parity_cannot_create_a_continuation(self):
        continuation = Gate1BuildContinuation()
        altered = copy.deepcopy(self.parity_result)
        altered["status"] = "FAIL"
        altered["result_sha256"] = continuation.canonical_hash(
            {key: value for key, value in altered.items() if key != "result_sha256"}
        )
        with self.assertRaisesRegex(BuildContinuationError, "PARITY_RESULT_NOT_ACCEPTABLE"):
            continuation.prepare(
                prior_root=self.prior_root,
                parity_result=altered,
                completed_run_ids=self.completed,
                completed_evidence_inventory_sha256=self.inventory_sha256,
                continuation_pre_tooling_sha256="B" * 64,
            )

    def test_approved_continuation_plans_only_after_the_accepted_prefix(self):
        package = (
            self.workspace
            / "governance"
            / "evidence"
            / "stage14"
            / "gate1_continuation_20260824_v2"
        )
        root = json.loads((package / "GATE1_ROOT.json").read_text())
        index = json.loads((package / "CHILD_INDEX.json").read_text())
        statement = json.loads((package / "OWNER_APPROVAL_PACKET.json").read_text())[
            "required_owner_statement"
        ]
        approval = {
            "owner_approved": True,
            "gate": 1,
            "root_sha256": root["root_sha256"],
            "owner_statement": statement,
            "oos_authorized": False,
            "holdout_authorized": False,
        }
        plan = Gate1ManualBatch(self.workspace).plan(
            root,
            index,
            approval,
            completed_run_ids=self.completed,
        )
        self.assertEqual(plan["run_ids"], ["G1-0120", "G1-0121"])
        with self.assertRaisesRegex(
            Gate1BatchError, "BUILD_CONTINUATION_PREFIX_INCOMPLETE"
        ):
            Gate1ManualBatch(self.workspace).plan(
                root,
                index,
                approval,
                completed_run_ids=self.completed[:-1],
            )


if __name__ == "__main__":
    unittest.main()
