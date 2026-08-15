import unittest
import json
import tempfile
from pathlib import Path

from research_pipeline.gate1_storage_policy import Gate1StoragePolicy


class Gate1StoragePolicyTests(unittest.TestCase):
    def test_hard_floor_has_stricter_reason_than_launch_floor(self):
        decision = Gate1StoragePolicy.evaluate(
            free_bytes=15 * 1024**3,
            completed_run_ids=[],
            archived_run_ids=[],
        )

        self.assertEqual("HARD_STOP_DISK_BELOW_16_GB", decision["action"])
        self.assertFalse(decision["launch_allowed"])

    def test_launch_is_blocked_below_thirty_gigabytes(self):
        decision = Gate1StoragePolicy.evaluate(
            free_bytes=29 * 1024**3,
            completed_run_ids=[f"G1-{number:04d}" for number in range(66)],
            archived_run_ids=[f"G1-{number:04d}" for number in range(66)],
        )

        self.assertEqual("BLOCK_RESEARCH_LOW_DISK", decision["action"])
        self.assertFalse(decision["launch_allowed"])

    def test_thirty_unarchived_runs_require_archival_before_launch(self):
        completed = [f"G1-{number:04d}" for number in range(66)]
        archived = [f"G1-{number:04d}" for number in range(36)]

        decision = Gate1StoragePolicy.evaluate(
            free_bytes=60 * 1024**3,
            completed_run_ids=completed,
            archived_run_ids=archived,
        )

        self.assertEqual("ARCHIVE_REQUIRED", decision["action"])
        self.assertFalse(decision["launch_allowed"])
        self.assertEqual(30, decision["unarchived_count"])

    def test_exactly_forty_five_gigabytes_requires_archival(self):
        decision = Gate1StoragePolicy.evaluate(
            free_bytes=45 * 1024**3,
            completed_run_ids=["G1-0000"],
            archived_run_ids=["G1-0000"],
        )

        self.assertEqual("ARCHIVE_REQUIRED", decision["action"])
        self.assertFalse(decision["launch_allowed"])

    def test_launch_is_allowed_above_thresholds_with_fewer_than_thirty_spools(self):
        completed = [f"G1-{number:04d}" for number in range(66)]
        archived = [f"G1-{number:04d}" for number in range(37)]

        decision = Gate1StoragePolicy.evaluate(
            free_bytes=46 * 1024**3,
            completed_run_ids=completed,
            archived_run_ids=archived,
        )

        self.assertEqual("ALLOW_RESEARCH", decision["action"])
        self.assertTrue(decision["launch_allowed"])
        self.assertEqual(29, decision["unarchived_count"])

    def test_contradictory_archive_inventory_fails_closed(self):
        decision = Gate1StoragePolicy.evaluate(
            free_bytes=60 * 1024**3,
            completed_run_ids=["G1-0000"],
            archived_run_ids=["G1-0000", "G1-0001"],
        )

        self.assertEqual("BLOCK_STORAGE_STATE_INVALID", decision["action"])
        self.assertFalse(decision["launch_allowed"])

    def test_workspace_inspection_derives_completed_and_archived_inventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            workspace = Path(temporary)
            children = workspace / "governance/evidence/stage14/gate1_execution_20260809_v2/children"
            archives = workspace / "archives"
            for number in range(31):
                run_id = f"G1-{number:04d}"
                child = children / run_id
                child.mkdir(parents=True)
                (child / "COMPLETE.json").write_text(
                    json.dumps({"status": "COMPLETE", "run_id": run_id}),
                    encoding="utf-8",
                )
            archives.mkdir()
            (archives / "G1-0000_HASH.ARCHIVED.json").write_text(
                json.dumps({"status": "ARCHIVED_VERIFIED", "run_id": "G1-0000"}),
                encoding="utf-8",
            )

            decision = Gate1StoragePolicy.inspect_workspace(
                workspace=workspace,
                archive_root=archives,
                free_bytes=60 * 1024**3,
            )

        self.assertEqual("ARCHIVE_REQUIRED", decision["action"])
        self.assertEqual(30, decision["unarchived_count"])
        self.assertEqual("G1-0001", decision["first_unarchived"])
        self.assertEqual("G1-0030", decision["last_unarchived"])

    def test_managed_launcher_checks_storage_before_frozen_launcher(self):
        workspace = Path(__file__).resolve().parents[1]
        source = (workspace / "operations/Start-Gate1ManagedBatch.ps1").read_text(
            encoding="utf-8"
        )

        check = "research_pipeline.gate1_storage_cli"
        launch = "Start-Gate1ManualBatch.ps1"
        self.assertLess(source.index(check), source.index(launch))
        self.assertIn("STORAGE_POLICY_BLOCKED", source)
        self.assertIn("ARCHIVE_MAINTENANCE_ACTIVE", source)
        self.assertNotRegex(source, r"Start-Job|Register-ScheduledTask|New-Service")


if __name__ == "__main__":
    unittest.main()
