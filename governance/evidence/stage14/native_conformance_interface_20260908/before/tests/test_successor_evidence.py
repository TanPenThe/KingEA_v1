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
        for key,value in [('native_cost_contract','NATIVE_COST_BOUNDARY_V1'),('package_schema','UNKNOWN'),('decision_a_sha256','A'*64)]:
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
                f=ControlFixture(Path(tmp))
                if boundary: f.add_boundary_package()
                context=PinnedControlContext(f.directory,f.pin)
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
            from research_pipeline.decision_a_evidence import decode_archive, encode_archive
            files=decode_archive(f.frame['native_cost_packages'][0])
            files['sidecar.evidence']=files['sidecar.evidence'].replace(b'CAND-ETH-ST-002',b'CAND-ETH-ST-001')
            f.frame['native_cost_packages'][0]=encode_archive(files)
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
            from research_pipeline.decision_a_evidence import decode_archive, encode_archive
            files=decode_archive(f.frame['native_cost_packages'][0])
            files['sidecar.evidence']=files['sidecar.evidence'].replace(b'NATIVE_GROUP_LIFECYCLE_PACKAGE_V3',b'NATIVE_COST_BOUNDARY_PACKAGE_V2')
            f.frame['native_cost_packages'][0]=encode_archive(files)
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
        from v3_fixture import profile, CONFIG, SOURCE
        from research_pipeline.decision_a_evidence import (digest, CONTRACT, PACKAGE, SEMANTICS, ADOPTION,
            INVENTORY_PROTOCOL, INVENTORY_ADOPTION, DECISION_A_ADOPTION, DECISION_S_ADOPTION, SWAP_TRANSITION_RULE, SWAP_TRANSITION_ADOPTION)
        self.profile = profile()
        profile_ref = self.store('profile.json', self.profile)
        self.binding = dict(candidate_id='CAND-ETH-ST-002', configuration_sha256=digest(CONFIG),
            source_sha256=digest(SOURCE), successor_evidence_sha256='E'*64,
            native_cost_contract=CONTRACT, package_schema=PACKAGE, evidence_semantics=SEMANTICS, filling='ORDER_FILLING_FOK',
            inventory_protocol=INVENTORY_PROTOCOL, inventory_protocol_sha256=INVENTORY_ADOPTION,
            swap_transition_rule=SWAP_TRANSITION_RULE, swap_transition_rule_sha256=SWAP_TRANSITION_ADOPTION,
            combined_specification_sha256=ADOPTION, decision_a_sha256=DECISION_A_ADOPTION,
            decision_s_sha256=DECISION_S_ADOPTION, tester_profile_sha256=profile_ref['sha256'])
        spec = dict(kind='REVIEWED_SUCCESSOR_SPECIFICATION', binding=self.binding, tester_profile=profile_ref)
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
        calendar_bytes = b'type,start_msc,end_msc,identity\nNEWS,100,200,synthetic\n'
        self.manifest['operational_facts']['calendar_file_sha256'] = hashlib.sha256(calendar_bytes).hexdigest().upper()
        self.manifest['manifest_sha256'] = hashed(self.manifest)
        execution_ref = self.store('execution.json', dict(kind='OWNER_SUCCESSOR_GATE1_EXECUTION', owner_approved=True,
            candidate_id=self.binding['candidate_id'], specification_sha256=spec_ref['sha256'],
            freeze_receipt_sha256=freeze_ref['sha256'], gate='GATE1',root_sha256='F'*64,
            child_sha256=self.manifest['manifest_sha256']))
        self.control = dict(kind='INDEPENDENT_SUCCESSOR_CONTROL', phase='execution', active=True,
            specification=spec_ref, review=review_ref, freeze=freeze_ref, execution=execution_ref)
        local = self.directory / 'agent' / 'MQL5' / 'Files' / 'KingEA' / 'runs' / self.manifest['manifest_sha256']
        local.mkdir(parents=True)
        manifest_bytes = canonical(self.manifest)
        (local/'manifest.json').write_bytes(manifest_bytes)
        (local/'fixture.csv').write_bytes(calendar_bytes)
        self.control['render_inputs'] = dict(storage_scope='AGENT_LOCAL_RUN_SCOPED',
            agent_files_root=str((self.directory/'agent'/'MQL5'/'Files').resolve()),
            child_sha256=self.manifest['manifest_sha256'],
            manifest=dict(path='manifest.json',sha256=hashlib.sha256(manifest_bytes).hexdigest().upper()),
            calendar=dict(path='fixture.csv',sha256=hashlib.sha256(calendar_bytes).hexdigest().upper()))
        self.control['completed_archives'] = {self.manifest['manifest_sha256']+':0':[]}
        completion=dict(kind='NATIVE_V3_COMPLETION',run_id=self.manifest['manifest_sha256'],configuration_id=0,profile_hash=self.binding['tester_profile_sha256'],group_count=0,boundary_count=0,research_invalid=False,containment_attempted=False,unsupported_financial_events=[],complete=1)
        self.control['native_completions']={self.manifest['manifest_sha256']+':0':self.store('native-completion.json',completion)}
        self.pin = self.store('control.json', self.control)['sha256']
        self.authorization = dict(owner_approved=True,gate='GATE1',root_sha256='F'*64,
            child_sha256=self.manifest['manifest_sha256'],freeze_receipt_sha256=freeze_ref['sha256'],
            execution_receipt_sha256=execution_ref['sha256'])
        self.frame = dict(unsupported_native_financial_events=[],complete=1,configuration_id=0,evidence_binding=copy.deepcopy(self.binding),
            authorization_binding=self.authorization,native_cost_packages=[],boundary_finalization_count=0,stage13_close_frames=[])

    def store(self, name, value):
        (self.directory/name).write_bytes(canonical(value))
        return dict(path=name,sha256=hashed(value))

    def add_boundary_package(self):
        from v3_fixture import package
        from research_pipeline.decision_a_evidence import encode_archive, read_package
        files, seal, _, _ = package(self, boundary=True)
        reference = self.store('archive-seal.json', seal)
        self.control['completed_archives'][self.manifest['manifest_sha256']+':0']=[reference]
        self.pin=self.store('control.json',self.control)['sha256']
        sidecar=read_package(files['sidecar.evidence'])
        from research_pipeline.decision_a_evidence import verify_archive
        _, verified=verify_archive(files,seal,{})
        self.frame.update(native_cost_packages=[encode_archive(files)],boundary_finalization_count=1,
            stage13_close_frames=[verified.resolve(sidecar['terminal']['stage13_root'],'STAGE13_EVENT').decode()])


if __name__ == '__main__':
    unittest.main()
