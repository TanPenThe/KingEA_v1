"""Read-only command adapter for Gate 1 storage admission."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .gate1_storage_policy import Gate1StoragePolicy


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument(
        "--archive-root",
        type=Path,
        default=Path(r"C:\KingEA_archives\stage14\gate1_spools"),
    )
    args = parser.parse_args()
    decision = Gate1StoragePolicy.inspect_workspace(
        workspace=args.workspace,
        archive_root=args.archive_root,
    )
    print(json.dumps(decision, sort_keys=True))
    return 0 if decision["launch_allowed"] else 4


if __name__ == "__main__":
    raise SystemExit(main())
