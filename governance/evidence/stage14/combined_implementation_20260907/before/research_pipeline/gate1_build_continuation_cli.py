"""Read-only evidence adapter and append-only package writer for build continuation."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from .gate1_build_continuation import BuildContinuationError, Gate1BuildContinuation
from .gate1_manual_batch import Gate1ManualBatch


PACKAGE_NAME = "gate1_continuation_20260824_v2"
PRE_TOOLING_NAME = "PRE_TOOLING_GATE1_BUILD_CONTINUATION_PREP_V2_20260824.json"


def _read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_new(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(value, indent=2, sort_keys=True) + "\n")


def _completed_inventory(
    workspace: Path, archive_root: Path, prior_package: Path
) -> tuple[list[str], dict]:
    execution = workspace / "governance/evidence/stage14/gate1_execution_20260809_v2"
    rows = []
    completed = []
    for number in range(Gate1BuildContinuation.COMPLETED_COUNT):
        run_id = f"G1-{number:04d}"
        completion_path = execution / "children" / run_id / "COMPLETE.json"
        child_path = prior_package / "children" / f"{run_id}.json"
        if not completion_path.is_file() or not child_path.is_file():
            raise BuildContinuationError("COMPLETED_EVIDENCE_MISSING")
        completion = _read(completion_path)
        child = _read(child_path)
        if (
            completion.get("status") != "COMPLETE"
            or completion.get("run_id") != run_id
            or child.get("run_id") != run_id
            or completion.get("manifest_sha256") != child.get("manifest_sha256")
        ):
            raise BuildContinuationError("COMPLETED_EVIDENCE_CONFLICT")
        markers = list(archive_root.glob(f"{run_id}_*.ARCHIVED.json"))
        if len(markers) != 1:
            raise BuildContinuationError("ARCHIVE_MARKER_CARDINALITY_INVALID")
        marker_path = markers[0]
        marker = _read(marker_path)
        archive_path = Path(str(marker.get("archive_path", ""))).resolve()
        if (
            marker.get("status") != "ARCHIVED_VERIFIED"
            or marker.get("run_id") != run_id
            or marker.get("manifest_sha256") != child.get("manifest_sha256")
            or marker.get("loose_files_removed") is not True
            or not archive_path.is_file()
            or archive_path.parent != archive_root.resolve()
            or Gate1ManualBatch.file_hash(archive_path) != marker.get("archive_sha256")
        ):
            raise BuildContinuationError("ARCHIVED_EVIDENCE_NOT_RECOVERABLE")
        rows.append(
            {
                "run_id": run_id,
                "manifest_sha256": child["manifest_sha256"],
                "child_file_sha256": Gate1ManualBatch.file_hash(child_path),
                "completion_file_sha256": Gate1ManualBatch.file_hash(completion_path),
                "archive_marker_file_sha256": Gate1ManualBatch.file_hash(marker_path),
                "archive_sha256": marker["archive_sha256"],
                "archive_size": archive_path.stat().st_size,
                "archive_file_count": marker["file_count"],
                "archive_sample_set_sha256": marker["sample_set_sha256"],
            }
        )
        completed.append(run_id)
    later = list((execution / "children").glob("G1-????/COMPLETE.json"))
    if len(later) != Gate1BuildContinuation.COMPLETED_COUNT:
        raise BuildContinuationError("COMPLETED_PREFIX_SCOPE_CHANGED")
    inventory = {
        "schema": 1,
        "kind": "GATE1_ACCEPTED_COMPLETED_EVIDENCE_INVENTORY",
        "prior_root_sha256": Gate1BuildContinuation.PRIOR_ROOT_SHA256,
        "completed_count": len(rows),
        "first_run_id": rows[0]["run_id"],
        "last_run_id": rows[-1]["run_id"],
        "rows": rows,
    }
    inventory["inventory_sha256"] = Gate1BuildContinuation.canonical_hash(inventory)
    return completed, inventory


def prepare(workspace: Path, archive_root: Path) -> dict:
    evidence = workspace / "governance/evidence/stage14"
    package = evidence / PACKAGE_NAME
    if package.exists():
        raise BuildContinuationError("CONTINUATION_PACKAGE_ALREADY_EXISTS")
    prior_package = evidence / "gate1_replacement_20260809"
    parity_package = evidence / "gate1_build_transition_20260823_v2"
    prior_root = _read(prior_package / "GATE1_ROOT.json")
    parity_result = _read(parity_package / "PARITY_RESULT.json")
    pre_tooling = _read(evidence / PRE_TOOLING_NAME)
    pre_tooling_stored = str(pre_tooling.get("manifest_sha256", "")).upper()
    pre_tooling_unhashed = {
        key: value for key, value in pre_tooling.items() if key != "manifest_sha256"
    }
    if Gate1ManualBatch.canonical_hash(pre_tooling_unhashed) != pre_tooling_stored:
        raise BuildContinuationError("CONTINUATION_PRE_TOOLING_MANIFEST_INVALID")
    completed, inventory = _completed_inventory(
        workspace, archive_root.resolve(), prior_package
    )
    builder = Gate1BuildContinuation()
    prepared = builder.prepare(
        prior_root=prior_root,
        parity_result=parity_result,
        completed_run_ids=completed,
        completed_evidence_inventory_sha256=inventory["inventory_sha256"],
        continuation_pre_tooling_sha256=pre_tooling_stored,
    )
    package.mkdir(parents=True)
    _write_new(package / "COMPLETED_EVIDENCE_INVENTORY.json", inventory)
    _write_new(package / "GATE1_ROOT.json", prepared["root"])
    _write_new(package / "CHILD_INDEX.json", prepared["index"])
    _write_new(package / "OWNER_APPROVAL_PACKET.json", prepared["approval_packet"])
    for child in prepared["children"]:
        _write_new(package / "children" / f"{child['run_id']}.json", child)
    files = sorted(path for path in package.rglob("*.json"))
    manifest = {
        "schema": 1,
        "kind": "GATE1_BUILD_CONTINUATION_PACKAGE",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "root_sha256": prepared["root"]["root_sha256"],
        "parity_result_sha256": parity_result["result_sha256"],
        "completed_evidence_inventory_sha256": inventory["inventory_sha256"],
        "files": [
            {
                "path": path.relative_to(package).as_posix(),
                "size": path.stat().st_size,
                "sha256": Gate1ManualBatch.file_hash(path),
            }
            for path in files
        ],
    }
    manifest["package_sha256"] = Gate1BuildContinuation.canonical_hash(manifest)
    _write_new(package / "PACKAGE_MANIFEST.json", manifest)
    return {
        "status": "PREPARED_OWNER_APPROVAL_REQUIRED",
        "root_sha256": prepared["root"]["root_sha256"],
        "package_sha256": manifest["package_sha256"],
        "completed_count": len(completed),
        "resume_run_id": prepared["approval_packet"]["resume_run_id"],
        "required_owner_statement": prepared["approval_packet"][
            "required_owner_statement"
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare Gate 1 build continuation")
    parser.add_argument("--workspace", type=Path, default=Path(r"C:\KingEA_v1"))
    parser.add_argument(
        "--archive-root",
        type=Path,
        default=Path(r"C:\KingEA_archives\stage14\gate1_spools"),
    )
    args = parser.parse_args(argv)
    try:
        value = prepare(args.workspace.resolve(), args.archive_root.resolve())
        print(json.dumps(value, sort_keys=True))
        return 0
    except (BuildContinuationError, OSError, UnicodeError, ValueError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}), file=sys.stderr)
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
