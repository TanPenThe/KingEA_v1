"""Classify non-Candidate IOC evidence. No execution, fallback, or historical inference."""
import configparser
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def classify(evidence):
    if not (evidence['environment_verified'] is True
            and evidence['filling'] == 'ORDER_FILLING_IOC'
            and evidence['execution_mode'] == 20
            and evidence['candidate_executed'] is False
            and evidence['fallback_count'] == 0):
        raise ValueError('IOC_CONFORMANCE_SCOPE_UNPROVEN')
    if evidence['check_retcode'] == 10030 and evidence['order_attempts'] == 0:
        return 'FROZEN_IOC_EXECUTION_CONTRACT_INCOMPATIBLE'
    if evidence['check_retcode'] not in (0, 10009) and evidence['order_attempts']:
        raise ValueError('SEND_AFTER_REJECTED_CHECK')
    if evidence['order_attempts'] == 1 and evidence['send_retcode'] == 10030:
        return 'FROZEN_IOC_EXECUTION_CONTRACT_INCOMPATIBLE'
    if (evidence['order_attempts'] == 1 and evidence['send_retcode'] == 10009
            and evidence.get('execution_authenticated_full_fill') is True):
        return 'IOC_EXECUTION_CONTRACT_SUPPORTED'
    raise ValueError('IOC_CONFORMANCE_INCONCLUSIVE')


def verify_sealed(root):
    """Read only retained evidence, never deployed sources, executable, or terminal files."""
    root = Path(root).resolve()
    def need(condition, reason):
        if not condition:
            raise ValueError(reason)
    def read(name):
        return json.loads((root / name).read_text())
    inventory = read('SEALED_INVENTORY.json')
    seen = set()
    for item in inventory['files']:
        rel = Path(item['path']); p = (root / rel).resolve()
        need(not rel.is_absolute() and '..' not in rel.parts and p.is_relative_to(root)
             and str(rel) not in seen, 'UNSAFE_OR_DUPLICATE_ARTIFACT')
        need(p.is_file() and p.stat().st_size == item['size'] and sha(p) == item['sha256'],
             'ARTIFACT_MISSING_OR_ALTERED')
        seen.add(str(rel))
    need(seen == {str(p.relative_to(root)) for p in root.rglob('*')
                  if p.is_file() and p.name != 'SEALED_INVENTORY.json'}, 'UNSEALED_ARTIFACT')
    m = read('MANIFEST.json'); a = read('AUTHORIZATION.json'); r = read('LAUNCH_RECEIPT.json')
    runtime = read('RUNTIME_RECEIPT.json'); build = read('BUILD_BINDING.json'); pre = read('PRE_TOOLING.json')
    result = read('runtime/harness/result.json'); spec = read('runtime/harness/specification.json')
    request = read('runtime/harness/request.json'); check = read('runtime/harness/order_check.json')
    execution = read('runtime/harness/execution.json')
    for fact in (a, r, result, spec, request, check, execution):
        need(fact['run_id'] == m['run_id'], 'RUN_BINDING')
    need(r['manifest_sha256'] == sha(root/'MANIFEST.json') and
         m['authorization_sha256'] == sha(root/'AUTHORIZATION.json') and
         a['owner_scope_sha256'] == sha(root/'OWNER_SCOPE.json'), 'AUTHORIZATION_BINDING')
    need(a['scope'] == 'NON_CANDIDATE_IOC_CONFORMANCE' and a['candidate_execution'] is False
         and a['budget'] == 0 and a['oos'] is False and a['holdout'] is False
         and a['simulated_entry_limit'] == 1 and a['b2'] == m['b2'] == 'LOCKED', 'SCOPE')
    need(runtime['pid'] == r['pid'] and r['pid'] > 0 and runtime['exit_code'] == 0
         and runtime['started'] == r['started'] < runtime['ended'] and
         m['command'] == r['command'] and m['command'][0] == m['terminal']['path']
         and m['command'][1].endswith('\\tester.ini'), 'LAUNCH_RUNTIME_BINDING')
    ini = configparser.ConfigParser(); ini.read(root/'tester.ini')
    expected = dict(Symbol='ETHUSD.s', Period='M30', Model='4', Optimization='0',
                    UseLocal='1', UseRemote='0', UseCloud='0', ExecutionMode='20',
                    FromDate='2023.06.01', ToDate='2023.06.02', ShutdownTerminal='1')
    need(all(ini['Tester'][k] == v for k, v in expected.items()), 'TESTER_SCOPE')
    settings = root/ini['Tester']['ExpertParameters']
    need(m['set_sha256'] == sha(settings) and m['ini_sha256'] == sha(root/'tester.ini'), 'SET_INI_BINDING')
    set_values = dict(line.split('=', 1) for line in settings.read_text().splitlines())
    need(spec['server'] == 'JustMarkets-Demo2' and spec['account_fingerprint'] == set_values['InpExpectedFingerprint']
         and spec['terminal_build'] == int(set_values['InpExpectedBuild']) == m['terminal']['build']
         and spec['facts_ok'] is True and spec['symbol'] == 'ETHUSD.s', 'ENVIRONMENT_BINDING')
    need(m['source_sha256'] == build['source_manifest_sha256'] == sha(root/'PRE_TOOLING.json')
         and build['preexisting_ex5'] is False and build['started'] < build['ended'] <= r['started']
         and build['log_sha256'] == sha(root/'compile.log'), 'FRESH_BUILD_BINDING')
    for source in pre['sources']:
        need(sha(root/'build/MQL5'/source['path']) == source['sha256'], 'SOURCE_BINDING')
    need(build['produced_ex5_sha256'] == m['ex5_sha256'] ==
         sha(root/'build/MQL5/Experts/KingEA/IOCExecutionConformance.ex5'), 'EX5_BINDING')
    need('Result: 0 errors, 0 warnings' in (root/'compile.log').read_text(encoding='utf-16'), 'COMPILE_FAILED')
    need(m['production_request_reference_sha256'] == sha(root/'PRODUCTION_REQUEST_REFERENCE.mq5'), 'PRODUCTION_REFERENCE')
    need(request['type_filling'] == m['type_filling'] == result['filling'] == 'ORDER_FILLING_IOC'
         and request['action'] == 'TRADE_ACTION_DEAL' and request['type'] == 'ORDER_TYPE_BUY'
         and request['symbol'] == spec['symbol'] and request['volume'] == 0.01
         and request['price'] == spec['ask'] and 0 < request['sl'] < request['price']
         and request['tp'] == request['deviation'] == 0 and request['magic'] == 12001
         and request['comment'] == 'KINGEA|CAND-ETH-ST-001|'+m['run_id'], 'FROZEN_REQUEST_SHAPE')
    need(result == runtime['result'] and result['status'] == 'PASS'
         and check['retcode'] == result['check_retcode']
         and execution['attempts'] == result['order_attempts']
         and execution['retcode'] == result['send_retcode'], 'RESULT_FACT_BINDING')
    journals = runtime['journals']
    need(len(journals) == 3 and len({j['source'] for j in journals}) == 3
         and any('Agent-127.0.0.1-' in j['source'] for j in journals), 'LOCAL_RUNTIME_EVIDENCE')
    for journal in journals:
        need(sha(root/journal['path']) == journal['sha256'], 'JOURNAL_BINDING')
    agent = next(j for j in journals if 'Agent-127.0.0.1-' in j['source'])
    text = (root/agent['path']).read_text(encoding='utf-16', errors='replace')
    need('IOC_CONFORMANCE_BEGIN|'+m['run_id'] in text and
         'IOC_CONFORMANCE_END|'+m['run_id'] in text, 'RUN_CORRELATED_AGENT_MARKERS')
    authenticated = dict(result)
    authenticated['execution_authenticated_full_fill'] = (execution['ok'] is True and
        execution['deal'] > 0 and execution['volume'] == request['volume'] and execution['price'] > 0)
    return dict(status='PASS', classification=classify(authenticated), artifacts=len(seen),
                run_id=m['run_id'], b2='LOCKED', seal_sha256=sha(root/'SEALED_INVENTORY.json'))
