"""Pinned, non-Candidate infrastructure authority. Never a successor fallback.

Control and evidence verification are read-only except for the explicitly
authorized loader-staging operation. Runtime launching and seal creation are
deliberately absent; a separately authorized custodian pins completed captures
and final seals.
"""
from pathlib import Path
from . import decision_a_evidence as v3

DOMAIN = 'NON_CANDIDATE_NATIVE_CONFORMANCE_V1'
SCOPE = 'NON_CANDIDATE_NATIVE_CONFORMANCE'
FIXTURE_FIELDS = {'fixture_id','run_id','group_id','side','volume','S0','start_msc','end_msc',
                  'entry_msc','reduction_msc','close_msc','outcome','data_scope','execution_mode',
                  'optimization','symbol'}

# Closed implementation metadata for the conformance SET map.  This is not
# discovered at runtime: changing an MQL input requires an explicit review of
# this map and its deterministic declaration test.
SET_INPUT_TYPES = {
    'InpNativeConformance':'bool', 'InpConformanceControlSha256':'string',
    'InpRunManifest':'string', 'InpManifestFileSha256':'string', 'InpManifestSha256':'string',
    'InpPurpose':'string', 'InpGate':'string', 'InpRootSha256':'string',
    'InpDetachedAuthorizationToken':'string', 'InpConfigurationId':'int',
    'InpEvaluationStart':'string', 'InpEvaluationEndExclusive':'string', 'InpBranch':'string',
    'InpExpectedSymbol':'string', 'InpExecutionAdapter':'string', 'InpScenario':'string',
    'InpDelayMs':'int', 'InpTesterModel':'int', 'InpLocalAgentsOnly':'bool',
    'InpRemoteAgentsDisabled':'bool', 'InpCloudAgentsDisabled':'bool',
    'InpZeroEntryDiagnostic':'bool', 'InpWorkloadDryRun':'bool',
    'InpCalendarIntervalsFile':'string', 'InpCalendarFileSha256':'string', 'InpCalendarSha256':'string',
}

def serialize_tester_set(values):
    """Serialize the fixed SET map in MetaTester non-optimization form."""
    v3.require(set(values) == set(SET_INPUT_TYPES), 'CONFORMANCE_SET_TYPE_MAP_MISMATCH')
    records=[]
    for name, value in values.items():
        v3.require(isinstance(value, str), 'CONFORMANCE_SET_VALUE_TYPE')
        kind=SET_INPUT_TYPES[name]
        if kind == 'string':
            records.append(name+'='+value)
        else:
            # The first field is the governed value. N prevents optimization;
            # the fixed range fields have no research authority.
            records.append(name+'='+value+'||'+value+'||1||'+value+'||N')
    return ('\r\n'.join(records)+'\r\n').encode()

def resolve_terminal_instance(terminal_executable, instance_id, *, terminal_root):
    """Resolve the exact terminal data tree; never infer it from a package."""
    exe=Path(terminal_executable).resolve();root=Path(terminal_root).resolve()
    v3.require(type(instance_id) is str and len(instance_id)==32 and all(c in '0123456789ABCDEF' for c in instance_id),'TERMINAL_INSTANCE_ID_INVALID')
    v3.require(exe.is_file() and root.is_dir(),'TERMINAL_INSTANCE_UNAVAILABLE')
    data=(root/instance_id).resolve();origin=data/'origin.txt'
    v3.require(data.is_dir() and origin.is_file() and not origin.is_symlink(),'TERMINAL_INSTANCE_UNAVAILABLE')
    value=origin.read_text(encoding='utf-8-sig').strip()
    v3.require(Path(value).resolve()==exe.parent,'TERMINAL_INSTANCE_BINDING_MISMATCH')
    return dict(instance_id=instance_id,terminal_executable=str(exe),terminal_executable_sha256=v3.digest(exe.read_bytes()),terminal_data_dir=str(data),origin_sha256=v3.digest(origin.read_bytes()),tester_journal_dir=str(data/'Tester'/'logs'),terminal_root=str(root))

def stage_expert_parameters(context, instance, ini_raw, *, set_name=None):
    """Make the pinned SET loader-visible and return an audit-only receipt."""
    v3.require(type(context) is ConformanceControl,'INDEPENDENT_CONFORMANCE_CONTEXT_REQUIRED')
    name=set_name or (context.fixture['fixture_id']+'.set')
    v3.require(name==context.fixture['fixture_id']+'.set' and '/' not in name and '\\' not in name,'EXPERT_PARAMETERS_BASENAME_INVALID')
    ini=ini_raw.decode('utf-8-sig')
    v3.require('ExpertParameters='+name in ini,'EXPERT_PARAMETERS_INI_MISMATCH')
    data=Path(instance['terminal_data_dir']).resolve()
    v3.require(data.name==instance['instance_id'] and (data/'origin.txt').is_file(),'TERMINAL_INSTANCE_BINDING_MISMATCH')
    target=data/'MQL5'/'Profiles'/'Tester'/name
    target.parent.mkdir(parents=True,exist_ok=True)
    expected=context.prepare_inputs()['set_bytes']
    target.write_bytes(expected)
    observed=target.read_bytes()
    v3.require(observed==expected and v3.digest(observed)==v3.digest(expected),'EXPERT_PARAMETERS_COPY_MISMATCH')
    return dict(kind='CONFORMANCE_EXPERT_PARAMETERS_BINDING_V1',fixture_id=context.fixture['fixture_id'],run_id=context.fixture['run_id'],terminal_instance_id=instance['instance_id'],terminal_executable=instance['terminal_executable'],terminal_executable_sha256=instance['terminal_executable_sha256'],terminal_data_dir=instance['terminal_data_dir'],origin_sha256=instance['origin_sha256'],loader_relative_path='MQL5/Profiles/Tester/'+name,loader_absolute_path=str(target),authoritative_set_sha256=v3.digest(expected),loader_set_sha256=v3.digest(observed),byte_length=len(observed),ini_sha256=v3.digest(ini_raw),expert_parameters=name,post_write_verification='PASS')

def read_pinned_loader_binding(root, reference):
    v3.require(type(reference) is dict and set(reference)=={'path','byte_length','sha256'} and
               type(reference['byte_length']) is int and reference['byte_length']>0 and
               v3.hash_value(reference['sha256']),'LOADER_BINDING_REFERENCE_INVALID')
    base=Path(root).resolve();name=v3.archive_path(reference['path']);path=(base/name).resolve()
    v3.require(path.is_relative_to(base) and path.is_file() and not path.is_symlink(),'LOADER_BINDING_REFERENCE_INVALID')
    raw=path.read_bytes();v3.require(len(raw)==reference['byte_length'] and v3.digest(raw)==reference['sha256'],'LOADER_BINDING_PIN_MISMATCH')
    return v3.parse_json(raw)

def read_pinned_expected_terminal_instance(root, reference):
    """Read the independently pinned terminal authority exactly once."""
    v3.require(type(reference) is dict and set(reference)=={'path','byte_length','sha256'} and
               type(reference['byte_length']) is int and reference['byte_length']>0 and
               v3.hash_value(reference['sha256']),'EXPECTED_TERMINAL_REFERENCE_INVALID')
    base=Path(root).resolve();name=v3.archive_path(reference['path']);path=(base/name).resolve()
    v3.require(path.is_relative_to(base) and path.is_file() and not path.is_symlink(),'EXPECTED_TERMINAL_REFERENCE_INVALID')
    raw=path.read_bytes();v3.require(len(raw)==reference['byte_length'] and v3.digest(raw)==reference['sha256'],'EXPECTED_TERMINAL_PIN_MISMATCH')
    return v3.parse_json(raw)

def validate_expected_terminal_instance(context, record):
    required={'kind','fixture_id','run_id','terminal_instance_id','terminal_executable',
              'terminal_executable_sha256','terminal_data_dir','origin_sha256',
              'tester_journal_dir','terminal_root','terminal_build'}
    v3.require(type(context) is ConformanceControl and type(record) is dict and set(record)==required and
               record['kind']=='CONFORMANCE_EXPECTED_TERMINAL_INSTANCE_V1' and
               record['fixture_id']==context.fixture['fixture_id'] and record['run_id']==context.fixture['run_id'] and
               record['terminal_build']==6140,'EXPECTED_TERMINAL_RECORD_INVALID')
    resolved=resolve_terminal_instance(record['terminal_executable'],record['terminal_instance_id'],terminal_root=record['terminal_root'])
    for key in ('terminal_executable','terminal_executable_sha256','terminal_data_dir','origin_sha256','tester_journal_dir','terminal_root'):
        v3.require(record[key]==resolved[key],'EXPECTED_TERMINAL_IDENTITY_MISMATCH')
    return resolved

def validate_loader_binding(context, receipt, *, expected_ini_raw, expected_terminal_reference, expected_terminal_root):
    v3.require(type(context) is ConformanceControl and type(receipt) is dict,'LOADER_BINDING_INVALID')
    name=context.fixture['fixture_id']+'.set'; expected=context.prepare_inputs()['set_bytes']
    required={'kind','fixture_id','run_id','terminal_instance_id','terminal_executable','terminal_executable_sha256','terminal_data_dir','origin_sha256','loader_relative_path','loader_absolute_path','authoritative_set_sha256','loader_set_sha256','byte_length','ini_sha256','expert_parameters','post_write_verification'}
    v3.require(set(receipt)==required and receipt['kind']=='CONFORMANCE_EXPERT_PARAMETERS_BINDING_V1' and receipt['fixture_id']==context.fixture['fixture_id'] and receipt['run_id']==context.fixture['run_id'],'LOADER_BINDING_INVALID')
    expected_record=read_pinned_expected_terminal_instance(expected_terminal_root,expected_terminal_reference)
    resolved=validate_expected_terminal_instance(context,expected_record)
    for key in ('instance_id','terminal_executable','terminal_executable_sha256','terminal_data_dir','origin_sha256'):
        receipt_key='terminal_instance_id' if key=='instance_id' else key
        expected_key='terminal_instance_id' if key=='instance_id' else key
        v3.require(receipt[receipt_key]==resolved[key] and expected_record[expected_key]==resolved[key],'LOADER_TERMINAL_IDENTITY_MISMATCH')
    target=(Path(resolved['terminal_data_dir'])/'MQL5'/'Profiles'/'Tester'/name).resolve()
    v3.require(receipt['loader_absolute_path']==str(target) and target.is_file() and target.read_bytes()==expected,'LOADER_BINDING_MISMATCH')
    v3.require(receipt['expert_parameters']==name and receipt['loader_relative_path']=='MQL5/Profiles/Tester/'+name and receipt['authoritative_set_sha256']==v3.digest(expected) and receipt['loader_set_sha256']==v3.digest(expected) and receipt['byte_length']==len(expected) and receipt['ini_sha256']==v3.digest(expected_ini_raw) and receipt['post_write_verification']=='PASS','LOADER_BINDING_MISMATCH')

class ConformanceControl:
    domain = DOMAIN
    binding_fields = (v3.BINDING_FIELDS - {'root_hash','freeze_receipt_hash','execution_receipt_hash'}) | {
        'evidence_scope','fixture_id','conformance_control_hash','fixture_specification_hash','launch_record_hash'}

    def __init__(self, directory, control_path, pinned_hash):
        self.directory=Path(directory).resolve();self._launch_hash=None
        self.control_raw=self._read({'path':control_path,'sha256':pinned_hash})
        self.control=v3.parse_json(self.control_raw);self.control_hash=v3.digest(self.control_raw)
        v3.require(set(self.control)=={'domain','fixture','profile','artifacts','local_inputs'},'CONFORMANCE_CONTROL_FIELDS')
        v3.require(self.control['domain']==DOMAIN,'CONFORMANCE_AUTHORITY_REQUIRED')
        self.fixture_raw=self._read(self.control['fixture']);self.fixture=v3.parse_json(self.fixture_raw)
        self.profile_raw=self._read(self.control['profile']);self.profile=v3.parse_json(self.profile_raw)
        f=self.fixture
        v3.require(set(f)==FIXTURE_FIELDS and f['data_scope']=='DEVELOPMENT_ONLY' and
                   f['execution_mode']==20 and f['optimization'] is False,'FIXED_DEVELOPMENT_FIXTURE_REQUIRED')
        v3.require(f['side'] in ('LONG','SHORT') and f['symbol']=='ETHUSD.s','FIXTURE_SIDE_SYMBOL')
        v3.require(v3.hash_value(f['run_id']) and all(type(f[k]) is str and f[k] and '|' not in f[k] for k in ('fixture_id','group_id')),'FIXTURE_IDENTITY')
        for k in ('start_msc','end_msc','entry_msc','reduction_msc','close_msc'):
            v3.require(type(f[k]) is int and f[k]>=0 and f[k]%1000==0,'FIXTURE_TIME')
        v3.require(f['start_msc']<=f['entry_msc']<f['reduction_msc']<f['end_msc'],'FIXTURE_SCHEDULE')
        v3.require((f['outcome']=='NORMAL_CLOSE' and f['reduction_msc']<f['close_msc']<f['end_msc']) or
                   (f['outcome']=='EVALUATOR_BOUNDARY' and f['close_msc']==0),'FIXTURE_OUTCOME')
        v3.require(v3.number(f['volume'])>0 and v3.number(f['S0'])>0,'FIXTURE_ORIGINAL')
        self.side=f['side']
        self.authorities={role:self._read(ref) for role,ref in self.control['artifacts'].items()}
        v3.require(not ({'FREEZE_RECEIPT','EXECUTION_RECEIPT'} & set(self.authorities)),'SUCCESSOR_RECEIPT_NOT_CONFORMANCE')
        self.authorities.update(CONFORMANCE_CONTROL=self.control_raw,FIXTURE_SPECIFICATION=self.fixture_raw,TESTER_PROFILE=self.profile_raw)
        v3.validate_profile(self.profile,self.side,conformance=self)
        for key,role in [('source_manifest_hash','SOURCE_MANIFEST'),('executable_hash','EXECUTABLE'),('configuration_hash','CONFIGURATION_SPECIFICATION'),('native_swap_profile_hash','NATIVE_SWAP_PROFILE')]:
            v3.require(self.profile[key]==v3.digest(self.authorities[role]),'CONFORMANCE_PROFILE_ARTIFACT_MISMATCH')
        bootstrap=v3.parse_json(self.authorities['NATIVE_SWAP_PROFILE'])
        v3.require(bootstrap.get('kind')=='UNACCEPTED_NATIVE_SWAP_BOOTSTRAP' and bootstrap.get('side')==self.side and bootstrap.get('fixture_id')==f['fixture_id'] and bootstrap.get('evidence_scope')==SCOPE,'LONG_PROOF_NOT_SHORT_BOOTSTRAP')
        inputs=self.control['local_inputs']
        v3.require(type(inputs) is dict and set(inputs)=={'manifest_path','calendar_path','calendar'},'LOCAL_INPUT_AUTHORITY_REQUIRED')
        for key in ('manifest_path','calendar_path'):
            path=v3.archive_path(inputs[key]);v3.require(path.startswith('KingEA/conformance/'+f['fixture_id']+'/'),'FIXTURE_LOCAL_INPUT_SCOPE')
        self.calendar_raw=self._read(inputs['calendar'])
        v3.ImmutableInput('calendar',v3.digest(self.calendar_raw),self.calendar_raw).calendar()

    def _read(self, ref):
        v3.require(type(ref) is dict and set(ref)=={'path','sha256'} and v3.hash_value(ref['sha256']),'INDEPENDENT_REFERENCE_REQUIRED')
        path=v3.archive_path(ref['path']);p=self.directory/path
        v3.require(not p.is_symlink() and p.resolve().is_relative_to(self.directory),'UNTRUSTED_CONFORMANCE_PATH')
        with p.open('rb') as stream:raw=stream.read(10_000_001)
        v3.require(0<len(raw)<=10_000_000,'CONFORMANCE_ARTIFACT_SIZE')
        v3.require(v3.digest(raw)==ref['sha256'],'CONFORMANCE_PIN_MISMATCH')
        return raw

    def validate_profile(self, profile, side):
        v3.require(profile==self.profile and side==self.side and profile.get('evidence_scope')==SCOPE and
                   profile.get('fixture_id')==self.fixture['fixture_id'] and profile.get('side')==side and
                   profile.get('evaluation_start_msc')==self.fixture['start_msc'] and
                   profile.get('evaluation_end_msc')==self.fixture['end_msc'] and
                   profile.get('accepted_proof_sha256') is None,'CONFORMANCE_PROFILE_MISMATCH')
        # This is expressly an unaccepted bootstrap profile, never LONG proof reuse.

    def binding(self):
        f=self.fixture;a=self.authorities
        keys={'configuration_hash':'CONFIGURATION_SPECIFICATION','source_manifest_hash':'SOURCE_MANIFEST',
              'executable_hash':'EXECUTABLE','specification_hash':'COMBINED_SPECIFICATION',
              'decision_a_hash':'DECISION_A_SPECIFICATION','decision_s_hash':'DECISION_S_SPECIFICATION'}
        b={key:v3.digest(a[role]) for key,role in keys.items()}
        b.update(run_id=f['run_id'],group_id=f['group_id'],candidate_id=DOMAIN,branch='CONFORMANCE',
                 partition='DEVELOPMENT_ONLY',symbol=f['symbol'],tester_profile_hash=v3.digest(self.profile_raw),
                 evidence_scope=SCOPE,fixture_id=f['fixture_id'],conformance_control_hash=self.control_hash,
                 fixture_specification_hash=v3.digest(self.fixture_raw),launch_record_hash=self._launch_hash or '')
        return b

    def _stable(self):
        v3.require(self.fixture==v3.parse_json(self.fixture_raw) and self.profile==v3.parse_json(self.profile_raw) and self.control==v3.parse_json(self.control_raw),'IMMUTABLE_CONFORMANCE_CONTEXT_CHANGED')
        v3.require(v3.digest(self.control_raw)==self.control_hash,'CONFORMANCE_PIN_MISMATCH')
        v3.require(all(v3.digest(self.authorities[role])==ref['sha256'] for role,ref in self.control['artifacts'].items()),'CONFORMANCE_AUTHORITY_BYTES_CHANGED')

    def validate_binding(self, binding):
        self._stable()
        v3.require(v3.hash_value(self._launch_hash) and binding==self.binding(),'CONFORMANCE_BINDING_MISMATCH')

    def with_launch_record(self, reference, *, loader_binding_root=None, expected_terminal_root=None):
        import copy
        launch=self.verify_launch_record(reference,loader_binding_root=loader_binding_root,
                                         expected_terminal_root=expected_terminal_root)
        bound=copy.copy(self);bound._launch_hash=reference['sha256']
        bound.authorities=dict(self.authorities,CONFORMANCE_LAUNCH_RECORD=self._read(reference))
        for key in ('set','ini','manifest','calendar'):bound.authorities['CONFORMANCE_LAUNCH_'+key.upper()]=self._read(launch[key+'_file'])
        return bound

    def build(self, capture_reference):
        self._stable()
        v3.require(v3.hash_value(self._launch_hash),'INDEPENDENT_LAUNCH_RECORD_REQUIRED')
        raw=self._read(capture_reference)
        f=self.fixture;c=v3.parse_json(raw)
        original=[v3.parse_json(r['payload'].encode()) for r in c['records'] if r['role']=='ORIGINAL']
        v3.require(len(original)==1 and all(v3.number(original[0][k])==v3.number(f[v]) for k,v in [('V0','volume'),('S0','S0')]),'FIXTURE_ORIGINAL_MISMATCH')
        v3.require(c['outcome']==f['outcome'],'FIXTURE_OUTCOME_MISMATCH')
        checks=[v3.parse_json(r['payload'].encode()) for r in c['records'] if r['role']=='ORDER_CHECK']
        windows=[(f['entry_msc'],f['reduction_msc']),(f['reduction_msc'],f['close_msc'] or f['end_msc'])]
        if f['outcome']=='NORMAL_CLOSE':windows.append((f['close_msc'],f['end_msc']))
        v3.require(len(checks)==len(windows) and all(start<=check['time_msc']<end for check,(start,end) in zip(checks,windows)), 'FIXTURE_REQUEST_SCHEDULE_MISMATCH')
        files=v3.assemble_native_archive(raw,self.binding(),self.profile,self.authorities,
              expected_capture_hash=capture_reference['sha256'],expected_configuration=0,conformance=self)
        return files

    def verify(self, files, independent_seal_reference, capture_reference, *, launch_record_reference, loader_binding_root=None, expected_terminal_root=None):
        launch=self.verify_launch_record(launch_record_reference,loader_binding_root=loader_binding_root,expected_terminal_root=expected_terminal_root)
        v3.require(self._launch_hash==launch_record_reference['sha256'],'LAUNCH_RECORD_PIN_MISMATCH')
        seal=v3.parse_json(self._read(independent_seal_reference))
        scope=dict(self.binding(),contract_id=v3.CONTRACT,package_id=v3.PACKAGE,semantic_id=v3.SEMANTICS,inventory_protocol_hash=v3.INVENTORY_ADOPTION)
        sidecar,refs=v3.verify_archive(files,seal,scope)
        v3.validate_package(files['sidecar.evidence'],self.binding(),self.profile,refs,conformance=self)
        v3.require(files==self.build(capture_reference),'CONFORMANCE_NATIVE_RECONSTRUCTION_MISMATCH')
        return {'evidence_scope':SCOPE,'fixture_id':self.fixture['fixture_id'],'side':self.side,
                'classification':'CONFORMANCE_EVIDENCE_FOR_INDEPENDENT_REVIEW','successor_eligible':False,'launch_record_hash':self._launch_hash}


    def prepare_inputs(self):
        """Return immutable manifest/calendar bytes and SET values, without writing.

        Local target paths come only from the independently pinned control.
        The caller must stage these exact bytes and bind the final SET/INI in a
        separately retained launch record. This method never launches anything.
        """
        from datetime import datetime,timezone
        self._stable();f=self.fixture;b=self.binding();i=self.control['local_inputs']
        manifest={k:str(value) for k,value in f.items()}
        manifest.update(domain=DOMAIN,control_sha256=self.control_hash,configuration_sha256=b['configuration_hash'],
                        source_sha256=b['source_manifest_hash'],tester_profile_sha256=b['tester_profile_hash'],
                        inventory_protocol_sha256=v3.INVENTORY_ADOPTION,swap_transition_rule_sha256=v3.SWAP_TRANSITION_ADOPTION)
        raw=v3.json_bytes(manifest)
        def iso(ms):
            v3.require(ms%1000==0,'FIXTURE_BOUNDARY_SECOND_PRECISION')
            return datetime.fromtimestamp(ms/1000,timezone.utc).strftime('%Y-%m-%dT%H:%M:%S')
        values=dict(InpNativeConformance='true',InpConformanceControlSha256=self.control_hash,
                    InpRunManifest=i['manifest_path'].replace('/','\\'),InpManifestFileSha256=v3.digest(raw),
                    InpManifestSha256=f['run_id'],InpPurpose=DOMAIN,InpGate='0',InpRootSha256='',InpDetachedAuthorizationToken='',
                    InpConfigurationId='0',InpEvaluationStart=iso(f['start_msc']),InpEvaluationEndExclusive=iso(f['end_msc']),
                    InpBranch='RECORDED',InpExpectedSymbol=f['symbol'],InpExecutionAdapter='NATIVE',InpScenario='BASELINE_20MS',
                    InpDelayMs='20',InpTesterModel='4',InpLocalAgentsOnly='true',InpRemoteAgentsDisabled='true',InpCloudAgentsDisabled='true',
                    InpZeroEntryDiagnostic='false',InpWorkloadDryRun='false',
                    InpCalendarIntervalsFile=i['calendar_path'].replace('/','\\'),InpCalendarFileSha256=v3.digest(self.calendar_raw),
                    InpCalendarSha256=v3.digest(self.calendar_raw))
        return dict(manifest=raw,calendar=self.calendar_raw,set_values=values,set_bytes=serialize_tester_set(values),
                    required_ini=dict(Optimization='0',ExecutionMode='20',Model='4',Visual='0',UseLocal='1',UseRemote='0',UseCloud='0'))


    def verify_launch_record(self, reference, *, loader_binding_root=None, expected_terminal_root=None):
        """Independent post-launch custodianship; no record is selected by an archive."""
        self._stable();record=v3.parse_json(self._read(reference))
        required={'domain','fixture_id','run_id','control_hash','source_hash','executable_hash','profile_hash',
                  'set_file','ini_file','manifest_file','calendar_file','consumed_set_hash','consumed_ini_hash',
                  'consumed_manifest_hash','consumed_calendar_hash','terminal_build','agent_build','compiler_build',
                   'account_fingerprint','mql_tester','dll_disabled','local_only','process_exited','loader_binding_receipt','expected_terminal_instance'}
        v3.require(set(record)==required and record['domain']==DOMAIN and record['fixture_id']==self.fixture['fixture_id'] and
                   record['run_id']==self.fixture['run_id'] and record['control_hash']==self.control_hash,'CONFORMANCE_LAUNCH_BINDING')
        binding=self.binding()
        for key,bkey in [('source_hash','source_manifest_hash'),('executable_hash','executable_hash'),('profile_hash','tester_profile_hash')]:
            v3.require(record[key]==binding[bkey],'CONFORMANCE_LAUNCH_ARTIFACT_MISMATCH')
        for key in ('set','ini','manifest','calendar'):
            raw=self._read(record[key+'_file'])
            v3.require(v3.digest(raw)==record['consumed_'+key+'_hash'],'CONSUMED_INPUT_HASH_MISMATCH')
            if key=='set':v3.require(raw==self.prepare_inputs()['set_bytes'],'CONSUMED_SET_VALUES_MISMATCH')
            if key=='ini':
                import configparser
                ini=configparser.ConfigParser(interpolation=None,strict=True);ini.optionxform=str;ini.read_string(raw.decode('utf-8-sig'))
                v3.require('Tester' in ini and all(ini['Tester'].get(k)==value for k,value in self.prepare_inputs()['required_ini'].items()),'CONSUMED_INI_PROFILE_MISMATCH')
            if key in ('manifest','calendar'):v3.require(raw==self.prepare_inputs()[key],'CONSUMED_INPUT_BYTES_MISMATCH')
        v3.require(loader_binding_root is not None and expected_terminal_root is not None,'INDEPENDENT_LOADER_BINDING_REQUIRED')
        binding=read_pinned_loader_binding(loader_binding_root,record['loader_binding_receipt'])
        validate_loader_binding(self,binding,expected_ini_raw=self._read(record['ini_file']),expected_terminal_reference=record['expected_terminal_instance'],expected_terminal_root=expected_terminal_root)
        v3.require(all(record[k]==6140 for k in ('terminal_build','agent_build','compiler_build')) and
                   all(record[k] is True for k in ('mql_tester','dll_disabled','local_only','process_exited')) and
                   v3.hash_value(record['account_fingerprint']),'CONFORMANCE_LAUNCH_PROFILE')
        return record
