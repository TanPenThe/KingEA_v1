"""Read-only, streaming evidence audit for Gate 1's all-zero anomaly."""

from __future__ import annotations

import hashlib
import json
import re
import tarfile
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping


class Gate1ZeroEntryForensicsError(ValueError):
    pass


class Gate1ZeroEntryForensics:
    """Inspects accepted archives without extracting or reinterpreting results."""

    _STAGE12 = re.compile(r"^(\d+)_KINGEA_STAGE12_COMPLETE_(\d+)\.frame$")
    _STAGE13_COMPLETE = re.compile(r"^(\d+)_KINGEA_STAGE13_ACCOUNTING_COMPLETE_(\d+)\.frame$")
    _STAGE13_EVENT = re.compile(r"^(\d+)_KINGEA_STAGE13_ACCOUNTING_EVENT_(\d+)\.frame$")
    _LAUNCH_ARTIFACT = re.compile(r"(?:\.set|\.ini|\.ex5|\.mq5|terminal.*\.log)$", re.I)
    _EVENT_TYPES = {
        "1": ("ORDER", "order/execution adapter", "conditional trade-routing evidence"),
        "2": ("DEAL", "execution adapter", "trade-related accounting evidence"),
        "3": ("POSITION", "position reconciliation", "conditional position evidence"),
        "4": ("STOP_CHANGE", "protective-stop management", "conditional protection evidence"),
        "5": ("EXTERNAL_CASH_FLOW", "accounting importer", "non-strategy accounting evidence"),
        "6": ("VALUATION", "tester daily valuation", "non-trade accounting heartbeat"),
        "7": ("SAFETY", "safety/exposure management", "conditional safety evidence"),
        "8": ("MISSED_SIGNAL", "execution routing", "conditional unfilled-signal evidence"),
        "9": ("TRADE_GROUP_CLOSE", "closed-trade finalizer", "trade-group completion evidence"),
    }
    _TRADE_OR_ROUTING_TYPES = {"1", "2", "3", "4", "7", "8", "9"}

    @staticmethod
    def file_hash(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest().upper()

    @staticmethod
    def _read_json(path: Path) -> dict[str, Any]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise Gate1ZeroEntryForensicsError(f"JSON_INVALID:{path}") from exc
        if not isinstance(value, dict):
            raise Gate1ZeroEntryForensicsError(f"JSON_OBJECT_REQUIRED:{path}")
        return value

    @staticmethod
    def _safe_member(name: str) -> str:
        normalized = name[2:] if name.startswith("./") else name
        path = PurePosixPath(normalized)
        if not normalized or path.is_absolute() or ".." in path.parts or "\\" in name:
            raise Gate1ZeroEntryForensicsError("UNSAFE_ARCHIVE_MEMBER")
        return normalized

    @staticmethod
    def _fields(raw: bytes) -> dict[str, str]:
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise Gate1ZeroEntryForensicsError("FRAME_NOT_UTF8") from exc
        fields: dict[str, str] = {}
        for part in text.split("|"):
            if "=" not in part:
                raise Gate1ZeroEntryForensicsError("FRAME_MALFORMED")
            key, value = part.split("=", 1)
            if not key or key in fields:
                raise Gate1ZeroEntryForensicsError("FRAME_MALFORMED")
            fields[key] = value
        return fields

    def scan_archive(self, marker_path: Path, child: Mapping[str, Any]) -> dict[str, Any]:
        marker_path = Path(marker_path)
        if "_INVALIDATED" in marker_path.name.upper():
            raise Gate1ZeroEntryForensicsError("INVALIDATED_ARCHIVE_NOT_ACCEPTED")
        marker = self._read_json(marker_path)
        run_id = str(child.get("run_id", ""))
        if (
            marker.get("status") != "ARCHIVED_VERIFIED"
            or marker.get("run_id") != run_id
            or marker.get("manifest_sha256") != child.get("manifest_sha256")
        ):
            raise Gate1ZeroEntryForensicsError("ARCHIVE_MARKER_CONFLICT")
        archive = Path(str(marker.get("archive_path", "")))
        if not archive.is_file() or self.file_hash(archive) != marker.get("archive_sha256"):
            raise Gate1ZeroEntryForensicsError("ARCHIVE_HASH_MISMATCH")

        seen: set[str] = set()
        configurations: set[int] = set()
        entries = exits = hard_failures = stage12_frames = launch_artifacts = 0
        previous = ""
        with tarfile.open(archive, "r|gz") as handle:
            for member in handle:
                if member.isdir() and member.name in (".", "./"):
                    continue
                if not member.isfile():
                    raise Gate1ZeroEntryForensicsError("ARCHIVE_NON_REGULAR_MEMBER")
                name = self._safe_member(member.name)
                if name <= previous or name in seen:
                    raise Gate1ZeroEntryForensicsError("ARCHIVE_MEMBER_DUPLICATE_OR_UNORDERED")
                previous = name
                seen.add(name)
                if self._LAUNCH_ARTIFACT.search(name):
                    launch_artifacts += 1
                matched = self._STAGE12.fullmatch(name)
                if matched is None:
                    continue
                stream = handle.extractfile(member)
                if stream is None:
                    raise Gate1ZeroEntryForensicsError("ARCHIVE_MEMBER_UNREADABLE")
                fields = self._fields(stream.read())
                config = int(fields.get("config", "-1"))
                if (
                    config in configurations
                    or config != int(matched.group(2))
                    or fields.get("branch") != child.get("branch")
                    or fields.get("partition") != child.get("partition")
                    or fields.get("complete") != "1"
                ):
                    raise Gate1ZeroEntryForensicsError("STAGE12_FRAME_SCOPE_CONFLICT")
                configurations.add(config)
                try:
                    entries += int(fields["entries"])
                    exits += int(fields["exits"])
                    hard_failures += int(fields["hard_failures"])
                except (KeyError, ValueError) as exc:
                    raise Gate1ZeroEntryForensicsError("STAGE12_FRAME_COUNTER_INVALID") from exc
                stage12_frames += 1

        expected = set(range(int(child["configuration_start"]), int(child["configuration_end"]) + 1))
        if configurations != expected:
            raise Gate1ZeroEntryForensicsError("STAGE12_CONFIGURATION_RANGE_INCOMPLETE")
        invalidated_partial_present = (marker_path.parent / f"{marker_path.stem.replace('.ARCHIVED', '')}_INVALIDATED.tar.gz").is_file()
        return {
            "run_id": run_id,
            "archive_sha256": marker["archive_sha256"],
            "stage12_frames": stage12_frames,
            "entries": entries,
            "exits": exits,
            "hard_failures": hard_failures,
            "launch_artifacts": launch_artifacts,
            "invalidated_partial_present": invalidated_partial_present,
        }

    @staticmethod
    def _stage13_fields(raw: bytes) -> dict[str, str]:
        """Parse the retained compact event payload; event_id may itself contain pipes."""
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise Gate1ZeroEntryForensicsError("STAGE13_EVENT_NOT_UTF8") from exc
        match = re.fullmatch(
            r"schema=1\|sequence=(\d+)\|event_id=(.+)\|event_type=(\d+)"
            r"\|server_time_msc=(\d+)\|sleeve=([^|]*)\|group=([^|]*)\|order=(\d+)"
            r"\|deal=(\d+)\|position=(\d+)\|gross=(-?\d+\.\d{12})"
            r"\|commission=(-?\d+\.\d{12})\|swap=(-?\d+\.\d{12})"
            r"\|fee=(-?\d+\.\d{12})\|net=(-?\d+\.\d{12})"
            r"\|net_return=(-?\d+\.\d{12})\|net_r=(-?\d+\.\d{12})"
            r"\|mae_r=(-?\d+\.\d{12})\|mfe_r=(-?\d+\.\d{12})"
            r"\|bars_held=(\d+)\|root=([0-9A-F]{64})",
            text,
        )
        if match is None:
            raise Gate1ZeroEntryForensicsError("STAGE13_EVENT_SCHEMA_INVALID")
        values = match.groups()
        return {"sequence": values[0], "event_id": values[1], "event_type": values[2],
                "server_time_msc": values[3], "sleeve": values[4], "group": values[5],
                "order": values[6], "deal": values[7], "position": values[8], "root": values[-1]}

    @staticmethod
    def _stage13_complete_fields(raw: bytes) -> dict[str, str]:
        fields = Gate1ZeroEntryForensics._fields(raw)
        required = {"schema", "event_count", "close_count", "trade_return_count", "legacy_net", "ledger_net", "root", "complete"}
        if set(fields) != required or fields.get("schema") != "1" or fields.get("complete") != "1":
            raise Gate1ZeroEntryForensicsError("STAGE13_COMPLETE_SCHEMA_INVALID")
        if fields["root"] and re.fullmatch(r"[0-9A-F]{64}", fields["root"]) is None:
            raise Gate1ZeroEntryForensicsError("STAGE13_COMPLETE_ROOT_INVALID")
        try:
            for name in ("event_count", "close_count", "trade_return_count"):
                if int(fields[name]) < 0:
                    raise ValueError(name)
        except ValueError as exc:
            raise Gate1ZeroEntryForensicsError("STAGE13_COMPLETE_COUNT_INVALID") from exc
        return fields

    def scan_stage13_archive(self, marker_path: Path, child: Mapping[str, Any]) -> dict[str, Any]:
        """Validate retained Stage 13 chains without treating absent upstream events as defects."""
        marker_path = Path(marker_path)
        if "_INVALIDATED" in marker_path.name.upper():
            raise Gate1ZeroEntryForensicsError("INVALIDATED_ARCHIVE_NOT_ACCEPTED")
        marker = self._read_json(marker_path)
        if (
            marker.get("status") != "ARCHIVED_VERIFIED"
            or marker.get("run_id") != child.get("run_id")
            or marker.get("manifest_sha256") != child.get("manifest_sha256")
        ):
            raise Gate1ZeroEntryForensicsError("ARCHIVE_MARKER_CONFLICT")
        archive = Path(str(marker.get("archive_path", "")))
        if not archive.is_file() or self.file_hash(archive) != marker.get("archive_sha256"):
            raise Gate1ZeroEntryForensicsError("ARCHIVE_HASH_MISMATCH")
        event_types: Counter[str] = Counter()
        routing_counts: Counter[str] = Counter()
        sleeves: Counter[str] = Counter()
        unknown_types: set[str] = set()
        configuration_classes: Counter[str] = Counter()
        class_ids: dict[str, list[int]] = {}
        root_binding: Counter[str] = Counter()
        crypto_verification: Counter[str] = Counter()
        nontrade_other_ids: list[int] = []
        configurations = 0
        completed_configurations: set[int] = set()

        def finalize_configuration(config: int, final: dict[str, str] | None,
                                   chain: dict[int, dict[str, str]]) -> None:
            nonlocal configurations
            if final is None or config in completed_configurations:
                raise Gate1ZeroEntryForensicsError("STAGE13_COMPLETE_MISSING_OR_DUPLICATE")
            count = int(final["event_count"])
            if sorted(chain) != list(range(1, count + 1)):
                raise Gate1ZeroEntryForensicsError("STAGE13_EVENT_SEQUENCE_INVALID")
            ordered = [chain[index] for index in range(1, count + 1)]
            if ordered and final["root"] != ordered[-1]["root"]:
                raise Gate1ZeroEntryForensicsError("STAGE13_FINAL_ROOT_MISMATCH")
            if not ordered and final["root"]:
                raise Gate1ZeroEntryForensicsError("STAGE13_EMPTY_ROOT_CONFLICT")
            prior_time = 0
            roots: set[str] = set()
            for event in ordered:
                if int(event["server_time_msc"]) < prior_time or event["root"] in roots:
                    raise Gate1ZeroEntryForensicsError("STAGE13_CHAIN_ORDER_OR_ROOT_INVALID")
                prior_time = int(event["server_time_msc"]); roots.add(event["root"])
                event_types[event["event_type"]] += 1
                if event["event_type"] not in self._EVENT_TYPES:
                    unknown_types.add(event["event_type"])
                if event["group"]:
                    routing_counts["events_with_group_id"] += 1
                if event["order"] != "0":
                    routing_counts["events_with_order_id"] += 1
                if event["deal"] != "0":
                    routing_counts["events_with_deal_id"] += 1
                if event["position"] != "0":
                    routing_counts["events_with_position_id"] += 1
                if event["sleeve"]:
                    sleeves[event["sleeve"]] += 1
            configurations += 1
            types = {event["event_type"] for event in ordered}
            if count == 0:
                classification = "ZERO_EVENT_COMPLETION"
                root_binding["ROOT_BINDING_NOT_APPLICABLE_ZERO_EVENT"] += 1
                crypto_verification["ROOT_CRYPTOGRAPHIC_NOT_APPLICABLE_ZERO_EVENT"] += 1
            elif types - set(self._EVENT_TYPES):
                classification = "UNKNOWN_EVENT_TYPE"
                root_binding["ROOT_BINDING_VALID"] += 1
                crypto_verification["ROOT_CRYPTOGRAPHIC_CHAIN_NOT_REPRODUCIBLE_FROM_RETAINED_EVIDENCE"] += 1
            elif types <= {"6"}:
                classification = "VALUATION_ONLY"
                root_binding["ROOT_BINDING_VALID"] += 1
                crypto_verification["ROOT_CRYPTOGRAPHIC_CHAIN_NOT_REPRODUCIBLE_FROM_RETAINED_EVIDENCE"] += 1
            elif types & self._TRADE_OR_ROUTING_TYPES:
                classification = "TRADE_OR_ROUTING_ACTIVITY_PRESENT"
                root_binding["ROOT_BINDING_VALID"] += 1
                crypto_verification["ROOT_CRYPTOGRAPHIC_CHAIN_NOT_REPRODUCIBLE_FROM_RETAINED_EVIDENCE"] += 1
            else:
                classification = "NON_TRADE_ACCOUNTING_ACTIVITY_ONLY"
                nontrade_other_ids.append(config)
                root_binding["ROOT_BINDING_VALID"] += 1
                crypto_verification["ROOT_CRYPTOGRAPHIC_CHAIN_NOT_REPRODUCIBLE_FROM_RETAINED_EVIDENCE"] += 1
            configuration_classes[classification] += 1
            class_ids.setdefault(classification, []).append(config)
            close_events = sum(1 for event in ordered if event["event_type"] == "9")
            if close_events != int(final["close_count"]) or close_events != int(final["trade_return_count"]):
                raise Gate1ZeroEntryForensicsError("STAGE13_CLOSE_COUNT_CONFLICT")
            completed_configurations.add(config)

        previous = ""
        current_config: int | None = None
        current_complete: dict[str, str] | None = None
        current_events: dict[int, dict[str, str]] = {}
        with tarfile.open(archive, "r|gz") as handle:
            for member in handle:
                if member.isdir() and member.name in (".", "./"):
                    continue
                if not member.isfile():
                    raise Gate1ZeroEntryForensicsError("ARCHIVE_NON_REGULAR_MEMBER")
                name = self._safe_member(member.name)
                if name <= previous:
                    raise Gate1ZeroEntryForensicsError("ARCHIVE_MEMBER_DUPLICATE_OR_UNORDERED")
                previous = name
                event_match = self._STAGE13_EVENT.fullmatch(name)
                complete_match = self._STAGE13_COMPLETE.fullmatch(name)
                if event_match is None and complete_match is None:
                    continue
                matched = event_match or complete_match
                config = int(child["configuration_start"]) + int(matched.group(1))
                if config > int(child["configuration_end"]):
                    raise Gate1ZeroEntryForensicsError("STAGE13_FRAME_SCOPE_CONFLICT")
                if current_config is not None and config != current_config:
                    finalize_configuration(current_config, current_complete, current_events)
                    current_complete = None; current_events = {}
                current_config = config
                stream = handle.extractfile(member)
                if stream is None:
                    raise Gate1ZeroEntryForensicsError("ARCHIVE_MEMBER_UNREADABLE")
                if event_match is not None:
                    payload = self._stage13_fields(stream.read())
                    sequence = int(payload["sequence"])
                    if sequence != int(event_match.group(2)) or sequence in current_events:
                        raise Gate1ZeroEntryForensicsError("STAGE13_EVENT_SEQUENCE_INVALID")
                    current_events[sequence] = payload
                else:
                    if int(complete_match.group(2)) != config or current_complete is not None:
                        raise Gate1ZeroEntryForensicsError("STAGE13_FRAME_SCOPE_CONFLICT")
                    current_complete = self._stage13_complete_fields(stream.read())
        if current_config is not None:
            finalize_configuration(current_config, current_complete, current_events)
        expected = set(range(int(child["configuration_start"]), int(child["configuration_end"]) + 1))
        if completed_configurations != expected:
            raise Gate1ZeroEntryForensicsError("STAGE13_COMPLETE_MISSING")
        if configuration_classes["UNKNOWN_EVENT_TYPE"]:
            boundary = "EVENT_TYPE_SEMANTICS_NOT_AFFIRMATIVELY_BOUND"
        elif configuration_classes["TRADE_OR_ROUTING_ACTIVITY_PRESENT"]:
            boundary = "RETAINED_STAGE13_TRADE_OR_ROUTING_ACTIVITY_PRESENT"
        elif configuration_classes["ZERO_EVENT_COMPLETION"] == configurations:
            boundary = "ALL_CONFIGURATIONS_ZERO_STAGE13_EVENTS"
        elif configuration_classes["VALUATION_ONLY"] == configurations:
            boundary = "ALL_CONFIGURATIONS_VALUATION_ONLY"
        elif (configuration_classes["ZERO_EVENT_COMPLETION"] + configuration_classes["VALUATION_ONLY"] == configurations):
            boundary = "NO_RETAINED_TRADE_ACTIVITY_MIXED_ZERO_AND_VALUATION"
        else:
            boundary = "NON_TRADE_ACCOUNTING_ACTIVITY_PRESENT"
        return {"run_id": child["run_id"], "integrity": "VALID", "configurations": configurations,
                "event_type_counts": dict(sorted(event_types.items())), "retained_boundary": boundary,
                "configuration_class_counts": dict(sorted(configuration_classes.items())),
                "configuration_ids_by_class": {name: values for name, values in sorted(class_ids.items())
                                               if name in {"TRADE_OR_ROUTING_ACTIVITY_PRESENT", "UNKNOWN_EVENT_TYPE"}},
                "non_trade_accounting_configuration_count": len(nontrade_other_ids),
                "root_binding_counts": dict(sorted(root_binding.items())),
                "root_cryptographic_counts": dict(sorted(crypto_verification.items())),
                "routing_counts": dict(sorted(routing_counts.items())), "events_by_sleeve": dict(sorted(sleeves.items())),
                "unknown_event_types": sorted(unknown_types),
                "unavailable": ["PARENT_EVENT_IDS_NOT_RETAINED", "UPSTREAM_CLASSIFIER_AND_SLEEVE_EVENTS_NOT_RETAINED"]}

    @staticmethod
    def governed_children(
        replacement_children: Path,
        continuation_children: Path,
    ) -> dict[str, dict[str, Any]]:
        """Load the two approved build epochs without inventing a third lineage."""
        children: dict[str, dict[str, Any]] = {}
        for directory, low, high, root in (
            (Path(replacement_children), 0, 119,
             "04AB5A4F1F2E078ACAEE0370ED23F22FB3C4FF872309231F69A2BFD5FF8BA795"),
            (Path(continuation_children), 120, 199,
             "B59D8052C11D732503147210703C2DA0402106B0012A6DE5E7FC5346E099E6EF"),
        ):
            for number in range(low, high + 1):
                run_id = f"G1-{number:04d}"
                child = Gate1ZeroEntryForensics._read_json(directory / f"{run_id}.json")
                if child.get("run_id") != run_id or child.get("root_sha256") != root:
                    raise Gate1ZeroEntryForensicsError("GOVERNED_CHILD_LINEAGE_CONFLICT")
                if child.get("purpose") != "DEVELOPMENT" or child.get("partition", "").startswith(("OOS", "HOLDOUT")):
                    raise Gate1ZeroEntryForensicsError("GOVERNED_CHILD_SCOPE_CONFLICT")
                children[run_id] = child
        return children

    @staticmethod
    def marker_for_run(archive_dir: Path, run_id: str) -> Path:
        """Resolve through the governed marker—not a tarball glob—and reject ambiguity."""
        matches: list[Path] = []
        for marker_path in Path(archive_dir).glob(f"{run_id}_*.ARCHIVED.json"):
            if "_INVALIDATED" in marker_path.name.upper():
                continue
            marker = Gate1ZeroEntryForensics._read_json(marker_path)
            if marker.get("run_id") == run_id:
                matches.append(marker_path)
        if len(matches) != 1:
            raise Gate1ZeroEntryForensicsError("GOVERNED_ARCHIVE_MARKER_MISSING_OR_AMBIGUOUS")
        return matches[0]

    @staticmethod
    def _historical_facts(child: Mapping[str, Any]) -> dict[str, Any]:
        hashes = child.get("artifact_hashes", {})
        if not isinstance(hashes, Mapping):
            raise Gate1ZeroEntryForensicsError("CHILD_ARTIFACT_HASHES_INVALID")
        return {
            "root_sha256": child.get("root_sha256"),
            "mt5_build": child.get("mt5_build"),
            "manifest_sha256": child.get("manifest_sha256"),
            "authorization": child.get("authorization_sha256", "NOT_RECORDED_IN_CHILD"),
            "execution_adapter": child.get("execution_adapter"),
            "execution_mode": child.get("execution_mode"),
            "scenario": child.get("scenario"),
            "purpose": child.get("purpose"),
            "source": hashes.get("source", "NOT_RECORDED"),
            "tester_ea": hashes.get("tester_ea", "NOT_RECORDED"),
            "pipeline": hashes.get("pipeline", "NOT_RECORDED"),
            "calendar": hashes.get("calendar", "NOT_RECORDED"),
            "research_specification": hashes.get("research_specification", "NOT_RECORDED"),
            "cost": hashes.get("cost", "NOT_RECORDED"),
        }

    def audit_batch(
        self,
        *,
        replacement_children: Path,
        continuation_children: Path,
        archive_dir: Path,
        run_ids: Iterable[str],
        diagnostic_result: Path,
    ) -> dict[str, Any]:
        """Audit a bounded archival batch. It never launches MT5 or makes a selection."""
        children = self.governed_children(replacement_children, continuation_children)
        result = self._read_json(Path(diagnostic_result))
        if result.get("status") != "QUARANTINED_PENDING_ROOT_CAUSE_REVIEW":
            raise Gate1ZeroEntryForensicsError("DIAGNOSTIC_RESULT_SCOPE_CONFLICT")
        requested = list(run_ids)
        if not requested or len(set(requested)) != len(requested):
            raise Gate1ZeroEntryForensicsError("AUDIT_BATCH_RUN_IDS_INVALID")
        reports: list[dict[str, Any]] = []
        totals = {"stage12_frames": 0, "entries": 0, "exits": 0, "hard_failures": 0, "launch_artifacts": 0}
        for run_id in requested:
            child = children.get(run_id)
            if child is None:
                raise Gate1ZeroEntryForensicsError("AUDIT_BATCH_RUN_NOT_GOVERNED")
            scanned = self.scan_archive(self.marker_for_run(archive_dir, run_id), child)
            facts = self._historical_facts(child)
            scanned["historical_launch_facts"] = facts
            # Accepted evidence intentionally stores frames only. Absence is evidence,
            # not an invitation to reconstruct settings from current source files.
            scanned["launch_bundle_recoverable"] = scanned["launch_artifacts"] > 0
            reports.append(scanned)
            for key in totals:
                totals[key] += int(scanned[key])
        unavailable = []
        if any(not item["launch_bundle_recoverable"] for item in reports):
            unavailable = [
                "HISTORICAL_TERMINAL_LOG", "HISTORICAL_TESTER_BINARY",
                "ORIGINAL_SET", "ORIGINAL_TESTER_INI",
            ]
        return {
            "schema": 1,
            "kind": "GATE1_ZERO_ENTRY_FORENSIC_BATCH",
            "status": "COMPLETE_INCONCLUSIVE_LAUNCH_BUNDLE_UNAVAILABLE" if unavailable else "COMPLETE",
            "controls": {
                "mt5_launch": False, "native_orders": False, "oos_access": False,
                "holdout_access": False, "selection": False, "candidate_budget_increment": 0,
            },
            "diagnostic_root_sha256": result.get("diagnostic_root_sha256"),
            "runs": reports,
            "totals": totals,
            "unavailable_historical_artifacts": unavailable,
            "differential_conclusion": (
                "INCONCLUSIVE: accepted archives carry verified output frames but no original "
                "launch bundle; a source/binary/INI divergence cannot be affirmatively identified."
                if unavailable else "LAUNCH_BUNDLE_AVAILABLE_FOR_DIFFERENTIAL_REVIEW"
            ),
        }

    def audit_stage13_batch(
        self,
        *,
        replacement_children: Path,
        continuation_children: Path,
        archive_dir: Path,
        run_ids: Iterable[str],
    ) -> dict[str, Any]:
        """Bounded Stage 13-only audit; it has no selection or execution capability."""
        children = self.governed_children(replacement_children, continuation_children)
        requested = list(run_ids)
        if not requested or len(set(requested)) != len(requested):
            raise Gate1ZeroEntryForensicsError("AUDIT_BATCH_RUN_IDS_INVALID")
        reports: list[dict[str, Any]] = []
        total_types: Counter[str] = Counter()
        boundary_counts: Counter[str] = Counter()
        configuration_distribution: Counter[str] = Counter()
        for run_id in requested:
            child = children.get(run_id)
            if child is None:
                raise Gate1ZeroEntryForensicsError("AUDIT_BATCH_RUN_NOT_GOVERNED")
            report = self.scan_stage13_archive(self.marker_for_run(archive_dir, run_id), child)
            report["partition"] = child["partition"]
            report["branch"] = child["branch"]
            report["mt5_build"] = child["mt5_build"]
            reports.append(report)
            total_types.update(report["event_type_counts"])
            boundary_counts[report["retained_boundary"]] += 1
            configuration_distribution.update(report["configuration_class_counts"])
        return {
            "schema": 1, "kind": "GATE1_STAGE13_FORENSIC_BATCH", "status": "COMPLETE",
            "controls": {"mt5_launch": False, "native_orders": False, "oos_access": False,
                         "holdout_access": False, "selection": False, "candidate_budget_increment": 0},
            "runs": reports, "event_type_counts": dict(sorted(total_types.items())),
            "retained_boundary_counts": dict(sorted(boundary_counts.items())),
            "configuration_distribution": dict(sorted(configuration_distribution.items())),
        }
