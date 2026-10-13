"""Single bounded non-Candidate native semantics run; no production imports."""
import hashlib,json,shutil,subprocess,time,os
from pathlib import Path
from datetime import datetime,timezone
BASE=Path(__file__).resolve().parent
DATA=Path(r'C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075')
COMMON=DATA.parent/'Common/Files'
TERMINAL=Path(r'C:\Program Files\MetaTrader 5\terminal64.exe')
GIB=1024**3
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def stamp():return datetime.now(timezone.utc).isoformat()
def write(p,v):
    with Path(p).open('x',encoding='utf-8') as f:f.write(v if isinstance(v,str) else json.dumps(v,indent=2))
def main():
    rid='DS-NATIVE-LONG-01'
    out=BASE/rid;out.mkdir(exist_ok=False)
    tasks=subprocess.check_output(['tasklist','/FO','CSV','/NH'],text=True).lower()
    assert 'terminal64.exe' not in tasks and 'metatester64.exe' not in tasks,'EXISTING_TERMINAL_OR_AGENT'
    floor=30*GIB;free=shutil.disk_usage('C:\\').free
    assert free>=floor,'CAPACITY_FLOOR'
    ex5=BASE/'DecisionSNativeProof.ex5';assert ex5.exists()
    assert '0 errors, 0 warnings' in (BASE/'compile.log').read_text(encoding='utf-16')
    deployed=DATA/'MQL5/Experts/KingEA'/('DecisionSNativeProof_'+rid+'.ex5')
    assert not deployed.exists();shutil.copyfile(ex5,deployed)
    setname='DecisionSNativeProof_'+rid+'.set'
    output_rel='KingEA\\decision_s_native_20260907\\'+rid+'.txt'
    evidence=COMMON/Path(output_rel.replace('\\','/'))
    evidence.parent.mkdir(parents=True,exist_ok=True);assert not evidence.exists()
    settings='RunId='+rid+'\nOutput='+output_rel+'\nExpectedBuild=6140\nShortSide=false\nFixedVolume=0.10\nEntryAfter=2022.12.05 12:00\nReductionAfter=2022.12.07 12:00\nDeadline=2022.12.09 00:00\n'
    write(out/setname,settings)
    target_set=DATA/'MQL5/Profiles/Tester'/setname;target_set.parent.mkdir(parents=True,exist_ok=True)
    assert not target_set.exists();shutil.copyfile(out/setname,target_set)
    ini=out/'tester.ini'
    write(ini,'[Tester]\nExpert=KingEA\\'+deployed.name+'\nExpertParameters='+setname+'\nSymbol=ETHUSD.s\nPeriod=M30\nModel=4\nOptimization=0\nVisual=0\nUseLocal=1\nUseRemote=0\nUseCloud=0\nExecutionMode=20\nDeposit=10000\nCurrency=USD\nFromDate=2022.12.05\nToDate=2022.12.09\nShutdownTerminal=1\n[Experts]\nAllowDllImport=0\n')
    logroots=[DATA/'logs',DATA/'Tester/logs',Path(r'C:\Users\tpent\AppData\Roaming\MetaQuotes\Tester')]
    before={str(p):(p.stat().st_size,p.stat().st_mtime_ns) for r in logroots if r.exists() for p in r.rglob('*.log')}
    command=[str(TERMINAL),'/config:'+str(ini)]
    write(out/'PRE_LAUNCH.json',{'scope':'NON_CANDIDATE_DECISION_S_NATIVE_SEMANTICS_PROOF','at':stamp(),'free_bytes':free,'required_bytes':floor,'shortfall':0,'formula':'max(200*64MiB + 2*64MiB + 16GiB,30GiB)','incremental_disk_stop_bytes':8*GIB,'wall_timeout_seconds':600,'command':command,'source_sha256':sha(BASE/'DecisionSNativeProof.mq5'),'executable_sha256':sha(ex5),'deployed_sha256':sha(deployed),'compiler_sha256':sha(TERMINAL.with_name('metaeditor64.exe')),'terminal_sha256':sha(TERMINAL),'compiler_terminal_version':'5.0.0.6140','set_sha256':sha(target_set),'ini_sha256':sha(ini),'owner_directive_sha256':sha(BASE/'OWNER_DIRECTIVE.txt'),'b2':'LOCKED','candidate_execution':False,'optimization':False,'development_binding':'CAND-ETH-ST-001_DRAFT validation.rolling_folds[0].train: 2021-07-01 <= dates < 2023-01-01'})
    # Immediate recheck after all setup; this run is separately owner-authorized.
    free2=shutil.disk_usage('C:\\').free;assert free2>=floor
    write(out/'IMMEDIATE_SPACE_RECHECK.json',{'at':stamp(),'free_bytes':free2,'required_bytes':floor,'shortfall':max(0,floor-free2)})
    si=subprocess.STARTUPINFO();si.dwFlags|=subprocess.STARTF_USESHOWWINDOW;si.wShowWindow=0
    started=stamp();p=subprocess.Popen(command,startupinfo=si);write(out/'LAUNCH.json',{'pid':p.pid,'at':started,'command':command})
    start=time.monotonic();stopped=None
    while p.poll() is None:
        free_now=shutil.disk_usage('C:\\').free
        if time.monotonic()-start>600 or free_now<floor or free2-free_now>8*GIB:
            stopped='BOUNDED_RESOURCE_OR_TIME_STOP'
            subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],capture_output=True)
            break
        time.sleep(2)
    time.sleep(2)
    runtime=out/'runtime';runtime.mkdir()
    journals=[]
    for r in logroots:
        if not r.exists():continue
        for f in r.rglob('*.log'):
            if before.get(str(f))!=(f.stat().st_size,f.stat().st_mtime_ns):
                dest=runtime/('journal-'+str(len(journals))+'.log');shutil.copyfile(f,dest)
                journals.append({'source':str(f),'retained':dest.name,'sha256':sha(dest)})
    if evidence.exists():shutil.copyfile(evidence,runtime/'native.txt')
    write(out/'RUNTIME_RECEIPT.json',{'started':started,'ended':stamp(),'exit_code':p.poll(),'resource_stop':stopped,'journals':journals,'native_evidence_exists':evidence.exists(),'native_evidence_source':str(evidence),'final_free_bytes':shutil.disk_usage('C:\\').free,'b2':'LOCKED'})
    print(json.dumps({'run':rid,'native_evidence':evidence.exists(),'resource_stop':stopped,'out':str(out)}))
if __name__=='__main__':main()
