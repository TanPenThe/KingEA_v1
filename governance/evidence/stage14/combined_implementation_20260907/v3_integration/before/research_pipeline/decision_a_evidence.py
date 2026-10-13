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

def validate_profile(profile, side='LONG'):
    require(isinstance(profile, dict), 'SWAP_PROFILE_NOT_AUTHORIZED')
    require(profile.get('accepted_proof_sha256') == NATIVE_PROOF and
            profile.get('server') == 'JustMarkets-Demo2' and profile.get('symbol') == 'ETHUSD.s' and
            all(profile.get(k) == 6140 for k in ('terminal_build', 'compiler_build', 'agent_build')),
            'SWAP_PROFILE_NOT_AUTHORIZED')
    require(profile.get('local') is True and profile.get('visual') is False and
            profile.get('dll') is False and profile.get('command_bridge') is False and
            profile.get('shared_trading_input') is False, 'TESTER_PROFILE_INVALID')
    facts = profile.get('facts', {})
    for key, expected in SWAP_FACTS.items():
        require(key in facts and number(facts[key]) == number(expected), 'SWAP_PROFILE_NOT_AUTHORIZED')
    # No separately accepted SHORT proof is currently in the governing contract.
    require(side == 'LONG', 'NATIVE_CONFORMANCE_REQUIRED_BEFORE_SUCCESSOR_READINESS')

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

def validate_package(raw, expected, profile):
    p = read_package(raw)
    require((p['contract_id'], p['package_id'], p['semantic_id']) == (CONTRACT, PACKAGE, SEMANTICS), 'V3_SEMANTICS_REQUIRED')
    b = p['binding']
    require(isinstance(b, dict) and all(b.get(k) == v for k, v in expected.items()), 'V3_BINDING_MISMATCH')
    require(b.get('decision_a_hash') and b.get('decision_s_hash') and b.get('specification_hash') == ADOPTION, 'ADOPTION_BINDING_INVALID')
    original = p['original']; validate_profile(profile, original.get('side'))
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
    require(len(p['swap_reconciliations'])==len(p['exit_portions']), 'SWAP_RECONCILIATION_MISSING')
    for r,d in zip(p['swap_reconciliations'],p['exit_portions']):
        require(r['deal_id']==d['deal_id'] and r['status']=='RECONCILED' and hash_value(r['interval_authority_hash']) and
                r['native_swap_profile_hash']==b['native_swap_profile_hash'], 'SWAP_AUTHORITY_INVALID')
        require(number(r['interval_accrual'])==0 and number(r['realized_swap'])==number(d['swap']) and
                number(r['before_swap'])==number(r['realized_swap'])+number(r['after_swap']), 'SWAP_RECONCILIATION_FAILED')
    net=gross+commission+fee+swap
    for k,v in dict(aggregate_gross=gross,aggregate_commission=commission,aggregate_fee=fee,aggregate_swap=swap,group_net=net,
                    net_return=net/number(original['E0']),net_R=net/number(original['R0'])).items():
        require(number(term[k]).quantize(Decimal('0.000000000001'))==v.quantize(Decimal('0.000000000001')), 'COMPONENT_ORACLE_MISMATCH:'+k)
    h=p['safety_handoff'];require(number(h['base_after'])==number(h['base_before'])+net and number(h['contribution_before'])==net and number(h['contribution_after'])==0, 'DOUBLE_SAFETY_PROJECTION')
    require(p['integrity']['lifecycle_root']==previous and p['integrity']['sidecar_hash_algorithm']=='SHA256', 'LIFECYCLE_ROOT_INVALID')
    return p
