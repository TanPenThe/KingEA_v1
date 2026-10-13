"""Prepare the immutable, non-executable Gate 1 zero-entry diagnostic packet."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from research_pipeline.gate1_zero_entry_diagnostic import (
    Gate1ZeroEntryDiagnostic,
    Gate1ZeroEntryDiagnosticError,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", default=r"C:\KingEA_v1")
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--prepare", action="store_true")
    args = parser.parse_args()
    if not args.prepare:
        parser.error("only --prepare is implemented; execution requires separate owner approval")

    workspace = Path(args.workspace)
    root = workspace / "governance" / "evidence" / "stage14" / "gate1_finalization_20260901_v1" / "DIAGNOSTIC_ROOT.json"
    try:
        packet = Gate1ZeroEntryDiagnostic().prepare(root, Path(args.output_root))
    except (OSError, ValueError, Gate1ZeroEntryDiagnosticError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}, sort_keys=True))
        return 4
    print(json.dumps({"status": "PLANNED", "prepared_root_sha256": packet["prepared_root_sha256"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
