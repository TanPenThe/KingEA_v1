import json
import tempfile
import unittest
from pathlib import Path

from research_pipeline.gate1_evidence_archive import EvidenceArchiveError, Gate1EvidenceArchive


class Gate1EvidenceArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.execution = self.base / "execution"
        self.spools = self.base / "spools"
        self.archives = self.base / "archives"
        self.run = "G1-0001"
        self.sha = "A" * 64
        child = self.execution / "children" / self.run
        child.mkdir(parents=True)
        (child / "COMPLETE.json").write_text(json.dumps({
            "status": "COMPLETE", "run_id": self.run,
            "manifest_sha256": self.sha, "frame_count": 2,
            "spool_path": str(self.spools / self.sha),
        }), encoding="utf-8")
        spool = self.spools / self.sha
        spool.mkdir(parents=True)
        (spool / "a.frame").write_bytes(b"alpha")
        (spool / "b.frame").write_bytes(b"beta")

    def tearDown(self):
        self.temp.cleanup()

    def test_verified_archive_is_recoverable_before_loose_files_are_removed(self):
        module = Gate1EvidenceArchive(self.execution, self.spools, self.archives)
        result = module.archive_completed(self.run, remove_verified=True)
        self.assertEqual("ARCHIVED_VERIFIED", result["status"])
        self.assertEqual(2, result["file_count"])
        self.assertEqual(2, result["sample_count"])
        self.assertEqual(64, len(result["metadata_sha256"]))
        self.assertFalse((self.spools / self.sha).exists())
        restored = module.restore(self.run)
        self.assertEqual("RESTORED_VERIFIED", restored["status"])
        self.assertEqual(b"alpha", (self.spools / self.sha / "a.frame").read_bytes())

    def test_incomplete_child_cannot_use_completed_archive_path(self):
        (self.execution / "children" / self.run / "COMPLETE.json").unlink()
        module = Gate1EvidenceArchive(self.execution, self.spools, self.archives)
        with self.assertRaisesRegex(EvidenceArchiveError, "CHILD_NOT_COMPLETE"):
            module.archive_completed(self.run, remove_verified=True)

    def test_recovery_runner_requires_archival_and_disk_headroom_before_retry(self):
        source = (Path(__file__).resolve().parents[1] / "operations" /
                  "Resume-Gate1AfterStorageRecovery.ps1").read_text(encoding="utf-8")
        self.assertLess(source.index("Archive maintenance complete:"),
                        source.index("--invalidate-partial"))
        self.assertLess(source.index("$free -lt 16GB"),
                        source.index("--invalidate-partial"))
        self.assertIn("-Children 1", source)

    def test_partial_attempt_is_archived_and_invalidated_without_becoming_complete(self):
        child = self.execution / "children" / self.run
        (child / "COMPLETE.json").unlink()
        (child / "RUNNING.json").write_text(json.dumps({
            "status": "RUNNING", "run_id": self.run, "manifest_sha256": self.sha
        }), encoding="utf-8")
        module = Gate1EvidenceArchive(self.execution, self.spools, self.archives)
        result = module.invalidate_partial(
            self.run, reason="TEST_DISK_EXHAUSTION", last_configuration_id=1
        )
        self.assertEqual("INVALIDATED_INFRASTRUCTURE", result["status"])
        self.assertFalse((self.spools / self.sha).exists())
        self.assertTrue((child / "INVALIDATED_INFRASTRUCTURE.json").is_file())
        self.assertFalse((child / "COMPLETE.json").exists())
        batch = self.execution / "batches" / "BATCH-0000-0001"
        batch.mkdir(parents=True)
        (batch / "PLAN.json").write_text("{}", encoding="utf-8")
        moved = module.prepare_retry(
            self.run, batch_id="BATCH-0000-0001", attempt_id="TEST-ATTEMPT-1"
        )
        self.assertEqual("RETRY_PREPARED", moved["status"])
        self.assertFalse(child.exists())
        self.assertTrue(Path(moved["preserved_child_path"]).is_dir())
        self.assertTrue((batch / "INVALIDATED_INFRASTRUCTURE.json").is_file())


if __name__ == "__main__":
    unittest.main()
