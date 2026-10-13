#property strict
#include <KingEA/DecisionADealAdapter.mqh>
#include <KingEA/DecisionAStaticStop.mqh>
// Compile-only in this implementation phase. No orders or history queries.
int failures=0;
void Check(bool ok,string name){if(!ok){failures++;Print("FAIL ",name);}}
void OnStart(){
 DecisionALifecycle ledger;ledger.Reset();
 Check(ledger.Begin("group","ETHUSD.s",1,1,90,1000,10,2,200000),"original basis");
 Check(!ledger.Commit(),"no commit without projection");
 Check(ledger.Prepare(DA_ENTRY,1),"entry prepare");
 MqlTradeRequest request;ZeroMemory(request);
 request.action=TRADE_ACTION_DEAL;request.type_filling=ORDER_FILLING_FOK;request.symbol="ETHUSD.s";
 request.magic=12001;request.volume=1;request.sl=90;request.type=ORDER_TYPE_BUY;
 Check(DAStaticSendAllowed(request,DA_ENTRY,ledger,true),"FOK entry seam");
 Check(!DAStaticSendAllowed(request,DA_ENTRY,ledger,false),"context loss denies seam");
 request.type_filling=ORDER_FILLING_IOC;
 Check(!DAStaticSendAllowed(request,DA_ENTRY,ledger,true),"IOC denied");
 request.type_filling=ORDER_FILLING_FOK;request.type=ORDER_TYPE_SELL;
 Check(!DAStaticSendAllowed(request,DA_ENTRY,ledger,true),"wrong direction denied");
 ledger.Receipt(123,true,1,true);DAPosition unknown;ZeroMemory(unknown);
 Check(!ledger.Reconcile(unknown,false)&&ledger.pending,"missing callback stays pending");
 DADeal entry;ZeroMemory(entry);entry.ticket=456;entry.order=123;entry.position=77;entry.time_msc=100;
 entry.entry=DEAL_ENTRY_IN;entry.type=DEAL_TYPE_BUY;entry.reason=DEAL_REASON_EXPERT;entry.magic=12001;
 entry.symbol="ETHUSD.s";entry.volume=1;entry.price=100;entry.commission=-2;entry.fee=-1;entry.reads=65535;entry.valid=true;
 DAPosition live;ZeroMemory(live);live.id=77;live.ticket=77;live.side=POSITION_TYPE_BUY;live.magic=12001;
 live.symbol="ETHUSD.s";live.volume=1;live.basis=100;live.sl=90;live.reads=2047;live.valid=true;live.time_msc=100;
 Check(ledger.Capture(entry)&&ledger.Reconcile(live,false),"authenticated entry");
 Check(ledger.Capture(entry)&&ledger.commission==-2,"duplicate entry idempotent");
 Check(ledger.Prepare(DA_REDUCTION,0.5),"governed reduction prepare");
 ledger.Receipt(124,true,0.5,true);
 DADeal reduction=entry;reduction.ticket=457;reduction.order=124;reduction.time_msc=150;
 reduction.entry=DEAL_ENTRY_OUT;reduction.type=DEAL_TYPE_SELL;reduction.volume=0.5;reduction.price=95;
 reduction.profit=-2.5;reduction.commission=-0.5;reduction.fee=-0.25;reduction.sl=90;
 live.volume=0.5;live.mark=-2.5;live.time_msc=150;
 Check(ledger.Capture(reduction)&&ledger.Reconcile(live,false),"reduction residual reconciliation");
 Check(ledger.Contribution()==-8.75,"realized plus residual safety equity");
 double operational=0;Check(ledger.OperationalContribution(operational)&&operational==-8.75,"non-booking operational components");
 Check(!ledger.Prepare(DA_REDUCTION,0.25),"second reduction denied");
 KingEAAccountingEvent boundary;ZeroMemory(boundary);
 Check(ledger.Projection(true,boundary)&&boundary.gross_profit==-5,"uncommitted residual boundary oracle");
 Check(ledger.Prepare(DA_CLOSE,0.5),"full residual close prepare");ledger.Receipt(125,true,0.5,true);
 DADeal close= reduction;close.ticket=458;close.order=125;close.time_msc=175;close.price=110;close.profit=5;
 ZeroMemory(unknown);
 Check(ledger.Capture(close)&&ledger.Reconcile(unknown,true),"full close components");
 KingEAAccountingEvent terminal;ZeroMemory(terminal);
 Check(ledger.Projection(false,terminal),"one terminal projection prepared");
 Check(terminal.gross_profit==2.5&&terminal.commission==-3&&terminal.fee==-1.5&&terminal.net_r==-0.2,"fixed denominator signed oracle");
 Check(ledger.Commit()&&!ledger.Commit(),"single terminal commit");
 Check(!ledger.Projection(false,terminal)&&ledger.invalid,"second projection invalidates");
 Check(!ledger.Begin("new group","ETHUSD.s",1,1,90,1000,10,2,300000),"invalidity cannot reset at new group");
 DAObservationRing ring;ring.Reset();MqlTradeTransaction trans;MqlTradeResult result;
 ZeroMemory(trans);ZeroMemory(result);trans.type=TRADE_TRANSACTION_POSITION;
 for(int i=0;i<256;i++)Check(ring.Capture(trans,request,result),"bounded capture");
 Check(!ring.Capture(trans,request,result)&&ring.overflow,"overflow sticky");
 DAObservation row;Check(ring.Pop(row)&&ring.overflow,"drain does not clear overflow");
 Print("Combined deterministic harness failures=",failures);
}
