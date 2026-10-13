#property strict
#property version "1.00"
#include <KingEA/NativeCostEvidence.mqh>
#include <KingEA/NativeCostContractTests.mqh>
#include <KingEA/NativeCostMetadataAdapter.mqh>

input string InpRunId="";
input string InpOutput="";
input bool InpRuntimeMetadata=false;
input string InpMetadataHash=KINGEA_COST_ADOPTION;
input string InpBoundaryHash=KINGEA_MTM_ADOPTION;
KingEANativeCostEvidence live_ledger;
KingEANativeCostBinding live_binding;
MqlTradeResult live_receipt={};
bool live_started=false,live_captured=false,live_reconciled=false,stop_requested=false;
bool runtime_failed=false,projected=false;
int ticks_after_fill=0,exit_callbacks=0;
string live_sidecar="",lifecycle_hash="";
KingEAAccountingDecision live_decision={};

void Emit(const string name,const string contents)
  {
   int h=FileOpen(InpOutput+"\\"+name,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) { runtime_failed=true; return; }
   FileWriteString(h,contents); FileClose(h);
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) ||
      InpRunId=="" || InpOutput=="" || InpMetadataHash!=KINGEA_COST_ADOPTION ||
      InpBoundaryHash!=KINGEA_MTM_ADOPTION) return INIT_FAILED;
   NCRunContracts();
   PrintFormat("NATIVE_COST_CONTRACTS|checks=%d|failures=%d",nc_checks,nc_failures);
   if(nc_failures!=0) return INIT_FAILED;
   KingEANativeCostEvidence ledger;
   KingEANativeCostBinding b={};
   b.run="NON_CANDIDATE_COST_CONFORMANCE"; b.configuration=0;
   b.branch="SYNTHETIC"; b.partition="CONFORMANCE"; b.group="GROUP-1";
   b.symbol="FIXTURE"; b.magic=99005; b.side=1; b.volume=1;
   b.start_msc=1000; b.end_msc=10000;
   if(!ledger.Begin(b)) return INIT_FAILED;
   KingEANativeDealFact d={};
   d.binding=ledger.BindingHash(); d.read_ok=true; d.deal=10; d.order=11;
   d.position_id=12; d.time_msc=2000; d.symbol=b.symbol; d.magic=b.magic;
   d.entry=DEAL_ENTRY_IN; d.type=DEAL_TYPE_BUY; d.volume=1; d.price=100;
   d.commission=-1; d.fee=-0.25;
   if(!ledger.CaptureEntry(d)) return INIT_FAILED;
   if(!ledger.ReconcileReceipt(10,11,1,100)) return INIT_FAILED;
   if(ledger.CostFactCount()!=1) return INIT_FAILED;
   Print("NATIVE_COST_TRACER_PASS");
   return INIT_SUCCEEDED;
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!InpRuntimeMetadata || !live_started || trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   KingEANativeDealFact d={};
   if(!KingEAReadCurrentRunDeal(trans,true,live_ledger.BindingHash(),d)) { runtime_failed=true; return; }
   if(d.entry==DEAL_ENTRY_IN)
     {
      live_captured=live_ledger.CaptureEntry(d);
      if(!live_captured) runtime_failed=true;
     }
   else
     {
      exit_callbacks++;
      // This fixture issues no exit, SL or TP. Only its explicit TesterStop lifecycle can close it.
      // Any earlier/ambiguous exit remains a failure. This proof is fixture-specific, not production inference.
      if(!projected || !stop_requested || !live_ledger.Housekeeping(d,lifecycle_hash,true)) runtime_failed=true;
     }
  }
void OnTick()
  {
   if(!InpRuntimeMetadata) { TesterStop(); return; }
   if(stop_requested) return;
   MqlTick tick={};
   if(!SymbolInfoTick(_Symbol,tick)) { runtime_failed=true; TesterStop(); return; }
   if(!live_started)
     {
      if(PositionsTotal()!=0 || OrdersTotal()!=0) { runtime_failed=true; TesterStop(); return; }
      live_binding.run=InpRunId; live_binding.configuration=0; live_binding.branch="NON_CANDIDATE";
      live_binding.partition="CONFORMANCE_2023"; live_binding.group="NATIVE-ONE";
      live_binding.symbol=_Symbol; live_binding.magic=99005; live_binding.side=1; live_binding.volume=0.01;
      live_binding.start_msc=tick.time_msc; live_binding.end_msc=tick.time_msc+60000;
      live_started=live_ledger.Begin(live_binding);
      if(!live_started) { runtime_failed=true; TesterStop(); return; }
      MqlTradeRequest order={}; order.action=TRADE_ACTION_DEAL; order.symbol=_Symbol;
      order.volume=0.01; order.type=ORDER_TYPE_BUY; order.price=tick.ask;
      order.magic=99005;
      long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK)!=0) order.type_filling=ORDER_FILLING_FOK;
      else if((filling & SYMBOL_FILLING_IOC)!=0) order.type_filling=ORDER_FILLING_IOC;
      else { runtime_failed=true; TesterStop(); return; }
      // Sole simulated tester transaction, protected by OnInit and repeated terminal guard.
      if(!MQLInfoInteger(MQL_TESTER) || !OrderSend(order,live_receipt) || live_receipt.retcode!=TRADE_RETCODE_DONE)
         { runtime_failed=true; TesterStop(); }
      return;
     }
   if(live_captured && !live_reconciled)
     {
      live_reconciled=live_ledger.ReconcileReceipt(live_receipt.deal,live_receipt.order,live_receipt.volume,live_receipt.price);
      if(!live_reconciled) runtime_failed=true;
     }
   if(runtime_failed || tick.time_msc>=live_binding.end_msc) { stop_requested=true; TesterStop(); return; }
   if(live_reconciled)
     {
      string spec=KingEAAccountingSha256(_Symbol+"|"+KingEACostNumber(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE))+"|"+
         (string)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE)+"|"+SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT));
      if(!KingEASealNativeEligibleQuote(live_ledger,tick,_Symbol,live_binding.start_msc,live_binding.end_msc,spec)) runtime_failed=true;
      ticks_after_fill++;
      if(ticks_after_fill>=10 || runtime_failed)
        {
         stop_requested=true;
         lifecycle_hash=KingEAAccountingSha256(InpRunId+"|EXPLICIT_TESTER_STOP_NO_EXIT_NO_SL_NO_TP|"+(string)tick.time_msc);
         Emit("lifecycle.txt",InpRunId+"|"+lifecycle_hash+"|TESTER_STOP_NO_EXIT_NO_SL_NO_TP");
         TesterStop();
        }
     }
  }
double OnTester()
  {
   if(InpRuntimeMetadata && !runtime_failed)
     {
      KingEAAccountingEvent base={}; base.schema_version=1; base.event_id=InpRunId+"-BOUNDARY";
      base.trade_group_id="NATIVE-ONE"; base.symbol=_Symbol;
      base.server_time_msc=live_ledger.SealedTime(); base.utc_time_msc=base.server_time_msc;
      base.account_fingerprint="NON_CANDIDATE"; base.deployment_id=InpRunId;
      KingEAAccountingCheckpoint prior={}; KingEAAccountingEvent event={};
      projected=live_ledger.Finalize(base,prior,1000,10,false,event,live_decision,live_sidecar);
      if(!projected) runtime_failed=true;
      Emit("boundary-evidence.txt",live_sidecar);
      for(int i=0;i<live_ledger.RecordCount();i++) Emit("cost-record-"+(string)i+".txt",live_ledger.Record(i));
     }
   return 0.0; // No optimization criterion or performance result.
  }
void OnDeinit(const int reason)
  {
   bool pass=nc_failures==0 && !runtime_failed && (!InpRuntimeMetadata ||
      (live_captured && live_reconciled && projected && live_ledger.Healthy() && live_ledger.BoundaryCount()==1));
   Emit("result.json",StringFormat("{\"run_id\":\"%s\",\"status\":\"%s\",\"contract_checks\":%d,\"contract_failures\":%d,\"metadata_captured\":%s,\"receipt_reconciled\":%s,\"boundary_count\":%d,\"exit_callbacks\":%d,\"candidate_execution\":false,\"b2\":\"LOCKED\"}",
      InpRunId,pass ? "PASS" : "FAIL",nc_checks,nc_failures,live_captured ? "true" : "false",
      live_reconciled ? "true" : "false",live_ledger.BoundaryCount(),exit_callbacks));
  }
