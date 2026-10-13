"""Read-only production native-cost/boundary evidence validation. No pricing or research."""
from __future__ import annotations
import hashlib
import json
import math
from decimal import Decimal
from pathlib import Path

COST='CDFE801225C54C622A566CB125FE37B0759A3E47320D988571B796629CF984D9'
MTM='909C23E3B14BB64A62BC371890B2FFFB1964D24FC24879971DB614FB078E92C6'

def digest(value):
    return hashlib.sha256(value if isinstance(value,bytes) else value.encode()).hexdigest().upper()

def require(ok, reason):
    if not ok: raise ValueError(reason)

def unique(pairs):
    result={}
    for key,value in pairs:
        require(key not in result,'DUPLICATE_EVIDENCE_FIELD')
        result[key]=value
    return result

def fields(text):
    return unique(part.split('=',1) for part in text.split('|'))

def finite(text):
    value=Decimal(text)
    require(value.is_finite(),'NON_FINITE_EVIDENCE')
    return value

class NativeCostArchiveConsumer:
    @staticmethod
    def validate_package(raw, scope):
        text=raw.decode('utf-8') if isinstance(raw,bytes) else raw
        payload,seal=text.rsplit('|sha256=',1)
        require(digest(payload)==seal,'PACKAGE_HASH_MISMATCH')
        p=json.loads(payload,object_pairs_hook=unique)
        require(p['schema'] in ('NATIVE_COST_BOUNDARY_PACKAGE_V1','NATIVE_COST_BOUNDARY_PACKAGE_V2'),'PACKAGE_SCHEMA')
        if scope.get('package_schema'): require(p['schema']==scope['package_schema'],'PACKAGE_VERSION_MISMATCH')
        for name in ('run','configuration','branch','partition'):
            require(p[name]==scope[name],'PACKAGE_SCOPE_MISMATCH')
        require(p['boundary_finalization_count']==1 and p['candidate_exit_count_delta']==0,'PROJECTION_COUNT')
        records=p['records']; require(len(records)>=3,'COST_RECORDS_MISSING')
        parents=[]; bodies=[]; roots=[]
        for record in records:
            parent,body=record.split('|',1); body,root=body.rsplit('|',1)
            require(digest(parent+'|'+body)==root,'COST_RECORD_HASH')
            if roots: require(parent==roots[-1],'COST_CHAIN_DISCONTINUITY')
            parents.append(parent); bodies.append(body.split('|')); roots.append(root)
        b=bodies[0]
        require(len(b)==12 and b[0]=='BINDING','COST_BINDING_MISSING')
        binding=digest('|'.join(b[1:]))
        require(parents[0]==digest(COST+'|'+binding),'COST_ADOPTION_OR_BINDING')
        require((b[1],int(b[2]),b[3],b[4],b[5])==
                (p['run'],p['configuration'],p['branch'],p['partition'],p['group']),'GROUP_BINDING')
        require(b[8] in ('1','-1') and finite(b[9])>0 and int(b[7])>0 and
                0<int(b[10])<int(b[11]),'INVALID_BOUND_GROUP')
        entry=bodies[1]
        require(len(entry)==10 and entry[0]=='ENTRY_METADATA' and entry[1]==binding,'ENTRY_METADATA_MISSING')
        require(all(int(x)>0 for x in entry[2:5]) and int(b[10])<=int(entry[5])<int(b[11])
                and entry[6]==b[9] and finite(entry[7])>0,'ENTRY_IDENTITY')
        finite(entry[8]); finite(entry[9])
        previous=int(entry[5]); first_ticket=None
        for s in bodies[2:]:
            require(len(s)==14 and s[0]=='PRE_END_SNAPSHOT' and s[1]==binding,'UNSUPPORTED_COST_RECORD')
            require(previous<=int(s[2])<int(b[11]) and s[3]==entry[4] and int(s[4])>0
                    and s[7]==entry[7] and s[8]==entry[6] and s[9]==b[8],'SNAPSHOT_IDENTITY')
            require(0<finite(s[5])<=finite(s[6]) and len(s[12])==64 and s[13]!='','SNAPSHOT_QUOTE')
            finite(s[10]); finite(s[11]); previous=int(s[2])
            if first_ticket is None: first_ticket=s[4]
        side,side_hash=p['sidecar'].rsplit('|sha256=',1)
        require(digest(side)==side_hash,'SIDECAR_HASH')
        prefix=side.split('|',3)
        require(prefix[:3]==['BOUNDARY_EVIDENCE',MTM,binding],'SIDECAR_POLICY_OR_BINDING')
        f=fields(prefix[3]); s=bodies[-1]
        expected={'evaluator_forced':'true','position_id':entry[4],'position_ticket':first_ticket,
                  'quote_time':s[2],'bid':s[5],'ask':s[6],'entry':s[7],'volume':s[8],'side':s[9],
                  'swap':s[10],'mark':s[11],'specification':s[12],'currency':s[13],
                  'commission':entry[8],'fee':entry[9],'cost_root':roots[-1],'boundary_finalization_count':'1'}
        require(all(f.get(k)==v for k,v in expected.items()),'SIDECAR_SNAPSHOT_COST_LINK')
        frame=fields(p['stage13_frame']); canonical=p['stage13_canonical']; c=canonical.split('|')
        require(len(c)==39 and c[0]=='1' and c[2]=='9','STAGE13_CANONICAL_SCHEMA')
        require(digest(canonical)==f['stage13_root']==frame['root'],'STAGE13_HASH_LINK')
        require(frame['schema']=='1' and frame['event_type']=='9' and
                f['event_id']==frame['event_id']==c[1] and f['sequence']==frame['sequence']==c[37]
                and int(c[37])>0 and len(c[38])==64,'STAGE13_EVENT_SEQUENCE_LINK')
        require(c[3]==frame['server_time_msc']==f['quote_time'] and c[10]==frame['group']==p['group']
                and c[15]==b[6] and c[16]==b[8] and c[12]==c[13]==frame['order']==frame['deal']=='0'
                and c[14]==frame['position']==first_ticket,'STAGE13_IDENTITY_LINK')
        require(c[35]=='EVALUATION_BOUNDARY_MARK_TO_MARKET_FINALIZATION' and
                c[36]=='EVALUATOR_PRE_END_MARK_TO_MARKET_V3','STAGE13_BOUNDARY_SEMANTICS')
        # Compare retained projections, never recalculate a mark using a second pricing model.
        for field,index in (('mark',21),('commission',22),('swap',23),('fee',24),('volume',17)):
            require(c[index]==format(float(f[field]),'.8f'),'STAGE13_CANONICAL_AMOUNT_LINK')
        quote=f['bid'] if b[8]=='1' else f['ask']
        require(c[19]==format(float(quote),'.8f') and all(Decimal(c[i])==0 for i in (18,25,26,27)),
                'STAGE13_PRICE_OR_DOUBLE_CHARGE')
        for field,side_field in (('gross','mark'),('commission','commission'),('swap','swap'),('fee','fee')):
            require(frame[field]==format(float(f[side_field]),'.12f'),'STAGE13_FRAME_COST_LINK')
        net=float(f['mark'])+float(f['commission'])+float(f['fee'])+float(f['swap'])
        require(math.isfinite(net) and frame['net']==format(net,'.12f') and
                frame['net_return']==c[30] and frame['net_r']==c[31],'STAGE13_NET_LINK')
        housekeeping=p['housekeeping_evidence'] if p['schema'].endswith('V2') else []
        require(isinstance(housekeeping,list) and len(housekeeping)<=1,'DUPLICATE_HOUSEKEEPING_EVIDENCE')
        for h in housekeeping:
            require(h['classification']=='STRATEGY_TESTER_END_OF_TEST_HOUSEKEEPING' and
                    h['binding']==binding and h['position_id']==int(entry[4]) and h['deal']>0 and h['order']>0
                    and h['side']==int(b[8]) and Decimal(str(h['volume']))==Decimal(b[9])
                    and h['time_msc']>=int(s[2]) and h['boundary_sha256']==side_hash
                    and h['financial_projection_count']==0,'HOUSEKEEPING_BINDING')
            require(digest(h['proof_material'])==h['proof_sha256'],'HOUSEKEEPING_PROOF_MISSING_OR_ALTERED')
            require(h['origin']=='NATIVE_TRANSACTION' or
                    (h['origin']=='SYNTHETIC_INJECTED' and scope.get('non_candidate') is True),
                    'SYNTHETIC_HOUSEKEEPING_NOT_NATIVE_EVIDENCE')
        return {'status':'PASS','binding':binding,'group':p['group'],'stage13_root':f['stage13_root'],
                'sequence':int(f['sequence']),'stage13_frame':p['stage13_frame'],
                'boundary_finalization_count':1,'candidate_exit_count_delta':0,
                'housekeeping_count':len(housekeeping),'package_sha256':seal}

    @classmethod
    def validate_packages(cls, packages, scope, *, boundary_count, close_frames):
        require(len(close_frames)==len(set(close_frames)),'DUPLICATE_STAGE13_CLOSE_FRAME')
        results=[]; groups=set(); roots=set()
        for raw in packages:
            result=cls.validate_package(raw,scope)
            require(result['group'] not in groups and result['stage13_root'] not in roots,'DUPLICATE_BOUNDARY_EVIDENCE')
            require(result['stage13_frame'] in close_frames,'BOUNDARY_STAGE13_CLOSE_MISSING_OR_ALTERED')
            groups.add(result['group']); roots.add(result['stage13_root']); results.append(result)
        require(boundary_count==len(results),'MISSING_OR_EXTRA_BOUNDARY_EVIDENCE')
        # A zero-ticket evaluator close cannot be hidden by setting boundary_count to zero.
        evaluator=[f for f in close_frames if '|event_type=9|' in f and '|order=0|deal=0|' in f]
        require(set(evaluator)=={r['stage13_frame'] for r in results},'UNBOUND_EVALUATOR_CLOSE')
        return {'status':'PASS','boundary_finalization_count':len(results),'groups':sorted(groups)}

    @staticmethod
    def selection_guard(funnel):
        counts=('entries','trade_groups','intents','safety_evaluations','approved','route_attempts','fills','accounting_submissions')
        require(all(type(funnel.get(k)) is int and funnel[k]>=0 for k in counts),'FUNNEL_FACTS_INVALID')
        broken=any(funnel[a]>0 and funnel[b]==0 for a,b in
                   [('intents','safety_evaluations'),('approved','route_attempts'),('fills','accounting_submissions')])
        return 'QUARANTINE_BEFORE_SELECTION' if broken or funnel['entries']==0 or funnel['trade_groups']==0 else 'PASS'
