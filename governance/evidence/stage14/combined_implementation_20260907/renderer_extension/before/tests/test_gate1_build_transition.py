import json
import hashlib
import tarfile
import tempfile
import unittest
from pathlib import Path

from research_pipeline.gate1_build_transition import (
    BuildTransitionError,
    Gate1BuildTransition,
)


class Gate1BuildTransitionTests(unittest.TestCase):
    def setUp(self):
        self.workspace = Path(__file__).resolve().parents[1]
        package = (
            self.workspace
            / "governance"
            / "evidence"
            / "stage14"
            / "gate1_replacement_20260809"
        )
        self.root = json.loads((package / "GATE1_ROOT.json").read_text())
        self.index = json.loads((package / "CHILD_INDEX.json").read_text())

    def test_prepares_fixed_representative_build_parity_package(self):
        module = Gate1BuildTransition(self.workspace)
        package = module.prepare(
            prior_root=self.root,
            prior_index=self.index,
            new_build=6140,
            terminal_sha256="D" * 64,
            transition_pre_tooling_sha256="E" * 64,
        )

        self.assertEqual("GATE1_MT5_BUILD_PARITY", package["root"]["kind"])
        self.assertEqual(6090, package["root"]["prior_mt5_build"])
        self.assertEqual(6140, package["root"]["new_mt5_build"])
        self.assertEqual(
            ["G1-0000", "G1-0039", "G1-0080", "G1-0119"],
            [row["reference_run_id"] for row in package["root"]["comparisons"]],
        )
        self.assertEqual(4, len(package["children"]))
        self.assertEqual(
            package["root"]["parity_root_sha256"],
            package["index"]["parity_root_sha256"],
        )
        for child in package["children"]:
            self.assertEqual(6140, child["mt5_build"])
            self.assertEqual("DEVELOPMENT", child["purpose"])
            self.assertEqual(1, child["gate"])
            self.assertTrue(child["run_id"].startswith("BP-"))

    def test_refuses_non_forward_build_or_wrong_prior_root(self):
        module = Gate1BuildTransition(self.workspace)
        with self.assertRaisesRegex(BuildTransitionError, "NEW_BUILD_NOT_FORWARD"):
            module.prepare(
                prior_root=self.root,
                prior_index=self.index,
                new_build=6090,
                terminal_sha256="D" * 64,
                transition_pre_tooling_sha256="E" * 64,
            )
        altered = dict(self.root)
        altered["root_sha256"] = "0" * 64
        with self.assertRaisesRegex(BuildTransitionError, "PRIOR_ROOT_INVALID"):
            module.prepare(
                prior_root=altered,
                prior_index=self.index,
                new_build=6140,
                terminal_sha256="D" * 64,
                transition_pre_tooling_sha256="E" * 64,
            )

    def test_comparison_accepts_only_expected_stage13_root_rehashing(self):
        module = Gate1BuildTransition(self.workspace)
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / "reference"
            spool = base / "candidate"
            source.mkdir()
            spool.mkdir()
            payloads = {
                "0_KINGEA_STAGE12_COMPLETE_0.frame": (
                    "config=0|branch=RECORDED|partition=FOLD_1_TRAIN|"
                    "hard_failures=0|complete=1"
                ),
                "0_KINGEA_STAGE13_ACCOUNTING_COMPLETE_0.frame": (
                    "schema=1|event_count=1|ledger_net=0.0|root=OLD|complete=1"
                ),
                "0_KINGEA_STAGE13_ACCOUNTING_EVENT_1.frame": (
                    "schema=1|sequence=1|event_type=6|net=0.0|root=OLD"
                ),
            }
            for name, payload in payloads.items():
                (source / name).write_text(payload, encoding="utf-8")
                (spool / name).write_text(
                    payload.replace("root=OLD", "root=NEW"), encoding="utf-8"
                )
            archive = base / "reference.tar.gz"
            with tarfile.open(archive, "w:gz") as handle:
                for path in sorted(source.iterdir()):
                    handle.add(path, arcname=path.name)
            marker = {
                "status": "ARCHIVED_VERIFIED",
                "run_id": "G1-0000",
                "archive_path": str(archive),
                "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest().upper(),
                "file_count": 3,
            }

            result = module.compare(reference_record=marker, candidate_spool=spool)

            self.assertEqual("PASS", result["status"])
            self.assertEqual(3, result["compared_frames"])
            self.assertEqual(2, result["normalized_stage13_frames"])

            (spool / "0_KINGEA_STAGE12_COMPLETE_0.frame").write_text(
                payloads["0_KINGEA_STAGE12_COMPLETE_0.frame"].replace(
                    "complete=1", "complete=0"
                ),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                BuildTransitionError, "PARITY_SUBSTANTIVE_MISMATCH"
            ):
                module.compare(reference_record=marker, candidate_spool=spool)

    def test_foreground_wrapper_cannot_continue_gate1_or_access_later_gates(self):
        source = (
            self.workspace / "operations" / "Start-Gate1BuildParity.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn("gate1_build_transition_cli execute", source)
        self.assertNotIn("Start-Gate1ManagedBatch", source)
        self.assertNotIn("execute-oos", source.lower())
        self.assertNotIn("execute-holdout", source.lower())


if __name__ == "__main__":
    unittest.main()
