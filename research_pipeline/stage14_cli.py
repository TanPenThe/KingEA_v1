"""Filesystem/process adapter for the pure Stage 14 coordinator.

Nothing in this adapter creates authorization.  Result-bearing execution needs
an owner-created detached authorization matching the exact gate root and child.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from .mql5_calendar import (
    CalendarSourceError,
    Mql5WebsiteCalendarAdapter,
    Mql5WebsiteHttpAdapter,
)
from .stage14 import ResearchRunCoordinator, Stage14Error


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_new(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(value, indent=2, sort_keys=True) + "\n"
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(encoded)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="KingEA Stage 14 governed coordinator")
    commands = parser.add_subparsers(dest="command", required=True)

    root = commands.add_parser("prepare-root")
    root.add_argument("--gate", type=int, choices=(1, 2, 3), required=True)
    root.add_argument("--facts", type=Path, required=True)
    root.add_argument("--output", type=Path, required=True)

    child = commands.add_parser("prepare-child")
    child.add_argument("--facts", type=Path, required=True)
    child.add_argument("--output", type=Path, required=True)

    bundle = commands.add_parser("render-bundle")
    bundle.add_argument("--manifest", type=Path, required=True)
    bundle.add_argument("--authorization", type=Path, required=True)
    bundle.add_argument("--set-output", type=Path, required=True)
    bundle.add_argument("--ini-output", type=Path, required=True)

    ingest = commands.add_parser("ingest-frame")
    ingest.add_argument("--manifest", type=Path, required=True)
    ingest.add_argument("--frame", type=Path, required=True)
    ingest.add_argument("--spool", type=Path, required=True)

    finalize = commands.add_parser("finalize")
    finalize.add_argument("--manifest", type=Path, required=True)
    finalize.add_argument("--spool", type=Path, required=True)

    benchmark = commands.add_parser("benchmark")
    benchmark.add_argument("--facts", type=Path, required=True)
    benchmark.add_argument("--output", type=Path, required=True)

    calendar = commands.add_parser("fetch-calendar-website")
    calendar.add_argument("--start", required=True)
    calendar.add_argument("--end", required=True)
    calendar.add_argument("--native-csv", type=Path, required=True)
    calendar.add_argument("--output-root", type=Path, required=True)

    execute = commands.add_parser("execute-child")
    execute.add_argument("--manifest", type=Path, required=True)
    execute.add_argument("--authorization", type=Path, required=True)
    execute.add_argument("--pre-tooling", type=Path, required=True)
    execute.add_argument("--set", dest="set_path", type=Path, required=True)
    execute.add_argument("--ini", type=Path, required=True)
    execute.add_argument("--terminal", type=Path, required=True)

    args = parser.parse_args(argv)
    coordinator = ResearchRunCoordinator()
    try:
        if args.command == "prepare-root":
            facts = read_json(args.facts)
            common = {
                "artifact_hashes": facts.pop("artifact_hashes"),
                "mt5_build": facts.pop("mt5_build"),
                "account_fingerprint": facts.pop("account_fingerprint"),
            }
            value = coordinator.prepare_gate_root(args.gate, common, **facts)
            write_new(args.output, value)
        elif args.command == "prepare-child":
            value = coordinator.prepare_child(read_json(args.facts))
            write_new(args.output, value)
        elif args.command == "render-bundle":
            value = coordinator.render_bundle(
                read_json(args.manifest), read_json(args.authorization)
            )
            args.set_output.parent.mkdir(parents=True, exist_ok=True)
            args.ini_output.parent.mkdir(parents=True, exist_ok=True)
            with args.set_output.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(value["set"])
            with args.ini_output.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(value["ini"])
        elif args.command == "ingest-frame":
            value = coordinator.append_frame(
                args.spool, read_json(args.manifest), read_json(args.frame)
            )
        elif args.command == "finalize":
            value = coordinator.finalize_frames(args.spool, read_json(args.manifest))
        elif args.command == "benchmark":
            value = coordinator.evaluate_benchmark(**read_json(args.facts))
            write_new(args.output, value)
        elif args.command == "fetch-calendar-website":
            if args.output_root.exists():
                raise Stage14Error("CALENDAR_EVIDENCE_ROOT_ALREADY_EXISTS")
            try:
                start = datetime.fromisoformat(args.start)
                end = datetime.fromisoformat(args.end)
            except ValueError as exc:
                raise Stage14Error("CALENDAR_RANGE_INVALID") from exc
            native_text = args.native_csv.read_text(encoding="utf-8-sig")
            http = Mql5WebsiteHttpAdapter()
            raw_segments: list[tuple[dict[str, str], bytes]] = []

            def recording_fetch(request: dict[str, str]) -> bytes:
                raw = http.fetch_segment(request)
                raw_segments.append((dict(request), raw))
                return raw

            adapter = Mql5WebsiteCalendarAdapter()
            snapshot = adapter.build_snapshot(start, end, recording_fetch)
            coverage = adapter.validate_coverage(snapshot)
            reconciliation = adapter.reconcile_native(snapshot, native_text)
            native_snapshot = coordinator.parse_calendar_export(
                native_text, start=args.start, end=args.end
            )

            args.output_root.mkdir(parents=True)
            raw_root = args.output_root / "raw"
            raw_root.mkdir()
            raw_manifest = []
            for index, (request, raw) in enumerate(raw_segments, start=1):
                raw_path = raw_root / f"segment_{index:02d}.json"
                with raw_path.open("xb") as stream:
                    stream.write(raw)
                raw_manifest.append(
                    {
                        "index": index,
                        "request": request,
                        "path": str(raw_path.resolve()),
                        "size": len(raw),
                        "sha256": hashlib.sha256(raw).hexdigest().upper(),
                    }
                )
            write_new(args.output_root / "website_snapshot.json", snapshot)
            write_new(args.output_root / "coverage.json", coverage)
            write_new(args.output_root / "native_reconciliation.json", reconciliation)
            write_new(args.output_root / "native_snapshot.json", native_snapshot)
            value = {
                "schema": 1,
                "status": "ACCEPTED",
                "source_role": "CORROBORATING_GOVERNED_WEBSITE_ADAPTER",
                "native_role": "PRIMARY_MT5_TRADE_SERVER_CALENDAR",
                "website_snapshot_sha256": snapshot["snapshot_sha256"],
                "native_csv_sha256": reconciliation["native_csv_sha256"],
                "native_snapshot_sha256": native_snapshot["snapshot_sha256"],
                "matched_events": reconciliation["matched_events"],
                "raw_segments": raw_manifest,
                "coverage": coverage,
            }
            write_new(args.output_root / "manifest.json", value)
        elif args.command == "execute-child":
            manifest = read_json(args.manifest)
            authorization = read_json(args.authorization)
            decision = coordinator.authorize(manifest, authorization)
            if not decision["allowed"]:
                raise Stage14Error(str(decision["reason"]))
            pre_tooling = coordinator.verify_pre_tooling_manifest(read_json(args.pre_tooling))
            if not pre_tooling["passed"]:
                raise Stage14Error(str(pre_tooling["reason"]))
            actual_bundle = {
                "set": args.set_path.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
                "ini": args.ini.read_text(encoding="utf-8-sig").replace("\r\n", "\n"),
            }
            coordinator.verify_bundle(manifest, authorization, actual_bundle)
            if not args.terminal.is_file() or args.terminal.name.lower() != "terminal64.exe":
                raise Stage14Error("TERMINAL_IDENTITY_INVALID")
            completed = subprocess.run(
                [str(args.terminal), f"/config:{args.ini}"],
                check=False,
                timeout=int(manifest.get("timeout_seconds", 86_400)),
            )
            return completed.returncode
        else:  # pragma: no cover
            raise Stage14Error("COMMAND_INVALID")
        print(json.dumps(value, sort_keys=True))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError, Stage14Error, CalendarSourceError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}), file=sys.stderr)
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
