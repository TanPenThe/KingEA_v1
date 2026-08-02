"""Fail-closed finalization helpers for KingEA non-performance evidence."""

from __future__ import annotations

from pathlib import Path
from decimal import Decimal
import csv
import hashlib
from datetime import datetime
import argparse
import copy
import json
import os


REGISTERED_CROSSED = (
    (
        1709374488223,
        Decimal("3427.62"),
        Decimal("3427.36"),
        "2024.03.02 10:14:48",
    ),
    (
        1709375322820,
        Decimal("3418.20"),
        Decimal("3418.16"),
        "2024.03.02 10:28:42",
    ),
)
SERVER_TIME_FORMAT = "%Y.%m.%d %H:%M:%S"
REGISTERED_SAMPLE_SHA256 = (
    "96AD33D6F51D61FF9411E0E1BB6012132B0FD4BC534FD7B596E91B32ABA6FA9B"
)


class GateFailure(ValueError):
    """Raised when evidence cannot authorize an accepted data manifest."""


def evaluate_manifest_evidence(
    evidence: dict, sample_audit_path: Path, expected_sample_sha256: str
) -> dict:
    """Validate evidence and return a normalized acceptance summary."""

    actual_sample_hash = hashlib.sha256(sample_audit_path.read_bytes()).hexdigest().upper()
    if actual_sample_hash != expected_sample_sha256.upper():
        raise GateFailure("sample audit SHA-256 mismatch")
    if evidence.get("status") != "PASS":
        raise GateFailure("validator status must be PASS")
    if int(evidence.get("total_ticks", -1)) != 327417608:
        raise GateFailure("tick count must equal 327417608")
    if int(evidence.get("backward_timestamps", -1)) != 0:
        raise GateFailure("backward timestamp count must be zero")
    if int(evidence.get("nonflag_mismatches", -1)) != 0:
        raise GateFailure("non-flag mismatch count must be zero")
    if int(evidence.get("invalid_flag_normalizations", -1)) != 0:
        raise GateFailure("flag normalization mismatch count must be zero")
    if int(evidence.get("unexpected_crossed", -1)) != 0:
        raise GateFailure("unexpected crossed quote count must be zero")
    observed = evidence.get("registered_crossed", [])
    if len(observed) != len(REGISTERED_CROSSED):
        raise GateFailure("registered crossed quote count must equal two")
    for row, expected in zip(observed, REGISTERED_CROSSED, strict=True):
        actual = (
            int(row.get("time_msc", -1)),
            Decimal(str(row.get("bid", "NaN"))),
            Decimal(str(row.get("ask", "NaN"))),
        )
        if actual != expected[:3] or int(row.get("native_count", 0)) != 1 or int(
            row.get("custom_count", 0)
        ) != 1:
            raise GateFailure("registered crossed quote tuple/count mismatch")

    windows, sampled_quotes = _load_sample_windows(sample_audit_path)
    if len(windows) != 60:
        raise GateFailure("sample window count must equal 60")
    if sampled_quotes != 400437:
        raise GateFailure("sampled quote count must equal 400437")
    containment = []
    for time_msc, _, _, server_time in REGISTERED_CROSSED:
        stamp = datetime.strptime(server_time, SERVER_TIME_FORMAT)
        matched = [name for name, start, end in windows if start <= stamp < end]
        if matched:
            raise GateFailure(
                f"registered crossed timestamp falls inside sample window {matched[0]}"
            )
        applicable = [
            (name, start, end)
            for name, start, end in windows
            if start.year == stamp.year and start.month == stamp.month
        ]
        if len(applicable) != 1:
            raise GateFailure(
                "registered crossed timestamp must have exactly one applicable "
                "monthly sample window"
            )
        window_name, window_start, window_end = applicable[0]
        containment.append(
            {
                "time_msc": time_msc,
                "contained_window_count": 0,
                "applicable_month_window": window_name,
                "applicable_month_window_start": window_start.strftime(
                    SERVER_TIME_FORMAT
                ),
                "applicable_month_window_end_exclusive": window_end.strftime(
                    SERVER_TIME_FORMAT
                ),
            }
        )

    warmup = evidence.get("warmup", {})
    if warmup.get("status") != "PASS":
        raise GateFailure("warm-up status must be PASS")
    if float(warmup.get("coverage_ratio", 0.0)) < 0.95:
        raise GateFailure("warm-up coverage must be at least 0.95")
    if int(warmup.get("unexplained_terminal_gaps", -1)) != 0:
        raise GateFailure("warm-up terminal gap count must be zero")
    return {
        "status": "PASS",
        "sample_window_containment": containment,
        "sample_audit_sha256": actual_sample_hash,
        "sample_windows": len(windows),
        "sampled_quotes": sampled_quotes,
        "warmup": warmup,
    }


def _load_sample_windows(
    path: Path,
) -> tuple[list[tuple[str, datetime, datetime]], int]:
    starts: dict[str, datetime] = {}
    ends: dict[str, datetime] = {}
    sampled_quotes = -1
    with path.open(newline="", encoding="utf-8-sig") as stream:
        for row in csv.DictReader(stream):
            key = row.get("key", "")
            if row.get("section") == "summary" and key == "sampled_valid_spreads":
                sampled_quotes = int(row["value"])
                continue
            if row.get("section") != "tick_sample":
                continue
            if key.endswith("_start"):
                starts[key.removesuffix("_start")] = datetime.strptime(
                    row["value"], SERVER_TIME_FORMAT
                )
            elif key.endswith("_end"):
                ends[key.removesuffix("_end")] = datetime.strptime(
                    row["value"], SERVER_TIME_FORMAT
                )
    names = sorted(starts.keys() & ends.keys())
    if not names:
        raise GateFailure("sample window definitions are unavailable")
    windows = []
    for name in names:
        if ends[name] <= starts[name]:
            raise GateFailure(f"sample window {name} is not half-open and increasing")
        windows.append((name, starts[name], ends[name]))
    return windows, sampled_quotes


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def parse_mt5_gate_report(path: Path) -> dict:
    """Convert the five-column MT5 report into the gate's public evidence shape."""

    values: dict[tuple[str, str], str] = {}
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["section", "key", "value", "unit", "notes"]:
            raise GateFailure("MT5 gate report header mismatch")
        for row in reader:
            values[(row["section"], row["key"])] = row["value"]

    required_identity = {
        ("audit", "scope"): "NON_PERFORMANCE_RSB3_MANIFEST_GATE",
        ("audit", "build_id"): "RSB3-MANIFEST-GATE-20260726-A",
        ("audit", "server"): "JustMarkets-Demo2",
        ("audit", "origin_symbol"): "ETHUSD.s",
        ("audit", "reduced_symbol"): "KINGEA_ETHUSD_S_RSB3",
    }
    for key, expected in required_identity.items():
        if values.get(key) != expected:
            raise GateFailure(f"MT5 gate report identity mismatch: {key[1]}")

    def integer(section: str, key: str) -> int:
        try:
            return int(values[(section, key)])
        except (KeyError, ValueError) as error:
            raise GateFailure(f"MT5 gate report missing integer {section}.{key}") from error

    crossed = []
    for index in (1, 2):
        crossed.append(
            {
                "time_msc": integer("crossed", f"registered_{index}_time_msc"),
                "bid": values.get(("crossed", f"registered_{index}_bid"), ""),
                "ask": values.get(("crossed", f"registered_{index}_ask"), ""),
                "native_count": integer(
                    "crossed", f"registered_{index}_native_count"
                ),
                "custom_count": integer(
                    "crossed", f"registered_{index}_custom_count"
                ),
            }
        )
    try:
        coverage_ratio = float(values[("warmup", "coverage_ratio")])
    except (KeyError, ValueError) as error:
        raise GateFailure("MT5 gate report missing warm-up coverage") from error

    return {
        "status": values.get(("result", "status"), ""),
        "total_ticks": integer("summary", "total_ticks"),
        "registered_crossed": crossed,
        "unexpected_crossed": integer("summary", "unexpected_crossed"),
        "backward_timestamps": integer("summary", "backward_timestamps"),
        "nonflag_mismatches": integer("summary", "nonflag_mismatches"),
        "invalid_flag_normalizations": integer(
            "summary", "invalid_flag_normalizations"
        ),
        "transformed_ticks": integer("summary", "transformed_ticks"),
        "unchanged_ticks": integer("summary", "unchanged_ticks"),
        "warmup": {
            "status": values.get(("warmup", "status"), ""),
            "from": values.get(("warmup", "from"), ""),
            "to_exclusive": values.get(("warmup", "to_exclusive"), ""),
            "m30_bars": integer("warmup", "m30_bars"),
            "expected_m30_slots": integer("warmup", "expected_m30_slots"),
            "coverage_ratio": coverage_ratio,
            "derived_h4_bars": integer("warmup", "derived_h4_bars"),
            "unexplained_terminal_gaps": integer(
                "warmup", "unexplained_terminal_gaps"
            ),
            "export_file": values.get(("warmup", "export_file"), ""),
        },
    }


def finalize_v2_manifest(
    v1_path: Path,
    gate_report_path: Path,
    sample_audit_path: Path,
    common_files_root: Path,
    output_path: Path,
) -> dict:
    """Write V2 only after every non-performance gate is independently green."""

    evidence = parse_mt5_gate_report(gate_report_path)
    accepted = evaluate_manifest_evidence(
        evidence, sample_audit_path, REGISTERED_SAMPLE_SHA256
    )
    warmup_file = common_files_root / evidence["warmup"]["export_file"]
    if not warmup_file.is_file():
        raise GateFailure("warm-up export artifact is unavailable")

    with v1_path.open(encoding="utf-8") as stream:
        manifest = copy.deepcopy(json.load(stream))
    manifest["manifest_id"] = "KINGEA-ETH-NATIVE-SPREAD-BRACKET-EVIDENCE-V2"
    manifest["status"] = "ACCEPTED_NON_PERFORMANCE_DATASET"
    manifest["performance_authorized"] = False
    manifest["supersedes_without_mutating"] = {
        "path": str(v1_path).replace("\\", "/"),
        "sha256": sha256_file(v1_path),
    }
    manifest["final_manifest_gate"] = {
        "report_file": gate_report_path.name,
        "report_sha256": sha256_file(gate_report_path),
        "result": accepted,
        "warmup_export_file": warmup_file.name,
        "warmup_export_sha256": sha256_file(warmup_file),
        "sample_audit_file": sample_audit_path.name,
        "sample_audit_sha256": sha256_file(sample_audit_path),
        "crossed_quote_reconciliation": (
            "The earlier 400437-quote targeted audit found zero crossed quotes; "
            "the automated half-open interval check proves both full-population "
            "crossed timestamps were outside all 60 fixed sample windows."
        ),
    }
    manifest["registered_dataset_scope"] = {
        "start_server_time_inclusive": "2021-07-01T00:00:00",
        "end_server_time_exclusive": "2026-07-01T00:00:00",
        "warmup_only": "[2021-04-01T00:00:00,2021-07-01T00:00:00)",
        "rolling_folds": [
            {
                "train": "[2021-07-01T00:00:00,2023-01-01T00:00:00)",
                "test": "[2023-01-01T00:00:00,2023-04-01T00:00:00)",
            },
            {
                "train": "[2021-10-01T00:00:00,2023-04-01T00:00:00)",
                "test": "[2023-04-01T00:00:00,2023-07-01T00:00:00)",
            },
            {
                "train": "[2022-01-01T00:00:00,2023-07-01T00:00:00)",
                "test": "[2023-07-01T00:00:00,2023-10-01T00:00:00)",
            },
            {
                "train": "[2022-04-01T00:00:00,2023-10-01T00:00:00)",
                "test": "[2023-10-01T00:00:00,2024-01-01T00:00:00)",
            },
        ],
        "final_selection": "[2022-07-01T00:00:00,2024-01-01T00:00:00)",
        "formal_oos": "[2024-01-01T00:00:00,2025-01-01T00:00:00)",
        "untouched_live2_holdout": "[2025-01-01T00:00:00,2026-07-01T00:00:00)",
        "timezone": "broker server time",
        "sample_size_rule": (
            "At least 150 original trade groups across stitched rolling tests "
            "and formal OOS; untouched holdout trades are excluded."
        ),
    }
    manifest["pending_before_candidate_freeze"] = []
    manifest["not_done"] = [
        "No strategy signal, trade, return, optimizer, OOS, or holdout result was consulted.",
        "Candidate performance testing remains unauthorized until CAND-ETH-ST-001 is FROZEN.",
    ]

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".partial")
    temporary.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, output_path)
    return {
        "manifest": str(output_path),
        "sha256": sha256_file(output_path),
        "status": manifest["status"],
    }


def _main() -> int:
    parser = argparse.ArgumentParser(
        description="Finalize the KingEA RSB3 V2 manifest after a read-only MT5 gate PASS."
    )
    parser.add_argument("--v1", type=Path, required=True)
    parser.add_argument("--gate-report", type=Path, required=True)
    parser.add_argument("--sample-audit", type=Path, required=True)
    parser.add_argument("--common-files-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = finalize_v2_manifest(
            args.v1,
            args.gate_report,
            args.sample_audit,
            args.common_files_root,
            args.output,
        )
    except (GateFailure, OSError, json.JSONDecodeError) as error:
        print(f"MANIFEST_GATE_FAIL: {error}")
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
