#ifndef KINGEA_NATIVE_COST_EVIDENCE_MQH
#define KINGEA_NATIVE_COST_EVIDENCE_MQH
#include "AccountingEvents.mqh"

// Adopted V2 metadata / V4 MTM. No terminal, history, equity or order access.
#define KINGEA_COST_ADOPTION "CDFE801225C54C622A566CB125FE37B0759A3E47320D988571B796629CF984D9"
#define KINGEA_MTM_ADOPTION "909C23E3B14BB64A62BC371890B2FFFB1964D24FC24879971DB614FB078E92C6"
struct KingEANativeCostBinding
  {
   string run,branch,partition,group,symbol;
   int configuration,side;
   ulong magic;
   double volume;
   long start_msc,end_msc;
  };
struct KingEANativeDealFact
  {
   string binding,symbol;
   bool read_ok;
   ulong deal,order,position_id,magic;
   long time_msc,entry,type;
   double volume,price,commission,fee,swap;
  };
struct KingEANativeCostSnapshot
  {
   string binding,specification_hash,currency;
   long time_msc;
   ulong position_id,position_ticket;
   int side;
   double volume,entry,bid,ask,swap,mark;
   bool position_read_ok,profit_read_ok;
  };

string KingEACostNumber(const double x) { return DoubleToString(x,16); }
bool KingEACostText(const string x)
  { return x!="" && StringFind(x,"|")<0 && StringFind(x,"\n")<0 && StringFind(x,"\r")<0; }

class KingEANativeCostEvidence
  {
private:
   KingEANativeCostBinding m_b;
   KingEANativeDealFact m_d;
   KingEANativeCostSnapshot m_s;
   string m_binding,m_root,m_snapshot_hash,m_reason,m_records[];
   bool m_active,m_failed,m_captured,m_receipt,m_snapshot,m_finalized,m_normal;
   int m_boundary_count,m_housekeeping_count;
   bool Fail(const string why) { m_failed=true; m_reason=why; return false; }
   void Append(const string record)
     {
      int n=ArraySize(m_records);
      string prior=m_root;
      m_root=KingEAAccountingSha256(prior+"|"+record);
      ArrayResize(m_records,n+1);
      m_records[n]=prior+"|"+record+"|"+m_root;
     }
public:
   KingEANativeCostEvidence()
     { m_active=false; m_failed=false; m_captured=false; m_receipt=false;
       m_snapshot=false; m_finalized=false; m_normal=false;
       m_boundary_count=0; m_housekeeping_count=0; }
   bool Begin(const KingEANativeCostBinding &b)
     {
      if(m_active) return Fail("GROUP_ALREADY_ACTIVE");
      if(!KingEACostText(b.run) || !KingEACostText(b.branch) ||
         !KingEACostText(b.partition) || !KingEACostText(b.group) ||
         !KingEACostText(b.symbol) || b.configuration<0 || b.magic==0 ||
         (b.side!=1 && b.side!=-1) || !MathIsValidNumber(b.volume) || b.volume<=0 ||
         b.start_msc<=0 || b.end_msc<=b.start_msc) return Fail("BINDING_INVALID");
      m_b=b; m_active=true;
      m_binding=KingEAAccountingSha256(b.run+"|"+(string)b.configuration+"|"+
         b.branch+"|"+b.partition+"|"+b.group+"|"+b.symbol+"|"+(string)b.magic+"|"+
         (string)b.side+"|"+KingEACostNumber(b.volume)+"|"+(string)b.start_msc+"|"+(string)b.end_msc);
      m_root=KingEAAccountingSha256(KINGEA_COST_ADOPTION+"|"+m_binding);
      return true;
     }
   string BindingHash() { return m_binding; }
   string Root() { return m_root; }
   string Reason() { return m_reason; }
   bool Healthy() { return m_active && !m_failed; }
   bool Finalized() { return m_finalized; }
   bool NormalClosed() { return m_normal; }
   int BoundaryCount() { return m_boundary_count; }
   int CostFactCount() { return m_captured ? 1 : 0; }
   int RecordCount() { return ArraySize(m_records); }
   string Record(const int i) { return i>=0 && i<ArraySize(m_records) ? m_records[i] : ""; }
   ulong PositionId() { return m_d.position_id; }
   double SealedNet() { return m_s.mark+m_d.commission+m_d.fee+m_s.swap; }
   long SealedTime() { return m_s.time_msc; }
   bool CaptureEntry(const KingEANativeDealFact &d)
     {
      if(!Healthy() || m_finalized || m_normal) return Fail("COST_STATE_INVALID");
      if(m_captured) return Fail("SECOND_ENTRY_DEAL_UNSUPPORTED");
      if(!d.read_ok || d.binding!=m_binding || d.symbol!=m_b.symbol || d.magic!=m_b.magic ||
         d.deal==0 || d.order==0 || d.position_id==0 || d.entry!=DEAL_ENTRY_IN ||
         d.type!=(m_b.side==1 ? DEAL_TYPE_BUY : DEAL_TYPE_SELL) ||
         !MathIsValidNumber(d.volume) || d.volume!=m_b.volume ||
         !MathIsValidNumber(d.price) || d.price<=0 ||
         !MathIsValidNumber(d.commission) || !MathIsValidNumber(d.fee) ||
         !MathIsValidNumber(d.swap) || d.swap!=0 ||
         d.time_msc<m_b.start_msc || d.time_msc>=m_b.end_msc)
         return Fail("ENTRY_METADATA_UNPROVEN_OR_UNSUPPORTED");
      m_d=d; m_captured=true;
      Append("ENTRY_METADATA|"+m_binding+"|"+(string)d.deal+"|"+(string)d.order+"|"+
         (string)d.position_id+"|"+(string)d.time_msc+"|"+KingEACostNumber(d.volume)+"|"+
         KingEACostNumber(d.price)+"|"+KingEACostNumber(d.commission)+"|"+KingEACostNumber(d.fee));
      return true;
     }
   bool ReconcileReceipt(const ulong deal,const ulong order,const double volume,const double price)
     {
      if(!Healthy() || !m_captured || deal!=m_d.deal || order!=m_d.order ||
         volume!=m_d.volume || price!=m_d.price) return Fail("RECEIPT_MISMATCH");
      m_receipt=true; return true;
     }
   bool Seal(const KingEANativeCostSnapshot &s)
     {
      if(!Healthy() || !m_captured || !m_receipt || m_finalized || m_normal)
         return Fail("SNAPSHOT_COST_BASIS_UNPROVEN");
      if(s.time_msc>=m_b.end_msc) { m_reason="POST_END_SNAPSHOT_PROHIBITED"; return false; }
      if(s.binding!=m_binding || !s.position_read_ok || !s.profit_read_ok ||
         s.position_id!=m_d.position_id || s.position_ticket==0 ||
         s.side!=m_b.side || s.volume!=m_d.volume || s.entry!=m_d.price ||
         s.time_msc<m_d.time_msc || s.time_msc<m_b.start_msc ||
         (m_snapshot && s.time_msc<m_s.time_msc) ||
         !MathIsValidNumber(s.bid) || !MathIsValidNumber(s.ask) || s.bid<=0 || s.ask<s.bid ||
         !MathIsValidNumber(s.swap) || !MathIsValidNumber(s.mark) ||
         !KingEAAccountingHash(s.specification_hash) || !KingEACostText(s.currency))
         return Fail("SNAPSHOT_IDENTITY_OR_VALUATION_INVALID");
      m_s=s;
      Append("PRE_END_SNAPSHOT|"+m_binding+"|"+(string)s.time_msc+"|"+(string)s.position_id+"|"+
         (string)s.position_ticket+"|"+KingEACostNumber(s.bid)+"|"+KingEACostNumber(s.ask)+"|"+
         KingEACostNumber(s.entry)+"|"+KingEACostNumber(s.volume)+"|"+(string)s.side+"|"+
         KingEACostNumber(s.swap)+"|"+KingEACostNumber(s.mark)+"|"+s.specification_hash+"|"+s.currency);
      m_snapshot_hash=m_root; m_snapshot=true; return true;
     }
   bool MarkNormalClose(const ulong position_id,const long native_time_msc,
                        const bool financially_projected)
     {
      if(!Healthy() || !m_captured || m_finalized || !financially_projected ||
         position_id!=m_d.position_id || native_time_msc<m_d.time_msc || native_time_msc>=m_b.end_msc)
         return Fail("NORMAL_CLOSE_ATTRIBUTION_UNPROVEN");
      m_normal=true; return true;
     }
   bool Finalize(const KingEAAccountingEvent &base,const KingEAAccountingCheckpoint &prior,
                 const double entry_equity,const double original_risk,
                 const bool prior_group_financial_booking,
                 KingEAAccountingEvent &event,KingEAAccountingDecision &decision,string &sidecar)
     {
      ZeroMemory(event); ZeroMemory(decision); sidecar="";
      if(!Healthy() || !m_snapshot || !m_receipt || m_finalized || m_normal || prior_group_financial_booking)
         return Fail("BOUNDARY_FINALIZATION_STATE_INVALID");
      if(base.schema_version!=1 || base.trade_group_id!=m_b.group || base.symbol!=m_b.symbol ||
         base.server_time_msc!=m_s.time_msc || prior.last_server_time_msc>m_s.time_msc ||
         !MathIsValidNumber(entry_equity) || entry_equity<=0 ||
         !MathIsValidNumber(original_risk) || original_risk<=0)
         return Fail("BOUNDARY_ACCOUNTING_BASIS_UNPROVEN");
      event=base;
      event.event_type=KINGEA_ACCOUNTING_EVENT_TRADE_GROUP_CLOSE;
      event.order_ticket=0; event.deal_ticket=0; event.position_ticket=m_s.position_ticket;
      event.direction=m_b.side; event.volume=m_s.volume;
      event.requested_price=0; event.executed_price=(m_b.side==1 ? m_s.bid : m_s.ask);
      event.gross_profit=m_s.mark; event.commission=m_d.commission;
      event.fee=m_d.fee; event.swap=m_s.swap;
      event.spread_attribution=0; event.slippage_attribution=0; event.external_cash_flow=0;
      event.account_equity=entry_equity+SealedNet(); event.sleeve_equity=event.account_equity;
      event.net_return=SealedNet()/entry_equity; event.net_r=SealedNet()/original_risk;
      event.reason_code="EVALUATION_BOUNDARY_MARK_TO_MARKET_FINALIZATION";
      event.source_quality="EVALUATOR_PRE_END_MARK_TO_MARKET_V3";
      KingEAProcessAccountingEvent(event,prior,decision);
      if(!decision.accepted) return Fail("BOUNDARY_STAGE13_REJECTED");
      m_finalized=true; m_boundary_count=1;
      sidecar="BOUNDARY_EVIDENCE|"+KINGEA_MTM_ADOPTION+"|"+m_binding+"|evaluator_forced=true|"+
         "position_id="+(string)m_d.position_id+"|position_ticket="+(string)m_s.position_ticket+
         "|quote_time="+(string)m_s.time_msc+"|bid="+KingEACostNumber(m_s.bid)+"|ask="+KingEACostNumber(m_s.ask)+
         "|entry="+KingEACostNumber(m_s.entry)+"|volume="+KingEACostNumber(m_s.volume)+"|side="+(string)m_b.side+
         "|mark="+KingEACostNumber(m_s.mark)+"|commission="+KingEACostNumber(m_d.commission)+
         "|fee="+KingEACostNumber(m_d.fee)+"|swap="+KingEACostNumber(m_s.swap)+
         "|specification="+m_s.specification_hash+"|currency="+m_s.currency+"|cost_root="+m_snapshot_hash+
         "|event_id="+event.event_id+"|sequence="+(string)decision.sequence+"|stage13_root="+decision.event_sha256+
         "|boundary_finalization_count=1";
      sidecar+="|sha256="+KingEAAccountingSha256(sidecar);
      return true;
     }
   bool Housekeeping(const KingEANativeDealFact &d,const string lifecycle_evidence_hash,
                     const bool unambiguous_tester_close)
     {
      // A proof producer must distinguish native lifecycle evidence. Timestamp/type alone cannot.
      if(!Healthy() || !m_finalized || !unambiguous_tester_close ||
         !KingEAAccountingHash(lifecycle_evidence_hash) || !d.read_ok ||
         d.binding!=m_binding || d.position_id!=m_d.position_id || d.symbol!=m_b.symbol ||
         d.magic!=m_b.magic || d.deal==0 || d.order==0 || d.entry!=DEAL_ENTRY_OUT ||
         d.type!=(m_b.side==1 ? DEAL_TYPE_SELL : DEAL_TYPE_BUY) || d.volume!=m_b.volume ||
         d.time_msc<m_s.time_msc || m_housekeeping_count!=0)
         return Fail("HOUSEKEEPING_ATTRIBUTION_AMBIGUOUS");
      m_housekeeping_count++; m_reason="STRATEGY_TESTER_END_OF_TEST_HOUSEKEEPING";
      return true; // Absolutely no cost-chain or financial mutation.
     }
   string ExpirePending(const long now_msc)
     {
      if(!Healthy() || m_captured || now_msc<m_b.end_msc) { Fail("PENDING_EXPIRY_INVALID"); return ""; }
      m_reason="PARTITION_END_PENDING_EXPIRY"; return m_reason;
     }
  };
#endif
