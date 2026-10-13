"""Create immutable, approved-only Gate 1 zero-entry diagnostic bundles."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from research_pipeline.gate1_zero_entry_execution import (
    Gate1ZeroEntryExecution,
    Gate1ZeroEntryExecutionError,
)


def write_new(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(value, indent=2, sort_keys=True) + "\n"
    if path.exists():
        if path.read_text(encoding="utf-8") != encoded:
            raise Gate1ZeroEntryExecutionError("IMMUTABLE_DIAGNOSTIC_ARTIFACT_CONFLICT")
        return
    path.write_text(encoded, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--prepare", action="store_true")
    args = parser.parse_args()
    if not args.prepare:
        parser.error("only --prepare is supported; this CLI cannot launch MT5")
    try:
        reference = json.loads(args.reference.read_text(encoding="utf-8"))
        controller = Gate1ZeroEntryExecution()
        plan = controller.build_plan(reference, args.output_root)
        write_new(args.output_root / "OWNER_APPROVAL.json", {
            "schema": 1,
            "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_OWNER_APPROVAL",
            "owner_approved": True,
            "owner_statement": "Explicit approval received to run the bounded development-only zero-entry diagnostic.",
            "diagnostic_root_sha256": controller.ROOT_SHA256,
            "prepared_root_sha256": controller.PREPARED_ROOT_SHA256,
            "orders_authorized": False,
            "returns_authorized": False,
            "oos_authorized": False,
            "holdout_authorized": False,
        })
        write_new(args.output_root / "EXECUTION_PLAN.json", plan)
        for child in plan["children"]:
            bundle = controller.render_bundle(child)
            write_new(args.output_root / "children" / f"{child['branch']}.json", child)
            path = args.output_root / "bundles" / child["branch"]
            path.mkdir(parents=True, exist_ok=True)
            for name, text in bundle.items():
                target = path / f"{child['manifest_sha256']}.{name}"
                if target.exists() and target.read_text(encoding="utf-8") != text:
                    raise Gate1ZeroEntryExecutionError("IMMUTABLE_DIAGNOSTIC_ARTIFACT_CONFLICT")
                if not target.exists():
                    target.write_text(text, encoding="utf-8", newline="\n")
        print(json.dumps({"status": "OWNER_APPROVED_PENDING_FOREGROUND_EXECUTION", "children": len(plan["children"])}, sort_keys=True))
        return 0
    except (OSError, ValueError, Gate1ZeroEntryExecutionError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}, sort_keys=True))
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
