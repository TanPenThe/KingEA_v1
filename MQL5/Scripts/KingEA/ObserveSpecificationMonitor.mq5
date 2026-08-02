#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only Stage 8 Demo2 specification observation."
#property description "Creates non-deployable evidence and never places or modifies orders."

#include <KingEA/SymbolSpecificationAdapter.mqh>

input string InpSymbol="ETHUSD.s";
input string InpRequiredServerFragment="JustMarkets-Demo2";
input string InpDeploymentId="KINGEA-DEMO2-STAGE8-OBSERVATION";
input int    InpReadinessTimeoutSeconds=30;

string SafeName(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,"/","-");
   StringReplace(value,"\\","-");
   return value;
  }

void WriteField(const int handle,const string key,const string value)
  {
   FileWrite(handle,key,value);
  }

void OnStart()
  {
   if(InpRequiredServerFragment=="")
     {
      Print("KingEA Stage 8 observation refused: required server fragment is blank");
      return;
     }

   KingEASymbolSpecification observed={};
   KingEASpecificationRequest request={};
   request.event=KINGEA_SPEC_EVENT_INITIALIZATION;
   request.expected_symbol=InpSymbol;
   request.administrative_proof_complete=false;
   request.sessions_strategy_equivalent=false;
   request.exposure.known=true;
   request.exposure.has_position=false;
   request.exposure.protective_stop_confirmed=true;
   request.exposure.stop_valid=true;
   request.exposure.volume_valid=true;
   request.exposure.closure_available=true;
   request.exposure.reduction_feasible=true;

   string reason="READINESS_TIMEOUT";
   string server="";
   bool captured=false;
   ulong deadline=GetTickCount64()+(ulong)MathMax(1,InpReadinessTimeoutSeconds)*1000;
   while(GetTickCount64()<=deadline)
     {
      server=AccountInfoString(ACCOUNT_SERVER);
      if(server!="" && StringFind(server,InpRequiredServerFragment)<0)
        {
         PrintFormat("KingEA Stage 8 observation refused: server='%s' required='%s'",
                     server,InpRequiredServerFragment);
         return;
        }
      if(server!="" && (bool)TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         request.expected_server_class=server;
         if(KingEACaptureSymbolSpecification(InpSymbol,observed,request,reason))
           {
            captured=true;
            break;
           }
        }
      Sleep(250);
     }
   if(!captured)
     {
      PrintFormat("KingEA Stage 8 observation failed: %s",reason);
      return;
     }

   KingEASpecificationState prior={};
   KingEASpecificationDecision decision={};
   KingEAEvaluateSpecification(observed,observed,request,prior,decision);

   string stamp=SafeName(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   string relative="KingEA\\stage8_spec_observation_"+SafeName(InpSymbol)+"_"+stamp+".csv";
   int handle=FileOpen(relative,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,
                       ',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA Stage 8 observation failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"key","value");
   WriteField(handle,"scope","NON_DEPLOYABLE_NON_PERFORMANCE_OBSERVATION");
   WriteField(handle,"deployment_id",InpDeploymentId);
   WriteField(handle,"server",server);
   WriteField(handle,"symbol_id",observed.symbol_id);
   WriteField(handle,"observed_server_time",TimeToString(request.observed_at,TIME_DATE|TIME_SECONDS));
   WriteField(handle,"specification_hash",decision.observed_hash);
   WriteField(handle,"classification",IntegerToString((int)decision.classification));
   WriteField(handle,"entry_allowed_for_observation_only",decision.entry_allowed ? "1" : "0");
   WriteField(handle,"description",observed.description);
   WriteField(handle,"path",observed.path);
   WriteField(handle,"currency_base",observed.currency_base);
   WriteField(handle,"currency_profit",observed.currency_profit);
   WriteField(handle,"currency_margin",observed.currency_margin);
   WriteField(handle,"digits",IntegerToString(observed.digits));
   WriteField(handle,"point",DoubleToString(observed.point,12));
   WriteField(handle,"tick_size",DoubleToString(observed.tick_size,12));
   WriteField(handle,"tick_value",DoubleToString(observed.tick_value,12));
   WriteField(handle,"tick_value_profit",DoubleToString(observed.tick_value_profit,12));
   WriteField(handle,"tick_value_loss",DoubleToString(observed.tick_value_loss,12));
   WriteField(handle,"contract_size",DoubleToString(observed.contract_size,12));
   WriteField(handle,"calc_mode",IntegerToString(observed.calc_mode));
   WriteField(handle,"execution_mode",IntegerToString(observed.execution_mode));
   WriteField(handle,"filling_mode",(string)observed.filling_mode);
   WriteField(handle,"order_mode",(string)observed.order_mode);
   WriteField(handle,"expiration_mode",(string)observed.expiration_mode);
   WriteField(handle,"trade_mode",IntegerToString(observed.trade_mode));
   WriteField(handle,"volume_min",DoubleToString(observed.volume_min,12));
   WriteField(handle,"volume_max",DoubleToString(observed.volume_max,12));
   WriteField(handle,"volume_step",DoubleToString(observed.volume_step,12));
   WriteField(handle,"volume_limit",DoubleToString(observed.volume_limit,12));
   WriteField(handle,"stops_level",IntegerToString(observed.stops_level));
   WriteField(handle,"freeze_level",IntegerToString(observed.freeze_level));
   WriteField(handle,"margin_initial",DoubleToString(observed.margin_initial,12));
   WriteField(handle,"margin_maintenance",DoubleToString(observed.margin_maintenance,12));
   WriteField(handle,"margin_hedged",DoubleToString(observed.margin_hedged,12));
   WriteField(handle,"margin_rate_buy",DoubleToString(observed.margin_rate_buy,12));
   WriteField(handle,"margin_rate_sell",DoubleToString(observed.margin_rate_sell,12));
   WriteField(handle,"session_count",IntegerToString(observed.session_count));
   for(int i=0;i<observed.session_count;i++)
      WriteField(handle,"session_"+IntegerToString(i),
                 IntegerToString(observed.sessions[i].from_second)+"-"+
                 IntegerToString(observed.sessions[i].to_second));
   WriteField(handle,"tick_probe_reported",DoubleToString(request.tick_probe_reported,12));
   WriteField(handle,"tick_probe_calculated",DoubleToString(request.tick_probe_calculated,12));
   WriteField(handle,"live_margin_per_lot",DoubleToString(request.live_margin_per_lot,8));
   WriteField(handle,"hmr_proxy_margin_per_lot",DoubleToString(request.hmr_proxy_margin_per_lot,8));
   WriteField(handle,"stressed_margin_level_percent",DoubleToString(request.stressed_margin_level_percent,4));
   WriteField(handle,"stressed_free_margin_ratio",DoubleToString(request.stressed_free_margin_ratio,8));
   WriteField(handle,"order_capability","PROHIBITED_AND_ABSENT");
   WriteField(handle,"performance_authorization","DENIED");
   WriteField(handle,"baseline_approval","PENDING_OWNER_REVIEW");
   FileFlush(handle);
   FileClose(handle);

   string full=TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+relative;
   PrintFormat("KingEA Stage 8 non-deployable observation complete: %s",full);
   PrintFormat("Result: PASS; server=%s; symbol=%s; hash=%s; no performance authorization.",
               server,observed.symbol_id,decision.observed_hash);
  }
