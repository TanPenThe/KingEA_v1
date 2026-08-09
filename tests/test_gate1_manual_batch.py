import json
import tempfile
import unittest
from pathlib import Path

from research_pipeline.gate1_manual_batch import Gate1BatchError, Gate1ManualBatch


class Gate1ManualBatchTests(unittest.TestCase):
    def setUp(self):
        self.workspace = Path(__file__).resolve().parents[1]
        self.package = (
            self.workspace
            / "governance"
            / "evidence"
            / "stage14"
            / "gate1_replacement_20260809"
        )
        self.root = json.loads((self.package / "GATE1_ROOT.json").read_text())
        self.index = json.loads((self.package / "CHILD_INDEX.json").read_text())
        self.approval = {
            "schema": 1,
            "kind": "GATE1_OWNER_AUTHORIZATION",
            "owner_approved": True,
            "gate": 1,
            "root_sha256": self.root["root_sha256"],
            "owner_statement": (
                "I explicitly approve replacement Gate 1 root "
                f"{self.root['root_sha256']} for exhaustive development execution "
                "after infrastructure invalidation of the prior root."
            ),
            "oos_authorized": False,
            "holdout_authorized": False,
        }

    def test_owner_can_plan_the_next_two_foreground_children(self):
        planner = Gate1ManualBatch(self.workspace)
        plan = planner.plan(self.root, self.index, self.approval, completed_run_ids=[])
        self.assertEqual(plan["run_ids"], ["G1-0000", "G1-0001"])
        self.assertEqual(plan["maximum_children"], 2)
        self.assertEqual(plan["execution_mode"], "MANUAL_FOREGROUND")
        self.assertLess(plan["projected_batch_hours"], 8.0)
        self.assertEqual(plan["hard_batch_hours"], 7.5)

    def test_batch_size_cannot_be_raised_above_two(self):
        planner = Gate1ManualBatch(self.workspace)
        with self.assertRaisesRegex(Gate1BatchError, "BATCH_CHILD_LIMIT_EXCEEDED"):
            planner.plan(
                self.root,
                self.index,
                self.approval,
                completed_run_ids=[],
                requested_children=3,
            )

    def test_resume_is_sequential_and_rejects_a_completion_gap(self):
        planner = Gate1ManualBatch(self.workspace)
        resumed = planner.plan(
            self.root,
            self.index,
            self.approval,
            completed_run_ids=["G1-0000", "G1-0001"],
        )
        self.assertEqual(resumed["run_ids"], ["G1-0002", "G1-0003"])
        with self.assertRaisesRegex(Gate1BatchError, "COMPLETION_SEQUENCE_GAP"):
            planner.plan(
                self.root,
                self.index,
                self.approval,
                completed_run_ids=["G1-0001"],
            )

    def test_wrong_root_or_owner_words_do_not_authorize_execution(self):
        planner = Gate1ManualBatch(self.workspace)
        altered = dict(self.approval)
        altered["owner_statement"] = "approved"
        with self.assertRaisesRegex(Gate1BatchError, "OWNER_STATEMENT_MISMATCH"):
            planner.plan(self.root, self.index, altered, completed_run_ids=[])
        altered = dict(self.approval)
        altered["root_sha256"] = "0" * 64
        with self.assertRaisesRegex(Gate1BatchError, "AUTHORIZATION_ROOT_MISMATCH"):
            planner.plan(self.root, self.index, altered, completed_run_ids=[])

    def test_replacement_root_must_preserve_the_consumed_candidate_budget(self):
        planner = Gate1ManualBatch(self.workspace)
        altered = json.loads(json.dumps(self.root))
        altered["candidate_budget_before"] = 0
        altered["candidate_budget_transition"] = "FIRST_VALID_RESULT_PASS"
        altered["root_sha256"] = planner.canonical_hash(
            {key: value for key, value in altered.items() if key != "root_sha256"}
        )
        prior = Gate1ManualBatch.EXACT_ROOT
        Gate1ManualBatch.EXACT_ROOT = altered["root_sha256"]
        try:
            with self.assertRaisesRegex(Gate1BatchError, "GATE1_ROOT_SCOPE_CHANGED"):
                planner.plan(altered, self.index, self.approval, completed_run_ids=[])
        finally:
            Gate1ManualBatch.EXACT_ROOT = prior

    def test_child_file_hashes_are_rechecked_before_planning(self):
        planner = Gate1ManualBatch(self.workspace)
        altered_index = json.loads(json.dumps(self.index))
        altered_index["children"][0]["file_sha256"] = "0" * 64
        altered_index["index_sha256"] = planner.canonical_hash(
            {key: value for key, value in altered_index.items() if key != "index_sha256"}
        )
        with self.assertRaisesRegex(Gate1BatchError, "CHILD_FILE_HASH_MISMATCH"):
            planner.plan(self.root, altered_index, self.approval, completed_run_ids=[])

    def test_completion_requires_every_expected_result_frame_and_no_hard_failure(self):
        planner = Gate1ManualBatch(self.workspace)
        manifest = json.loads((self.package / "children" / "G1-0199.json").read_text())
        self.assertEqual(len(manifest["expected_frame_ids"]), 440)
        with tempfile.TemporaryDirectory() as directory:
            spool = Path(directory)
            for configuration_id in manifest["configuration_ids"]:
                payload = (
                    f"config={configuration_id}|branch={manifest['branch']}|"
                    f"partition={manifest['partition']}|hard_failures=0|complete=1"
                )
                (spool / f"1_KINGEA_STAGE12_COMPLETE_{configuration_id}.frame").write_text(
                    payload, encoding="utf-8"
                )
            result = planner.verify_completion(manifest, spool)
            self.assertEqual(result["status"], "COMPLETE")
            self.assertEqual(result["frame_count"], 440)
            first = spool / f"1_KINGEA_STAGE12_COMPLETE_{manifest['configuration_start']}.frame"
            first.write_text(first.read_text().replace("hard_failures=0", "hard_failures=1"))
            with self.assertRaisesRegex(Gate1BatchError, "RESULT_FRAME_HARD_FAILURE"):
                planner.verify_completion(manifest, spool)

    def test_historical_execution_provenance_is_invalid_after_tester_repair(self):
        planner = Gate1ManualBatch(self.workspace)
        evidence = self.workspace / "governance" / "evidence" / "stage14"
        base = json.loads(
            (evidence / "PRE_TOOLING_GATE1_PREP_V3_20260808.json").read_text()
        )
        manual = json.loads(
            (evidence / "PRE_TOOLING_GATE1_MANUAL_BATCH_V7_20260809.json").read_text()
        )
        # The old root is deliberately non-resumable after the shared-read
        # repair changed GuardedResearchTester.mq5.  A replacement root must
        # bind the repaired source rather than treating it as a policy-only
        # supersession of the historical execution provenance.
        with self.assertRaisesRegex(Gate1BatchError, "UNGOVERNED_BASE_SOURCE_CHANGE"):
            planner.verify_execution_provenance(base, manual)

    def test_fresh_replacement_provenance_requires_no_supersession(self):
        planner = Gate1ManualBatch(self.workspace)
        def manifest(build_id, source_paths):
            value = {
                "schema": 1,
                "kind": "PRE_TOOLING",
                "build_id": build_id,
                "sources": [
                    {
                        "path": str(path.resolve()),
                        "size": path.stat().st_size,
                        "sha256": planner.file_hash(path),
                    }
                    for path in source_paths
                ],
                "dependency_hashes": {
                    "policy_source": planner.file_hash(
                        self.workspace / "tests" / "Test-Stage14ResearchReadinessPolicy.ps1"
                    )
                },
            }
            value["manifest_sha256"] = planner.canonical_hash(value)
            return value

        base = manifest(
            "TEST-FRESH-REPLACEMENT-BASE",
            [
                self.workspace / "MQL5" / "Experts" / "KingEA" / "GuardedResearchTester.mq5",
                self.workspace / "research_pipeline" / "stage14.py",
                self.workspace / "research_pipeline" / "stage14_cli.py",
                self.workspace / "tests" / "test_stage14_pipeline.py",
            ],
        )
        source_paths = [
            self.workspace / "research_pipeline" / "gate1_manual_batch.py",
            self.workspace / "research_pipeline" / "gate1_manual_cli.py",
            self.workspace / "operations" / "Start-Gate1ManualBatch.ps1",
            self.workspace / "tests" / "test_gate1_manual_batch.py",
        ]
        manual = manifest("TEST-FRESH-REPLACEMENT-PROVENANCE", source_paths)
        result = planner.verify_execution_provenance(base, manual)
        self.assertTrue(result["passed"])
        self.assertEqual([], result["governed_supersessions"])


if __name__ == "__main__":
    unittest.main()
