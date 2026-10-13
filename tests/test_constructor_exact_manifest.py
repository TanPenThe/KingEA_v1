"""Exact source-authority tests; no governed package or runtime is created."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from governance.review.build6182_exact_maintenance_20260914 import construct_fixture_packages as c

BASE=c.ROOT/'governance/review/build6182_native_persist_path_length_repair_governed_compile_20260921'
PIN='22584AF4570D0BEABFEBA010C3A317512B4197CE384F7B3BA68BB3BD13DF7B0F'
LAYERS=['89DE69166D48962B6E8F415CEE57342351E95FD090B4E9143668A16E58F50CC8','8FBD11C1490C58473FAD7DF8E3451F8B31BB1222DC9CE795AAC5F374ACBF209E','F71250A0B4728867FD9F6898EC54E7F3C8080DF2DC597AF6971CD44DF3B49740']

class ExactManifestTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.root=Path(self.tmp.name);self.path=self.root/'authority.json'
  self.raw=(BASE/'SOURCE_MANIFEST_V3.json').read_bytes();self.path.write_bytes(self.raw)
  # This is a historical compile-stable manifest. Verify its retained compile
  # source, while allowing separately authorized later working-tree edits.
  historical=BASE/'compile/MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh'
  retained=historical.read_bytes()
  self.assertEqual(c.sha(retained),json.loads(self.raw)['files'][1]['sha256'])
  historical_validation=c.ROOT/'governance/review/order_terminality_diagnostic_instrumentation_20260923/before/decision_a_evidence.py'
  retained_validation=historical_validation.read_bytes()
  self.assertEqual(c.sha(retained_validation),json.loads(self.raw)['files'][4]['sha256'])
  original=Path.read_bytes
  def historical_read(path):
   if path.resolve()==c.INTEGRATION_SOURCE.resolve():return retained
   if path.resolve()==c.VALIDATION_SOURCE.resolve():return retained_validation
   return original(path)
  source_patch=patch.object(Path,'read_bytes',historical_read)
  source_patch.start();self.addCleanup(source_patch.stop)
 def reject(self,raw,reason,pin=None):
  self.path.write_bytes(raw)
  with self.assertRaisesRegex(ValueError,reason):
   c.construct_layer_a(self.root/'must_not_exist',c.FIXTURES[0],source_manifest_path=self.path,source_manifest_sha256=pin or c.sha(raw))
  self.assertFalse((self.root/'must_not_exist').exists())
 def changed(self,change,reason):
  obj=json.loads(self.raw);change(obj);self.reject(c.raw_json(obj),reason)
 def test_accepted_exact_753_bytes(self):
  with patch.object(c,'source_manifest',side_effect=AssertionError('fallback forbidden')):
   observed=c.read_exact_source_manifest(self.path,PIN)
  self.assertEqual(observed,self.raw);self.assertEqual(len(observed),753);self.assertEqual(c.sha(observed),PIN)
 def test_hash_mismatch_before_parse(self):
  with patch.object(c.json,'loads',side_effect=AssertionError('parsed before hash')):
   self.reject(b'not json','SOURCE_MANIFEST_HASH_MISMATCH',PIN)
 def test_semantically_equivalent_byte_change_rejects(self):
  self.reject(self.raw+b'\n','SOURCE_MANIFEST_HASH_MISMATCH',PIN)
 def test_removal_of_length_rejects_original_pin(self):
  obj=json.loads(self.raw);del obj['files'][1]['byte_length']
  self.reject(c.raw_json(obj),'SOURCE_MANIFEST_HASH_MISMATCH',PIN)
 def test_wrong_length(self):
  self.changed(lambda x:x['files'][1].update(byte_length=36491),'LENGTH_MISMATCH')
 def test_wrong_member_hash(self):
  self.changed(lambda x:x['files'][1].update(sha256='0'*64),'SOURCE_DRIFT')
 def test_missing_member(self):
  self.changed(lambda x:x['files'].pop(),'MEMBERS_INVALID')
 def test_duplicate_path(self):
  self.changed(lambda x:x['files'].__setitem__(1,x['files'][0].copy()),'DUPLICATE_PATH')
 def test_traversal(self):
  self.changed(lambda x:x['files'][1].update(path='../outside'),'PATH_INVALID')
 def test_absolute_path(self):
  self.changed(lambda x:x['files'][1].update(path=str(c.INTEGRATION_SOURCE)),'PATH_INVALID')
 def test_wrong_kind(self):
  self.changed(lambda x:x.update(kind='FOREIGN'),'KIND_INVALID')
 def test_malformed_json(self):
  self.reject(b'{','JSON_INVALID')
 def test_noncanonical_pinned_bytes_preserved(self):
  raw=json.dumps(json.loads(self.raw),indent=4).encode()+b'\r\n';self.path.write_bytes(raw)
  with patch.object(c,'raw_json',side_effect=AssertionError('reserialization forbidden')):
   self.assertEqual(c.read_exact_source_manifest(self.path,c.sha(raw)),raw)
 def test_unknown_fields(self):
  for change in (lambda x:x.update(extra=True),lambda x:x['files'][0].update(extra=True)):
   self.changed(change,'STRUCTURE_INVALID')
 def test_duplicate_json_keys(self):
  self.reject(self.raw.replace(b'"kind":',b'"kind":"duplicate","kind":',1),'DUPLICATE_KEY')
 def test_member_order(self):
  self.changed(lambda x:x['files'].reverse(),'ORDER_INVALID')
 def test_boolean_length_not_integer(self):
  self.changed(lambda x:x['files'][1].update(byte_length=True),'LENGTH_MISMATCH')
 def test_missing_pin_no_fallback(self):
  with self.assertRaisesRegex(ValueError,'PIN_REQUIRED'):
   c.construct(self.root/'absent',c.FIXTURES[0],build_authority_root=self.root)
  with self.assertRaises(TypeError):c.construct_layer_a(self.root/'absent',c.FIXTURES[0])
  self.assertFalse((self.root/'absent').exists())
 def test_source_file_missing(self):
  original=Path.read_bytes
  def read(p):
   if p.resolve()==c.INTEGRATION_SOURCE.resolve():raise FileNotFoundError(str(p))
   return original(p)
  with patch.object(Path,'read_bytes',read),self.assertRaises(FileNotFoundError):c.read_exact_source_manifest(self.path,PIN)
 def test_three_layer_a_dry_reproduction(self):
  raw=c.read_exact_source_manifest(self.path,PIN)
  for f,expected in zip(c.FIXTURES,LAYERS):
   old=(BASE/f"compile/MQL5/Files/KingEA/conformance/{f['fixture_id']}/manifest.json").read_bytes();obj=json.loads(old)
   fixture=dict(f);fixture.pop('run_label');fixture.update(data_scope='DEVELOPMENT_ONLY',execution_mode=20,optimization=False,symbol='ETHUSD.s')
   derived=c.build_layer_a(fixture,obj['configuration_sha256'],c.sha(raw))
   self.assertEqual(derived,old);self.assertEqual(c.sha(derived),expected)

if __name__=='__main__':unittest.main()
