"""Seal or sealed-only-verify B1 non-candidate evidence. Never launches MT5."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from .b1_evidence_infrastructure import B1ExternalEvidenceCoordinator, B1ExternalEvidenceRequest, B1EvidenceError

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-sealed", type=Path)
    parser.add_argument("--run-id")
    parser.add_argument("--run-manifest", type=Path)
    parser.add_argument("--source-manifest", type=Path)
    parser.add_argument("--compile-log", type=Path)
    parser.add_argument("--executable", type=Path)
    parser.add_argument("--settings", type=Path)
    parser.add_argument("--ini", type=Path)
    parser.add_argument("--authorization", type=Path)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--runtime-proof", type=Path)
    parser.add_argument("--journals", type=Path, nargs="*")
    parser.add_argument("--telemetry", type=Path)
    parser.add_argument("--result", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    coordinator = B1ExternalEvidenceCoordinator()
    try:
        if args.verify_sealed:
            value = coordinator.verify_sealed(args.verify_sealed)
        else:
            required = (args.run_id,args.run_manifest,args.source_manifest,args.compile_log,args.executable,args.settings,args.ini,args.authorization,args.receipt,args.runtime_proof,args.telemetry,args.result,args.output)
            if any(item is None for item in required) or not args.journals:
                parser.error("complete external evidence arguments are required")
            value = coordinator.seal(B1ExternalEvidenceRequest(args.run_id,args.run_manifest,args.source_manifest,args.compile_log,args.executable,args.settings,args.ini,args.authorization,args.receipt,args.runtime_proof,tuple(args.journals),args.telemetry,args.result,args.output))
        print(json.dumps(value,sort_keys=True))
        return 0
    except (B1EvidenceError,OSError,UnicodeError,ValueError) as error:
        print(json.dumps({"status":"FAIL","reason":str(error)}))
        return 4

if __name__ == "__main__":
    raise SystemExit(main())
