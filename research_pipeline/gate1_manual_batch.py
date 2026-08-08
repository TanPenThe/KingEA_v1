"""Fail-closed planning and completion checks for manual Gate 1 batches.

The module does not launch MT5.  It reduces the 200-child Gate 1 root to the
next bounded, sequential foreground batch and verifies the result frames that
the tester persisted after each child run.
"""

from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Mapping, Sequence


class Gate1BatchError(ValueError):
    """A Gate 1 manual-batch contract violation."""


class Gate1ManualBatch:
    EXACT_ROOT = "BC4D5D84DBF45AAB6628AA0E1D39D984F715217BB1CA1C092DE1EE97385FA889"
    MAXIMUM_CHILDREN = 2
    MAXIMUM_CHILD_HOURS = 3.75
    PROJECTED_GATE_WALL_DAYS = 26.4783984375
    EXPECTED_LAUNCHES = 200
    _RESULT_NAME = re.compile(r"^[0-9]+_KINGEA_STAGE12_COMPLETE_([0-9]+)\.frame$")

    def __init__(self, workspace: Path):
        self.workspace = Path(workspace).resolve()

    @staticmethod
    def canonical_hash(value: Mapping[str, Any]) -> str:
        encoded = json.dumps(
            value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest().upper()

    @staticmethod
    def file_hash(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest().upper()

    def _validate_root(self, root: Mapping[str, Any]) -> None:
        stored = str(root.get("root_sha256", "")).upper()
        unhashed = {key: value for key, value in root.items() if key != "root_sha256"}
        if stored != self.EXACT_ROOT or self.canonical_hash(unhashed) != stored:
            raise Gate1BatchError("GATE1_ROOT_HASH_MISMATCH")
        if (
            root.get("gate") != 1
            or root.get("launch_count") != self.EXPECTED_LAUNCHES
            or root.get("configuration_pass_count") != 194_400
            or root.get("owner_approved") is not False
        ):
            raise Gate1BatchError("GATE1_ROOT_SCOPE_CHANGED")

    def _validate_approval(
        self, root: Mapping[str, Any], approval: Mapping[str, Any]
    ) -> None:
        if approval.get("owner_approved") is not True or approval.get("gate") != 1:
            raise Gate1BatchError("OWNER_GATE_AUTHORIZATION_REQUIRED")
        if str(approval.get("root_sha256", "")).upper() != root["root_sha256"]:
            raise Gate1BatchError("AUTHORIZATION_ROOT_MISMATCH")
        required = (
            "I explicitly approve Gate 1 root "
            f"{root['root_sha256']} for exhaustive development execution."
        )
        if approval.get("owner_statement") != required:
            raise Gate1BatchError("OWNER_STATEMENT_MISMATCH")
        if approval.get("oos_authorized") is not False or approval.get(
            "holdout_authorized"
        ) is not False:
            raise Gate1BatchError("AUTHORIZATION_SCOPE_TOO_BROAD")

    def _validate_index(
        self, root: Mapping[str, Any], index: Mapping[str, Any]
    ) -> list[Mapping[str, Any]]:
        stored = str(index.get("index_sha256", "")).upper()
        unhashed = {key: value for key, value in index.items() if key != "index_sha256"}
        if self.canonical_hash(unhashed) != stored:
            raise Gate1BatchError("CHILD_INDEX_HASH_MISMATCH")
        children = index.get("children")
        if (
            index.get("root_sha256") != root["root_sha256"]
            or index.get("child_count") != self.EXPECTED_LAUNCHES
            or not isinstance(children, list)
            or len(children) != self.EXPECTED_LAUNCHES
        ):
            raise Gate1BatchError("CHILD_INDEX_SCOPE_MISMATCH")
        for expected_number, child in enumerate(children):
            expected_id = f"G1-{expected_number:04d}"
            if child.get("run_id") != expected_id:
                raise Gate1BatchError("CHILD_SEQUENCE_INVALID")
            path = (self.workspace / str(child.get("path", ""))).resolve()
            try:
                path.relative_to(self.workspace)
            except ValueError as exc:
                raise Gate1BatchError("CHILD_PATH_OUTSIDE_WORKSPACE") from exc
            if not path.is_file() or self.file_hash(path) != child.get("file_sha256"):
                raise Gate1BatchError("CHILD_FILE_HASH_MISMATCH")
            manifest = json.loads(path.read_text(encoding="utf-8"))
            if (
                manifest.get("manifest_sha256") != child.get("manifest_sha256")
                or manifest.get("root_sha256") != root["root_sha256"]
                or manifest.get("run_id") != expected_id
                or manifest.get("gate") != 1
                or manifest.get("purpose") != "DEVELOPMENT"
                or manifest.get("partition") == "FORMAL_OOS"
            ):
                raise Gate1BatchError("CHILD_MANIFEST_SCOPE_MISMATCH")
        return children

    def plan(
        self,
        root: Mapping[str, Any],
        index: Mapping[str, Any],
        approval: Mapping[str, Any],
        completed_run_ids: Sequence[str],
        requested_children: int = 2,
    ) -> dict[str, Any]:
        if (
            isinstance(requested_children, bool)
            or not isinstance(requested_children, int)
            or requested_children < 1
            or requested_children > self.MAXIMUM_CHILDREN
        ):
            raise Gate1BatchError("BATCH_CHILD_LIMIT_EXCEEDED")
        self._validate_root(root)
        self._validate_approval(root, approval)
        children = self._validate_index(root, index)
        completed = list(completed_run_ids)
        expected_prefix = [f"G1-{number:04d}" for number in range(len(completed))]
        if completed != expected_prefix:
            raise Gate1BatchError("COMPLETION_SEQUENCE_GAP")
        selected = children[len(completed) : len(completed) + requested_children]
        projected_child_hours = (
            self.PROJECTED_GATE_WALL_DAYS * 24.0 / self.EXPECTED_LAUNCHES
        )
        return {
            "schema": 1,
            "kind": "GATE1_MANUAL_FOREGROUND_BATCH_PLAN",
            "root_sha256": root["root_sha256"],
            "execution_mode": "MANUAL_FOREGROUND",
            "maximum_children": self.MAXIMUM_CHILDREN,
            "requested_children": requested_children,
            "run_ids": [child["run_id"] for child in selected],
            "child_manifest_sha256": [child["manifest_sha256"] for child in selected],
            "projected_child_hours": projected_child_hours,
            "projected_batch_hours": projected_child_hours * len(selected),
            "hard_child_hours": self.MAXIMUM_CHILD_HOURS,
            "hard_batch_hours": self.MAXIMUM_CHILD_HOURS * len(selected),
            "oos_authorized": False,
            "holdout_authorized": False,
            "background_or_watchdog": False,
        }

    def child_authorization(
        self, manifest: Mapping[str, Any], approval: Mapping[str, Any]
    ) -> dict[str, Any]:
        if manifest.get("root_sha256") != approval.get("root_sha256"):
            raise Gate1BatchError("AUTHORIZATION_ROOT_MISMATCH")
        return {
            "schema": 1,
            "kind": "GATE1_DETACHED_CHILD_AUTHORIZATION",
            "owner_approved": True,
            "gate": 1,
            "root_sha256": approval["root_sha256"],
            "child_sha256": manifest["manifest_sha256"],
            "run_id": manifest["run_id"],
            "derived_from_owner_statement": approval["owner_statement"],
            "oos_authorized": False,
            "holdout_authorized": False,
        }

    def verify_completion(
        self, manifest: Mapping[str, Any], spool: Path
    ) -> dict[str, Any]:
        expected = set(int(value) for value in manifest.get("configuration_ids", []))
        found: dict[int, Path] = {}
        for path in Path(spool).glob("*_KINGEA_STAGE12_COMPLETE_*.frame"):
            match = self._RESULT_NAME.fullmatch(path.name)
            if not match:
                continue
            configuration_id = int(match.group(1))
            if configuration_id in found:
                raise Gate1BatchError("DUPLICATE_RESULT_FRAME")
            payload = path.read_text(encoding="utf-8")
            fields = dict(
                part.split("=", 1) for part in payload.split("|") if "=" in part
            )
            if int(fields.get("config", -1)) != configuration_id:
                raise Gate1BatchError("RESULT_FRAME_CONFIGURATION_MISMATCH")
            if fields.get("branch") != manifest.get("branch") or fields.get(
                "partition"
            ) != manifest.get("partition"):
                raise Gate1BatchError("RESULT_FRAME_SCOPE_MISMATCH")
            if fields.get("complete") != "1":
                raise Gate1BatchError("RESULT_FRAME_INCOMPLETE")
            if fields.get("hard_failures") != "0":
                raise Gate1BatchError("RESULT_FRAME_HARD_FAILURE")
            found[configuration_id] = path
        if set(found) != expected:
            raise Gate1BatchError("RESULT_FRAME_CARDINALITY_MISMATCH")
        hashes = [self.file_hash(found[value]) for value in sorted(found)]
        return {
            "schema": 1,
            "status": "COMPLETE",
            "run_id": manifest["run_id"],
            "manifest_sha256": manifest["manifest_sha256"],
            "frame_count": len(found),
            "first_configuration_id": min(found),
            "last_configuration_id": max(found),
            "result_frame_set_sha256": hashlib.sha256(
                "\n".join(hashes).encode("ascii")
            ).hexdigest().upper(),
        }
