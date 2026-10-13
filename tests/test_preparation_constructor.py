"""Preparation tests use synthetic authority and mock only Windows file observation."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from governance.review.build6182_exact_maintenance_20260914 import construct_fixture_packages as c

class PreparationConstructorTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  for name in ('EA_SOURCE','INTEGRATION_SOURCE','STATIC_STOP_SOURCE','CONTROL_SOURCE','VALIDATION_SOURCE'):
   old=getattr(c,name);new=self.root/old.relative_to(c.ROOT);new.parent.mkdir(parents=True,exist_ok=True);new.write_bytes(old.read_bytes())
   p=patch.object(c,name,new);p.start();self.addCleanup(p.stop)
  p=patch.object(c,'ROOT',self.root);p.start();self.addCleanup(p.stop)
  self.manifest_pin=self.pin_sources()
  self.d=c.construct_layer_a(self.root/'package',c.FIXTURES[0],**self.manifest_pin)

 def pin_sources(self):
  raw=c.raw_json(c.source_manifest());p=self.root/'independent_source_manifest.json';p.write_bytes(raw)
  return dict(source_manifest_path=p,source_manifest_sha256=c.sha(raw))

 def pinned(self,name,value):
  raw=c.raw_json(value);p=self.root/name;p.write_bytes(raw)
  return dict(path=name,byte_length=len(raw),sha256=c.sha(raw))

 def authority(self):
  fixture=json.loads((self.d/'fixture_specification.json').read_bytes())
  a=dict(kind='NATIVE_CONFORMANCE_BUILD_AUTHORITY_V1',domain=c.DOMAIN,fixture_id=fixture['fixture_id'],run_id=fixture['run_id'])
  self.observations={};paths={}
  for build,key in zip(c.BUILD_KEYS,c.BUILD_HASH_KEYS):
   p=self.root/(key+'.exe');p.write_bytes(('SYNTHETIC ONLY '+key).encode());a[build]=6182;a[key]=c.sha(p.read_bytes());paths[key]=p
   self.observations[str(p)]=dict(path=str(p),sha256=a[key],byte_length=p.stat().st_size,version='5.0.0.6182',build=6182)
  self.a=a;ap=self.pinned('authority.json',a)
  ex5=self.root/'synthetic.ex5';ex5.write_bytes(b'SYNTHETIC EX5 NOT RUNTIME AUTHORITY')
  receipt=dict(kind='CONFORMANCE_POSTCOMPILE_BINDING_V1',layer_a_sha256=c.sha((self.d/'manifest.json').read_bytes()),source_manifest_sha256=c.sha((self.d/'source_manifest.json').read_bytes()),compiler_build=6182,compiler_sha256=a['metaeditor_executable_sha256'],ex5_sha256=c.sha(ex5.read_bytes()),ex5_byte_length=ex5.stat().st_size)
  return dict(build_authority_root=self.root,build_authority_reference=ap,binary_paths=paths,ex5_path=ex5,compile_receipt_root=self.root,compile_receipt_reference=self.pinned('compile.json',receipt),**self.manifest_pin)

 def observe(self,path):return self.observations[str(path)]

 def test_layer_a_determinism_and_closed_dependencies(self):
  other=c.construct_layer_a(self.root/'rebuild',c.FIXTURES[0],**self.manifest_pin)
  self.assertEqual((other/'manifest.json').read_bytes(),(self.d/'manifest.json').read_bytes())
  manifest=json.loads((self.d/'manifest.json').read_bytes())
  from research_pipeline.native_conformance_control import LAYER_A_FIELDS
  self.assertEqual(set(manifest),LAYER_A_FIELDS)
  source=json.loads((self.d/'source_manifest.json').read_bytes())
  self.assertEqual(source['kind'],'CONFORMANCE_COMPILE_STABLE_SOURCE_MANIFEST_V3')
  self.assertEqual(len(source['files']),5)
  self.assertEqual([x['path'] for x in source['files']],[
   'MQL5/Experts/KingEA/GuardedResearchTester.mq5',
   'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh',
   'MQL5/Include/KingEA/DecisionAStaticStop.mqh',
   'research_pipeline/native_conformance_control.py',
   'research_pipeline/decision_a_evidence.py'])
  historical=c.source_manifest_v2()
  self.assertEqual(historical['kind'],'CONFORMANCE_COMPILE_STABLE_SOURCE_MANIFEST_V2')
  self.assertEqual([x['path'] for x in historical['files']],[
   'MQL5/Experts/KingEA/GuardedResearchTester.mq5',
   'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh',
   'research_pipeline/native_conformance_control.py',
   'research_pipeline/decision_a_evidence.py'])
  for word in ('executable','build_authority','profile','terminal','set_sha256','ini_sha256'):
   self.assertNotIn(word,(self.d/'source_manifest.json').read_text())

 def test_manifest_membership_and_order_are_identity_bearing(self):
  manifest=c.source_manifest();raw=c.raw_json(manifest)
  reordered=copy.deepcopy(manifest);reordered['files'][1],reordered['files'][2]=reordered['files'][2],reordered['files'][1]
  omitted=copy.deepcopy(manifest);omitted['files'].pop()
  added=copy.deepcopy(manifest);added['files'].append(dict(path='FOREIGN',sha256='F'*64))
  for changed in (reordered,omitted,added):self.assertNotEqual(c.sha(raw),c.sha(c.raw_json(changed)))

 def test_each_python_identity_changes_layer_a(self):
  original=(self.d/'manifest.json').read_bytes()
  for name in ('EA_SOURCE','INTEGRATION_SOURCE','STATIC_STOP_SOURCE','CONTROL_SOURCE','VALIDATION_SOURCE'):
   p=getattr(c,name);before=p.read_bytes();p.write_bytes(before+b'\n# synthetic source delta\n')
   other=c.construct_layer_a(self.root/name,c.FIXTURES[0],**self.pin_sources());self.assertNotEqual(original,(other/'manifest.json').read_bytes());p.write_bytes(before)

 def test_explicit_authority_required_without_writes(self):
  with self.assertRaises(TypeError):c.complete_layer_b(self.d)
  with self.assertRaises(ValueError):c.construct(self.root/'denied',c.FIXTURES[0])
  self.assertFalse((self.d/'conformance_control.json').exists())

 def test_synthetic_cannot_claim_actual(self):
  args=self.authority()
  with self.assertRaisesRegex(ValueError,'ACTUAL_BINARY_REQUIRED'):c.complete_layer_b(self.d,**args)
  self.assertFalse((self.d/'conformance_control.json').exists())

 def test_synthetic_unit_construction_only_and_acyclicity(self):
  args=self.authority();before=(self.d/'manifest.json').read_bytes()
  with patch.object(c,'observe_binary',side_effect=self.observe):c.complete_layer_b(self.d,**args)
  self.assertEqual(before,(self.d/'manifest.json').read_bytes())
  status=json.loads((self.d/'PREPARATION_STATUS.json').read_bytes());self.assertFalse(status['runtime_authorized']);self.assertFalse(status['launch_authority'])
  self.assertEqual(status['constructor_kind'],'CONFORMANCE_PREPARATION_CONSTRUCTOR_V3')
  self.assertEqual(status['constructor_scope'],'REPAIRED_BUILD6182_CONFORMANCE_LINEAGE_ONLY')
  self.assertEqual(status['constructor_predecessor_sha256'],'DFFB6E8C5052AB575C1362F406A4AA76C18CE8BF030CF31AC78AE92BA8B6580D')
  self.assertEqual(status['source_manifest_schema'],'V3')
  control=json.loads((self.d/'conformance_control.json').read_bytes());profile=json.loads((self.d/'tester_profile.json').read_bytes())
  self.assertEqual(profile['terminal_build'],6182);self.assertIsNone(profile['accepted_proof_sha256'])
  self.assertEqual(control['build_authority_reference'],args['build_authority_reference'])
  self.assertEqual(control['local_inputs']['calendar_path'],c.CONFORMANCE_CALENDAR_RESOURCE_PATH)
  self.assertNotIn('set_sha256',control);self.assertNotIn('SET',control['artifacts'])
  name=c.FIXTURES[0]['fixture_id']+'.set'
  self.assertEqual([p.name for p in self.d.glob('*.set')],[name])
  self.assertIn('ExpertParameters='+name,(self.d/'tester.ini').read_text())
  self.assertIn(c.sha((self.d/'conformance_control.json').read_bytes()),(self.d/name).read_text())
  self.assertIn('InpConformanceExpectedTerminalBuild=6182||6182||1||6182||N',(self.d/name).read_text())
  self.assertFalse((self.d/'tester.ini').read_bytes().startswith(b'\xef\xbb\xbf'))

 def test_set_ini_binding_negatives(self):
  args=self.authority()
  with patch.object(c,'observe_binary',side_effect=self.observe):c.complete_layer_b(self.d,**args)
  control=self.d/'conformance_control.json'
  ctx=c.ConformanceControl(self.d,control.name,c.sha(control.read_bytes()),build_authority_root=self.root,build_authority_reference=args['build_authority_reference'])
  name=c.FIXTURES[0]['fixture_id']+'.set';set_path=self.d/name;ini_path=self.d/'tester.ini'
  expected=set_path.read_bytes();ini=ini_path.read_bytes()
  self.assertEqual(c.validate_set_ini_binding(self.d,ctx)['set_sha256'],c.sha(ctx.prepare_inputs()['set_bytes']))
  for case in ('missing','legacy','foreign_ini','altered','alias','bom'):
   with self.subTest(case=case):
    if case=='missing':set_path.unlink()
    elif case=='legacy':set_path.rename(self.d/'GuardedResearchTester.set')
    elif case=='foreign_ini':ini_path.write_bytes(ini.replace(name.encode(),b'FOREIGN.set'))
    elif case=='altered':set_path.write_bytes(expected+b'X')
    elif case=='alias':(self.d/'GuardedResearchTester.set').write_bytes(expected)
    elif case=='bom':ini_path.write_bytes(b'\xef\xbb\xbf'+ini)
    with self.assertRaises(ValueError):c.validate_set_ini_binding(self.d,ctx)
    for p in self.d.glob('*.set'):p.unlink()
    set_path.write_bytes(expected);ini_path.write_bytes(ini)

 def test_each_wrong_observed_executable_hash_rejects(self):
  args=self.authority()
  for key in c.BUILD_HASH_KEYS:
   path=str(args['binary_paths'][key]);old=self.observations[path]['sha256'];self.observations[path]['sha256']='F'*64
   with self.subTest(key=key),patch.object(c,'observe_binary',side_effect=self.observe),self.assertRaisesRegex(ValueError,'ACTUAL_BUILD_BINARY_MISMATCH'):c.complete_layer_b(self.d,**args)
   self.observations[path]['sha256']=old
  self.assertFalse((self.d/'conformance_control.json').exists())

 def test_6183_authority_rejects(self):
  args=self.authority();a=copy.deepcopy(self.a)
  for key in c.BUILD_KEYS:a[key]=6183
  args['build_authority_reference']=self.pinned('authority.json',a)
  with self.assertRaises(ValueError):c.complete_layer_b(self.d,**args)

 def test_compile_and_source_drift_rejects(self):
  args=self.authority();args['ex5_path'].write_bytes(b'CHANGED')
  with patch.object(c,'observe_binary',side_effect=self.observe),self.assertRaisesRegex(ValueError,'COMPILE_BINDING'):c.complete_layer_b(self.d,**args)
  c.CONTROL_SOURCE.write_bytes(b'CHANGED')
  with patch.object(c,'observe_binary',side_effect=self.observe),self.assertRaisesRegex(ValueError,'SOURCE_DRIFT'):c.complete_layer_b(self.d,**args)
