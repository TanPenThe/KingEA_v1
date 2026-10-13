"""Synthetic independent conformance fixtures; never native execution receipts."""
import copy,json,tempfile,unittest
from pathlib import Path
from test_successor_evidence import ControlFixture
from v3_fixture import package
from research_pipeline import decision_a_evidence as v
from research_pipeline.native_conformance_control import ConformanceControl,DOMAIN,SCOPE,SET_INPUT_TYPES,serialize_tester_set,resolve_terminal_instance,stage_expert_parameters,read_pinned_loader_binding,read_pinned_expected_terminal_instance,validate_loader_binding

class ConformanceTests(unittest.TestCase):
 def setup_fixture(self,side='LONG'):
  t=tempfile.TemporaryDirectory();self.addCleanup(t.cleanup);self.dir=Path(t.name)
  old=ControlFixture(self.dir);self.successor=old;files,seal,b,profile=package(old,False,True,True)
  capture=v.parse_json((self.dir/'native-capture.json').read_bytes())
  def store(name,value):
   raw=value if isinstance(value,bytes) else v.json_bytes(value);(self.dir/name).write_bytes(raw);return dict(path=name,sha256=v.digest(raw))
  self.store=store
  fixture=dict(fixture_id='FIXED-'+side,run_id=b['run_id'],group_id=b['group_id'],side=side,volume='2',S0='90' if side=='LONG' else '110',start_msc=1000,end_msc=100000,entry_msc=1000,reduction_msc=2000,close_msc=3000,outcome='NORMAL_CLOSE',data_scope='DEVELOPMENT_ONLY',execution_mode=20,optimization=False,symbol='ETHUSD.s')
  profile.update(evaluation_start_msc=1000,evidence_scope=SCOPE,fixture_id=fixture['fixture_id'],side=side,accepted_proof_sha256=None)
  refs=v.parse_json(files['references.json'])['entries'];art={e['role']:store('cf_'+e['role'].replace(':','_')+'.bin',files[e['path']]) for e in refs if e['role'] in {'CONFIGURATION_SPECIFICATION','SOURCE_MANIFEST','EXECUTABLE','COMBINED_SPECIFICATION','DECISION_A_SPECIFICATION','DECISION_S_SPECIFICATION','PRICE_CONVENTION','ARITHMETIC_CONTRACT'}}
  bootstrap=dict(kind='UNACCEPTED_NATIVE_SWAP_BOOTSTRAP',side=side,fixture_id=fixture['fixture_id'],evidence_scope=SCOPE)
  art['NATIVE_SWAP_PROFILE']=store('bootstrap.json',bootstrap);profile['native_swap_profile_hash']=art['NATIVE_SWAP_PROFILE']['sha256']
  self.control=dict(domain=DOMAIN,fixture=store('fixture.json',fixture),profile=store('cf-profile.json',profile),artifacts=art,local_inputs=dict(manifest_path='KingEA/conformance/'+fixture['fixture_id']+'/manifest.json',calendar_path='KingEA/conformance/'+fixture['fixture_id']+'/calendar.csv',calendar=store('calendar-fixture.csv',b'type,start_msc,end_msc,identity\nNEWS_BLOCK,110000,120000,SYNTHETIC\n')))
  pin=store('cf-control.json',self.control);self.ctx=ConformanceControl(self.dir,pin['path'],pin['sha256'])
  rows=[];n=0
  for row in capture['records']:
   row=copy.deepcopy(row);role=row['role']
   if role=='ORIGINAL':
    data=v.parse_json(row['payload'].encode());data.update(S0=fixture['S0'],profile_hash=v.digest(self.ctx.profile_raw));row['payload']=v.json_bytes(data).decode()
   if role in ('RECONCILED_POSITION','BEFORE_REQUEST'):
    data=v.parse_json(row['payload'].encode());data.update(sl=fixture['S0'],side=0 if side=='LONG' else 1);row['payload']=v.json_bytes(data).decode()
   if role=='DEAL_ADD':
    parts=row['payload'].split('|');parts[5]=str((0 if side=='LONG' else 1) if parts[4]=='0' else (1 if side=='LONG' else 0));parts[15]=fixture['S0'];row['payload']='|'.join(parts)
   if role=='ORDER_TERMINAL_OBSERVATION':
    data=v.parse_json(row['payload'].encode());data['type']=data['type'] if side=='LONG' else 1-data['type'];row['payload']=v.json_bytes(data).decode()
   if role=='REQUEST_RESULT':
    data=v.parse_json(row['payload'].encode());r=dict(action=1,magic=12001,order=0,symbol='ETHUSD.s',volume=data['volume'],price=data['price'],stoplimit='0',sl=fixture['S0'] if n==0 else '0',tp='0',deviation=0,type=(0 if side=='LONG' else 1) if n==0 else (1 if side=='LONG' else 0),type_filling=0,type_time=0,expiration=0,comment='CONFORMANCE',position=0 if n==0 else 701,position_by=0)
    check=dict(run_id=b['run_id'],group_id=b['group_id'],request=r,request_hash=v.digest(json.dumps(r,separators=(',',':')).encode()),bool_return=True,retcode=0,error=0,comment='Done',balance='1000',equity='1000',profit='0',margin='1',margin_free='999',margin_level='1000',time_msc=1000+n*1000,context_hash=self.ctx.control_hash)
    rows.append(dict(role='ORDER_CHECK',payload=json.dumps(check,separators=(',',':'))));n+=1
   if role=='STAGE13_PREPARED':
    parts=row['payload'].split('|');parts[7]=DOMAIN;row['payload']='|'.join(parts);eventhash=v.digest(row['payload'])
   if role=='STAGE13_COMMITTED':
    data=v.parse_json(row['payload'].encode());data['event_hash']=eventhash;row['payload']=v.json_bytes(data).decode()
   rows.append(row)
  capture['records']=rows;self.capture=capture;self.capture_ref=store('cf-capture.json',capture)
  self.launch_ref=self.launch_receipt();self.ctx=self.ctx.with_launch_record(self.launch_ref,loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root)
  return self.ctx.build(self.capture_ref)

 def test_long_and_short_bootstrap(self):
  for side in ('LONG','SHORT'):
   with self.subTest(side=side):
    files=self.setup_fixture(side);s=v.read_package(files['sidecar.evidence'])
    self.assertEqual(s['original']['side'],side);self.assertEqual(s['binding']['evidence_scope'],SCOPE)
    self.assertNotIn('freeze_receipt_hash',s['binding']);self.assertNotIn('root_hash',s['binding'])

 def test_no_successor_acceptance_without_context(self):
  files=self.setup_fixture();s=v.read_package(files['sidecar.evidence'])
  with self.assertRaises(ValueError):v.validate_package(files['sidecar.evidence'],s['binding'],self.ctx.profile)

 def test_pinned_control_cotampering_rejects(self):
  self.setup_fixture();old=self.ctx.control_hash
  self.control['domain']='CAND-ETH-ST-002';self.store('cf-control.json',self.control)
  with self.assertRaises(ValueError):ConformanceControl(self.dir,'cf-control.json',old)

 def test_successor_receipt_cannot_select_fixture(self):
  self.setup_fixture();self.control['domain']='SUCCESSOR_FREEZE';p=self.store('cf-control.json',self.control)
  with self.assertRaises(ValueError):ConformanceControl(self.dir,p['path'],p['sha256'])

 def test_fixture_payload_mismatch(self):
  self.setup_fixture();row=self.capture['records'][0];data=v.parse_json(row['payload'].encode());data['V0']='4';row['payload']=v.json_bytes(data).decode()
  with self.assertRaises(ValueError):self.ctx.build(self.store('bad.json',self.capture))

 def test_missing_or_rejected_order_check(self):
  self.setup_fixture();original=copy.deepcopy(self.capture)
  for bad in ('missing','false','retcode','foreign'):
   self.capture=copy.deepcopy(original)
   if bad=='missing':self.capture['records']=[r for r in self.capture['records'] if r['role']!='ORDER_CHECK']
   else:
    row=next(r for r in self.capture['records'] if r['role']=='ORDER_CHECK');c=json.loads(row['payload'])
    c[{'false':'bool_return','retcode':'retcode','foreign':'group_id'}[bad]]={'false':False,'retcode':10009,'foreign':'FOREIGN'}[bad];row['payload']=json.dumps(c,separators=(',',':'))
   with self.assertRaises(ValueError):self.ctx.build(self.store('bad.json',self.capture))

 def test_accepted_check_does_not_prove_fill(self):
  self.setup_fixture();self.capture['records']=[r for r in self.capture['records'] if r['role']!='DEAL_ADD']
  with self.assertRaises(ValueError):self.ctx.build(self.store('bad.json',self.capture))

 def test_long_cannot_claim_short(self):
  self.setup_fixture('SHORT');row=next(r for r in self.capture['records'] if r['role']=='DEAL_ADD');p=row['payload'].split('|');p[5]='0';row['payload']='|'.join(p)
  with self.assertRaises(ValueError):self.ctx.build(self.store('bad.json',self.capture))


 def launch_receipt(self):
  c=self.ctx;b=c.binding();inputs=c.prepare_inputs()
  record=dict(domain=DOMAIN,fixture_id=c.fixture['fixture_id'],run_id=c.fixture['run_id'],control_hash=c.control_hash,
              source_hash=b['source_manifest_hash'],executable_hash=b['executable_hash'],profile_hash=b['tester_profile_hash'],
              terminal_build=6140,agent_build=6140,compiler_build=6140,account_fingerprint='A'*64,
              mql_tester=True,dll_disabled=True,local_only=True,process_exited=True)
  name=c.fixture['fixture_id']+'.set';data=dict(set=inputs['set_bytes'],ini=('[Tester]\nExpertParameters='+name+'\n'+'\n'.join(k+'='+value for k,value in inputs['required_ini'].items())).encode(),manifest=inputs['manifest'],calendar=inputs['calendar'])
  for key,raw in data.items():record[key+'_file']=self.store('launch-'+key,raw);record['consumed_'+key+'_hash']=v.digest(raw)
  root=self.dir/'terminal-root';iid='A'*32;data_dir=root/iid;data_dir.mkdir(parents=True,exist_ok=True);exe=self.dir/'terminal64.exe';exe.write_bytes(b'TERMINAL');(data_dir/'origin.txt').write_text(str(exe.parent));self.instance=resolve_terminal_instance(exe,iid,terminal_root=root)
  self.expected_root=self.dir/'expected-terminal-pins';self.expected_root.mkdir(exist_ok=True)
  expected=dict(kind='CONFORMANCE_EXPECTED_TERMINAL_INSTANCE_V1',fixture_id=c.fixture['fixture_id'],run_id=c.fixture['run_id'],terminal_instance_id=self.instance['instance_id'],terminal_executable=self.instance['terminal_executable'],terminal_executable_sha256=self.instance['terminal_executable_sha256'],terminal_data_dir=self.instance['terminal_data_dir'],origin_sha256=self.instance['origin_sha256'],tester_journal_dir=self.instance['tester_journal_dir'],terminal_root=self.instance['terminal_root'],terminal_build=6140)
  expected_raw=v.json_bytes(expected);(self.expected_root/'expected.json').write_bytes(expected_raw);record['expected_terminal_instance']=dict(path='expected.json',byte_length=len(expected_raw),sha256=v.digest(expected_raw))
  receipt=stage_expert_parameters(c,self.instance,data['ini']);self.loader_root=self.dir/'loader-pins';self.loader_root.mkdir(exist_ok=True);raw=v.json_bytes(receipt);(self.loader_root/'binding.json').write_bytes(raw);record['loader_binding_receipt']=dict(path='binding.json',byte_length=len(raw),sha256=v.digest(raw))
  return self.store('launch-record.json',record)

 def test_independent_seal_and_native_reconstruction(self):
  files=self.setup_fixture('SHORT');scope=v.parse_json(files['archive.json'])['binding']
  seal=dict(kind='INDEPENDENT_FINAL_ARCHIVE_SEAL',authority='COMPLETED_PACKAGE_INTEGRITY_ONLY',binding=scope,archive_sha256=v.digest(files['archive.json']))
  ref=self.store('seal.json',seal);launch=self.launch_receipt()
  result=self.ctx.verify(files,ref,self.capture_ref,launch_record_reference=launch,loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root)
  self.assertFalse(result['successor_eligible']);self.assertEqual(result['evidence_scope'],SCOPE)
  for name in files:
   with self.subTest(artifact=name):
    bad=dict(files);bad[name]+=b'X'
    with self.assertRaises(ValueError):self.ctx.verify(bad,ref,self.capture_ref,launch_record_reference=launch,loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root)

 def test_fixture_inputs_are_exact_and_immutable(self):
  self.setup_fixture();a=self.ctx.prepare_inputs();self.assertEqual(v.digest(a['manifest']),a['set_values']['InpManifestFileSha256'])
  self.assertEqual(a['set_values']['InpGate'],'0');self.assertEqual(a['set_values']['InpRootSha256'],'')
  self.assertNotIn('SET_AT_EXECUTION',a['set_bytes'].decode())
  self.ctx.fixture['side']='SHORT'
  with self.assertRaises(ValueError):self.ctx.prepare_inputs()

 def test_tester_set_serialization_is_type_aware_and_non_optimizing(self):
  self.setup_fixture();inputs=self.ctx.prepare_inputs();text=inputs['set_bytes'].decode()
  plain='\r\n'.join(k+'='+v for k,v in inputs['set_values'].items())+'\r\n'
  self.assertNotEqual(text,plain)
  self.assertEqual(inputs['set_bytes'],serialize_tester_set(inputs['set_values']))
  for key,value in inputs['set_values'].items():
   line=next(x for x in text.splitlines() if x.startswith(key+'='))
   if SET_INPUT_TYPES[key]=='string':self.assertEqual(line,key+'='+value)
   else:self.assertEqual(line,key+'='+value+'||'+value+'||1||'+value+'||N')
  self.assertNotIn('||Y',text)

 def test_closed_type_map_matches_mql_conformance_declarations(self):
  import re
  source=(Path(__file__).resolve().parents[1]/'MQL5/Experts/KingEA/GuardedResearchTester.mq5').read_text()
  declared={name:kind for kind,name in re.findall(r'^input\s+(string|int|bool)\s+(Inp\w+)\s*=',source,re.M)}
  self.setup_fixture();emitted=set(self.ctx.prepare_inputs()['set_values'])
  self.assertEqual(set(SET_INPUT_TYPES),emitted)
  self.assertEqual({key:declared.get(key) for key in emitted},SET_INPUT_TYPES)
  self.assertTrue(all(key in declared for key in emitted))

 def test_expert_parameters_loader_binding_is_exact_and_instance_bound(self):
  self.setup_fixture();root=self.dir/'terminal-root';iid='B'*32;data=root/iid;data.mkdir(parents=True)
  exe=self.dir/'terminal64-b.exe';exe.write_bytes(b'TERMINAL');(data/'origin.txt').write_text(str(exe.parent))
  instance=resolve_terminal_instance(exe,iid,terminal_root=root)
  name=self.ctx.fixture['fixture_id']+'.set';ini=('[Tester]\r\nExpertParameters='+name+'\r\n').encode()
  receipt=stage_expert_parameters(self.ctx,instance,ini)
  target=data/'MQL5'/'Profiles'/'Tester'/name
  self.assertEqual(target.read_bytes(),self.ctx.prepare_inputs()['set_bytes'])
  expected_root=self.dir/'expert-expected';expected_root.mkdir();expected=dict(kind='CONFORMANCE_EXPECTED_TERMINAL_INSTANCE_V1',fixture_id=self.ctx.fixture['fixture_id'],run_id=self.ctx.fixture['run_id'],terminal_instance_id=instance['instance_id'],terminal_executable=instance['terminal_executable'],terminal_executable_sha256=instance['terminal_executable_sha256'],terminal_data_dir=instance['terminal_data_dir'],origin_sha256=instance['origin_sha256'],tester_journal_dir=instance['tester_journal_dir'],terminal_root=instance['terminal_root'],terminal_build=6140);expected_raw=v.json_bytes(expected);(expected_root/'expected.json').write_bytes(expected_raw);expected_ref=dict(path='expected.json',byte_length=len(expected_raw),sha256=v.digest(expected_raw))
  validate_loader_binding(self.ctx,receipt,expected_ini_raw=ini,expected_terminal_reference=expected_ref,expected_terminal_root=expected_root)
  target.write_bytes(target.read_bytes()+b'X')
  self.assertNotEqual(v.digest(target.read_bytes()),receipt['loader_set_sha256'])
  with self.assertRaises(ValueError):stage_expert_parameters(self.ctx,instance,b'[Tester]\r\nExpertParameters=wrong.set\r\n')
  with self.assertRaises(ValueError):resolve_terminal_instance(exe,'C'*32,terminal_root=root)

 def test_loader_receipt_and_terminal_identity_fail_closed(self):
  self.setup_fixture();record=v.parse_json((self.dir/self.launch_ref['path']).read_bytes())
  ref=record['loader_binding_receipt'];receipt=read_pinned_loader_binding(self.loader_root,ref)
  ini=self.ctx._read(record['ini_file']);target=Path(self.instance['terminal_data_dir'])/'MQL5'/'Profiles'/'Tester'/(self.ctx.fixture['fixture_id']+'.set')
  self.assertEqual(receipt['fixture_id'],self.ctx.fixture['fixture_id'])
  expected_ref=record['expected_terminal_instance'];self.assertEqual(read_pinned_expected_terminal_instance(self.expected_root,expected_ref)['terminal_instance_id'],self.instance['instance_id'])
  with self.assertRaises(ValueError):validate_loader_binding(self.ctx,receipt,expected_ini_raw=ini,expected_terminal_reference=self.instance,expected_terminal_root=self.expected_root)
  with self.assertRaises(ValueError):read_pinned_expected_terminal_instance(self.expected_root,dict(expected_ref,sha256='0'*64))
  expected_path=self.expected_root/expected_ref['path'];expected_raw=expected_path.read_bytes();expected_path.write_bytes(expected_raw+b'X')
  with self.assertRaises(ValueError):read_pinned_expected_terminal_instance(self.expected_root,expected_ref)
  expected_path.write_bytes(expected_raw)
  (self.loader_root/ref['path']).write_bytes(v.json_bytes(dict(receipt,fixture_id='FOREIGN')))
  with self.assertRaises(ValueError):read_pinned_loader_binding(self.loader_root,ref)
  (self.loader_root/ref['path']).write_bytes(v.json_bytes(receipt))
  bad=dict(record,loader_binding_receipt=receipt)
  with self.assertRaises(ValueError):self.ctx.verify_launch_record(self.store('inline-loader.json',bad),loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root)
  origin=Path(self.instance['terminal_data_dir'])/'origin.txt';original_origin=origin.read_bytes()
  origin.write_text(str(self.dir/'foreign-terminal-root'))
  with self.assertRaises(ValueError):validate_loader_binding(self.ctx,receipt,expected_ini_raw=ini,expected_terminal_reference=record['expected_terminal_instance'],expected_terminal_root=self.expected_root)
  origin.write_bytes(original_origin)
  exe=Path(self.instance['terminal_executable']);original_exe=exe.read_bytes();exe.write_bytes(original_exe+b'X')
  with self.assertRaises(ValueError):validate_loader_binding(self.ctx,receipt,expected_ini_raw=ini,expected_terminal_reference=record['expected_terminal_instance'],expected_terminal_root=self.expected_root)
  exe.write_bytes(original_exe)
  target.write_bytes(target.read_bytes()+b'X')
  with self.assertRaises(ValueError):validate_loader_binding(self.ctx,receipt,expected_ini_raw=ini,expected_terminal_reference=record['expected_terminal_instance'],expected_terminal_root=self.expected_root)
  target.write_bytes(self.ctx.prepare_inputs()['set_bytes'])
  forged=dict(receipt,loader_absolute_path=str(self.dir/'foreign.set'))
  with self.assertRaises(ValueError):validate_loader_binding(self.ctx,forged,expected_ini_raw=ini,expected_terminal_reference=record['expected_terminal_instance'],expected_terminal_root=self.expected_root)
  root=self.dir/'foreign-root';iid='D'*32;data=root/iid;data.mkdir(parents=True);foreign_exe=self.dir/'foreign-terminal.exe';foreign_exe.write_bytes(b'FOREIGN');(data/'origin.txt').write_text(str(foreign_exe.parent))
  foreign=resolve_terminal_instance(foreign_exe,iid,terminal_root=root)
  foreign_receipt=dict(receipt,terminal_instance_id=foreign['instance_id'],terminal_executable=foreign['terminal_executable'],terminal_executable_sha256=foreign['terminal_executable_sha256'],terminal_data_dir=foreign['terminal_data_dir'],origin_sha256=foreign['origin_sha256'],loader_absolute_path=str(data/'MQL5'/'Profiles'/'Tester'/(self.ctx.fixture['fixture_id']+'.set')))
  with self.assertRaises(ValueError):validate_loader_binding(self.ctx,foreign_receipt,expected_ini_raw=ini,expected_terminal_reference=record['expected_terminal_instance'],expected_terminal_root=self.expected_root)

 def test_action_schedule_and_interval_enforced(self):
  self.setup_fixture();original=copy.deepcopy(self.capture)
  for timestamp in (999,100000,2500):
   self.capture=copy.deepcopy(original);row=next(r for r in self.capture['records'] if r['role']=='ORDER_CHECK');c=json.loads(row['payload']);c['time_msc']=timestamp;row['payload']=json.dumps(c,separators=(',',':'))
   with self.assertRaises(ValueError):self.ctx.build(self.store('bad.json',self.capture))

 def test_payload_profile_cannot_authorize_short(self):
  self.setup_fixture();p=copy.deepcopy(self.ctx.profile);p['side']='SHORT'
  with self.assertRaises(ValueError):v.validate_profile(p,'SHORT')
  with self.assertRaises(ValueError):v.validate_profile(p,'SHORT',conformance={'domain':DOMAIN})

 def test_consumed_set_ini_and_profile_loss(self):
  self.setup_fixture();ref=self.launch_receipt();record=v.parse_json((self.dir/ref['path']).read_bytes())
  for field,value in [('dll_disabled',False),('local_only',False),('process_exited',False),('consumed_set_hash','0'*64),('control_hash','0'*64)]:
   bad=dict(record);bad[field]=value
   with self.assertRaises(ValueError):self.ctx.verify_launch_record(self.store('bad-launch.json',bad),loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root)

 def test_wrong_local_scope_and_hash_reject(self):
  self.setup_fixture()
  self.control['local_inputs']['manifest_path']='Common/manifest.json';pin=self.store('wrong-control.json',self.control)
  with self.assertRaises(ValueError):ConformanceControl(self.dir,pin['path'],pin['sha256'])


 def test_conformance_archive_rejected_by_actual_successor_ingestion(self):
  from research_pipeline.successor_evidence import PinnedControlContext,SuccessorEvidenceError
  from research_pipeline.stage14 import ResearchRunCoordinator
  files=self.setup_fixture();f=self.successor
  scope=v.parse_json(files['archive.json'])['binding']
  seal=dict(kind='INDEPENDENT_FINAL_ARCHIVE_SEAL',authority='COMPLETED_PACKAGE_INTEGRITY_ONLY',binding=scope,archive_sha256=v.digest(files['archive.json']))
  f.control['completed_archives'][f.manifest['manifest_sha256']+':0']=[self.store('substituted-seal.json',seal)]
  f.pin=f.store('control.json',f.control)['sha256']
  event=next(raw.decode() for name,raw in files.items() if name.startswith('support/stage13_event.'))
  f.frame.update(native_cost_packages=[v.encode_archive(files)],boundary_finalization_count=0,stage13_close_frames=[event])
  before={p:p.read_bytes() for p in self.dir.rglob('*') if p.is_file()};spool=self.dir/'spool-forbidden'
  with self.assertRaises(SuccessorEvidenceError) as caught:
   ResearchRunCoordinator(control_context=PinnedControlContext(self.dir,f.pin)).append_frame(spool,f.manifest,dict(frame_id='0',payload=f.frame))
  self.assertEqual(str(caught.exception),'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED')
  self.assertEqual(caught.exception.stage,'ingestion');self.assertFalse(spool.exists())
  self.assertEqual(before,{p:p.read_bytes() for p in self.dir.rglob('*') if p.is_file()})


 def test_order_check_malformed_request_and_context(self):
  self.setup_fixture();original=copy.deepcopy(self.capture)
  for field,value in [('context_hash','0'*64),('request_hash','0'*64),('retcode',10018),('bool_return',False)]:
   self.capture=copy.deepcopy(original);row=next(r for r in self.capture['records'] if r['role']=='ORDER_CHECK');check=json.loads(row['payload']);check[field]=value;row['payload']=json.dumps(check,separators=(',',':'))
   with self.assertRaises(ValueError):self.ctx.build(self.store('bad.json',self.capture))

 def test_conformance_requires_independent_launch_binding(self):
  self.setup_fixture();unbound=ConformanceControl(self.dir,'cf-control.json',self.ctx.control_hash)
  with self.assertRaisesRegex(ValueError,'INDEPENDENT_LAUNCH_RECORD_REQUIRED'):unbound.build(self.capture_ref)

 def test_bound_artifact_mutation_cannot_redefine_authority(self):
  self.setup_fixture();self.ctx.authorities['EXECUTABLE']+=b'changed'
  with self.assertRaises(ValueError):self.ctx.build(self.capture_ref)


 def test_launch_receipt_hash_uses_exact_bytes(self):
  self.setup_fixture();record=json.loads((self.dir/self.launch_ref['path']).read_bytes())
  exact=json.dumps(record,indent=4).encode();ref=self.store('pretty-launch.json',exact)
  self.ctx=self.ctx.with_launch_record(ref,loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root);files=self.ctx.build(self.capture_ref)
  scope=v.parse_json(files['archive.json'])['binding']
  seal=dict(kind='INDEPENDENT_FINAL_ARCHIVE_SEAL',authority='COMPLETED_PACKAGE_INTEGRITY_ONLY',binding=scope,archive_sha256=v.digest(files['archive.json']))
  result=self.ctx.verify(files,self.store('pretty-seal.json',seal),self.capture_ref,launch_record_reference=ref,loader_binding_root=self.loader_root,expected_terminal_root=self.expected_root)
  self.assertEqual(result['launch_record_hash'],v.digest(exact))
