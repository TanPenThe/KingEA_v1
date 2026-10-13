"""Serialize synthetic observations using the production MQL capture wire format."""
from research_pipeline.decision_a_evidence import *


def native_capture(sidecar, files):
    s=sidecar;b=s['binding'];o=s['original'];rows=[]
    r=parse_json(files['references.json'])
    def record(role):
        e=next(e for e in r['entries'] if e['role']==role)
        return parse_json(files[e['path']])
    def emit(role,obj,raw=False):rows.append(dict(role=role,payload=obj if raw else json_bytes(obj).decode()))
    def position(snap):return dict(position_id=snap['position_id'],position_ticket=snap['position_ticket'],side=0,magic=12001,symbol=b['symbol'],volume=snap['Vr'],basis=snap['P0'],sl=snap['S0'],swap=snap['position_swap'],mark=snap['mark'],bid=snap['bid'],ask=snap['ask'],time_msc=snap['native_or_observation_time'],reads=2047,valid=True)
    emit('ORIGINAL',dict(run_id=b['run_id'],group_id=b['group_id'],configuration_id=0,V0=o['V0'],S0=o['S0'],E0=o['E0'],R0=o['R0'],profile_hash=b['tester_profile_hash']))
    snapshots=s['residual_snapshots'];current=snapshots[0]
    for i,d in enumerate([s['entry']]+s['exit_portions']):
        passive = i > 0 and d['reason'] == 'DEAL_REASON_SL'
        if passive:emit('STATIC_PROTECTIVE_STOP_INTENT',{})
        if i and not passive:
            emit('BEFORE_REQUEST',position(current))
            intent=record('REQUEST_INTENT:'+str(d['order_id']))
            emit('BEFORE_REQUEST_INTENT',dict(intent=1 if d['role']=='SAFETY_REDUCTION' else 2,volume=d['requested_volume'],position=current['position_ticket'],reason=intent['governed_reason'],FOK=True,attempt_consumed=False))
        if not passive:emit('REQUEST_RESULT',dict(order=d['order_id'],deal=d['deal_id'],retcode=10009,volume=d['executed_volume'],price=d['price']))
        emit('DEAL_ADD','|'.join(map(str,[d['deal_id'],d['order_id'],d['position_id'],d['native_time_msc'],0 if i==0 else 1,0 if i==0 else 1,4 if passive else 3,12001,b['symbol'],d['executed_volume'],d['price'],d['profit'],d['commission'],d['fee'],d['swap'],o['S0'],65535,'true'])),True)
        emit('ORDER_TERMINAL_OBSERVATION',dict(order=d['order_id'],position=current['position_ticket'],state=4,type=0 if i==0 else 1,unfilled='0',symbol=b['symbol']))
        if d['role']=='SAFETY_REDUCTION':current=next(x for x in snapshots if x['predecessor_deal_id']==d['deal_id'])
        if d['role']!='FINAL_CLOSE':emit('RECONCILED_POSITION',position(current))
    if s['terminal']['outcome']=='EVALUATOR_BOUNDARY':emit('TERMINAL_POSITION',position(snapshots[-1]))
    else:emit('TERMINAL_POSITION',dict(position_id=0,position_ticket=0,side=0,magic=0,symbol='',volume='0',basis='0',sl='0',swap='0',mark='0',bid='0',ask='0',time_msc=0,reads=0,valid=True))
    event=next(e for e in r['entries'] if e['role']=='STAGE13_EVENT')
    canonical=files[event['path']].decode();emit('STAGE13_PREPARED',canonical,True)
    emit('STAGE13_COMMITTED',dict(event_hash=digest(canonical),prior_root=canonical.split('|')[38],base_before=s['safety_handoff']['base_before'],base_after=s['safety_handoff']['base_after'],contribution_after='0',financial_projection_count=1,atomic_handoff=True))
    return json_bytes(dict(kind='NATIVE_LIFECYCLE_CAPTURE_V3',run_id=b['run_id'],group_id=b['group_id'],outcome=s['terminal']['outcome'],records=rows))
