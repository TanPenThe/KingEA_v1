"""Gate B1 non-candidate evidence-chain sealing and fail-closed verification.

This module never launches MT5, compiles source, or evaluates Candidate 001.
It seals caller-supplied synthetic infrastructure artifacts and verifies their
cryptographic chain before a result archive can be accepted.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from hashlib import sha256
import json
from pathlib import Path
import shutil
from typing import Any


class B1EvidenceError(ValueError):
    """A required B1 evidence fact is absent or contradictory."""


@dataclass(frozen=True)
class B1EvidenceRequest:
    run_id: str
    source_files: tuple[Path, ...]
    executable: Path
    settings: Path
    ini: Path
    runtime_journals: tuple[Path, ...]
    telemetry: Path
    result: Path
    output: Path


class B1EvidenceCoordinator:
    """Deep non-executing seam for source-to-result evidence verification."""

    PACKET_NAME = "B1_EVIDENCE_PACKET.json"
    RECEIPT_NAME = "B1_LAUNCH_RECEIPT.json"

    @staticmethod
    def canonical_hash(value: Any) -> str:
        return sha256(
            json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        ).hexdigest().upper()

    @staticmethod
    def file_hash(path: Path) -> str:
        if not path.is_file():
            raise B1EvidenceError(f"ARTIFACT_MISSING:{path}")
        return sha256(path.read_bytes()).hexdigest().upper()

    def _source_tree(self, request: B1EvidenceRequest) -> dict[str, Any]:
        if not request.source_files:
            raise B1EvidenceError("SOURCE_TREE_EMPTY")
        entries = []
        for path in sorted(request.source_files, key=lambda item: str(item).lower()):
            entries.append({"path": str(path.resolve()), "sha256": self.file_hash(path)})
        return {"files": entries, "sha256": self.canonical_hash(entries)}

    def _funnel_verdict(self, telemetry: dict[str, Any]) -> tuple[str, list[str]]:
        required = (
            "valid_ticks", "m30_closes", "regime_evaluations", "sleeve_evaluations",
            "entry_intents", "exit_intents", "safety_evaluations", "safety_approvals",
            "route_attempts", "fills", "accounting_submissions",
        )
        if telemetry.get("kind") != "SYNTHETIC_NON_CANDIDATE_FUNNEL":
            raise B1EvidenceError("TELEMETRY_NOT_SYNTHETIC_NON_CANDIDATE")
        if any(not isinstance(telemetry.get(key), int) or telemetry[key] < 0 for key in required):
            raise B1EvidenceError("TELEMETRY_SCHEMA_INVALID")
        reasons: list[str] = []
        if telemetry["entry_intents"] == 0:
            reasons.append("GLOBAL_ZERO_ENTRIES")
        if telemetry["exit_intents"] == 0:
            reasons.append("GLOBAL_ZERO_EXITS")
        transitions = (
            ("valid_ticks", "m30_closes", "VALID_TICKS_WITHOUT_M30_CLOSES"),
            ("m30_closes", "regime_evaluations", "M30_CLOSES_WITHOUT_REGIME_EVALUATIONS"),
            ("regime_evaluations", "sleeve_evaluations", "REGIME_EVALUATIONS_WITHOUT_SLEEVE_EVALUATIONS"),
            ("entry_intents", "safety_evaluations", "INTENTS_WITHOUT_SAFETY_EVALUATIONS"),
            ("safety_approvals", "route_attempts", "SAFETY_APPROVALS_WITHOUT_ROUTE_ATTEMPTS"),
            ("fills", "accounting_submissions", "FILLS_WITHOUT_ACCOUNTING_SUBMISSIONS"),
        )
        for prior, following, reason in transitions:
            if telemetry[prior] > 0 and telemetry[following] == 0:
                reasons.append(reason)
        return ("QUARANTINE_BEFORE_SELECTION" if reasons else "NO_QUARANTINE", reasons)

    @staticmethod
    def _read_json(path: Path) -> dict[str, Any]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise B1EvidenceError(f"JSON_INVALID:{path}") from error
        if not isinstance(value, dict):
            raise B1EvidenceError(f"JSON_OBJECT_REQUIRED:{path}")
        return value

    def _packet_facts(self, request: B1EvidenceRequest) -> dict[str, Any]:
        if not request.run_id.startswith("B1-SYNTHETIC-"):
            raise B1EvidenceError("NON_CANDIDATE_RUN_ID_REQUIRED")
        source_tree = self._source_tree(request)
        telemetry = self._read_json(request.telemetry)
        verdict, reasons = self._funnel_verdict(telemetry)
        runtime = [
            {"path": str(path.resolve()), "sha256": self.file_hash(path)}
            for path in sorted(request.runtime_journals, key=lambda item: str(item).lower())
        ]
        if not runtime:
            raise B1EvidenceError("RUNTIME_JOURNALS_EMPTY")
        return {
            "schema": 1,
            "kind": "B1_SYNTHETIC_NON_CANDIDATE_EVIDENCE",
            "run_id": request.run_id,
            "source_tree": source_tree,
            "ex5_sha256": self.file_hash(request.executable),
            "set_sha256": self.file_hash(request.settings),
            "ini_sha256": self.file_hash(request.ini),
            "runtime_journals": runtime,
            "telemetry_sha256": self.file_hash(request.telemetry),
            "result_sha256": self.file_hash(request.result),
            "funnel_verdict": verdict,
            "funnel_reasons": reasons,
            "controls": {
                "candidate_execution": False,
                "candidate_budget_consumption": 0,
                "mt5_launch": False,
                "oos_access": False,
                "holdout_access": False,
                "native_orders": 0,
            },
        }

    def _write_immutable(self, path: Path, value: dict[str, Any]) -> None:
        payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
        if path.exists():
            if path.read_text(encoding="utf-8") != payload:
                raise B1EvidenceError(f"IMMUTABLE_ARTIFACT_CONFLICT:{path}")
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")

    def _retain_artifact(self, source: Path, output: Path, relative: Path) -> dict[str, str]:
        """Copy a verified input into the immutable B1 packet exactly once."""
        expected_hash = self.file_hash(source)
        retained = output / relative
        retained.parent.mkdir(parents=True, exist_ok=True)
        if retained.exists():
            if self.file_hash(retained) != expected_hash:
                raise B1EvidenceError(f"RETAINED_ARTIFACT_CONFLICT:{retained}")
        else:
            shutil.copyfile(source, retained)
            if self.file_hash(retained) != expected_hash:
                raise B1EvidenceError(f"RETAINED_ARTIFACT_COPY_MISMATCH:{retained}")
        return {"path": relative.as_posix(), "sha256": expected_hash}

    def _retain_artifacts(self, request: B1EvidenceRequest) -> list[dict[str, str]]:
        """Retain source through result before committing its receipt and packet."""
        retained: list[dict[str, str]] = []
        for index, source in enumerate(sorted(request.source_files, key=lambda item: str(item).lower())):
            retained.append(self._retain_artifact(source, request.output, Path("retained/source") / f"{index:03d}_{source.name}"))
        retained.append(self._retain_artifact(request.executable, request.output, Path("retained/ex5") / request.executable.name))
        retained.append(self._retain_artifact(request.settings, request.output, Path("retained/set") / request.settings.name))
        retained.append(self._retain_artifact(request.ini, request.output, Path("retained/ini") / request.ini.name))
        for index, journal in enumerate(sorted(request.runtime_journals, key=lambda item: str(item).lower())):
            retained.append(self._retain_artifact(journal, request.output, Path("retained/journals") / f"{index:03d}_{journal.name}"))
        retained.append(self._retain_artifact(request.telemetry, request.output, Path("retained/telemetry") / request.telemetry.name))
        retained.append(self._retain_artifact(request.result, request.output, Path("retained/result") / request.result.name))
        return retained

    def _verify_retained_artifacts(self, output: Path, artifacts: Any) -> None:
        if not isinstance(artifacts, list) or not artifacts:
            raise B1EvidenceError("RETAINED_ARTIFACTS_MISSING")
        seen: set[str] = set()
        for artifact in artifacts:
            if not isinstance(artifact, dict) or set(artifact) != {"path", "sha256"}:
                raise B1EvidenceError("RETAINED_ARTIFACT_SCHEMA_INVALID")
            relative = artifact["path"]
            if not isinstance(relative, str) or not relative.startswith("retained/") or ".." in Path(relative).parts:
                raise B1EvidenceError("RETAINED_ARTIFACT_PATH_INVALID")
            if relative in seen:
                raise B1EvidenceError("RETAINED_ARTIFACT_DUPLICATE")
            seen.add(relative)
            if self.file_hash(output / relative) != artifact["sha256"]:
                raise B1EvidenceError("RETAINED_ARTIFACT_HASH_MISMATCH")

    def seal(self, request: B1EvidenceRequest) -> dict[str, Any]:
        facts = self._packet_facts(request)
        facts["retained_artifacts"] = self._retain_artifacts(request)
        receipt = {
            "kind": "B1_SYNTHETIC_LAUNCH_RECEIPT",
            "run_id": request.run_id,
            "source_tree_sha256": facts["source_tree"]["sha256"],
            "ex5_sha256": facts["ex5_sha256"],
            "set_sha256": facts["set_sha256"],
            "ini_sha256": facts["ini_sha256"],
            "runtime_journal_hashes": [item["sha256"] for item in facts["runtime_journals"]],
            "telemetry_sha256": facts["telemetry_sha256"],
            "result_sha256": facts["result_sha256"],
        }
        receipt["receipt_sha256"] = self.canonical_hash(receipt)
        self._write_immutable(request.output / self.RECEIPT_NAME, receipt)
        packet = {**facts, "launch_receipt_sha256": receipt["receipt_sha256"]}
        packet["packet_sha256"] = self.canonical_hash(packet)
        self._write_immutable(request.output / self.PACKET_NAME, packet)
        return {"status": "PASS", **packet}

    def verify(self, request: B1EvidenceRequest) -> dict[str, Any]:
        packet = self._read_json(request.output / self.PACKET_NAME)
        receipt = self._read_json(request.output / self.RECEIPT_NAME)
        if packet.get("packet_sha256") != self.canonical_hash({key: value for key, value in packet.items() if key != "packet_sha256"}):
            raise B1EvidenceError("PACKET_HASH_MISMATCH")
        if receipt.get("receipt_sha256") != self.canonical_hash({key: value for key, value in receipt.items() if key != "receipt_sha256"}):
            raise B1EvidenceError("RECEIPT_HASH_MISMATCH")
        self._verify_retained_artifacts(request.output, packet.get("retained_artifacts"))
        facts = self._packet_facts(request)
        expected = {**facts, "launch_receipt_sha256": receipt["receipt_sha256"]}
        if {key: packet.get(key) for key in expected} != expected:
            raise B1EvidenceError("ARTIFACT_CHAIN_MISMATCH")
        receipt_expected = {
            "run_id": request.run_id,
            "source_tree_sha256": facts["source_tree"]["sha256"],
            "ex5_sha256": facts["ex5_sha256"],
            "set_sha256": facts["set_sha256"],
            "ini_sha256": facts["ini_sha256"],
            "runtime_journal_hashes": [item["sha256"] for item in facts["runtime_journals"]],
            "telemetry_sha256": facts["telemetry_sha256"],
            "result_sha256": facts["result_sha256"],
        }
        if any(receipt.get(key) != value for key, value in receipt_expected.items()):
            raise B1EvidenceError("LAUNCH_RECEIPT_BINDING_MISMATCH")
        return {"status": "PASS", **packet}


@dataclass(frozen=True)
class B1ExternalEvidenceRequest:
    """Artifacts produced by a governed launcher, never by this verifier."""

    run_id: str
    run_manifest: Path
    source_manifest: Path
    compile_log: Path
    executable: Path
    settings: Path
    ini: Path
    authorization: Path
    launch_receipt: Path
    runtime_proof: Path
    runtime_journals: tuple[Path, ...]
    telemetry: Path
    result: Path
    output: Path


class B1ExternalEvidenceCoordinator:
    """Validates and seals an externally-produced, non-candidate launch chain."""

    PACKET_NAME = "B1_EXTERNAL_EVIDENCE_PACKET.json"

    def __init__(self) -> None:
        self._common = B1EvidenceCoordinator()

    def _json(self, path: Path) -> dict[str, Any]:
        return self._common._read_json(path)

    def _hash(self, path: Path) -> str:
        return self._common.file_hash(path)

    def _canonical(self, value: Any) -> str:
        return self._common.canonical_hash(value)

    @staticmethod
    def _require_hash(value: Any, reason: str) -> str:
        if not isinstance(value, str) or len(value) != 64 or any(character not in "0123456789ABCDEF" for character in value):
            raise B1EvidenceError(reason)
        return value

    def _validate_source_manifest(self, value: dict[str, Any], executable_hash: str, compile_log_hash: str) -> None:
        if value.get("kind") != "B1_SOURCE_EX5_BINDING":
            raise B1EvidenceError("SOURCE_EX5_BINDING_KIND_INVALID")
        commit = value.get("git_commit")
        if not isinstance(commit, str) or len(commit) != 40 or any(character not in "0123456789abcdefABCDEF" for character in commit):
            raise B1EvidenceError("SOURCE_EX5_GIT_COMMIT_INVALID")
        compiler = value.get("compiler")
        required_compiler = ("path", "version", "build", "compile_started_at", "compile_ended_at", "compile_command", "return_code", "compile_log_sha256", "ex5_preexisting", "produced_ex5_sha256")
        if not isinstance(compiler, dict) or any(key not in compiler for key in required_compiler) or not isinstance(compiler.get("build"), int) or compiler["build"] <= 0 or not isinstance(compiler.get("version"), str) or not isinstance(compiler.get("compile_command"), list) or not isinstance(compiler.get("return_code"), int) or compiler.get("ex5_preexisting") is not False:
            raise B1EvidenceError("SOURCE_EX5_COMPILER_FACTS_INVALID")
        self._require_hash(compiler.get("compile_log_sha256"), "SOURCE_EX5_COMPILE_LOG_HASH_INVALID")
        if compiler.get("compile_log_sha256") != compile_log_hash:
            raise B1EvidenceError("SOURCE_EX5_COMPILE_LOG_BINDING_MISMATCH")
        if not compiler["compile_command"] or compiler["compile_command"][0] != compiler["path"]:
            raise B1EvidenceError("SOURCE_EX5_COMPILE_COMMAND_INVALID")
        try:
            compile_started = datetime.fromisoformat(compiler["compile_started_at"].replace("Z", "+00:00"))
            compile_ended = datetime.fromisoformat(compiler["compile_ended_at"].replace("Z", "+00:00"))
        except (AttributeError, ValueError) as error:
            raise B1EvidenceError("SOURCE_EX5_COMPILE_TIMESTAMP_INVALID") from error
        if compile_started > compile_ended:
            raise B1EvidenceError("SOURCE_EX5_COMPILE_TIMESTAMP_INCONSISTENT")
        if compiler.get("produced_ex5_sha256") != executable_hash:
            raise B1EvidenceError("SOURCE_EX5_FRESH_COMPILE_PROOF_INVALID")
        sources = value.get("sources")
        if not isinstance(sources, list) or not sources:
            raise B1EvidenceError("SOURCE_EX5_SOURCES_INVALID")
        normalized: list[dict[str, str]] = []
        for source in sources:
            if not isinstance(source, dict) or set(source) != {"relative_path", "sha256"}:
                raise B1EvidenceError("SOURCE_EX5_SOURCE_ENTRY_INVALID")
            relative = source["relative_path"]
            if not isinstance(relative, str) or relative.startswith(("/", "\\")) or ".." in Path(relative).parts:
                raise B1EvidenceError("SOURCE_EX5_RELATIVE_PATH_INVALID")
            normalized.append(source)
            self._require_hash(source["sha256"], "SOURCE_EX5_SOURCE_HASH_INVALID")
        if normalized != sorted(normalized, key=lambda entry: entry["relative_path"].lower()):
            raise B1EvidenceError("SOURCE_EX5_SOURCE_ORDER_INVALID")
        if value.get("source_tree_sha256") != self._canonical(normalized):
            raise B1EvidenceError("SOURCE_EX5_TREE_HASH_MISMATCH")
        if value.get("ex5_sha256") != executable_hash:
            raise B1EvidenceError("SOURCE_EX5_BINARY_HASH_MISMATCH")

    def _validate_telemetry(self, value: dict[str, Any], run_id: str) -> tuple[str, list[str]]:
        if value.get("kind") != "B1_NON_CANDIDATE_FUNNEL_TELEMETRY_V2" or value.get("run_id") != run_id:
            raise B1EvidenceError("TELEMETRY_V2_IDENTITY_INVALID")
        shapes = {
            "tick": ("valid", "invalid", "bucket_transitions"),
            "bars": ("appended", "faults"),
            "regime": ("evaluations", "healthy", "blocked"),
            "breakout": ("evaluated", "intents", "blocked"),
            "sleeve": ("evaluations", "entry_intents", "exit_intents", "blocked"),
            "safety": ("evaluations", "approved", "rejected"),
            "routing": ("attempts", "accepted", "no_order_proof"),
            "accounting": ("submissions", "completed", "faults"),
        }
        for section, counters in shapes.items():
            values = value.get(section)
            if not isinstance(values, dict) or any(not isinstance(values.get(counter), int) or values[counter] < 0 for counter in counters):
                raise B1EvidenceError(f"TELEMETRY_V2_{section.upper()}_INVALID")
        reasons = value["regime"].get("reason_counts")
        if not isinstance(reasons, dict) or any(not isinstance(key, str) or not isinstance(count, int) or count < 0 for key, count in reasons.items()):
            raise B1EvidenceError("TELEMETRY_V2_REGIME_REASONS_INVALID")
        quarantine: list[str] = []
        if value["sleeve"]["entry_intents"] == 0:
            quarantine.append("GLOBAL_ZERO_ENTRIES")
        if value["sleeve"]["exit_intents"] == 0:
            quarantine.append("GLOBAL_ZERO_EXITS")
        transitions = (
            (value["tick"]["valid"], value["bars"]["appended"], "VALID_TICKS_WITHOUT_BARS"),
            (value["bars"]["appended"], value["regime"]["evaluations"], "BARS_WITHOUT_REGIME"),
            (value["regime"]["evaluations"], value["sleeve"]["evaluations"], "REGIME_WITHOUT_SLEEVE"),
            (value["sleeve"]["entry_intents"], value["safety"]["evaluations"], "INTENTS_WITHOUT_SAFETY"),
            (value["safety"]["approved"], value["routing"]["attempts"], "SAFETY_APPROVALS_WITHOUT_ROUTING"),
            (value["routing"]["accepted"], value["accounting"]["submissions"], "ROUTING_WITHOUT_ACCOUNTING"),
        )
        quarantine.extend(reason for prior, following, reason in transitions if prior > 0 and following == 0)
        return ("QUARANTINE_BEFORE_SELECTION" if quarantine else "NO_QUARANTINE", quarantine)

    def _validate_runtime(self, proof: dict[str, Any], journals: list[dict[str, str]], run_id: str, receipt: dict[str, Any]) -> None:
        required = ("run_id", "process_id", "agent_ids", "started_at", "ended_at", "exit_code", "terminal_journal_sha256", "tester_journal_sha256", "agent_journal_sha256", "run_correlated")
        if proof.get("kind") != "B1_RUNTIME_PROOF" or any(key not in proof for key in required):
            raise B1EvidenceError("RUNTIME_PROOF_SCHEMA_INVALID")
        if proof["run_id"] != run_id or proof["process_id"] != receipt["process_id"] or proof["agent_ids"] != receipt["agent_ids"] or proof["exit_code"] != 0 or proof["run_correlated"] is not True:
            raise B1EvidenceError("RUNTIME_PROOF_IDENTITY_INVALID")
        hashes = {entry["sha256"] for entry in journals}
        if any(proof[key] not in hashes for key in ("terminal_journal_sha256", "tester_journal_sha256", "agent_journal_sha256")):
            raise B1EvidenceError("RUNTIME_PROOF_JOURNAL_BINDING_INVALID")
        if len({proof["terminal_journal_sha256"], proof["tester_journal_sha256"], proof["agent_journal_sha256"]}) != 3:
            raise B1EvidenceError("RUNTIME_PROOF_JOURNALS_NOT_DISTINCT")
        try:
            started = datetime.fromisoformat(proof["started_at"].replace("Z", "+00:00"))
            ended = datetime.fromisoformat(proof["ended_at"].replace("Z", "+00:00"))
            launched = datetime.fromisoformat(receipt["launch_timestamp"].replace("Z", "+00:00"))
        except (AttributeError, ValueError) as error:
            raise B1EvidenceError("RUNTIME_PROOF_TIMESTAMP_INVALID") from error
        if started > launched or launched > ended:
            raise B1EvidenceError("RUNTIME_PROOF_TIMESTAMP_INCONSISTENT")

    def _validate_authorization(self, authorization: dict[str, Any], run_id: str) -> None:
        if authorization.get("kind") != "B1_AUTHORIZATION" or authorization.get("run_id") != run_id or authorization.get("owner_authorized") is not True or authorization.get("candidate_execution") is not False or authorization.get("native_orders") is not False or authorization.get("oos_access") is not False or authorization.get("holdout_access") is not False or authorization.get("candidate_budget_consumption") not in (False, 0):
            raise B1EvidenceError("EXTERNAL_AUTHORIZATION_SCOPE_INVALID")

    def _validate_run_manifest(self, manifest: dict[str, Any], request: B1ExternalEvidenceRequest, source: dict[str, Any]) -> None:
        required = ("run_id", "scope", "authorization_sha256", "source_tree_sha256", "ex5_sha256", "set_sha256", "ini_sha256", "launch_command", "terminal_scope", "controls")
        if manifest.get("kind") != "B1_RUN_MANIFEST" or any(key not in manifest for key in required):
            raise B1EvidenceError("B1_RUN_MANIFEST_SCHEMA_INVALID")
        if manifest["run_id"] != request.run_id or manifest["scope"] != "B1_NON_CANDIDATE_SYNTHETIC_ONLY" or not isinstance(manifest["launch_command"], list) or len(manifest["launch_command"]) < 2:
            raise B1EvidenceError("B1_RUN_MANIFEST_SCOPE_INVALID")
        expected = {"authorization_sha256": self._hash(request.authorization), "source_tree_sha256": source["source_tree_sha256"], "ex5_sha256": self._hash(request.executable), "set_sha256": self._hash(request.settings), "ini_sha256": self._hash(request.ini)}
        if any(manifest.get(key) != value for key, value in expected.items()):
            raise B1EvidenceError("B1_RUN_MANIFEST_BINDING_MISMATCH")
        controls = manifest["controls"]
        if not isinstance(controls, dict) or any(controls.get(key) is not False for key in ("candidate_execution", "native_orders", "candidate_budget_consumption", "oos_access", "holdout_access")):
            raise B1EvidenceError("B1_RUN_MANIFEST_CONTROLS_INVALID")
        if not isinstance(manifest["terminal_scope"], dict) or manifest["terminal_scope"].get("local_only") is not True or manifest["terminal_scope"].get("remote_agents") is not False or manifest["terminal_scope"].get("cloud_agents") is not False or not isinstance(manifest["terminal_scope"].get("terminal_version"), str) or not isinstance(manifest["terminal_scope"].get("terminal_build"), int) or manifest["terminal_scope"]["terminal_build"] <= 0 or not isinstance(manifest["terminal_scope"].get("compiler_version"), str) or not isinstance(manifest["terminal_scope"].get("compiler_build"), int) or manifest["terminal_scope"]["compiler_build"] <= 0:
            raise B1EvidenceError("B1_RUN_MANIFEST_TERMINAL_SCOPE_INVALID")

    def _validate_receipt(self, receipt: dict[str, Any], request: B1ExternalEvidenceRequest, source: dict[str, Any], manifest: dict[str, Any]) -> None:
        required = ("run_id", "manifest_sha256", "authorization_sha256", "source_tree_sha256", "ex5_sha256", "set_sha256", "ini_sha256", "launcher_sha256", "launch_command", "terminal_executable", "terminal_path", "terminal_version", "terminal_build", "compiler_version", "compiler_build", "process_id", "agent_ids", "launch_timestamp")
        if receipt.get("kind") != "B1_GOVERNED_LAUNCH_RECEIPT" or receipt.get("producer") != "B1_GOVERNED_LAUNCHER" or any(key not in receipt for key in required):
            raise B1EvidenceError("EXTERNAL_LAUNCH_RECEIPT_SCHEMA_INVALID")
        if receipt.get("receipt_sha256") != self._canonical({key: value for key, value in receipt.items() if key != "receipt_sha256"}):
            raise B1EvidenceError("EXTERNAL_LAUNCH_RECEIPT_HASH_MISMATCH")
        expected = {"run_id": request.run_id, "manifest_sha256": self._hash(request.run_manifest), "authorization_sha256": self._hash(request.authorization), "source_tree_sha256": source["source_tree_sha256"], "ex5_sha256": self._hash(request.executable), "set_sha256": self._hash(request.settings), "ini_sha256": self._hash(request.ini)}
        if any(receipt.get(key) != value for key, value in expected.items()):
            raise B1EvidenceError("EXTERNAL_LAUNCH_RECEIPT_BINDING_MISMATCH")
        if not isinstance(receipt["process_id"], int) or receipt["process_id"] <= 0 or not isinstance(receipt["terminal_build"], int) or receipt["terminal_build"] <= 0 or not isinstance(receipt["agent_ids"], list) or not receipt["agent_ids"] or receipt["terminal_path"] != manifest["terminal_scope"].get("terminal_path") or receipt["terminal_build"] != manifest["terminal_scope"].get("terminal_build") or receipt["terminal_version"] != manifest["terminal_scope"].get("terminal_version") or receipt["compiler_version"] != manifest["terminal_scope"].get("compiler_version") or receipt["compiler_build"] != manifest["terminal_scope"].get("compiler_build") or receipt["compiler_version"] != source["compiler"]["version"] or receipt["compiler_build"] != source["compiler"]["build"] or receipt["launch_command"] != manifest["launch_command"]:
            raise B1EvidenceError("EXTERNAL_LAUNCH_RECEIPT_RUNTIME_FACTS_INVALID")
        for key in ("manifest_sha256", "launcher_sha256"):
            self._require_hash(receipt[key], "EXTERNAL_LAUNCH_RECEIPT_HASH_FIELD_INVALID")

    def _retain(self, path: Path, output: Path, role: str, ordinal: int) -> dict[str, str]:
        digest = self._hash(path)
        target = output / "retained" / role / f"{ordinal:03d}_{path.name}"
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            if self._hash(target) != digest:
                raise B1EvidenceError("EXTERNAL_RETAINED_ARTIFACT_CONFLICT")
        else:
            shutil.copyfile(path, target)
            if self._hash(target) != digest:
                raise B1EvidenceError("EXTERNAL_RETAINED_ARTIFACT_COPY_MISMATCH")
        return {"role": role, "path": str(target.relative_to(output)).replace("\\", "/"), "sha256": digest}

    def seal(self, request: B1ExternalEvidenceRequest) -> dict[str, Any]:
        source = self._json(request.source_manifest)
        executable_hash = self._hash(request.executable)
        self._validate_source_manifest(source, executable_hash, self._hash(request.compile_log))
        receipt = self._json(request.launch_receipt)
        manifest = self._json(request.run_manifest)
        self._validate_run_manifest(manifest, request, source)
        self._validate_receipt(receipt, request, source, manifest)
        authorization = self._json(request.authorization)
        self._validate_authorization(authorization, request.run_id)
        telemetry = self._json(request.telemetry)
        verdict, reasons = self._validate_telemetry(telemetry, request.run_id)
        journals = [{"path": str(path.resolve()), "sha256": self._hash(path)} for path in request.runtime_journals]
        if len(journals) < 3:
            raise B1EvidenceError("RUNTIME_JOURNALS_INCOMPLETE")
        proof = self._json(request.runtime_proof)
        self._validate_runtime(proof, journals, request.run_id, receipt)
        result = self._json(request.result)
        if result.get("kind") != "B1_NON_CANDIDATE_RESULT_V2" or result.get("run_id") != request.run_id or result.get("status") != "COMPLETE" or result.get("native_orders") != 0:
            raise B1EvidenceError("EXTERNAL_RESULT_SCOPE_INVALID")
        compiler = source["compiler"]
        if self._hash(request.compile_log) != compiler["compile_log_sha256"]:
            raise B1EvidenceError("SOURCE_EX5_COMPILE_LOG_BINDING_MISMATCH")
        retained = [self._retain(request.run_manifest, request.output, "run_manifest", 0), self._retain(request.source_manifest, request.output, "source_manifest", 0), self._retain(request.compile_log, request.output, "compile_log", 0), self._retain(request.executable, request.output, "ex5", 0), self._retain(request.settings, request.output, "set", 0), self._retain(request.ini, request.output, "ini", 0), self._retain(request.authorization, request.output, "authorization", 0), self._retain(request.launch_receipt, request.output, "launch_receipt", 0), self._retain(request.runtime_proof, request.output, "runtime_proof", 0), self._retain(request.telemetry, request.output, "telemetry", 0), self._retain(request.result, request.output, "result", 0)]
        retained.extend(self._retain(path, request.output, "journal", index) for index, path in enumerate(request.runtime_journals))
        packet = {"schema": 2, "kind": "B1_EXTERNAL_EVIDENCE_PACKET", "run_id": request.run_id, "retained_artifacts": retained, "launch_receipt_sha256": receipt["receipt_sha256"], "source_tree_sha256": source["source_tree_sha256"], "ex5_sha256": executable_hash, "funnel_verdict": verdict, "funnel_reasons": reasons, "controls": {"candidate_execution": False, "candidate_budget_consumption": 0, "mt5_launch": True, "native_orders": 0, "oos_access": False, "holdout_access": False}}
        packet["packet_sha256"] = self._canonical(packet)
        self._common._write_immutable(request.output / self.PACKET_NAME, packet)
        return {"status": "PASS", **packet}

    def verify_sealed(self, output: Path) -> dict[str, Any]:
        packet = self._json(output / self.PACKET_NAME)
        if packet.get("packet_sha256") != self._canonical({key: value for key, value in packet.items() if key != "packet_sha256"}):
            raise B1EvidenceError("SEALED_PACKET_HASH_MISMATCH")
        if packet.get("kind") != "B1_EXTERNAL_EVIDENCE_PACKET":
            raise B1EvidenceError("SEALED_PACKET_KIND_INVALID")
        artifacts = packet.get("retained_artifacts")
        if not isinstance(artifacts, list) or not artifacts:
            raise B1EvidenceError("SEALED_ARTIFACTS_MISSING")
        paths: dict[str, Path] = {}
        journal_paths: list[Path] = []
        for artifact in artifacts:
            if not isinstance(artifact, dict) or set(artifact) != {"role", "path", "sha256"} or (artifact["role"] != "journal" and artifact["role"] in paths):
                raise B1EvidenceError("SEALED_ARTIFACT_SCHEMA_INVALID")
            relative = Path(artifact["path"])
            if not artifact["path"].startswith("retained/") or ".." in relative.parts:
                raise B1EvidenceError("SEALED_ARTIFACT_PATH_INVALID")
            path = output / relative
            if self._hash(path) != artifact["sha256"]:
                raise B1EvidenceError("SEALED_ARTIFACT_HASH_MISMATCH")
            if artifact["role"] == "journal":
                journal_paths.append(path)
            else:
                paths[artifact["role"]] = path
        for required in ("run_manifest", "source_manifest", "compile_log", "ex5", "set", "ini", "authorization", "launch_receipt", "runtime_proof", "telemetry", "result"):
            if required not in paths:
                raise B1EvidenceError("SEALED_ARTIFACT_ROLE_MISSING")
        if len(journal_paths) < 3:
            raise B1EvidenceError("SEALED_JOURNALS_INCOMPLETE")
        source = self._json(paths["source_manifest"])
        self._validate_source_manifest(source, self._hash(paths["ex5"]), self._hash(paths["compile_log"]))
        manifest = self._json(paths["run_manifest"])
        sealed_request = B1ExternalEvidenceRequest(packet["run_id"], paths["run_manifest"], paths["source_manifest"], paths["compile_log"], paths["ex5"], paths["set"], paths["ini"], paths["authorization"], paths["launch_receipt"], paths["runtime_proof"], tuple(journal_paths), paths["telemetry"], paths["result"], output)
        self._validate_run_manifest(manifest, sealed_request, source)
        self._validate_authorization(self._json(paths["authorization"]), packet["run_id"])
        if self._hash(paths["compile_log"]) != source["compiler"]["compile_log_sha256"]:
            raise B1EvidenceError("SEALED_COMPILE_LOG_BINDING_MISMATCH")
        receipt = self._json(paths["launch_receipt"])
        self._validate_receipt(receipt, sealed_request, source, manifest)
        telemetry = self._json(paths["telemetry"])
        verdict, reasons = self._validate_telemetry(telemetry, packet["run_id"])
        if packet.get("funnel_verdict") != verdict or packet.get("funnel_reasons") != reasons:
            raise B1EvidenceError("SEALED_FUNNEL_VERDICT_MISMATCH")
        proof = self._json(paths["runtime_proof"])
        journals = [{"path": str(path), "sha256": self._hash(path)} for path in journal_paths]
        self._validate_runtime(proof, journals, packet["run_id"], receipt)
        if receipt.get("source_tree_sha256") != source.get("source_tree_sha256") or receipt.get("ex5_sha256") != self._hash(paths["ex5"]) or receipt.get("set_sha256") != self._hash(paths["set"]) or receipt.get("ini_sha256") != self._hash(paths["ini"]):
            raise B1EvidenceError("SEALED_RECEIPT_BINDING_MISMATCH")
        result = self._json(paths["result"])
        if result.get("run_id") != packet["run_id"] or result.get("native_orders") != 0:
            raise B1EvidenceError("SEALED_RESULT_BINDING_MISMATCH")
        return {"status": "PASS", **packet}
