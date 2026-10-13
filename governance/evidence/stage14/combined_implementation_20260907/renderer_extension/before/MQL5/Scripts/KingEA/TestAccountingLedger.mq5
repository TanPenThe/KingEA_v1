#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Deterministic non-trading Stage 13 accounting contract."

#include <KingEA/AccountingEvents.mqh>

int g_checks=0;
int g_failures=0;

void Check(const bool condition,const string label)
  {
   g_checks++;
   if(!condition)
     {
      g_failures++;
      Print("STAGE13_FAIL: ",label);
     }
  }

KingEAAccountingEvent BaseEvent()
  {
   KingEAAccountingEvent event={};
   event.schema_version=1;
   event.event_id="SYNTHETIC-DEAL-1";
   event.event_type=KINGEA_ACCOUNTING_EVENT_DEAL;
   event.server_time_msc=1722162000000;
   event.utc_time_msc=1722133200000;
   StringInit(event.account_fingerprint,64,'A');
   event.deployment_id="KINGEA-DEMO2-001";
   event.candidate_id="CAND-ETH-ST-001";
   StringInit(event.configuration_hash,64,'B');
   event.sleeve_id="SLEEVE-1";
   event.trade_group_id="GROUP-1";
   event.symbol="ETHUSD.s";
   event.volume=0.01;
   event.requested_price=1876.20;
   event.executed_price=1876.28;
   event.protective_stop=1783.23;
   event.gross_profit=12.0;
   event.commission=-1.0;
   event.swap=-0.5;
   event.fee=-0.25;
   event.spread_attribution=2.0;
   event.slippage_attribution=1.0;
   event.account_equity=1010.25;
   event.sleeve_equity=1010.25;
   event.reason_code="SYNTHETIC";
   event.source_quality="CONTRACT_FIXTURE";
   return event;
  }

void OnStart()
  {
   KingEAAccountingCheckpoint checkpoint={};
   KingEAAccountingEvent event=BaseEvent();
   KingEAAccountingDecision first={};
   KingEAProcessAccountingEvent(event,checkpoint,first);
   Check(first.accepted,"valid event accepted");
   Check(MathAbs(first.event_net_pnl-10.25)<1e-9,
         "net PnL includes broker components once");
   Check(MathAbs(first.next_checkpoint.spread_attribution-2.0)<1e-9 &&
         MathAbs(first.next_checkpoint.slippage_attribution-1.0)<1e-9,
         "spread and slippage remain attribution only");
   Check(KingEAAccountingHash(first.event_sha256),"event is SHA-256 chained");

   KingEAAccountingDecision repeated={};
   KingEAProcessAccountingEvent(event,checkpoint,repeated);
   Check(repeated.event_sha256==first.event_sha256,
         "same event and checkpoint are deterministic");

   KingEAAccountingEvent cash=BaseEvent();
   cash.event_id="SYNTHETIC-FLOW-1";
   cash.event_type=KINGEA_ACCOUNTING_EVENT_EXTERNAL_CASH_FLOW;
   cash.server_time_msc++;
   cash.gross_profit=0.0; cash.commission=0.0; cash.swap=0.0; cash.fee=0.0;
   cash.external_cash_flow=500.0;
   KingEAAccountingDecision flow={};
   KingEAProcessAccountingEvent(cash,first.next_checkpoint,flow);
   Check(flow.accepted && MathAbs(flow.event_net_pnl)<1e-9 &&
         MathAbs(flow.next_checkpoint.external_cash_flow-500.0)<1e-9,
         "external cash flow is separate from strategy PnL");

   KingEAAccountingEvent backward=BaseEvent();
   backward.event_id="SYNTHETIC-BACKWARD";
   backward.server_time_msc--;
   KingEAAccountingDecision invalid={};
   KingEAProcessAccountingEvent(backward,first.next_checkpoint,invalid);
   Check(!invalid.accepted,"backward event fails closed");

   string payload=KingEAAccountingFramePayload(event,first);
   Check(StringFind(payload,"net=10.250000000000")>=0 &&
         StringFind(payload,"root=")>=0,
         "versioned tester frame is complete");

   string path="KingEA\\stage13_accounting_contract_"+
               TimeToString(TimeLocal(),TIME_DATE|TIME_MINUTES|TIME_SECONDS)+".csv";
   StringReplace(path,":","-");
   StringReplace(path," ","_");
   int handle=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_COMMON,',');
   if(handle!=INVALID_HANDLE)
     {
      FileWrite(handle,"field","value");
      FileWrite(handle,"result",g_failures==0 ? "PASS" : "FAIL");
      FileWrite(handle,"checks",g_checks);
      FileWrite(handle,"failures",g_failures);
      FileWrite(handle,"first_reason",first.reason);
      FileWrite(handle,"fixture","SYNTHETIC_ONLY");
      FileWrite(handle,"candidate_budget_consumed",0);
      FileWrite(handle,"performance_authorization","DENIED");
      FileClose(handle);
     }
   PrintFormat("KINGEA_STAGE13_ACCOUNTING_CONTRACT: result=%s checks=%d failures=%d report=%s",
               g_failures==0 ? "PASS" : "FAIL",g_checks,g_failures,path);
  }
