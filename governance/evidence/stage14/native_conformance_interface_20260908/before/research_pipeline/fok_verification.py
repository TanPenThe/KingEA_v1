"""Sealed-only FOK infrastructure verification and lossless archive construction.

No Candidate, ranking, market-data query, or execution capability.
"""
from __future__ import annotations
import argparse
import configparser
import gzip
import io
import json
import shutil
import tarfile
from pathlib import Path, PurePosixPath
from .native_cost_archive import NativeCostArchiveConsumer, digest, require, unique

ACCOUNTING_V1='2B88475645AC23207D9A4227A676E89E8D6D58C9753FAE12BF1C8496CA839D9D'

def verify_files(files):
    def read(name): return json.loads(files[name].decode('utf-8'),object_pairs_hook=unique)
    seal=read('SEALED_INVENTORY.json'); listed=set()
    for item in seal['files']:
        name=item['path'].replace('\\','/')
        require(name not in listed and name in files,'MISSING_OR_DUPLICATE_SEALED_ARTIFACT')
        require(len(files[name])==item['size'] and digest(files[name])==item['sha256'],'SEALED_ARTIFACT_ALTERED')
        listed.add(name)
    require(listed==set(files)-{'SEALED_INVENTORY.json'},'UNSEALED_ARTIFACT')
    m=read('MANIFEST.json'); a=read('AUTHORIZATION.json'); launch=read('LAUNCH_RECEIPT.json')
    runtime=read('RUNTIME_RECEIPT.json'); build=read('BUILD_BINDING.json'); pre=read('PRE_TOOLING.json')
    r=read('runtime/harness/result.json'); spec=read('runtime/harness/specification.json')
    req=read('runtime/harness/request.json'); check=read('runtime/harness/order_check.json')
    execution=read('runtime/harness/execution.json'); stop=read('runtime/harness/confirmed-stop.json')
    require(m['run_id'].startswith('NC-FOK-') and all(x['run_id']==m['run_id'] for x in
            (a,launch,r,spec,req,check,execution,stop)),'RUN_IDENTITY_MISMATCH')
    require(launch['manifest_sha256']==digest(files['MANIFEST.json']) and
            m['authorization_sha256']==digest(files['AUTHORIZATION.json']) and
            a['owner_scope_sha256']==digest(files['OWNER_SCOPE.json']),'AUTHORIZATION_BINDING')
    owner=read('OWNER_SCOPE.json')
    require(owner['scope']=='IMPLEMENTATION_AND_NON_CANDIDATE_FOK_CONFORMANCE_ONLY'
            and owner['b2']=='LOCKED' and owner['b2_demo2_path']=='CLOSED_ENVIRONMENT_INCOMPATIBLE','OWNER_SCOPE')
    require(a['scope']=='NON_CANDIDATE_FOK_INFRASTRUCTURE' and a['candidate_execution'] is False
            and a['budget']==0 and a['oos'] is False and a['holdout'] is False
            and a['simulated_entry_limit']==1 and m['candidate_id'] is None,'NON_CANDIDATE_SCOPE')
    require(r==runtime['result'] and r['status']=='PASS' and r['contract_failures']==0 and
            r['filling']==m['type_filling']=='ORDER_FILLING_FOK' and r['fallback_count']==0 and
            r['candidate_execution'] is False and r['candidate_exit_count']==0
            and r['boundary_count']==1 and r['metadata_captured'] and r['receipt_reconciled'],'RUNTIME_FAILURE')
    require(launch['pid']==runtime['pid']>0 and launch['started']==runtime['started']<runtime['ended']
            and runtime['exit_code']==0 and launch['command']==m['command'],'LAUNCH_RUNTIME_IDENTITY')
    ini=configparser.ConfigParser(); ini.read_string(files['tester.ini'].decode()); ini=ini['Tester']
    expected={'Symbol':'ETHUSD.s','Period':'M30','Model':'4','Optimization':'0','ExecutionMode':'20',
              'UseLocal':'1','UseRemote':'0','UseCloud':'0','FromDate':'2023.06.01','ToDate':'2023.06.02','ShutdownTerminal':'1'}
    require(all(ini[k]==v for k,v in expected.items()),'TESTER_SCOPE')
    set_name=ini['ExpertParameters']; settings=dict(line.split('=',1) for line in files[set_name].decode().splitlines())
    require(m['set_sha256']==digest(files[set_name]) and m['ini_sha256']==digest(files['tester.ini'])
            and settings['InpRunId']==m['run_id'],'CONSUMED_SET_INI')
    require(spec['server']=='JustMarkets-Demo2' and spec['symbol']=='ETHUSD.s' and spec['facts_ok'] and
            spec['account_fingerprint']==settings['InpExpectedFingerprint'] and
            spec['terminal_build']==int(settings['InpExpectedBuild'])==m['terminal']['build'],'ENVIRONMENT_IDENTITY')
    require(m['terminal']['file_version'].split('.')[-1]==str(m['terminal']['build']) and
            build['compiler']['file_version'].split('.')[-1]==str(build['compiler']['build']),'BUILD_METADATA')
    require(build['source_manifest_sha256']==m['source_sha256']==digest(files['PRE_TOOLING.json'])
            and not build['preexisting_ex5'] and build['started']<build['ended']<=launch['started']
            and digest(files['compile.log'])==build['log_sha256'],'FRESH_COMPILE_BINDING')
    for source in pre['sources']:
        require(digest(files['build/MQL5/'+source['path']])==source['sha256'],'SOURCE_DEPENDENCY_BINDING')
    require(digest(files['build/MQL5/Include/KingEA/AccountingEvents.mqh'])==ACCOUNTING_V1,'STAGE13_V1_CHANGED')
    require(digest(files['build/MQL5/Experts/KingEA/FOKInfrastructureConformance.ex5'])==
            build['produced_ex5_sha256']==m['ex5_sha256'],'EX5_BINDING')
    require('Result: 0 errors, 0 warnings' in files['compile.log'].decode('utf-16'),'COMPILATION_FAILURE')
    require(check['ok'] is True and check['retcode'] in (0,10009) and execution['ok'] is True and
            execution['retcode']==10009 and execution['attempts']==1 and
            execution['volume']==req['volume']==0.01 and execution['deal']>0 and execution['order']>0,'FOK_FULL_FILL')
    require(req['type_filling']=='ORDER_FILLING_FOK' and req['type']=='ORDER_TYPE_BUY' and
            0<stop['sl']==req['sl']<req['price'] and stop['position_identifier']>0,'PROTECTIVE_STOP_UNPROVEN')
    package=files['runtime/harness/native-cost-package.evidence']
    scope=dict(run=m['run_id'],configuration=0,branch='NON_CANDIDATE',partition='CONFORMANCE_2023')
    if m['evidence_contract']=='NATIVE_COST_BOUNDARY_V2': scope['package_schema']='NATIVE_COST_BOUNDARY_PACKAGE_V2'
    result=NativeCostArchiveConsumer.validate_package(package,scope)
    data=json.loads(package.decode().rsplit('|sha256=',1)[0],object_pairs_hook=unique)
    require(data['stage13_frame']==files['runtime/harness/stage13-event.txt'].decode()
            and data['stage13_canonical']==files['runtime/harness/stage13-canonical.txt'].decode()
            and data['sidecar']==files['runtime/harness/boundary-evidence.txt'].decode(),'SEPARATE_PROJECTION_BINDING')
    for i,line in enumerate(data['records']):
        require(line==files[f'runtime/harness/cost-record-{i}.txt'].decode(),'SEPARATE_COST_RECORD_BINDING')
    entry=data['records'][1].split('|')
    require(int(entry[3])==execution['deal'] and int(entry[4])==execution['order']
            and int(entry[5])==stop['position_identifier'] and float(entry[8])==execution['price'],'ENTRY_RECEIPT_COST_BINDING')
    require('|specification='+digest(files['runtime/harness/specification.json'])+'|' in data['sidecar'],
            'VALUATION_SPECIFICATION_BINDING')
    callback_pairs=0
    for index in range(2):
        callback_name=f'runtime/harness/synthetic-callback-package-{index}.evidence'
        plain_name=f'runtime/harness/synthetic-no-callback-package-{index}.evidence'
        if callback_name not in files and m['evidence_contract']=='NATIVE_COST_BOUNDARY_V1': continue
        # Later V2 proofs explicitly retain synthetic artifacts; no native callback claim.
        require(callback_name in files and plain_name in files,'MISSING_CALLBACK_CONFORMANCE_PAIR')
        synthetic_scope=dict(run='NON_CANDIDATE',configuration=0,branch='SYNTHETIC',partition='CONFORMANCE',
                             non_candidate=True,package_schema='NATIVE_COST_BOUNDARY_PACKAGE_V2')
        cb=NativeCostArchiveConsumer.validate_package(files[callback_name],synthetic_scope)
        plain=NativeCostArchiveConsumer.validate_package(files[plain_name],synthetic_scope)
        require(cb['stage13_frame']==plain['stage13_frame'] and cb['stage13_root']==plain['stage13_root'] and
                cb['housekeeping_count']==1 and plain['housekeeping_count']==0,'CALLBACK_CUSTOM_RESULT_DISAGREEMENT')
        callback_pairs+=1
    journals=runtime['journals']
    require(len(journals)==3 and len({j['source'] for j in journals})==3,'DISTINCT_JOURNALS_REQUIRED')
    for j in journals: require(digest(files[j['path'].replace('\\','/')])==j['sha256'],'JOURNAL_BINDING')
    agent=next(j for j in journals if 'Agent-127.0.0.1-' in j['source'])
    journal=files[agent['path'].replace('\\','/')].decode('utf-16',errors='replace')
    require('FOK_CONFORMANCE_BEGIN|'+m['run_id'] in journal and 'FOK_CONFORMANCE_END|'+m['run_id'] in journal,'AGENT_RUN_CORRELATION')
    return {'status':'PASS','run_id':m['run_id'],'fok_full_fill':True,'sealed_only':True,
            'artifacts':len(listed),'boundary_finalization_count':1,'candidate_exit_count':0,
            'synthetic_callback_pairs_verified':callback_pairs,
            'cost_package_sha256':result['package_sha256'],'seal_sha256':digest(files['SEALED_INVENTORY.json']),'b2':'LOCKED'}

def read_archive(path):
    files={}
    with tarfile.open(path,'r|gz') as archive:
        for member in archive:
            name=member.name; rel=PurePosixPath(name)
            require(member.isfile() and not rel.is_absolute() and '..' not in rel.parts and
                    '\\' not in name and ':' not in name and name not in files,'UNSAFE_OR_DUPLICATE_ARCHIVE_MEMBER')
            files[name]=archive.extractfile(member).read()
            require(len(files[name])==member.size,'ARCHIVE_MEMBER_TRUNCATED')
    return files

def verify_directory(root):
    root=Path(root)
    require(not any(p.is_symlink() for p in root.rglob('*')),'LINK_IN_SEALED_DIRECTORY')
    return verify_files({p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()})

def measure_capacity(proof, output):
    """Physical format-size sample only; not executable or valid research-result evidence.

    Uses the bounded non-Candidate fixture's byte layout, not candidate trade frequency.
    No claim that ten quote snapshots per configuration bounds a full research pass.
    """
    proof=Path(proof); output=Path(output)
    verified=verify_directory(proof)
    require(not output.exists(),'APPEND_ONLY_CAPACITY_OUTPUT_EXISTS'); output.mkdir(parents=True)
    free=shutil.disk_usage(output).free
    dynamic={p.name:p.read_bytes() for p in (proof/'runtime/harness').iterdir() if p.is_file()}
    fixed=sum(p.stat().st_size for p in proof.rglob('*') if p.is_file())-sum(map(len,dynamic.values()))
    sample=output/'NON_EXECUTABLE_1000_CONFIGURATION_FORMAT_SAMPLE.tar.gz'
    logical=0; telemetry=0; count=0
    with (sample.open('xb') as target,gzip.GzipFile(filename='',fileobj=target,mode='wb',mtime=0) as zipped,
          tarfile.open(fileobj=zipped,mode='w|') as tar):
        for configuration in range(1000):
            for name,data in dynamic.items():
                info=tarfile.TarInfo(f'FORMAT_ONLY/{configuration:05d}/{name}')
                info.size=len(data); tar.addfile(info,io.BytesIO(data)); logical+=len(data); count+=1
            data=json.dumps(dict(kind='NON_EXECUTABLE_CAPACITY_TELEMETRY_FIXTURE',configuration=configuration,
                                 candidate_execution=False,budget=0,metrics='ABSENT')).encode()
            info=tarfile.TarInfo(f'FORMAT_ONLY/{configuration:05d}/telemetry.json')
            info.size=len(data); tar.addfile(info,io.BytesIO(data)); logical+=len(data); telemetry+=len(data); count+=1
    # Read every member back without extraction. No format sample can authorize research.
    restored=read_archive(sample)
    require(len(restored)==count and sum(map(len,restored.values()))==logical,'CAPACITY_SAMPLE_ROUNDTRIP')
    for configuration in range(1000):
        for name,data in dynamic.items():
            require(restored[f'FORMAT_ONLY/{configuration:05d}/{name}']==data,'CAPACITY_SAMPLE_CONTENT_MISMATCH')
    w=logical+fixed; a=sample.stat().st_size+fixed
    required=200*max(w,a)+2*a+16*1024**3
    result=dict(kind='NON_CANDIDATE_FORMAT_CAPACITY_MEASUREMENT',configuration_count=1000,
                quote_snapshots_per_fixture=10,source_proof_seal=verified['seal_sha256'],
                measured_unarchived_dynamic_bytes=logical,measured_fixed_build_journal_overhead_bytes=fixed,
                W=w,A=a,largest_sample_child_archive_bytes=a,telemetry_bytes=telemetry,
                sample_archive_bytes=sample.stat().st_size,sample_archive_sha256=digest(sample.read_bytes()),
                formula='200 * max(W,A) + 2 * largest_archive + 16 GiB',required_free_bytes=required,
                free_bytes=free,volume=str(output.resolve().anchor),formula_pass=free>=required,
                hard_floor_bytes=30*1024**3,hard_floor_pass=free>=30*1024**3,
                production_growth_bound_proven=False,
                result='NOT_READY',
                limitations=['FORMAT_SAMPLE_NOT_A_BOUND_ON_FULL_PASS_QUOTE_OR_TRADE_COUNTS',
                             'PER_ELIGIBLE_TICK_SNAPSHOT_RETENTION_GROWS_WITH_EXPOSURE_DURATION'],
                candidate_execution=False,budget=0,b2='LOCKED')
    if not result['hard_floor_pass']: result['limitations'].append('ACTIVE_C_VOLUME_BELOW_30_GIB')
    (output/'CAPACITY_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--proof',type=Path,required=True)
    parser.add_argument('--capacity-only',action='store_true')
    parser.add_argument('--output',type=Path,required=True); args=parser.parse_args()
    if args.capacity_only:
        print(json.dumps(measure_capacity(args.proof,args.output))); return
    result=verify_directory(args.proof)
    require(not args.output.exists(),'APPEND_ONLY_OUTPUT_EXISTS'); args.output.mkdir(parents=True)
    archive=args.output/'FOK_NON_CANDIDATE_PROOF.tar.gz'
    with (archive.open('xb') as target,
          gzip.GzipFile(filename='',fileobj=target,mode='wb',mtime=0) as compressed,
          tarfile.open(fileobj=compressed,mode='w|') as tar):
        for p in sorted(args.proof.rglob('*')):
            if not p.is_file(): continue
            data=p.read_bytes(); info=tarfile.TarInfo(p.relative_to(args.proof).as_posix())
            info.size=len(data); info.mode=0o600; tar.addfile(info,io.BytesIO(data))
    archived=verify_files(read_archive(archive)); require(result==archived,'ARCHIVE_ROUNDTRIP_MISMATCH')
    result.update(archive_sha256=digest(archive.read_bytes()),archive_bytes=archive.stat().st_size)
    (args.output/'SEALED_VERIFICATION.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__': main()
