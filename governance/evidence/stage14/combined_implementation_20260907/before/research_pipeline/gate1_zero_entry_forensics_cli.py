"""CLI for bounded, read-only Gate 1 zero-entry forensic batches."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from research_pipeline.gate1_zero_entry_forensics import Gate1ZeroEntryForensics, Gate1ZeroEntryForensicsError


def canonical(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True) + "\n").encode("utf-8")


def run_ids(first: int, count: int) -> list[str]:
    if first < 0 or count < 1 or first + count > 200:
        raise Gate1ZeroEntryForensicsError("AUDIT_BATCH_RANGE_INVALID")
    return [f"G1-{number:04d}" for number in range(first, first + count)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--replacement-children", required=True, type=Path)
    parser.add_argument("--continuation-children", required=True, type=Path)
    parser.add_argument("--archive-dir", required=True, type=Path)
    parser.add_argument("--diagnostic-result", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--first", required=True, type=int)
    parser.add_argument("--count", default=20, type=int)
    parser.add_argument("--stage13", action="store_true")
    parser.add_argument("--artifact-prefix", default="")
    args = parser.parse_args()
    ids = run_ids(args.first, args.count)
    auditor = Gate1ZeroEntryForensics()
    if args.stage13:
        report = auditor.audit_stage13_batch(
            replacement_children=args.replacement_children,
            continuation_children=args.continuation_children,
            archive_dir=args.archive_dir, run_ids=ids,
        )
    else:
        report = auditor.audit_batch(
            replacement_children=args.replacement_children,
            continuation_children=args.continuation_children,
            archive_dir=args.archive_dir,
            run_ids=ids,
            diagnostic_result=args.diagnostic_result,
        )
    report["run_range"] = [ids[0], ids[-1]]
    evidence_sha256 = hashlib.sha256(canonical(report)).hexdigest().upper()
    prefix = args.artifact_prefix or ("STAGE13_FORENSIC_BATCH" if args.stage13 else "FORENSIC_BATCH")
    path = args.output_dir / f"{prefix}_{args.first:04d}_{args.first + args.count - 1:04d}.json"
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if path.exists():
        existing = json.loads(path.read_text(encoding="utf-8"))
        if existing.get("evidence_sha256") != evidence_sha256:
            raise Gate1ZeroEntryForensicsError("FORENSIC_BATCH_OUTPUT_CONFLICT")
    else:
        report["created_at"] = datetime.now(timezone.utc).isoformat()
        report["evidence_sha256"] = evidence_sha256
        path.write_bytes(canonical(report))
    print(json.dumps({"status": report["status"], "output": str(path), "sha256": evidence_sha256}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Gate1ZeroEntryForensicsError as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}, sort_keys=True))
        raise SystemExit(4)
