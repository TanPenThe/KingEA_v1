"""Foreground, non-executing adapter for the streaming Gate 1 finalizer."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .gate1_finalization import (
    Gate1FinalizationError,
    Gate1FinalizationRequest,
    Gate1Finalizer,
)


def _progress(value: dict) -> None:
    print(json.dumps({"kind": "GATE1_FINALIZATION_PROGRESS", **value}, sort_keys=True), flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Stream and finalize governed Gate 1 development evidence"
    )
    parser.add_argument("--workspace", type=Path, default=Path(r"C:\KingEA_v1"))
    parser.add_argument(
        "--archive-root",
        type=Path,
        default=Path(r"C:\KingEA_archives\stage14\gate1_spools"),
    )
    parser.add_argument("--output-root", type=Path, required=True)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument("--batch-id", type=int)
    actions.add_argument("--merge", action="store_true")
    actions.add_argument("--status", action="store_true")
    actions.add_argument("--single-stream", action="store_true")
    args = parser.parse_args(argv)
    workspace = args.workspace.resolve()
    evidence = workspace / "governance" / "evidence" / "stage14"
    request = Gate1FinalizationRequest(
        prior_package=evidence / "gate1_replacement_20260809",
        continuation_package=evidence / "gate1_continuation_20260824_v2",
        parity_package=evidence / "gate1_build_transition_20260823_v2",
        archive_root=args.archive_root.resolve(),
        execution_root=evidence / "gate1_execution_20260809_v2",
        output_root=args.output_root.resolve(),
        progress_callback=_progress,
    )
    shard_root = args.output_root.resolve() / "audit_shards"
    try:
        finalizer = Gate1Finalizer()
        if args.single_stream:
            result = finalizer.finalize(request)
        elif args.status:
            result = finalizer.batch_status(request, shard_root)
        elif args.merge:
            result = finalizer.merge_batches(request, shard_root)
        else:
            result = finalizer.audit_batch(request, shard_root, args.batch_id)
    except (Gate1FinalizationError, OSError, UnicodeError, ValueError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}, sort_keys=True), file=sys.stderr)
        return 4
    print(
        json.dumps(
            {
                **result,
                "output_root": str(args.output_root.resolve()),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
