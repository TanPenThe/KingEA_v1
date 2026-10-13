"""V3 production-consumer tests with synthetic independently pinned controls."""
import copy,json,tempfile,unittest
from pathlib import Path
from test_successor_evidence import ControlFixture
from v3_fixture import package
from research_pipeline.decision_a_evidence import *
from research_pipeline.successor_evidence import PinnedControlContext,SuccessorEvidenceError
from research_pipeline.stage14 import ResearchRunCoordinator
from research_pipeline.gate1_finalization import Gate1Finalizer

class V3ArchiveTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
  self.f=ControlFixture(Path(self.temp.name));self.files,self.seal,self.binding,self.profile=package(self.f,True,True,True)
 def sidecar(self):return read_package(self.files['sidecar.evidence'])
 def reseal(self,s=None,r=None):
  if r is not None:self.files['references.json']=json_bytes(r)
  if s is None:s=self.sidecar()
  s['integrity']['archive_inventory_hash']=digest(self.files['references.json'])
  raw=json_bytes(s);self.files['sidecar.evidence']=raw+b'|sha256='+digest(raw).encode()
  r=parse_json(self.files['references.json'])
  entries=copy.deepcopy(r['entries'])
  for path,role in [('references.json','REFERENCE_INVENTORY'),('sidecar.evidence','V3_SIDECAR')]:
   entries.append(inventory_entry(path,role,self.files[path],self.seal['binding']))
  self.files['archive.json']=json_bytes(dict(kind='FINAL_ARCHIVE_INVENTORY_V1',binding=self.seal['binding'],entries=entries))
  self.seal['archive_sha256']=digest(self.files['archive.json'])
 def install(self):
  f=self.f;seal_ref=f.store('v3-final-seal.json',self.seal)
  f.control['completed_archives'][f.manifest['manifest_sha256']+':0']=[seal_ref]
  f.pin=f.store('control.json',f.control)['sha256']
  # The known original canonical frame is fixture data; negative checks happen before writes.
  canonical_frame=next(data.decode() for path,data in self.files.items() if path.startswith('support/stage13_event.'))
  f.frame.update(native_cost_packages=[encode_archive(self.files)],boundary_finalization_count=1,stage13_close_frames=[canonical_frame])
  return ResearchRunCoordinator(control_context=PinnedControlContext(f.directory,f.pin))
 def reject(self,reason=None):
  c=self.install();spool=self.f.directory/'rejected-spool';before=set(self.f.directory.rglob('*'));manifest=copy.deepcopy(self.f.manifest);auth=copy.deepcopy(self.f.authorization)
  with self.assertRaises(SuccessorEvidenceError) as caught:c.append_frame(spool,self.f.manifest,dict(frame_id='0',payload=self.f.frame))
  self.assertEqual(str(caught.exception),'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED');self.assertEqual(caught.exception.stage,'ingestion')
  if reason:self.assertIn(reason,caught.exception.detail)
  self.assertEqual(before,set(self.f.directory.rglob('*')));self.assertFalse(spool.exists())
  self.assertEqual(self.f.manifest,manifest);self.assertEqual(self.f.authorization,auth)
  for name in ('FINALIZED.json','GATE2_READY.json','RUNNING.json','VALID_V3.json'):
   self.assertFalse(any(p.name==name for p in self.f.directory.rglob('*')))
 def test_full_and_reduced_normal_and_boundary_positive(self):
  for boundary in (False,True):
   for reduction in (False,True):
    with self.subTest(boundary=boundary,reduction=reduction),tempfile.TemporaryDirectory() as tmp:
     f=ControlFixture(Path(tmp));files,seal,b,profile=package(f,boundary,reduction,True,not boundary)
     s,refs=verify_archive(files,seal,b);validate_package(files['sidecar.evidence'],b,profile,refs)
     ref=f.store('seal.json',seal);f.control['completed_archives'][f.manifest['manifest_sha256']+':0']=[ref];f.pin=f.store('control.json',f.control)['sha256']
     f.frame.update(native_cost_packages=[encode_archive(files)],boundary_finalization_count=int(boundary),stage13_close_frames=[refs.resolve(s['terminal']['stage13_root'],'STAGE13_EVENT').decode()])
     context=PinnedControlContext(f.directory,f.pin);c=ResearchRunCoordinator(control_context=context);spool=Path(tmp)/'spool'
     c.append_frame(spool,f.manifest,dict(frame_id='0',payload=f.frame))
     result=Gate1Finalizer(control_context=context).finalize_successor_frames(spool,f.manifest,boundary=boundary)
     self.assertEqual(result['status'],'COMPLETE');self.assertNotIn('running_eligible',result);self.assertNotIn('gate2_prepared',result)
 def test_R_S_A_and_support_tamper(self):
  original=copy.deepcopy(self.files)
  for path in ('references.json','archive.json','sidecar.evidence','support/entry_effective_stop.json'):
   with self.subTest(path=path):
    self.files=copy.deepcopy(original);self.files[path]+=b'changed';self.reject()
  self.files=original
 def test_missing_supporting_file(self):
  del self.files['support/entry_effective_stop.json'];self.reject('MEMBERSHIP')
 def test_missing_R(self):
  del self.files['references.json'];self.reject('MEMBERSHIP')
 def test_missing_A(self):
  del self.files['archive.json'];self.reject()
 def test_missing_S(self):
  del self.files['sidecar.evidence']
  self.reject('MEMBERSHIP')
 def test_extra_undeclared_file(self):
  self.files['undeclared.json']=b'{}';self.reject('MEMBERSHIP')
 def test_wrong_role_even_with_new_integrity_seal(self):
  r=parse_json(self.files['references.json']);next(e for e in r['entries'] if e['role']=='ENTRY_EFFECTIVE_STOP')['role']='FOREIGN_ROLE'
  self.reseal(r=r);self.reject('WRONG_ROLE')
 def test_foreign_group(self):
  r=parse_json(self.files['references.json']);r['entries'][0]['group_id']='foreign';self.reseal(r=r);self.reject('FOREIGN')
 def test_duplicate_role(self):
  r=parse_json(self.files['references.json']);r['entries'][1]['role']=r['entries'][0]['role'];self.reseal(r=r);self.reject('DUPLICATE')
 def test_duplicate_casefold_path_alias(self):
  transport=json.loads(encode_archive(self.files));entry=copy.deepcopy(transport['artifacts'][0]);entry['path']=entry['path'].upper();transport['artifacts'].append(entry)
  with self.assertRaisesRegex(ValueError,'ALIAS'):decode_archive(json_bytes(transport))
 def test_traversal_reserved_and_alternate_stream_paths(self):
  for path in ('../a','a/../b','a\\b','/root','C:/x','a:stream','CON.txt','a.','a//b'):
   with self.subTest(path=path),self.assertRaisesRegex(ValueError,'PATH_INVALID'):archive_path(path)
 def test_old_inventory_protocol_rejected(self):
  self.seal['binding']['inventory_protocol_hash']='A'*64;self.reject('DOWNGRADE')
 def test_seal_is_integrity_only_not_execution_authority(self):
  self.seal['authority']='EXECUTION_AUTHORIZATION';self.reject('AUTHORITY')
 def test_payload_cannot_select_seal(self):
  transport=json.loads(encode_archive(self.files));transport['seal']=self.seal
  with self.assertRaisesRegex(ValueError,'TRANSPORT_INVALID'):decode_archive(json_bytes(transport))
 def test_unreferenced_support_cannot_gain_authority(self):
  r=parse_json(self.files['references.json']);self.files['extra.json']=b'{"x":7}'
  r['entries'].append(inventory_entry('extra.json','EXTRA',self.files['extra.json'],self.seal['binding']))
  self.reseal(r=r);self.reject('UNREFERENCED')
 def test_containment_substitution(self):
  r=parse_json(self.files['references.json']);r['entries'][0]['role']='INVALID_RUN_CONTAINMENT_EVIDENCE';self.reseal(r=r);self.reject('CONTAINMENT')
 def test_S_cannot_bind_final_A_hash(self):
  s=self.sidecar();s['integrity']['archive_inventory_hash']=self.seal['archive_sha256']
  raw=json_bytes(s);self.files['sidecar.evidence']=raw+b'|sha256='+digest(raw).encode()
  a=parse_json(self.files['archive.json']);e=next(e for e in a['entries'] if e['role']=='V3_SIDECAR');e.update(size=len(self.files['sidecar.evidence']),sha256=digest(self.files['sidecar.evidence']))
  self.files['archive.json']=json_bytes(a);self.seal['archive_sha256']=digest(self.files['archive.json']);self.reject('REFERENCE_INVENTORY_MISMATCH')
 def test_financial_projection_twice(self):
  s=self.sidecar();s['terminal']['financial_projection_count']=2;self.reseal(s);self.reject('PROJECTION')
 def test_original_denominators_cannot_change(self):
  for key in ('E0','R0'):
   original=copy.deepcopy(self.files);original_seal=copy.deepcopy(self.seal)
   s=self.sidecar();s['original'][key]='9000';self.reseal(s);self.reject()
   self.files=original;self.seal=original_seal
 def test_missing_or_failed_zero_property_reads(self):
  for key in ('profit','commission','fee','swap','reason','volume','price','identity','time'):
   original=copy.deepcopy(self.files);original_seal=copy.deepcopy(self.seal)
   s=self.sidecar();s['entry']['read_flags'][key]=False;self.reseal(s);self.reject()
   self.files=original;self.seal=original_seal
 def test_foreign_position_rejects(self):
  s=self.sidecar();s['original']['position_id']=999;self.reseal(s);self.reject('POSITION')
 def test_residual_volume_and_stop_reject(self):
  for key in ('Vr','S0','P0'):
   original=copy.deepcopy(self.files);original_seal=copy.deepcopy(self.seal)
   s=self.sidecar();s['residual_snapshots'][-1][key]='88';self.reseal(s);self.reject()
   self.files=original;self.seal=original_seal
 def test_missing_sidecar_fields_and_v2_relabel(self):
  for key in ('original','precision','integrity'):
   s=self.sidecar();del s[key]
   raw=json_bytes(s)+b'|sha256='+digest(json_bytes(s)).encode()
   with self.assertRaisesRegex(ValueError,'V3_FIELDS'):read_package(raw)
  s=self.sidecar();s['package_id']='NATIVE_COST_BOUNDARY_PACKAGE_V2';self.reseal(s);self.reject('V3_SEMANTICS')
 def test_seal_cannot_self_authorize_successor(self):
  result=ResearchRunCoordinator().authorize(self.f.manifest,self.seal)
  self.assertFalse(result['allowed']);self.assertNotIn('next_status',result)

if __name__=='__main__':unittest.main()
