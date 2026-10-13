"""Read-only consumer probe. All control/seal identities are synthetic fixtures.

This records an implementation gap; it is not a passing acceptance test and it
does not append/finalize frames or create research/authorization artifacts.
"""
from pathlib import Path
import json
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[6]
sys.path[:0] = [str(ROOT), str(ROOT / 'tests')]
from test_successor_evidence import ControlFixture
from v3_fixture import package
from research_pipeline.decision_a_evidence import (
    parse_json, verify_archive, validate_package,
)


def main():
    with tempfile.TemporaryDirectory(prefix='KingEA-synthetic-interval-probe-') as tmp:
        fixture = ControlFixture(Path(tmp))
        files, seal, binding, profile = package(fixture, False, True, True, False)
        sidecar, references = verify_archive(files, seal, binding)
        intervals = [
            parse_json(references.resolve(r['interval_authority_hash'],
                       'SWAP_INTERVAL:' + str(r['deal_id'])))
            for r in sidecar['swap_reconciliations']
        ]
        validate_package(files['sidecar.evidence'], binding, profile, references)
        assert all(row['no_accrual_authenticated'] is True for row in intervals)
        print(json.dumps({
            'classification': 'IMPLEMENTATION_GAP_REPRODUCED_NOT_ACCEPTANCE',
            'synthetic_only': True,
            'reduced_normal_close_signed_swap': True,
            'consumer_currently_accepts': True,
            'interval_records': intervals,
            'interval_authority_from_independent_control': False,
            'native_general_interval_source_provided': False,
            'final_seal_authority': seal['authority'],
            'production_source_changed': False,
            'accepted_result_written': False,
            'runtime_executed': False,
        }, indent=2))


if __name__ == '__main__':
    main()
