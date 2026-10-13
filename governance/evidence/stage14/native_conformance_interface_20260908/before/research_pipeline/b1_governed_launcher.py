"""Bounded B1 launcher for a synthetic no-order Strategy Tester harness only.

It rejects Candidate 001, OOS/holdout, orders, remote/cloud agents, and B2.
"""
from __future__ import annotations
import argparse, json, shutil, subprocess, time
from datetime import datetime, timezone
from hashlib import sha256
from pathlib import Path
from .b1_evidence_infrastructure import B1EvidenceCoordinator

def digest(path: Path) -> str: return B1EvidenceCoordinator.file_hash(path)
def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
def canonical(value: object) -> str: return B1EvidenceCoordinator.canonical_hash(value)
def executable_metadata(path: Path) -> dict:
    command=["powershell","-NoProfile","-Command",f"(Get-Item -LiteralPath '{str(path).replace("'","''")}').VersionInfo.FileVersion"]
    value=subprocess.run(command,capture_output=True,text=True,check=True).stdout.strip()
    build=int(value.split('.')[-1])
    return {'path':str(path),'version':value,'build':build}

def main(argv: list[str] | None = None) -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument("--workspace",type=Path,default=Path(r"C:\KingEA_v1"))
    parser.add_argument("--run-id",default="B1-SYNTHETIC-CONSUMPTION-20260904")
    parser.add_argument("--terminal",type=Path,default=Path(r"C:\Program Files\MetaTrader 5\terminal64.exe"))
    parser.add_argument("--terminal-data",type=Path,default=Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"))
    parser.add_argument("--common-files",type=Path,default=Path(r"C:\Users\tpent\AppData\Roaming\MetaQuotes\Terminal\Common\Files"))
    args=parser.parse_args(argv)
    root=args.workspace.resolve(); evidence=root/'governance/evidence/stage14/b1_real_consumption_20260904'/'runs'/args.run_id; runtime=evidence/'runtime'; build=evidence/'build'; launch=evidence/'launch'
    if evidence.exists(): raise RuntimeError('B1_RUN_EVIDENCE_ALREADY_EXISTS')
    adoption=json.loads((root/'governance/evidence/stage14/GOVERNANCE_ADOPTION_OPTION_B_B1_20260904.json').read_text())
    if adoption.get('gate_b2')!='LOCKED' or adoption.get('candidate_scientific_status')!='QUARANTINED_PENDING_DIAGNOSTIC': raise RuntimeError('B1_GOVERNANCE_SCOPE_INVALID')
    if not args.run_id.startswith('B1-SYNTHETIC-') or 'CAND' in args.run_id: raise RuntimeError('NON_CANDIDATE_RUN_ID_REQUIRED')
    running=subprocess.run(['tasklist','/FI','IMAGENAME eq terminal64.exe','/NH'],capture_output=True,text=True,check=False)
    if 'terminal64.exe' in running.stdout.lower(): raise RuntimeError('MT5_ALREADY_RUNNING')
    source=root/'MQL5/Experts/KingEA/B1SyntheticNoOrder.mq5'; editor=args.terminal.with_name('metaeditor64.exe'); compile_log=build/'B1SyntheticNoOrder.compile.log'; build.mkdir(parents=True,exist_ok=True); executable=source.with_suffix('.ex5')
    if executable.exists(): executable.unlink()
    if executable.exists(): raise RuntimeError('PRECOMPILE_EX5_ISOLATION_FAILED')
    compiler_meta=executable_metadata(editor); terminal_meta=executable_metadata(args.terminal)
    compile_command=[str(editor),f'/compile:{source}',f'/log:{compile_log}']; compile_started=datetime.now(timezone.utc); compiled=subprocess.run(compile_command,capture_output=True,text=True,check=False); compile_ended=datetime.now(timezone.utc)
    if not executable.is_file() or 'Result: 0 errors, 0 warnings' not in compile_log.read_text(encoding='utf-16',errors='ignore')+compile_log.read_text(encoding='utf-8',errors='ignore'):
        raise RuntimeError('SYNTHETIC_COMPILE_FAILED')
    deployed=args.terminal_data/'MQL5/Experts/KingEA'; deployed.mkdir(parents=True,exist_ok=True)
    for item in (source,executable): shutil.copyfile(item,deployed/item.name)
    if digest(executable)!=digest(deployed/executable.name): raise RuntimeError('EX5_DEPLOYMENT_HASH_MISMATCH')
    commit=subprocess.run(['git','rev-parse','HEAD'],cwd=root,capture_output=True,text=True,check=True).stdout.strip()
    source_entry={'relative_path':'Experts/KingEA/B1SyntheticNoOrder.mq5','sha256':digest(source)}
    source_manifest={'kind':'B1_SOURCE_EX5_BINDING','git_commit':commit,'compiler':{**compiler_meta,'compile_started_at':compile_started.isoformat(),'compile_ended_at':compile_ended.isoformat(),'compile_command':compile_command,'return_code':compiled.returncode,'compile_log_sha256':digest(compile_log),'ex5_preexisting':False,'produced_ex5_sha256':digest(deployed/executable.name)},'sources':[source_entry],'source_tree_sha256':canonical([source_entry]),'ex5_sha256':digest(deployed/executable.name)}
    write_json(build/'source-manifest.json',source_manifest)
    authorization={'kind':'B1_AUTHORIZATION','run_id':args.run_id,'owner_authorized':True,'candidate_execution':False,'native_orders':False,'oos_access':False,'holdout_access':False,'candidate_budget_consumption':0}
    write_json(launch/'authorization.json',authorization)
    folder=f'KingEA\\B1\\{args.run_id}'
    settings=launch/'B1SyntheticNoOrder.set'; settings.write_text(f'InpRunId={args.run_id}\nInpEvidenceFolder={folder}\n',encoding='utf-8')
    profile=args.terminal_data/'MQL5/Profiles/Tester'; profile.mkdir(parents=True,exist_ok=True); shutil.copyfile(settings,profile/settings.name)
    ini=launch/'B1SyntheticNoOrder.ini'; ini.write_text('[Tester]\nExpert=KingEA\\B1SyntheticNoOrder.ex5\nExpertParameters=B1SyntheticNoOrder.set\nSymbol=ETHUSD.s\nPeriod=M30\nModel=4\nOptimization=0\nUseLocal=1\nUseRemote=0\nUseCloud=0\nFromDate=2024.01.02\nToDate=2024.01.03\nShutdownTerminal=1\n',encoding='utf-8')
    launch_command=[str(args.terminal),f'/config:{ini}']
    run_manifest={'kind':'B1_RUN_MANIFEST','run_id':args.run_id,'scope':'B1_NON_CANDIDATE_SYNTHETIC_ONLY','authorization_sha256':digest(launch/'authorization.json'),'source_tree_sha256':source_manifest['source_tree_sha256'],'ex5_sha256':digest(deployed/executable.name),'set_sha256':digest(settings),'ini_sha256':digest(ini),'launch_command':launch_command,'terminal_scope':{'terminal_path':terminal_meta['path'],'terminal_version':terminal_meta['version'],'terminal_build':terminal_meta['build'],'compiler_version':compiler_meta['version'],'compiler_build':compiler_meta['build'],'local_only':True,'remote_agents':False,'cloud_agents':False},'controls':{'candidate_execution':False,'native_orders':False,'candidate_budget_consumption':False,'oos_access':False,'holdout_access':False}}
    write_json(launch/'B1_RUN_MANIFEST.json',run_manifest)
    manifest_hash=digest(launch/'B1_RUN_MANIFEST.json')
    receipt={'kind':'B1_GOVERNED_LAUNCH_RECEIPT','producer':'B1_GOVERNED_LAUNCHER','run_id':args.run_id,'manifest_sha256':manifest_hash,'authorization_sha256':digest(launch/'authorization.json'),'source_tree_sha256':source_manifest['source_tree_sha256'],'ex5_sha256':digest(deployed/executable.name),'set_sha256':digest(settings),'ini_sha256':digest(ini),'launcher_sha256':digest(Path(__file__)),'launch_command':launch_command,'terminal_executable':args.terminal.name,'terminal_path':str(args.terminal),'terminal_version':terminal_meta['version'],'terminal_build':terminal_meta['build'],'compiler_version':compiler_meta['version'],'compiler_build':compiler_meta['build'],'process_id':0,'agent_ids':[],'launch_timestamp':datetime.now(timezone.utc).isoformat()}
    log_root=args.terminal_data/'logs'; before_logs={path: digest(path) for path in log_root.glob('*.log')}
    started=datetime.now(timezone.utc); receipt['launch_timestamp']=started.isoformat(); process=subprocess.Popen(launch_command); agent_id=f'local-terminal-tester:{process.pid}:in-process'; receipt['process_id']=process.pid; receipt['agent_ids']=[agent_id]; receipt['receipt_sha256']=canonical(receipt); write_json(launch/'launch-receipt.json',receipt)
    exit_code=process.wait(timeout=300); ended=datetime.now(timezone.utc)
    common=args.common_files/f'KingEA/B1/{args.run_id}'; telemetry=common/'telemetry.json'; result=common/'result.json'
    if exit_code!=0 or not telemetry.is_file() or not result.is_file(): raise RuntimeError('SYNTHETIC_TERMINAL_CONSUMPTION_FAILED')
    runtime.mkdir(parents=True,exist_ok=True)
    changed_logs=[path for path in log_root.glob('*.log') if before_logs.get(path)!=digest(path)]
    if len(changed_logs)!=1: raise RuntimeError('TERMINAL_TESTER_JOURNAL_NOT_UNAMBIGUOUS')
    actual_log=changed_logs[0]
    terminal_journal=runtime/'terminal.journal.log'; tester_journal=runtime/'tester-runtime-capability.json'; agent_journal=runtime/'local-agent-runtime-capability.json'
    shutil.copyfile(actual_log,terminal_journal)
    terminal_text=terminal_journal.read_text(encoding='utf-16',errors='ignore')+terminal_journal.read_text(encoding='utf-8',errors='ignore')
    if 'automatic testing started' not in terminal_text:
        raise RuntimeError('TERMINAL_TESTER_JOURNAL_CONTENT_INVALID')
    tester_journal.write_text(json.dumps({'kind':'B1_TESTER_RUNTIME_LIMITATION','run_id':args.run_id,'native_separate_tester_journal_available':False,'source_terminal_journal_sha256':digest(terminal_journal),'evidence':'terminal journal contains Strategy Tester start/completion records','limitation':'MT5 local single-run tester emits Tester records into the terminal journal rather than a separate tester journal'},sort_keys=True,separators=(',',':'))+'\n',encoding='utf-8')
    agent_journal.write_text(json.dumps({'kind':'B1_LOCAL_AGENT_RUNTIME_LIMITATION','run_id':args.run_id,'native_separate_agent_journal_available':False,'agent_id':agent_id,'process_id':process.pid,'source_terminal_journal_sha256':digest(terminal_journal),'limitation':'MT5 local single-run tester executes in the terminal process; no separate MetaTester agent journal was emitted'},sort_keys=True,separators=(',',':'))+'\n',encoding='utf-8')
    proof={'kind':'B1_RUNTIME_PROOF','run_id':args.run_id,'process_id':process.pid,'agent_ids':[agent_id],'started_at':started.isoformat(),'ended_at':ended.isoformat(),'exit_code':exit_code,'terminal_journal_sha256':digest(terminal_journal),'tester_journal_sha256':digest(tester_journal),'agent_journal_sha256':digest(agent_journal),'run_correlated':True}
    write_json(runtime/'runtime-proof.json',proof)
    print(json.dumps({'status':'CONSUMED','run_id':args.run_id,'evidence':str(evidence),'telemetry':str(telemetry),'result':str(result)},sort_keys=True)); return 0

if __name__=='__main__': raise SystemExit(main())
