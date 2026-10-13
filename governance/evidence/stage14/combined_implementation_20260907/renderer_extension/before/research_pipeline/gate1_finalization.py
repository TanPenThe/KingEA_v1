from __future__ import annotations

import hashlib
import json
import math
import re
import tarfile
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Mapping

from .stage12 import Stage12Error, Stage12Pipeline
from .stage14 import ResearchRunCoordinator
from .native_cost_archive import NativeCostArchiveConsumer
from .successor_evidence import SuccessorEvidenceError, validate, validate_frame


class Gate1FinalizationError(ValueError):
    pass


_RETIRED_HISTORICAL_AUDIT_CAPABILITY = object()


@dataclass(frozen=True)
class Gate1FinalizationRequest:
    prior_package: Path
    continuation_package: Path
    parity_package: Path
    archive_root: Path
    execution_root: Path
    output_root: Path
    allow_test_fixture: bool = False
    progress_callback: Callable[[dict[str, Any]], None] | None = None


class Gate1Finalizer:
    """Stream Gate 1 evidence, classify it, and publish one immutable result."""

    def __init__(self, *, control_context=None, _historical_audit_capability=None):
        self._control_context = control_context
        self._historical_audit = (
            _historical_audit_capability is _RETIRED_HISTORICAL_AUDIT_CAPABILITY
        )

    def finalize_successor_frames(self, spool: Path, manifest: Mapping[str, Any], *, boundary=False):
        """Evidence acceptance only; no scoring, economics or gate advancement.

        Old epoch/archive APIs below cannot interpret a successor or use a
        generic historical compatibility fallback. They remain default-deny.
        """
        return ResearchRunCoordinator(control_context=self._control_context).finalize_frames(
            spool, manifest, finalization_stage='boundary_finalization' if boundary else 'normal_finalization')

    _STAGE12 = re.compile(r"^(\d+)_KINGEA_STAGE12_COMPLETE_(\d+)\.frame$")
    _NATIVE_COST = re.compile(r"^(\d+)_KINGEA_NATIVE_COST_PACKAGE_(\d+)\.frame$")
    _STAGE13_COMPLETE = re.compile(
        r"^(\d+)_KINGEA_STAGE13_ACCOUNTING_COMPLETE_(\d+)\.frame$"
    )
    _STAGE13_EVENT = re.compile(
        r"^(\d+)_KINGEA_STAGE13_ACCOUNTING_EVENT_(\d+)\.frame$"
    )
    _ACCOUNTING_EVENT_PAYLOAD = re.compile(
        rb"^schema=1\|sequence=(?P<sequence>\d+)"
        rb"\|event_id=.+?\|event_type=(?P<event_type>\d+)"
        rb"\|server_time_msc=(?P<server_time_msc>\d+)"
        rb"\|sleeve=[^|]*\|group=[^|]*\|order=\d+\|deal=\d+\|position=\d+"
        rb"\|gross=-?\d+\.\d{12}\|commission=-?\d+\.\d{12}"
        rb"\|swap=-?\d+\.\d{12}\|fee=-?\d+\.\d{12}"
        rb"\|net=(?P<net>-?\d+\.\d{12})"
        rb"\|net_return=(?P<net_return>-?\d+\.\d{12})"
        rb"\|net_r=(?P<net_r>-?\d+\.\d{12})"
        rb"\|mae_r=-?\d+\.\d{12}\|mfe_r=-?\d+\.\d{12}\|bars_held=\d+"
        rb"\|root=(?P<root>[0-9A-F]{64})$"
    )

    @staticmethod
    def canonical_bytes(value: Any) -> bytes:
        return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()

    @classmethod
    def canonical_hash(cls, value: Any) -> str:
        return hashlib.sha256(cls.canonical_bytes(value)).hexdigest().upper()

    @staticmethod
    def _read(path: Path) -> dict[str, Any]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise Gate1FinalizationError(f"JSON_INVALID:{path}") from exc
        if not isinstance(value, dict):
            raise Gate1FinalizationError(f"JSON_OBJECT_REQUIRED:{path}")
        return value

    @staticmethod
    def _sha256_file(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest().upper()

    @staticmethod
    def _parse_payload(data: bytes) -> dict[str, str]:
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise Gate1FinalizationError("FRAME_NOT_UTF8") from exc
        fields: dict[str, str] = {}
        previous_key = ""
        for part in text.split("|"):
            if "=" not in part:
                if previous_key == "event_id" and part:
                    fields[previous_key] += "|" + part
                    continue
                raise Gate1FinalizationError("FRAME_FIELD_MALFORMED")
            key, value = part.split("=", 1)
            if not key or key in fields:
                raise Gate1FinalizationError("FRAME_FIELD_DUPLICATE")
            fields[key] = value
            previous_key = key
        return fields

    @classmethod
    def _parse_accounting_event(cls, data: bytes) -> dict[str, str]:
        matched = cls._ACCOUNTING_EVENT_PAYLOAD.fullmatch(data)
        if matched is None:
            raise Gate1FinalizationError("ACCOUNTING_EVENT_SCHEMA_INVALID")
        return {
            key: value.decode("ascii")
            for key, value in matched.groupdict().items()
        }

    @staticmethod
    def _sample_indexes(count: int) -> list[int]:
        if count <= 128:
            return list(range(count))
        return sorted({round(index * (count - 1) / 127) for index in range(128)})

    @staticmethod
    def _decimal12(value: str, reason: str) -> Decimal:
        if re.fullmatch(r"-?\d+\.\d{12}", value or "") is None:
            raise Gate1FinalizationError(reason)
        try:
            return Decimal(value)
        except InvalidOperation as exc:
            raise Gate1FinalizationError(reason) from exc

    @classmethod
    def _decimal12_list(cls, value: str, reason: str) -> list[Decimal]:
        if value == "":
            return []
        return [cls._decimal12(item, reason) for item in value.split(";")]

    @staticmethod
    def _safe_name(raw: str) -> str:
        name = raw[2:] if raw.startswith("./") else raw
        path = PurePosixPath(name)
        if not name or path.is_absolute() or ".." in path.parts or "\\" in name:
            raise Gate1FinalizationError("UNSAFE_ARCHIVE_MEMBER")
        return name

    def _verify_lineage(
        self,
        request: Gate1FinalizationRequest,
        prior_root: Mapping[str, Any],
        continuation_root: Mapping[str, Any],
        fixture: bool,
    ) -> None:
        parity = self._read(Path(request.parity_package) / "PARITY_RESULT.json")
        stored_parity_hash = str(parity.get("result_sha256", ""))
        parity_body = {key: value for key, value in parity.items() if key != "result_sha256"}
        if (
            parity.get("status") != "PASS"
            or (not fixture and parity.get("selection_eligible") is not False)
            or self.canonical_hash(parity_body) != stored_parity_hash
        ):
            raise Gate1FinalizationError("BUILD_PARITY_NOT_ACCEPTABLE")
        comparisons = parity.get("comparisons")
        if comparisons is not None:
            if (
                not isinstance(comparisons, list)
                or parity.get("comparison_count", len(comparisons)) != len(comparisons)
                or any(
                    not isinstance(row, Mapping) or row.get("status") != "PASS"
                    for row in comparisons
                )
            ):
                raise Gate1FinalizationError("BUILD_PARITY_COMPARISON_INVALID")
        if not fixture:
            expected_references = ["G1-0000", "G1-0039", "G1-0080", "G1-0119"]
            if (
                not isinstance(comparisons, list)
                or [row.get("reference_run_id") for row in comparisons]
                != expected_references
                or parity.get("prior_mt5_build") != 6090
                or parity.get("new_mt5_build") != 6140
                or parity.get("continuation_authorized") is not False
                or any(
                    row.get("new_mt5_build") != 6140
                    or int(row.get("compared_frames", 0)) <= 0
                    or int(row.get("normalized_stage13_frames", 0)) <= 0
                    or re.fullmatch(
                        r"[0-9A-F]{64}", str(row.get("parity_archive_sha256", ""))
                    )
                    is None
                    for row in comparisons
                )
            ):
                raise Gate1FinalizationError("BUILD_PARITY_COMPARISON_INVALID")

        inventory = self._read(
            Path(request.continuation_package) / "COMPLETED_EVIDENCE_INVENTORY.json"
        )
        stored_inventory_hash = str(inventory.get("inventory_sha256", ""))
        inventory_body = {
            key: value for key, value in inventory.items() if key != "inventory_sha256"
        }
        if self.canonical_hash(inventory_body) != stored_inventory_hash:
            raise Gate1FinalizationError("COMPLETED_INVENTORY_HASH_MISMATCH")

        inventory_rows = inventory.get("rows")
        prior_index = self._read(Path(request.prior_package) / "CHILD_INDEX.json")
        prior_children = {
            str(row.get("run_id")): row
            for row in prior_index.get("children", [])
            if isinstance(row, Mapping)
        }
        if not isinstance(inventory_rows, list):
            raise Gate1FinalizationError("COMPLETED_INVENTORY_ROWS_INVALID")
        expected_inventory_ids = [
            "G1-0000"
        ] if fixture else [f"G1-{index:04d}" for index in range(120)]
        if [str(row.get("run_id")) for row in inventory_rows] != expected_inventory_ids:
            raise Gate1FinalizationError("COMPLETED_INVENTORY_RUN_SET_INVALID")
        production_keys = {
            "run_id",
            "manifest_sha256",
            "child_file_sha256",
            "completion_file_sha256",
            "archive_marker_file_sha256",
            "archive_sha256",
            "archive_size",
            "archive_file_count",
            "archive_sample_set_sha256",
        }
        for inventory_row in inventory_rows:
            run_id = str(inventory_row.get("run_id"))
            child = prior_children.get(run_id)
            if (
                child is None
                or inventory_row.get("manifest_sha256")
                != child.get("manifest_sha256")
                or (
                    "child_file_sha256" in inventory_row
                    and inventory_row.get("child_file_sha256")
                    != child.get("file_sha256")
                )
            ):
                raise Gate1FinalizationError("COMPLETED_INVENTORY_ROW_CONFLICT")
            if fixture:
                continue
            if set(inventory_row) != production_keys:
                raise Gate1FinalizationError("COMPLETED_INVENTORY_ROW_SCHEMA_INVALID")
            complete_path = (
                Path(request.execution_root) / "children" / run_id / "COMPLETE.json"
            )
            marker_paths = list(
                Path(request.archive_root).glob(f"{run_id}_*.ARCHIVED.json")
            )
            if not complete_path.is_file() or len(marker_paths) != 1:
                raise Gate1FinalizationError("COMPLETED_INVENTORY_EVIDENCE_MISSING")
            marker_path = marker_paths[0]
            marker = self._read(marker_path)
            archive_path = Path(str(marker.get("archive_path", "")))
            exact = {
                "completion_file_sha256": self._sha256_file(complete_path),
                "archive_marker_file_sha256": self._sha256_file(marker_path),
                "archive_sha256": marker.get("archive_sha256"),
                "archive_size": archive_path.stat().st_size
                if archive_path.is_file()
                else -1,
                "archive_file_count": marker.get("file_count"),
                "archive_sample_set_sha256": marker.get("sample_set_sha256"),
            }
            if any(inventory_row.get(key) != value for key, value in exact.items()):
                raise Gate1FinalizationError("COMPLETED_INVENTORY_EVIDENCE_CONFLICT")

        authorization = self._read(
            Path(request.continuation_package) / "GATE1_AUTHORIZATION.json"
        )
        if (
            authorization.get("owner_approved") is not True
            or authorization.get("oos_authorized") is not False
            or authorization.get("holdout_authorized") is not False
            or authorization.get("root_sha256") != continuation_root.get("root_sha256")
        ):
            raise Gate1FinalizationError("CONTINUATION_AUTHORIZATION_INVALID")

        if fixture:
            if (
                inventory.get("completed_count") != 1
                or inventory.get("prior_root_sha256") != prior_root.get("root_sha256")
                or parity.get("prior_root_sha256") != prior_root.get("root_sha256")
                or parity.get("continuation_root_sha256")
                != continuation_root.get("root_sha256")
            ):
                raise Gate1FinalizationError("FIXTURE_LINEAGE_INVALID")
            return

        for root in (prior_root, continuation_root):
            stored = str(root.get("root_sha256", ""))
            body = {key: value for key, value in root.items() if key != "root_sha256"}
            if self.canonical_hash(body) != stored:
                raise Gate1FinalizationError("GATE1_ROOT_HASH_MISMATCH")
        transition = continuation_root.get("build_transition")
        if not isinstance(transition, Mapping):
            raise Gate1FinalizationError("BUILD_TRANSITION_MISSING")
        expected = {
            "prior_root_sha256": prior_root["root_sha256"],
            "parity_result_sha256": stored_parity_hash,
            "completed_evidence_inventory_sha256": stored_inventory_hash,
            "accepted_completed_count": 120,
            "resume_run_id": "G1-0120",
        }
        if any(transition.get(key) != value for key, value in expected.items()):
            raise Gate1FinalizationError("BUILD_TRANSITION_CONFLICT")
        if (
            authorization.get("prior_root_sha256") != prior_root["root_sha256"]
            or authorization.get("parity_result_sha256") != stored_parity_hash
            or authorization.get("completed_evidence_inventory_sha256")
            != stored_inventory_hash
            or inventory.get("completed_count") != 120
            or inventory.get("first_run_id") != "G1-0000"
            or inventory.get("last_run_id") != "G1-0119"
            or inventory.get("prior_root_sha256") != prior_root["root_sha256"]
        ):
            raise Gate1FinalizationError("BUILD_TRANSITION_LINEAGE_INVALID")

    def _epoch_rows(self, request: Gate1FinalizationRequest) -> list[dict[str, Any]]:
        prior_root = self._read(Path(request.prior_package) / "GATE1_ROOT.json")
        continuation_root = self._read(
            Path(request.continuation_package) / "GATE1_ROOT.json"
        )
        fixture = (
            prior_root.get("kind") == "GATE1_TEST_FIXTURE"
            and continuation_root.get("kind") == "GATE1_TEST_FIXTURE"
        )
        if fixture and not request.allow_test_fixture:
            raise Gate1FinalizationError("TEST_FIXTURE_NOT_ALLOWED")
        if not fixture and request.allow_test_fixture:
            raise Gate1FinalizationError("FIXTURE_OVERRIDE_ON_PRODUCTION_ROOT")
        self._verify_lineage(request, prior_root, continuation_root, fixture)

        rows: list[dict[str, Any]] = []
        packages = (request.prior_package, request.continuation_package)
        roots = (prior_root, continuation_root)
        for epoch, package in enumerate(packages):
            index = self._read(Path(package) / "CHILD_INDEX.json")
            children = index.get("children")
            stored_index_hash = str(index.get("index_sha256", ""))
            index_body = {key: value for key, value in index.items() if key != "index_sha256"}
            if (
                not isinstance(children, list)
                or index.get("root_sha256") != roots[epoch].get("root_sha256")
                or index.get("child_count") != len(children)
                or self.canonical_hash(index_body) != stored_index_hash
            ):
                raise Gate1FinalizationError("CHILD_INDEX_INVALID")
            for child in children:
                number = int(str(child.get("run_id", ""))[3:])
                if not fixture and ((epoch == 0 and number >= 120) or (epoch == 1 and number < 120)):
                    continue
                child_path = Path(str(child["path"]))
                if not child_path.is_absolute():
                    child_path = Path.cwd() / child_path
                child_path = child_path.resolve()
                expected_parent = (Path(package) / "children").resolve()
                if child_path.parent != expected_parent or not child_path.is_file():
                    raise Gate1FinalizationError("CHILD_PATH_INVALID")
                if self._sha256_file(child_path) != child.get("file_sha256"):
                    raise Gate1FinalizationError("CHILD_FILE_HASH_MISMATCH")
                child_manifest = self._read(child_path)
                if child_manifest.get("manifest_sha256") != child.get("manifest_sha256"):
                    raise Gate1FinalizationError("CHILD_MANIFEST_HASH_CONFLICT")
                if not fixture:
                    manifest_body = {
                        key: value
                        for key, value in child_manifest.items()
                        if key != "manifest_sha256"
                    }
                    if self.canonical_hash(manifest_body) != child["manifest_sha256"]:
                        raise Gate1FinalizationError("CHILD_MANIFEST_HASH_MISMATCH")
                    descriptor = roots[epoch]["child_descriptors"][number]
                    expected_descriptor = {
                        "partition": child_manifest["partition"],
                        "branch": child_manifest["branch"],
                        "configuration_start": child_manifest["configuration_start"],
                        "configuration_end": child_manifest["configuration_end"],
                        "scenario": child_manifest["scenario"],
                        "seed": child_manifest["seed"],
                        "adapter": child_manifest["execution_adapter"],
                        "execution_mode": child_manifest["execution_mode"],
                    }
                    if descriptor != expected_descriptor:
                        raise Gate1FinalizationError("CHILD_DESCRIPTOR_CONFLICT")
                rows.append(
                    {
                        "epoch": epoch,
                        "run_id": child["run_id"],
                        "manifest_sha256": child["manifest_sha256"],
                        "child": child_manifest,
                    }
                )
        run_ids = [str(row["run_id"]) for row in rows]
        if len(run_ids) != len(set(run_ids)):
            raise Gate1FinalizationError("LINEAGE_RUN_DUPLICATE")
        if not fixture and run_ids != [f"G1-{index:04d}" for index in range(200)]:
            raise Gate1FinalizationError("LINEAGE_RUN_SET_INVALID")
        return rows

    def _finalize_configuration_record(
        self,
        local_pass_id: int,
        record: Mapping[str, Any],
        child: Mapping[str, Any],
    ) -> dict[str, Any]:
        if not self._historical_audit:
            validate(self._control_context, child, 'normal_finalization')
            validate_frame(self._control_context, child, record.get('successor_evidence_frame'), 'normal_finalization')
        native_contract=record.get("stage12",{}).get("native_cost_contract")
        native_present="native_packages" in record
        expected_record={
            "configuration_id",
            "events",
            "stage12",
            "stage13_complete",
        }
        if native_contract or native_present:
            expected_record |= {"native_packages","native_close_frames"}
        if set(record) != expected_record:
            raise Gate1FinalizationError("CONFIGURATION_COMPLETION_INCOMPLETE")
        configuration_id = record["configuration_id"]
        if not isinstance(configuration_id, int):
            raise Gate1FinalizationError("CONFIGURATION_ID_MISSING")
        stage12 = record["stage12"]
        stage13 = record["stage13_complete"]
        if native_contract or native_present:
            if native_contract!="NATIVE_COST_BOUNDARY_V2" or not child.get("manifest_sha256"):
                raise Gate1FinalizationError("NATIVE_COST_CONTRACT_UNBOUND")
            try:
                NativeCostArchiveConsumer.validate_packages(
                    record["native_packages"],
                    dict(run=child["manifest_sha256"],configuration=configuration_id,
                         branch=child["branch"],partition=child["partition"],package_schema='NATIVE_COST_BOUNDARY_PACKAGE_V2'),
                    boundary_count=int(stage12["boundary_finalization_count"]),
                    close_frames=record["native_close_frames"])
            except (ValueError,KeyError) as exc:
                raise Gate1FinalizationError(f"NATIVE_COST_EVIDENCE_INVALID:{exc}") from exc
        if (
            int(stage12.get("config", -1)) != configuration_id
            or stage12.get("branch") != child["branch"]
            or stage12.get("partition") != child["partition"]
            or stage12.get("complete") != "1"
            or stage13.get("complete") != "1"
        ):
            raise Gate1FinalizationError("FRAME_SCOPE_CONFLICT")
        event_count = int(stage13.get("event_count", -1))
        events = record["events"]
        if sorted(events) != list(range(1, event_count + 1)):
            raise Gate1FinalizationError("ACCOUNTING_EVENT_SEQUENCE_INVALID")
        ordered_events = [events[index] for index in range(1, event_count + 1)]
        observed_roots: set[str] = set()
        previous_server_time = 0
        required_event_fields = {
            "sequence",
            "event_type",
            "server_time_msc",
            "net",
            "net_return",
            "net_r",
            "root",
        }
        for index, event in enumerate(ordered_events, start=1):
            if set(event) != required_event_fields:
                raise Gate1FinalizationError("ACCOUNTING_EVENT_SCHEMA_INVALID")
            if int(event.get("sequence", -1)) != index:
                raise Gate1FinalizationError("ACCOUNTING_EVENT_SEQUENCE_INVALID")
            try:
                server_time = int(event.get("server_time_msc", -1))
            except (TypeError, ValueError) as exc:
                raise Gate1FinalizationError("ACCOUNTING_EVENT_TIME_INVALID") from exc
            if server_time <= 0 or server_time < previous_server_time:
                raise Gate1FinalizationError("ACCOUNTING_EVENT_TIME_INVALID")
            previous_server_time = server_time
            root = str(event.get("root", ""))
            if re.fullmatch(r"[0-9A-F]{64}", root) is None:
                raise Gate1FinalizationError("ACCOUNTING_EVENT_ROOT_INVALID")
            if root in observed_roots:
                raise Gate1FinalizationError("ACCOUNTING_LEDGER_ROOT_REPEAT")
            observed_roots.add(root)
        expected_final_root = ordered_events[-1]["root"] if ordered_events else ""
        if stage13.get("root") != expected_final_root:
            raise Gate1FinalizationError("ACCOUNTING_FINAL_ROOT_MISMATCH")

        entries = int(stage12.get("entries", -1))
        exits = int(stage12.get("exits", -1))
        hard_failures = int(stage12.get("hard_failures", -1))
        if min(entries, exits, hard_failures) < 0:
            raise Gate1FinalizationError("STAGE12_COUNT_INVALID")
        close_events = [event for event in ordered_events if event.get("event_type") == "9"]
        if (
            int(stage13.get("close_count", -1)) != len(close_events)
            or int(stage13.get("trade_return_count", -1)) != len(close_events)
        ):
            raise Gate1FinalizationError("ACCOUNTING_TRADE_COUNT_MISMATCH")
        stage12_returns = self._decimal12_list(
            stage12.get("trade_returns", ""), "STAGE12_NET_RETURN_INVALID"
        )
        stage12_r = self._decimal12_list(
            stage12.get("trade_r", ""), "STAGE12_NET_R_INVALID"
        )
        close_returns = [
            self._decimal12(event.get("net_return", ""), "STAGE13_NET_RETURN_INVALID")
            for event in close_events
        ]
        close_r = [
            self._decimal12(event.get("net_r", ""), "STAGE13_NET_R_INVALID")
            for event in close_events
        ]
        if stage12_returns != close_returns:
            raise Gate1FinalizationError("ACCOUNTING_NET_RETURN_MISMATCH")
        if stage12_r != close_r:
            raise Gate1FinalizationError("ACCOUNTING_FIXED_R_MISMATCH")
        close_net = sum(
            (
                self._decimal12(event.get("net", ""), "STAGE13_NET_AMOUNT_INVALID")
                for event in close_events
            ),
            Decimal("0.000000000000"),
        )
        legacy_net = self._decimal12(
            stage13.get("legacy_net", ""), "ACCOUNTING_LEGACY_NET_INVALID"
        )
        ledger_net = self._decimal12(
            stage13.get("ledger_net", ""), "ACCOUNTING_LEDGER_NET_INVALID"
        )
        if close_net != legacy_net or legacy_net != ledger_net:
            raise Gate1FinalizationError("ACCOUNTING_NET_AMOUNT_MISMATCH")

        compact: dict[str, Any] = {
            "configuration_id": configuration_id,
            "local_pass_id": local_pass_id,
            "partition": child["partition"],
            "branch": child["branch"],
            "entries": entries,
            "exits": exits,
            "trade_groups": len(close_events),
            "hard_failures": hard_failures,
            "valid": False,
            "trade_count": len(close_events),
            "mar": 0.0,
            "sortino": 0.0,
            "profit_factor": 0.0,
            "expectancy_mean_r": 0.0,
            "expectancy_lcb": 0.0,
            "max_drawdown_percent": 0.0,
            "ending_equity": 1000.0,
        }
        if close_events and hard_failures == 0:
            daily = self._decimal12_list(
                stage12.get("daily_returns", ""), "STAGE12_DAILY_RETURN_INVALID"
            )
            try:
                metrics = Stage12Pipeline.calculate_metrics(
                    trade_groups=[
                        {"net_return": float(net_return), "net_r": float(net_r)}
                        for net_return, net_r in zip(stage12_returns, stage12_r)
                    ],
                    broker_daily_returns=[float(value) for value in daily],
                )
            except Stage12Error as exc:
                raise Gate1FinalizationError(f"METRIC_CALCULATION_INVALID:{exc}") from exc
            compact.update(metrics)
            compact["valid"] = all(
                isinstance(metrics[key], (int, float))
                and math.isfinite(float(metrics[key]))
                for key in (
                    "mar",
                    "sortino",
                    "profit_factor",
                    "expectancy_lcb",
                    "max_drawdown_percent",
                )
            )
            if not compact["valid"]:
                for key, value in metrics.items():
                    if isinstance(value, float) and not math.isfinite(value):
                        compact[key] = 0.0
        return compact

    def _verify_archive(
        self, request: Gate1FinalizationRequest, row: Mapping[str, Any]
    ) -> list[dict[str, Any]]:
        run_id = str(row["run_id"])
        manifest_sha = str(row["manifest_sha256"])
        markers = list(Path(request.archive_root).glob(f"{run_id}_*.ARCHIVED.json"))
        if len(markers) != 1:
            raise Gate1FinalizationError(f"ARCHIVE_MARKER_NOT_UNIQUE:{run_id}")
        marker = self._read(markers[0])
        if (
            marker.get("status") != "ARCHIVED_VERIFIED"
            or marker.get("run_id") != run_id
            or marker.get("manifest_sha256") != manifest_sha
        ):
            raise Gate1FinalizationError(f"ARCHIVE_MARKER_CONFLICT:{run_id}")
        complete = self._read(
            Path(request.execution_root) / "children" / run_id / "COMPLETE.json"
        )
        if (
            complete.get("status") != "COMPLETE"
            or complete.get("run_id") != run_id
            or complete.get("manifest_sha256") != manifest_sha
        ):
            raise Gate1FinalizationError(f"COMPLETION_MARKER_CONFLICT:{run_id}")
        archive = Path(str(marker.get("archive_path", "")))
        if not archive.is_file() or self._sha256_file(archive) != marker.get("archive_sha256"):
            raise Gate1FinalizationError(f"ARCHIVE_HASH_MISMATCH:{run_id}")

        expected_file_count = int(marker.get("file_count", -1))
        sample_indexes = set(self._sample_indexes(expected_file_count))
        metadata = hashlib.sha256()
        samples: dict[str, str] = {}
        file_count = logical_bytes = 0
        previous_name = ""
        current_pass: int | None = None
        current_record: dict[str, Any] | None = None
        observed_passes: set[int] = set()
        results: list[dict[str, Any]] = []
        child = row["child"]
        with tarfile.open(archive, "r|gz") as handle:
            for member in handle:
                if member.isdir() and member.name in (".", "./"):
                    continue
                if not member.isfile():
                    raise Gate1FinalizationError("ARCHIVE_NON_REGULAR_MEMBER")
                name = self._safe_name(member.name)
                stream = handle.extractfile(member)
                if stream is None:
                    raise Gate1FinalizationError("ARCHIVE_MEMBER_UNREADABLE")
                data = stream.read()
                if len(data) != member.size:
                    raise Gate1FinalizationError("ARCHIVE_MEMBER_SIZE_MISMATCH")
                if previous_name and name <= previous_name:
                    raise Gate1FinalizationError("ARCHIVE_MEMBER_ORDER_OR_DUPLICATE_INVALID")
                previous_name = name
                metadata.update(name.encode() + b"\0" + str(member.size).encode() + b"\n")
                if file_count in sample_indexes:
                    samples[name] = hashlib.sha256(data).hexdigest().upper()
                file_count += 1
                logical_bytes += member.size
                matched = self._STAGE12.match(name)
                kind = "stage12"
                if matched is None:
                    matched = self._STAGE13_COMPLETE.match(name)
                    kind = "stage13_complete"
                if matched is None:
                    matched = self._STAGE13_EVENT.match(name)
                    kind = "stage13_event"
                if matched is None:
                    matched = self._NATIVE_COST.match(name)
                    kind = "native_package"
                if matched is None:
                    raise Gate1FinalizationError(f"UNEXPECTED_FRAME_NAME:{name}")
                pass_id, identifier = (int(value) for value in matched.groups())
                if current_pass != pass_id:
                    if current_record is not None and current_pass is not None:
                        results.append(
                            self._finalize_configuration_record(
                                current_pass, current_record, child
                            )
                        )
                    if pass_id in observed_passes:
                        raise Gate1FinalizationError("CONFIGURATION_FRAME_NOT_CONTIGUOUS")
                    observed_passes.add(pass_id)
                    current_pass = pass_id
                    current_record = {"events": {}, "configuration_id": None}
                assert current_record is not None
                record = current_record
                if kind=="native_package":
                    if record["configuration_id"] is not None and record["configuration_id"]!=identifier:
                        raise Gate1FinalizationError("FRAME_CONFIGURATION_ID_CONFLICT")
                    record["configuration_id"]=identifier
                    record.setdefault("native_packages",[]).append(data.decode('utf-8'))
                    record.setdefault("native_close_frames",[])
                    continue
                payload = (
                    self._parse_accounting_event(data)
                    if kind == "stage13_event"
                    else self._parse_payload(data)
                )
                if kind in record and kind != "stage13_event":
                    raise Gate1FinalizationError("DUPLICATE_COMPLETION_FRAME")
                if kind == "stage13_event":
                    if identifier in record["events"]:
                        raise Gate1FinalizationError("DUPLICATE_ACCOUNTING_EVENT")
                    record["events"][identifier] = payload
                    if "native_packages" in record and payload.get("event_type")=="9":
                        record["native_close_frames"].append(data.decode('utf-8').strip())
                else:
                    if record["configuration_id"] is None:
                        record["configuration_id"] = identifier
                    elif record["configuration_id"] != identifier:
                        raise Gate1FinalizationError("FRAME_CONFIGURATION_ID_CONFLICT")
                    record[kind] = payload
                    if kind=="stage12" and payload.get("native_cost_contract"):
                        record.setdefault("native_packages",[])
                        record.setdefault("native_close_frames",[])
        if current_record is not None and current_pass is not None:
            results.append(
                self._finalize_configuration_record(current_pass, current_record, child)
            )
        checks = {
            "file_count": file_count,
            "logical_bytes": logical_bytes,
            "metadata_sha256": metadata.hexdigest().upper(),
            "sample_count": len(samples),
            "sample_set_sha256": hashlib.sha256(
                json.dumps(samples, sort_keys=True).encode()
            )
            .hexdigest()
            .upper(),
        }
        if any(marker.get(key) != value for key, value in checks.items()):
            raise Gate1FinalizationError(f"ARCHIVE_READBACK_MISMATCH:{run_id}")

        expected = set(range(int(child["configuration_start"]), int(child["configuration_end"]) + 1))
        if {int(result["configuration_id"]) for result in results} != expected:
            raise Gate1FinalizationError(f"CONFIGURATION_FRAME_SET_INCOMPLETE:{run_id}")
        return results

    def _verify_archive_inventory(
        self, request: Gate1FinalizationRequest, rows: list[Mapping[str, Any]]
    ) -> dict[str, Any]:
        governed: set[Path] = set()
        for row in rows:
            markers = list(
                Path(request.archive_root).glob(f"{row['run_id']}_*.ARCHIVED.json")
            )
            if len(markers) != 1:
                raise Gate1FinalizationError(
                    f"ARCHIVE_MARKER_NOT_UNIQUE:{row['run_id']}"
                )
            governed.add(Path(str(self._read(markers[0])["archive_path"])).resolve())
        all_archives = {
            path.resolve() for path in Path(request.archive_root).glob("*.tar.gz")
        }
        extras = sorted(all_archives - governed)
        verified_invalidated: list[str] = []
        invalidation_records = list(
            Path(request.execution_root).glob(
                "invalidated_attempts/**/INVALIDATED_INFRASTRUCTURE.json"
            )
        )
        by_archive: dict[Path, dict[str, Any]] = {}
        for path in invalidation_records:
            record = self._read(path)
            archive_path = record.get("archive_path")
            if archive_path:
                by_archive[Path(str(archive_path)).resolve()] = record
        for archive in extras:
            record = by_archive.get(archive)
            if (
                record is None
                or record.get("status") != "INVALIDATED_INFRASTRUCTURE"
                or record.get("selection_eligible") is not False
                or self._sha256_file(archive) != record.get("archive_sha256")
            ):
                raise Gate1FinalizationError(f"UNEXPLAINED_EXTRA_ARCHIVE:{archive}")
            verified_invalidated.append(str(archive))
        return {
            "governed_archive_count": len(governed),
            "preserved_invalidated_archive_count": len(verified_invalidated),
            "preserved_invalidated_archives": verified_invalidated,
        }

    def _prepare_diagnostic_root(
        self,
        request: Gate1FinalizationRequest,
        anomaly_sha256: str,
    ) -> dict[str, Any]:
        prior = self._read(Path(request.prior_package) / "GATE1_ROOT.json")
        continuation = self._read(
            Path(request.continuation_package) / "GATE1_ROOT.json"
        )
        default_id = Stage12Pipeline().default_configuration_id
        synthetic_fixture = {
            "schema": 1,
            "kind": "DETERMINISTIC_SYNTHETIC_TREND_FIXTURE_CONTRACT",
            "bar_period_seconds": 1800,
            "h4_alignment_epoch_seconds": 14400,
            "closed_bars_only": True,
            "warmup_calendar_days": 90,
            "construction": "MONOTONIC_STEP_TREND_WITH_STRICT_BREAKOUT_AND_CONFIRMED_M30_H4_SUPERTREND",
            "required_truths": [
                "REGIME_TRENDING",
                "VOLATILITY_NORMAL_OR_HIGH",
                "STRICT_BREAKOUT_FRESH",
                "M30_H4_DIRECTION_AGREE",
                "TECHNICAL_STOP_VALID",
            ],
            "performance_outputs": False,
        }
        synthetic_fixture_sha256 = self.canonical_hash(synthetic_fixture)
        children = [
            {
                "diagnostic": "SYNTHETIC_TREND",
                "source": "DETERMINISTIC_SYNTHETIC_CLOSED_BARS",
                "source_fixture_sha256": synthetic_fixture_sha256,
                "branch": "SYNTHETIC",
                "partition": "NONE",
                "execution": "CONTRACT_HARNESS_NO_ORDERS",
            },
            {
                "diagnostic": "FOLD_1_TRAIN_RECORDED",
                "source": "GOVERNED_DEVELOPMENT_HISTORY",
                "branch": "RECORDED",
                "partition": "FOLD_1_TRAIN",
                "execution": "TESTER_FUNNEL_NO_ORDERS",
            },
            {
                "diagnostic": "FOLD_1_TRAIN_RSB3",
                "source": "GOVERNED_DEVELOPMENT_HISTORY",
                "branch": "RSB3",
                "partition": "FOLD_1_TRAIN",
                "execution": "TESTER_FUNNEL_NO_ORDERS",
            },
        ]
        for child in children:
            child["manifest_sha256"] = self.canonical_hash(child)
        root = {
            "schema": 1,
            "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_ROOT",
            "status": "PLANNED",
            "owner_approved": False,
            "candidate_id": prior.get("candidate_id", "TEST-CANDIDATE"),
            "configuration_id": default_id,
            "candidate_budget_before": 1,
            "candidate_budget_increment": 0,
            "prior_root_sha256": prior["root_sha256"],
            "continuation_root_sha256": continuation["root_sha256"],
            "anomaly_sha256": anomaly_sha256,
            "synthetic_fixture": synthetic_fixture,
            "synthetic_fixture_sha256": synthetic_fixture_sha256,
            "signals_exposed": "COUNTS_AND_IDENTITIES_ONLY",
            "returns_emitted": False,
            "ranking_authorized": False,
            "orders_authorized": False,
            "oos_authorized": False,
            "holdout_authorized": False,
            "required_funnel_counts": [
                "closed_bars",
                "healthy_regimes",
                "breakout_intents",
                "safety_approvals",
                "safety_rejections",
                "order_attempts",
                "fills",
                "accounting_completions",
            ],
            "children": children,
        }
        root["root_sha256"] = self.canonical_hash(root)
        return root

    @staticmethod
    def _is_fixture(rows: list[Mapping[str, Any]]) -> bool:
        return len(rows) != 200

    def _validate_cardinality(
        self,
        rows: list[Mapping[str, Any]],
        results: list[Mapping[str, Any]],
    ) -> None:
        if self._is_fixture(rows):
            return
        allowed_partitions = {
            "FOLD_1_TRAIN",
            "FOLD_2_TRAIN",
            "FOLD_3_TRAIN",
            "FOLD_4_TRAIN",
            "FINAL_SELECTION",
        }
        if len(rows) != 200 or len(results) != 194_400:
            raise Gate1FinalizationError("GATE1_PRODUCTION_CARDINALITY_INVALID")
        sizes = [
            int(row["child"]["configuration_end"])
            - int(row["child"]["configuration_start"])
            + 1
            for row in rows
        ]
        if sizes.count(1000) != 190 or sizes.count(440) != 10:
            raise Gate1FinalizationError("GATE1_CHUNK_CARDINALITY_INVALID")
        observed: dict[tuple[str, str], list[int]] = {}
        for result in results:
            partition = str(result["partition"])
            branch = str(result["branch"])
            if partition not in allowed_partitions or branch not in ("RECORDED", "RSB3"):
                raise Gate1FinalizationError("UNMANIFESTED_OR_PROHIBITED_PARTITION")
            observed.setdefault((partition, branch), []).append(
                int(result["configuration_id"])
            )
        expected = list(range(19_440))
        expected_keys = {
            (partition, branch)
            for partition in allowed_partitions
            for branch in ("RECORDED", "RSB3")
        }
        if set(observed) != expected_keys or any(
            sorted(identifiers) != expected for identifiers in observed.values()
        ):
            raise Gate1FinalizationError("GATE1_CONFIGURATION_COVERAGE_INVALID")

    def _partition_summary(
        self, results: list[Mapping[str, Any]]
    ) -> dict[str, dict[str, dict[str, int]]]:
        summary: dict[str, dict[str, dict[str, int]]] = {}
        for row in results:
            counters = summary.setdefault(str(row["partition"]), {}).setdefault(
                str(row["branch"]),
                {
                    "evaluated_configurations": 0,
                    "entries": 0,
                    "exits": 0,
                    "trade_groups": 0,
                    "hard_failures": 0,
                },
            )
            counters["evaluated_configurations"] += 1
            counters["entries"] += int(row["entries"])
            counters["exits"] += int(row["exits"])
            counters["trade_groups"] += int(row["trade_groups"])
            counters["hard_failures"] += int(row["hard_failures"])
        return summary

    @staticmethod
    def _write_immutable(path: Path, value: Any) -> dict[str, Any]:
        if path.exists():
            raise Gate1FinalizationError(f"APPEND_ONLY_TARGET_EXISTS:{path}")
        path.parent.mkdir(parents=True, exist_ok=True)
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
        path.write_bytes(encoded)
        return {
            "path": str(path),
            "size": len(encoded),
            "sha256": hashlib.sha256(encoded).hexdigest().upper(),
        }

    def _neighborhood_evidence(
        self,
        pipeline: Stage12Pipeline,
        metrics: list[Mapping[str, Any]],
    ) -> dict[int, dict[str, Any]]:
        by_key = {
            (int(row["configuration_id"]), str(row["branch"])): row
            for row in metrics
        }
        evidence: dict[int, dict[str, Any]] = {}
        for center in range(pipeline.configuration_count):
            neighbors = pipeline.neighbor_ids(center)
            qualifying = 0
            drawdown_veto = False
            for identifier in neighbors:
                branch_rows = [
                    by_key[(identifier, branch)] for branch in ("RECORDED", "RSB3")
                ]
                if any(
                    float(row["max_drawdown_percent"]) > 20.0
                    for row in branch_rows
                ):
                    drawdown_veto = True
                if all(
                    bool(row["valid"])
                    and float(row["expectancy_mean_r"]) > 0.0
                    and float(row["profit_factor"]) >= 1.20
                    for row in branch_rows
                ):
                    qualifying += 1
            fraction = qualifying / len(neighbors)
            passed = fraction >= 0.80 and not drawdown_veto
            evidence[center] = {
                "passed": passed,
                "reason": "PASS" if passed else "NEIGHBOR_GATE_FAIL",
                "qualifying_fraction": fraction,
                "qualifying_count": qualifying,
                "neighbor_count": len(neighbors),
                "drawdown_veto": drawdown_veto,
            }
        return evidence

    def _publish_scoring(
        self,
        request: Gate1FinalizationRequest,
        results: list[Mapping[str, Any]],
        evidence_files: list[dict[str, Any]],
    ) -> dict[str, Any]:
        pipeline = Stage12Pipeline()
        selections: dict[str, int] = {}
        selection_records: dict[str, Any] = {}
        surface_records: dict[str, Any] = {}
        partitions = [
            "FOLD_1_TRAIN",
            "FOLD_2_TRAIN",
            "FOLD_3_TRAIN",
            "FOLD_4_TRAIN",
            "FINAL_SELECTION",
        ]
        for partition in partitions:
            metrics = [dict(row) for row in results if row["partition"] == partition]
            scored = pipeline.score_configurations(metrics)
            neighborhoods = self._neighborhood_evidence(pipeline, metrics)
            combined = []
            metrics_by_config: dict[int, dict[str, dict[str, Any]]] = {}
            for metric_row in metrics:
                metrics_by_config.setdefault(
                    int(metric_row["configuration_id"]), {}
                )[str(metric_row["branch"])] = metric_row
            if set(metrics_by_config) != set(range(pipeline.configuration_count)) or any(
                set(branches) != {"RECORDED", "RSB3"}
                for branches in metrics_by_config.values()
            ):
                raise Gate1FinalizationError("SURFACE_BRANCH_METRICS_INCOMPLETE")
            for row in scored:
                identifier = int(row["configuration_id"])
                combined.append(
                    {
                        **row,
                        "branch_metrics": metrics_by_config[identifier],
                        "neighborhood": neighborhoods[identifier],
                    }
                )
            surface = pipeline.build_surface_evidence(combined)
            surface_dir = Path(request.output_root) / "surfaces" / partition
            heatmap_index = {}
            for key, heatmap in surface.pop("pairwise_heatmaps").items():
                artifact = self._write_immutable(
                    surface_dir / "heatmaps" / f"{key.replace('|', '__')}.json",
                    heatmap,
                )
                evidence_files.append(artifact)
                heatmap_index[key] = artifact
            surface_artifact = self._write_immutable(
                surface_dir / "SURFACE.json", surface
            )
            evidence_files.append(surface_artifact)
            surface_records[partition] = {
                "surface": surface_artifact,
                "heatmaps": heatmap_index,
                "surface_sha256": surface["surface_sha256"],
            }
            try:
                selected = pipeline.select_configuration(scored, neighborhoods)
            except Stage12Error as exc:
                if str(exc) == "NO_NEIGHBORHOOD_ELIGIBLE_CANDIDATES":
                    rejection = {
                        "schema": 1,
                        "status": "REJECTED",
                        "candidate_id": "CAND-ETH-ST-001",
                        "candidate_budget_consumed": 1,
                        "partition": partition,
                        "reason": str(exc),
                        "infrastructure_invalidated": False,
                    }
                    rejection["rejection_sha256"] = self.canonical_hash(rejection)
                    artifact = self._write_immutable(
                        Path(request.output_root) / "REJECTED.json", rejection
                    )
                    evidence_files.append(artifact)
                    return {"status": "REJECTED", "rejection": rejection}
                raise
            selection_records[partition] = {
                **selected,
                "parameters": pipeline.decode_configuration(
                    int(selected["configuration_id"])
                ),
                "neighborhood": neighborhoods[int(selected["configuration_id"])],
            }
            if partition.startswith("FOLD_"):
                selections[partition.replace("_TRAIN", "")] = int(
                    selected["configuration_id"]
                )

        selection_artifact = self._write_immutable(
            Path(request.output_root) / "selections" / "SELECTIONS.json",
            selection_records,
        )
        evidence_files.append(selection_artifact)
        return {
            "status": "DEVELOPMENT_COMPLETE_PENDING_OWNER_REVIEW",
            "selections": selections,
            "selection_records": selection_records,
            "selection_artifact": selection_artifact,
            "surface_records": surface_records,
        }

    def _prepare_gate2(
        self,
        request: Gate1FinalizationRequest,
        selections: Mapping[str, int],
        finalization_root_sha256: str,
    ) -> dict[str, Any]:
        continuation = self._read(
            Path(request.continuation_package) / "GATE1_ROOT.json"
        )
        common = {
            "artifact_hashes": continuation["artifact_hashes"],
            "mt5_build": continuation["mt5_build"],
            "account_fingerprint": continuation["account_fingerprint"],
            "operational_facts": continuation["operational_facts"],
        }
        coordinator = ResearchRunCoordinator()
        root = coordinator.prepare_gate_root(
            2,
            common,
            upstream_root_sha256=finalization_root_sha256,
            selections=selections,
            candidate_budget_before=1,
        )
        children = coordinator.materialize_children(root)
        gate2_dir = Path(request.output_root) / "gate2"
        child_records = []
        for child in children:
            artifact = self._write_immutable(
                gate2_dir / "children" / f"{child['run_id']}.json", child
            )
            child_records.append(
                {
                    "run_id": child["run_id"],
                    "manifest_sha256": child["manifest_sha256"],
                    **artifact,
                }
            )
        index = {
            "schema": 1,
            "kind": "GATE2_PLANNED_CHILD_INDEX",
            "root_sha256": root["root_sha256"],
            "child_count": len(children),
            "children": child_records,
        }
        index["index_sha256"] = self.canonical_hash(index)
        root_artifact = self._write_immutable(gate2_dir / "GATE2_ROOT.json", root)
        index_artifact = self._write_immutable(gate2_dir / "CHILD_INDEX.json", index)
        return {
            "root": root,
            "root_artifact": root_artifact,
            "index_artifact": index_artifact,
            "children": child_records,
        }

    @classmethod
    def historical_record_identity(cls, request: Gate1FinalizationRequest) -> str:
        """Hash the exact retained roots and indexes named by an audit caller."""
        prior = Path(request.prior_package)
        continuation = Path(request.continuation_package)
        value = {
            "prior_root": cls._read(prior / "GATE1_ROOT.json"),
            "prior_index_sha256": hashlib.sha256(
                (prior / "CHILD_INDEX.json").read_bytes()
            ).hexdigest().upper(),
            "continuation_root": cls._read(continuation / "GATE1_ROOT.json"),
            "continuation_index_sha256": hashlib.sha256(
                (continuation / "CHILD_INDEX.json").read_bytes()
            ).hexdigest().upper(),
        }
        return cls.canonical_hash(value)

    def _retired_audit_summary(
        self,
        request: Gate1FinalizationRequest,
        rows: list[Mapping[str, Any]],
        archive_inventory: Mapping[str, Any],
        results: list[dict[str, Any]],
    ) -> dict[str, Any]:
        self._validate_cardinality(rows, results)
        entries = sum(row["entries"] for row in results)
        trades = sum(row["trade_groups"] for row in results)
        result = {
            "schema": 1,
            "status": "RETIRED_HISTORICAL_AUDIT_PASS",
            "authority": "READ_ONLY_INTEGRITY_VERIFICATION",
            "evaluated_configuration_count": len(results),
            "entry_count": entries,
            "exit_count": sum(row["exits"] for row in results),
            "trade_group_count": trades,
            "hard_failure_count": sum(row["hard_failures"] for row in results),
            "partition_summary": self._partition_summary(results),
            "archive_inventory": dict(archive_inventory),
            "historical_classification": (
                "QUARANTINED_PENDING_DIAGNOSTIC"
                if entries == 0 or trades == 0
                else "INTEGRITY_VERIFIED_WITH_NONZERO_ACTIVITY"
            ),
            "candidate_budget_consumed": 0,
            "selection_emitted": False,
            "research_root_created": False,
            "gate2_prepared": False,
        }
        result["result_sha256"] = self.canonical_hash(result)
        return result

    def _retired_audit_finalize(
        self, request: Gate1FinalizationRequest
    ) -> dict[str, Any]:
        rows = self._epoch_rows(request)
        archive_inventory = self._verify_archive_inventory(request, rows)
        results: list[dict[str, Any]] = []
        for completed_archives, row in enumerate(rows, start=1):
            results.extend(self._verify_archive(request, row))
            if request.progress_callback is not None:
                request.progress_callback(
                    {
                        "run_id": row["run_id"],
                        "completed_archives": completed_archives,
                        "total_archives": len(rows),
                        "verified_configurations": len(results),
                    }
                )
        return self._retired_audit_summary(
            request, rows, archive_inventory, results
        )

    def finalize(self, request: Gate1FinalizationRequest) -> dict[str, Any]:
        if self._historical_audit:
            return self._retired_audit_finalize(request)
        raise SuccessorEvidenceError('normal_finalization', 'HISTORICAL_COMPATIBILITY_DEFAULT_DENY')
        output = Path(request.output_root)
        if output.exists() and any(output.iterdir()):
            raise Gate1FinalizationError("OUTPUT_ROOT_NOT_EMPTY")
        output.mkdir(parents=True, exist_ok=True)
        rows = self._epoch_rows(request)
        archive_inventory = self._verify_archive_inventory(request, rows)
        results: list[dict[str, Any]] = []
        for completed_archives, row in enumerate(rows, start=1):
            archive_results = self._verify_archive(request, row)
            results.extend(archive_results)
            if request.progress_callback is not None:
                request.progress_callback(
                    {
                        "run_id": row["run_id"],
                        "completed_archives": completed_archives,
                        "total_archives": len(rows),
                        "verified_configurations": len(results),
                    }
                )
        self._validate_cardinality(rows, results)
        entries = sum(row["entries"] for row in results)
        trades = sum(row["trade_groups"] for row in results)
        hard_failures = sum(row["hard_failures"] for row in results)
        partition_summary = self._partition_summary(results)
        lineage = {
            "schema": 1,
            "prior_root_sha256": self._read(
                Path(request.prior_package) / "GATE1_ROOT.json"
            )["root_sha256"],
            "continuation_root_sha256": self._read(
                Path(request.continuation_package) / "GATE1_ROOT.json"
            )["root_sha256"],
            "epoch_1_runs": [row["run_id"] for row in rows if row["epoch"] == 0],
            "epoch_2_runs": [row["run_id"] for row in rows if row["epoch"] == 1],
            "archive_inventory": archive_inventory,
        }
        lineage["lineage_sha256"] = self.canonical_hash(lineage)
        evidence_files = [
            self._write_immutable(output / "LINEAGE_INVENTORY.json", lineage),
            self._write_immutable(
                output / "INTEGRITY_INVENTORY.json",
                {
                    "schema": 1,
                    "status": "PASS",
                    "evaluated_configuration_count": len(results),
                    "partition_summary": partition_summary,
                    "candidate_budget_consumed": 1,
                },
            ),
        ]
        if entries == 0 or trades == 0:
            anomaly = {
                "schema": 1,
                "status": "QUARANTINED_PENDING_DIAGNOSTIC",
                "evaluated_configuration_count": len(results),
                "entry_count": entries,
                "exit_count": sum(row["exits"] for row in results),
                "trade_group_count": trades,
                "hard_failure_count": hard_failures,
                "partition_summary": partition_summary,
                "candidate_budget_consumed": 1,
                "archive_inventory": archive_inventory,
                "selection_emitted": False,
                "gate2_prepared": False,
                "reason": "ALL_CONFIGURATIONS_ZERO_ENTRY_OR_TRADE_GROUP",
            }
            anomaly["anomaly_sha256"] = self.canonical_hash(anomaly)
            anomaly_path = output / "ZERO_ENTRY_ANOMALY.json"
            evidence_files.append(self._write_immutable(anomaly_path, anomaly))
            diagnostic = self._prepare_diagnostic_root(
                request, anomaly["anomaly_sha256"]
            )
            diagnostic_path = output / "DIAGNOSTIC_ROOT.json"
            evidence_files.append(self._write_immutable(diagnostic_path, diagnostic))
            result = dict(anomaly)
            result["anomaly_report_path"] = str(anomaly_path)
            result["diagnostic_root_path"] = str(diagnostic_path)
            result["diagnostic_root_sha256"] = diagnostic["root_sha256"]
            result["evidence_files"] = evidence_files
            result["result_sha256"] = self.canonical_hash(result)
            result_path = output / "FINALIZATION_RESULT.json"
            self._write_immutable(result_path, result)
            return result
        scoring = self._publish_scoring(request, results, evidence_files)
        if scoring["status"] == "REJECTED":
            result = {
                "schema": 1,
                "status": "REJECTED",
                "candidate_budget_consumed": 1,
                "evidence_files": evidence_files,
            }
            result["result_sha256"] = self.canonical_hash(result)
            self._write_immutable(output / "FINALIZATION_RESULT.json", result)
            return result
        packet = {
            "schema": 1,
            "status": "DEVELOPMENT_COMPLETE_PENDING_OWNER_REVIEW",
            "candidate_id": "CAND-ETH-ST-001",
            "candidate_budget_consumed": 1,
            "lineage_sha256": lineage["lineage_sha256"],
            "selection_sha256": scoring["selection_artifact"]["sha256"],
            "surface_sha256": self.canonical_hash(scoring["surface_records"]),
            "evidence_files": evidence_files,
        }
        packet["finalization_root_sha256"] = self.canonical_hash(packet)
        packet_artifact = self._write_immutable(
            output / "FINALIZATION_PACKET.json", packet
        )
        gate2 = self._prepare_gate2(
            request, scoring["selections"], packet["finalization_root_sha256"]
        )
        result = {
            **packet,
            "finalization_packet_path": packet_artifact["path"],
            "gate2_root_path": gate2["root_artifact"]["path"],
            "gate2_root_sha256": gate2["root"]["root_sha256"],
            "gate2_child_count": len(gate2["children"]),
            "gate2_owner_approved": False,
        }
        result["result_sha256"] = self.canonical_hash(result)
        self._write_immutable(output / "FINALIZATION_RESULT.json", result)
        return result


    def _audit_binding(
        self,
        request: Gate1FinalizationRequest,
        rows: list[Mapping[str, Any]],
        archive_inventory: Mapping[str, Any],
    ) -> str:
        value = {
            "schema": 1,
            "kind": "GATE1_AUDIT_LINEAGE_BINDING",
            "prior_root_sha256": self._read(
                Path(request.prior_package) / "GATE1_ROOT.json"
            )["root_sha256"],
            "continuation_root_sha256": self._read(
                Path(request.continuation_package) / "GATE1_ROOT.json"
            )["root_sha256"],
            "runs": [
                {
                    "run_id": row["run_id"],
                    "epoch": row["epoch"],
                    "manifest_sha256": row["manifest_sha256"],
                }
                for row in rows
            ],
            "archive_inventory": dict(archive_inventory),
        }
        return self.canonical_hash(value)

    def _batch_rows(
        self,
        request: Gate1FinalizationRequest,
        batch_id: int,
        batch_size: int,
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
        if batch_size <= 0:
            raise Gate1FinalizationError("AUDIT_BATCH_SIZE_INVALID")
        rows = self._epoch_rows(request)
        fixture = self._is_fixture(rows)
        if not fixture and batch_size != 20:
            raise Gate1FinalizationError("AUDIT_PRODUCTION_BATCH_SIZE_MUST_BE_20")
        batch_count = math.ceil(len(rows) / batch_size)
        if batch_id < 1 or batch_id > batch_count:
            raise Gate1FinalizationError("AUDIT_BATCH_ID_INVALID")
        selected = rows[(batch_id - 1) * batch_size : batch_id * batch_size]
        if not selected:
            raise Gate1FinalizationError("AUDIT_BATCH_EMPTY")
        return rows, selected, {
            "batch_count": batch_count,
            "batch_id": batch_id,
            "batch_size": batch_size,
        }

    def _read_verified_shard(
        self,
        path: Path,
        expected_binding: str,
        expected_runs: list[Mapping[str, Any]],
        batch_id: int,
        batch_size: int,
    ) -> dict[str, Any]:
        shard = self._read(path)
        stored = str(shard.get("shard_sha256", ""))
        body = {key: value for key, value in shard.items() if key != "shard_sha256"}
        if self.canonical_hash(body) != stored:
            raise Gate1FinalizationError("AUDIT_SHARD_HASH_MISMATCH")
        expected_run_ids = [str(row["run_id"]) for row in expected_runs]
        expected_epochs = [int(row["epoch"]) for row in expected_runs]
        if (
            shard.get("kind") != "GATE1_AUDIT_SHARD"
            or shard.get("status") != "COMPLETE"
            or shard.get("batch_id") != batch_id
            or shard.get("batch_size") != batch_size
            or shard.get("lineage_binding_sha256") != expected_binding
            or shard.get("run_ids") != expected_run_ids
            or shard.get("epochs") != expected_epochs
            or not isinstance(shard.get("results"), list)
        ):
            raise Gate1FinalizationError("AUDIT_SHARD_CONTENT_CONFLICT")
        return shard

    def audit_batch(
        self,
        request: Gate1FinalizationRequest,
        shard_root: Path,
        batch_id: int,
        *,
        batch_size: int = 20,
    ) -> dict[str, Any]:
        if not self._historical_audit:
            raise SuccessorEvidenceError('ingestion', 'HISTORICAL_COMPATIBILITY_DEFAULT_DENY')
        rows, selected, batch = self._batch_rows(request, batch_id, batch_size)
        archive_inventory = self._verify_archive_inventory(request, rows)
        binding = self._audit_binding(request, rows, archive_inventory)
        shard_root = Path(shard_root)
        path = shard_root / f"BATCH-{batch_id:02d}.json"
        if path.exists():
            shard = self._read_verified_shard(
                path, binding, selected, batch_id, batch_size
            )
            return {
                "status": "COMPLETE_EXISTING",
                **batch,
                "run_ids": shard["run_ids"],
                "shard_path": str(path),
                "shard_sha256": shard["shard_sha256"],
            }
        results: list[dict[str, Any]] = []
        for completed, row in enumerate(selected, start=1):
            results.extend(self._verify_archive(request, row))
            if request.progress_callback is not None:
                request.progress_callback(
                    {
                        "batch_id": batch_id,
                        "completed_archives": completed,
                        "total_archives": len(selected),
                        "run_id": row["run_id"],
                        "verified_configurations": len(results),
                    }
                )
        expected_results = sum(
            int(row["child"]["configuration_end"])
            - int(row["child"]["configuration_start"])
            + 1
            for row in selected
        )
        if len(results) != expected_results:
            raise Gate1FinalizationError("AUDIT_BATCH_RESULT_CARDINALITY_INVALID")
        shard = {
            "schema": 1,
            "kind": "GATE1_AUDIT_SHARD",
            "status": "COMPLETE",
            **batch,
            "lineage_binding_sha256": binding,
            "run_ids": [row["run_id"] for row in selected],
            "epochs": [row["epoch"] for row in selected],
            "results": results,
            "partition_summary": self._partition_summary(results),
            "entry_count": sum(row["entries"] for row in results),
            "trade_group_count": sum(row["trade_groups"] for row in results),
            "hard_failure_count": sum(row["hard_failures"] for row in results),
        }
        shard["shard_sha256"] = self.canonical_hash(shard)
        artifact = self._write_immutable(path, shard)
        return {"status": "COMPLETE", **batch, "run_ids": shard["run_ids"], **artifact}

    def merge_batches(
        self,
        request: Gate1FinalizationRequest,
        shard_root: Path,
        *,
        batch_size: int = 20,
    ) -> dict[str, Any]:
        if not self._historical_audit:
            raise SuccessorEvidenceError('normal_finalization', 'HISTORICAL_COMPATIBILITY_DEFAULT_DENY')
        rows, _, batch = self._batch_rows(request, 1, batch_size)
        archive_inventory = self._verify_archive_inventory(request, rows)
        binding = self._audit_binding(request, rows, archive_inventory)
        shard_root = Path(shard_root)
        expected_paths = [
            shard_root / f"BATCH-{index:02d}.json"
            for index in range(1, batch["batch_count"] + 1)
        ]
        actual_paths = sorted(shard_root.glob("BATCH-*.json")) if shard_root.is_dir() else []
        if actual_paths != expected_paths:
            raise Gate1FinalizationError("AUDIT_SHARD_SET_INCOMPLETE")
        results: list[dict[str, Any]] = []
        for index, path in enumerate(expected_paths, start=1):
            selected = rows[(index - 1) * batch_size : index * batch_size]
            shard = self._read_verified_shard(
                path, binding, selected, index, batch_size
            )
            results.extend(shard["results"])
        return self._retired_audit_summary(
            request, rows, archive_inventory, results
        )

    def batch_status(
        self,
        request: Gate1FinalizationRequest,
        shard_root: Path,
        *,
        batch_size: int = 20,
    ) -> dict[str, Any]:
        if not self._historical_audit:
            raise SuccessorEvidenceError('normal_finalization', 'HISTORICAL_COMPATIBILITY_DEFAULT_DENY')
        rows, _, batch = self._batch_rows(request, 1, batch_size)
        archive_inventory = self._verify_archive_inventory(request, rows)
        binding = self._audit_binding(request, rows, archive_inventory)
        shard_root = Path(shard_root)
        completed: list[int] = []
        for index in range(1, batch["batch_count"] + 1):
            path = shard_root / f"BATCH-{index:02d}.json"
            if not path.exists():
                continue
            selected = rows[(index - 1) * batch_size : index * batch_size]
            self._read_verified_shard(path, binding, selected, index, batch_size)
            completed.append(index)
        remaining = [
            index for index in range(1, batch["batch_count"] + 1)
            if index not in completed
        ]
        return {
            **batch,
            "status": "AUDIT_COMPLETE" if not remaining else "PENDING",
            "completed_batches": completed,
            "remaining_batches": remaining,
            "next_batch_id": remaining[0] if remaining else None,
            "shard_root": str(shard_root),
        }

    def _publish_verified_results(
        self,
        request: Gate1FinalizationRequest,
        rows: list[Mapping[str, Any]],
        archive_inventory: Mapping[str, Any],
        results: list[dict[str, Any]],
    ) -> dict[str, Any]:
        output = Path(request.output_root)
        allowed_existing = {"audit_shards"}
        if output.exists() and any(
            path.name not in allowed_existing for path in output.iterdir()
        ):
            raise Gate1FinalizationError("OUTPUT_ROOT_NOT_EMPTY")
        output.mkdir(parents=True, exist_ok=True)
        self._validate_cardinality(rows, results)
        entries = sum(row["entries"] for row in results)
        trades = sum(row["trade_groups"] for row in results)
        hard_failures = sum(row["hard_failures"] for row in results)
        partition_summary = self._partition_summary(results)
        lineage = {
            "schema": 1,
            "prior_root_sha256": self._read(Path(request.prior_package) / "GATE1_ROOT.json")["root_sha256"],
            "continuation_root_sha256": self._read(Path(request.continuation_package) / "GATE1_ROOT.json")["root_sha256"],
            "epoch_1_runs": [row["run_id"] for row in rows if row["epoch"] == 0],
            "epoch_2_runs": [row["run_id"] for row in rows if row["epoch"] == 1],
            "archive_inventory": dict(archive_inventory),
        }
        lineage["lineage_sha256"] = self.canonical_hash(lineage)
        evidence_files = [
            self._write_immutable(output / "LINEAGE_INVENTORY.json", lineage),
            self._write_immutable(output / "INTEGRITY_INVENTORY.json", {
                "schema": 1, "status": "PASS", "evaluated_configuration_count": len(results),
                "partition_summary": partition_summary, "candidate_budget_consumed": 1,
            }),
        ]
        if entries == 0 or trades == 0:
            anomaly = {
                "schema": 1, "status": "QUARANTINED_PENDING_DIAGNOSTIC",
                "evaluated_configuration_count": len(results), "entry_count": entries,
                "exit_count": sum(row["exits"] for row in results), "trade_group_count": trades,
                "hard_failure_count": hard_failures, "partition_summary": partition_summary,
                "candidate_budget_consumed": 1, "archive_inventory": dict(archive_inventory),
                "selection_emitted": False, "gate2_prepared": False,
                "reason": "ALL_CONFIGURATIONS_ZERO_ENTRY_OR_TRADE_GROUP",
            }
            anomaly["anomaly_sha256"] = self.canonical_hash(anomaly)
            anomaly_path = output / "ZERO_ENTRY_ANOMALY.json"
            evidence_files.append(self._write_immutable(anomaly_path, anomaly))
            diagnostic = self._prepare_diagnostic_root(request, anomaly["anomaly_sha256"])
            diagnostic_path = output / "DIAGNOSTIC_ROOT.json"
            evidence_files.append(self._write_immutable(diagnostic_path, diagnostic))
            result = {**anomaly, "anomaly_report_path": str(anomaly_path),
                      "diagnostic_root_path": str(diagnostic_path),
                      "diagnostic_root_sha256": diagnostic["root_sha256"],
                      "evidence_files": evidence_files}
            result["result_sha256"] = self.canonical_hash(result)
            self._write_immutable(output / "FINALIZATION_RESULT.json", result)
            return result
        scoring = self._publish_scoring(request, results, evidence_files)
        if scoring["status"] == "REJECTED":
            result = {"schema": 1, "status": "REJECTED", "candidate_budget_consumed": 1,
                      "evidence_files": evidence_files}
            result["result_sha256"] = self.canonical_hash(result)
            self._write_immutable(output / "FINALIZATION_RESULT.json", result)
            return result
        packet = {"schema": 1, "status": "DEVELOPMENT_COMPLETE_PENDING_OWNER_REVIEW",
                  "candidate_id": "CAND-ETH-ST-001", "candidate_budget_consumed": 1,
                  "lineage_sha256": lineage["lineage_sha256"],
                  "selection_sha256": scoring["selection_artifact"]["sha256"],
                  "surface_sha256": self.canonical_hash(scoring["surface_records"]),
                  "evidence_files": evidence_files}
        packet["finalization_root_sha256"] = self.canonical_hash(packet)
        packet_artifact = self._write_immutable(output / "FINALIZATION_PACKET.json", packet)
        gate2 = self._prepare_gate2(request, scoring["selections"], packet["finalization_root_sha256"])
        result = {**packet, "finalization_packet_path": packet_artifact["path"],
                  "gate2_root_path": gate2["root_artifact"]["path"],
                  "gate2_root_sha256": gate2["root"]["root_sha256"],
                  "gate2_child_count": len(gate2["children"]), "gate2_owner_approved": False}
        result["result_sha256"] = self.canonical_hash(result)
        self._write_immutable(output / "FINALIZATION_RESULT.json", result)
        return result
