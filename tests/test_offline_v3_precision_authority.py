import copy,hashlib,json,sys,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from governance.review.offline_v3_precision_authority_20260929 import precision_test_support as support
import test_native_conformance_control as fixture_module

class PrecisionAuthorityReviewTests(unittest.TestCase):
 def setUp(self):
  self.fixture=fixture_module.ConformanceTests('test_long_and_short_bootstrap')
  self.files=self.fixture.setup_fixture();self.addCleanup(self.fixture.doCleanups)
  self.ctx=self.fixture.ctx;self.profile=copy.deepcopy(self.ctx.profile)
  self.p=support.NEW.read_package(self.files['sidecar.evidence']);self.pr=self.p['precision']
  self.references=support.refs(support.NEW,self.files)
 def run_rule(self,ctx=True):
  return support.NEW_RULE(self.pr,self.profile,self.references,self.ctx if ctx else None)
 def reject(self):
  with self.assertRaises((ValueError,KeyError)):self.run_rule()
 def test_01_both_roles_positive(self):
  self.assertEqual(self.run_rule(),{(self.pr[k],r) for k,r in [('price_convention_hash','PRICE_CONVENTION'),('arithmetic_contract_hash','ARITHMETIC_CONTRACT')]})
 def test_02_both_roles_missing(self):
  for role in ('PRICE_CONVENTION','ARITHMETIC_CONTRACT'):
   with self.subTest(role=role):
    raw=self.ctx.authorities.pop(role)
    self.reject();self.ctx.authorities[role]=raw
 def test_03_both_roles_foreign_bytes(self):
  for role in ('PRICE_CONVENTION','ARITHMETIC_CONTRACT'):
   with self.subTest(role=role):
    raw=self.ctx.authorities[role];self.ctx.authorities[role]=b'{"foreign":true}'
    self.reject();self.ctx.authorities[role]=raw
 def test_04_control_hash_and_reference_mutations(self):
  for role in ('PRICE_CONVENTION','ARITHMETIC_CONTRACT'):
   original=copy.deepcopy(self.ctx.control['artifacts'][role])
   self.ctx.control['artifacts'][role]['sha256']='F'*64;self.reject()
   self.ctx.control['artifacts'][role]=original
   del self.ctx.control['artifacts'][role];self.reject()
   self.ctx.control['artifacts'][role]=original
 def test_05_reference_role_substitution(self):
  entries=[dict(e) for e in self.references.entries]
  for e in entries:
   if e['role']=='PRICE_CONVENTION':e['role']='FOREIGN_PRICE_CONVENTION'
  self.references=support.NEW.VerifiedReferences(self.references.binding,tuple(entries),self.references.files,self.references.reference_hash)
  self.reject()
 def test_06_precision_hash_disagrees(self):
  self.pr['price_convention_hash']=self.pr['arithmetic_contract_hash'];self.reject()
 def test_07_profile_cannot_select_other_authority(self):
  self.profile['price_convention_hash']='F'*64;self.reject()
 def test_08_context_profile_mutation(self):
  self.ctx.profile['price_convention_hash']='F'*64;self.profile=self.ctx.profile;self.reject()
 def test_09_changed_control_bytes_and_layer_b(self):
  saved=self.ctx.control_raw;self.ctx.control_raw=saved+b' ';self.reject();self.ctx.control_raw=saved
  self.ctx.control_hash='F'*64;self.reject()
 def test_10_unbound_reference_bytes(self):
  files=dict(self.references.files)
  entry=next(e for e in self.references.entries if e['role']=='ARITHMETIC_CONTRACT')
  files[entry['path']]=b'foreign'
  self.references=support.NEW.VerifiedReferences(self.references.binding,self.references.entries,files,self.references.reference_hash)
  self.reject()
 def test_11_extra_authority_substitution(self):
  self.ctx.authorities['EXTRA_PRICE_CONVENTION']=self.ctx.authorities['PRICE_CONVENTION']
  self.ctx.authorities['PRICE_CONVENTION']=self.ctx.authorities['ARITHMETIC_CONTRACT'];self.reject()
 def test_12_retained_package_path_rehashed(self):
  ref=self.ctx.control['artifacts']['PRICE_CONVENTION']
  (self.ctx.directory/ref['path']).write_bytes(b'foreign');self.reject()
 def test_13_nonconformance_requires_both_profile_fields(self):
  self.assertEqual(self.run_rule(False),support.OLD_RULE(self.pr,self.profile,support.refs(support.OLD,self.files),None))
  for key in ('price_convention_hash','arithmetic_contract_hash'):
   saved=self.profile.pop(key)
   with self.assertRaises(KeyError):self.run_rule(False)
   self.profile[key]='F'*64
   with self.assertRaisesRegex(ValueError,'UNPINNED_PRECISION_CONVENTION'):self.run_rule(False)
   self.profile[key]=saved
 def test_14_synthetic_full_lifecycle_parity(self):
  # Valid synthetic ConformanceControl contains the historical redundant keys.
  old_used=support.OLD_RULE(self.pr,self.profile,support.refs(support.OLD,self.files),self.ctx)
  self.assertEqual(old_used,self.run_rule())
  from research_pipeline import decision_a_evidence as accepted
  parity=support.synthetic_parity_module()
  a=accepted.validate_package(self.files['sidecar.evidence'],self.ctx.binding(),self.profile,support.refs(accepted,self.files),conformance=self.ctx)
  b=parity.validate_package(self.files['sidecar.evidence'],self.ctx.binding(),self.profile,support.refs(parity,self.files),conformance=self.ctx)
  self.assertEqual(a,b)
  for digest,role in old_used:
   self.assertEqual(self.references.resolve(digest,role),self.ctx.authorities[role])
 def test_15_valid_type_and_domain_required(self):
  with self.assertRaises(ValueError):support.NEW_RULE(self.pr,self.profile,self.references,object())
  self.ctx.control['domain']='CANDIDATE';self.reject()
 def test_16_profile_and_ieee_bytes_immutable(self):
  raw=(ROOT/'governance/review/offline_v3_ieee754_rounding_cell_20260929/REVIEW_BUNDLE/source/tester_profile.json').read_bytes()
  self.assertEqual(hashlib.sha256(raw).hexdigest().upper(),'0689CC715B623D9A6EFA14F47E0146D95B9FBA08A268655A8B5D323242E7FAA2')
  self.assertFalse({'price_convention_hash','arithmetic_contract_hash'}&json.loads(raw).keys())
  prior=ROOT/'governance/review/offline_v3_ieee754_rounding_cell_20260929/ieee754_price_grid.py'
  self.assertEqual(prior.read_bytes(),(support.DIR/'ieee754_price_grid.py').read_bytes())
  self.assertEqual(hashlib.sha256((ROOT/'research_pipeline/decision_a_evidence.py').read_bytes()).hexdigest().upper(),'B9D7CBB12185BCDFAF318D483AA9D234644303F48F75EF50C6E56B800DC2132F')

if __name__=='__main__':unittest.main()
