from __future__ import annotations

import argparse
import json
from pathlib import Path

from .gate1_evidence_archive import EvidenceArchiveError, Gate1EvidenceArchive


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify and consolidate one Gate 1 spool")
    parser.add_argument("run_id")
    parser.add_argument("--invalidate-partial", action="store_true")
    parser.add_argument("--last-configuration", type=int)
    parser.add_argument("--prepare-retry", action="store_true")
    parser.add_argument("--batch-id")
    parser.add_argument("--attempt-id")
    args = parser.parse_args()
    module = Gate1EvidenceArchive(
        Path(r"C:\KingEA_v1\governance\evidence\stage14\gate1_execution_20260809_v2"),
        Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files\KingEA\stage14_spool"),
        Path(r"C:\KingEA_archives\stage14\gate1_spools"),
    )
    try:
        if args.prepare_retry:
            if not args.batch_id or not args.attempt_id:
                raise EvidenceArchiveError("BATCH_AND_ATTEMPT_REQUIRED")
            result = module.prepare_retry(
                args.run_id, batch_id=args.batch_id, attempt_id=args.attempt_id
            )
        elif args.invalidate_partial:
            if args.last_configuration is None:
                raise EvidenceArchiveError("LAST_CONFIGURATION_REQUIRED")
            result = module.invalidate_partial(
                args.run_id,
                reason="MT5_AGENT_DISK_EXHAUSTION_AFTER_653_OF_1000_FRAMES",
                last_configuration_id=args.last_configuration,
            )
        else:
            result = module.archive_completed(args.run_id, remove_verified=True)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, ValueError, EvidenceArchiveError) as exc:
        print(json.dumps({"status": "FAIL", "reason": str(exc)}))
        return 4


if __name__ == "__main__":
    raise SystemExit(main())
