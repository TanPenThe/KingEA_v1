"""Bounded non-Candidate accounting conformance; never a research launcher."""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADOPTION = ROOT / 'governance/evidence/stage14/GOVERNANCE_ADOPTION_NATIVE_COST_V2_BOUNDARY_MTM_V4_20260905.json'
FILES = ['Experts/KingEA/NativeCostConformance.mq5', 'Include/KingEA/NativeCostEvidence.mqh',
         'Include/KingEA/NativeCostMetadataAdapter.mqh', 'Include/KingEA/NativeCostContractTests.mqh',
         'Include/KingEA/AccountingEvents.mqh']

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()

def stamp():
    return datetime.now(timezone.utc).isoformat()

def write(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open('x', encoding='utf-8', newline='\n') as f:
        f.write(data if isinstance(data, str) else json.dumps(data, indent=2, sort_keys=True)+'\n')

def metadata(p):
    out = subprocess.run(['powershell.exe','-NoProfile','-Command',
        "(Get-Item -LiteralPath '"+str(p).replace("'","''")+"').VersionInfo.FileVersion"],
        check=True, capture_output=True, text=True).stdout.strip()
    return {'path':str(p),'file_version':out,'build':int(out.split('.')[-1]),'sha256':sha(p)}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--run-id',required=True)
    parser.add_argument('--metadata-runtime',action='store_true')
    parser.add_argument('--ioc-only',action='store_true')
    parser.add_argument('--fok-integration',action='store_true')
    parser.add_argument('--compile-production-only',action='store_true')
    args=parser.parse_args()
    prefix='NC-FOK-' if args.fok_integration else ('NC-IOC-' if args.ioc_only else 'NC-COST-')
    if not args.run_id.startswith(prefix) or any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-' for c in args.run_id):
        raise ValueError('NON_CANDIDATE_RUN_ID_REQUIRED')
    assert not (args.ioc_only and args.metadata_runtime), 'CONFORMANCE_MODES_EXCLUSIVE'
    assert not (args.fok_integration and (args.ioc_only or args.metadata_runtime)), 'CONFORMANCE_MODES_EXCLUSIVE'
    assert not args.compile_production_only or args.fok_integration, 'COMPILE_ONLY_SCOPE_REQUIRED'
    files=(['Experts/KingEA/IOCExecutionConformance.mq5','Include/KingEA/AccountingEvents.mqh']
           if args.ioc_only else FILES)
    stem='IOCExecutionConformance' if args.ioc_only else 'NativeCostConformance'
    scope=ROOT/'governance/evidence/stage14/ioc_conformance_20260905/OWNER_SCOPE.json'
    if args.ioc_only:
        assert json.loads(scope.read_text())['authorization']=='BOUNDED_NON_CANDIDATE_IOC_EXECUTION_CONFORMANCE_ONLY'
    if args.fok_integration:
        files=['Experts/KingEA/FOKInfrastructureConformance.mq5','Include/KingEA/AccountingEvents.mqh',
               'Include/KingEA/NativeCostEvidence.mqh','Include/KingEA/NativeCostMetadataAdapter.mqh',
               'Include/KingEA/NativeCostIntegration.mqh','Include/KingEA/NativeCostIntegrationTests.mqh',
               'Include/KingEA/NativeCostContractTests.mqh']
        stem='FOKInfrastructureConformance'
        scope=ROOT/'governance/evidence/stage14/fok_infrastructure_20260905/OWNER_CLOSURE_AND_SCOPE.json'
        assert json.loads(scope.read_text())['scope']=='IMPLEMENTATION_AND_NON_CANDIDATE_FOK_CONFORMANCE_ONLY'
        if args.compile_production_only:
            files=['Experts/KingEA/GuardedResearchTester.mq5']+[
                p.relative_to(ROOT/'MQL5').as_posix() for p in sorted((ROOT/'MQL5/Include/KingEA').glob('*.mqh'))]
    approval=json.loads(ADOPTION.read_text())
    assert approval['authorization']=='IMPLEMENTATION_AND_NON_CANDIDATE_CONFORMANCE_ONLY' and approval['b2']=='LOCKED'
    for a in approval['adopted_artifacts']:
        assert sha(ROOT/a['path'])==a['sha256'], 'ADOPTED_HASH_MISMATCH'
    tasks=subprocess.run(['tasklist','/FO','CSV','/NH'],check=True,capture_output=True,text=True).stdout.lower()
    assert 'terminal64.exe' not in tasks and 'metatester64.exe' not in tasks, 'TERMINAL_ALREADY_RUNNING'
    folder='ioc_conformance_20260905' if args.ioc_only else 'native_cost_mtm_20260905'
    if args.fok_integration: folder='fok_infrastructure_20260905'
    out=ROOT/'governance/evidence/stage14'/folder/args.run_id
    assert not out.exists(), 'APPEND_ONLY_RUN_EXISTS'
    out.mkdir(parents=True)
    terminal=Path(r'C:\Program Files\MetaTrader 5\terminal64.exe')
    editor=terminal.with_name('metaeditor64.exe')
    data=Path(r'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075')
    common=data.parent/('Common/Files/KingEA/'+stem)/args.run_id
    assert not common.exists(), 'COMMON_EVIDENCE_EXISTS'
    sources=[]
    for rel in files:
        src=ROOT/'MQL5'/rel; dest=out/'build/MQL5'/rel
        dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(src,dest)
        sources.append({'path':rel,'size':src.stat().st_size,'sha256':sha(src)})
        assert sha(src)==sha(dest)
    write(out/'PRE_TOOLING.json',{'sources':sources,'adoption_sha256':sha(ADOPTION),
        'launcher_sha256':sha(__file__),'b2':'LOCKED','created_at':stamp()})
    if args.ioc_only:
        shutil.copyfile(scope,out/'OWNER_SCOPE.json')
        shutil.copyfile(ROOT/'MQL5/Experts/KingEA/GuardedResearchTester.mq5',out/'PRODUCTION_REQUEST_REFERENCE.mq5')
    if args.fok_integration:
        shutil.copyfile(scope,out/'OWNER_SCOPE.json')
    source=out/'build/MQL5'/files[0]; ex5=source.with_suffix('.ex5'); log=out/'compile.log'
    assert not ex5.exists(), 'STALE_EX5'
    compile_command=[str(editor),'/compile:'+str(source),'/include:'+str(out/'build/MQL5'),'/log:'+str(log)]
    started=stamp(); p=subprocess.run(compile_command,timeout=60); ended=stamp()
    compile_text=log.read_text(encoding='utf-16',errors='replace')
    assert ex5.exists() and 'Result: 0 errors, 0 warnings' in compile_text, 'COMPILE_FAILED'
    for s in sources:
        assert sha(ROOT/'MQL5'/s['path'])==s['sha256']==sha(out/'build/MQL5'/s['path']), 'SOURCE_CHANGED'
    write(out/'BUILD_BINDING.json',{'source_manifest_sha256':sha(out/'PRE_TOOLING.json'),
        'compiler':metadata(editor),'command':compile_command,'started':started,'ended':ended,
        'return_code':p.returncode,'log_sha256':sha(log),'produced_ex5_sha256':sha(ex5),'preexisting_ex5':False})
    if args.compile_production_only:
        write(out/'COMPILE_ONLY.json',{'candidate_executed':False,'terminal_launched':False,
                                      'deployed':False,'b2':'LOCKED','status':'PASS'})
        print(json.dumps({'status':'PASS','scope':'COMPILE_ONLY_NO_DEPLOYMENT_NO_EXECUTION','evidence':str(out)}))
        return 0
    deployed=data/'MQL5/Experts/KingEA'/(stem+'_'+args.run_id+'.ex5')
    deployed.parent.mkdir(parents=True,exist_ok=True)
    assert not deployed.exists(), 'DEPLOYED_EX5_ALREADY_EXISTS'
    shutil.copyfile(ex5,deployed)
    setname=stem+'_'+args.run_id+'.set'
    settings='InpRunId='+args.run_id+'\nInpOutput=KingEA\\'+stem+'\\'+args.run_id+'\n'
    if args.ioc_only or args.fok_integration:
        registered=json.loads((ROOT/'governance/drills/DRILL-DEMO-001.json').read_text())
        settings+='InpExpectedBuild='+str(metadata(terminal)['build'])+'\nInpExpectedFingerprint='+registered['AccountFingerprint']+'\n'
    else:
        settings+='InpRuntimeMetadata='+('true' if args.metadata_runtime else 'false')+'\n'
    write(out/setname,settings)
    target_set=data/'MQL5/Profiles/Tester'/setname
    target_set.parent.mkdir(parents=True,exist_ok=True)
    assert not target_set.exists(); shutil.copyfile(out/setname,target_set)
    ini=out/'tester.ini'
    write(ini,'[Tester]\nExpert=KingEA\\'+deployed.name+'\nExpertParameters='+setname+
        '\nSymbol=ETHUSD.s\nPeriod=M30\nModel=4\nOptimization=0\nUseLocal=1\nUseRemote=0\nUseCloud=0\nExecutionMode=20\nDeposit=1000\nCurrency=USD\nFromDate=2023.06.01\nToDate=2023.06.02\nShutdownTerminal=1\n')
    authorization={'run_id':args.run_id,'adoption_sha256':sha(ADOPTION),'candidate_execution':False,
        'scope':'NON_CANDIDATE_IOC_CONFORMANCE' if args.ioc_only else 'NON_CANDIDATE_ACCOUNTING_CONFORMANCE',
        'simulated_entry_limit':1 if (args.metadata_runtime or args.ioc_only or args.fok_integration) else 0,
        'budget':0,'oos':False,'holdout':False,'b2':'LOCKED'}
    if args.ioc_only: authorization['owner_scope_sha256']=sha(out/'OWNER_SCOPE.json')
    if args.fok_integration:
        authorization.update(scope='NON_CANDIDATE_FOK_INFRASTRUCTURE',owner_scope_sha256=sha(out/'OWNER_SCOPE.json'))
    write(out/'AUTHORIZATION.json',authorization)
    command=[str(terminal),'/config:'+str(ini)]
    manifest={'run_id':args.run_id,'source_sha256':sha(out/'PRE_TOOLING.json'),'ex5_sha256':sha(ex5),
        'set_sha256':sha(out/setname),'ini_sha256':sha(ini),'authorization_sha256':sha(out/'AUTHORIZATION.json'),
        'terminal':metadata(terminal),'command':command,'partition':'NON_CANDIDATE_2023_06_01_ONLY',
        'local_only':True,'b2':'LOCKED'}
    if args.ioc_only:
        manifest.update(type_filling='ORDER_FILLING_IOC',execution_mode=20,
                        production_request_reference_sha256=sha(out/'PRODUCTION_REQUEST_REFERENCE.mq5'))
    if args.fok_integration:
        manifest.update(type_filling='ORDER_FILLING_FOK',execution_mode=20,
                        candidate_id=None,evidence_contract='NATIVE_COST_BOUNDARY_V2')
    write(out/'MANIFEST.json',manifest)
    assert sha(deployed)==sha(ex5) and sha(target_set)==sha(out/setname)
    logroots=[data/'logs',data/'Tester/logs',Path(r'C:\Users\tpent\AppData\Roaming\MetaQuotes\Tester')]
    before={str(p):(p.stat().st_size,p.stat().st_mtime_ns) for r in logroots if r.exists() for p in r.rglob('*.log')}
    started=stamp(); child=subprocess.Popen(command)
    write(out/'LAUNCH_RECEIPT.json',{'run_id':args.run_id,'manifest_sha256':sha(out/'MANIFEST.json'),
        'command':command,'pid':child.pid,'started':started,'launcher_sha256':sha(__file__)})
    try:
        code=child.wait(timeout=180)
    except subprocess.TimeoutExpired:
        write(out/'TIMEOUT.json',{'pid':child.pid,'status':'FAIL_TIMEOUT_NO_AUTOMATIC_RETRY','b2':'LOCKED'})
        raise
    ended=stamp()
    retained=[]
    for r in logroots:
        if not r.exists(): continue
        for p in r.rglob('*.log'):
            if before.get(str(p))!=(p.stat().st_size,p.stat().st_mtime_ns):
                dest=out/'runtime'/('journal-'+str(len(retained))+'.log')
                dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(p,dest)
                retained.append({'source':str(p),'path':str(dest.relative_to(out)),'sha256':sha(dest)})
    if common.exists(): shutil.copytree(common,out/'runtime/harness')
    result_path=out/'runtime/harness/result.json'
    result=json.loads(result_path.read_text()) if result_path.exists() else {'status':'MISSING_RESULT'}
    write(out/'RUNTIME_RECEIPT.json',{'pid':child.pid,'started':started,'ended':ended,'exit_code':code,
        'journals':retained,'result':result,'b2':'LOCKED'})
    inventory=[{'path':str(p.relative_to(out)),'size':p.stat().st_size,'sha256':sha(p)} for p in sorted(out.rglob('*')) if p.is_file()]
    write(out/'SEALED_INVENTORY.json',{'files':inventory,'b2':'LOCKED'})
    print(json.dumps({'status':result['status'],'run':args.run_id,'evidence':str(out)}))
    return 0 if code==0 and result.get('status')=='PASS' else 1

if __name__=='__main__':
    raise SystemExit(main())
