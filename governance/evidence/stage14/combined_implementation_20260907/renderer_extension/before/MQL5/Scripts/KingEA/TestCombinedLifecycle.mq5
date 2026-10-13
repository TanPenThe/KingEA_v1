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
 Check(DAStaticSendAllowed(request,DA_ENTRY,ledger),"FOK entry seam");
 request.type_filling=ORDER_FILLING_IOC;
 Check(!DAStaticSendAllowed(request,DA_ENTRY,ledger),"IOC denied");
 request.type_filling=ORDER_FILLING_FOK;request.type=ORDER_TYPE_SELL;
 Check(!DAStaticSendAllowed(request,DA_ENTRY,ledger),"wrong direction denied");
 ledger.Receipt(123,true);DAPosition unknown;ZeroMemory(unknown);
 Check(!ledger.Reconcile(unknown,false)&&ledger.pending,"missing callback stays pending");
 DAObservationRing ring;ring.Reset();MqlTradeTransaction trans;MqlTradeResult result;
 ZeroMemory(trans);ZeroMemory(result);trans.type=TRADE_TRANSACTION_POSITION;
 for(int i=0;i<256;i++)Check(ring.Capture(trans,request,result),"bounded capture");
 Check(!ring.Capture(trans,request,result)&&ring.overflow,"overflow sticky");
 DAObservation row;Check(ring.Pop(row)&&ring.overflow,"drain does not clear overflow");
 Print("Combined deterministic harness failures=",failures);
}
