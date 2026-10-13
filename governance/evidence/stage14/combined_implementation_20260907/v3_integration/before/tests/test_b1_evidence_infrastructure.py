"""Synthetic, non-candidate contract tests for Gate B1 evidence retention."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from research_pipeline.b1_evidence_infrastructure import (
    B1EvidenceCoordinator,
    B1EvidenceError,
    B1EvidenceRequest,
    B1ExternalEvidenceCoordinator,
    B1ExternalEvidenceRequest,
)


class B1EvidenceInfrastructureTests(unittest.TestCase):
    def _external_fixture(self, root: Path) -> B1ExternalEvidenceRequest:
        inputs = root / "external-inputs"
        source = inputs / "source" / "B1SyntheticNoOrder.mq5"
        executable = inputs / "build" / "B1SyntheticNoOrder.ex5"
        settings = inputs / "launch" / "B1SyntheticNoOrder.set"
        ini = inputs / "launch" / "B1SyntheticNoOrder.ini"
        compile_log = inputs / "build" / "compile.log"
        journals = (inputs / "runtime" / "terminal.log", inputs / "runtime" / "tester.log", inputs / "runtime" / "agent-1.log")
        telemetry = inputs / "runtime" / "telemetry.json"
        result = inputs / "runtime" / "result.json"
        for path, content in {
            source: "// harmless synthetic no-order EA\n",
            executable: "synthetic compiled bytes\n",
            settings: "SyntheticOnly=true\n",
            ini: "[Tester]\nExpert=KingEA\\B1SyntheticNoOrder.ex5\n",
            compile_log: "Result: 0 errors, 0 warnings\n",
            journals[0]: "RUN=B1-SYNTHETIC-REAL-0001 START PID=4242\nRUN=B1-SYNTHETIC-REAL-0001 END EXIT=0\n",
            journals[1]: "RUN=B1-SYNTHETIC-REAL-0001 tester start/end\n",
            journals[2]: "RUN=B1-SYNTHETIC-REAL-0001 agent=local-1\n",
            telemetry: json.dumps({
                "kind": "B1_NON_CANDIDATE_FUNNEL_TELEMETRY_V2", "run_id": "B1-SYNTHETIC-REAL-0001",
                "tick": {"valid": 2, "invalid": 0, "bucket_transitions": 1},
                "bars": {"appended": 1, "faults": 0},
                "regime": {"evaluations": 1, "healthy": 1, "blocked": 0, "reason_counts": {}},
                "breakout": {"evaluated": 1, "intents": 1, "blocked": 0},
                "sleeve": {"evaluations": 1, "entry_intents": 1, "exit_intents": 1, "blocked": 0},
                "safety": {"evaluations": 2, "approved": 1, "rejected": 1},
                "routing": {"attempts": 1, "accepted": 1, "no_order_proof": 1},
                "accounting": {"submissions": 1, "completed": 1, "faults": 0},
            }, sort_keys=True),
            result: json.dumps({"kind": "B1_NON_CANDIDATE_RESULT_V2", "run_id": "B1-SYNTHETIC-REAL-0001", "status": "COMPLETE", "native_orders": 0}),
        }.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        source_entry = {"relative_path": "Experts/KingEA/B1SyntheticNoOrder.mq5", "sha256": B1EvidenceCoordinator.file_hash(source)}
        source_manifest = inputs / "build" / "source-manifest.json"
        source_manifest.write_text(json.dumps({"kind": "B1_SOURCE_EX5_BINDING", "git_commit": "a" * 40, "compiler": {"path": "C:/Synthetic/metaeditor64.exe", "version": "5.0.0.6140", "build": 6140, "compile_started_at": "2026-09-04T00:00:00Z", "compile_ended_at": "2026-09-04T00:00:00Z", "compile_command": ["C:/Synthetic/metaeditor64.exe", "/compile:synthetic", "/log:synthetic"], "return_code": 0, "compile_log_sha256": B1EvidenceCoordinator.file_hash(compile_log), "ex5_preexisting": False, "produced_ex5_sha256": B1EvidenceCoordinator.file_hash(executable)}, "sources": [source_entry], "source_tree_sha256": B1EvidenceCoordinator.canonical_hash([source_entry]), "ex5_sha256": B1EvidenceCoordinator.file_hash(executable)}, sort_keys=True), encoding="utf-8")
        authorization = inputs / "launch" / "authorization.json"
        authorization.write_text(json.dumps({"kind": "B1_AUTHORIZATION", "run_id": "B1-SYNTHETIC-REAL-0001", "owner_authorized": True, "candidate_execution": False, "native_orders": False, "candidate_budget_consumption": False, "oos_access": False, "holdout_access": False}), encoding="utf-8")
        run_manifest = inputs / "launch" / "run-manifest.json"
        run_manifest.write_text(json.dumps({"kind": "B1_RUN_MANIFEST", "run_id": "B1-SYNTHETIC-REAL-0001", "scope": "B1_NON_CANDIDATE_SYNTHETIC_ONLY", "authorization_sha256": B1EvidenceCoordinator.file_hash(authorization), "source_tree_sha256": json.loads(source_manifest.read_text())["source_tree_sha256"], "ex5_sha256": B1EvidenceCoordinator.file_hash(executable), "set_sha256": B1EvidenceCoordinator.file_hash(settings), "ini_sha256": B1EvidenceCoordinator.file_hash(ini), "launch_command": ["C:/Synthetic/terminal64.exe", f"/config:{ini}"], "terminal_scope": {"local_only": True, "remote_agents": False, "cloud_agents": False, "terminal_path": "C:/Synthetic/terminal64.exe", "terminal_version": "5.0.0.6140", "terminal_build": 6140, "compiler_version": "5.0.0.6140", "compiler_build": 6140}, "controls": {"candidate_execution": False, "native_orders": False, "candidate_budget_consumption": False, "oos_access": False, "holdout_access": False}}, sort_keys=True), encoding="utf-8")
        receipt = inputs / "launch" / "launch-receipt.json"
        receipt_body = {"kind": "B1_GOVERNED_LAUNCH_RECEIPT", "producer": "B1_GOVERNED_LAUNCHER", "run_id": "B1-SYNTHETIC-REAL-0001", "manifest_sha256": B1EvidenceCoordinator.file_hash(run_manifest), "authorization_sha256": B1EvidenceCoordinator.file_hash(authorization), "source_tree_sha256": json.loads(source_manifest.read_text())["source_tree_sha256"], "ex5_sha256": B1EvidenceCoordinator.file_hash(executable), "set_sha256": B1EvidenceCoordinator.file_hash(settings), "ini_sha256": B1EvidenceCoordinator.file_hash(ini), "launcher_sha256": "C" * 64, "launch_command": ["C:/Synthetic/terminal64.exe", f"/config:{ini}"], "terminal_executable": "terminal64.exe", "terminal_path": "C:/Synthetic/terminal64.exe", "terminal_version": "5.0.0.6140", "terminal_build": 6140, "compiler_version": "5.0.0.6140", "compiler_build": 6140, "process_id": 4242, "agent_ids": ["local-1"], "launch_timestamp": "2026-09-04T00:00:01Z"}
        receipt_body["receipt_sha256"] = B1EvidenceCoordinator.canonical_hash(receipt_body)
        receipt.write_text(json.dumps(receipt_body, sort_keys=True), encoding="utf-8")
        runtime_proof = inputs / "runtime" / "runtime-proof.json"
        runtime_proof.write_text(json.dumps({"kind": "B1_RUNTIME_PROOF", "run_id": "B1-SYNTHETIC-REAL-0001", "process_id": 4242, "agent_ids": ["local-1"], "started_at": "2026-09-04T00:00:01Z", "ended_at": "2026-09-04T00:00:02Z", "exit_code": 0, "terminal_journal_sha256": B1EvidenceCoordinator.file_hash(journals[0]), "tester_journal_sha256": B1EvidenceCoordinator.file_hash(journals[1]), "agent_journal_sha256": B1EvidenceCoordinator.file_hash(journals[2]), "run_correlated": True}), encoding="utf-8")
        return B1ExternalEvidenceRequest("B1-SYNTHETIC-REAL-0001", run_manifest, source_manifest, compile_log, executable, settings, ini, authorization, receipt, runtime_proof, journals, telemetry, result, root / "external-sealed")

    def test_external_receipt_and_sealed_only_verification_survive_working_file_removal(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._external_fixture(Path(temp))
            coordinator = B1ExternalEvidenceCoordinator()
            sealed = coordinator.seal(request)
            for artifact in request.output.parent.glob("external-inputs/**/*"):
                if artifact.is_file():
                    artifact.unlink()
            verified = coordinator.verify_sealed(request.output)
            self.assertEqual("PASS", sealed["status"])
            self.assertEqual("PASS", verified["status"])
            self.assertEqual("NO_QUARANTINE", verified["funnel_verdict"])

    def test_sealed_external_receipt_tampering_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._external_fixture(Path(temp))
            coordinator = B1ExternalEvidenceCoordinator()
            coordinator.seal(request)
            retained = request.output / "retained" / "launch_receipt" / "000_launch-receipt.json"
            receipt = json.loads(retained.read_text(encoding="utf-8"))
            receipt["process_id"] = 7
            retained.write_text(json.dumps(receipt, sort_keys=True), encoding="utf-8")
            with self.assertRaisesRegex(B1EvidenceError, "SEALED_ARTIFACT_HASH_MISMATCH"):
                coordinator.verify_sealed(request.output)

    def test_external_cross_binding_failures_are_fail_closed(self) -> None:
        mutations = (
            ("run-manifest.json", "source_tree_sha256", "0" * 64, "B1_RUN_MANIFEST_BINDING_MISMATCH"),
            ("authorization.json", "run_id", "B1-SYNTHETIC-WRONG", "B1_RUN_MANIFEST_BINDING_MISMATCH"),
            ("runtime-proof.json", "process_id", 7, "RUNTIME_PROOF_IDENTITY_INVALID"),
            ("runtime-proof.json", "terminal_journal_sha256", "0" * 64, "RUNTIME_PROOF_JOURNAL_BINDING_INVALID"),
            ("runtime-proof.json", "started_at", "2026-09-04T00:00:03Z", "RUNTIME_PROOF_TIMESTAMP_INCONSISTENT"),
        )
        for filename, key, value, reason in mutations:
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as temp:
                request = self._external_fixture(Path(temp))
                target = request.run_manifest if filename == "run-manifest.json" else request.authorization if filename == "authorization.json" else request.runtime_proof
                payload = json.loads(target.read_text(encoding="utf-8"))
                payload[key] = value
                target.write_text(json.dumps(payload, sort_keys=True), encoding="utf-8")
                with self.assertRaisesRegex(B1EvidenceError, reason):
                    B1ExternalEvidenceCoordinator().seal(request)

    def test_build_and_command_provenance_failures_are_fail_closed(self) -> None:
        cases = (
            ("manifest", "terminal_build", 7, "EXTERNAL_LAUNCH_RECEIPT_BINDING_MISMATCH"),
            ("source", "build", 7, "EXTERNAL_LAUNCH_RECEIPT_RUNTIME_FACTS_INVALID"),
            ("receipt", "launch_command", ["C:/Synthetic/terminal64.exe", "/config:altered"], "EXTERNAL_LAUNCH_RECEIPT_RUNTIME_FACTS_INVALID"),
            ("source", "ex5_preexisting", True, "SOURCE_EX5_COMPILER_FACTS_INVALID"),
        )
        for target, key, value, reason in cases:
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as temp:
                request = self._external_fixture(Path(temp))
                path = request.run_manifest if target == "manifest" else request.launch_receipt if target == "receipt" else request.source_manifest
                payload = json.loads(path.read_text(encoding="utf-8"))
                if target == "manifest":
                    payload["terminal_scope"][key] = value
                elif target == "source":
                    payload["compiler"][key] = value
                else:
                    payload[key] = value
                    payload["receipt_sha256"] = B1EvidenceCoordinator.canonical_hash({name: item for name, item in payload.items() if name != "receipt_sha256"})
                path.write_text(json.dumps(payload, sort_keys=True), encoding="utf-8")
                with self.assertRaisesRegex(B1EvidenceError, reason):
                    B1ExternalEvidenceCoordinator().seal(request)
    def _fixture(self, root: Path) -> B1EvidenceRequest:
        source = root / "source" / "SyntheticTester.mq5"
        executable = root / "build" / "SyntheticTester.ex5"
        settings = root / "launch" / "Synthetic.set"
        ini = root / "launch" / "Synthetic.ini"
        runtime = root / "runtime" / "terminal.log"
        telemetry = root / "runtime" / "telemetry.json"
        result = root / "results" / "result.json"
        for path, content in {
            source: "// non-candidate synthetic tester\n",
            executable: "synthetic-ex5-bytes\n",
            settings: "SyntheticOnly=true\n",
            ini: "[Tester]\nExpert=SyntheticTester.ex5\n",
            runtime: "synthetic process start\nsynthetic process end\n",
            telemetry: json.dumps(
                {
                    "kind": "SYNTHETIC_NON_CANDIDATE_FUNNEL",
                    "valid_ticks": 100,
                    "m30_closes": 10,
                    "regime_evaluations": 10,
                    "sleeve_evaluations": 10,
                    "entry_intents": 1,
                    "exit_intents": 1,
                    "safety_evaluations": 2,
                    "safety_approvals": 1,
                    "route_attempts": 1,
                    "fills": 1,
                    "accounting_submissions": 1,
                },
                sort_keys=True,
            ),
            result: json.dumps({"kind": "SYNTHETIC_NON_CANDIDATE_RESULT", "complete": True}),
        }.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        return B1EvidenceRequest(
            run_id="B1-SYNTHETIC-0001",
            source_files=(source,),
            executable=executable,
            settings=settings,
            ini=ini,
            runtime_journals=(runtime,),
            telemetry=telemetry,
            result=result,
            output=root / "evidence",
        )

    def test_seals_and_verifies_non_candidate_chain(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._fixture(Path(temp))
            coordinator = B1EvidenceCoordinator()
            sealed = coordinator.seal(request)
            verified = coordinator.verify(request)
            self.assertEqual("PASS", sealed["status"])
            self.assertEqual("PASS", verified["status"])
            self.assertEqual("NO_QUARANTINE", verified["funnel_verdict"])
            self.assertTrue(sealed["retained_artifacts"])
            for artifact in sealed["retained_artifacts"]:
                retained = request.output / artifact["path"]
                self.assertTrue(retained.is_file())
                self.assertEqual(artifact["sha256"], coordinator.file_hash(retained))

    def test_altered_or_missing_artifacts_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._fixture(Path(temp))
            coordinator = B1EvidenceCoordinator()
            coordinator.seal(request)
            request.settings.write_text("SyntheticOnly=false\n", encoding="utf-8")
            with self.assertRaisesRegex(B1EvidenceError, "ARTIFACT_CHAIN_MISMATCH"):
                coordinator.verify(request)
            request.settings.unlink()
            with self.assertRaisesRegex(B1EvidenceError, "ARTIFACT_MISSING"):
                coordinator.verify(request)

    def test_tampered_launch_receipt_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._fixture(Path(temp))
            coordinator = B1EvidenceCoordinator()
            coordinator.seal(request)
            receipt = request.output / coordinator.RECEIPT_NAME
            value = json.loads(receipt.read_text(encoding="utf-8"))
            value["set_sha256"] = "0" * 64
            receipt.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
            with self.assertRaisesRegex(B1EvidenceError, "RECEIPT_HASH_MISMATCH"):
                coordinator.verify(request)

    def test_tampered_retained_artifact_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._fixture(Path(temp))
            coordinator = B1EvidenceCoordinator()
            sealed = coordinator.seal(request)
            retained = request.output / sealed["retained_artifacts"][0]["path"]
            retained.write_text("altered retained source\n", encoding="utf-8")
            with self.assertRaisesRegex(B1EvidenceError, "RETAINED_ARTIFACT_HASH_MISMATCH"):
                coordinator.verify(request)

    def test_global_zero_and_funnel_discontinuities_quarantine_before_selection(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._fixture(Path(temp))
            telemetry = json.loads(request.telemetry.read_text(encoding="utf-8"))
            telemetry.update(
                {
                    "entry_intents": 0,
                    "exit_intents": 0,
                    "m30_closes": 0,
                }
            )
            request.telemetry.write_text(json.dumps(telemetry, sort_keys=True), encoding="utf-8")
            verified = B1EvidenceCoordinator().seal(request)
            self.assertEqual("QUARANTINE_BEFORE_SELECTION", verified["funnel_verdict"])
            self.assertEqual(
                {
                    "GLOBAL_ZERO_ENTRIES",
                    "GLOBAL_ZERO_EXITS",
                    "VALID_TICKS_WITHOUT_M30_CLOSES",
                },
                set(verified["funnel_reasons"]),
            )

    def test_positive_intent_without_safety_quarantines_before_selection(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            request = self._fixture(Path(temp))
            telemetry = json.loads(request.telemetry.read_text(encoding="utf-8"))
            telemetry.update({"safety_evaluations": 0, "safety_approvals": 0, "route_attempts": 0})
            request.telemetry.write_text(json.dumps(telemetry, sort_keys=True), encoding="utf-8")
            sealed = B1EvidenceCoordinator().seal(request)
            self.assertEqual("QUARANTINE_BEFORE_SELECTION", sealed["funnel_verdict"])
            self.assertIn("INTENTS_WITHOUT_SAFETY_EVALUATIONS", sealed["funnel_reasons"])


if __name__ == "__main__":
    unittest.main()
