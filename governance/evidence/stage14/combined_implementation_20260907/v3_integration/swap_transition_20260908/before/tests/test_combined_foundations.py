"""Deterministic foundation tests; no MT5, no native proof, no execution authority."""
import copy
import tempfile
import unittest
from pathlib import Path
from research_pipeline.decision_a_evidence import (
    ImmutableInput, ExposureControl, classify_execution, validate_profile,
    digest, number, unique, SWAP_FACTS, NATIVE_PROOF,
)

class ImmutableCaptureTests(unittest.TestCase):
    def test_same_buffer_survives_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'input.json'; original=b'{"value":1}'; p.write_bytes(original)
            capture=ImmutableInput.capture(p.parent,dict(path=p.name,sha256=digest(original)))
            p.write_bytes(b'{"value":2}')
            self.assertEqual(capture.json(),{'value':1})
            self.assertEqual(capture.sha256,digest(original))
            with self.assertRaisesRegex(ValueError,'INPUT_PIN_MISMATCH'):
                ImmutableInput.capture(p.parent,dict(path=p.name,sha256=digest(original)))
    def test_calendar_uses_captured_bytes(self):
        raw=b'type,start_msc,end_msc,identity\nNEWS,100,200,event\n'
        c=ImmutableInput('calendar.csv',digest(raw),raw)
        self.assertEqual(c.calendar(),(('NEWS',100,200,'event'),))
    def test_duplicate_manifest_fields(self):
        with self.assertRaisesRegex(ValueError,'DUPLICATE_FIELD'):
            ImmutableInput('x','',b'{"x":1,"x":2}').json()
    def test_path_escape(self):
        for name in ('../x','C:x','x/y','x\\y','..',''):
            with self.subTest(name=name),self.assertRaisesRegex(ValueError,'INPUT_PATH_INVALID'):
                ImmutableInput.capture(Path('.'),dict(path=name,sha256='A'*64))
    def test_missing_local_never_uses_common(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                ImmutableInput.capture(Path(directory),dict(path='missing',sha256='A'*64))
    def test_bad_calendar_rows(self):
        for row in ('NEWS,200,100,event','NEWS,x,200,event','NEWS,100,200,','NEWS,100,200,event,extra'):
            with self.subTest(row=row),self.assertRaises(ValueError):
                ImmutableInput('x','',('type,start_msc,end_msc,identity\n'+row).encode()).calendar()
    def test_nonfinite_and_bool_rejected(self):
        for value in ('NaN','Infinity',True,float('-inf')):
            with self.subTest(value=value),self.assertRaises(ValueError):number(value)

class ExecutionContainmentTests(unittest.TestCase):
    def test_full_single(self):
        self.assertEqual(classify_execution('1',['1'],terminal=True,confirmed_executed='1'),'FOK_FULL_SINGLE_DEAL')
    def test_full_multi_is_not_partial(self):
        self.assertEqual(classify_execution('1',['.4','.6'],terminal=True,confirmed_executed='1'),'FOK_FULL_MULTI_DEAL')
    def test_partial(self):
        self.assertEqual(classify_execution('1',['.4'],terminal=True,confirmed_executed='.4'),'PARTIAL_ORDER_EXECUTION')
    def test_missing_terminality(self):
        self.assertEqual(classify_execution('1',['.4'],terminal=False),'EXECUTION_EVIDENCE_INCOMPLETE')
    def test_no_fill(self):
        self.assertEqual(classify_execution('1',[],terminal=True,confirmed_executed=0,no_fill_receipt=True),'FOK_REJECTED_NO_FILL')
    def test_excess_rejected(self):
        with self.assertRaisesRegex(ValueError,'EXCEEDS_REQUEST'):classify_execution('1',['1.1'],terminal=True,confirmed_executed='1.1')
    def test_incomplete_callback_set_waits_for_confirmed_volume(self):
        self.assertEqual(classify_execution('1',['.4'],terminal=True,confirmed_executed='1'),'EXECUTION_EVIDENCE_INCOMPLETE')
    def test_no_execution_volume_authority_cannot_classify_partial(self):
        self.assertEqual(classify_execution('1',['.4'],terminal=True),'EXECUTION_EVIDENCE_INCOMPLETE')
    def test_no_callbacks_are_not_rejection_evidence(self):
        self.assertEqual(classify_execution('1',[],terminal=True,confirmed_executed=0),'EXECUTION_EVIDENCE_INCOMPLETE')
    def test_receipt_callback_conflict_rejects(self):
        with self.assertRaisesRegex(ValueError,'EXECUTION_RECEIPT_CALLBACK_CONFLICT'):
            classify_execution('1',['1'],terminal=True,confirmed_executed='.4')
    def invalid_control(self,**overrides):
        c=ExposureControl(); args=dict(terminal=True,residual=dict(read_ok=True,position_id=7,volume='.6'),expected_position=7);args.update(overrides)
        c.observe('PARTIAL_ORDER_EXECUTION',**args);return c
    def test_actual_residual_not_requested_volume(self):
        c=self.invalid_control();self.assertEqual(c.containment()['volume'],'.6')
        self.assertTrue(c.invalid);self.assertTrue(c.monitoring)
    def test_no_retry_after_rejection(self):
        c=self.invalid_control();c.containment();c.containment_result(flat_authenticated=False)
        with self.assertRaisesRegex(ValueError,'CONTAINMENT_NOT_AUTHORIZED'):c.containment()
        self.assertTrue(c.invalid);self.assertTrue(c.monitoring)
    def test_no_retry_after_success(self):
        c=self.invalid_control();c.containment();c.containment_result(flat_authenticated=True)
        self.assertEqual(c.exposure,'FLAT_CONFIRMED');self.assertTrue(c.invalid)
        with self.assertRaises(ValueError):c.containment()
    def test_no_speculative_containment(self):
        for options in (dict(terminal=False),dict(residual=None),dict(expected_position=8),dict(residual=dict(read_ok=False,position_id=7,volume='.6'))):
            with self.subTest(options=options):
                c=self.invalid_control(**options)
                with self.assertRaises(ValueError):c.containment()
                self.assertTrue(c.monitoring)
    def test_unrelated_invalidation_not_containment_authority(self):
        c=ExposureControl();c.invalidate('PROFILE_LOST')
        c.observe('FOK_FULL_SINGLE_DEAL',terminal=True,residual=dict(read_ok=True,position_id=7,volume='.6'),expected_position=7)
        with self.assertRaisesRegex(ValueError,'CONTAINMENT_CAUSE_NOT_AUTHORIZED'):c.containment()
    def test_sticky_invalidity_after_later_supported_observation(self):
        c=self.invalid_control();c.observe('FOK_FULL_SINGLE_DEAL',terminal=True,residual=dict(read_ok=True,position_id=7,volume='.6'),expected_position=7)
        self.assertTrue(c.invalid);self.assertEqual(c.reason,'PARTIAL_ORDER_EXECUTION')

class ProfileTests(unittest.TestCase):
    def profile(self):
        return dict(accepted_proof_sha256=NATIVE_PROOF,server='JustMarkets-Demo2',symbol='ETHUSD.s',terminal_build=6140,compiler_build=6140,agent_build=6140,local=True,visual=False,dll=False,command_bridge=False,shared_trading_input=False,facts=copy.deepcopy(SWAP_FACTS))
    def test_exact_long_profile(self):validate_profile(self.profile())
    def test_long_proof_cannot_authorize_short(self):
        with self.assertRaisesRegex(ValueError,'NATIVE_CONFORMANCE_REQUIRED'):validate_profile(self.profile(),'SHORT')
    def test_profile_mismatch(self):
        for key,value in [('terminal_build',6141),('agent_build',6141),('compiler_build',6141),('server','other'),('dll',True),('shared_trading_input',True)]:
            p=self.profile();p[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):validate_profile(p)
    def test_signed_swap_mismatch(self):
        p=self.profile();p['facts']['SYMBOL_SWAP_LONG']='280.56'
        with self.assertRaises(ValueError):validate_profile(p)

if __name__=='__main__':unittest.main()
