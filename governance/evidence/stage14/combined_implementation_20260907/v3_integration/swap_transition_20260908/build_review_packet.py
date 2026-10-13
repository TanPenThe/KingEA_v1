from pathlib import Path
import json,hashlib,difflib,ast,re
root=Path.cwd();base=root/'governance/evidence/stage14/combined_implementation_20260907';out=base/'v3_integration/swap_transition_20260908'
def h(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def write(name,data): (out/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
pre=json.loads((base/'FINAL_PRE_TOOLING.json').read_text());old=json.loads((base/'v3_integration/interval_authority_blocker/POST_TOOLING.json').read_text())
protected=[]
for e in old['protected']:
 p=root/e['path'];protected.append(dict(path=e['path'],before=e['original_pre_sha256'],after=h(p),equal=h(p)==e['original_pre_sha256']))
assert len(protected)==190 and all(x['equal'] for x in protected)
assert h(root/'research_pipeline/stage14.py')=='DBD8039666FE9285932118A755369229EB65B3E7163A167C00EE4A41BF1D844E'
paths={e['path'].replace('\\','/') for e in pre['files']}
paths.update(e['path'].replace('\\','/') for e in json.loads((out/'FINAL_PRE_TOOLING.json').read_text())['files'])
paths.update(str(p.relative_to(root)).replace('\\','/') for p in (root/'tests').glob('*.py'))
paths.update(['MQL5/Scripts/KingEA/TestCombinedLifecycle.mq5','MQL5/Scripts/KingEA/TestSwapTransition.mq5','research_pipeline/decision_a_evidence.py','research_pipeline/successor_evidence.py'])
paths.update('MQL5/Include/KingEA/'+n for n in ['DecisionALifecycle.mqh','DecisionADealAdapter.mqh','DecisionAStaticStop.mqh'])
orig={e['path'].replace('\\','/'):e for e in pre['files']};inventory=[];changed=[];diff=[];amend=[]
for name in sorted(paths):
 p=root/name
 if not p.is_file():continue
 row=dict(path=name,sha256=h(p),size=p.stat().st_size,original_sha256=orig.get(name,{}).get('sha256'))
 row['changed_or_new']=row['sha256']!=row['original_sha256'];inventory.append(row)
 if row['changed_or_new']:
  changed.append(row)
  if p.suffix.lower() in {'.py','.mq5','.mqh','.ps1','.json','.md'}:
   before=base/'before'/name
   a=before.read_bytes().decode('utf-8-sig').splitlines(True) if before.exists() else []
   b=p.read_bytes().decode('utf-8-sig').splitlines(True)
   diff.extend(difflib.unified_diff(a,b,fromfile='before/'+name if before.exists() else '/dev/null',tofile='after/'+name))
 before=out/'before'/name
 if before.exists() and h(before)!=h(p) and p.suffix.lower() in {'.py','.mq5','.mqh'}:
  amend.extend(difflib.unified_diff(before.read_bytes().decode('utf-8-sig').splitlines(True),p.read_bytes().decode('utf-8-sig').splitlines(True),fromfile='amendment-before/'+name,tofile='after/'+name))
(out/'COMPLETE_IMPLEMENTATION.diff').write_text(''.join(diff),encoding='utf-8')
(out/'SWAP_TRANSITION_CONTINUATION.diff').write_text(''.join(amend),encoding='utf-8')
write('POST_TOOLING.json',dict(status='IMPLEMENTATION_PENDING_INDEPENDENT_REVIEW',source_implementation_materially_complete=True,successor_freeze='NOT_AUTHORIZED',B2='LOCKED',baselines=[dict(path=str(p),sha256=h(p)) for p in [base/'FINAL_PRE_TOOLING.json',base/'v3_integration/FINAL_PRE_TOOLING.json',out/'FINAL_PRE_TOOLING.json']],protected_count=len(protected),protected_all_equal=True,protected=protected,changed_or_new=changed,current_inventory=inventory))
compiler=Path('C:/Program Files/MetaTrader 5/metaeditor64.exe');builds=[]
for name,source in [('GuardedResearchTester','MQL5/Experts/KingEA/GuardedResearchTester.mq5'),('TestCombinedLifecycle','MQL5/Scripts/KingEA/TestCombinedLifecycle.mq5'),('TestSwapTransition','MQL5/Scripts/KingEA/TestSwapTransition.mq5')]:
 d=out/'compile_final';copy=d/(name+'.mq5');log=d/(name+'.log');ex5=d/(name+'.ex5');assert h(copy)==h(root/source);assert '0 errors, 0 warnings' in log.read_text(encoding='utf-16')
 builds.append(dict(source=source,source_sha256=h(root/source),copy=str(copy),copy_equal=True,log=str(log),log_sha256=h(log),ex5=str(ex5),ex5_sha256=h(ex5),ex5_bytes=ex5.stat().st_size,result='0 errors, 0 warnings',runtime_executed=False,stale_control='Source copied into new empty compile_final directory before compilation; EX5 generated there, never reused from production directories.',command=[str(compiler),'/compile:'+str(copy),'/inc:'+str(root/'MQL5'),'/log:'+str(log)]))
write('COMPILE_PROVENANCE.json',dict(compiler=str(compiler),compiler_build=6140,compiler_sha256=h(compiler),builds=builds,include_inventory=[x for x in inventory if x['path'].startswith('MQL5/Include/')],runtime='NOT_EXECUTED'))
log=(out/'PYTHON_SUITE_RELEASE.log').read_text(encoding='utf-8-sig');assert 'Ran 315 tests' in log and '\nOK\n' in log
cases=[]
for p in sorted((root/'tests').glob('test*.py')):
 tree=ast.parse(p.read_text(encoding='utf-8-sig'))
 for cls in tree.body:
  if isinstance(cls,ast.ClassDef):
   for f in cls.body:
    if isinstance(f,ast.FunctionDef) and f.name.startswith('test'):
     cases.append(dict(module=p.stem,class_name=cls.name,test=f.name,line=f.lineno))
write('TEST_RESULTS.json',dict(command='python -m unittest discover -s tests -v',result='PASS',count=315,log='PYTHON_SUITE_RELEASE.log',log_sha256=h(out/'PYTHON_SUITE_RELEASE.log'),evidence_kind='SYNTHETIC_DETERMINISTIC_PYTHON; MQL COMPILE ONLY',runtime_executed=False,cases=cases))
print('protected',len(protected),'changed/new',len(changed),'inventory',len(inventory),'tests',315)
