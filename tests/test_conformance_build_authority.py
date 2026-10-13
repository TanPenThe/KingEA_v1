"""Synthetic 6182 compatibility only. No executable here is a real MT5 binary."""
import copy
import unittest
import test_native_conformance_control as fixtures
from research_pipeline import decision_a_evidence as v
from research_pipeline.native_conformance_control import ConformanceControl, DOMAIN, BUILD_KEYS, BUILD_HASH_KEYS, read_build_authority, validate_prelaunch_binding, build_layer_b

class BuildAuthorityTests(unittest.TestCase):
 def setUp(self):
  self.fixture=fixtures.ConformanceTests();self.addCleanup(self.fixture.doCleanups)
  self.fixture.setup_fixture();f=self.fixture
  self.authority=dict(kind='NATIVE_CONFORMANCE_BUILD_AUTHORITY_V1',domain=DOMAIN,fixture_id=f.ctx.fixture['fixture_id'],run_id=f.ctx.fixture['run_id'],terminal_build=6182,agent_build=6182,compiler_build=6182,terminal_executable_sha256=v.digest(b'TERMINAL'),metatester_executable_sha256=v.digest(b'SYNTHETIC_TESTER'),metaeditor_executable_sha256=v.digest(b'SYNTHETIC_COMPILER'))
  self.pinroot=f.dir/'independent-build-pins';self.pinroot.mkdir()
  raw=v.json_bytes(self.authority);(self.pinroot/'build.json').write_bytes(raw)
  self.pin=dict(path='build.json',byte_length=len(raw),sha256=v.digest(raw))
  self.control=copy.deepcopy(f.control);self.control['build_authority_reference']=self.pin
  profile=copy.deepcopy(f.ctx.profile)
  for k in BUILD_KEYS+BUILD_HASH_KEYS:
   self.control['environment'][k]=self.authority[k];profile[k]=self.authority[k]
  self.control['profile']=f.store('6182-profile.json',profile)

 def context(self,authority=True):
  p=self.fixture.store('6182-control.json',self.control)
  return ConformanceControl(self.fixture.dir,p['path'],p['sha256'],**(dict(build_authority_root=self.pinroot,build_authority_reference=self.pin) if authority else {}))

 def test_builder_binds_reference_without_changing_layer_a(self):
  c=self.control
  raw=build_layer_b(**{k:c[k] for k in ('fixture','profile','artifacts','local_inputs','embedded_manifest','ea_source_sha256','environment','build_authority_reference')})
  self.assertEqual(v.parse_json(raw),c)
  self.assertEqual(self.context().layer_a_raw,self.fixture.ctx.layer_a_raw)

 def test_launch_build_and_binary_hash_mismatches(self):
  c=self.context();self.fixture.ctx=c;ref=self.fixture.launch_receipt()
  original=v.parse_json((self.fixture.dir/ref['path']).read_bytes())
  for k in BUILD_KEYS+BUILD_HASH_KEYS:
   bad=copy.deepcopy(original);bad[k]=6183 if k in BUILD_KEYS else 'F'*64
   with self.subTest(field=k),self.assertRaises(ValueError):
    c.verify_launch_record(self.fixture.store('bad-launch.json',bad),loader_binding_root=self.fixture.loader_root,expected_terminal_root=self.fixture.expected_root)

 def test_synthetic_6182_profile_layer_b_set_terminal_and_launch(self):
  c=self.context();self.fixture.ctx=c
  self.assertTrue(validate_prelaunch_binding(c,c.prepare_inputs()['set_bytes'])['launch_authorized'])
  self.assertEqual(c.prepare_inputs()['set_values']['InpConformanceExpectedTerminalBuild'],'6182')
  launch=self.fixture.launch_receipt()
  bound=c.with_launch_record(launch,loader_binding_root=self.fixture.loader_root,expected_terminal_root=self.fixture.expected_root)
  self.assertEqual(bound.expected_build('agent_build'),6182)
  self.assertIsNone(bound.profile['accepted_proof_sha256'])

 def test_missing_authority(self):
  with self.assertRaises(ValueError):self.context(False)

 def test_set_build_must_equal_fixture_authority_exactly(self):
  c=self.context();good=c.prepare_inputs()['set_bytes']
  for bad_value in (6140,6183,0):
   bad=good.replace(b'InpConformanceExpectedTerminalBuild=6182||6182||1||6182||N',
                    ('InpConformanceExpectedTerminalBuild='+str(bad_value)+'||'+str(bad_value)+'||1||'+str(bad_value)+'||N').encode())
   with self.subTest(build=bad_value),self.assertRaisesRegex(ValueError,'CONFORMANCE_PRELAUNCH_SET_MISMATCH'):
    validate_prelaunch_binding(c,bad)

 def test_foreign_fixture_authority_rejects(self):
  foreign=dict(self.authority,fixture_id='FOREIGN',run_id='F'*64)
  raw=v.json_bytes(foreign);(self.pinroot/'foreign.json').write_bytes(raw)
  ref=dict(path='foreign.json',byte_length=len(raw),sha256=v.digest(raw))
  control=self.fixture.store('foreign-control.json',dict(self.control,build_authority_reference=ref))
  with self.assertRaisesRegex(ValueError,'CONFORMANCE_BUILD_AUTHORITY'):
   ConformanceControl(self.fixture.dir,control['path'],control['sha256'],build_authority_root=self.pinroot,build_authority_reference=ref)
  del self.control['build_authority_reference']
  with self.assertRaises(ValueError):self.context(False)

 def test_each_build_and_hash_mismatch(self):
  original=copy.deepcopy(self.control)
  for k in BUILD_KEYS+BUILD_HASH_KEYS:
   with self.subTest(field=k):
    self.control=copy.deepcopy(original);self.control['environment'][k]=6183 if k in BUILD_KEYS else 'F'*64
    with self.assertRaises(ValueError):self.context()

 def test_profile_build_hash_and_swap_mismatch(self):
  original=copy.deepcopy(self.fixture.ctx.profile)
  for k in BUILD_KEYS+BUILD_HASH_KEYS+('native_swap_profile_hash',):
   with self.subTest(field=k):
    profile=copy.deepcopy(original)
    for field in BUILD_KEYS+BUILD_HASH_KEYS:profile[field]=self.authority[field]
    profile[k]=6183 if k in BUILD_KEYS else 'F'*64
    self.control['profile']=self.fixture.store('6182-profile.json',profile)
    with self.assertRaises(ValueError):self.context()

 def test_malformed_unknown_build_and_candidate_authority(self):
  for change in ({'terminal_build':6183},{'agent_build':6183},{'compiler_build':6183},{'domain':'CAND-ETH-ST-002'},{'extra':True},{'terminal_executable_sha256':'bad'}):
   raw=v.json_bytes(dict(self.authority,**change));(self.pinroot/'build.json').write_bytes(raw)
   pin=dict(self.pin,byte_length=len(raw),sha256=v.digest(raw))
   with self.subTest(change=change),self.assertRaises(ValueError):read_build_authority(self.pinroot,pin)

 def test_cotamper_without_pin_and_foreign_lineage(self):
  (self.pinroot/'build.json').write_bytes(v.json_bytes(dict(self.authority,fixture_id='FOREIGN')))
  with self.assertRaises(ValueError):self.context()
  raw=(self.pinroot/'build.json').read_bytes();self.pin.update(byte_length=len(raw),sha256=v.digest(raw))
  with self.assertRaises(ValueError):self.context()

 def test_successor_cannot_use_conformance_profile_or_manufactured_proof(self):
  c=self.context()
  with self.assertRaises(ValueError):v.validate_profile(c.profile)
  profile=copy.deepcopy(c.profile);profile['accepted_proof_sha256']=v.NATIVE_PROOF
  self.control['profile']=self.fixture.store('6182-profile.json',profile)
  with self.assertRaises(ValueError):self.context()

 def test_later_authority_mutation_rejects(self):
  c=self.context();(self.pinroot/'build.json').write_bytes(b'{}')
  with self.assertRaises(ValueError):c.prepare_inputs()
