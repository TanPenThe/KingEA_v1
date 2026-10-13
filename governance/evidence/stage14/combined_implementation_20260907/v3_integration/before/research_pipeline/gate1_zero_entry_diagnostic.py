"""Immutable, non-performance controller for Gate 1's zero-entry diagnosis."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Mapping


class Gate1ZeroEntryDiagnosticError(ValueError):
    """Raised when diagnostic lineage, frames, or authorization boundaries fail."""


class Gate1ZeroEntryDiagnostic:
    ROOT_SHA256 = "B17EA4E5AA3A6D823B522252D5997F63BC8C0A6CD620C0DDDBA26851E194185D"
    REQUIRED_CHILDREN = (
        ("SYNTHETIC_TREND", "SYNTHETIC", "NONE"),
        ("FOLD_1_TRAIN_RECORDED", "RECORDED", "FOLD_1_TRAIN"),
        ("FOLD_1_TRAIN_RSB3", "RSB3", "FOLD_1_TRAIN"),
    )
    COUNTERS = (
        "closed_bars",
        "regime_healthy",
        "regime_entry_eligible",
        "sleeve_healthy",
        "breakout_intents",
        "safety_approvals",
        "safety_rejections",
        "virtual_order_attempts",
        "virtual_fills",
        "virtual_execution_failures",
        "accounting_completions",
        "native_order_calls",
        "first_zero_stage",
    )
    STAGES = {
        0: "NONE",
        1: "CLOSED_BARS",
        2: "REGIME_HEALTH",
        3: "REGIME_ELIGIBLE",
        4: "SLEEVE_HEALTH",
        5: "BREAKOUT_INTENT",
        6: "SAFETY_APPROVAL",
        7: "VIRTUAL_FILL",
        8: "ACCOUNTING",
    }

    def __init__(self, *, allow_test_fixture: bool = False) -> None:
        self.allow_test_fixture = allow_test_fixture

    @staticmethod
    def canonical_hash(value: Mapping[str, Any]) -> str:
        return hashlib.sha256(
            json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest().upper()

    def _read_root(self, path: Path) -> dict[str, Any]:
        value = json.loads(path.read_text(encoding="utf-8"))
        stored = str(value.pop("root_sha256", ""))
        if self.canonical_hash(value) != stored:
            raise Gate1ZeroEntryDiagnosticError("ROOT_HASH_MISMATCH")
        value["root_sha256"] = stored
        if (
            (not self.allow_test_fixture and stored != self.ROOT_SHA256)
            or value.get("kind") != "GATE1_ZERO_ENTRY_DIAGNOSTIC_ROOT"
            or value.get("candidate_id") != "CAND-ETH-ST-001"
            or value.get("configuration_id") != 7168
            or value.get("owner_approved") is not False
            or value.get("orders_authorized") is not False
            or value.get("oos_authorized") is not False
            or value.get("holdout_authorized") is not False
        ):
            raise Gate1ZeroEntryDiagnosticError("ROOT_SCOPE_INVALID")
        observed = tuple(
            (child.get("diagnostic"), child.get("branch"), child.get("partition"))
            for child in value.get("children", [])
        )
        if observed != self.REQUIRED_CHILDREN:
            raise Gate1ZeroEntryDiagnosticError("ROOT_CHILDREN_INVALID")
        return value

    @classmethod
    def _write_immutable(cls, path: Path, value: dict[str, Any]) -> dict[str, Any]:
        path.parent.mkdir(parents=True, exist_ok=True)
        if "artifact_sha256" not in value:
            value = dict(value)
            value["artifact_sha256"] = cls.canonical_hash(value)
        encoded = json.dumps(value, indent=2, sort_keys=True) + "\n"
        if path.exists():
            existing = json.loads(path.read_text(encoding="utf-8"))
            if existing != value:
                raise Gate1ZeroEntryDiagnosticError("IMMUTABLE_ARTIFACT_CONFLICT")
        else:
            path.write_text(encoded, encoding="utf-8", newline="\n")
        return value

    def prepare(self, root_path: Path, output_root: Path) -> dict[str, Any]:
        root = self._read_root(Path(root_path))
        children = []
        for diagnostic, branch, partition in self.REQUIRED_CHILDREN:
            child = {
                "schema": 1,
                "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_CHILD",
                "diagnostic": diagnostic,
                "branch": branch,
                "partition": partition,
                "candidate_id": root["candidate_id"],
                "configuration_id": root["configuration_id"],
                "diagnostic_root_sha256": root["root_sha256"],
                "status": "PLANNED",
                "owner_approved": False,
                "orders_authorized": False,
                "returns_authorized": False,
                "oos_authorized": False,
                "holdout_authorized": False,
                "execution": (
                    "CONTRACT_HARNESS_NO_ORDERS"
                    if branch == "SYNTHETIC"
                    else "TESTER_FUNNEL_NO_ORDERS"
                ),
            }
            child["manifest_sha256"] = self.canonical_hash(child)
            children.append(child)
            self._write_immutable(
                Path(output_root) / "children" / f"{diagnostic}.json",
                {**child, "artifact_sha256": self.canonical_hash(child)},
            )
        packet = {
            "schema": 1,
            "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_PREPARED_ROOT",
            "status": "PLANNED",
            "diagnostic_root_sha256": root["root_sha256"],
            "candidate_budget_before": 1,
            "candidate_budget_increment": 0,
            "owner_approved": False,
            "orders_authorized": False,
            "returns_authorized": False,
            "oos_authorized": False,
            "holdout_authorized": False,
            "children": children,
        }
        packet["prepared_root_sha256"] = self.canonical_hash(packet)
        self._write_immutable(Path(output_root) / "PREPARED_ROOT.json", packet)
        return packet

    def parse_frame(self, payload: str) -> dict[str, Any]:
        fields: dict[str, str] = {}
        for token in payload.split("|"):
            if "=" not in token:
                raise Gate1ZeroEntryDiagnosticError("FRAME_MALFORMED")
            key, value = token.split("=", 1)
            if not key or key in fields:
                raise Gate1ZeroEntryDiagnosticError("FRAME_MALFORMED")
            fields[key] = value
        if (
            fields.get("schema") != "1"
            or fields.get("kind") != "GATE1_ZERO_ENTRY_DIAGNOSTIC"
            or fields.get("complete") != "1"
        ):
            raise Gate1ZeroEntryDiagnosticError("FRAME_SCOPE_INVALID")
        if fields.get("returns") != "ABSENT":
            raise Gate1ZeroEntryDiagnosticError("FRAME_RETURNS_FORBIDDEN")
        result: dict[str, Any] = {"source": fields.get("source", "")}
        if result["source"] not in {"SYNTHETIC", "RECORDED", "RSB3"}:
            raise Gate1ZeroEntryDiagnosticError("FRAME_SOURCE_INVALID")
        for key in self.COUNTERS:
            try:
                result[key] = int(fields[key])
            except (KeyError, ValueError) as exc:
                raise Gate1ZeroEntryDiagnosticError("FRAME_COUNTER_INVALID") from exc
            if result[key] < 0:
                raise Gate1ZeroEntryDiagnosticError("FRAME_COUNTER_INVALID")
        if result["first_zero_stage"] not in self.STAGES:
            raise Gate1ZeroEntryDiagnosticError("FRAME_STAGE_INVALID")
        if result["native_order_calls"] != 0:
            raise Gate1ZeroEntryDiagnosticError("FRAME_NATIVE_ORDER_PROHIBITED")
        return result

    def classify(
        self, synthetic: Mapping[str, Any], historical: list[Mapping[str, Any]]
    ) -> dict[str, Any]:
        if synthetic.get("source") != "SYNTHETIC" or synthetic.get("first_zero_stage") != 0:
            return {
                "status": "INVALIDATED_PENDING_REPAIR",
                "candidate_rejected": False,
                "earliest_failed_stage": "SYNTHETIC_CONTRACT",
            }
        sources = {row.get("source") for row in historical}
        if sources != {"RECORDED", "RSB3"}:
            raise Gate1ZeroEntryDiagnosticError("HISTORICAL_BRANCH_SET_INVALID")
        stages = {int(row["first_zero_stage"]) for row in historical}
        # Matching funnel counters identify a reproducible location to investigate;
        # they do not, by themselves, prove a defect.  Only a separately reviewed
        # root-cause record may promote this quarantine to INVALIDATED.
        if len(stages) == 1 and next(iter(stages)) in self.STAGES:
            return {
                "status": "QUARANTINED_PENDING_DIAGNOSTIC",
                "candidate_rejected": False,
                "earliest_failed_stage": self.STAGES[next(iter(stages))],
            }
        return {
            "status": "QUARANTINED_PENDING_DIAGNOSTIC",
            "candidate_rejected": False,
            "earliest_failed_stage": "INCONCLUSIVE",
        }
