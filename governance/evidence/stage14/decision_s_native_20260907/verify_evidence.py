"""Read-only independent Decimal verifier; writes new review artifacts only."""
from pathlib import Path
from decimal import Decimal as D
import json,hashlib
B=Path(__file__).resolve().parent
R=B/'DS-NATIVE-LONG-01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest().upper()
def fields(line):return dict(x.split('=',1) for x in line.split('|') if '=' in x)
def fill(requested,volumes,complete=True):
    if not complete:return 'EXECUTION_EVIDENCE_INCOMPLETE'
    total=sum(volumes,D(0))
    if not volumes:return 'FOK_REJECTED_NO_FILL'
    if total!=requested:return 'PARTIAL_ORDER_EXECUTION' if total<requested else 'EXECUTION_VOLUME_EXCEEDED'
    return 'FOK_FULL_SINGLE_DEAL' if len(volumes)==1 else 'FOK_FULL_MULTI_DEAL'
assert fill(D('.1'),[D('.1')])=='FOK_FULL_SINGLE_DEAL'
assert fill(D('.1'),[D('.04'),D('.06')])=='FOK_FULL_MULTI_DEAL'
assert fill(D('.1'),[])=='FOK_REJECTED_NO_FILL'
assert fill(D('.1'),[D('.04')])=='PARTIAL_ORDER_EXECUTION'
assert fill(D('.1'),[],False)=='EXECUTION_EVIDENCE_INCOMPLETE'
lines=(R/'runtime/native.txt').read_text().splitlines()
journal=(R/'runtime/journal-2.log').read_text(encoding='utf-16')
assert all('DS_NATIVE|'+line in journal for line in lines),'NATIVE_JOURNAL_MIRROR_MISMATCH'
reads={};snaps={};snap_flags={};sends={};receipts={};spec={};current=None
for line in lines:
    f=fields(line)
    if line.startswith('D_READ|'):
        assert f['ok']=='true';ticket=f['ticket'];prop=line.split('|')[2]
        assert prop not in reads.setdefault(ticket,{}),'DUPLICATE_PROPERTY'
        reads[ticket][prop]=f['value']
    if line.startswith('SNAP_BEGIN|'):current=line.split('|')[1];snap_flags[current]=[]
    if line.startswith('P_READ|'):
        assert f['ok']=='true';snap_flags[current].append(line.split('|')[1])
    if line.startswith('SNAP_END|'):snaps[line.split('|')[1]]=f
    if line.startswith('SEND|'):sends[f['stage']]=f
    if line.startswith('RECEIPT|'):receipts[f['stage']]=f
    if line.startswith('SPEC|'):assert f['ok']=='true';spec[line.split('|')[1]]=f['value']
required={'DEAL_ORDER','DEAL_POSITION_ID','DEAL_TIME_MSC','DEAL_ENTRY','DEAL_TYPE','DEAL_REASON','DEAL_VOLUME','DEAL_PRICE','DEAL_PROFIT','DEAL_COMMISSION','DEAL_FEE','DEAL_SWAP','DEAL_SL','DEAL_SYMBOL'}
assert len(reads)==3 and set(snaps)=={'ENTRY','PRE_REDUCTION','POST_REDUCTION','PRE_FINAL_CLOSE'}
for t,d in reads.items():assert set(d)==required and d['DEAL_SYMBOL']=='ETHUSD.s' and d['DEAL_POSITION_ID']=='2'
stages=[]
for stage in ('0','1','2'):
    req=sends[stage];receipt=receipts[stage]
    assert req['FOK']=='1' and receipt['ok']=='true' and receipt['retcode']=='10009'
    deals=[dict(ticket=t,**d) for t,d in reads.items() if d['DEAL_ORDER']==receipt['order']]
    status=fill(D(req['requested_q']),[D(x['DEAL_VOLUME']) for x in deals])
    assert status=='FOK_FULL_SINGLE_DEAL'
    assert deals[0]['DEAL_ENTRY']==('0' if stage=='0' else '1')
    assert deals[0]['DEAL_TYPE']==('0' if stage=='0' else '1')
    assert deals[0]['DEAL_REASON']=='3'
    assert D(receipt['volume'])==D(req['requested_q'])
    stages.append({'stage':stage,'order':receipt['order'],'deal_cardinality':len(deals),'volume_status':status,'requested_volume':req['requested_q'],'executed_volume':str(sum(D(x['DEAL_VOLUME']) for x in deals)),'deals':deals})
for name,s in snaps.items():
    assert len(snap_flags[name])==7
    assert s['id']==snaps['ENTRY']['id'] and s['ticket']==snaps['ENTRY']['ticket']
    assert D(s['basis'])==D(snaps['ENTRY']['basis']) and D(s['sl'])==D(sends['0']['sl'])
assert D(snaps['POST_REDUCTION']['volume'])==D(snaps['ENTRY']['volume'])-D(sends['1']['requested_q'])
ub=D(snaps['PRE_REDUCTION']['swap']);ua=D(snaps['POST_REDUCTION']['swap']);uf=D(snaps['PRE_FINAL_CLOSE']['swap'])
ds=D(stages[1]['deals'][0]['DEAL_SWAP']);df=D(stages[2]['deals'][0]['DEAL_SWAP'])
assert ub!=0 and ds!=0 and ua!=0 and df!=0
assert ub==ds+ua and ua==uf and uf==df and ds+df==ub
assert D(stages[0]['deals'][0]['DEAL_SWAP'])==0
assert any(x.startswith('DEINIT|') and 'phase=5' in x and 'overflow=false' in x for x in lines)
assert len([x for x in lines if x.startswith('TX|') and fields(x)['type']=='6'])==3
receipt=json.loads((R/'RUNTIME_RECEIPT.json').read_text());assert receipt['exit_code']==0 and receipt['resource_stop'] is None
production=json.loads((B/'PRODUCTION_BASELINE.json').read_text(encoding='utf-8-sig'))
assert all(sha(x['path'])==x['sha256'] for x in production)
result={'classification':'REALIZED_RESIDUAL_SWAP_DISJOINT_CONFIRMED','scope':'OBSERVED_LONG_LIFECYCLE_ON_BOUND_BUILD_AND_SYMBOL_PROFILE_ONLY','independent_review_acceptance':'PENDING','decision_s':'NOT_ADOPTED','b2':'LOCKED','Ub':str(ub),'reduction_DEAL_SWAP':str(ds),'Ua':str(ua),'pre_final_POSITION_SWAP':str(uf),'final_DEAL_SWAP':str(df),'total_actual_deal_swap':str(ds+df),'nonzero_obtained':True,'volume_basis_identity_s0':'PASS','exact_decimal_swap_conservation':'PASS','journal_evidence_mirror':'PASS','successful_property_reads':'PASS','cardinality_classifier_controls_passed':5,'production_files_unchanged':len(production),'stages':stages,'snapshots':snaps,'specification':spec,'native_evidence_sha256':sha(R/'runtime/native.txt'),'limitations':['One LONG lifecycle, not SHORT/triple-rollover/profile-universal proof.','No claim of complete upstream native transaction observation; observed lifecycle cardinalities and receipt volumes reconcile.','Pre/post snapshots share the tester second and reduction occurs at noon; this observation does not define a general authenticated accrual/correction source for all intervals.','Stage13 and production A/S integration are not implemented or tested.','Standalone callback performs bounded diagnostic file/Print I/O; not the proposed production constant-work capture design.']}
with (B/'INDEPENDENT_VERIFICATION.json').open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
print(json.dumps({k:v for k,v in result.items() if k not in ('stages','snapshots','specification','limitations')}))
