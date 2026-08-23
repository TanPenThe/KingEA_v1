"""Governed MT5 build-transition parity for an interrupted Gate 1 run.

The module is pure: it prepares immutable parity manifests and compares result
frames.  Filesystem/process effects belong to the CLI adapter.
"""

from __future__ import annotations

import json
import hashlib
import tarfile
from pathlib import Path
from typing import Any, Mapping

from .gate1_manual_batch import Gate1ManualBatch
from .stage14 import ResearchRunCoordinator


class BuildTransitionError(ValueError):
    """A build-transition contract violation."""


class Gate1BuildTransition:
    """Prepare and verify one bounded MT5 build-parity decision."""

    REFERENCE_RUNS = ("G1-0000", "G1-0039", "G1-0080", "G1-0119")

    def __init__(self, workspace: Path):
        self.workspace = Path(workspace).resolve()
        self.coordinator = ResearchRunCoordinator()

    @staticmethod
    def _valid_hash(value: Any) -> bool:
        return (
            isinstance(value, str)
            and len(value) == 64
            and all(character in "0123456789ABCDEF" for character in value.upper())
        )

    def _validate_prior(
        self, root: Mapping[str, Any], index: Mapping[str, Any]
    ) -> dict[str, Mapping[str, Any]]:
        stored = str(root.get("root_sha256", "")).upper()
        unhashed = {key: value for key, value in root.items() if key != "root_sha256"}
        if (
            stored != Gate1ManualBatch.EXACT_ROOT
            or self.coordinator.canonical_hash(unhashed) != stored
            or int(root.get("mt5_build", 0)) <= 0
        ):
            raise BuildTransitionError("PRIOR_ROOT_INVALID")
        index_stored = str(index.get("index_sha256", "")).upper()
        index_unhashed = {
            key: value for key, value in index.items() if key != "index_sha256"
        }
        rows = index.get("children")
        if (
            self.coordinator.canonical_hash(index_unhashed) != index_stored
            or index.get("root_sha256") != stored
            or not isinstance(rows, list)
        ):
            raise BuildTransitionError("PRIOR_INDEX_INVALID")
        by_id = {str(row.get("run_id")): row for row in rows}
        if any(run_id not in by_id for run_id in self.REFERENCE_RUNS):
            raise BuildTransitionError("REFERENCE_RUN_MISSING")
        return by_id

    def prepare(
        self,
        *,
        prior_root: Mapping[str, Any],
        prior_index: Mapping[str, Any],
        new_build: int,
        terminal_sha256: str,
        transition_pre_tooling_sha256: str,
    ) -> dict[str, Any]:
        by_id = self._validate_prior(prior_root, prior_index)
        if isinstance(new_build, bool) or int(new_build) <= int(prior_root["mt5_build"]):
            raise BuildTransitionError("NEW_BUILD_NOT_FORWARD")
        if not self._valid_hash(terminal_sha256):
            raise BuildTransitionError("TERMINAL_HASH_INVALID")
        if not self._valid_hash(transition_pre_tooling_sha256):
            raise BuildTransitionError("TRANSITION_PRE_TOOLING_HASH_INVALID")

        references: list[tuple[str, Mapping[str, Any], Mapping[str, Any]]] = []
        comparisons: list[dict[str, Any]] = []
        for reference_run_id in self.REFERENCE_RUNS:
            row = by_id[reference_run_id]
            path = (self.workspace / str(row.get("path", ""))).resolve()
            try:
                path.relative_to(self.workspace)
            except ValueError as exc:
                raise BuildTransitionError("REFERENCE_PATH_OUTSIDE_WORKSPACE") from exc
            if not path.is_file() or Gate1ManualBatch.file_hash(path) != row.get(
                "file_sha256"
            ):
                raise BuildTransitionError("REFERENCE_MANIFEST_CHANGED")
            manifest = json.loads(path.read_text(encoding="utf-8"))
            parity_run_id = f"BP-{reference_run_id[3:]}-B{int(new_build)}"
            comparisons.append(
                {
                    "reference_run_id": reference_run_id,
                    "parity_run_id": parity_run_id,
                    "reference_manifest_sha256": manifest["manifest_sha256"],
                    "branch": manifest["branch"],
                    "partition": manifest["partition"],
                    "configuration_start": manifest["configuration_start"],
                    "configuration_end": manifest["configuration_end"],
                }
            )
            references.append((parity_run_id, row, manifest))

        root = {
            "schema": 1,
            "kind": "GATE1_MT5_BUILD_PARITY",
            "status": "PLANNED",
            "candidate_id": "CAND-ETH-ST-001",
            "prior_root_sha256": prior_root["root_sha256"],
            "prior_mt5_build": int(prior_root["mt5_build"]),
            "new_mt5_build": int(new_build),
            "new_terminal_sha256": terminal_sha256.upper(),
            "transition_pre_tooling_sha256": transition_pre_tooling_sha256.upper(),
            "comparisons": comparisons,
            "acceptance": {
                "stage12_payloads": "EXACT",
                "stage13_payloads": "EXACT_EXCEPT_LEDGER_ROOT_FIELD",
                "missing_extra_or_duplicate_frames": "FAIL",
                "any_substantive_difference": "FAIL_AND_RESTART_GATE1",
            },
            "selection_eligible": False,
            "oos_authorized": False,
            "holdout_authorized": False,
            "candidate_budget_increment": 0,
        }
        root["parity_root_sha256"] = self.coordinator.canonical_hash(root)

        children: list[dict[str, Any]] = []
        index_rows: list[dict[str, Any]] = []
        for parity_run_id, _, reference in references:
            facts = {
                "run_id": parity_run_id,
                "gate": 1,
                "purpose": "DEVELOPMENT",
                "partition": reference["partition"],
                "branch": reference["branch"],
                "configuration_start": int(reference["configuration_start"]),
                "configuration_end": int(reference["configuration_end"]),
                "scenario": reference["scenario"],
                "seed": int(reference["seed"]),
                "execution_adapter": reference["execution_adapter"],
                "execution_mode": int(reference["execution_mode"]),
                "artifact_hashes": dict(reference["artifact_hashes"]),
                "mt5_build": int(new_build),
                "account_fingerprint": reference["account_fingerprint"],
                "operational_facts": dict(reference["operational_facts"]),
                "root_sha256": root["parity_root_sha256"],
            }
            child = self.coordinator.prepare_child(facts)
            children.append(child)
            index_rows.append(
                {
                    "run_id": parity_run_id,
                    "reference_run_id": next(
                        row["reference_run_id"]
                        for row in comparisons
                        if row["parity_run_id"] == parity_run_id
                    ),
                    "manifest_sha256": child["manifest_sha256"],
                }
            )
        index = {
            "schema": 1,
            "kind": "GATE1_MT5_BUILD_PARITY_INDEX",
            "parity_root_sha256": root["parity_root_sha256"],
            "child_count": len(index_rows),
            "children": index_rows,
        }
        index["index_sha256"] = self.coordinator.canonical_hash(index)
        return {"root": root, "index": index, "children": children}

    @staticmethod
    def _normalized_payload(name: str, payload: bytes) -> tuple[bytes, bool]:
        if "_KINGEA_STAGE13_ACCOUNTING_" not in name:
            return payload, False
        try:
            text = payload.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise BuildTransitionError("FRAME_NOT_UTF8") from exc
        fields = text.split("|")
        roots = [field for field in fields if field.startswith("root=")]
        if len(roots) != 1:
            raise BuildTransitionError("STAGE13_ROOT_FIELD_INVALID")
        normalized = "|".join(
            field for field in fields if not field.startswith("root=")
        ).encode("utf-8")
        return normalized, True

    def compare(
        self, *, reference_record: Mapping[str, Any], candidate_spool: Path
    ) -> dict[str, Any]:
        if (
            reference_record.get("status") != "ARCHIVED_VERIFIED"
            or not self._valid_hash(reference_record.get("archive_sha256"))
            or int(reference_record.get("file_count", 0)) <= 0
        ):
            raise BuildTransitionError("REFERENCE_RECORD_INVALID")
        archive = Path(str(reference_record.get("archive_path", ""))).resolve()
        spool = Path(candidate_spool).resolve()
        if not archive.is_file() or not spool.is_dir():
            raise BuildTransitionError("COMPARISON_INPUT_MISSING")
        if Gate1ManualBatch.file_hash(archive) != str(
            reference_record["archive_sha256"]
        ).upper():
            raise BuildTransitionError("REFERENCE_ARCHIVE_HASH_MISMATCH")

        candidate_count = sum(1 for path in spool.iterdir() if path.is_file())
        expected_count = int(reference_record["file_count"])
        if candidate_count != expected_count:
            raise BuildTransitionError("PARITY_FRAME_CARDINALITY_MISMATCH")

        digest = hashlib.sha256()
        compared = normalized_count = 0
        with tarfile.open(archive, "r:gz") as handle:
            for member in handle:
                if not member.isfile():
                    continue
                name = member.name[2:] if member.name.startswith("./") else member.name
                relative = Path(name)
                if relative.is_absolute() or ".." in relative.parts or len(relative.parts) != 1:
                    raise BuildTransitionError("UNSAFE_REFERENCE_MEMBER")
                candidate = spool / name
                if not candidate.is_file():
                    raise BuildTransitionError("PARITY_FRAME_MISSING")
                stream = handle.extractfile(member)
                if stream is None:
                    raise BuildTransitionError("REFERENCE_FRAME_UNREADABLE")
                reference_payload, reference_normalized = self._normalized_payload(
                    name, stream.read()
                )
                candidate_payload, candidate_normalized = self._normalized_payload(
                    name, candidate.read_bytes()
                )
                if reference_normalized != candidate_normalized:
                    raise BuildTransitionError("PARITY_FRAME_TYPE_MISMATCH")
                if reference_payload != candidate_payload:
                    raise BuildTransitionError(f"PARITY_SUBSTANTIVE_MISMATCH:{name}")
                digest.update(name.encode("utf-8") + b"\0")
                digest.update(reference_payload + b"\0")
                compared += 1
                normalized_count += int(reference_normalized)
        if compared != expected_count:
            raise BuildTransitionError("REFERENCE_FRAME_CARDINALITY_MISMATCH")
        return {
            "schema": 1,
            "status": "PASS",
            "reference_run_id": reference_record.get("run_id"),
            "compared_frames": compared,
            "normalized_stage13_frames": normalized_count,
            "substantive_frame_set_sha256": digest.hexdigest().upper(),
        }
