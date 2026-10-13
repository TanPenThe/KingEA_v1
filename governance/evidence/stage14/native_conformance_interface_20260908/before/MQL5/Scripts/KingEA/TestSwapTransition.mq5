#property strict
#include <KingEA/DecisionADealAdapter.mqh>
#include <KingEA/DecisionAStaticStop.mqh>
// Deterministic synthetic harness. Compile only under this authorization.
int failures=0;
void Check(bool ok,string name){if(!ok){failures++;Print("FAIL ",name);}}
void Entry(DecisionALifecycle &l,DAPosition &p,DADeal &d){
 l.Reset();Check(l.Begin("synthetic","ETHUSD.s",1,2,90,1000,100,2,10000),"begin");
 Check(l.Prepare(DA_ENTRY,2),"entry intent");l.Receipt(10,true,2,true);
 ZeroMemory(d);d.ticket=100;d.order=10;d.position=700;d.time_msc=1000;d.entry=DEAL_ENTRY_IN;
 d.type=DEAL_TYPE_BUY;d.reason=DEAL_REASON_EXPERT;d.magic=12001;d.symbol="ETHUSD.s";
 d.volume=2;d.price=100;d.commission=-2;d.fee=-1;d.reads=65535;d.valid=true;
 ZeroMemory(p);p.id=700;p.ticket=701;p.side=POSITION_TYPE_BUY;p.magic=12001;p.symbol=d.symbol;
 p.volume=2;p.basis=100;p.sl=90;p.mark=-10;p.bid=95;p.ask=95.01;p.time_msc=1100;p.reads=2047;p.valid=true;
 Check(l.Capture(d)&&l.Reconcile(p,false),"authenticated full entry");
 p.swap=-4;l.residual=p;
}
void ReductionFact(DADeal &d){
 d.ticket=101;d.order=11;d.entry=DEAL_ENTRY_OUT;d.type=DEAL_TYPE_SELL;d.volume=1;d.price=95;
 d.profit=-5;d.commission=-0.5;d.fee=-0.25;d.swap=-2;d.time_msc=2000;d.sl=90;
}
void OnStart(){
 DecisionALifecycle l;DAPosition p;DADeal d;Entry(l,p,d);
 Check(l.Prepare(DA_REDUCTION,1),"single FOK reduction");l.Receipt(11,true,1,true);ReductionFact(d);
 p.volume=1;p.mark=-5;p.swap=-2;p.time_msc=2100;
 Check(l.Capture(d)&&l.Reconcile(p,false),"T02 native B D A conservation");
 double prior=l.Contribution();l.residual.swap=-7;
 Check(l.Contribution()-prior==-5,"T13 later residual U replaces prior U");
 Check(l.Prepare(DA_CLOSE,1),"residual close intent");l.Receipt(12,true,1,true);
 d.ticket=102;d.order=12;d.time_msc=3000;d.profit=5;d.swap=-9;
 DAPosition flat;ZeroMemory(flat);
 Check(l.Capture(d)&&l.Reconcile(flat,true),"T12 actual close swap does not reconcile arbitrary old U");
 KingEAAccountingEvent event;ZeroMemory(event);
 Check(l.Projection(false,event)&&event.swap==-11,"T11 actual final swap once; old U excluded");
 Check(l.Commit()&&!l.Commit(),"single financial handoff");

 Entry(l,p,d);Check(l.Prepare(DA_REDUCTION,1),"failed conservation prepare");l.Receipt(11,true,1,true);ReductionFact(d);
 p.volume=1;p.mark=-5;p.swap=-1.99;
 Check(l.Capture(d)&&!l.Reconcile(p,false)&&l.failure=="SWAP_TRANSITION_CONSERVATION_FAIL","T10 exact conservation failure");
 Check(!l.Prepare(DA_CONTAINMENT,1),"conservation failure cannot invent flatten trigger");
 Check(!l.Projection(true,event),"failed conservation has no financial projection");

 Entry(l,p,d);Check(l.Prepare(DA_REDUCTION,1),"missing callback prepare");l.Receipt(11,true,1,true);
 Check(!l.Reconcile(p,false)&&l.pending&&!l.no_fill,"S20 missing callback is never no-fill");
 Check(!l.Prepare(DA_CLOSE,2),"no speculative close of pending execution");

 Entry(l,p,d);Check(l.Prepare(DA_REDUCTION,1),"full multi-deal prepare");l.Receipt(11,true,1,true);ReductionFact(d);
 d.volume=0.5;Check(l.Capture(d),"multi-deal first capture");d.ticket=103;Check(l.Capture(d),"multi-deal second capture");
 p.volume=1;p.swap=-2;p.mark=-5;
 Check(!l.Reconcile(p,false)&&l.failure=="FOK_FULL_MULTI_DEAL_UNSUPPORTED_LEDGER_CARDINALITY","full multi-deal differs from partial");
 Check(l.invalid&&l.residual.volume==1&&l.Prepare(DA_CONTAINMENT,1)&&l.contained,"one allowance consumed before containment submission");
 l.Receipt(12,true,1,true);d.order=12;d.ticket=104;Check(l.Capture(d),"containment first fact");d.ticket=105;Check(l.Capture(d),"containment second fact");
 Check(!l.Reconcile(flat,true)&&l.exposure==DA_FLAT&&l.invalid,"unsupported containment may authenticate flat without acceptance");
 Check(!l.Prepare(DA_CONTAINMENT,1)&&!l.Projection(false,event),"no retry and no valid terminal projection");

 Entry(l,p,d);Check(l.Prepare(DA_REDUCTION,1),"partial prepare");l.Receipt(11,true,0.5,true);ReductionFact(d);d.volume=0.5;
 p.volume=1.5;Check(l.Capture(d)&&!l.Reconcile(p,false)&&l.failure=="PARTIAL_ORDER_EXECUTION","partial execution classification");
 Check(l.residual.volume==1.5&&!l.Prepare(DA_CONTAINMENT,1)&&l.Prepare(DA_CONTAINMENT,1.5),"containment uses actual residual, never V0-requested q");

 Entry(l,p,d);Check(l.Prepare(DA_REDUCTION,1),"no-fill prepare");l.Receipt(11,true,0,true,true);
 Check(!l.Reconcile(p,false)&&!l.pending&&l.no_fill&&!l.reduced,"S19 explicit no-fill preserves original position and components");
 Check(l.Prepare(DA_CLOSE,2),"existing authenticated no-fill fallback is full original position");

 DANativeCaptureRing ring;ring.Reset();MqlTradeTransaction t;ZeroMemory(t);t.type=TRADE_TRANSACTION_ORDER_DELETE;
 for(int i=0;i<256;i++)Check(ring.Capture(t),"bounded order observation capture");
 Check(!ring.Capture(t)&&ring.overflow,"upstream-independent internal overflow fails closed");
 DANativeCapture row;Check(ring.Pop(row)&&ring.overflow,"overflow remains latched");
 Print("Swap transition synthetic harness failures=",failures);
}
