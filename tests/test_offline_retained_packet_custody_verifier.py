"""Review-only packet custody and historical snapshot regression tests."""
import builtins,copy,hashlib,io,json,os,sys,tempfile,unittest
from pathlib import Path
from unittest import mock
ROOT=Path(__file__).resolve().parents[1]
REVIEW=ROOT/'governance/review/offline_retained_packet_custody_verifier_20260928'
sys.path.insert(0,str(REVIEW))
import packet_only_verifier as p
from test_v3_completion_lineage_key_repair import verify_historical_snapshot
RUNTIME=ROOT/'governance/review/v5_retained_custodianship_long_runtime_20260928/RUNTIME_REVIEW_BUNDLE.zip'
H=lambda b:hashlib.sha256(b).hexdigest().upper()

class PacketOnlyVerifierTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.runtime=RUNTIME.read_bytes();cls.baseline=p.packet_facts(cls.runtime)
 def facts(self):return copy.deepcopy(self.baseline)
 def edit(self,facts,name,key,value):
  path=p.NAMES[name];record=p.obj(facts['members'][path]);record[key]=value;facts['members'][path]=p.canonical(record)
 def reject(self,facts,semantic=True):
  with self.assertRaises(p.PacketError):
   (p._validate_attestation_semantics if semantic else p.validate_attestation)(facts)
 def test_exact_packet_positive_proposed_only(self):
  output=p.verify_packet(self.runtime);a=output['attestation'];r=output['proposed_launch_record']
  self.assertEqual('PASS_PACKET_ONLY',a['result']);self.assertEqual('PROPOSED_FOR_INDEPENDENT_REVIEW',a['classification'])
  self.assertEqual('NOT_AVAILABLE_PACKET_ONLY',a['TERMINAL_BINARY_BYTES_REHASH']);self.assertFalse(r['accepted_live_api_record'])
  self.assertFalse(any(r[k] for k in ('runtime_authority','trading_authority','candidate_authority','successor_authority')))
 def test_archive_byte_mutation_rejects(self):
  raw=bytearray(self.runtime);raw[-50]^=1
  with self.assertRaises(p.PacketError):p.verify_packet(bytes(raw))
 def test_wrong_terminal_hash_rejects(self):
  f=self.facts();self.edit(f,'expected','terminal_executable_sha256','0'*64);self.reject(f)
 def test_wrong_build_rejects(self):
  f=self.facts();self.edit(f,'expected','terminal_build',6183);self.reject(f)
 def test_wrong_instance_id_rejects(self):
  f=self.facts();self.edit(f,'expected','terminal_instance_id','a'*32);self.reject(f)
 def test_wrong_data_dir_instance_relationship_rejects(self):
  f=self.facts();self.edit(f,'expected','terminal_data_dir',r'C:\other\D0E8209F77C8CF37AD8BF550E51FF075');self.reject(f)
 def test_wrong_raw_origin_hash_rejects(self):
  f=self.facts();self.edit(f,'expected','origin_sha256','0'*64);self.reject(f)
 def test_wrong_decoded_origin_directory_rejects(self):
  f=self.facts();raw=b'\xff\xfe'+r'C:\Other Terminal'.encode('utf-16-le');f['members'][p.NAMES['origin']]=raw;self.edit(f,'expected','origin_sha256',H(raw));self.reject(f)
 def test_wrong_loader_terminal_identity_rejects(self):
  f=self.facts();self.edit(f,'receipt','terminal_instance_id','A'*32);self.reject(f)
 def test_wrong_set_hash_rejects(self):
  f=self.facts();self.edit(f,'receipt','loader_set_sha256','0'*64);self.reject(f)
 def test_wrong_set_length_rejects(self):
  f=self.facts();self.edit(f,'receipt','byte_length',1427);self.reject(f)
 def test_wrong_ini_hash_rejects(self):
  f=self.facts();self.edit(f,'receipt','ini_sha256','0'*64);self.reject(f)
 def test_wrong_expert_parameters_basename_rejects(self):
  f=self.facts();self.edit(f,'receipt','expert_parameters','wrong.set');self.reject(f)
 def test_wrong_loader_absolute_path_rejects(self):
  f=self.facts();self.edit(f,'receipt','loader_absolute_path',r'C:\wrong\NCV1-LONG-NORMAL-001.set');self.reject(f)
 def test_post_write_not_pass_rejects(self):
  f=self.facts();self.edit(f,'receipt','post_write_verification','FAIL');self.reject(f)
 def test_missing_accepted_loader_validation_rejects(self):
  f=self.facts();del f['members'][p.NAMES['loader_validation']];self.reject(f)
 def test_accepted_loader_validation_not_pass_rejects(self):
  f=self.facts();self.edit(f,'loader_validation','result','FAIL');self.reject(f)
 def test_wrong_api_names_rejects(self):
  for key in ('api','staging_api','terminal_instance_api'):
   with self.subTest(key=key):
    f=self.facts();self.edit(f,'loader_validation',key,'wrong_api');self.reject(f)
 def test_wrong_accepted_loader_reference_rejects(self):
  f=self.facts();x=p.record(f,'loader_validation');x['receipt_reference']['sha256']='0'*64;f['members'][p.NAMES['loader_validation']]=p.canonical(x);self.reject(f)
 def test_wrong_custody_manifest_references_rejects(self):
  for key in ('origin_raw_reference','loader_receipt_reference','expected_terminal_reference','accepted_loader_validation_reference'):
   with self.subTest(key=key):
    f=self.facts();x=p.record(f,'manifest');x[key]['sha256']='0'*64;f['members'][p.NAMES['manifest']]=p.canonical(x);self.reject(f)
 def test_wrong_creation_order_rejects(self):
  f=self.facts();x=p.record(f,'order');x['retained_custody'][1]['mtime_ns']=x['retained_custody'][0]['mtime_ns']-1;f['members'][p.NAMES['order']]=p.canonical(x);self.reject(f)
 def test_origin_created_after_launch_rejects(self):
  f=self.facts();x=p.record(f,'order');x['retained_custody'][0]['mtime_ns']=x['launch_attempt_mtime_ns']+1;f['members'][p.NAMES['order']]=p.canonical(x);self.reject(f)
 def test_receipt_created_after_launch_rejects(self):
  f=self.facts();x=p.record(f,'order');x['retained_custody'][1]['mtime_ns']=x['launch_attempt_mtime_ns']+1;f['members'][p.NAMES['order']]=p.canonical(x);self.reject(f)
 def test_wrong_authority_origin_hash_rejects(self):
  f=self.facts();self.edit(f,'authority','origin_raw_sha256','0'*64);self.reject(f)
 def test_wrong_authority_loader_hash_rejects(self):
  f=self.facts();self.edit(f,'authority','loader_binding_receipt_sha256','0'*64);self.reject(f)
 def test_wrong_consumed_authority_hash_rejects(self):
  f=self.facts();self.edit(f,'consumed','authority_sha256','0'*64);self.reject(f)
 def test_wrong_launch_executable_path_rejects(self):
  f=self.facts();x=p.record(f,'launch_process');x['args'][0]=r'C:\wrong\terminal64.exe';f['members'][p.NAMES['launch_process']]=p.canonical(x);self.reject(f)
 def test_retrospective_only_substitution_rejects(self):
  f=self.facts();f['members']['postflight/terminal_origin.raw']=f['members'].pop(p.NAMES['origin']);self.reject(f,False)
 def test_missing_packet_artifact_rejects(self):
  f=self.facts();del f['members'][p.NAMES['expected']];self.reject(f,False)
 def test_missing_package_artifact_rejects(self):
  f=self.facts();del f['package'][p.P+'NCV1-LONG-NORMAL-001.set'];self.reject(f)
 def test_live_terminal_paths_poisoned_and_not_accessed(self):
  # Fixture bytes are loaded before all file-open functions are poisoned.
  with (mock.patch('builtins.open',side_effect=AssertionError('LIVE_PATH_READ')),
        mock.patch('pathlib.Path.open',side_effect=AssertionError('LIVE_PATH_READ')),
        mock.patch('os.open',side_effect=AssertionError('LIVE_PATH_READ')),
        mock.patch('research_pipeline.native_conformance_control.resolve_terminal_instance',side_effect=AssertionError('LIVE_RESOLVER'))):
   self.assertEqual('PASS_PACKET_ONLY',p.verify_packet(self.runtime)['attestation']['result'])

class HistoricalSnapshotRepairTests(unittest.TestCase):
 def snapshot(self,count):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);root=Path(self.tmp.name);expected=[]
  for i in range(count):
   name=f'file{i:03d}.evidence';value=f'original-{i}'.encode();(root/name).write_bytes(value);expected.append({'filename':name,'byte_length':len(value),'sha256':H(value)})
  return root,expected
 def test_missing_historical_file_rejects(self):
  root,expected=self.snapshot(46);(root/expected[0]['filename']).unlink()
  with self.assertRaises(AssertionError):verify_historical_snapshot(root,expected,46)
 def test_same_name_byte_mutation_rejects(self):
  root,expected=self.snapshot(46);(root/expected[0]['filename']).write_bytes(b'X'*expected[0]['byte_length'])
  with self.assertRaises(AssertionError):verify_historical_snapshot(root,expected,46)
 def test_same_name_length_mutation_rejects(self):
  root,expected=self.snapshot(46);(root/expected[0]['filename']).write_bytes(b'X')
  with self.assertRaises(AssertionError):verify_historical_snapshot(root,expected,46)
 def test_historical_hash_mutation_rejects(self):
  root,expected=self.snapshot(154);expected[0]['sha256']='0'*64
  with self.assertRaises(AssertionError):verify_historical_snapshot(root,expected,154)
 def test_authorized_extra_files_do_not_reject(self):
  root,expected=self.snapshot(46);(root/'later-evidence').write_bytes(b'later');verify_historical_snapshot(root,expected,46)
 def test_historical_snapshot_cardinality_exact(self):
  gate=json.loads((ROOT/'governance/review/v3_completion_lineage_key_source_repair_20260927/PRE_REPAIR_GATE.json').read_bytes())
  self.assertEqual(46,len(gate['spool_files']));self.assertEqual(154,len(gate['observability_files']))
  root,expected=self.snapshot(46)
  with self.assertRaises(AssertionError):verify_historical_snapshot(root,expected[:-1],46)
  root,expected=self.snapshot(154)
  with self.assertRaises(AssertionError):verify_historical_snapshot(root,expected[:-1],154)

if __name__=='__main__':unittest.main()
