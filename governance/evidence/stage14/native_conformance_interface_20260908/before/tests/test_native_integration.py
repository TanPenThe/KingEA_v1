"""Production capture/assembly/control APIs; all observations are synthetic."""
import copy
import tempfile
import unittest
from pathlib import Path
from test_successor_evidence import ControlFixture
from v3_fixture import package
from research_pipeline.decision_a_evidence import *
from research_pipeline.successor_evidence import PinnedControlContext,SuccessorEvidenceError


class NativeIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.f=ControlFixture(Path(self.tmp.name))
        self.files,self.seal,self.binding,self.profile=package(self.f,False,True,True)
        self.raw=(self.f.directory/'native-capture.json').read_bytes()
        self.capture=parse_json(self.raw)
        inventory=parse_json(self.files['references.json'])
        self.authorities={e['role']:self.files[e['path']] for e in inventory['entries']}

    def build(self):
        raw=json_bytes(self.capture)
        return assemble_native_archive(raw,self.binding,self.profile,self.authorities,
            expected_capture_hash=digest(raw),expected_configuration=0)

    def rejects(self,mutate,reason=None):
        mutate(self.capture)
        before={p:p.read_bytes() for p in self.f.directory.rglob('*') if p.is_file()}
        with self.assertRaises(ValueError) as caught:self.build()
        if reason:self.assertIn(reason,str(caught.exception))
        self.assertEqual(before,{p:p.read_bytes() for p in self.f.directory.rglob('*') if p.is_file()})

    def deal(self,index=0):return [r for r in self.capture['records'] if r['role']=='DEAL_ADD'][index]
    def set_deal(self,index,field,value):
        row=self.deal(index);parts=row['payload'].split('|');parts[field]=str(value);row['payload']='|'.join(parts)

    def test_native_capture_reproduces_archive_exactly(self):self.assertEqual(self.build(),self.files)

    def test_independent_control_build_and_frame_preparation(self):
        f=self.f;key=f.manifest['manifest_sha256']+':0'
        f.control['completed_archives'][key]=[f.store('final-seal.json',self.seal)]
        f.pin=f.store('control.json',f.control)['sha256'];context=PinnedControlContext(f.directory,f.pin)
        before={p:p.read_bytes() for p in f.directory.rglob('*') if p.is_file()}
        self.assertEqual(context.build_native_archive(f.manifest,0,self.binding['group_id']),self.files)
        frame=context.prepare_result_frame(f.manifest,0)
        self.assertEqual(frame['configuration_id'],0)
        self.assertEqual(before,{p:p.read_bytes() for p in f.directory.rglob('*') if p.is_file()})
        self.assertNotIn('running_eligible',frame);self.assertNotIn('gate2_prepared',frame)

    def test_capture_mutation_cannot_choose_new_independent_pin(self):
        with self.assertRaisesRegex(ValueError,'PIN_MISMATCH'):
            assemble_native_archive(self.raw+b' ',self.binding,self.profile,self.authorities,expected_capture_hash=digest(self.raw),expected_configuration=0)

    def test_duplicate_callback_is_idempotent(self):
        records=self.capture['records'];i=records.index(self.deal())
        records.insert(i+1,copy.deepcopy(records[i]))
        # Capture sequence changes are retained; group economics and cardinality do not.
        out=self.build();s=read_package(out['sidecar.evidence'])
        self.assertEqual(len(s['exit_portions']),2)
        self.assertEqual(s['terminal']['aggregate_swap'],'-4')

    def test_conflicting_duplicate_rejects(self):
        row=copy.deepcopy(self.deal());self.capture['records'].append(row)
        parts=row['payload'].split('|');parts[11]='900';row['payload']='|'.join(parts)
        self.rejects(lambda c:None,'CONFLICTING_DUPLICATE_DEAL')

    def test_missing_callback_not_no_fill(self):
        self.rejects(lambda c:c['records'].remove(self.deal(1)))

    def test_missing_order_terminality_rejects(self):
        self.rejects(lambda c:c.update(records=[r for r in c['records'] if r['role']!='ORDER_TERMINAL_OBSERVATION']),'TERMINALITY')

    def test_wrong_configuration_rejects(self):
        row=self.capture['records'][0];body=parse_json(row['payload'].encode());body['configuration_id']=1;row['payload']=json_bytes(body).decode()
        self.rejects(lambda c:None,'CONFIGURATION')

    def test_partial_execution_rejects(self):
        self.set_deal(1,9,'.5');self.rejects(lambda c:None,'TERMINALITY')

    def test_multideal_full_volume_rejects(self):
        original=copy.deepcopy(self.deal(1));self.set_deal(1,9,'.5')
        parts=original['payload'].split('|');parts[0]='900';parts[9]='.5';original['payload']='|'.join(parts)
        self.capture['records'].append(original);self.rejects(lambda c:None,'CARDINALITY')

    def test_each_failed_deal_scalar_read_rejects(self):
        initial=copy.deepcopy(self.capture)
        for bit in range(16):
            with self.subTest(bit=bit):
                self.capture=copy.deepcopy(initial);self.set_deal(1,16,65535^(1<<bit));self.rejects(lambda c:None,'READ_FAILED')

    def test_foreign_position_rejects(self):
        self.set_deal(1,2,999);self.rejects(lambda c:None,'POSITION')

    def test_manual_desktop_mobile_web_not_selectable(self):
        initial=copy.deepcopy(self.capture)
        for reason in (0,1,2):
            with self.subTest(reason=reason):
                self.capture=copy.deepcopy(initial);self.set_deal(2,6,reason)
                self.rejects(lambda c:None,'ORIGIN')

    def test_external_cash_isolation(self):
        row=dict(role='EXTERNAL_CASH_EVIDENCE',payload='999|0|0|1500|0|2|0|0||0|0|5000|0|0|0|0|65535|false')
        self.capture['records'].append(row);out=self.build()
        self.assertEqual(read_package(out['sidecar.evidence'])['terminal'],read_package(self.files['sidecar.evidence'])['terminal'])

    def test_trading_fact_cannot_be_relabelled_external_cash(self):
        self.capture['records'].append(dict(role='EXTERNAL_CASH_EVIDENCE',payload=self.deal(1)['payload']))
        self.rejects(lambda c:None,'EXTERNAL_CASH_CLASSIFICATION')

    def test_unsupported_financial_event_rejects(self):
        self.rejects(lambda c:c['records'].append(dict(role='INVALID_NATIVE_FINANCIAL_EVENT',payload='CORRECTION')))

    def test_containment_capture_is_never_packaged(self):
        self.rejects(lambda c:c['records'].append(dict(role='INVALID_RUN_CONTAINMENT_EVIDENCE',payload='actual audit truth')))

    def test_prepared_without_committed_is_not_a_financial_receipt(self):
        self.rejects(lambda c:c.update(records=[r for r in c['records'] if r['role']!='STAGE13_COMMITTED']),'CARDINALITY')

    def test_second_financial_projection_rejects(self):
        row=next(r for r in self.capture['records'] if r['role']=='STAGE13_COMMITTED')
        self.rejects(lambda c:c['records'].append(copy.deepcopy(row)),'CARDINALITY')

    def test_failed_position_snapshot_read_rejects(self):
        row=next(r for r in self.capture['records'] if r['role']=='BEFORE_REQUEST');body=parse_json(row['payload'].encode());body['valid']=False;row['payload']=json_bytes(body).decode()
        self.rejects(lambda c:None,'POSITION_READ_FAILED')

    def test_altered_independent_artifact_rejects(self):
        self.authorities['EXECUTABLE']+=b'changed';self.rejects(lambda c:None,'AUTHORITY_ARTIFACT_MISMATCH')

    def make_passive_stop(self):
        self.set_deal(2,6,4)
        order=int(self.deal(2)['payload'].split('|')[1])
        rows=self.capture['records']
        rows[:]=[r for r in rows if not (r['role']=='REQUEST_RESULT' and parse_json(r['payload'].encode())['order']==order)]
        rows.append(dict(role='STATIC_PROTECTIVE_STOP_INTENT',payload='{}'))

    def test_authenticated_passive_stop_and_gap(self):
        self.make_passive_stop()
        self.set_deal(2,10,'89')
        out=self.build();s=read_package(out['sidecar.evidence'])
        self.assertEqual(s['exit_portions'][-1]['reason'],'DEAL_REASON_SL')
        self.assertEqual(s['exit_portions'][-1]['exit_sl'],'90')

    def test_stop_cause_without_strategy_intent_rejects(self):
        self.make_passive_stop()
        self.rejects(lambda c:c.update(records=[r for r in c['records'] if r['role']!='STATIC_PROTECTIVE_STOP_INTENT']))

    def test_stop_exit_state_mismatch_rejects(self):
        self.make_passive_stop();self.set_deal(2,15,'91');self.rejects(lambda c:None)

    def test_observed_stop_mutation_cannot_be_cleared_by_final_equality(self):
        self.make_passive_stop()
        self.rejects(lambda c:c['records'].append(dict(role='INVALID_STOP_MUTATION',payload='S0->B->S0')))

    def test_independent_completion_required_and_valid(self):
        f=self.f;key=f.manifest['manifest_sha256']+':0'
        f.control['completed_archives'][key]=[f.store('final-seal.json',self.seal)]
        original=copy.deepcopy(f.control['native_completions'])
        for mutation in ('missing','count','invalid','profile'):
            with self.subTest(mutation=mutation):
                f.control['native_completions']=copy.deepcopy(original)
                if mutation=='missing':f.control['native_completions']={}
                else:
                    ref=f.control['native_completions'][key]
                    body=parse_json((f.directory/ref['path']).read_bytes())
                    if mutation=='count':body['group_count']=99
                    elif mutation=='invalid':body['research_invalid']=True
                    else:body['profile_hash']='0'*64
                    f.control['native_completions'][key]=f.store('bad-completion.json',body)
                f.pin=f.store('control.json',f.control)['sha256']
                before={p:p.read_bytes() for p in f.directory.rglob('*') if p.is_file()}
                with self.assertRaises(SuccessorEvidenceError) as caught:
                    PinnedControlContext(f.directory,f.pin).prepare_result_frame(f.manifest,0)
                self.assertEqual(str(caught.exception),'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED')
                self.assertEqual(before,{p:p.read_bytes() for p in f.directory.rglob('*') if p.is_file()})

    def test_unsupported_entry_and_exit_scalars(self):
        initial=copy.deepcopy(self.capture)
        for index,field,value in ((0,11,'1'),(0,14,'1'),(1,4,2),(1,5,0),(1,7,999),(1,8,'FOREIGN'),(1,6,5),(1,6,6),(1,6,7),(1,11,'NaN'),(1,12,'Infinity')):
            with self.subTest(index=index,field=field,value=value):
                self.capture=copy.deepcopy(initial);self.set_deal(index,field,value);self.rejects(lambda c:None)

    def test_entry_and_residual_state_binding(self):
        initial=copy.deepcopy(self.capture)
        for index,key,value in ((0,'sl','91'),(0,'basis','99'),(0,'position_id',999),(1,'sl','91'),(1,'basis','99'),(1,'volume','.5'),(1,'position_ticket',999)):
            with self.subTest(index=index,key=key):
                self.capture=copy.deepcopy(initial)
                row=[r for r in self.capture['records'] if r['role']=='RECONCILED_POSITION'][index]
                body=parse_json(row['payload'].encode());body[key]=value;row['payload']=json_bytes(body).decode()
                self.rejects(lambda c:None)


if __name__=='__main__':unittest.main()

