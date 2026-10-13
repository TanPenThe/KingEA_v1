"""Synthetic V3 fixtures; these never represent owner execution authority."""
from pathlib import Path
from research_pipeline.decision_a_evidence import *
ROOT=Path(__file__).resolve().parents[1]
DOCS={
 'COMBINED_SPECIFICATION':'governance/review/combined_adoption_20260907/CONSOLIDATED_CONTRACT.md',
 'DECISION_A_SPECIFICATION':'governance/review/decision_a_adoption_plan_20260907/ADOPTED_SPECIFICATION.md',
 'DECISION_S_SPECIFICATION':'governance/review/decision_s_tester_trust_20260907/DECISION_S_REVISED.md',
 'NATIVE_SWAP_PROFILE':'governance/review/decision_s_operational_closure_20260907/NATIVE_SWAP_PROFILE_REFERENCE.json'}
CONFIG=json_bytes({'kind':'SYNTHETIC_CONFIG','parameters':'governed'})
SOURCE=json_bytes({'kind':'SYNTHETIC_SOURCE_MANIFEST','dependencies':{'ea.mq5':digest(b'fixture EA')}})
EXE=b'compile-only fixture, not native execution'
PRICE=json_bytes({'digits':2,'tick':'.01','convention':'NORMALIZE_DOUBLE'})
ARITH=json_bytes({'component_order':['gross','commission','fee','swap'],'denominators':'ORIGINAL'})

def profile():
 return dict(kind='INDEPENDENT_CONTROLLED_TESTER_PROFILE',accepted_proof_sha256=NATIVE_PROOF,
  server='JustMarkets-Demo2',symbol='ETHUSD.s',terminal_build=6140,compiler_build=6140,agent_build=6140,
  local=True,visual=False,dll=False,command_bridge=False,shared_trading_input=False,mql_tester=True,
  post_entry_sl_mutation=False,alternate_order_sink=False,facts=dict(SWAP_FACTS),
  native_swap_profile_hash=digest((ROOT/DOCS['NATIVE_SWAP_PROFILE']).read_bytes()),
  source_manifest_hash=digest(SOURCE),executable_hash=digest(EXE),configuration_hash=digest(CONFIG),
  price_convention_hash=digest(PRICE),arithmetic_contract_hash=digest(ARITH),
  evaluation_start_msc=100,evaluation_end_msc=100000)

def package(f,boundary=False,reduction=False,signed_swap=False,stop_exit=False):
 pprofile=f.profile; group='SYNTHETIC-GROUP-1';run=f.manifest['manifest_sha256'];support={}
 def add(role,value,raw=False):
  data=value if raw else json_bytes(value)
  path='support/'+role.replace(':','_').lower()+('.bin' if raw else '.json')
  support[path]=(role,data);return digest(data)
 def scoped(**kwargs):return dict(run_id=run,group_id=group,**kwargs)
 b=dict(run_id=run,root_hash=f.manifest['root_sha256'],candidate_id=f.binding['candidate_id'],
  configuration_hash=add('CONFIGURATION_SPECIFICATION',CONFIG,True),branch='RECORDED',partition='FINAL_SELECTION',group_id=group,symbol='ETHUSD.s',
  source_manifest_hash=add('SOURCE_MANIFEST',SOURCE,True),executable_hash=add('EXECUTABLE',EXE,True),
  specification_hash=add('COMBINED_SPECIFICATION',(ROOT/DOCS['COMBINED_SPECIFICATION']).read_bytes(),True),
  decision_a_hash=add('DECISION_A_SPECIFICATION',(ROOT/DOCS['DECISION_A_SPECIFICATION']).read_bytes(),True),
  decision_s_hash=add('DECISION_S_SPECIFICATION',(ROOT/DOCS['DECISION_S_SPECIFICATION']).read_bytes(),True),
  freeze_receipt_hash=add('FREEZE_RECEIPT',(f.directory/'freeze.json').read_bytes(),True),
  execution_receipt_hash=add('EXECUTION_RECEIPT',(f.directory/'execution.json').read_bytes(),True),
  tester_profile_hash=add('TESTER_PROFILE',json_bytes(pprofile),True))
 pr=dict(volume_step='.01',volume_digits=8,currency='USD',currency_precision=8,
  price_convention_hash=add('PRICE_CONVENTION',PRICE,True),arithmetic_contract_hash=add('ARITHMETIC_CONTRACT',ARITH,True))
 o=dict(V0='2',P0='100',side='LONG',R0='100',E0='1000',S0='90',position_id=700,
  entry_intent_hash='',entry_effective_stop_hash='')
 deals=[];snaps=[];swaps=[];previous='0'*64
 def deal(i,role,vol,price,profit,commission,fee,reason='STRATEGY_CLOSE'):
  nonlocal previous
  order=100+i;ticket=200+i;time=1000+i*1000
  intent=scoped(order_id=order,role=role,requested_volume=vol,filling='ORDER_FILLING_FOK',context_integrity=True,
   governed_reason='STATIC_PROTECTIVE_STOP' if stop_exit and role=='FINAL_CLOSE' else reason)
  if stop_exit and role=='FINAL_CLOSE':intent['entry_intent_hash']=o['entry_intent_hash']
  if role=='ENTRY':intent.update({k:o[k] for k in ('V0','E0','R0','S0')})
  ih=add('REQUEST_INTENT:'+str(order),intent)
  rh=add('REQUEST_RECEIPT:'+str(order),scoped(order_id=order,terminal=True,read_ok=True,deal_ids=[ticket],
   executed_volume=vol,position_id=700,classification='FOK_FULL_SINGLE_DEAL'))
  d=dict(deal_id=ticket,order_id=order,position_id=700,request_intent_hash=ih,request_receipt_hash=rh,
   role=role,requested_volume=vol,executed_volume=vol,native_time_msc=time,capture_sequence=i+1,price=price,
   profit=profit,commission=commission,fee=fee,swap=('-2' if reduction else '-4') if signed_swap and role!='ENTRY' else '0',reason='DEAL_REASON_SL' if stop_exit and role=='FINAL_CLOSE' else 'DEAL_REASON_EXPERT',exit_sl=None if role=='ENTRY' else '90',
   read_flags={k:True for k in ('volume','price','profit','commission','fee','swap','reason','identity','time')},previous_fact_hash=previous)
  d['read_flags']['exit_sl']='NOT_APPLICABLE' if role=='ENTRY' else True
  d['fact_hash']=add('DEAL:'+str(ticket),d);previous=d['fact_hash'];deals.append(d);return d
 def snapshot(sid,predecessor,time,vol,mark):
  s=dict(snapshot_id=sid,predecessor_deal_id=predecessor,position_id=700,position_ticket=701,
   native_or_observation_time=time,time_source='CALLBACK_OR_TICK_OBSERVATION_MSC',Vr=vol,P0='100',S0='90',
   bid='95',ask='95.01',mark=mark,position_swap=('-2' if sid=='reduced' else '-4') if signed_swap else '0',read_flags={k:True for k in
    ('position_id','ticket','volume','basis','sl','swap','quote','mark','symbol','magic','side')})
  s['snapshot_hash']=add('POSITION_SNAPSHOT:'+sid,s);snaps.append(s);return s
 entry=deal(0,'ENTRY','2','100','0','-2','-1');o['entry_intent_hash']=entry['request_intent_hash']
 o['entry_effective_stop_hash']=add('ENTRY_EFFECTIVE_STOP',scoped(position_id=700,read_ok=True,S0='90',V0='2',P0='100',
  profile_hash=b['tester_profile_hash'],post_entry_mutation_authorized=False,context_integrity=True,unexplained_modification=False,
  observation_overflow=False,observation_time_msc=1000))
 current=snapshot('entry',entry['deal_id'],1100,'2','-10')
 def reconcile(d,before,after_hash):
  swap_hash=add('NATIVE_SWAP_PROFILE',(ROOT/DOCS['NATIVE_SWAP_PROFILE']).read_bytes(),True)
  ih=add('SWAP_INTERVAL:'+str(d['deal_id']),scoped(deal_id=d['deal_id'],no_accrual_authenticated=True,
   native_swap_profile_hash=swap_hash,before_snapshot_hash=before['snapshot_hash'],after_snapshot_hash=after_hash))
  swaps.append(dict(deal_id=d['deal_id'],before_snapshot_hash=before['snapshot_hash'],after_snapshot_hash=after_hash,
   before_swap=before['position_swap'],realized_swap=d['swap'],after_swap=('-2' if signed_swap and d['role']=='SAFETY_REDUCTION' else '0'),interval_accrual='0',interval_authority_hash=ih,native_swap_profile_hash=swap_hash,status='RECONCILED'))
 if reduction:
  d=deal(1,'SAFETY_REDUCTION','1','95','-5','-.5','-.25','SPREAD_ABOVE_2_5X_REDUCE_50_PERCENT')
  after=snapshot('reduced',d['deal_id'],2100,'1','-5');reconcile(d,current,after['snapshot_hash']);current=after
 if not boundary:
  d=deal(len(deals),'FINAL_CLOSE','1' if reduction else '2','105','5' if reduction else '10','-.5','-.25')
  flat=add('FLAT_STATE:'+str(d['deal_id']),scoped(position_id=700,order_id=d['order_id'],terminal=True,flat_authenticated=True))
  reconcile(d,current,flat)
 gross=sum(number(d['profit']) for d in deals)+(number(current['mark']) if boundary else 0)
 commission=sum(number(d['commission']) for d in deals);fee=sum(number(d['fee']) for d in deals)
 swap=sum(number(d['swap']) for d in deals)+(number(current['position_swap']) if boundary else 0);net=gross+commission+fee+swap
 t=dict(outcome='EVALUATOR_BOUNDARY' if boundary else 'NORMAL_CLOSE',time_msc=current['native_or_observation_time'] if boundary else deals[-1]['native_time_msc'],
  aggregate_gross=str(gross),aggregate_commission=str(commission),aggregate_fee=str(fee),aggregate_swap=str(swap),group_net=str(net),
  net_return=str(net/1000),net_R=str(net/100),stage13_event_id='CLOSE-'+group,stage13_sequence=1,stage13_root='',
  financial_projection_count=1,boundary_snapshot_hash=current['snapshot_hash'] if boundary else None)
 c=['0']*39;c[0]='1';c[1]=t['stage13_event_id'];c[2]='9';c[3]=str(t['time_msc']);c[7]=b['candidate_id'];c[8]=b['configuration_hash'];c[10]=group;c[15]='ETHUSD.s'
 c[12]='0' if boundary else str(deals[-1]['order_id']);c[13]='0' if boundary else str(deals[-1]['deal_id']);c[37]='1';c[38]='0'*64
 for key,index in [('aggregate_gross',21),('aggregate_commission',22),('aggregate_swap',23),('aggregate_fee',24),('net_return',30),('net_R',31)]:c[index]=t[key]
 t['stage13_root']=add('STAGE13_EVENT','|'.join(c).encode(),True)
 prior=add('PRIOR_CHECKPOINT',scoped(ledger_root=c[38],base='1000'))
 nxt=add('NEW_CHECKPOINT',scoped(ledger_root=t['stage13_root'],base=str(1000+net)))
 closeid='CLOSE-1';commit=add('STAGE13_COMMIT',scoped(lifecycle_close_id=closeid,stage13_event_hash=t['stage13_root'],financial_projection_count=1,atomic_handoff=True,research_valid=True))
 s=dict(contract_id=CONTRACT,package_id=PACKAGE,semantic_id=SEMANTICS,binding=b,precision=pr,original=o,entry=entry,exit_portions=deals[1:],
  residual_snapshots=snaps,swap_reconciliations=swaps,safety_handoff=dict(lifecycle_close_id=closeid,base_before='1000',contribution_before=str(net),base_after=str(1000+net),
  contribution_after='0',prior_checkpoint_hash=prior,new_checkpoint_hash=nxt,stage13_event_hash=t['stage13_root'],commit_receipt_hash=commit),terminal=t,
  integrity=dict(lifecycle_root=previous,archive_inventory_hash='',sidecar_hash_algorithm='SHA256'))
 binding=dict(b,contract_id=CONTRACT,package_id=PACKAGE,semantic_id=SEMANTICS,inventory_protocol_hash=INVENTORY_ADOPTION)
 files=construct_archive(support,s,binding)
 seal=dict(kind='INDEPENDENT_FINAL_ARCHIVE_SEAL',authority='COMPLETED_PACKAGE_INTEGRITY_ONLY',binding=binding,archive_sha256=digest(files['archive.json']))
 return files,seal,b,pprofile
