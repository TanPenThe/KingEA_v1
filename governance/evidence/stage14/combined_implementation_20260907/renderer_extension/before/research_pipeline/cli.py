"""Command-line adapter for the pure Stage 12 pipeline module."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from .stage12 import Stage12Error, Stage12Pipeline


def _read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_new(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="KingEA guarded Stage 12 orchestrator")
    subparsers = parser.add_subparsers(dest="command", required=True)
    plan = subparsers.add_parser("plan")
    plan.add_argument("--facts", type=Path, required=True)
    plan.add_argument("--output", type=Path, required=True)
    verify = subparsers.add_parser("verify")
    verify.add_argument("--manifest", type=Path, required=True)
    for name in ("execute-development", "execute-oos", "execute-holdout"):
        command = subparsers.add_parser(name)
        command.add_argument("--manifest", type=Path, required=True)
        command.add_argument("--authorization", type=Path, required=True)
        command.add_argument("--terminal", type=Path, required=True)
        command.add_argument("--tester-config", type=Path, required=True)
        command.add_argument("--tester-set", type=Path, required=True)
        command.add_argument("--common-files-root", type=Path, required=True)
    args = parser.parse_args(argv)
    pipeline = Stage12Pipeline()
    try:
        if args.command == "plan":
            manifest = pipeline.plan_run(_read_json(args.facts))
            _write_new(args.output, manifest)
            print(json.dumps({"status": "PLANNED", "manifest_sha256": manifest["manifest_sha256"]}))
            return 0
        manifest = _read_json(args.manifest)
        if args.command == "verify":
            decision = pipeline.execution_decision(
                f"execute-{str(manifest.get('purpose', '')).lower()}", manifest, None
            )
            hash_valid = decision.get("reason") != "MANIFEST_HASH_MISMATCH"
            print(json.dumps({"status": "PASS" if hash_valid else "FAIL", "hash_valid": hash_valid}))
            return 0 if hash_valid else 2
        authorization = _read_json(args.authorization)
        decision = pipeline.execution_decision(args.command, manifest, authorization)
        if not decision["allowed"]:
            print(json.dumps(decision))
            return 3
        bundle = pipeline.render_tester_bundle(manifest, authorization)
        manifest_file_hash = Stage12Pipeline.file_sha256(args.manifest)
        expected_set = bundle["set"].replace("SET_AT_EXECUTION", manifest_file_hash)
        if args.tester_set.read_text(encoding="utf-8-sig").replace("\r\n", "\n") != expected_set:
            raise Stage12Error("TESTER_SET_NOT_DERIVED_FROM_MANIFEST")
        if args.tester_config.read_text(encoding="utf-8-sig").replace("\r\n", "\n") != bundle["ini"]:
            raise Stage12Error("TESTER_CONFIG_NOT_DERIVED_FROM_MANIFEST")
        tester_contract = Stage12Pipeline.validate_tester_ini_text(
            args.tester_config.read_text(encoding="utf-8-sig")
        )
        if not tester_contract["passed"]:
            raise Stage12Error(str(tester_contract["reason"]))
        if not args.terminal.is_file() or args.terminal.name.lower() != "terminal64.exe":
            raise Stage12Error("TERMINAL_IDENTITY_INVALID")
        common_manifest = (
            args.common_files_root
            / "KingEA"
            / "runs"
            / f"{manifest['manifest_sha256']}.json"
        )
        common_manifest.parent.mkdir(parents=True, exist_ok=True)
        if common_manifest.exists():
            if Stage12Pipeline.file_sha256(common_manifest) != manifest_file_hash:
                raise Stage12Error("COMMON_MANIFEST_CONFLICT")
        else:
            common_manifest.write_bytes(args.manifest.read_bytes())
        completed = subprocess.run(
            [str(args.terminal), f"/config:{args.tester_config}"],
            check=False,
            timeout=int(manifest.get("timeout_seconds", 86_400)),
        )
        return completed.returncode
    except (OSError, ValueError, Stage12Error, subprocess.SubprocessError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}), file=sys.stderr)
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
