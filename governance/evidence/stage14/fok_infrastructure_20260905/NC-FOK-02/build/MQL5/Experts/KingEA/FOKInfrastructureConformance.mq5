#property strict
#property version "1.00"
// Non-Candidate execution-shape fixture. No signal, sizing, or research evaluation.
#include <KingEA/NativeCostMetadataAdapter.mqh>
#include <KingEA/NativeCostIntegrationTests.mqh>

input string InpRunId="";
input string InpOutput="";
input int InpExpectedBuild=0;
input string InpExpectedFingerprint="";
bool consumed=false;
bool environment_verified=false;
string fingerprint="";
KingEANativeCostEvidence fok_ledger;
KingEANativeCostBinding fok_binding;
MqlTradeResult entry_receipt={};
bool failed=false,captured=false,reconciled=false,projected=false;
int quote_count=0,callback_count=0;
string fok_sidecar="";
long last_eligible=0;

string Q(string value)
  {
   StringReplace(value,"\\","\\\\"); StringReplace(value,"\"","\\\"");
   StringReplace(value,"\r","\\r"); StringReplace(value,"\n","\\n");
   return "\""+value+"\"";
  }
string B(const bool value) { return value ? "true":"false"; }
string N(const double value) { return DoubleToString(value,12); }
bool Emit(const string name,const string contents)
  {
   string path=InpOutput+"\\"+name;
   if(FileIsExist(path,FILE_COMMON)) return false;
   int h=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return false;
   FileWriteString(h,contents); FileClose(h); return true;
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) ||
      InpRunId=="" || InpOutput=="" || InpExpectedBuild<=0 ||
      StringLen(InpExpectedFingerprint)!=64 || _Symbol!="ETHUSD.s" || _Period!=PERIOD_M30)
      return INIT_FAILED;
   fingerprint=KingEAAccountingSha256(AccountInfoString(ACCOUNT_SERVER)+"|"+
                                    IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   environment_verified=(AccountInfoString(ACCOUNT_SERVER)=="JustMarkets-Demo2" &&
                         fingerprint==InpExpectedFingerprint &&
                         TerminalInfoInteger(TERMINAL_BUILD)==InpExpectedBuild &&
                         PositionsTotal()==0 && OrdersTotal()==0);
   Print("FOK_CONFORMANCE_BEGIN|",InpRunId,"|environment_verified=",environment_verified);
   if(!environment_verified)
     {
      Emit("result.json","{\"status\":\"FAIL_ENVIRONMENT\",\"run_id\":"+Q(InpRunId)+
           ",\"server\":"+Q(AccountInfoString(ACCOUNT_SERVER))+",\"fingerprint\":"+Q(fingerprint)+"}");
      return INIT_FAILED;
     }
   NCRunContracts(); NCIntegrationContracts();
   if(nc_failures!=0) return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnTick()
  {
   if(!environment_verified) return;
   if(consumed)
     {
      if(failed) { TesterStop(); return; }
      MqlTick t={}; if(!SymbolInfoTick(_Symbol,t)) { failed=true; TesterStop(); return; }
      if(t.time_msc>=fok_binding.end_msc) { TesterStop(); return; }
      last_eligible=t.time_msc;
      if(captured && !reconciled)
         reconciled=fok_ledger.ReconcileReceipt(entry_receipt.deal,entry_receipt.order,entry_receipt.volume,entry_receipt.price);
      if(captured && !reconciled) { failed=true; TesterStop(); return; }
      if(reconciled)
        {
         string spec=KingEAAccountingSha256("FOK_SPEC|"+_Symbol+"|"+
            KingEACostNumber(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE))+"|"+
            (string)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE));
         if(!KingEASealNativeEligibleQuote(fok_ledger,t,_Symbol,fok_binding.start_msc,fok_binding.end_msc,spec))
            { failed=true; TesterStop(); return; }
         quote_count++;
         if(quote_count>=10) TesterStop();
        }
      return;
     }
   consumed=true;
   MqlTick tick={};
   bool facts_ok=SymbolInfoTick(_Symbol,tick) && tick.time_msc>0 &&
                 MathIsValidNumber(tick.bid) && MathIsValidNumber(tick.ask) &&
                 tick.bid>0 && tick.ask>=tick.bid;
   ENUM_SYMBOL_INFO_INTEGER props[]={SYMBOL_TRADE_EXEMODE,SYMBOL_FILLING_MODE,SYMBOL_ORDER_MODE,
      SYMBOL_TRADE_MODE,SYMBOL_EXPIRATION_MODE,SYMBOL_DIGITS,SYMBOL_TRADE_STOPS_LEVEL,
      SYMBOL_TRADE_FREEZE_LEVEL,SYMBOL_TRADE_CALC_MODE};
   string spec="{\"run_id\":"+Q(InpRunId)+",\"symbol\":"+Q(_Symbol)+
      ",\"server\":"+Q(AccountInfoString(ACCOUNT_SERVER))+",\"account_fingerprint\":"+Q(fingerprint)+
      ",\"terminal_build\":"+IntegerToString(TerminalInfoInteger(TERMINAL_BUILD))+
      ",\"tick_time_msc\":"+IntegerToString(tick.time_msc);
   for(int i=0;i<ArraySize(props);i++)
     {
      long value=0; bool ok=SymbolInfoInteger(_Symbol,props[i],value); facts_ok=ok && facts_ok;
      spec+=","+Q(EnumToString(props[i]))+":"+IntegerToString(value);
     }
   ENUM_SYMBOL_INFO_DOUBLE doubles[]={SYMBOL_VOLUME_MIN,SYMBOL_VOLUME_MAX,SYMBOL_VOLUME_STEP,
      SYMBOL_VOLUME_LIMIT,SYMBOL_POINT,SYMBOL_TRADE_TICK_SIZE,SYMBOL_TRADE_TICK_VALUE,
      SYMBOL_TRADE_CONTRACT_SIZE,SYMBOL_MARGIN_INITIAL,SYMBOL_MARGIN_MAINTENANCE};
   for(int i=0;i<ArraySize(doubles);i++)
     {
      double value=0; bool ok=SymbolInfoDouble(_Symbol,doubles[i],value);
      facts_ok=ok && MathIsValidNumber(value) && facts_ok;
      spec+=","+Q(EnumToString(doubles[i]))+":"+N(value);
     }
   spec+=",\"bid\":"+N(tick.bid)+",\"ask\":"+N(tick.ask)+",\"facts_ok\":"+B(facts_ok)+"}";
   if(!Emit("specification.json",spec) || !facts_ok) { TesterStop(); return; }

   // The production request shape is frozen; only the fixture's input facts are injected.
   // No Candidate signal/safety logic executes. There is deliberately no filling fallback.
   MqlTradeRequest order={};
   order.action=TRADE_ACTION_DEAL;
   order.symbol=_Symbol;
   order.volume=0.01;
   order.type=ORDER_TYPE_BUY;
   order.price=tick.ask;
   order.sl=NormalizeDouble(tick.ask*0.95,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
   order.tp=0;
   order.deviation=0;
   order.magic=99005;
   order.comment="KINGEA|NON-CANDIDATE|"+InpRunId;
   order.type_filling=ORDER_FILLING_FOK;
   string request="{\"run_id\":"+Q(InpRunId)+",\"fixture_only\":true,\"action\":"+Q(EnumToString(order.action))+
      ",\"symbol\":"+Q(order.symbol)+",\"volume\":"+N(order.volume)+",\"type\":"+Q(EnumToString(order.type))+
      ",\"price\":"+N(order.price)+",\"sl\":"+N(order.sl)+",\"tp\":"+N(order.tp)+
      ",\"deviation\":0,\"magic\":99005,\"comment\":"+Q(order.comment)+
      ",\"type_filling\":"+Q(EnumToString(order.type_filling))+
      ",\"type_time\":"+Q(EnumToString(order.type_time))+
      ",\"order\":0,\"position\":0,\"position_by\":0,\"stoplimit\":0,\"expiration\":0}";
   if(!Emit("request.json",request)) { TesterStop(); return; }
   fok_binding.run=InpRunId; fok_binding.configuration=0; fok_binding.branch="NON_CANDIDATE";
   fok_binding.partition="CONFORMANCE_2023"; fok_binding.group="FOK-GROUP"; fok_binding.symbol=_Symbol;
   fok_binding.magic=99005; fok_binding.side=1; fok_binding.volume=order.volume;
   fok_binding.start_msc=tick.time_msc; fok_binding.end_msc=tick.time_msc+60000;
   if(!fok_ledger.Begin(fok_binding)) { failed=true; TesterStop(); return; }
   MqlTradeCheckResult check={}; ResetLastError();
   bool check_ok=OrderCheck(order,check); int check_error=GetLastError();
   string check_json="{\"run_id\":"+Q(InpRunId)+",\"ok\":"+B(check_ok)+
      ",\"retcode\":"+IntegerToString(check.retcode)+",\"last_error\":"+IntegerToString(check_error)+
      ",\"comment\":"+Q(check.comment)+",\"balance\":"+N(check.balance)+
      ",\"equity\":"+N(check.equity)+",\"profit\":"+N(check.profit)+
      ",\"margin\":"+N(check.margin)+",\"margin_free\":"+N(check.margin_free)+
      ",\"margin_level\":"+N(check.margin_level)+"}";
   if(!Emit("order_check.json",check_json)) { TesterStop(); return; }
   int attempts=0; bool sent=false; MqlTradeResult result={};
   // One simulated tester entry maximum; no request when OrderCheck rejected it.
   if(check_ok && (check.retcode==0 || check.retcode==TRADE_RETCODE_DONE) &&
      MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION))
     {
      attempts=1; sent=OrderSend(order,result); entry_receipt=result;
     }
   string send_json="{\"run_id\":"+Q(InpRunId)+",\"attempts\":"+IntegerToString(attempts)+
      ",\"ok\":"+B(sent)+",\"retcode\":"+IntegerToString(result.retcode)+
      ",\"comment\":"+Q(result.comment)+",\"order\":"+IntegerToString((long)result.order)+
      ",\"deal\":"+IntegerToString((long)result.deal)+",\"volume\":"+N(result.volume)+
      ",\"price\":"+N(result.price)+"}";
   bool saved=Emit("execution.json",send_json);
   failed=!saved || !sent || result.retcode!=TRADE_RETCODE_DONE || result.volume!=order.volume ||
          result.deal==0 || result.order==0;
   if(failed) TesterStop();
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!consumed || trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   KingEANativeDealFact fact={};
   if(!KingEAReadCurrentRunDeal(trans,true,fok_ledger.BindingHash(),fact)) { failed=true; return; }
   KingEANativeLifecycleFacts life={}; life.observation_origin="NATIVE_TRANSACTION"; life.non_candidate=true;
   string outcome;
   if(!KingEAHandleNativeCostDeal(fok_ledger,fok_binding,fact,life,outcome)) { failed=true; return; }
   if(outcome=="ENTRY_METADATA_CAPTURED") captured=true;
   else { callback_count++; failed=true; } // This runtime fixture never requests a normal exit.
  }
double OnTester()
  {
   if(!failed && captured && reconciled && fok_ledger.SealedTime()==last_eligible && quote_count>0)
     {
      KingEAAccountingEvent base={}; base.schema_version=1; base.event_id=InpRunId+"-BOUNDARY";
      base.trade_group_id=fok_binding.group; base.symbol=_Symbol; base.server_time_msc=fok_ledger.SealedTime();
      base.utc_time_msc=base.server_time_msc; base.account_fingerprint=fingerprint;
      base.deployment_id=InpRunId; base.candidate_id="NON_CANDIDATE";
      KingEAAccountingCheckpoint prior={}; KingEAAccountingEvent event={}; KingEAAccountingDecision decision={};
      projected=fok_ledger.Finalize(base,prior,1000,10,false,event,decision,fok_sidecar);
      string zero; StringInit(zero,64,'0');
      if(!projected || !Emit("boundary-evidence.txt",fok_sidecar) ||
         !Emit("stage13-event.txt",KingEAAccountingFramePayload(event,decision)) ||
         !Emit("stage13-canonical.txt",KingEAAccountingCanonical(event,decision.sequence,zero))) failed=true;
      for(int i=0;i<fok_ledger.RecordCount();i++)
         if(!Emit("cost-record-"+(string)i+".txt",fok_ledger.Record(i))) failed=true;
     }
   else failed=true;
   return 0.0;
  }
void OnDeinit(const int reason)
  {
   bool pass=environment_verified && !failed && projected && fok_ledger.Healthy() && nc_failures==0;
   Emit("result.json",StringFormat("{\"run_id\":\"%s\",\"status\":\"%s\",\"contract_checks\":%d,\"contract_failures\":%d,\"metadata_captured\":%s,\"receipt_reconciled\":%s,\"boundary_count\":%d,\"exit_callbacks\":%d,\"candidate_execution\":false,\"candidate_exit_count\":0,\"b2\":\"LOCKED\",\"filling\":\"ORDER_FILLING_FOK\",\"fallback_count\":0}",
     InpRunId,pass ? "PASS":"FAIL",nc_checks,nc_failures,B(captured),B(reconciled),fok_ledger.BoundaryCount(),callback_count));
   Print("FOK_CONFORMANCE_END|",InpRunId,"|pass=",pass,"|checks=",nc_checks,"|failures=",nc_failures);
  }
