#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Synthetic, non-performance Stage 12 execution-contract tests."

#include <KingEA/ResearchExecution.mqh>

int g_checks=0;
int g_failures=0;

void Check(const bool condition,const string name)
  {
   g_checks++;
   if(condition)
      Print("PASS: ",name);
   else
     {
      g_failures++;
      Print("FAIL: ",name);
     }
  }

void WriteContractReport()
  {
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   StringReplace(utc,".","-");
   StringReplace(utc,":","-");
   StringReplace(utc," ","_");
   string filename="KingEA\\stage14_research_contract_"+utc+".csv";
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      g_failures++;
      PrintFormat("FAIL: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"key","value");
   FileWrite(report,"build_id","KINGEA-STAGE14-20260802-A");
   FileWrite(report,"result",g_failures==0 ? "PASS" : "FAIL");
   FileWrite(report,"checks",g_checks);
   FileWrite(report,"failures",g_failures);
   FileWrite(report,"fixture","SYNTHETIC_ONLY");
   FileWrite(report,"performance_authorization","DENIED");
   FileWrite(report,"candidate_budget_consumed",0);
   FileWrite(report,"order_capability","PROHIBITED_AND_ABSENT");
   FileWrite(report,"standdown_required","ACTIVE");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA Stage 12 contract report: %s\\Files\\%s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH),filename);
  }

void OnStart()
  {
   KingEACandidateParameters parameters={};
   Check(KingEAResearchDecodeConfiguration(0,parameters) &&
         parameters.atr_period==10 && parameters.maximum_holding_bars==48,
         "configuration zero decodes in frozen order");
   Check(KingEAResearchDecodeConfiguration(19439,parameters) &&
         parameters.atr_period==22 && parameters.maximum_holding_bars==96,
         "configuration 19439 decodes in frozen order");
   Check(!KingEAResearchDecodeConfiguration(19440,parameters),
         "off-grid configuration id fails closed");

   KingEAResearchAuthorization authorization={};
   authorization.in_tester=true;
   authorization.every_tick_real=true;
   authorization.local_agents_only=true;
   authorization.manifest_hash_valid=true;
   authorization.detached_authorization_valid=true;
   authorization.status_running=true;
   authorization.partition_authorized=true;
   Check(KingEAResearchAuthorized(authorization),
         "complete tester authorization permits the adapter seam");
   authorization.detached_authorization_valid=false;
   Check(!KingEAResearchAuthorized(authorization),
         "missing detached authorization blocks every execution path");

   KingEAResearchStress stress={};
   stress.spread_multiplier=3.0;
   stress.cost_multiplier=1.3;
   stress.slippage_spread_fraction=0.5;
   stress.missed_entry_fraction=0.10;
   stress.seed=12345;
   KingEAResearchVirtualFill first={};
   KingEAResearchVirtualFill second={};
   KingEAResearchApplyVirtualStress(stress,"SYNTHETIC-SIGNAL-1",100.0,101.0,
                                    KINGEA_DIRECTION_LONG,first);
   KingEAResearchApplyVirtualStress(stress,"SYNTHETIC-SIGNAL-1",100.0,101.0,
                                    KINGEA_DIRECTION_LONG,second);
   Check(first.missed==second.missed && first.entry_price==second.entry_price,
         "seeded virtual stress is deterministic");
   Check(first.stressed_spread==3.0 && first.entry_price==104.5,
         "spread and adverse long slippage are applied exactly");

   KingEAResearchVirtualPosition virtual_position={};
   virtual_position.equity=1000.0;
   KingEAResearchEntryRoute virtual_route={};
   KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_VIRTUAL,stress,
                            "SENTINEL-STRESS",100.0,101.0,
                            KINGEA_DIRECTION_LONG,95.0,0.01,1000,
                            1800000,0.0,false,virtual_position,virtual_route);
   Check(virtual_route.healthy && virtual_route.outcome==KINGEA_RESEARCH_VIRTUAL_FILL &&
         !virtual_route.native_order_required &&
         virtual_route.fill_price==104.5 &&
         virtual_position.entry_price==104.5 &&
         virtual_route.accounting_price==104.5,
         "virtual sentinel fill reaches position and accounting without native order");

   KingEAResearchVirtualPosition native_unused={};
   native_unused.equity=1000.0;
   KingEAResearchEntryRoute native_route={};
   KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_NATIVE,stress,
                            "SENTINEL-NATIVE",100.0,101.0,
                            KINGEA_DIRECTION_LONG,95.0,0.01,1000,
                            1800000,100.75,true,native_unused,native_route);
   Check(native_route.healthy && native_route.native_order_required &&
         native_route.fill_price==100.75 &&
         native_route.accounting_price==100.75 &&
         !native_unused.has_position,
         "native route consumes only tester result price and leaves virtual state unused");

   KingEAResearchVirtualPosition missed_position={};
   missed_position.equity=1000.0;
   KingEAResearchEntryRoute missed_route={};
   KingEAResearchStress always_missed=stress;
   always_missed.missed_entry_fraction=1.0;
   KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_VIRTUAL,always_missed,
                            "MISSED",100.0,101.0,KINGEA_DIRECTION_LONG,
                            95.0,0.01,1000,1800000,0.0,false,
                            missed_position,missed_route);
   Check(missed_route.outcome==KINGEA_RESEARCH_SEEDED_MISS &&
         !missed_route.enqueued && !missed_position.has_position,
         "seeded miss is terminal and never enters the delay queue");

   WriteContractReport();
   PrintFormat("STAGE14_RESEARCH_CONTRACT_%s: checks=%d; failures=%d; synthetic only; no performance authorization.",
               g_failures==0 ? "PASS" : "FAIL",g_checks,g_failures);
  }
