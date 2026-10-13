#ifndef KINGEA_NATIVE_COST_CONTRACT_TESTS_MQH
#define KINGEA_NATIVE_COST_CONTRACT_TESTS_MQH
#include "NativeCostEvidence.mqh"
int nc_checks=0,nc_failures=0;
void NCCheck(const bool ok,const string name)
  { nc_checks++; if(!ok) { nc_failures++; Print("NC_FAIL|",name); } }
void NCFixture(KingEANativeCostBinding &b,KingEANativeDealFact &d,KingEANativeCostSnapshot &s,const int side=1)
  {
   ZeroMemory(b); ZeroMemory(d); ZeroMemory(s);
   b.run="NON_CANDIDATE"; b.configuration=0; b.branch="SYNTHETIC"; b.partition="CONFORMANCE";
   b.group="GROUP-1"; b.symbol="FIXTURE"; b.magic=99005; b.side=side; b.volume=1;
   b.start_msc=1000; b.end_msc=10000;
   d.read_ok=true; d.deal=10; d.order=11; d.position_id=12; d.time_msc=2000;
   d.symbol=b.symbol; d.magic=b.magic; d.entry=DEAL_ENTRY_IN;
   d.type=(side==1 ? DEAL_TYPE_BUY : DEAL_TYPE_SELL); d.volume=1; d.price=100;
   d.commission=-1; d.fee=-0.25;
   s.time_msc=9000; s.position_id=12; s.position_ticket=77; s.side=side;
   s.volume=1; s.entry=100; s.bid=102; s.ask=103; s.swap=-0.5;
   s.mark=(side==1 ? 2 : -3); // Injected native-profit fact at the terminal seam only.
   s.position_read_ok=true; s.profit_read_ok=true;
   s.currency="USD"; s.specification_hash=KingEAAccountingSha256("FIXTURE_SPEC");
  }
bool NCReady(KingEANativeCostEvidence &l,KingEANativeCostBinding &b,KingEANativeDealFact &d,KingEANativeCostSnapshot &s)
  {
   if(!l.Begin(b)) return false;
   d.binding=l.BindingHash(); s.binding=d.binding;
   return l.CaptureEntry(d) && l.ReconcileReceipt(10,11,1,100) && l.Seal(s);
  }
KingEAAccountingEvent NCBase()
  {
   KingEAAccountingEvent e={}; e.schema_version=1; e.event_id="BOUNDARY-1";
   e.trade_group_id="GROUP-1"; e.symbol="FIXTURE"; e.server_time_msc=9000; e.utc_time_msc=9000;
   e.account_fingerprint="SYNTHETIC"; e.deployment_id="NON_CANDIDATE"; return e;
  }
bool NCProject(KingEANativeCostEvidence &l,KingEAAccountingDecision &d,string &sidecar,KingEAAccountingEvent &e)
  {
   KingEAAccountingCheckpoint p={}; KingEAAccountingEvent base=NCBase();
   bool ok=l.Finalize(base,p,1000,10,false,e,d,sidecar);
   if(ok) NCCheck(e.deal_ticket==0 && e.order_ticket==0 && e.position_ticket==77,"zero closing tickets / original linkage");
   return ok;
  }
bool NCProject(KingEANativeCostEvidence &l,KingEAAccountingDecision &d,string &sidecar)
  { KingEAAccountingEvent e={}; return NCProject(l,d,sidecar,e); }
void NCRunContracts()
  {
   for(int side=-1;side<=1;side+=2)
     {
      KingEANativeCostBinding b; KingEANativeDealFact f; KingEANativeCostSnapshot s;
      NCFixture(b,f,s,side); KingEANativeCostEvidence a,bvariant;
      NCCheck(NCReady(a,b,f,s),"entry before position observation accepted");
      NCCheck(NCReady(bvariant,b,f,s),"second isolated fixture");
      KingEAAccountingCheckpoint untouched={};
      NCCheck(untouched.strategy_net_pnl==0 && a.CostFactCount()==1,"metadata has zero financial mutation");
      string root=a.Root(); KingEANativeCostSnapshot late=s; late.time_msc=10000; late.mark=1e12; late.swap=-1e9;
      NCCheck(!a.Seal(late) && root==a.Root(),"post-end mark and swap cannot mutate snapshot");
      KingEAAccountingDecision da={},db={}; string sa,sb;
      NCCheck(NCProject(a,da,sa) && NCProject(bvariant,db,sb),"both terminal variants finalize");
      NCCheck(da.event_net_pnl==(side==1 ? 0.25 : -4.75),"exact signed cost sum once");
      NCCheck(da.event_sha256==db.event_sha256 && sa==sb,"A/B custom result equality");
      NCCheck(a.BoundaryCount()==1,"one boundary count");
      f.entry=DEAL_ENTRY_OUT; f.type=(side==1 ? DEAL_TYPE_SELL : DEAL_TYPE_BUY); f.time_msc=10000; f.deal=99; f.order=98;
      string before=bvariant.Root();
      NCCheck(bvariant.Housekeeping(f,KingEAAccountingSha256("SYNTHETIC_LIFECYCLE_PROOF"),true),"observable terminal close classified separately");
      NCCheck(before==bvariant.Root() && da.event_sha256==db.event_sha256 && bvariant.BoundaryCount()==1,"housekeeping leaves financial and cost roots unchanged");
      NCCheck(!NCProject(a,da,sa),"second projection rejected");
     }
   for(int mutation=0;mutation<18;mutation++)
     {
      KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
      NCFixture(b,d,s); KingEANativeCostEvidence l; l.Begin(b); d.binding=l.BindingHash();
      if(mutation==0) d.read_ok=false;
      if(mutation==1) d.binding="FOREIGN_RUN";
      if(mutation==2) d.symbol="FOREIGN";
      if(mutation==3) d.magic++;
      if(mutation==4) d.deal=0;
      if(mutation==5) d.order=0;
      if(mutation==6) d.position_id=0;
      if(mutation==7) d.entry=DEAL_ENTRY_OUT;
      if(mutation==8) d.entry=DEAL_ENTRY_INOUT;
      if(mutation==9) d.type=DEAL_TYPE_SELL;
      if(mutation==10) d.volume=0.5;
      if(mutation==11) d.price=0;
      if(mutation==12) d.time_msc=999;
      if(mutation==13) d.time_msc=10000;
      if(mutation==14) d.swap=-1;
      if(mutation==15) d.binding=KingEAAccountingSha256("WRONG_GROUP");
      if(mutation==16) d.commission=MathSqrt(-1.0);
      if(mutation==17) d.fee=MathSqrt(-1.0);
      NCCheck(!l.CaptureEntry(d) && !l.Healthy(),"entry mutation "+(string)mutation);
     }
   for(int mutation=0;mutation<9;mutation++)
     {
      KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
      NCFixture(b,d,s); KingEANativeCostEvidence l; l.Begin(b); d.binding=l.BindingHash();
      l.CaptureEntry(d); l.ReconcileReceipt(10,11,1,100); s.binding=l.BindingHash();
      if(mutation==0) s.position_id++;
      if(mutation==1) s.position_read_ok=false;
      if(mutation==2) s.profit_read_ok=false;
      if(mutation==3) s.side=0;
      if(mutation==4) s.volume=0.5;
      if(mutation==5) s.entry=101;
      if(mutation==6) s.binding="WRONG_GROUP";
      if(mutation==7) s.specification_hash="";
      if(mutation==8) s.bid=104;
      NCCheck(!l.Seal(s),"snapshot mutation "+(string)mutation);
     }
   {
    KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
    NCFixture(b,d,s); KingEANativeCostEvidence l; l.Begin(b); d.binding=l.BindingHash();
    d.commission=0; d.fee=0;
    NCCheck(l.CaptureEntry(d),"successful zero commission and fee accepted");
    NCCheck(!l.CaptureEntry(d),"duplicate captured only once");
   }
   {
    KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
    NCFixture(b,d,s); KingEANativeCostEvidence l; l.Begin(b); s.binding=l.BindingHash();
    NCCheck(!l.Seal(s),"missing entry costs fail closed");
   }
   {
    KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
    NCFixture(b,d,s); KingEANativeCostEvidence l; NCReady(l,b,d,s);
    NCCheck(l.MarkNormalClose(12,9500,true),"normal pre-end close takes precedence");
    KingEAAccountingDecision out={}; string sidecar;
    NCCheck(!NCProject(l,out,sidecar),"normal financially projected close excludes boundary");
   }
   {
    KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
    NCFixture(b,d,s); KingEANativeCostEvidence l; NCReady(l,b,d,s);
    KingEAAccountingDecision out={}; string sidecar; NCProject(l,out,sidecar);
    NCCheck(!l.Housekeeping(d,"",false),"ambiguous housekeeping fails closed");
   }
   {
    KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
    NCFixture(b,d,s); KingEANativeCostEvidence l; l.Begin(b);
    NCCheck(l.ExpirePending(10000)=="PARTITION_END_PENDING_EXPIRY" && l.BoundaryCount()==0 && l.CostFactCount()==0,"pending expiry without trade or PnL");
   }
   {
    KingEANativeCostBinding b; KingEANativeDealFact d; KingEANativeCostSnapshot s;
    NCFixture(b,d,s); b.side=0; KingEANativeCostEvidence l;
    NCCheck(!l.Begin(b),"invalid direction rejected explicitly");
   }
  }
#endif
