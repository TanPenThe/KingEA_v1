"""Filesystem/process adapter for the governed Gate 1 MT5 build parity gate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from .gate1_build_transition import BuildTransitionError, Gate1BuildTransition
from .gate1_evidence_archive import Gate1EvidenceArchive
from .gate1_manual_batch import Gate1BatchError, Gate1ManualBatch
from .gate1_manual_cli import (
    MAX_CHILD_SECONDS,
    STANDDOWN_SHA256,
    _copy_exact,
    _scheduled_kingea_tasks,
    _terminal_build,
    _terminal_process_count,
    _verify_demo2_terminal_identity,
    _wait_for_completion,
    _write_bytes_new,
    _write_new,
)
from .stage14 import ResearchRunCoordinator, Stage14Error


PACKAGE_NAME = "gate1_build_transition_20260823_v2"
PRE_TOOLING_NAME = "PRE_TOOLING_GATE1_BUILD_PARITY_V3_20260823.json"
OWNER_STATEMENT = "ok do it now, let me know when to run the script"


def _read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _package_dir(workspace: Path) -> Path:
    return workspace / "governance/evidence/stage14" / PACKAGE_NAME


def _atomic_package_manifest(package: Path, paths: list[Path]) -> dict:
    rows = [
        {
            "path": path.relative_to(package).as_posix(),
            "size": path.stat().st_size,
            "sha256": Gate1ManualBatch.file_hash(path),
        }
        for path in sorted(paths, key=lambda item: item.relative_to(package).as_posix())
    ]
    value = {
        "schema": 1,
        "kind": "GATE1_MT5_BUILD_PARITY_PACKAGE",
        "files": rows,
    }
    value["package_sha256"] = Gate1ManualBatch.canonical_hash(value)
    return value


def prepare(workspace: Path, terminal: Path) -> dict:
    package = _package_dir(workspace)
    if package.exists():
        raise BuildTransitionError("PARITY_PACKAGE_ALREADY_EXISTS")
    if not terminal.is_file() or terminal.name.lower() != "terminal64.exe":
        raise BuildTransitionError("TERMINAL_IDENTITY_INVALID")
    build = _terminal_build(terminal)
    terminal_sha256 = Gate1ManualBatch.file_hash(terminal)
    pre_tooling_path = workspace / "governance/evidence/stage14" / PRE_TOOLING_NAME
    pre_tooling = _read(pre_tooling_path)
    pre_tooling_stored = str(pre_tooling.get("manifest_sha256", "")).upper()
    pre_tooling_unhashed = {
        key: value for key, value in pre_tooling.items() if key != "manifest_sha256"
    }
    if Gate1ManualBatch.canonical_hash(pre_tooling_unhashed) != pre_tooling_stored:
        raise BuildTransitionError("TRANSITION_PRE_TOOLING_MANIFEST_INVALID")
    prior = workspace / "governance/evidence/stage14/gate1_replacement_20260809"
    module = Gate1BuildTransition(workspace)
    prepared = module.prepare(
        prior_root=_read(prior / "GATE1_ROOT.json"),
        prior_index=_read(prior / "CHILD_INDEX.json"),
        new_build=build,
        terminal_sha256=terminal_sha256,
        transition_pre_tooling_sha256=pre_tooling_stored,
    )
    package.mkdir(parents=True)
    written: list[Path] = []
    root_path = package / "PARITY_ROOT.json"
    _write_new(root_path, prepared["root"])
    written.append(root_path)
    children_dir = package / "children"
    for child in prepared["children"]:
        path = children_dir / f"{child['run_id']}.json"
        _write_new(path, child)
        written.append(path)
    index = dict(prepared["index"])
    by_id = {child["run_id"]: child for child in prepared["children"]}
    for row in index["children"]:
        path = children_dir / f"{row['run_id']}.json"
        row["path"] = path.relative_to(workspace).as_posix()
        row["file_sha256"] = Gate1ManualBatch.file_hash(path)
        row["manifest_sha256"] = by_id[row["run_id"]]["manifest_sha256"]
    index.pop("index_sha256", None)
    index["index_sha256"] = Gate1ManualBatch.canonical_hash(index)
    index_path = package / "CHILD_INDEX.json"
    _write_new(index_path, index)
    written.append(index_path)
    authorization = {
        "schema": 1,
        "kind": "GATE1_MT5_BUILD_PARITY_AUTHORIZATION",
        "owner_approved": True,
        "owner_statement": OWNER_STATEMENT,
        "parity_root_sha256": prepared["root"]["parity_root_sha256"],
        "authorized_runs": [row["run_id"] for row in index["children"]],
        "selection_eligible": False,
        "candidate_budget_increment": 0,
        "oos_authorized": False,
        "holdout_authorized": False,
    }
    authorization["authorization_sha256"] = Gate1ManualBatch.canonical_hash(
        authorization
    )
    authorization_path = package / "AUTHORIZATION.json"
    _write_new(authorization_path, authorization)
    written.append(authorization_path)
    package_manifest = _atomic_package_manifest(package, written)
    manifest_path = package / "PACKAGE_MANIFEST.json"
    _write_new(manifest_path, package_manifest)
    return {
        "status": "PREPARED",
        "parity_root_sha256": prepared["root"]["parity_root_sha256"],
        "package_sha256": package_manifest["package_sha256"],
        "new_mt5_build": build,
        "run_ids": authorization["authorized_runs"],
    }


def _verify_package(workspace: Path) -> tuple[Path, dict, dict, dict]:
    package = _package_dir(workspace)
    package_manifest = _read(package / "PACKAGE_MANIFEST.json")
    stored = str(package_manifest.get("package_sha256", "")).upper()
    unhashed = {
        key: value
        for key, value in package_manifest.items()
        if key != "package_sha256"
    }
    if Gate1ManualBatch.canonical_hash(unhashed) != stored:
        raise BuildTransitionError("PACKAGE_MANIFEST_HASH_MISMATCH")
    for row in package_manifest.get("files", []):
        path = (package / str(row.get("path", ""))).resolve()
        try:
            path.relative_to(package)
        except ValueError as exc:
            raise BuildTransitionError("PACKAGE_PATH_OUTSIDE_ROOT") from exc
        if (
            not path.is_file()
            or path.stat().st_size != row.get("size")
            or Gate1ManualBatch.file_hash(path) != row.get("sha256")
        ):
            raise BuildTransitionError("PACKAGE_FILE_HASH_MISMATCH")
    root = _read(package / "PARITY_ROOT.json")
    root_stored = str(root.get("parity_root_sha256", "")).upper()
    root_unhashed = {
        key: value for key, value in root.items() if key != "parity_root_sha256"
    }
    if Gate1ManualBatch.canonical_hash(root_unhashed) != root_stored:
        raise BuildTransitionError("PARITY_ROOT_HASH_MISMATCH")
    pre_tooling_path = (
        workspace / "governance/evidence/stage14" / PRE_TOOLING_NAME
    )
    pre_tooling = _read(pre_tooling_path)
    pre_tooling_stored = str(pre_tooling.get("manifest_sha256", "")).upper()
    pre_tooling_unhashed = {
        key: value for key, value in pre_tooling.items() if key != "manifest_sha256"
    }
    if (
        Gate1ManualBatch.canonical_hash(pre_tooling_unhashed) != pre_tooling_stored
        or root.get("transition_pre_tooling_sha256") != pre_tooling_stored
    ):
        raise BuildTransitionError("TRANSITION_PRE_TOOLING_BINDING_INVALID")
    index = _read(package / "CHILD_INDEX.json")
    index_stored = str(index.get("index_sha256", "")).upper()
    index_unhashed = {
        key: value for key, value in index.items() if key != "index_sha256"
    }
    if Gate1ManualBatch.canonical_hash(index_unhashed) != index_stored:
        raise BuildTransitionError("PARITY_INDEX_HASH_MISMATCH")
    authorization = _read(package / "AUTHORIZATION.json")
    authorization_stored = str(authorization.get("authorization_sha256", "")).upper()
    authorization_unhashed = {
        key: value
        for key, value in authorization.items()
        if key != "authorization_sha256"
    }
    if (
        Gate1ManualBatch.canonical_hash(authorization_unhashed)
        != authorization_stored
        or authorization.get("owner_statement") != OWNER_STATEMENT
        or authorization.get("parity_root_sha256") != root_stored
        or authorization.get("owner_approved") is not True
        or authorization.get("selection_eligible") is not False
        or authorization.get("candidate_budget_increment") != 0
        or authorization.get("oos_authorized") is not False
        or authorization.get("holdout_authorized") is not False
    ):
        raise BuildTransitionError("PARITY_AUTHORIZATION_INVALID")
    return package, root, index, authorization


def execute(
    workspace: Path,
    terminal: Path,
    terminal_data: Path,
    common_files: Path,
) -> dict:
    package, root, index, authorization = _verify_package(workspace)
    if _terminal_process_count() != 0:
        raise BuildTransitionError("MT5_OR_TESTER_ALREADY_RUNNING")
    if _scheduled_kingea_tasks():
        raise BuildTransitionError("KINGEA_SCHEDULED_TASK_PRESENT")
    standdown = common_files / "KingEA/control/KINGEA-DEMO2-001/manual_standdown.json"
    if (
        not standdown.is_file()
        or Gate1ManualBatch.file_hash(standdown) != STANDDOWN_SHA256
        or _read(standdown).get("DeploymentId") != "KINGEA-DEMO2-001"
    ):
        raise BuildTransitionError("STAGE9_STANDDOWN_INVALID")
    if _terminal_build(terminal) != int(root["new_mt5_build"]):
        raise BuildTransitionError("TERMINAL_BUILD_CHANGED_AFTER_PREPARATION")
    if Gate1ManualBatch.file_hash(terminal) != root["new_terminal_sha256"]:
        raise BuildTransitionError("TERMINAL_HASH_CHANGED_AFTER_PREPARATION")
    identity = _verify_demo2_terminal_identity(terminal)

    execution_root = package / "execution"
    archive_root = Path(r"C:\KingEA_archives\stage14\gate1_build_parity_20260823_v2")
    spool_root = common_files / "KingEA/stage14_spool"
    coordinator = ResearchRunCoordinator()
    comparer = Gate1BuildTransition(workspace)
    results: list[dict] = []
    references = {
        row["parity_run_id"]: row["reference_run_id"]
        for row in root["comparisons"]
    }
    for row in index["children"]:
        run_id = row["run_id"]
        child_root = execution_root / "children" / run_id
        comparison_path = child_root / "COMPARISON.json"
        complete_path = child_root / "COMPLETE.json"
        if comparison_path.is_file() and complete_path.is_file():
            comparison = _read(comparison_path)
            if comparison.get("status") != "PASS":
                raise BuildTransitionError("PREVIOUS_PARITY_RESULT_NOT_PASS")
            results.append(comparison)
            continue
        if child_root.exists():
            raise BuildTransitionError(f"PARTIAL_PARITY_RUN_REQUIRES_REVIEW:{run_id}")
        manifest_path = (workspace / row["path"]).resolve()
        if (
            not manifest_path.is_file()
            or Gate1ManualBatch.file_hash(manifest_path) != row["file_sha256"]
        ):
            raise BuildTransitionError("PARITY_CHILD_FILE_CHANGED")
        manifest = _read(manifest_path)
        child_root.mkdir(parents=True)
        detached = {
            "schema": 1,
            "kind": "GATE1_BUILD_PARITY_CHILD_AUTHORIZATION",
            "owner_approved": True,
            "gate": 1,
            "root_sha256": root["parity_root_sha256"],
            "child_sha256": manifest["manifest_sha256"],
            "run_id": run_id,
            "derived_from_owner_statement": OWNER_STATEMENT,
            "selection_eligible": False,
            "candidate_budget_increment": 0,
            "oos_authorized": False,
            "holdout_authorized": False,
        }
        _write_new(child_root / "AUTHORIZATION.json", detached)
        common_manifest = common_files / "KingEA/runs" / f"{manifest['manifest_sha256']}.json"
        _copy_exact(manifest_path, common_manifest, row["file_sha256"])
        bundle = coordinator.render_bundle(manifest, detached)
        coordinator.verify_bundle(manifest, detached, bundle)
        set_text = bundle["set"].replace("SET_AT_EXECUTION", row["file_sha256"])
        set_path = child_root / f"{manifest['manifest_sha256']}.set"
        ini_path = child_root / f"{run_id}.ini"
        _write_bytes_new(set_path, set_text.encode("utf-8"))
        _write_bytes_new(ini_path, bundle["ini"].encode("utf-8"))
        profile_set = terminal_data / "MQL5/Profiles/Tester" / set_path.name
        _copy_exact(set_path, profile_set, Gate1ManualBatch.file_hash(set_path))
        spool = spool_root / manifest["manifest_sha256"]
        if spool.exists() and any(spool.iterdir()):
            raise BuildTransitionError("PREEXISTING_PARITY_SPOOL_REQUIRES_REVIEW")
        _write_new(
            child_root / "RUNNING.json",
            {
                "schema": 1,
                "status": "RUNNING",
                "run_id": run_id,
                "manifest_sha256": manifest["manifest_sha256"],
                "started_at": datetime.now(timezone.utc).isoformat(),
                "maximum_child_seconds": MAX_CHILD_SECONDS,
            },
        )
        started = time.monotonic()
        try:
            process = subprocess.run(
                [str(terminal), f"/config:{ini_path}"],
                check=False,
                timeout=MAX_CHILD_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise BuildTransitionError("PARITY_CHILD_TIME_LIMIT") from exc
        if process.returncode != 0:
            raise BuildTransitionError(f"PARITY_MT5_EXIT_{process.returncode}")
        completion = _wait_for_completion(Gate1ManualBatch(workspace), manifest, spool)
        completion.update(
            {
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "elapsed_seconds": time.monotonic() - started,
                "terminal_exit_code": process.returncode,
                "spool_path": str(spool),
            }
        )
        reference_run = references[run_id]
        markers = list(
            Path(r"C:\KingEA_archives\stage14\gate1_spools").glob(
                f"{reference_run}_*.ARCHIVED.json"
            )
        )
        if len(markers) != 1:
            raise BuildTransitionError("REFERENCE_ARCHIVE_RECORD_NOT_UNIQUE")
        comparison = comparer.compare(
            reference_record=_read(markers[0]), candidate_spool=spool
        )
        comparison.update(
            {
                "parity_run_id": run_id,
                "reference_run_id": reference_run,
                "new_mt5_build": root["new_mt5_build"],
                "new_terminal_sha256": root["new_terminal_sha256"],
                "completed_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        _write_new(comparison_path, comparison)
        _write_new(complete_path, completion)
        archiver = Gate1EvidenceArchive(execution_root, spool_root, archive_root)
        archive_record = archiver.archive_completed(run_id, remove_verified=True)
        comparison["parity_archive_sha256"] = archive_record["archive_sha256"]
        results.append(comparison)
        if _terminal_process_count() != 0:
            raise BuildTransitionError("MT5_OR_TESTER_REMAINS_AFTER_PARITY_CHILD")

    if len(results) != 4 or any(row.get("status") != "PASS" for row in results):
        raise BuildTransitionError("PARITY_RESULT_SET_INCOMPLETE")
    result = {
        "schema": 1,
        "kind": "GATE1_MT5_BUILD_PARITY_RESULT",
        "status": "PASS",
        "parity_root_sha256": root["parity_root_sha256"],
        "prior_mt5_build": root["prior_mt5_build"],
        "new_mt5_build": root["new_mt5_build"],
        "new_terminal_sha256": root["new_terminal_sha256"],
        "identity": identity,
        "comparisons": results,
        "selection_eligible": False,
        "candidate_budget_increment": 0,
        "continuation_authorized": False,
        "completed_at": datetime.now(timezone.utc).isoformat(),
    }
    result["result_sha256"] = Gate1ManualBatch.canonical_hash(result)
    _write_new(package / "PARITY_RESULT.json", result)
    return {
        "status": "PASS",
        "result_sha256": result["result_sha256"],
        "comparison_count": len(results),
        "continuation_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="KingEA Gate 1 MT5 build transition")
    parser.add_argument("command", choices=("prepare", "execute"))
    parser.add_argument("--workspace", type=Path, default=Path(r"C:\KingEA_v1"))
    parser.add_argument(
        "--terminal", type=Path, default=Path(r"C:\Program Files\MetaTrader 5\terminal64.exe")
    )
    parser.add_argument(
        "--terminal-data",
        type=Path,
        default=Path(
            r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
        ),
    )
    parser.add_argument(
        "--common-files",
        type=Path,
        default=Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files"),
    )
    args = parser.parse_args(argv)
    try:
        workspace = args.workspace.resolve()
        if args.command == "prepare":
            value = prepare(workspace, args.terminal.resolve())
        else:
            value = execute(
                workspace,
                args.terminal.resolve(),
                args.terminal_data.resolve(),
                args.common_files.resolve(),
            )
        print(json.dumps(value, sort_keys=True))
        return 0
    except (
        BuildTransitionError,
        Gate1BatchError,
        Stage14Error,
        OSError,
        UnicodeError,
        ValueError,
        subprocess.SubprocessError,
    ) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}), file=sys.stderr)
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
