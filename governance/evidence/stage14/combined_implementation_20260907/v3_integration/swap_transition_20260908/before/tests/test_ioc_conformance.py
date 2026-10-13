import unittest
import json
import hashlib
import tempfile
import shutil
from pathlib import Path

from research_pipeline.ioc_conformance import classify, verify_sealed

PROOF = Path(__file__).resolve().parents[1] / 'governance/evidence/stage14/ioc_conformance_20260905/NC-IOC-01'


class IOCConformanceTests(unittest.TestCase):
    def fixture(self):
        return dict(environment_verified=True, filling='ORDER_FILLING_IOC',
                    execution_mode=20, candidate_executed=False, fallback_count=0,
                    check_retcode=10030, order_attempts=0, send_retcode=0)

    def test_actual_invalid_fill_rejects_frozen_contract(self):
        evidence = dict(environment_verified=True, filling='ORDER_FILLING_IOC',
                        execution_mode=20, candidate_executed=False, fallback_count=0,
                        check_retcode=10030, order_attempts=0, send_retcode=0)
        self.assertEqual(classify(evidence), 'FROZEN_IOC_EXECUTION_CONTRACT_INCOMPATIBLE')

    def test_done_without_authenticated_full_fill_is_not_support_proof(self):
        evidence = self.fixture()
        evidence.update(check_retcode=10009, order_attempts=1, send_retcode=10009)
        with self.assertRaises(ValueError):
            classify(evidence)

    def test_failed_check_followed_by_send_is_a_conflict(self):
        evidence = self.fixture()
        evidence.update(order_attempts=1, send_retcode=10030)
        with self.assertRaises(ValueError):
            classify(evidence)

    def test_sealed_real_ioc_rejection_is_self_contained(self):
        with tempfile.TemporaryDirectory() as tmp:
            retained = Path(tmp) / 'retained'
            shutil.copytree(PROOF, retained)
            self.assertEqual(verify_sealed(retained)['classification'],
                             'FROZEN_IOC_EXECUTION_CONTRACT_INCOMPATIBLE')

    def test_scope_fallback_and_other_check_errors_never_mean_ioc_supported(self):
        for change in (dict(environment_verified=False), dict(filling='ORDER_FILLING_FOK'),
                       dict(execution_mode=0), dict(candidate_executed=True),
                       dict(fallback_count=1), dict(check_retcode=10019)):
            with self.subTest(change=change):
                evidence = self.fixture(); evidence.update(change)
                with self.assertRaises(ValueError):
                    classify(evidence)

    def test_missing_and_altered_actual_evidence_fail_closed(self):
        for name in ('specification.json', 'request.json', 'order_check.json', 'execution.json'):
            for remove in (False, True):
                with self.subTest(name=name, remove=remove), tempfile.TemporaryDirectory() as tmp:
                    retained = Path(tmp)/'retained'; shutil.copytree(PROOF, retained)
                    p = retained/'runtime/harness'/name
                    if remove:
                        p.unlink()
                    else:
                        p.write_bytes(p.read_bytes()+b' ')
                    with self.assertRaises(ValueError):
                        verify_sealed(retained)

    def test_wrong_runtime_facts_fail_even_with_rehashed_inventory(self):
        cases = [('runtime/harness/request.json', 'type_filling', 'ORDER_FILLING_FOK'),
                 ('runtime/harness/specification.json', 'terminal_build', 1),
                 ('runtime/harness/specification.json', 'account_fingerprint', '0'*64),
                 ('runtime/harness/order_check.json', 'retcode', 10009),
                 ('runtime/harness/execution.json', 'attempts', 1),
                 ('RUNTIME_RECEIPT.json', 'pid', 1)]
        for name, key, value in cases:
            with self.subTest(name=name, key=key), tempfile.TemporaryDirectory() as tmp:
                retained = Path(tmp)/'retained'; shutil.copytree(PROOF, retained)
                p = retained/name; data = json.loads(p.read_text()); data[key] = value
                p.write_text(json.dumps(data))
                seal = retained/'SEALED_INVENTORY.json'; inventory = json.loads(seal.read_text())
                for item in inventory['files']:
                    if Path(item['path']) == Path(name):
                        item['size'] = p.stat().st_size
                        item['sha256'] = hashlib.sha256(p.read_bytes()).hexdigest().upper()
                seal.write_text(json.dumps(inventory))
                with self.assertRaises(ValueError):
                    verify_sealed(retained)

    def test_ioc_harness_cannot_run_candidate_or_fallback(self):
        source = (PROOF/'build/MQL5/Experts/KingEA/IOCExecutionConformance.mq5').read_text()
        self.assertNotIn('ORDER_FILLING_FOK', source)
        self.assertEqual(source.count('OrderSend('), 1)
        self.assertIn('MQLInfoInteger(MQL_TESTER)', source)
        self.assertIn('order.type_filling=ORDER_FILLING_IOC;', source)
        self.assertNotIn('HistoryDeal', source)
        self.assertNotIn('#include <KingEA/Candidate', source)
        self.assertNotIn('#include <KingEA/Sleeve', source)


if __name__ == '__main__':
    unittest.main()
