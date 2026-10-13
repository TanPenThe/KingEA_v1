"""Adopted transition invariant: synthetic fixtures, no native execution."""
import copy
import tempfile
import unittest
from pathlib import Path
from test_successor_evidence import ControlFixture
from v3_fixture import package
from research_pipeline.decision_a_evidence import *
from research_pipeline.successor_evidence import PinnedControlContext, SuccessorEvidenceError
from research_pipeline.stage14 import ResearchRunCoordinator


class SwapTransitionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.f = ControlFixture(Path(self.temp.name))
        self.files, self.seal, self.binding, self.profile = package(self.f, False, True, True)

    def change_transition(self, mutate):
        s, refs = verify_archive(self.files, self.seal, self.binding)
        r = s['swap_reconciliations'][0]
        inventory = parse_json(self.files['references.json'])
        support = {e['path']: (e['role'], self.files[e['path']]) for e in inventory['entries']}
        path = next(path for path, (role, _) in support.items() if role == 'SWAP_INTERVAL:201')
        receipt = parse_json(support[path][1]); mutate(receipt)
        raw = json_bytes(receipt)
        support[path] = (support[path][0], raw)
        r['interval_authority_hash'] = digest(raw)
        s['integrity']['archive_inventory_hash'] = ''
        self.files = construct_archive(support, s, self.seal['binding'])
        self.seal['archive_sha256'] = digest(self.files['archive.json'])

    def consume(self, reject=False, detail=None):
        f = self.f
        ref = f.store('transition-seal.json', self.seal)
        f.control['completed_archives'][f.manifest['manifest_sha256'] + ':0'] = [ref]
        f.pin = f.store('control.json', f.control)['sha256']
        s = read_package(self.files['sidecar.evidence'])
        r = parse_json(self.files['references.json'])
        event = next(e for e in r['entries'] if e['role'] == 'STAGE13_EVENT')
        f.frame.update(native_cost_packages=[encode_archive(self.files)],
                       stage13_close_frames=[self.files[event['path']].decode()],
                       boundary_finalization_count=int(s['terminal']['outcome'] == 'EVALUATOR_BOUNDARY'))
        c = ResearchRunCoordinator(control_context=PinnedControlContext(f.directory, f.pin))
        spool = f.directory / 'spool'
        before = {p: p.read_bytes() for p in f.directory.rglob('*') if p.is_file()}
        call = lambda: c.append_frame(spool, f.manifest, dict(frame_id='0', payload=f.frame))
        if reject:
            with self.assertRaises(SuccessorEvidenceError) as caught: call()
            self.assertEqual(str(caught.exception), 'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED')
            self.assertEqual(caught.exception.stage, 'ingestion')
            if detail: self.assertIn(detail, caught.exception.detail)
            self.assertEqual(before, {p: p.read_bytes() for p in f.directory.rglob('*') if p.is_file()})
            self.assertFalse(spool.exists())
            for name in ('FINALIZED.json','VALID_V3.json','RUNNING.json','GATE2_READY.json','STAGE13_COMPLETE.json'):
                self.assertFalse(any(f.directory.rglob(name)))
        else:
            self.assertEqual(call()['status'], 'APPENDED')

    def test_T01_assertion_only_rejects(self):
        self.change_transition(lambda r: [r.pop(k) for k in list(r) if k not in ('run_id','group_id')])
        self.change_transition(lambda r: r.update(no_accrual_authenticated=True))
        self.consume(True, 'SWAP_TRANSITION_RECEIPT_FIELDS')

    def test_T02_native_linked_B_D_A_conservation(self): self.consume()

    def test_T03_unbound_balancing_amount_rejects(self):
        self.change_transition(lambda r: r.update(Ub='-40', Ds='-20', Ua='-20'))
        self.consume(True, 'VALUES_UNBOUND')

    def test_T04_wrong_position(self):
        self.change_transition(lambda r: r.update(position_id=999)); self.consume(True, 'IDENTITY')

    def test_T05_wrong_request_or_deal(self):
        self.change_transition(lambda r: r.update(deal_id=202, order_id=102)); self.consume(True, 'LINK')

    def test_T06_wrong_q_Vr(self):
        self.change_transition(lambda r: r.update(q='.5', Vr='1.5')); self.consume(True, 'VALUES_UNBOUND')

    def test_T07_failed_native_read(self):
        self.change_transition(lambda r: r['read_flags'].update(POSITION_SWAP_BEFORE=False))
        self.consume(True, 'READ_FAILED')

    def test_T08_successful_zero_reads(self):
        self.files, self.seal, self.binding, self.profile = package(self.f, False, True, False)
        self.consume()

    def test_T09_wrong_profile(self):
        self.change_transition(lambda r: r.update(native_swap_profile_hash='F'*64))
        self.consume(True, 'PROFILE_NOT_AUTHORIZED')

    def test_T10_conservation_failure_no_tolerance(self):
        s, refs = verify_archive(self.files, self.seal, self.binding)
        r = s['swap_reconciliations'][0]
        receipt = parse_json(refs.resolve(r['interval_authority_hash'], 'SWAP_INTERVAL:201'))
        before = copy.deepcopy(next(x for x in s['residual_snapshots'] if x['snapshot_hash']==r['before_snapshot_hash']))
        after = copy.deepcopy(next(x for x in s['residual_snapshots'] if x['snapshot_hash']==r['after_snapshot_hash']))
        before['position_swap'] = '-4.00000001'; receipt['Ub'] = before['position_swap']
        with self.assertRaisesRegex(ValueError, 'SWAP_TRANSITION_CONSERVATION_FAIL'):
            validate_swap_transition(receipt,before,s['exit_portions'][0],after,
                binding=s['binding'],original=s['original'],precision=s['precision'],profile=self.profile)

    def test_T11_old_residual_not_added_at_final_close(self):
        self.files,self.seal,self.binding,self.profile = package(self.f,False,True,True,final_swap='-9')
        s = read_package(self.files['sidecar.evidence'])
        self.assertEqual(number(s['terminal']['aggregate_swap']), -11)
        self.assertEqual(number(s['residual_snapshots'][-1]['position_swap']), -2)
        self.consume()

    def test_T12_final_actual_swap_once_without_arbitrary_interval(self):
        self.files,self.seal,self.binding,self.profile = package(self.f,False,False,True,final_swap='-17')
        s = read_package(self.files['sidecar.evidence'])
        self.assertEqual(s['swap_reconciliations'], [])
        self.assertEqual(number(s['terminal']['aggregate_swap']), -17)
        self.consume()

    def test_T13_boundary_realized_plus_sealed_residual(self):
        self.files,self.seal,self.binding,self.profile = package(self.f,True,True,True)
        self.assertEqual(number(read_package(self.files['sidecar.evidence'])['terminal']['aggregate_swap']), -4)
        self.consume()

    def test_T14_stale_replayed_receipt(self):
        self.change_transition(lambda r: r.update(before_snapshot_hash=r['after_snapshot_hash']))
        self.consume(True, 'LINK')

    def test_T15_cotampered_receipt_and_new_integrity_seal_cannot_change_rule(self):
        self.change_transition(lambda r: r.update(adopted_rule_hash='A'*64))
        self.consume(True, 'RULE_NOT_AUTHORIZED')

    def test_T16_unsupported_observed_financial_event(self):
        self.f.frame['unsupported_native_financial_events'] = [{'deal':777,'type':'CORRECTION'}]
        self.consume(True, 'SWAP_PROFILE_OUTSIDE_SUPPORTED_SEMANTICS')

    def test_T17_legacy_assertion_cannot_be_added_to_valid_receipt(self):
        self.change_transition(lambda r: r.update(no_accrual_authenticated=True))
        self.consume(True, 'RECEIPT_FIELDS')

    def test_T18_containment_cannot_supply_transition(self):
        self.change_transition(lambda r: r.update(kind='INVALID_RUN_CONTAINMENT_EVIDENCE'))
        self.consume(True, 'RULE_NOT_AUTHORIZED')


if __name__ == '__main__': unittest.main()
