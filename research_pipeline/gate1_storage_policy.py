"""Deterministic Gate 1 storage admission policy."""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Sequence


class Gate1StoragePolicy:
    GIB = 1024**3
    HARD_FLOOR_BYTES = 16 * GIB
    LAUNCH_FLOOR_BYTES = 30 * GIB
    ARCHIVE_TRIGGER_BYTES = 45 * GIB
    ARCHIVE_TRIGGER_RUNS = 30

    @classmethod
    def inspect_workspace(
        cls,
        *,
        workspace: Path,
        archive_root: Path,
        free_bytes: int | None = None,
    ) -> dict:
        workspace = Path(workspace).resolve()
        archive_root = Path(archive_root).resolve()
        children = (
            workspace
            / "governance/evidence/stage14/gate1_execution_20260809_v2/children"
        )
        completed: list[str] = []
        archived: list[str] = []
        try:
            for marker in children.glob("G1-????/COMPLETE.json"):
                value = json.loads(marker.read_text(encoding="utf-8"))
                run_id = marker.parent.name
                if value.get("status") != "COMPLETE" or value.get("run_id") != run_id:
                    raise ValueError("invalid completion marker")
                completed.append(run_id)
            for marker in archive_root.glob("*.ARCHIVED.json"):
                value = json.loads(marker.read_text(encoding="utf-8"))
                run_id = str(value.get("run_id", ""))
                if value.get("status") != "ARCHIVED_VERIFIED" or not run_id:
                    raise ValueError("invalid archive marker")
                archived.append(run_id)
        except (OSError, UnicodeError, ValueError, json.JSONDecodeError):
            return {
                "action": "BLOCK_STORAGE_STATE_INVALID",
                "launch_allowed": False,
                "unarchived_count": 0,
            }
        if free_bytes is None:
            free_bytes = shutil.disk_usage(workspace.anchor).free
        decision = cls.evaluate(
            free_bytes=free_bytes,
            completed_run_ids=sorted(completed),
            archived_run_ids=sorted(archived),
        )
        unarchived = sorted(set(completed) - set(archived))
        return {
            **decision,
            "free_bytes": free_bytes,
            "free_gb": round(free_bytes / cls.GIB, 2),
            "completed_count": len(completed),
            "archived_count": len(archived),
            "first_unarchived": unarchived[0] if unarchived else None,
            "last_unarchived": unarchived[-1] if unarchived else None,
        }

    @classmethod
    def evaluate(
        cls,
        *,
        free_bytes: int,
        completed_run_ids: Sequence[str],
        archived_run_ids: Sequence[str],
    ) -> dict:
        completed = set(completed_run_ids)
        archived = set(archived_run_ids)
        if not archived.issubset(completed):
            return {
                "action": "BLOCK_STORAGE_STATE_INVALID",
                "launch_allowed": False,
                "unarchived_count": len(completed - archived),
            }
        unarchived_count = len(completed - archived)
        if free_bytes < cls.HARD_FLOOR_BYTES:
            return {
                "action": "HARD_STOP_DISK_BELOW_16_GB",
                "launch_allowed": False,
                "unarchived_count": unarchived_count,
            }
        if free_bytes < cls.LAUNCH_FLOOR_BYTES:
            return {
                "action": "BLOCK_RESEARCH_LOW_DISK",
                "launch_allowed": False,
                "unarchived_count": unarchived_count,
            }
        if (
            free_bytes <= cls.ARCHIVE_TRIGGER_BYTES
            or unarchived_count >= cls.ARCHIVE_TRIGGER_RUNS
        ):
            return {
                "action": "ARCHIVE_REQUIRED",
                "launch_allowed": False,
                "unarchived_count": unarchived_count,
            }
        return {
            "action": "ALLOW_RESEARCH",
            "launch_allowed": True,
            "unarchived_count": unarchived_count,
        }
