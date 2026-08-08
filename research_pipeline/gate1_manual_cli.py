"""Foreground-only launcher for the authorized Gate 1 manual batches."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from .gate1_manual_batch import Gate1BatchError, Gate1ManualBatch
from .stage14 import ResearchRunCoordinator, Stage14Error


ROOT_SHA256 = "BC4D5D84DBF45AAB6628AA0E1D39D984F715217BB1CA1C092DE1EE97385FA889"
STANDDOWN_SHA256 = "8414EB459A695F34C777EF33CF9F94BF1A269FE3F5FBA7B8360E28AAEB5B93D7"
APPROVAL_FILE_SHA256 = "6FF67C9D7AB21DDAF50357E030C62E1FB377DD5EEBCB0B78BCE5FBC8EADACDC4"
MAX_CHILD_SECONDS = int(Gate1ManualBatch.MAXIMUM_CHILD_HOURS * 60 * 60)


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_new(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(value, indent=2, sort_keys=True) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(encoded)


def _write_bytes_new(path: Path, value: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(value)


def _copy_exact(source: Path, target: Path, expected_sha256: str) -> None:
    source_hash = Gate1ManualBatch.file_hash(source)
    if source_hash != expected_sha256:
        raise Gate1BatchError("SOURCE_HASH_MISMATCH")
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if Gate1ManualBatch.file_hash(target) != expected_sha256:
            raise Gate1BatchError("IMMUTABLE_TARGET_CONFLICT")
        return
    shutil.copyfile(source, target)
    if Gate1ManualBatch.file_hash(target) != expected_sha256:
        raise Gate1BatchError("COPY_READBACK_HASH_MISMATCH")


def _scheduled_kingea_tasks() -> list[str]:
    completed = subprocess.run(
        ["schtasks", "/Query", "/FO", "CSV", "/NH"],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise Gate1BatchError("SCHEDULED_TASK_QUERY_FAILED")
    return [line for line in completed.stdout.splitlines() if "kingea" in line.lower()]


def _terminal_process_count() -> int:
    command = (
        "@(Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue).Count"
    )
    completed = subprocess.run(
        ["powershell", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise Gate1BatchError("PROCESS_QUERY_FAILED")
    return int((completed.stdout.strip() or "0").splitlines()[-1])


def _terminal_build(terminal: Path) -> int:
    escaped = str(terminal).replace("'", "''")
    command = f"(Get-Item -LiteralPath '{escaped}').VersionInfo.FileVersion"
    completed = subprocess.run(
        ["powershell", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise Gate1BatchError("TERMINAL_BUILD_QUERY_FAILED")
    parts = completed.stdout.strip().split(".")
    if not parts or not parts[-1].isdigit():
        raise Gate1BatchError("TERMINAL_BUILD_INVALID")
    return int(parts[-1])


def _verify_demo2_terminal_identity(terminal: Path) -> dict:
    """Open the exact terminal briefly, inspect its active title, then close it."""
    if _terminal_process_count() != 0:
        raise Gate1BatchError("MT5_OR_TESTER_ALREADY_RUNNING")
    process = subprocess.Popen([str(terminal)])
    title = ""
    try:
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            command = (
                f"$p=Get-Process -Id {process.pid} -ErrorAction SilentlyContinue;"
                "if($p){$p.MainWindowTitle}"
            )
            observed = subprocess.run(
                ["powershell", "-NoProfile", "-Command", command],
                capture_output=True,
                text=True,
                check=False,
            )
            title = observed.stdout.strip()
            if title:
                break
            time.sleep(1)
        if "JustMarkets-Demo2" not in title or "1768" not in title:
            raise Gate1BatchError("DEMO2_ACCOUNT_IDENTITY_MISMATCH")
        proof = {
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "server": "JustMarkets-Demo2",
            "account_suffix": "1768",
            "terminal_sha256": Gate1ManualBatch.file_hash(terminal),
            "raw_login_stored": False,
        }
    finally:
        if process.poll() is None:
            close = subprocess.run(
                [
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    f"$p=Get-Process -Id {process.pid} -ErrorAction SilentlyContinue;"
                    "if($p){$null=$p.CloseMainWindow();$p.WaitForExit(15000)}",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            if close.returncode != 0 or process.poll() is None:
                raise Gate1BatchError("DEMO2_PREFLIGHT_TERMINAL_DID_NOT_CLOSE")
    if _terminal_process_count() != 0:
        raise Gate1BatchError("MT5_OR_TESTER_REMAINS_AFTER_PREFLIGHT")
    return proof


def _completed_ids(execution_root: Path) -> list[str]:
    completed: list[str] = []
    children = execution_root / "children"
    for number in range(200):
        run_id = f"G1-{number:04d}"
        marker = children / run_id / "COMPLETE.json"
        if marker.exists():
            value = _read_json(marker)
            if value.get("status") != "COMPLETE" or value.get("run_id") != run_id:
                raise Gate1BatchError("INVALID_COMPLETION_MARKER")
            completed.append(run_id)
        elif any((children / f"G1-{later:04d}" / "COMPLETE.json").exists() for later in range(number + 1, 200)):
            raise Gate1BatchError("COMPLETION_SEQUENCE_GAP")
        else:
            break
    return completed


def _wait_for_completion(
    planner: Gate1ManualBatch, manifest: dict, spool: Path
) -> dict:
    deadline = time.monotonic() + 120
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            return planner.verify_completion(manifest, spool)
        except (OSError, UnicodeError, Gate1BatchError) as exc:
            last_error = exc
            time.sleep(2)
    raise Gate1BatchError(f"RESULT_FRAMES_NOT_COMPLETE:{last_error}")


def _run(args: argparse.Namespace) -> dict:
    workspace = args.workspace.resolve()
    package = workspace / "governance/evidence/stage14/gate1_preparation_20260808"
    execution_root = workspace / "governance/evidence/stage14/gate1_execution_20260808"
    root = _read_json(package / "GATE1_ROOT.json")
    index = _read_json(package / "CHILD_INDEX.json")
    approval_path = package / "GATE1_AUTHORIZATION.json"
    if Gate1ManualBatch.file_hash(approval_path) != APPROVAL_FILE_SHA256:
        raise Gate1BatchError("OWNER_AUTHORIZATION_FILE_HASH_MISMATCH")
    approval = _read_json(approval_path)
    planner = Gate1ManualBatch(workspace)
    completed = _completed_ids(execution_root)
    plan = planner.plan(
        root, index, approval, completed_run_ids=completed, requested_children=args.children
    )
    if not plan["run_ids"]:
        return {"status": "ALL_GATE1_CHILDREN_COMPLETE", "completed": len(completed)}
    if _scheduled_kingea_tasks():
        raise Gate1BatchError("KINGEA_SCHEDULED_TASK_PRESENT")
    standdown = args.common_files / "KingEA/control/KINGEA-DEMO2-001/manual_standdown.json"
    if (
        not standdown.is_file()
        or Gate1ManualBatch.file_hash(standdown) != STANDDOWN_SHA256
        or _read_json(standdown).get("DeploymentId") != "KINGEA-DEMO2-001"
    ):
        raise Gate1BatchError("STAGE9_STANDDOWN_INVALID")
    if not args.terminal.is_file() or args.terminal.name.lower() != "terminal64.exe":
        raise Gate1BatchError("TERMINAL_IDENTITY_INVALID")
    if _terminal_build(args.terminal) != int(root["mt5_build"]):
        raise Gate1BatchError("TERMINAL_BUILD_MISMATCH")
    identity = _verify_demo2_terminal_identity(args.terminal)
    coordinator = ResearchRunCoordinator()
    for name in (
        "PRE_TOOLING_GATE1_PREP_V3_20260808.json",
        "PRE_TOOLING_GATE1_MANUAL_BATCH_V6_20260808.json",
    ):
        pre_tooling = _read_json(workspace / "governance/evidence/stage14" / name)
        if not coordinator.verify_pre_tooling_manifest(pre_tooling)["passed"]:
            raise Gate1BatchError(f"PRE_TOOLING_VERIFICATION_FAILED:{name}")

    first = plan["run_ids"][0].split("-")[-1]
    last = plan["run_ids"][-1].split("-")[-1]
    batch_id = f"BATCH-{first}-{last}"
    batch_root = execution_root / "batches" / batch_id
    if batch_root.exists():
        raise Gate1BatchError("BATCH_EVIDENCE_ALREADY_EXISTS")
    plan = {
        **plan,
        "batch_id": batch_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "identity": identity,
        "standdown_sha256": STANDDOWN_SHA256,
    }
    _write_new(batch_root / "PLAN.json", plan)

    index_by_id = {row["run_id"]: row for row in index["children"]}
    results = []
    for run_id in plan["run_ids"]:
        child_record = index_by_id[run_id]
        manifest_path = workspace / child_record["path"]
        manifest = _read_json(manifest_path)
        child_root = execution_root / "children" / run_id
        if child_root.exists():
            raise Gate1BatchError("PARTIAL_CHILD_EVIDENCE_REQUIRES_REVIEW")
        child_root.mkdir(parents=True)
        authorization = planner.child_authorization(manifest, approval)
        _write_new(child_root / "AUTHORIZATION.json", authorization)

        common_manifest = args.common_files / "KingEA/runs" / f"{manifest['manifest_sha256']}.json"
        _copy_exact(manifest_path, common_manifest, child_record["file_sha256"])
        manifest_file_sha = Gate1ManualBatch.file_hash(manifest_path)
        bundle = coordinator.render_bundle(manifest, authorization)
        coordinator.verify_bundle(manifest, authorization, bundle)
        set_text = bundle["set"].replace("SET_AT_EXECUTION", manifest_file_sha)
        ini_text = bundle["ini"]
        set_path = child_root / f"{manifest['manifest_sha256']}.set"
        ini_path = child_root / f"{run_id}.ini"
        _write_bytes_new(set_path, set_text.encode("utf-8"))
        _write_bytes_new(ini_path, ini_text.encode("utf-8"))
        profile_set = args.terminal_data / "MQL5/Profiles/Tester" / set_path.name
        _copy_exact(set_path, profile_set, Gate1ManualBatch.file_hash(set_path))

        spool = args.common_files / "KingEA/stage14_spool" / manifest["manifest_sha256"]
        if spool.exists() and any(spool.iterdir()):
            raise Gate1BatchError("PREEXISTING_CHILD_SPOOL_REQUIRES_REVIEW")
        started_at = datetime.now(timezone.utc).isoformat()
        _write_new(
            child_root / "RUNNING.json",
            {
                "schema": 1,
                "status": "RUNNING",
                "run_id": run_id,
                "manifest_sha256": manifest["manifest_sha256"],
                "started_at": started_at,
                "maximum_child_seconds": MAX_CHILD_SECONDS,
            },
        )
        started = time.monotonic()
        try:
            completed_process = subprocess.run(
                [str(args.terminal), f"/config:{ini_path}"],
                check=False,
                timeout=MAX_CHILD_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise Gate1BatchError("CHILD_EXCEEDED_THREE_HOUR_FORTY_FIVE_MINUTE_LIMIT") from exc
        if completed_process.returncode != 0:
            raise Gate1BatchError(f"MT5_CHILD_EXIT_{completed_process.returncode}")
        completion = _wait_for_completion(planner, manifest, spool)
        completion.update(
            {
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "elapsed_seconds": time.monotonic() - started,
                "terminal_exit_code": completed_process.returncode,
                "spool_path": str(spool),
            }
        )
        _write_new(child_root / "COMPLETE.json", completion)
        results.append(completion)
        if len(completed) == 0 and len(results) == 1:
            _write_new(
                execution_root / "CANDIDATE_RUNTIME_STATE.json",
                {
                    "schema": 1,
                    "candidate_id": "CAND-ETH-ST-001",
                    "status": "RUNNING",
                    "candidate_budget_consumed": 1,
                    "transition_trigger": "FIRST_VALID_RESULT_BEARING_CHILD_COMPLETE",
                    "first_run_id": run_id,
                    "root_sha256": ROOT_SHA256,
                    "at": completion["completed_at"],
                },
            )
        if _terminal_process_count() != 0:
            raise Gate1BatchError("MT5_OR_TESTER_REMAINS_AFTER_CHILD")
    batch_complete = {
        "schema": 1,
        "status": "COMPLETE",
        "batch_id": batch_id,
        "run_ids": plan["run_ids"],
        "elapsed_seconds": sum(float(row["elapsed_seconds"]) for row in results),
        "completed_at": datetime.now(timezone.utc).isoformat(),
    }
    _write_new(batch_root / "COMPLETE.json", batch_complete)
    return batch_complete


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="KingEA Gate 1 manual foreground batch")
    parser.add_argument("--workspace", type=Path, default=Path(r"C:\KingEA_v1"))
    parser.add_argument("--children", type=int, default=2)
    parser.add_argument(
        "--terminal", type=Path, default=Path(r"C:\Program Files\MetaTrader 5\terminal64.exe")
    )
    parser.add_argument(
        "--terminal-data",
        type=Path,
        default=Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"),
    )
    parser.add_argument(
        "--common-files",
        type=Path,
        default=Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files"),
    )
    args = parser.parse_args(argv)
    try:
        value = _run(args)
        print(json.dumps(value, sort_keys=True))
        return 0
    except (
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
