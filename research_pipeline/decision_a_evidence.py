"""Controlled-tester V3 verification. No trading, launch, or historical fallback.

The caller supplies independently resolved expectations, never a payload-selected
trust directory. Native economics are checked with Decimal, not account equity.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
import hashlib
import json
import re
import stat
from pathlib import Path

CONTRACT = 'NATIVE_GROUP_LIFECYCLE_CONTRACT_V3'
PACKAGE = 'NATIVE_GROUP_LIFECYCLE_PACKAGE_V3'
SEMANTICS = 'PARTIAL_POSITION_COMPONENTS_V1'
ADOPTION = '335148375AF80997CCEFF73F883F358EDCB1876419F328D071C7F3E94331EFAF'
NATIVE_PROOF = 'D429EA8BC417878320CB9E5A786A252C7D292E5298C946CA056CE3F8B56C93A7'

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'DUPLICATE_FIELD')
        result[key] = value
    return result

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)

def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else value.encode()).hexdigest().upper()

def number(value):
    require(not isinstance(value, bool) and isinstance(value, (int, float, str, Decimal)), 'INVALID_NUMBER')
    try:
        result = Decimal(str(value))
    except InvalidOperation as exc:
        raise ValueError('INVALID_NUMBER') from exc
    require(result.is_finite(), 'NONFINITE_NUMBER')
    return result

def hash_value(value):
    return isinstance(value, str) and len(value) == 64 and all(c in '0123456789ABCDEF' for c in value)

def lock_capture_paths(paths):
    """Hold Windows deny-write/delete handles through capture and parsing.

    These are read-only handles. They are not execution/profile authority.
    A different platform needs an equally strong implementation, not an unlocked fallback.
    """
    import os
    import ctypes
    from ctypes import wintypes
    from contextlib import contextmanager

    @contextmanager
    def locked():
        require(os.name == 'nt', 'IMMUTABLE_CAPTURE_LOCK_UNAVAILABLE')
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        create = api.CreateFileW
        create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                           wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        create.restype = wintypes.HANDLE
        close = api.CloseHandle
        close.argtypes = [wintypes.HANDLE]
        close.restype = wintypes.BOOL
        handles = []
        try:
            for path in paths:
                handle = create(str(path), 0x80000000, 1, None, 3, 0x80, None)
                if handle == ctypes.c_void_p(-1).value:
                    raise ctypes.WinError(ctypes.get_last_error())
                handles.append(handle)
            yield
        finally:
            for handle in reversed(handles):
                close(handle)
    return locked()


@dataclass(frozen=True)
class ImmutableInput:
    """One capture used for hashing and parsing. No reopen/reload API."""
    path: str
    sha256: str
    data: bytes

    @classmethod
    def capture(cls, root: Path, reference: dict):
        require(set(reference) == {'path', 'sha256'}, 'INPUT_REFERENCE_FIELDS')
        name = reference['path']
        require(isinstance(name, str) and name not in ('', '.', '..') and
                '/' not in name and '\\' not in name and ':' not in name and
                re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}', name) is not None, 'INPUT_PATH_INVALID')
        require(hash_value(reference['sha256']), 'INPUT_PIN_INVALID')
        root = Path(root)
        path = root / name
        require(not root.is_symlink() and not path.is_symlink() and
                not (getattr(path.stat(), 'st_file_attributes', 0) & 0x400), 'INPUT_LINK_FORBIDDEN')
        require(stat.S_ISREG(path.stat().st_mode), 'INPUT_REGULAR_FILE_REQUIRED')
        with path.open('rb') as stream:
            raw = stream.read(10_000_001)
        require(0 < len(raw) <= 10_000_000, 'INPUT_SIZE_INVALID')
        require(digest(raw) == reference['sha256'], 'INPUT_PIN_MISMATCH')
        return cls(name, reference['sha256'], raw)

    def json(self):
        return json.loads(self.data.decode('utf-8-sig'), object_pairs_hook=unique)

    def calendar(self):
        lines = self.data.decode('utf-8-sig').splitlines()
        require(lines and lines[0] == 'type,start_msc,end_msc,identity', 'CALENDAR_HEADER')
        rows = []
        for line in lines[1:]:
            if not line:
                continue
            row = line.split(',')
            require(len(row) == 4 and row[0] and row[3], 'CALENDAR_ROW')
            require(row[1].isdigit() and row[2].isdigit(), 'CALENDAR_TIME')
            start, end = int(row[1]), int(row[2])
            require(0 < start < end and (not rows or start >= rows[-1][1]), 'CALENDAR_ORDER')
            rows.append((row[0], start, end, row[3]))
        require(rows, 'CALENDAR_EMPTY')
        return tuple(rows)

SWAP_FACTS = dict(SYMBOL_SWAP_MODE='1', SYMBOL_SWAP_ROLLOVER3DAYS='3', SYMBOL_DIGITS='2',
    SYMBOL_SWAP_LONG='-280.56', SYMBOL_SWAP_SHORT='-184.08', SYMBOL_VOLUME_MIN='.01',
    SYMBOL_VOLUME_STEP='.01', SYMBOL_VOLUME_MAX='100', SYMBOL_POINT='.01',
    SYMBOL_TRADE_TICK_SIZE='.01', SYMBOL_TRADE_CONTRACT_SIZE='1',
    SYMBOL_SWAP_MONDAY='1', SYMBOL_SWAP_TUESDAY='1', SYMBOL_SWAP_WEDNESDAY='3',
    SYMBOL_SWAP_THURSDAY='1', SYMBOL_SWAP_FRIDAY='1', SYMBOL_SWAP_SATURDAY='0', SYMBOL_SWAP_SUNDAY='0')

def validate_profile(profile, side='LONG', *, conformance=None):
    require(isinstance(profile, dict), 'SWAP_PROFILE_NOT_AUTHORIZED')
    if conformance is not None:
        from .native_conformance_control import ConformanceControl
        require(type(conformance) is ConformanceControl,'INDEPENDENT_CONFORMANCE_CONTEXT_REQUIRED')
        conformance.validate_build_values(profile)
    require((conformance is not None or profile.get('accepted_proof_sha256') == NATIVE_PROOF) and
            profile.get('server') == 'JustMarkets-Demo2' and profile.get('symbol') == 'ETHUSD.s' and
            (conformance is not None or all(profile.get(k) == 6140 for k in ('terminal_build', 'compiler_build', 'agent_build'))),
            'SWAP_PROFILE_NOT_AUTHORIZED')
    require(profile.get('local') is True and profile.get('visual') is False and
            profile.get('dll') is False and profile.get('command_bridge') is False and
            profile.get('shared_trading_input') is False, 'TESTER_PROFILE_INVALID')
    require(profile.get('swap_transition_rule_hash')==SWAP_TRANSITION_ADOPTION, 'SWAP_TRANSITION_RULE_NOT_AUTHORIZED')
    facts = profile.get('facts', {})
    for key, expected in SWAP_FACTS.items():
        require(key in facts and number(facts[key]) == number(expected), 'SWAP_PROFILE_NOT_AUTHORIZED')
    # No separately accepted SHORT proof is currently in the governing contract.
    if conformance is None:
        require(side == 'LONG', 'NATIVE_CONFORMANCE_REQUIRED_BEFORE_SUCCESSOR_READINESS')
    else:
        from .native_conformance_control import ConformanceControl
        require(type(conformance) is ConformanceControl,'INDEPENDENT_CONFORMANCE_CONTEXT_REQUIRED')
        conformance.validate_profile(profile, side)

def classify_execution(requested, volumes, *, terminal, confirmed_executed=None, no_fill_receipt=False):
    if not terminal or confirmed_executed is None:
        return 'EXECUTION_EVIDENCE_INCOMPLETE'
    q = number(requested)
    require(q > 0, 'REQUEST_VOLUME_INVALID')
    values = [number(x) for x in volumes]
    require(all(x > 0 for x in values), 'DEAL_VOLUME_INVALID')
    total = sum(values, Decimal(0))
    confirmed = number(confirmed_executed)
    require(confirmed >= 0, 'EXECUTION_RECEIPT_VOLUME_INVALID')
    if total < confirmed:
        return 'EXECUTION_EVIDENCE_INCOMPLETE'
    require(total == confirmed, 'EXECUTION_RECEIPT_CALLBACK_CONFLICT')
    if not values:
        return 'FOK_REJECTED_NO_FILL' if no_fill_receipt else 'EXECUTION_EVIDENCE_INCOMPLETE'
    if total < q:
        return 'PARTIAL_ORDER_EXECUTION'
    require(total == q, 'EXECUTED_VOLUME_EXCEEDS_REQUEST')
    return 'FOK_FULL_SINGLE_DEAL' if len(values) == 1 else 'FOK_FULL_MULTI_DEAL'

@dataclass
class ExposureControl:
    """Research validity never acts as the monitoring-enable flag."""
    invalid: bool = False
    exposure: str = 'FULL_POSITION'
    terminal: bool = False
    residual: dict | None = None
    containment_attempts: int = 0
    reason: str = ''
    monitoring: bool = True

    def invalidate(self, reason):
        self.invalid = True
        self.reason = self.reason or reason

    def observe(self, classification, *, terminal, residual, expected_position):
        self.terminal = terminal
        if classification in ('FOK_FULL_MULTI_DEAL', 'PARTIAL_ORDER_EXECUTION'):
            self.invalidate(classification)
        require(self.monitoring, 'MONITORING_DISABLED')
        if not terminal or not residual or residual.get('read_ok') is not True or residual.get('position_id') != expected_position:
            self.residual = None
            self.exposure = 'AMBIGUOUS_EXPOSURE_FAIL_CLOSED'
            return
        require(number(residual['volume']) >= 0, 'RESIDUAL_VOLUME_INVALID')
        self.residual = dict(residual)
        self.exposure = 'QUARANTINED_MONITORED_POSITION' if self.invalid else 'REDUCED_POSITION'

    def containment(self):
        require(self.reason in ('FOK_FULL_MULTI_DEAL', 'PARTIAL_ORDER_EXECUTION'), 'CONTAINMENT_CAUSE_NOT_AUTHORIZED')
        require(self.invalid and self.terminal and self.residual is not None and
                self.containment_attempts == 0 and number(self.residual['volume']) > 0, 'CONTAINMENT_NOT_AUTHORIZED')
        self.containment_attempts = 1  # consumed at submission, including rejection
        self.exposure = 'CONTAINMENT_PENDING'
        return dict(classification='INVALID_RUN_CONTAINMENT_FLATTEN', filling='ORDER_FILLING_FOK',
                    position_id=self.residual['position_id'], volume=self.residual['volume'])

    def containment_result(self, *, flat_authenticated, residual=None):
        require(self.containment_attempts == 1 and self.invalid, 'CONTAINMENT_STATE_INVALID')
        self.residual = residual
        self.exposure = ('FLAT_CONFIRMED' if flat_authenticated else
                         'QUARANTINED_MONITORED_POSITION' if residual and residual.get('read_ok') is True else
                         'AMBIGUOUS_EXPOSURE_FAIL_CLOSED')

SWAP_TRANSITION_RULE = 'SWAP_TRANSITION_CONSERVATION_V1'
SWAP_TRANSITION_ADOPTION = 'BEE9D303C1FBC804C9F0993685B8CBD2B9FCF43F226CD7BFBA5D73C972C9E772'
TRANSITION_FIELDS = {'kind','adopted_rule_hash','native_swap_profile_hash','run_id','group_id',
    'position_id','position_ticket','symbol','magic','side','request_intent_hash','request_receipt_hash',
    'order_id','deal_id','deal_fact_hash','before_snapshot_hash','after_snapshot_hash',
    'Ub','Ds','Ua','Vb','q','Vr','P0','S0','read_flags','precision_rule',
    'causal_interval_accrual_claim','transition_conservation'}


def validate_swap_transition(receipt, before, deal, after, *, binding, original, precision, profile):
    """Authenticate linked B/D/A facts before checking the adopted invariant.

    Call only after independently controlled package/profile verification and
    exact native fact/reference validation. No hidden-event absence is claimed.
    """
    require(type(receipt) is dict and set(receipt)==TRANSITION_FIELDS, 'SWAP_TRANSITION_RECEIPT_FIELDS')
    require(receipt['kind']==SWAP_TRANSITION_RULE+'_RECEIPT' and
            receipt['adopted_rule_hash']==SWAP_TRANSITION_ADOPTION==profile.get('swap_transition_rule_hash'),
            'SWAP_TRANSITION_RULE_NOT_AUTHORIZED')
    require(receipt['causal_interval_accrual_claim']=='NOT_MADE' and
            receipt['transition_conservation']=='RECONCILED', 'SWAP_TRANSITION_CLAIM_INVALID')
    require(receipt['native_swap_profile_hash']==profile['native_swap_profile_hash'], 'SWAP_PROFILE_NOT_AUTHORIZED')
    require(receipt['run_id']==binding['run_id'] and receipt['group_id']==binding['group_id'] and
            receipt['position_id']==before['position_id']==after['position_id']==deal['position_id']==original['position_id'] and
            receipt['position_ticket']==before['position_ticket']==after['position_ticket'] and
            receipt['symbol']==binding['symbol'] and receipt['magic']==12001 and receipt['side']==original['side'],
            'SWAP_TRANSITION_IDENTITY_INVALID')
    require(receipt['order_id']==deal['order_id'] and receipt['deal_id']==deal['deal_id'] and
            receipt['request_intent_hash']==deal['request_intent_hash'] and receipt['request_receipt_hash']==deal['request_receipt_hash'] and
            receipt['deal_fact_hash']==deal['fact_hash'] and receipt['before_snapshot_hash']==before['snapshot_hash'] and
            receipt['after_snapshot_hash']==after['snapshot_hash'] and after['predecessor_deal_id']==deal['deal_id'],
            'SWAP_TRANSITION_LINK_INVALID')
    require(deal['role']=='SAFETY_REDUCTION' and before['predecessor_deal_id']!=deal['deal_id'] and
            before['native_or_observation_time']<=deal['native_time_msc']<=after['native_or_observation_time'],
            'SWAP_TRANSITION_SEQUENCE_INVALID')
    require(receipt['read_flags']=={'POSITION_SWAP_BEFORE':True,'DEAL_SWAP':True,'POSITION_SWAP_AFTER':True} and
            before['read_flags']['swap'] is True and after['read_flags']['swap'] is True and deal['read_flags']['swap'] is True,
            'SWAP_TRANSITION_READ_FAILED')
    require(receipt['precision_rule']==precision and precision['currency_precision']==8,
            'SWAP_TRANSITION_PRECISION_INVALID')
    pairs=[('Ub',before['position_swap']),('Ds',deal['swap']),('Ua',after['position_swap']),
           ('Vb',before['Vr']),('q',deal['executed_volume']),('Vr',after['Vr']),('P0',original['P0']),('S0',original['S0'])]
    require(all(number(receipt[k])==number(v) for k,v in pairs) and
            number(before['Vr'])==number(deal['executed_volume'])+number(after['Vr']) and
            number(deal['requested_volume'])==number(deal['executed_volume']), 'SWAP_TRANSITION_VALUES_UNBOUND')
    # Exact equality at Stage13 signed component serialization precision.
    q=Decimal('0.00000001')
    require(number(before['position_swap']).quantize(q)==
            (number(deal['swap'])+number(after['position_swap'])).quantize(q), 'SWAP_TRANSITION_CONSERVATION_FAIL')


def assemble_native_archive(raw, binding, profile, authority_artifacts, *, expected_capture_hash, expected_configuration, conformance=None):
    """Build unsealed R/S/A from an independently pinned native capture.

    Pure bytes in/out. No seal, approval, root, result acceptance or file write.
    The control adapter, never the captured payload, supplies all expectations.
    Native-runtime conformance of the producer remains a separate requirement.
    """
    require(digest(raw)==expected_capture_hash, 'NATIVE_CAPTURE_PIN_MISMATCH')
    capture=parse_json(raw)
    require(set(capture)=={'kind','run_id','group_id','outcome','records'} and
            capture['kind']=='NATIVE_LIFECYCLE_CAPTURE_V3' and
            capture['run_id']==binding['run_id'] and capture['group_id']==binding['group_id'], 'NATIVE_CAPTURE_BINDING')
    side = 'LONG' if conformance is None else conformance.side
    if conformance is not None: conformance.validate_binding(binding)
    validate_profile(profile, side, conformance=conformance)
    rows=capture['records'];require(type(rows) is list and 1<=len(rows)<=256,'NATIVE_CAPTURE_CARDINALITY')
    support={}
    def add(role,value,serialized=False):
        data=value if serialized else json_bytes(value)
        path='support/'+role.replace(':','_').lower()+('.bin' if serialized else '.json')
        require(path not in support or support[path]==(role,data),'NATIVE_SUPPORT_CONFLICT')
        support[path]=(role,data);return digest(data)
    def scoped(**kw):return dict(run_id=binding['run_id'],group_id=binding['group_id'],**kw)
    originals=[];native_deals={};native_positions=[];requests=[];terminals={};terminal_captures=[];terminal_authorities={};terminal_sequences={};prepared=[];committed=[]
    pending_before=None;pending_intent=None;passive_stop=False;pending_check=None
    for seq,row in enumerate(rows,1):
        require(type(row) is dict and set(row)=={'role','payload'} and type(row['payload']) is str,'NATIVE_ROW_FIELDS')
        role=row['role'];payload=row['payload']
        require(not role.startswith('INVALID') and role!='INVALID_LATCHED','INVALID_RUN_CONTAINMENT_EVIDENCE')
        if role=='DEAL_ADD':
            fields=payload.split('|');require(len(fields)==18,'NATIVE_DEAL_FORMAT')
            d=dict(zip(('ticket','order','position','time','entry','type','reason','magic','symbol','volume','price','profit','commission','fee','swap','sl','reads','valid'),fields))
            for k in ('ticket','order','position','time','entry','type','reason','magic','reads'):d[k]=int(d[k])
            require(d['reads']==65535 and d['valid']=='true' and d['magic']==12001 and d['symbol']==binding['symbol'],'NATIVE_DEAL_READ_FAILED')
            require(d['type'] in (0,1) and d['entry'] in (0,1),'SWAP_PROFILE_OUTSIDE_SUPPORTED_SEMANTICS')
            if d['ticket'] in native_deals:require(native_deals[d['ticket']][0]==d,'CONFLICTING_DUPLICATE_DEAL')
            else:native_deals[d['ticket']]=(d,seq)
        elif role=='ORIGINAL': originals.append(parse_json(payload.encode()))
        elif role in ('BEFORE_REQUEST','RECONCILED_POSITION','TERMINAL_POSITION'):
            position=parse_json(payload.encode());require(position.get('valid') is True and (number(position['volume'])==0 or position.get('reads')==2047),'NATIVE_POSITION_READ_FAILED')
            native_positions.append((role,position,seq))
            if role=='BEFORE_REQUEST':pending_before=position
        elif role=='BEFORE_REQUEST_INTENT':pending_intent=parse_json(payload.encode())
        elif role=='ORDER_CHECK':
            pending_check=parse_json(payload.encode())
            validate_order_check(pending_check,binding,conformance=conformance)
        elif role=='REQUEST_RESULT':
            result=parse_json(payload.encode())
            if conformance is not None:require(pending_check is not None,'NATIVE_ORDER_CHECK_REQUIRED')
            if pending_check is not None:
                require(number(pending_check['request']['volume'])==number(result['volume']), 'ORDER_CHECK_RESULT_VOLUME_MISMATCH')
            requests.append((result,pending_intent,pending_before,seq,pending_check));pending_check=None;pending_intent=None;pending_before=None
        elif role=='STATIC_PROTECTIVE_STOP_INTENT':passive_stop=True
        elif role=='ORDER_TERMINAL_OBSERVATION':
            t=parse_json(payload.encode())
            if conformance is not None:
                # Preserve every native terminal callback, but select only a
                # valid HISTORY_ADD snapshot as lifecycle terminal authority.
                # ORDER_DELETE is retained evidence, never an authority source.
                required={'order','position','state','type','unfilled','symbol','transaction_type','capture_sequence','raw_transaction_volume'}
                require(type(t) is dict and set(t)==required,'NATIVE_TERMINAL_CALLBACK_FIELDS')
                require(type(t['transaction_type']) is int and t['transaction_type'] in (2,3) and
                        type(t['capture_sequence']) is int and t['capture_sequence']>0 and
                        type(t['order']) is int and t['order']>0 and type(t['position']) is int and t['position']>0 and
                        type(t['state']) is int and type(t['type']) is int and type(t['symbol']) is str and
                        type(t['unfilled']) is str and type(t['raw_transaction_volume']) is str and
                        number(t['raw_transaction_volume'])==number(t['unfilled']),
                        'NATIVE_TERMINAL_CAPTURE_INVALID')
                raw_observation=dict(order=t['order'],position=t['position'],state=t['state'],type=t['type'],
                    unfilled=t['unfilled'],symbol=t['symbol'],transaction_type=t['transaction_type'],
                    capture_sequence=t['capture_sequence'],raw_transaction_volume=t['raw_transaction_volume'])
                terminal_captures.append(raw_observation)
                prior_sequence=terminal_sequences.get(t['capture_sequence'])
                require(prior_sequence is None or prior_sequence==raw_observation,'CONFLICTING_ORDER_TERMINALITY')
                terminal_sequences[t['capture_sequence']]=raw_observation
                continue
            if t['state'] not in (2,4,5,6):continue
            # Diagnostic callback identity cannot turn an otherwise identical
            # terminal observation into an economic/terminality conflict.
            terminal={key:t[key] for key in ('order','position','state','type','unfilled','symbol')}
            if t['order'] in terminals:require(terminals[t['order']]==terminal,'CONFLICTING_ORDER_TERMINALITY')
            terminals[t['order']]=terminal
        elif role=='STAGE13_PREPARED':prepared.append(payload)
        elif role=='STAGE13_COMMITTED':committed.append(parse_json(payload.encode()))
        elif role=='EXTERNAL_CASH_EVIDENCE':
            cash=payload.split('|')
            require(len(cash)==18 and int(cash[0])>0 and int(cash[3])>0 and int(cash[5])==2 and int(cash[16])&16 and int(cash[1])==int(cash[2])==0,'EXTERNAL_CASH_CLASSIFICATION_INVALID')
            require(all(number(cash[i])==0 for i in (12,13,14)),'SWAP_PROFILE_OUTSIDE_SUPPORTED_SEMANTICS')
            # Retained in the independently pinned raw capture, excluded from group P&L.
            continue
        else:raise ValueError('UNSUPPORTED_NATIVE_CAPTURE_ROLE:'+str(role))
    if conformance is not None:
        ended_states=(2,4,5,6)
        for t in terminal_captures:
            if t['transaction_type']!=3 or t['state'] not in ended_states:continue
            matching=[r for r in requests if r[0]['order']==t['order']]
            if len(matching)!=1 or matching[0][4] is None:continue
            request=matching[0][4]['request'];requested=number(request['volume']);unfilled=number(t['unfilled'])
            valid=(0<=unfilled<=requested and t['type']==request['type'] and
                   (t['state']!=4 or unfilled==0))
            if not valid:continue
            authority={key:t[key] for key in ('order','position','state','type','unfilled','symbol')}
            if t['order'] in terminal_authorities:
                prior=terminal_authorities[t['order']]
                prior_actual=requested-number(prior['unfilled'])
                prior_no_fill=prior_actual==0 and prior['state']!=4
                current_no_fill=requested-unfilled==0 and t['state']!=4
                same_identity=(prior['order']==authority['order'] and prior['position']==authority['position'] and
                    prior['type']==authority['type'] and prior['symbol']==authority['symbol'])
                require(same_identity and prior_actual==requested-unfilled and prior_no_fill==current_no_fill,
                        'CONFLICTING_ORDER_TERMINALITY')
                # Equivalent terminal economics are idempotent; choose a stable
                # representative independent of callback arrival order.
                priority={4:0,5:1,6:2,2:3}
                if priority[t['state']]<priority[prior['state']]:terminal_authorities[t['order']]=authority
            else:terminal_authorities[t['order']]=authority
            terminals[t['order']]=terminal_authorities[t['order']]
    require(len(originals)==1 and len(prepared)==1 and len(committed)==1 and 1<=len(native_deals)<=3,'NATIVE_LIFECYCLE_CARDINALITY')
    original=originals[0];require(type(expected_configuration) is int and original.get('configuration_id')==expected_configuration,'NATIVE_CONFIGURATION_MISMATCH')
    require(original['run_id']==binding['run_id'] and original['group_id']==binding['group_id'] and original['profile_hash']==binding['tester_profile_hash'],'NATIVE_ORIGINAL_BINDING')
    native=list(native_deals.values());native.sort(key=lambda pair:(pair[0]['time'],pair[1]))
    entry=native[0][0];require(entry['entry']==0 and entry['type']==(0 if side=='LONG' else 1),'NATIVE_ENTRY_OR_SIDE_UNSUPPORTED')
    live=[(role,p,seq) for role,p,seq in native_positions if number(p['volume'])>0]
    require(live,'EFFECTIVE_ENTRY_STOP_MISSING');entry_pos=next((p for role,p,seq in live if role=='RECONCILED_POSITION'),None)
    require(entry_pos is not None and entry_pos['position_id']==entry['position'] and number(entry_pos['volume'])==number(original['V0']),'EFFECTIVE_ENTRY_STOP_MISSING')
    require((number(original['S0'])<number(entry_pos['basis'])) if side=='LONG' else (number(original['S0'])>number(entry_pos['basis'])), 'ENTRY_STOP_DIRECTION_INVALID')
    o={k:original[k] for k in ('V0','S0','E0','R0')};o.update(P0=entry_pos['basis'],side=side,position_id=entry['position'],entry_intent_hash='',entry_effective_stop_hash='')
    roles={'configuration_hash':'CONFIGURATION_SPECIFICATION','source_manifest_hash':'SOURCE_MANIFEST','executable_hash':'EXECUTABLE','specification_hash':'COMBINED_SPECIFICATION','decision_a_hash':'DECISION_A_SPECIFICATION','decision_s_hash':'DECISION_S_SPECIFICATION','freeze_receipt_hash':'FREEZE_RECEIPT','execution_receipt_hash':'EXECUTION_RECEIPT','tester_profile_hash':'TESTER_PROFILE'}
    if conformance is not None:
        roles.pop('freeze_receipt_hash');roles.pop('execution_receipt_hash')
        roles['conformance_control_hash']='CONFORMANCE_CONTROL'
        roles['fixture_specification_hash']='FIXTURE_SPECIFICATION'
        roles['launch_record_hash']='CONFORMANCE_LAUNCH_RECORD'
    for key,role in roles.items():require(add(role,authority_artifacts[role],True)==binding[key],'INDEPENDENT_AUTHORITY_ARTIFACT_MISMATCH:'+role)
    if conformance is not None:
        for key in ('SET','INI','MANIFEST','CALENDAR'):add('CONFORMANCE_LAUNCH_'+key,authority_artifacts['CONFORMANCE_LAUNCH_'+key],True)
    pr=dict(volume_step=profile['facts']['SYMBOL_VOLUME_STEP'],volume_digits=8,currency='USD',currency_precision=8,
            price_convention_hash=add('PRICE_CONVENTION',authority_artifacts['PRICE_CONVENTION'],True),arithmetic_contract_hash=add('ARITHMETIC_CONTRACT',authority_artifacts['ARITHMETIC_CONTRACT'],True))
    native_hash=add('NATIVE_CAPTURE',raw,True)
    swap_profile=add('NATIVE_SWAP_PROFILE',authority_artifacts['NATIVE_SWAP_PROFILE'],True)
    require(swap_profile==profile['native_swap_profile_hash'],'SWAP_PROFILE_NOT_AUTHORIZED')
    snapshots=[];deals=[];swaps=[];previous='0'*64
    def snapshot(pos,predecessor,sid):
        require(pos['position_id']==o['position_id'] and pos['symbol']==binding['symbol'] and pos['magic']==12001 and pos['side']==(0 if side=='LONG' else 1),'NATIVE_POSITION_IDENTITY')
        snap=dict(snapshot_id=sid,predecessor_deal_id=predecessor,position_id=pos['position_id'],position_ticket=pos['position_ticket'],native_or_observation_time=pos['time_msc'],time_source='CALLBACK_OR_TICK_OBSERVATION_MSC',Vr=pos['volume'],P0=pos['basis'],S0=pos['sl'],bid=pos['bid'],ask=pos['ask'],mark=pos['mark'],position_swap=pos['swap'],read_flags={k:True for k in ('position_id','ticket','volume','basis','sl','swap','quote','mark','symbol','magic','side')})
        snap['snapshot_hash']=add('POSITION_SNAPSHOT:'+sid,snap);snapshots.append(snap);return snap
    entry_snapshot=snapshot(entry_pos,entry['ticket'],'entry')
    o['entry_effective_stop_hash']=add('ENTRY_EFFECTIVE_STOP',scoped(position_id=o['position_id'],read_ok=True,S0=o['S0'],V0=o['V0'],P0=o['P0'],profile_hash=binding['tester_profile_hash'],post_entry_mutation_authorized=False,context_integrity=True,unexplained_modification=False,observation_overflow=False,observation_time_msc=entry_pos['time_msc'],native_capture_hash=native_hash))
    remaining=number(o['V0'])
    for i,(nd,seq) in enumerate(native):
        require(nd['position']==o['position_id'],'FOREIGN_NATIVE_POSITION')
        require(nd['type']==((0 if side=='LONG' else 1) if i==0 else (1 if side=='LONG' else 0)), 'NATIVE_DEAL_DIRECTION_MISMATCH')
        matching=[r for r in requests if r[0]['order']==nd['order']]
        passive=i>0 and nd['reason']==4 and passive_stop and not matching
        require(len(matching)==1 or passive,'NATIVE_REQUEST_BINDING_MISSING')
        req=matching[0] if matching else None
        role='ENTRY' if i==0 else 'SAFETY_REDUCTION' if req and req[1] and req[1]['intent']==1 else 'FINAL_CLOSE'
        q=o['V0'] if i==0 else req[1]['volume'] if req and req[1] else str(remaining)
        t=terminals.get(nd['order']);require(t is not None and t['symbol']==binding['symbol'] and t['state']==4 and t['type']==nd['type'] and number(t['unfilled'])==0 and number(nd['volume'])==number(q),'NATIVE_TERMINALITY_OR_CARDINALITY')
        if req and req[4] is not None:
            cr=req[4]['request']
            require(cr['type']==nd['type'] and number(cr['volume'])==number(q) and cr['position']==(0 if i==0 else entry_pos['position_ticket']), 'ORDER_CHECK_DEAL_LINK')
        reason='STATIC_PROTECTIVE_STOP' if passive else 'ENTRY' if i==0 else req[1]['reason']
        intent=scoped(order_id=nd['order'],role=role,requested_volume=q,filling='ORDER_FILLING_FOK',context_integrity=True,governed_reason=reason)
        receipt=scoped(order_id=nd['order'],terminal=True,read_ok=True,deal_ids=[nd['ticket']],executed_volume=nd['volume'],position_id=o['position_id'],classification='FOK_FULL_SINGLE_DEAL')
        before=None;after=None
        if i==0:intent.update({k:o[k] for k in ('V0','E0','R0','S0')})
        if passive:intent['entry_intent_hash']=o['entry_intent_hash']
        if role=='SAFETY_REDUCTION':
            require(req[2] is not None,'IMMEDIATE_BEFORE_NATIVE_SNAPSHOT_MISSING')
            before=snapshot(req[2],deals[-1]['deal_id'],'before-reduction')
            after_pos=next((p for typ,p,idx in live if typ=='RECONCILED_POSITION' and idx>seq and number(p['volume'])==remaining-number(q)),None)
            require(after_pos is not None,'RESIDUAL_NATIVE_SNAPSHOT_MISSING')
            after=snapshot(after_pos,nd['ticket'],'after-reduction')
            intent['immediate_before_snapshot_hash']=before['snapshot_hash'];receipt['reconciled_after_snapshot_hash']=after['snapshot_hash']
        if role=='FINAL_CLOSE':
            require(number(q)==remaining,'FINAL_NATIVE_VOLUME_MISMATCH')
            receipt['flat_state_hash']=add('FLAT_STATE:'+str(nd['ticket']),scoped(position_id=o['position_id'],order_id=nd['order'],terminal=True,flat_authenticated=True))
        ih=add('REQUEST_INTENT:'+str(nd['order']),intent);rh=add('REQUEST_RECEIPT:'+str(nd['order']),receipt)
        d=dict(deal_id=nd['ticket'],order_id=nd['order'],position_id=nd['position'],request_intent_hash=ih,request_receipt_hash=rh,role=role,requested_volume=q,executed_volume=nd['volume'],native_time_msc=nd['time'],capture_sequence=seq,price=nd['price'],profit=nd['profit'],commission=nd['commission'],fee=nd['fee'],swap=nd['swap'],reason={3:'DEAL_REASON_EXPERT',4:'DEAL_REASON_SL'}.get(nd['reason'],'UNSUPPORTED'),exit_sl=None if i==0 else nd['sl'],read_flags={k:True for k in ('volume','price','profit','commission','fee','swap','reason','identity','time')},previous_fact_hash=previous)
        d['read_flags']['exit_sl']='NOT_APPLICABLE' if i==0 else True
        d['fact_hash']=add('DEAL:'+str(d['deal_id']),d);previous=d['fact_hash'];deals.append(d)
        if i==0:o['entry_intent_hash']=ih
        else:remaining-=number(q)
        if role=='SAFETY_REDUCTION':
            transition=scoped(kind=SWAP_TRANSITION_RULE+'_RECEIPT',adopted_rule_hash=SWAP_TRANSITION_ADOPTION,native_swap_profile_hash=swap_profile,position_id=o['position_id'],position_ticket=before['position_ticket'],symbol=binding['symbol'],magic=12001,side=o['side'],request_intent_hash=ih,request_receipt_hash=rh,order_id=d['order_id'],deal_id=d['deal_id'],deal_fact_hash=d['fact_hash'],before_snapshot_hash=before['snapshot_hash'],after_snapshot_hash=after['snapshot_hash'],Ub=before['position_swap'],Ds=d['swap'],Ua=after['position_swap'],Vb=before['Vr'],q=q,Vr=after['Vr'],P0=o['P0'],S0=o['S0'],read_flags={'POSITION_SWAP_BEFORE':True,'DEAL_SWAP':True,'POSITION_SWAP_AFTER':True},precision_rule=pr,causal_interval_accrual_claim='NOT_MADE',transition_conservation='RECONCILED')
            validate_swap_transition(transition,before,d,after,binding=binding,original=o,precision=pr,profile=profile)
            th=add('SWAP_INTERVAL:'+str(d['deal_id']),transition)
            swaps.append(dict(deal_id=d['deal_id'],before_snapshot_hash=before['snapshot_hash'],after_snapshot_hash=after['snapshot_hash'],before_swap=before['position_swap'],realized_swap=d['swap'],after_swap=after['position_swap'],interval_accrual='0',interval_authority_hash=th,native_swap_profile_hash=swap_profile,status='RECONCILED'))
    boundary=capture['outcome']=='EVALUATOR_BOUNDARY';require(boundary or capture['outcome']=='NORMAL_CLOSE','NATIVE_OUTCOME_INVALID')
    sealed=None
    if boundary:
        terminal_positions=[p for role,p,seq in native_positions if role=='TERMINAL_POSITION'];require(len(terminal_positions)==1,'SEALED_NATIVE_POSITION_MISSING')
        sealed=snapshot(terminal_positions[0],deals[-1]['deal_id'],'sealed-boundary')
    else:
        require(remaining==0 and any(role=='TERMINAL_POSITION' and number(p['volume'])==0 for role,p,seq in native_positions),'NATIVE_FULL_CLOSE_UNAUTHENTICATED')
    canonical_event=prepared[0];c=canonical_event.split('|');require(len(c)==39,'NATIVE_STAGE13_CANONICAL_INVALID')
    event_hash=add('STAGE13_EVENT',canonical_event.encode(),True)
    gross=sum(number(d['profit']) for d in deals)+(number(sealed['mark']) if boundary else 0)
    commission=sum(number(d['commission']) for d in deals);fee=sum(number(d['fee']) for d in deals)
    swap=sum(number(d['swap']) for d in deals)+(number(sealed['position_swap']) if boundary else 0);net=gross+commission+fee+swap
    prior=add('PRIOR_CHECKPOINT',scoped(ledger_root=c[38],base=o['E0']));following=add('NEW_CHECKPOINT',scoped(ledger_root=event_hash,base=str(number(o['E0'])+net)))
    native_commit=committed[0]
    require(native_commit.get('event_hash')==event_hash and native_commit.get('prior_root')==c[38] and native_commit.get('atomic_handoff') is True and native_commit.get('financial_projection_count')==1 and number(native_commit['base_before'])==number(o['E0']) and number(native_commit['base_after'])==number(o['E0'])+net and number(native_commit['contribution_after'])==0,'NATIVE_COMMIT_UNAUTHENTICATED')
    closeid=c[1];commit=add('STAGE13_COMMIT',scoped(lifecycle_close_id=closeid,stage13_event_hash=event_hash,financial_projection_count=1,atomic_handoff=True,research_valid=True))
    terminal=dict(outcome=capture['outcome'],time_msc=int(c[3]),aggregate_gross=str(gross),aggregate_commission=str(commission),aggregate_fee=str(fee),aggregate_swap=str(swap),group_net=str(net),net_return=str(net/number(o['E0'])),net_R=str(net/number(o['R0'])),stage13_event_id=c[1],stage13_sequence=int(c[37]),stage13_root=event_hash,financial_projection_count=1,boundary_snapshot_hash=sealed['snapshot_hash'] if boundary else None)
    sidecar=dict(contract_id=CONTRACT,package_id=PACKAGE,semantic_id=SEMANTICS,binding=binding,precision=pr,original=o,entry=deals[0],exit_portions=deals[1:],residual_snapshots=snapshots,swap_reconciliations=swaps,safety_handoff=dict(lifecycle_close_id=closeid,base_before=o['E0'],contribution_before=str(net),base_after=str(number(o['E0'])+net),contribution_after='0',prior_checkpoint_hash=prior,new_checkpoint_hash=following,stage13_event_hash=event_hash,commit_receipt_hash=commit),terminal=terminal,integrity=dict(lifecycle_root=previous,archive_inventory_hash='',sidecar_hash_algorithm='SHA256'))
    scope=dict(binding,contract_id=CONTRACT,package_id=PACKAGE,semantic_id=SEMANTICS,inventory_protocol_hash=INVENTORY_ADOPTION)
    files=construct_archive(support,sidecar,scope)
    # Construction-time conformance only: no seal and no acceptance transition.
    r=parse_json(files['references.json'])
    view=VerifiedReferences(scope,tuple(r['entries']),files,digest(files['references.json']))
    validate_package(files['sidecar.evidence'],binding,profile,view,conformance=conformance)
    return files

TOP = {'contract_id','package_id','semantic_id','binding','precision','original','entry',
       'exit_portions','residual_snapshots','swap_reconciliations','safety_handoff','terminal','integrity'}
DEAL_FIELDS = {'deal_id','order_id','position_id','request_intent_hash','request_receipt_hash','role',
    'requested_volume','executed_volume','native_time_msc','capture_sequence','price','profit','commission','fee',
    'swap','reason','exit_sl','read_flags','previous_fact_hash','fact_hash'}

def read_package(raw):
    if isinstance(raw, bytes):
        raw = raw.decode('utf-8')
    require(isinstance(raw, str), 'PACKAGE_TYPE')
    body, sep, checksum = raw.rpartition('|sha256=')
    require(sep and digest(body) == checksum, 'PACKAGE_DIGEST_MISMATCH')
    value = json.loads(body, object_pairs_hook=unique)
    require(isinstance(value, dict) and set(value) == TOP, 'V3_FIELDS_REQUIRED')
    return value

def validate_package(raw, expected, profile, references=None, *, conformance=None):
    require(type(references) is VerifiedReferences, 'VERIFIED_REFERENCE_INVENTORY_REQUIRED')
    p = read_package(raw)
    require(p['integrity'].get('archive_inventory_hash') == references.reference_hash, 'REFERENCE_INVENTORY_BINDING_REQUIRED')
    require((p['contract_id'], p['package_id'], p['semantic_id']) == (CONTRACT, PACKAGE, SEMANTICS), 'V3_SEMANTICS_REQUIRED')
    b = p['binding']
    require(isinstance(b, dict) and all(b.get(k) == v for k, v in expected.items()), 'V3_BINDING_MISMATCH')
    require(b.get('decision_a_hash') and b.get('decision_s_hash') and b.get('specification_hash') == ADOPTION, 'ADOPTION_BINDING_INVALID')
    original = p['original']; validate_profile(profile, original.get('side'), conformance=conformance)
    for k in ('V0', 'P0', 'E0', 'R0', 'S0'):
        require(number(original[k]) > 0, 'ORIGINAL_BASIS_INVALID')
    require(isinstance(p['exit_portions'], list) and 0 <= len(p['exit_portions']) <= 2, 'EXIT_CARDINALITY')
    deals = [p['entry']] + p['exit_portions']; seen=set(); orders=set(); previous='0'*64
    gross=Decimal(0); commission=Decimal(0); fee=Decimal(0); swap=Decimal(0); exited=Decimal(0)
    reductions=0; previous_time=0
    for i, d in enumerate(deals):
        require(isinstance(d, dict) and set(d) == DEAL_FIELDS, 'DEAL_FIELDS')
        require(d['deal_id'] not in seen and d['order_id'] not in orders, 'UNSUPPORTED_LEDGER_CARDINALITY')
        seen.add(d['deal_id']); orders.add(d['order_id'])
        require(type(d['deal_id']) is int and d['deal_id']>0 and type(d['order_id']) is int and d['order_id']>0, 'DEAL_ID_INVALID')
        require(d['position_id']==original['position_id'], 'POSITION_ID_MISMATCH')
        require(type(d['native_time_msc']) is int and d['native_time_msc']>=previous_time, 'DEAL_TIME_INVALID')
        previous_time=d['native_time_msc']
        require(d['previous_fact_hash']==previous and hash_value(d['fact_hash']), 'DEAL_CHAIN_INVALID')
        require(d['fact_hash']==digest(canonical({k:v for k,v in d.items() if k!='fact_hash'})), 'DEAL_DIGEST_INVALID')
        previous=d['fact_hash']
        required_reads={'volume','price','profit','commission','fee','swap','reason','identity','time'}
        require(isinstance(d['read_flags'],dict) and required_reads <= set(d['read_flags']) and
                all(d['read_flags'][k] is True for k in required_reads), 'MISSING_OR_FAILED_READ')
        volume=number(d['executed_volume'])
        require(volume>0 and volume==number(d['requested_volume']), 'PARTIAL_ORDER_EXECUTION')
        require(hash_value(d['request_intent_hash']) and hash_value(d['request_receipt_hash']), 'REQUEST_AUTHORITY_MISSING')
        if i==0:
            require(d['role']=='ENTRY' and volume==number(original['V0']) and number(d['profit'])==0 and number(d['swap'])==0, 'ENTRY_INVALID')
        else:
            require(d['role'] in ('SAFETY_REDUCTION','FINAL_CLOSE'), 'CONTAINMENT_OR_UNSUPPORTED_ROLE')
            if d['role']=='SAFETY_REDUCTION':
                reductions+=1;require(i==1 and reductions==1 and volume<number(original['V0']), 'SECOND_REDUCTION')
            else:
                require(i==len(deals)-1, 'CLOSE_ORDER_INVALID')
            require(d['reason'] in ('DEAL_REASON_EXPERT','DEAL_REASON_SL'), 'EXIT_ORIGIN_INVALID')
            if d['reason']=='DEAL_REASON_SL':
                require(d['read_flags'].get('exit_sl') is True and number(d['exit_sl'])==number(original['S0']), 'STOP_MISMATCH')
            exited+=volume;gross+=number(d['profit']);swap+=number(d['swap'])
        commission+=number(d['commission']);fee+=number(d['fee'])
    require(exited<=number(original['V0']), 'EXIT_VOLUME_EXCEEDED')
    term=p['terminal'];require(term['outcome'] in ('NORMAL_CLOSE','EVALUATOR_BOUNDARY') and term['financial_projection_count']==1, 'TERMINAL_PROJECTION_INVALID')
    if term['outcome']=='NORMAL_CLOSE':
        require(exited==number(original['V0']) and deals[-1]['role']=='FINAL_CLOSE' and term['boundary_snapshot_hash'] is None, 'NORMAL_CLOSE_INVALID')
    else:
        require(exited<number(original['V0']) and p['residual_snapshots'], 'BOUNDARY_RESIDUAL_MISSING')
        s=p['residual_snapshots'][-1]
        require(s['snapshot_hash']==term['boundary_snapshot_hash'] and s['position_id']==original['position_id'] and
                number(s['Vr'])==number(original['V0'])-exited and number(s['P0'])==number(original['P0']) and number(s['S0'])==number(original['S0']), 'RESIDUAL_BINDING_MISMATCH')
        require(all(v is True for v in s['read_flags'].values()) and s['read_flags'], 'RESIDUAL_READ_FAILED')
        gross+=number(s['mark']);swap+=number(s['position_swap'])
    reduction_deals=[d for d in p['exit_portions'] if d['role']=='SAFETY_REDUCTION']
    require(len(p['swap_reconciliations'])==len(reduction_deals), 'SWAP_RECONCILIATION_MISSING')
    for r,d in zip(p['swap_reconciliations'],reduction_deals):
        require(r['deal_id']==d['deal_id'] and r['status']=='RECONCILED' and hash_value(r['interval_authority_hash']) and
                r['native_swap_profile_hash']==profile['native_swap_profile_hash'], 'SWAP_AUTHORITY_INVALID')
        require(number(r['interval_accrual'])==0 and number(r['realized_swap'])==number(d['swap']), 'SWAP_TRANSITION_VALUES_UNBOUND')
    net=gross+commission+fee+swap
    for k,v in dict(aggregate_gross=gross,aggregate_commission=commission,aggregate_fee=fee,aggregate_swap=swap,group_net=net,
                    net_return=net/number(original['E0']),net_R=net/number(original['R0'])).items():
        require(number(term[k]).quantize(Decimal('0.000000000001'))==v.quantize(Decimal('0.000000000001')), 'COMPONENT_ORACLE_MISMATCH:'+k)
    h=p['safety_handoff'];require(number(h['base_after'])==number(h['base_before'])+net and number(h['contribution_before'])==net and number(h['contribution_after'])==0, 'DOUBLE_SAFETY_PROJECTION')
    require(p['integrity']['lifecycle_root']==previous and p['integrity']['sidecar_hash_algorithm']=='SHA256', 'LIFECYCLE_ROOT_INVALID')
    validate_lifecycle_references(p, expected, profile, references, conformance=conformance)
    return p

# Adopted evidence-integrity convention; not execution or successor authority.
INVENTORY_PROTOCOL = 'V3_ACYCLIC_REFERENCE_INVENTORY_V1'
INVENTORY_ADOPTION = '42E9BAA5FE03DBE0416BBFFA22B0FDA8820AF51E9E16A4F3C67240D01536A7F6'
DECISION_A_ADOPTION = '13F2CDDD2D58864ECE033A2041B0B4885A4501B3ED0CD869D003235BD9E1E23E'
DECISION_S_ADOPTION = 'C5C75302E0823B41B4466BEF2F9ADCD3681AE2CE9F2D4568773F5F47B0EC00C2'
ENTRY_KEYS = {'path', 'role', 'size', 'sha256', 'run_id', 'group_id'}
RESERVED_ROLES = {'REFERENCE_INVENTORY', 'V3_SIDECAR', 'FINAL_ARCHIVE_INVENTORY', 'INDEPENDENT_FINAL_ARCHIVE_SEAL'}
RESERVED_PATHS = {'references.json', 'sidecar.evidence', 'archive.json'}


def json_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode('utf-8')


def parse_json(raw):
    require(type(raw) is bytes and 0 < len(raw) <= 10_000_000, 'ARTIFACT_BYTES_REQUIRED')
    return json.loads(raw.decode('utf-8'), object_pairs_hook=unique,
                      parse_constant=lambda _: require(False, 'NONFINITE_JSON'))


def archive_path(path):
    require(type(path) is str and 0 < len(path) <= 240, 'ARCHIVE_PATH_INVALID')
    parts = path.split('/')
    for part in parts:
        require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,79}', part) is not None and
                not part.endswith('.') and part.split('.')[0].upper() not in
                {'CON','PRN','AUX','NUL',*(f'COM{i}' for i in range(1,10)),*(f'LPT{i}' for i in range(1,10))},
                'ARCHIVE_PATH_INVALID')
    return path


def archive_binding(binding):
    require(isinstance(binding, dict), 'ARCHIVE_BINDING_REQUIRED')
    required = {'run_id','group_id','contract_id','package_id','semantic_id','decision_a_hash',
                'decision_s_hash','inventory_protocol_hash','execution_receipt_hash','tester_profile_hash'}
    if binding.get('evidence_scope')=='NON_CANDIDATE_NATIVE_CONFORMANCE':
        required.remove('execution_receipt_hash');required.update({'conformance_control_hash','fixture_specification_hash','fixture_id','evidence_scope'})
    require(required <= set(binding), 'ARCHIVE_BINDING_FIELDS')
    require(binding['contract_id'] == CONTRACT and binding['package_id'] == PACKAGE and
            binding['semantic_id'] == SEMANTICS and binding['inventory_protocol_hash'] == INVENTORY_ADOPTION and
            binding['decision_a_hash'] == DECISION_A_ADOPTION and binding['decision_s_hash'] == DECISION_S_ADOPTION,
            'ARCHIVE_ADOPTION_OR_DOWNGRADE')
    for key in ('run_id','conformance_control_hash' if binding.get('evidence_scope')=='NON_CANDIDATE_NATIVE_CONFORMANCE' else 'execution_receipt_hash','tester_profile_hash'):
        require(hash_value(binding[key]), 'ARCHIVE_BINDING_HASH_INVALID')
    require(type(binding['group_id']) is str and 0 < len(binding['group_id']) <= 256, 'GROUP_ID_INVALID')


def inventory_entry(path, role, data, binding):
    archive_path(path)
    require(type(role) is str and re.fullmatch(r'[A-Z][A-Z0-9_]*(?::[A-Za-z0-9_.-]+)?', role) is not None,
            'SEMANTIC_ROLE_INVALID')
    require('CONTAINMENT' not in role and 'INVALID_RUN' not in role, 'CONTAINMENT_NOT_ACCEPTED_EVIDENCE')
    require(type(data) is bytes and 0 < len(data) <= 10_000_000, 'ARTIFACT_BYTES_REQUIRED')
    return dict(path=path, role=role, size=len(data), sha256=digest(data),
                run_id=binding['run_id'], group_id=binding['group_id'])


def validate_inventory(raw, kind, binding):
    value = parse_json(raw)
    require(isinstance(value, dict) and set(value) == {'kind','binding','entries'} and
            value['kind'] == kind and value['binding'] == binding, 'INVENTORY_KIND_OR_BINDING')
    require(type(value['entries']) is list and 0 < len(value['entries']) <= 4096, 'INVENTORY_CARDINALITY')
    paths, roles, hashes = set(), set(), set()
    for entry in value['entries']:
        require(type(entry) is dict and set(entry) == ENTRY_KEYS, 'INVENTORY_ENTRY_FIELDS')
        archive_path(entry['path'])
        require(type(entry['size']) is int and 0 < entry['size'] <= 10_000_000 and hash_value(entry['sha256']), 'INVENTORY_LENGTH_OR_HASH')
        require(entry['run_id'] == binding['run_id'] and entry['group_id'] == binding['group_id'], 'FOREIGN_INVENTORY_EVIDENCE')
        require(type(entry['role']) is str and re.fullmatch(r'[A-Z][A-Z0-9_]*(?::[A-Za-z0-9_.-]+)?',entry['role']) is not None,
                'SEMANTIC_ROLE_INVALID')
        require('CONTAINMENT' not in entry['role'] and 'INVALID_RUN' not in entry['role'], 'CONTAINMENT_NOT_ACCEPTED_EVIDENCE')
        require(entry['path'].casefold() not in paths and entry['role'] not in roles and entry['sha256'] not in hashes,
                'DUPLICATE_PATH_ROLE_OR_ALIAS')
        paths.add(entry['path'].casefold());roles.add(entry['role']);hashes.add(entry['sha256'])
    return value


def construct_archive(supporting, sidecar, binding):
    """Pure construction only. Returns bytes; cannot issue an independent seal.

    supporting maps normalized path -> (unique semantic role, exact immutable bytes).
    No sidecar byte is excluded from hashing. No filesystem or acceptance operation.
    """
    archive_binding(binding)
    require(type(supporting) is dict and supporting, 'SUPPORTING_EVIDENCE_REQUIRED')
    files, entries = {}, []
    for path, (role, data) in supporting.items():
        require(path.casefold() not in RESERVED_PATHS and role not in RESERVED_ROLES, 'REFERENCE_INVENTORY_SELF_REFERENCE')
        files[path] = data
        entries.append(inventory_entry(path, role, data, binding))
    references = json_bytes(dict(kind='REFERENCE_INVENTORY_V1', binding=binding, entries=sorted(entries,key=lambda e:e['path'])))
    validate_inventory(references, 'REFERENCE_INVENTORY_V1', binding)
    # Copy the caller's object so construction cannot mutate an existing/sealed sidecar.
    s = parse_json(json_bytes(sidecar))
    require(type(s) is dict and set(s) == TOP, 'V3_FIELDS_REQUIRED')
    require(s['integrity'].get('archive_inventory_hash') in (None, ''), 'SIDECAR_ALREADY_BOUND')
    s['integrity']['archive_inventory_hash'] = digest(references)
    body = json_bytes(s)
    sidecar_bytes = body + b'|sha256=' + digest(body).encode('ascii')
    files['references.json'] = references
    files['sidecar.evidence'] = sidecar_bytes
    entries += [inventory_entry('references.json','REFERENCE_INVENTORY',references,binding),
                inventory_entry('sidecar.evidence','V3_SIDECAR',sidecar_bytes,binding)]
    archive = json_bytes(dict(kind='FINAL_ARCHIVE_INVENTORY_V1',binding=binding,entries=sorted(entries,key=lambda e:e['path'])))
    validate_inventory(archive,'FINAL_ARCHIVE_INVENTORY_V1',binding)
    files['archive.json'] = archive
    return files


@dataclass(frozen=True)
class VerifiedReferences:
    """Read-only, exact-byte reference resolver returned after archive verification."""
    binding: dict
    entries: tuple
    files: dict
    reference_hash: str

    def resolve(self, sha256, role):
        matches = [e for e in self.entries if e['sha256'] == sha256 and e['role'] == role]
        require(len(matches) == 1, 'SUPPORTING_REFERENCE_MISSING_OR_WRONG_ROLE:' + role)
        entry = matches[0]; raw = self.files[entry['path']]
        require(digest(raw) == sha256 and len(raw) == entry['size'], 'SUPPORTING_REFERENCE_ALTERED')
        return raw

    def record(self, sha256, role):
        value = parse_json(self.resolve(sha256, role))
        require(type(value) is dict and value.get('run_id') == self.binding['run_id'] and
                value.get('group_id') == self.binding['group_id'], 'FOREIGN_SUPPORTING_RECORD')
        return value


def verify_archive(files, independent_seal, expected_binding):
    """Seal must be resolved by independent control, never from archive/payload.

    This function verifies integrity only; it grants no authorization or acceptance.
    The caller must next run lifecycle/accounting/Stage13 validation.
    """
    require(type(independent_seal) is dict and set(independent_seal) == {'kind','authority','binding','archive_sha256'},
            'INDEPENDENT_FINAL_SEAL_REQUIRED')
    seal = independent_seal
    require(seal['kind'] == 'INDEPENDENT_FINAL_ARCHIVE_SEAL' and
            seal['authority'] == 'COMPLETED_PACKAGE_INTEGRITY_ONLY', 'FINAL_SEAL_AUTHORITY_INVALID')
    binding = seal['binding'];archive_binding(binding)
    require(all(binding.get(k) == v for k,v in expected_binding.items()), 'FINAL_SEAL_EXPECTATION_MISMATCH')
    require(type(files) is dict and len(files) <= 4097 and all(type(v) is bytes for v in files.values()), 'ARCHIVE_TRANSPORT_INVALID')
    require(hash_value(seal['archive_sha256']) and digest(files['archive.json']) == seal['archive_sha256'], 'FINAL_ARCHIVE_PIN_MISMATCH')
    a = validate_inventory(files['archive.json'],'FINAL_ARCHIVE_INVENTORY_V1',binding)
    require(set(files) == {e['path'] for e in a['entries']} | {'archive.json'}, 'ARCHIVE_MEMBERSHIP_MISMATCH')
    for entry in a['entries']:
        require(entry['path'] != 'archive.json' and entry['role'] not in {'FINAL_ARCHIVE_INVENTORY','INDEPENDENT_FINAL_ARCHIVE_SEAL'},
                'ARCHIVE_SELF_REFERENCE')
        raw = files[entry['path']]
        require(len(raw) == entry['size'] and digest(raw) == entry['sha256'], 'ARCHIVE_ARTIFACT_ALTERED:' + entry['path'])
    by_role = {e['role']:e for e in a['entries']}
    require(by_role.get('REFERENCE_INVENTORY',{}).get('path') == 'references.json' and
            by_role.get('V3_SIDECAR',{}).get('path') == 'sidecar.evidence', 'ARCHIVE_REQUIRED_ROLE_MISSING')
    r = validate_inventory(files['references.json'],'REFERENCE_INVENTORY_V1',binding)
    require(all(e['role'] not in RESERVED_ROLES and e['path'].casefold() not in RESERVED_PATHS for e in r['entries']),
            'REFERENCE_INVENTORY_SELF_REFERENCE')
    supporting = [e for e in a['entries'] if e['role'] not in {'REFERENCE_INVENTORY','V3_SIDECAR'}]
    require(sorted(supporting,key=lambda e:e['path']) == sorted(r['entries'],key=lambda e:e['path']), 'REFERENCE_ARCHIVE_COVERAGE_MISMATCH')
    s = read_package(files['sidecar.evidence'])
    require(s['integrity'].get('archive_inventory_hash') == digest(files['references.json']), 'SIDECAR_REFERENCE_INVENTORY_MISMATCH')
    require((s['contract_id'],s['package_id'],s['semantic_id']) == (CONTRACT,PACKAGE,SEMANTICS), 'V3_SEMANTICS_REQUIRED')
    return s, VerifiedReferences(dict(binding),tuple(r['entries']),dict(files),digest(files['references.json']))


def encode_archive(files):
    import base64
    return canonical(dict(kind='V3_ARCHIVE_TRANSPORT',artifacts=[dict(path=p,data=base64.b64encode(v).decode('ascii')) for p,v in sorted(files.items())]))


def decode_archive(raw):
    import base64
    value = parse_json(raw.encode('utf-8') if type(raw) is str else raw)
    require(type(value) is dict and set(value) == {'kind','artifacts'} and value['kind'] == 'V3_ARCHIVE_TRANSPORT' and
            type(value['artifacts']) is list and 0 < len(value['artifacts']) <= 4097, 'ARCHIVE_TRANSPORT_INVALID')
    files = {}; paths = set();total = 0
    for entry in value['artifacts']:
        require(type(entry) is dict and set(entry) == {'path','data'}, 'ARCHIVE_TRANSPORT_ENTRY_INVALID')
        path = archive_path(entry['path'])
        require(path.casefold() not in paths, 'ARCHIVE_TRANSPORT_ALIAS')
        paths.add(path.casefold())
        require(type(entry['data']) is str, 'ARCHIVE_TRANSPORT_DATA_INVALID')
        data = base64.b64decode(entry['data'],validate=True)
        total += len(data);require(total <= 10_000_000, 'ARCHIVE_TRANSPORT_SIZE')
        files[path] = data
    return files

BINDING_FIELDS = {'run_id','root_hash','candidate_id','configuration_hash','branch','partition','group_id','symbol',
                  'source_manifest_hash','executable_hash','specification_hash','decision_a_hash','decision_s_hash',
                  'freeze_receipt_hash','execution_receipt_hash','tester_profile_hash'}
PRECISION_FIELDS = {'volume_step','volume_digits','price_convention_hash','currency','currency_precision','arithmetic_contract_hash'}
ORIGINAL_FIELDS = {'V0','P0','side','R0','E0','S0','position_id','entry_intent_hash','entry_effective_stop_hash'}
SNAPSHOT_FIELDS = {'snapshot_id','predecessor_deal_id','position_id','position_ticket','native_or_observation_time',
                   'time_source','Vr','P0','S0','bid','ask','mark','position_swap','read_flags','snapshot_hash'}
SWAP_FIELDS = {'deal_id','before_snapshot_hash','after_snapshot_hash','before_swap','realized_swap','after_swap',
               'interval_accrual','interval_authority_hash','native_swap_profile_hash','status'}
HANDOFF_FIELDS = {'lifecycle_close_id','base_before','contribution_before','base_after','contribution_after',
                  'prior_checkpoint_hash','new_checkpoint_hash','stage13_event_hash','commit_receipt_hash'}
TERMINAL_FIELDS = {'outcome','time_msc','aggregate_gross','aggregate_commission','aggregate_fee','aggregate_swap',
                   'group_net','net_return','net_R','stage13_event_id','stage13_sequence','stage13_root',
                   'financial_projection_count','boundary_snapshot_hash'}


def validate_lifecycle_references(p, expected, profile, references, *, conformance=None):
    """Mandatory second half of V3 verification after independently sealed bytes."""
    used = set()
    def ref(sha, role, *, json_record=True):
        require(hash_value(sha), 'REFERENCE_HASH_INVALID:' + role)
        raw = references.resolve(sha, role);used.add((sha,role))
        return parse_json(raw) if json_record else raw
    def fields(value, keys, reason):
        require(type(value) is dict and set(value) == keys, reason)
    def integer(value, *, minimum=1):
        require(type(value) is int and value >= minimum, 'INTEGER_REQUIRED')
    def bound(value):
        require(type(value) is dict and value.get('run_id') == b['run_id'] and value.get('group_id') == b['group_id'], 'SUPPORTING_SCOPE_MISMATCH')
    b=p['binding'];o=p['original'];t=p['terminal'];pr=p['precision'];handoff=p['safety_handoff']
    binding_fields=BINDING_FIELDS if conformance is None else conformance.binding_fields
    fields(b,binding_fields,'V3_BINDING_FIELDS');fields(o,ORIGINAL_FIELDS,'ORIGINAL_FIELDS')
    fields(pr,PRECISION_FIELDS,'PRECISION_FIELDS');fields(t,TERMINAL_FIELDS,'TERMINAL_FIELDS')
    fields(handoff,HANDOFF_FIELDS,'HANDOFF_FIELDS')
    fields(p['integrity'],{'lifecycle_root','archive_inventory_hash','sidecar_hash_algorithm'},'INTEGRITY_FIELDS')
    if conformance is not None: conformance.validate_binding(b)
    require((b['candidate_id']=='CAND-ETH-ST-002' if conformance is None else b['candidate_id']==conformance.domain) and b['specification_hash']==ADOPTION and
            b['decision_a_hash']==DECISION_A_ADOPTION and b['decision_s_hash']==DECISION_S_ADOPTION, 'ADOPTION_BINDING_INVALID')
    require(all(type(b[k]) is str and b[k] for k in binding_fields), 'EMPTY_BINDING')
    integer(o['position_id']);integer(t['time_msc']);integer(t['stage13_sequence'])
    require(type(t['financial_projection_count']) is int and t['financial_projection_count']==1, 'SECOND_FINANCIAL_PROJECTION')
    require(type(pr['volume_digits']) is int and 0<=pr['volume_digits']<=8 and pr['currency']=='USD' and
            type(pr['currency_precision']) is int and 0<=pr['currency_precision']<=12, 'PRECISION_CONVENTION_INVALID')
    require(number(pr['volume_step'])==number(profile['facts']['SYMBOL_VOLUME_STEP']), 'VOLUME_STEP_PROFILE_MISMATCH')
    step=number(pr['volume_step']);tick=number(profile['facts']['SYMBOL_TRADE_TICK_SIZE'])
    for key in ('V0',):require(number(o[key])%step==0,'ORIGINAL_VOLUME_OFF_GRID')
    for key in ('P0','S0'):require(number(o[key])%tick==0,'ORIGINAL_PRICE_OFF_GRID')
    require(number(profile['facts']['SYMBOL_VOLUME_MIN'])<=number(o['V0'])<=number(profile['facts']['SYMBOL_VOLUME_MAX']), 'ORIGINAL_VOLUME_PROFILE')
    for key,role in [('configuration_hash','CONFIGURATION_SPECIFICATION'),('source_manifest_hash','SOURCE_MANIFEST'),
                     ('executable_hash','EXECUTABLE'),('specification_hash','COMBINED_SPECIFICATION'),
                     ('decision_a_hash','DECISION_A_SPECIFICATION'),('decision_s_hash','DECISION_S_SPECIFICATION'),
                     ('freeze_receipt_hash','FREEZE_RECEIPT'),('execution_receipt_hash','EXECUTION_RECEIPT'),
                     ('tester_profile_hash','TESTER_PROFILE')]:
        if conformance is not None and key=='freeze_receipt_hash':key,role='conformance_control_hash','CONFORMANCE_CONTROL'
        if conformance is not None and key=='execution_receipt_hash':key,role='fixture_specification_hash','FIXTURE_SPECIFICATION'
        raw=ref(b[key],role,json_record=False)
        if role=='TESTER_PROFILE':require(parse_json(raw)==profile,'PROFILE_REFERENCE_MISMATCH')
    if conformance is not None:
        launch=ref(b['launch_record_hash'],'CONFORMANCE_LAUNCH_RECORD')
        for key in ('set','ini','manifest','calendar'):ref(launch[key+'_file']['sha256'],'CONFORMANCE_LAUNCH_'+key.upper(),json_record=False)
    for key,role in [('price_convention_hash','PRICE_CONVENTION'),('arithmetic_contract_hash','ARITHMETIC_CONTRACT')]:
        ref(pr[key],role,json_record=False)
        require(profile[key]==pr[key],'UNPINNED_PRECISION_CONVENTION')
    stop=ref(o['entry_effective_stop_hash'],'ENTRY_EFFECTIVE_STOP');bound(stop)
    require(stop.get('position_id')==o['position_id'] and stop.get('read_ok') is True and
            number(stop['S0'])==number(o['S0']) and number(stop['V0'])==number(o['V0']) and number(stop['P0'])==number(o['P0']), 'EFFECTIVE_ENTRY_STOP_UNAUTHENTICATED')
    require(stop.get('profile_hash')==b['tester_profile_hash'] and stop.get('post_entry_mutation_authorized') is False and
            stop.get('context_integrity') is True and stop.get('unexplained_modification') is False and
            stop.get('observation_overflow') is False,'STATIC_STOP_CONTEXT_INVALID')
    ref(stop.get('native_capture_hash'),'NATIVE_CAPTURE',json_record=False)
    ref(profile['native_swap_profile_hash'],'NATIVE_SWAP_PROFILE',json_record=False)
    integer(stop['observation_time_msc'])
    start,end=profile['evaluation_start_msc'],profile['evaluation_end_msc'];integer(start);integer(end)
    require(start<end,'EVALUATION_WINDOW_INVALID')
    deals=[p['entry']]+p['exit_portions'];previous_sequence=0;remaining=number(o['V0']);snapshots={}
    require(type(p['residual_snapshots']) is list,'SNAPSHOT_COLLECTION_REQUIRED')
    for snapshot in p['residual_snapshots']:
        fields(snapshot,SNAPSHOT_FIELDS,'SNAPSHOT_FIELDS')
        sid=snapshot['snapshot_id'];require(type(sid) is str and sid and sid not in snapshots,'SNAPSHOT_ID_DUPLICATE')
        expected_raw=json_bytes({k:v for k,v in snapshot.items() if k!='snapshot_hash'})
        actual=ref(snapshot['snapshot_hash'],'POSITION_SNAPSHOT:'+sid,json_record=False)
        require(actual==expected_raw,'SNAPSHOT_REFERENCE_MISMATCH')
        integer(snapshot['position_ticket']);integer(snapshot['predecessor_deal_id']);integer(snapshot['native_or_observation_time'])
        require(snapshot['position_id']==o['position_id'] and number(snapshot['P0'])==number(o['P0']) and
                number(snapshot['S0'])==number(o['S0']) and snapshot['time_source']=='CALLBACK_OR_TICK_OBSERVATION_MSC', 'RESIDUAL_IDENTITY_OR_STOP_MISMATCH')
        require(start<=snapshot['native_or_observation_time']<end and 0<number(snapshot['Vr'])<=number(o['V0']) and
                number(snapshot['Vr'])%step==0 and 0<number(snapshot['bid'])<=number(snapshot['ask']), 'RESIDUAL_SNAPSHOT_INVALID')
        required={'position_id','ticket','volume','basis','sl','swap','quote','mark','symbol','magic','side'}
        require(type(snapshot['read_flags']) is dict and set(snapshot['read_flags'])==required and all(v is True for v in snapshot['read_flags'].values()), 'RESIDUAL_READ_FAILED')
        snapshots[sid]=snapshot
    for i,d in enumerate(deals):
        integer(d['capture_sequence']);require(d['capture_sequence']>previous_sequence,'CAPTURE_SEQUENCE_CONFLICT');previous_sequence=d['capture_sequence']
        require(start<=d['native_time_msc']<end,'DEAL_OUTSIDE_WINDOW')
        require(number(d['price'])>0 and number(d['price'])%tick==0 and number(d['executed_volume'])%step==0,'DEAL_PRECISION_INVALID')
        require(ref(d['fact_hash'],'DEAL:'+str(d['deal_id']),json_record=False)==json_bytes({k:v for k,v in d.items() if k!='fact_hash'}),'DEAL_REFERENCE_MISMATCH')
        intent=ref(d['request_intent_hash'],'REQUEST_INTENT:'+str(d['order_id']));bound(intent)
        receipt=ref(d['request_receipt_hash'],'REQUEST_RECEIPT:'+str(d['order_id']));bound(receipt)
        require(intent.get('filling')=='ORDER_FILLING_FOK' and intent.get('role')==d['role'] and
                intent.get('order_id')==d['order_id'] and number(intent['requested_volume'])==number(d['requested_volume']) and
                intent.get('context_integrity') is True,'REQUEST_INTENT_AUTHORITY_INVALID')
        require(receipt.get('order_id')==d['order_id'] and receipt.get('terminal') is True and receipt.get('read_ok') is True and
                receipt.get('deal_ids')==[d['deal_id']] and number(receipt['executed_volume'])==number(d['executed_volume']) and
                receipt.get('classification')=='FOK_FULL_SINGLE_DEAL', 'EXECUTION_COMPLETENESS_UNAUTHENTICATED')
        require(receipt.get('position_id')==o['position_id'],'RECEIPT_POSITION_MISMATCH')
        if i==0:
            require(d['request_intent_hash']==o['entry_intent_hash'] and number(d['price'])==number(o['P0']) and
                    all(number(intent[k])==number(o[k]) for k in ('V0','E0','R0','S0')) and
                    d['reason']=='DEAL_REASON_EXPERT' and d['exit_sl'] is None and d['read_flags'].get('exit_sl')=='NOT_APPLICABLE', 'ENTRY_ORIGINAL_BINDING_INVALID')
        else:
            if d['role']=='SAFETY_REDUCTION':
                residual=(number(o['V0'])/2//step)*step
                require(number(d['executed_volume'])==number(o['V0'])-residual and residual>=number(profile['facts']['SYMBOL_VOLUME_MIN']) and
                        intent.get('governed_reason')=='SPREAD_ABOVE_2_5X_REDUCE_50_PERCENT','UNGOVERNED_REDUCTION')
            else:
                require(number(d['executed_volume'])==remaining,'FINAL_RESIDUAL_VOLUME_MISMATCH')
                require(intent.get('governed_reason') in {'STRATEGY_CLOSE','SEVERE_SPREAD_FLATTEN','BROKER_VOLUME_FALLBACK',
                        'MAINTENANCE_CLOSE','NEWS_CLOSE','STATIC_PROTECTIVE_STOP'},'UNGOVERNED_CLOSE')
            if d['reason']=='DEAL_REASON_SL':
                require(intent.get('governed_reason')=='STATIC_PROTECTIVE_STOP' and intent.get('entry_intent_hash')==o['entry_intent_hash'], 'STOP_PROVENANCE_UNAUTHENTICATED')
            remaining-=number(d['executed_volume'])
    require(stop['observation_time_msc']>=p['entry']['native_time_msc'] and stop['observation_time_msc']<end,'ENTRY_STOP_TIME_INVALID')
    if t['outcome']=='NORMAL_CLOSE':require(t['time_msc']==deals[-1]['native_time_msc'] and t['time_msc']<end,'NORMAL_CLOSE_TIMESTAMP_INVALID')
    else:
        final=[s for s in snapshots.values() if s['snapshot_hash']==t['boundary_snapshot_hash']]
        require(len(final)==1 and t['time_msc']==final[0]['native_or_observation_time'] and
                number(final[0]['Vr'])==remaining and final[0]['predecessor_deal_id']==deals[-1]['deal_id'], 'SEALED_BOUNDARY_INVALID')
    for r,d in zip(p['swap_reconciliations'],[d for d in p['exit_portions'] if d['role']=='SAFETY_REDUCTION']):
        fields(r,SWAP_FIELDS,'SWAP_FIELDS')
        before=next((s for s in snapshots.values() if s['snapshot_hash']==r['before_snapshot_hash']),None)
        after=next((s for s in snapshots.values() if s['snapshot_hash']==r['after_snapshot_hash']),None)
        require(before is not None and after is not None,'SWAP_TRANSITION_SNAPSHOTS_MISSING')
        require(number(before['position_swap'])==number(r['before_swap']) and
                number(after['position_swap'])==number(r['after_swap']), 'SWAP_TRANSITION_VALUES_UNBOUND')
        transition=ref(r['interval_authority_hash'],'SWAP_INTERVAL:'+str(d['deal_id']));bound(transition)
        validate_swap_transition(transition,before,d,after,binding=b,original=o,precision=pr,profile=profile)
        intent=ref(d['request_intent_hash'],'REQUEST_INTENT:'+str(d['order_id']))
        receipt=ref(d['request_receipt_hash'],'REQUEST_RECEIPT:'+str(d['order_id']))
        require(intent.get('immediate_before_snapshot_hash')==before['snapshot_hash'] and
                receipt.get('reconciled_after_snapshot_hash')==after['snapshot_hash'], 'SWAP_TRANSITION_REQUEST_SNAPSHOT_LINK')
        ref(r['native_swap_profile_hash'],'NATIVE_SWAP_PROFILE',json_record=False)
    for d in p['exit_portions']:
        if d['role']=='FINAL_CLOSE':
            receipt=ref(d['request_receipt_hash'],'REQUEST_RECEIPT:'+str(d['order_id']))
            flat=ref(receipt.get('flat_state_hash'),'FLAT_STATE:'+str(d['deal_id']));bound(flat)
            require(flat.get('position_id')==o['position_id'] and flat.get('order_id')==d['order_id'] and
                    flat.get('terminal') is True and flat.get('flat_authenticated') is True,'FLAT_STATE_UNAUTHENTICATED')
            ref(profile['native_swap_profile_hash'],'NATIVE_SWAP_PROFILE',json_record=False)
    canonical_event=ref(t['stage13_root'],'STAGE13_EVENT',json_record=False).decode('utf-8')
    c=canonical_event.split('|');require(len(c)==39 and c[0]=='1' and c[2]=='9','STAGE13_SCHEMA_INVALID')
    require(c[1]==t['stage13_event_id'] and c[7]==b['candidate_id'] and c[8]==b['configuration_hash'] and c[10]==b['group_id'] and
            c[15]==b['symbol'] and int(c[3])==t['time_msc'] and int(c[37])==t['stage13_sequence'], 'STAGE13_BINDING_MISMATCH')
    for key,index in [('aggregate_gross',21),('aggregate_commission',22),('aggregate_swap',23),('aggregate_fee',24)]:
        require(number(c[index])==number(t[key]).quantize(Decimal('.00000001')), 'STAGE13_COMPONENT_MISMATCH')
    for key,index in [('net_return',30),('net_R',31)]:require(number(c[index])==number(t[key]).quantize(Decimal('.000000000001')),'STAGE13_RETURN_MISMATCH')
    require(all(number(c[i])==0 for i in (25,26,27)), 'EXTERNAL_CASH_OR_DOUBLE_CHARGE')
    if t['outcome']=='EVALUATOR_BOUNDARY':require(c[12]==c[13]=='0','BOUNDARY_FICTITIOUS_DEAL')
    else:require(int(c[12])==deals[-1]['order_id'] and int(c[13])==deals[-1]['deal_id'],'STAGE13_EXIT_LINK')
    require(handoff['stage13_event_hash']==t['stage13_root'], 'STAGE13_HANDOFF_LINK')
    prior=ref(handoff['prior_checkpoint_hash'],'PRIOR_CHECKPOINT');bound(prior)
    following=ref(handoff['new_checkpoint_hash'],'NEW_CHECKPOINT');bound(following)
    require(prior.get('ledger_root')==c[38] and following.get('ledger_root')==t['stage13_root'] and
            number(prior['base'])==number(handoff['base_before']) and number(following['base'])==number(handoff['base_after']), 'CHECKPOINT_HANDOFF_MISMATCH')
    commit=ref(handoff['commit_receipt_hash'],'STAGE13_COMMIT');bound(commit)
    require(commit.get('lifecycle_close_id')==handoff['lifecycle_close_id'] and commit.get('stage13_event_hash')==t['stage13_root'] and
            commit.get('financial_projection_count')==1 and commit.get('atomic_handoff') is True and
            commit.get('research_valid') is True,'TERMINAL_COMMIT_UNAUTHENTICATED')
    require(used=={(e['sha256'],e['role']) for e in references.entries},'UNREFERENCED_SUPPORTING_EVIDENCE')


ORDER_REQUEST_FIELDS={'action','magic','order','symbol','volume','price','stoplimit','sl','tp','deviation','type','type_filling','type_time','expiration','comment','position','position_by'}
ORDER_CHECK_FIELDS={'run_id','group_id','request','request_hash','bool_return','retcode','error','comment','balance','equity','profit','margin','margin_free','margin_level','time_msc','context_hash'}
def validate_order_check(check,binding,*,conformance=None):
    require(type(check) is dict and set(check)==ORDER_CHECK_FIELDS,'ORDER_CHECK_FIELDS')
    require(check['run_id']==binding['run_id'] and check['group_id']==binding['group_id'],'FOREIGN_ORDER_CHECK')
    r=check['request'];require(type(r) is dict and set(r)==ORDER_REQUEST_FIELDS,'ORDER_CHECK_REQUEST_FIELDS')
    # Preserve the producer's field order: this is the hash of exact serialized request bytes.
    require(digest(json.dumps(r,separators=(',',':'),ensure_ascii=False).encode())==check['request_hash'],'ORDER_CHECK_REQUEST_HASH')
    require(check['bool_return'] is True and type(check['retcode']) is int and check['retcode']==0,'ORDER_CHECK_REJECTED_NO_SEND')
    require(r['action']==1 and r['magic']==12001 and r['symbol']==binding['symbol'] and r['type_filling']==0 and r['type'] in (0,1),'ORDER_CHECK_REQUEST_INVALID')
    for k in ('balance','equity','profit','margin','margin_free','margin_level'):number(check[k])
    for k in ('volume','price','sl','tp','stoplimit'):number(r[k])
    require(number(r['volume'])>0 and number(r['price'])>0 and number(r['tp'])==0,'ORDER_CHECK_REQUEST_INVALID')
    require(type(check['time_msc']) is int and check['time_msc']>0 and hash_value(check['context_hash']),'ORDER_CHECK_CONTEXT')
    if conformance is not None:
        require(check['context_hash']==conformance.control_hash,'ORDER_CHECK_CONTEXT')
        f=conformance.fixture;require(f['start_msc']<=check['time_msc']<f['end_msc'],'ORDER_CHECK_OUTSIDE_FIXTURE')
        expected=0 if conformance.side=='LONG' else 1
        require(r['type']==(expected if r['position']==0 else 1-expected),'ORDER_CHECK_SIDE')
        require(number(r['sl'])==(number(f['S0']) if r['position']==0 else 0),'ORDER_CHECK_SL')
    return check
