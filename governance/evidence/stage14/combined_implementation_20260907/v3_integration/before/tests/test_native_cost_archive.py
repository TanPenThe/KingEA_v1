import unittest
import json
import hashlib
import tempfile
import shutil
from pathlib import Path
from research_pipeline.native_cost_archive import NativeCostArchiveConsumer

ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'governance/evidence/stage14/fok_infrastructure_20260905/NC-FOK-09-FINAL'

class NativeCostArchiveTests(unittest.TestCase):
    def payload(self):
        return json.loads((PROOF/'runtime/harness/native-cost-package.evidence').read_text().rsplit('|sha256=',1)[0])

    def encode(self,p):
        raw=json.dumps(p,separators=(',',':'))
        return raw+'|sha256='+hashlib.sha256(raw.encode()).hexdigest().upper()

    def scope(self):
        return dict(run='NC-FOK-09-FINAL',configuration=0,branch='NON_CANDIDATE',partition='CONFORMANCE_2023')

    def test_actual_production_package_binds_cost_snapshot_and_stage13(self):
        raw=(PROOF/'runtime/harness/native-cost-package.evidence').read_bytes()
        scope=self.scope()
        result=NativeCostArchiveConsumer.validate_package(raw,scope)
        self.assertEqual(result['boundary_finalization_count'],1)
        self.assertEqual(result['candidate_exit_count_delta'],0)

    def test_missing_altered_sidecar_and_wrong_roots_fail_closed(self):
        original=self.payload()
        for field in ('sidecar','records','stage13_canonical','stage13_frame'):
            for action in ('missing','altered'):
                with self.subTest(field=field,action=action):
                    p=dict(original)
                    if action=='missing': p.pop(field)
                    elif field=='records': p[field]=p[field][1:]
                    else: p[field]=p[field]+'ALTERED'
                    with self.assertRaises((ValueError,KeyError)):
                        NativeCostArchiveConsumer.validate_package(self.encode(p),self.scope())

    def test_wrong_scope_and_boundary_duplicate_or_missing_rejected(self):
        p=self.payload(); raw=self.encode(p); frame=p['stage13_frame']; scope=self.scope()
        for key in scope:
            wrong=dict(scope); wrong[key]=99 if key=='configuration' else 'FOREIGN'
            with self.assertRaises(ValueError): NativeCostArchiveConsumer.validate_package(raw,wrong)
        for packages,count,frames in (([],1,[frame]),([raw,raw],2,[frame]),([raw],1,[]),
                                      ([raw],0,[frame]),([],0,[frame])):
            with self.subTest(count=count,packages=len(packages)),self.assertRaises(ValueError):
                NativeCostArchiveConsumer.validate_packages(packages,scope,boundary_count=count,close_frames=frames)

    def test_zero_or_broken_funnel_quarantines_without_selection(self):
        valid=dict(entries=1,trade_groups=1,intents=1,safety_evaluations=1,approved=1,
                   route_attempts=1,fills=1,accounting_submissions=1)
        self.assertEqual(NativeCostArchiveConsumer.selection_guard(valid),'PASS')
        for key in ('entries','trade_groups','safety_evaluations','route_attempts','accounting_submissions'):
            f=dict(valid); f[key]=0
            self.assertEqual(NativeCostArchiveConsumer.selection_guard(f),'QUARANTINE_BEFORE_SELECTION')

    def test_production_coordinator_consumes_same_package_before_finalizing(self):
        from research_pipeline.stage14 import Stage14Error
        from research_pipeline.historical_audit import (
            HistoricalAuditScope,
            RetiredHistoricalFrameAudit,
        )
        p=self.payload(); raw=self.encode(p)
        manifest=dict(manifest_sha256=p['run'],branch=p['branch'],partition=p['partition'],
                      native_cost_contract='NATIVE_COST_BOUNDARY_V2',expected_frame_ids=['NON_CANDIDATE-0'])
        frame=dict(complete=1,configuration_id=0,native_cost_packages=[raw],
                   boundary_finalization_count=1,stage13_close_frames=[p['stage13_frame']])
        for corrupted in (False,True):
            with self.subTest(corrupted=corrupted),tempfile.TemporaryDirectory() as tmp:
                payload=dict(frame)
                if corrupted: payload['native_cost_packages']=[]
                coordinator=RetiredHistoricalFrameAudit(HistoricalAuditScope(
                    scope_id='RETIRED_NATIVE_COST_FRAME_V2', schema_version=2,
                    record_identity=manifest['manifest_sha256']))
                path=Path(tmp)
                coordinator.append_frame(path,manifest,dict(frame_id='NON_CANDIDATE-0',payload=payload))
                if corrupted:
                    with self.assertRaises(Stage14Error): coordinator.finalize_frames(path,manifest)
                    self.assertFalse((path/'HISTORICAL_AUDIT_RESULT.json').exists())
                else:
                    result=coordinator.finalize_frames(path,manifest)
                    self.assertEqual(result['status'],'RETIRED_HISTORICAL_AUDIT_PASS')
                    self.assertFalse(result['successor_evidence_satisfied'])

    def test_sealed_only_roundtrip_and_tamper_rejection(self):
        from research_pipeline.fok_verification import verify_directory
        with tempfile.TemporaryDirectory() as tmp:
            copied=Path(tmp)/'sealed'; shutil.copytree(PROOF,copied)
            self.assertTrue(verify_directory(copied)['sealed_only'])
            target=copied/'runtime/harness/native-cost-package.evidence'
            target.write_bytes(target.read_bytes()+b'bad')
            with self.assertRaises(ValueError): verify_directory(copied)

    def test_resealed_wrong_event_sequence_hash_and_cost_root_rejected(self):
        for field in ('cost_root','stage13_root','sequence'):
            p=self.payload(); side,ignored=p['sidecar'].rsplit('|sha256=',1)
            parts=side.split('|')
            for i,x in enumerate(parts):
                if x.startswith(field+'='): parts[i]=field+'='+('99' if field=='sequence' else 'F'*64)
            side='|'.join(parts); p['sidecar']=side+'|sha256='+hashlib.sha256(side.encode()).hexdigest().upper()
            with self.subTest(field=field),self.assertRaises(ValueError):
                NativeCostArchiveConsumer.validate_package(self.encode(p),self.scope())

    def test_sealed_v2_requires_both_callback_proof_pairs(self):
        from research_pipeline.fok_verification import verify_files
        files={p.relative_to(PROOF).as_posix():p.read_bytes() for p in PROOF.rglob('*') if p.is_file()}
        self.assertEqual(verify_files(files)['synthetic_callback_pairs_verified'],2)
        for index in range(2):
            altered=dict(files)
            name=f'runtime/harness/synthetic-callback-package-{index}.evidence'
            altered.pop(name)
            inventory=json.loads(altered['SEALED_INVENTORY.json'])
            inventory['files']=[a for a in inventory['files'] if a['path'].replace('\\','/')!=name]
            altered['SEALED_INVENTORY.json']=json.dumps(inventory).encode()
            with self.subTest(index=index),self.assertRaises((ValueError,KeyError)):
                verify_files(altered)

    def test_missing_or_ambiguous_housekeeping_is_not_silently_accepted(self):
        p=self.payload(); p.pop('housekeeping_evidence')
        with self.assertRaises(KeyError): NativeCostArchiveConsumer.validate_package(self.encode(p),self.scope())
        p=self.payload(); p['housekeeping_evidence']=[dict(classification='AMBIGUOUS_OUT')]
        with self.assertRaises((ValueError,KeyError)):
            NativeCostArchiveConsumer.validate_package(self.encode(p),self.scope())

if __name__=='__main__': unittest.main()
