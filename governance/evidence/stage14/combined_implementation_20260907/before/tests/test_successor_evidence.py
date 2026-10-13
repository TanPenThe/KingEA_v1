"""Non-runtime public-interface successor enforcement tests."""
import unittest
import json
import hashlib
import tempfile
import copy
from pathlib import Path
from research_pipeline.stage14 import ResearchRunCoordinator

REJECTION = 'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED'


class SuccessorEvidenceTests(unittest.TestCase):
    def rejected(self, mutate, stages=None):
        from research_pipeline.successor_evidence import PinnedControlContext
        from research_pipeline.gate1_finalization import Gate1Finalizer
        stages = stages or ['authorization','rendering','ingestion','normal_finalization','boundary_finalization']
        for stage in stages:
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as tmp:
                f = ControlFixture(Path(tmp)); mutate(f)
                context = PinnedControlContext(f.directory, f.pin)
                coordinator = ResearchRunCoordinator(control_context=context)
                spool = Path(tmp)/'spool'
                if stage == 'authorization':
                    result = coordinator.authorize(f.manifest, f.authorization)
                    self.assertFalse(result['allowed']); self.assertEqual(result['reason'], REJECTION)
                    self.assertEqual(result['stage'],stage); self.assertTrue(result['detail'])
                    self.assertNotIn('next_status',result)
                else:
                    if stage.endswith('finalization'):
                        # An untrusted persisted frame, not a call to valid ingestion.
                        spool.mkdir()
                        (spool/'untrusted.frame.json').write_bytes(canonical(dict(manifest_sha256=f.manifest['manifest_sha256'],
                            frame_id='0',payload=f.frame)))
                    before = set(spool.iterdir()) if spool.exists() else set()
                    with self.assertRaisesRegex(ValueError, REJECTION) as caught:
                        if stage == 'rendering': coordinator.render_bundle(f.manifest,f.authorization)
                        elif stage == 'ingestion': coordinator.append_frame(spool,f.manifest,dict(frame_id='0',payload=f.frame))
                        else: Gate1Finalizer(control_context=context).finalize_successor_frames(spool,f.manifest,boundary=stage=='boundary_finalization')
                    self.assertEqual(caught.exception.stage,stage)
                    self.assertTrue(caught.exception.detail)
                    self.assertEqual(set(spool.iterdir()) if spool.exists() else set(),before)

    def test_E01_declaration_and_packages_omitted_all_gates(self):
        def mutate(f): f.manifest.pop('native_cost_contract'); f.frame.pop('native_cost_packages')
        self.rejected(mutate)

    def test_E02_empty_null_wrong_type_declaration(self):
        for value in ['',None,[], '   ']:
            with self.subTest(value=value): self.rejected(lambda f:f.manifest.update(native_cost_contract=value))

    def test_E03_downgrade_unknown_wrong_policy(self):
        for key,value in [('native_cost_contract','NATIVE_COST_BOUNDARY_V1'),('package_schema','UNKNOWN'),('metadata_policy_sha256','A'*64)]:
            self.rejected(lambda f:f.manifest.update({key:value}))

    def test_E04_parent_identity(self):
        self.rejected(lambda f:f.manifest.update(candidate_id='CAND-ETH-ST-001'))

    def test_E05_parent_approval(self):
        self.rejected(lambda f:f.authorization.update(execution_receipt_sha256='1'*64))

    def test_E06_parent_evidence(self):
        self.rejected(lambda f:f.manifest.update(successor_evidence_sha256='1'*64))

    def test_E07_wrong_configuration_source_root_branch_partition(self):
        for key in ['configuration_sha256','source_sha256','root_sha256','branch','partition']:
            self.rejected(lambda f:f.manifest.update({key:'FOREIGN'}))

    def test_E08_missing_evidence_at_consumption(self):
        for key in ['native_cost_packages','stage13_close_frames','boundary_finalization_count']:
            self.rejected(lambda f:f.frame.pop(key),['ingestion','normal_finalization','boundary_finalization'])

    def test_E09_zero_boundary_does_not_waive_contract(self):
        self.rejected(lambda f:f.manifest.pop('native_cost_contract'))

    def test_E10_hidden_evaluator_close(self):
        self.rejected(lambda f:f.frame.update(stage13_close_frames=['schema=1|event_type=9|order=0|deal=0|']),
                      ['ingestion','normal_finalization','boundary_finalization'])

    def test_E11_historical_default_deny(self):
        self.rejected(lambda f:f.manifest.update(historical_scope_id='OLD',historical_schema_version=1,historical_authorization_hash='1'*64))
        from research_pipeline.gate1_finalization import Gate1Finalizer
        for call in [lambda:Gate1Finalizer().finalize(None),lambda:Gate1Finalizer().audit_batch(None,None,1),
                     lambda:Gate1Finalizer().merge_batches(None,None),
                     lambda:Gate1Finalizer().batch_status(None,None)]:
            with self.assertRaisesRegex(ValueError,REJECTION):call()

    def test_E12_change_after_authorization(self):
        def mutate(f):
            from research_pipeline.successor_evidence import PinnedControlContext
            c=ResearchRunCoordinator(control_context=PinnedControlContext(f.directory,f.pin))
            self.assertTrue(c.authorize(f.manifest,f.authorization)['allowed'])
            f.manifest['configuration_sha256']='B'*64
        self.rejected(mutate)

    def test_E13_co_tampered_expectation_declaration_and_local_seals(self):
        def mutate(f):
            spec=json.loads((f.directory/'spec.json').read_text())
            spec['binding']['source_sha256']='A'*64; f.manifest['source_sha256']='A'*64
            f.control['specification']=f.store('spec.json',spec)
            f.store('control.json',f.control)  # External pin deliberately unchanged.
            f.manifest['manifest_sha256']=hashed({k:v for k,v in f.manifest.items() if k!='manifest_sha256'})
        self.rejected(mutate)

    def test_E14_stale_wrong_execution_receipt(self):
        self.rejected(lambda f:f.authorization.update(execution_receipt_sha256='B'*64))

    def test_E15_freeze_alone(self):
        self.rejected(lambda f:(f.directory/'execution.json').unlink())

    def test_E16_unrecognized_receipt_resealed_local_control(self):
        def mutate(f):
            f.control['execution']=f.store('foreign.json',dict(owner_approved=True,kind='OWNER_SUCCESSOR_GATE1_EXECUTION'))
            f.store('control.json',f.control)
        self.rejected(mutate)

    def test_E17_payload_selected_store_or_design_as_execution(self):
        self.rejected(lambda f:f.manifest.update(trust_store='attacker'))
        def mutate(f):
            f.control['phase']='design';f.pin=f.store('control.json',f.control)['sha256']
        self.rejected(mutate)

    def test_E18_residual_semantics_not_v2(self):
        self.rejected(lambda f:f.manifest.update(evidence_semantics='PARTIAL_POSITION_LIFECYCLE'))
        self.rejected(lambda f:f.frame['evidence_binding'].update(evidence_semantics='PARTIAL_POSITION_LIFECYCLE'),
                      ['ingestion','normal_finalization','boundary_finalization'])

    def test_historical_audit_result_cannot_satisfy_successor_evidence(self):
        from research_pipeline.historical_audit import (
            HistoricalAuditScope,
            RetiredHistoricalFrameAudit,
        )
        with tempfile.TemporaryDirectory() as tmp:
            spool = Path(tmp) / 'historical'
            manifest = dict(manifest_sha256='A' * 64, expected_frame_ids=['HIST-0'])
            audit = RetiredHistoricalFrameAudit(HistoricalAuditScope(
                scope_id='RETIRED_STAGE14_FRAME_V2_TEST_FIXTURE',
                schema_version=2,
                record_identity=manifest['manifest_sha256'],
            ))
            audit.append_frame(
                spool, manifest,
                dict(frame_id='HIST-0', payload=dict(complete=1, configuration_id=0)),
            )
            result = audit.finalize_frames(spool, manifest)
            self.assertFalse(result['successor_evidence_satisfied'])
            self.assertFalse(result['gate2_prepared'])
            self.rejected(
                lambda f: f.manifest.update(
                    successor_evidence_sha256=result['evidence_sha256']
                )
            )

    def test_positive_render_ingest_and_both_finalizers(self):
        from research_pipeline.successor_evidence import PinnedControlContext
        from research_pipeline.gate1_finalization import Gate1Finalizer
        for boundary in [False,True]:
            with self.subTest(boundary=boundary),tempfile.TemporaryDirectory() as tmp:
                f=ControlFixture(Path(tmp));context=PinnedControlContext(f.directory,f.pin)
                if boundary: f.add_boundary_package()
                c=ResearchRunCoordinator(control_context=context)
                self.assertEqual(set(c.render_bundle(f.manifest,f.authorization)),{'ini','set'})
                spool=Path(tmp)/'spool'
                self.assertEqual(c.append_frame(spool,f.manifest,dict(frame_id='0',payload=f.frame))['status'],'APPENDED')
                self.assertEqual(Gate1Finalizer(control_context=context).finalize_successor_frames(spool,f.manifest,boundary=boundary)['status'],'COMPLETE')

    def test_E08_boundary_sidecar_tampered(self):
        def mutate(f):
            f.add_boundary_package()
            f.frame['native_cost_packages'][0] += 'ALTERED'
        self.rejected(mutate,['ingestion','boundary_finalization'])

    def test_E04_parent_financial_identity_inside_package(self):
        def mutate(f):
            f.add_boundary_package()
            p=json.loads(f.frame['native_cost_packages'][0].rsplit('|sha256=',1)[0])
            p['stage13_canonical']=p['stage13_canonical'].replace('CAND-ETH-ST-002','CAND-ETH-ST-001')
            raw=json.dumps(p,separators=(',',':'))
            f.frame['native_cost_packages'][0]=raw+'|sha256='+hashlib.sha256(raw.encode()).hexdigest().upper()
        self.rejected(mutate,['ingestion','boundary_finalization'])

    def test_E10_duplicate_boundary_package(self):
        def mutate(f):
            f.add_boundary_package()
            f.frame['native_cost_packages'] *= 2
            f.frame['boundary_finalization_count'] = 2
        self.rejected(mutate,['ingestion','boundary_finalization'])

    def test_E18_residual_package_fields_cannot_hide_behind_v2(self):
        def mutate(f):
            f.add_boundary_package()
            p=json.loads(f.frame['native_cost_packages'][0].rsplit('|sha256=',1)[0])
            p['residual_volume']=0.005
            raw=json.dumps(p,separators=(',',':'))
            f.frame['native_cost_packages'][0]=raw+'|sha256='+hashlib.sha256(raw.encode()).hexdigest().upper()
        self.rejected(mutate,['ingestion','boundary_finalization'])

    def test_design_validation_cannot_authorize_execution(self):
        from research_pipeline.successor_evidence import PinnedControlContext,validate
        with tempfile.TemporaryDirectory() as tmp:
            f=ControlFixture(Path(tmp));f.control['phase']='design'
            f.control.pop('execution');f.control.pop('freeze');f.pin=f.store('control.json',f.control)['sha256']
            context=PinnedControlContext(f.directory,f.pin)
            self.assertEqual(validate(context,f.manifest,'design',design_only=True)['binding'],f.binding)
            self.assertFalse(ResearchRunCoordinator(control_context=context).authorize(f.manifest,f.authorization)['allowed'])

    def test_E12_rendered_bundle_tampering_and_E08_missing_frame(self):
        from research_pipeline.successor_evidence import PinnedControlContext
        with tempfile.TemporaryDirectory() as tmp:
            f=ControlFixture(Path(tmp));c=ResearchRunCoordinator(control_context=PinnedControlContext(f.directory,f.pin))
            bundle=c.render_bundle(f.manifest,f.authorization);bundle['set']+='TAMPERED'
            with self.assertRaisesRegex(ValueError,REJECTION) as e:c.verify_bundle(f.manifest,f.authorization,bundle)
            self.assertEqual(e.exception.stage,'rendering')
            for stage in ['normal_finalization','boundary_finalization']:
                with self.assertRaisesRegex(ValueError,REJECTION) as e:c.finalize_frames(Path(tmp)/'missing',f.manifest,finalization_stage=stage)
                self.assertEqual(e.exception.stage,stage)
    def test_E01_omission_rejects_before_ingestion_write(self):
        from research_pipeline.successor_evidence import PinnedControlContext
        with tempfile.TemporaryDirectory() as tmp:
            f = ControlFixture(Path(tmp))
            coordinator = ResearchRunCoordinator(control_context=PinnedControlContext(f.directory, f.pin))
            del f.manifest['native_cost_contract']
            spool = Path(tmp)/'spool'
            with self.assertRaisesRegex(ValueError, REJECTION):
                coordinator.append_frame(spool, f.manifest, dict(frame_id='0',payload=dict(complete=1)))
            self.assertFalse(spool.exists())
    def test_independently_pinned_authorization_positive_control(self):
        from research_pipeline.successor_evidence import PinnedControlContext
        with tempfile.TemporaryDirectory() as tmp:
            f = ControlFixture(Path(tmp))
            coordinator = ResearchRunCoordinator(control_context=PinnedControlContext(f.directory, f.pin))
            self.assertTrue(coordinator.authorize(f.manifest, f.authorization)['allowed'])
    def test_missing_independent_context_denies_authorization(self):
        result = ResearchRunCoordinator().authorize({}, {'owner_approved': True})
        self.assertFalse(result['allowed'])
        self.assertEqual(result['reason'], REJECTION)
        self.assertEqual(result['stage'], 'authorization')


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def hashed(value):
    return hashlib.sha256(canonical(value)).hexdigest().upper()


class ControlFixture:
    """Independent control-plane fixture, never a production approval/root."""
    def __init__(self, directory):
        self.directory = directory
        self.binding = dict(candidate_id='CAND-ETH-ST-002', configuration_sha256='C'*64,
            source_sha256='D'*64, successor_evidence_sha256='E'*64,
            native_cost_contract='NATIVE_COST_BOUNDARY_V2', package_schema='NATIVE_COST_BOUNDARY_PACKAGE_V2',
            evidence_semantics='WHOLE_POSITION_V2', filling='ORDER_FILLING_FOK',
            metadata_policy_sha256='CDFE801225C54C622A566CB125FE37B0759A3E47320D988571B796629CF984D9',
            boundary_policy_sha256='909C23E3B14BB64A62BC371890B2FFFB1964D24FC24879971DB614FB078E92C6')
        spec = dict(kind='REVIEWED_SUCCESSOR_SPECIFICATION', binding=self.binding)
        spec_ref = self.store('spec.json', spec)
        review_ref = self.store('review.json', dict(kind='INDEPENDENT_SPECIFICATION_REVIEW', accepted=True, specification_sha256=spec_ref['sha256']))
        freeze_ref = self.store('freeze.json', dict(kind='OWNER_SUCCESSOR_FREEZE', owner_approved=True,
            candidate_id=self.binding['candidate_id'], specification_sha256=spec_ref['sha256']))
        self.manifest = dict(self.binding, gate='GATE1', root_sha256='F'*64,
            branch='RECORDED', partition='FINAL_SELECTION', configuration_start=0, configuration_end=0,
            expected_frame_ids=['0'], scenario='BASELINE_20MS', purpose='RESEARCH', expected_symbol='ETHUSD.s',
            execution_adapter='NATIVE', execution_mode=20, seed=0,
            from_date='2022.04.02', evaluation_start='2022-07-01T00:00:00',
            evaluation_end_exclusive='2024-01-01T00:00:00', to_date_inclusive='2023.12.31',
            artifact_hashes=dict(calendar='A'*64,cost='A'*64,research_specification='A'*64),
            operational_facts=dict(calendar_intervals_file='fixture.csv',calendar_file_sha256='A'*64,
                commission_per_lot_round_turn=0,swap_per_lot_stress=0,weekend_risk_multiplier=.5,
                maintenance_entry_block_minutes=30,maintenance_force_flat_minutes=5,maintenance_clean_minutes=15))
        self.manifest['manifest_sha256'] = hashed(self.manifest)
        execution_ref = self.store('execution.json', dict(kind='OWNER_SUCCESSOR_GATE1_EXECUTION', owner_approved=True,
            candidate_id=self.binding['candidate_id'], specification_sha256=spec_ref['sha256'],
            freeze_receipt_sha256=freeze_ref['sha256'], gate='GATE1',root_sha256='F'*64,
            child_sha256=self.manifest['manifest_sha256']))
        self.control = dict(kind='INDEPENDENT_SUCCESSOR_CONTROL', phase='execution', active=True,
            specification=spec_ref, review=review_ref, freeze=freeze_ref, execution=execution_ref)
        self.pin = self.store('control.json', self.control)['sha256']
        self.authorization = dict(owner_approved=True,gate='GATE1',root_sha256='F'*64,
            child_sha256=self.manifest['manifest_sha256'],freeze_receipt_sha256=freeze_ref['sha256'],
            execution_receipt_sha256=execution_ref['sha256'])
        self.frame = dict(complete=1,configuration_id=0,evidence_binding=copy.deepcopy(self.binding),
            authorization_binding=self.authorization,native_cost_packages=[],boundary_finalization_count=0,stage13_close_frames=[])

    def store(self, name, value):
        (self.directory/name).write_bytes(canonical(value))
        return dict(path=name,sha256=hashed(value))

    def add_boundary_package(self):
        # Rebind a retained non-Candidate format fixture entirely in memory.
        # This is synthetic test evidence, not successor execution evidence.
        from research_pipeline.native_cost_archive import digest,COST
        root=Path(__file__).resolve().parents[1]
        source=root/'governance/evidence/stage14/fok_infrastructure_20260905/NC-FOK-09-FINAL/runtime/harness/native-cost-package.evidence'
        p=json.loads(source.read_text().rsplit('|sha256=',1)[0])
        old_binding=p['records'][1].split('|')[2]
        bodies=[r.split('|',1)[1].rsplit('|',1)[0] for r in p['records']]
        b=bodies[0].split('|');b[1]=self.manifest['manifest_sha256'];b[3]='RECORDED';b[4]='FINAL_SELECTION'
        bodies[0]='|'.join(b);new_binding=digest('|'.join(b[1:]))
        previous=digest(COST+'|'+new_binding);records=[]
        for body in bodies:
            body=body.replace(old_binding,new_binding);current=digest(previous+'|'+body)
            records.append(previous+'|'+body+'|'+current);previous=current
        c=p['stage13_canonical'].split('|');old_root=digest(p['stage13_canonical'])
        c[7]=self.binding['candidate_id'];c[8]=self.binding['configuration_sha256']
        p['stage13_canonical']='|'.join(c);new_root=digest(p['stage13_canonical'])
        p['stage13_frame']=p['stage13_frame'].replace(old_root,new_root)
        side=p['sidecar'].rsplit('|sha256=',1)[0].replace(old_binding,new_binding).replace(old_root,new_root)
        old_cost_root=p['records'][-1].rsplit('|',1)[1]
        side=side.replace(old_cost_root,previous);p['sidecar']=side+'|sha256='+digest(side)
        p.update(records=records,run=self.manifest['manifest_sha256'],branch='RECORDED',partition='FINAL_SELECTION')
        raw=json.dumps(p,separators=(',',':'))
        self.frame.update(native_cost_packages=[raw+'|sha256='+digest(raw)],boundary_finalization_count=1,
                          stage13_close_frames=[p['stage13_frame']])


if __name__ == '__main__':
    unittest.main()
