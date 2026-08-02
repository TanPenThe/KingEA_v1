#property copyright "KingEA"
#property version   "1.00"
#property tester_everytick_calculate
#property description "Guarded Candidate 001 research adapter; Strategy Tester only."
#property description "Requires a separately authorized content-addressed manifest."

#include <KingEA/ResearchExecution.mqh>
#include <KingEA/RegimeClassifier.mqh>
#include <KingEA/SleeveEthSt001.mqh>
#include <KingEA/SafetyKernel.mqh>
#include <KingEA/AccountingEvents.mqh>

input string InpRunManifest="";
input string InpManifestSha256="";
input string InpManifestFileSha256="";
input string InpDetachedAuthorizationToken="";
input string InpRootSha256="";
input int    InpGate=0;
input string InpPurpose="DEVELOPMENT";
input string InpPartition="";
input string InpBranch="RECORDED";
input string InpExpectedSymbol="";
input int    InpConfigurationId=-1;
input int    InpTesterModel=4;
input bool   InpLocalAgentsOnly=true;
input bool   InpRemoteAgentsDisabled=true;
input bool   InpCloudAgentsDisabled=true;
input string InpSelectionSha256="";
input string InpSurfaceSha256="";
input string InpStage15AuthorizationSha256="";
input string InpScenario="BASELINE_20MS";
input string InpExecutionAdapter="NATIVE";
input string InpCalendarSha256="";
input string InpCostManifestSha256="";
input string InpResearchSpecificationSha256="";
input string InpCalendarIntervalsFile="";
input string InpCalendarFileSha256="";
input int    InpDelayMs=20;
input double InpSpreadMultiplier=1.0;
input double InpCostMultiplier=1.0;
input double InpSlippageSpreadFraction=0.0;
input bool   InpVolatilityDependentSlippage=false;
input double InpMissedEntryFraction=0.0;
input uint   InpStressSeed=0;
input double InpCommissionPerLotRoundTurn=0.0;
input double InpSwapPerLotStress=0.0;
input double InpWeekendRiskMultiplier=0.50;
input int    InpMaintenanceEntryBlockMinutes=30;
input int    InpMaintenanceForceFlatMinutes=5;
input int    InpMaintenanceCleanMinutes=15;

KingEASleeveBar g_bars[];
KingEARegimeHysteresis g_regime_state={};
KingEASleeveState g_sleeve_state={};
KingEASafetyState g_safety_state={};
KingEACandidateParameters g_parameters={};
KingEASleevePositionContext g_position={};
KingEASleeveBar g_current_bar={};
bool g_has_current=false;
bool g_initialized=false;
bool g_manifest_valid=false;
double g_initial_equity=0.0;
double g_equity_high=0.0;
double g_day_open=0.0;
double g_week_open=0.0;
double g_month_open=0.0;
datetime g_day_start=0;
datetime g_week_start=0;
datetime g_month_start=0;
int g_entries=0;
int g_exits=0;
int g_missed=0;
int g_delay_expired=0;
int g_gate_rejected_after_delay=0;
int g_virtual_execution_failed=0;
int g_hard_failures=0;
double g_trade_returns[];
double g_trade_r[];
double g_daily_returns[];
double g_entry_equity=0.0;
double g_entry_risk_money=0.0;
KingEAAccountingCheckpoint g_accounting_checkpoint={};
string g_accounting_payloads[];
string g_account_fingerprint="";
string g_trade_group_id="";
double g_trade_net[];
double g_trade_mfe_r=0.0;
double g_trade_mae_r=0.0;
int g_trade_bars_held=0;
int g_accounting_close_count=0;
ulong g_open_order_ticket=0;
ulong g_open_deal_ticket=0;
ulong g_position_ticket=0;
ulong g_close_order_ticket=0;
ulong g_close_deal_ticket=0;
double g_trade_volume=0.0;
int g_current_volatility=KINGEA_STAGE10_VOLATILITY_INVALID;
KingEAResearchVirtualPosition g_virtual_position={};
bool g_virtual_pending=false;
string g_pending_signal_identity="";
int g_pending_direction=KINGEA_DIRECTION_NONE;
double g_pending_stop=0.0;
double g_pending_volume=0.0;
double g_pending_risk_money=0.0;
datetime g_pending_signal_bar=0;
long g_pending_due_msc=0;
long g_pending_expiry_msc=0;
double g_pending_requested_price=0.0;
long g_market_interval_start[];
long g_market_interval_end[];
string g_market_interval_type[];
bool g_market_intervals_loaded=false;
double g_current_bar_spreads[];
datetime g_spread_slot_time[];
double g_spread_slot_median[];
double g_latest_spread_ratio=0.0;
int g_above_three_count=0;
long g_above_three_start_msc=0;
bool g_spread_reduced=false;

void ResearchProcessPeriodTransition(const datetime now,const bool new_day,
                                     const bool new_week,const bool new_month);
void ResearchHealthyFacts(const datetime now,const double entry,
                          const double stop,const int direction,
                          KingEASafetyFacts &facts);
bool ResearchUsesVirtual();
double ResearchEquity();
bool ResearchHasPosition();
bool ResearchMarketBlocked(const long now_msc,string &kind);
bool ResearchProtectedForNews();
bool ResearchReduceHalf(const MqlTick &tick);
void ResearchTrackSpread(const MqlTick &tick);
void ResearchUpdateSpreadState(const MqlTick &tick);
double ResearchCurrentSpreadRatio(const MqlTick &tick);

string ResearchHex(const uchar &bytes[])
  {
   string result="";
   for(int i=0;i<ArraySize(bytes);i++)
      result+=StringFormat("%02X",(int)bytes[i]);
   return result;
  }

string ResearchSha256Bytes(const uchar &source[])
  {
   uchar key[],digest[];
   if(CryptEncode(CRYPT_HASH_SHA256,source,key,digest)!=32)
      return "";
   return ResearchHex(digest);
  }

string ResearchSha256String(const string value)
  {
   uchar bytes[];
   int count=StringToCharArray(value,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=0)
      return "";
   ArrayResize(bytes,count-1);
   return ResearchSha256Bytes(bytes);
  }

string ResearchFileSha256(const string filename)
  {
   int handle=FileOpen(filename,FILE_READ|FILE_BIN|FILE_COMMON);
   if(handle==INVALID_HANDLE)
      return "";
   ulong size=FileSize(handle);
   if(size==0 || size>10000000)
     {
      FileClose(handle);
      return "";
     }
   uchar bytes[];
   ArrayResize(bytes,(int)size);
   uint read=FileReadArray(handle,bytes,0,(int)size);
   FileClose(handle);
   if(read!=(uint)size)
      return "";
   return ResearchSha256Bytes(bytes);
  }

KingEAAccountingEvent ResearchAccountingBase(const int type,
                                              const string event_id,
                                              const long server_time_msc)
  {
   KingEAAccountingEvent event={};
   event.schema_version=1;
   event.event_id=event_id;
   event.event_type=type;
   event.server_time_msc=server_time_msc;
   event.utc_time_msc=server_time_msc;
   event.account_fingerprint=g_account_fingerprint;
   event.deployment_id="KINGEA-TESTER-STAGE13";
   event.candidate_id="CAND-ETH-ST-001";
   event.configuration_hash="A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE";
   event.sleeve_id="SLEEVE-1";
   event.trade_group_id=g_trade_group_id;
   event.symbol=_Symbol;
   event.account_equity=ResearchEquity();
   event.sleeve_equity=event.account_equity;
   event.source_quality="TESTER_ACCOUNTING_V1";
   return event;
  }

bool ResearchBufferAccounting(KingEAAccountingEvent &event)
  {
   KingEAAccountingDecision decision={};
   KingEAProcessAccountingEvent(event,g_accounting_checkpoint,decision);
   if(!decision.accepted)
     {
      g_hard_failures++;
      return false;
     }
   string payload=KingEAAccountingFramePayload(event,decision);
   if(payload=="")
     {
      g_hard_failures++;
      return false;
     }
   int count=ArraySize(g_accounting_payloads);
   ArrayResize(g_accounting_payloads,count+1);
   g_accounting_payloads[count]=payload;
   g_accounting_checkpoint=decision.next_checkpoint;
   return true;
  }

void ResearchUpdateTradeExcursion()
  {
   if(!g_position.has_position || ArraySize(g_bars)<1)
      return;
   double original_r=MathAbs(g_position.entry_price-
                             g_position.original_confirmed_stop);
   if(original_r<=0.0)
     {
      g_hard_failures++;
      return;
     }
   KingEASleeveBar bar=g_bars[ArraySize(g_bars)-1];
   double favorable=0.0,adverse=0.0;
   if(g_position.direction==KINGEA_DIRECTION_LONG)
     {
      favorable=(bar.high-g_position.entry_price)/original_r;
      adverse=(g_position.entry_price-bar.low)/original_r;
     }
   else
     {
      favorable=(g_position.entry_price-bar.low)/original_r;
      adverse=(bar.high-g_position.entry_price)/original_r;
     }
   g_trade_mfe_r=MathMax(g_trade_mfe_r,favorable);
   g_trade_mae_r=MathMax(g_trade_mae_r,adverse);
   g_trade_bars_held++;
  }

bool ResearchHash(const string value)
  {
   if(StringLen(value)!=64)
      return false;
   for(int i=0;i<64;i++)
     {
      ushort character=StringGetCharacter(value,i);
      if(!((character>='0' && character<='9') ||
           (character>='A' && character<='F')))
         return false;
     }
   return true;
  }

bool ResearchPartitionAuthorized()
  {
   if(InpPurpose=="DEVELOPMENT")
      return InpGate==1 &&
             ((StringFind(InpPartition,"FOLD_")==0 &&
               StringFind(InpPartition,"_TRAIN")>0) ||
              InpPartition=="FINAL_SELECTION");
   if(InpPurpose=="FORWARD")
      return InpGate==2 && StringFind(InpPartition,"FOLD_")==0 &&
             StringFind(InpPartition,"_FORWARD")>0;
   if(InpPurpose=="OOS")
      return InpGate==3 && InpPartition=="FORMAL_OOS" &&
             ResearchHash(InpSelectionSha256) && ResearchHash(InpSurfaceSha256);
   if(InpPurpose=="HOLDOUT")
      return InpPartition=="HOLDOUT" &&
             ResearchHash(InpStage15AuthorizationSha256);
   return false;
  }

bool ResearchAuthorizationValid()
  {
   if(!MQLInfoInteger(MQL_TESTER) || InpTesterModel!=4 ||
      !InpLocalAgentsOnly || !InpRemoteAgentsDisabled ||
      !InpCloudAgentsDisabled || !ResearchPartitionAuthorized())
      return false;
   if(!ResearchHash(InpRootSha256) ||
      (InpExecutionAdapter!="NATIVE" && InpExecutionAdapter!="VIRTUAL") ||
      InpScenario=="" || !ResearchHash(InpCalendarSha256) ||
      !ResearchHash(InpCalendarFileSha256) ||
      InpCalendarFileSha256!=InpCalendarSha256 ||
      InpCalendarIntervalsFile=="" ||
      ResearchFileSha256(InpCalendarIntervalsFile)!=InpCalendarFileSha256 ||
      !ResearchHash(InpCostManifestSha256) ||
      !ResearchHash(InpResearchSpecificationSha256) ||
      InpWeekendRiskMultiplier!=0.50 ||
      InpMaintenanceEntryBlockMinutes!=30 ||
      InpMaintenanceForceFlatMinutes!=5 ||
      InpMaintenanceCleanMinutes!=15)
      return false;
   if(InpRunManifest=="" || !ResearchHash(InpManifestSha256) ||
      !ResearchHash(InpManifestFileSha256) ||
      ResearchFileSha256(InpRunManifest)!=InpManifestFileSha256)
      return false;
   string expected=ResearchSha256String(InpManifestSha256+"|"+
                                         InpPurpose+"|RUNNING");
   return expected!="" && InpDetachedAuthorizationToken==expected;
  }

bool ResearchUsesVirtual()
  {
   return InpExecutionAdapter=="VIRTUAL";
  }

double ResearchEquity()
  {
   return ResearchUsesVirtual() ? g_virtual_position.equity :
                                  AccountInfoDouble(ACCOUNT_EQUITY);
  }

bool ResearchHasPosition()
  {
   return ResearchUsesVirtual() ? g_virtual_position.has_position :
                                  PositionSelect(_Symbol);
  }

bool ResearchLoadMarketIntervals()
  {
   ArrayResize(g_market_interval_start,0);
   ArrayResize(g_market_interval_end,0);
   ArrayResize(g_market_interval_type,0);
   int handle=FileOpen(InpCalendarIntervalsFile,
                       FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
      return false;
   bool first=true;
   long previous_start=0;
   while(!FileIsEnding(handle))
     {
      string type=FileReadString(handle);
      string start_text=FileReadString(handle);
      string end_text=FileReadString(handle);
      string identity=FileReadString(handle);
      if(first)
        {
         first=false;
         if(type!="type" || start_text!="start_msc" ||
            end_text!="end_msc" || identity!="identity")
           { FileClose(handle); return false; }
         continue;
        }
      if(type=="" && start_text=="" && end_text=="")
         continue;
      long start=(long)StringToInteger(start_text);
      long end=(long)StringToInteger(end_text);
      if((type!="NEWS_BLOCK" && type!="MAINTENANCE_ENTRY_BLOCK" &&
          type!="MAINTENANCE_FORCE_FLAT" &&
          type!="MAINTENANCE_RECOVERY") ||
         start<=0 || end<=start || identity=="" ||
         (previous_start>0 && start<previous_start))
        { FileClose(handle); return false; }
      int count=ArraySize(g_market_interval_start);
      ArrayResize(g_market_interval_start,count+1);
      ArrayResize(g_market_interval_end,count+1);
      ArrayResize(g_market_interval_type,count+1);
      g_market_interval_start[count]=start;
      g_market_interval_end[count]=end;
      g_market_interval_type[count]=type;
      previous_start=start;
     }
   FileClose(handle);
   return ArraySize(g_market_interval_start)>0;
  }

bool ResearchMarketBlocked(const long now_msc,string &kind)
  {
   kind="";
   if(!g_market_intervals_loaded)
     { kind="MARKET_INTERVALS_INVALID"; return true; }
   int selected_priority=0;
   for(int i=0;i<ArraySize(g_market_interval_start);i++)
     {
      if(now_msc<g_market_interval_start[i])
         break;
      if(now_msc>=g_market_interval_start[i] &&
         now_msc<g_market_interval_end[i])
        {
         int priority=(g_market_interval_type[i]=="MAINTENANCE_FORCE_FLAT" ? 4 :
                       g_market_interval_type[i]=="NEWS_BLOCK" ? 3 :
                       g_market_interval_type[i]=="MAINTENANCE_ENTRY_BLOCK" ? 2 : 1);
         if(priority>selected_priority)
           { selected_priority=priority; kind=g_market_interval_type[i]; }
        }
     }
   return selected_priority>0;
  }

bool ResearchProtectedForNews()
  {
   if(!g_position.has_position || !g_position.original_stop_confirmed ||
      g_trade_volume<=0.0)
      return false;
   double spread=MathAbs(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-
                         SymbolInfoDouble(_Symbol,SYMBOL_BID))*3.0;
   double slippage_fraction=(InpVolatilityDependentSlippage ?
      (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
       g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
      InpSlippageSpreadFraction);
   double worst_stop=(g_position.direction==KINGEA_DIRECTION_LONG ?
                      g_position.original_confirmed_stop-spread*(1.0+slippage_fraction) :
                      g_position.original_confirmed_stop+spread*(1.0+slippage_fraction));
   double profit=0.0;
   ENUM_ORDER_TYPE type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                         ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,_Symbol,g_trade_volume,g_position.entry_price,
                       worst_stop,profit))
      return false;
   double costs=(InpCommissionPerLotRoundTurn+InpSwapPerLotStress)*
                g_trade_volume*InpCostMultiplier;
   return profit-costs>0.0;
  }

double ResearchMedian(double &values[])
  {
   int count=ArraySize(values);
   if(count<=0)
      return 0.0;
   double ordered[];
   ArrayCopy(ordered,values);
   ArraySort(ordered);
   if((count%2)==1)
      return ordered[count/2];
   return (ordered[count/2-1]+ordered[count/2])/2.0;
  }

void ResearchFinalizeSpreadSlot(const datetime open_time)
  {
   double median=ResearchMedian(g_current_bar_spreads);
   if(median<=0.0 || !MathIsValidNumber(median))
     { g_hard_failures++; ArrayResize(g_current_bar_spreads,0); return; }
   int count=ArraySize(g_spread_slot_time);
   ArrayResize(g_spread_slot_time,count+1);
   ArrayResize(g_spread_slot_median,count+1);
   g_spread_slot_time[count]=open_time;
   g_spread_slot_median[count]=median;
   datetime cutoff=open_time-90*86400;
   int first=0;
   while(first<ArraySize(g_spread_slot_time) &&
         g_spread_slot_time[first]<cutoff)
      first++;
   if(first>0)
     {
      int remaining=ArraySize(g_spread_slot_time)-first;
      for(int i=0;i<remaining;i++)
        {
         g_spread_slot_time[i]=g_spread_slot_time[i+first];
         g_spread_slot_median[i]=g_spread_slot_median[i+first];
        }
      ArrayResize(g_spread_slot_time,remaining);
      ArrayResize(g_spread_slot_median,remaining);
     }
   ArrayResize(g_current_bar_spreads,0);
  }

double ResearchSpreadBaseline(const datetime now)
  {
   MqlDateTime current={};
   TimeToStruct(now,current);
   double matches[];
   ArrayResize(matches,0);
   datetime cutoff=now-90*86400;
   for(int i=0;i<ArraySize(g_spread_slot_time);i++)
     {
      if(g_spread_slot_time[i]<cutoff || g_spread_slot_time[i]>=now)
         continue;
      MqlDateTime prior={};
      TimeToStruct(g_spread_slot_time[i],prior);
      if(prior.day_of_week==current.day_of_week && prior.hour==current.hour &&
         prior.min==current.min)
        {
         int count=ArraySize(matches);
         ArrayResize(matches,count+1);
         matches[count]=g_spread_slot_median[i];
        }
     }
   if(ArraySize(matches)<8)
      return 0.0;
   return ResearchMedian(matches);
  }

double ResearchCurrentSpreadRatio(const MqlTick &tick)
  {
   double baseline=ResearchSpreadBaseline((datetime)((long)tick.time/1800*1800));
   double spread=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
   if(baseline<=0.0 || spread<0.0 || !MathIsValidNumber(spread))
      return 0.0;
   return spread/baseline;
  }

void ResearchTrackSpread(const MqlTick &tick)
  {
   double spread=MathAbs(tick.ask-tick.bid);
   if(!MathIsValidNumber(spread) || spread<=0.0)
     { g_hard_failures++; return; }
   int count=ArraySize(g_current_bar_spreads);
   ArrayResize(g_current_bar_spreads,count+1);
   g_current_bar_spreads[count]=spread;
  }

void ResearchUpdateSpreadState(const MqlTick &tick)
  {
   g_latest_spread_ratio=ResearchCurrentSpreadRatio(tick);
   if(g_latest_spread_ratio>3.0)
     {
      if(g_above_three_count==0)
         g_above_three_start_msc=(long)tick.time_msc;
      g_above_three_count++;
     }
   else
     {
      g_above_three_count=0;
      g_above_three_start_msc=0;
     }
  }

bool ResearchOrderSend(MqlTradeRequest &request,MqlTradeResult &result)
  {
   // Every tester order path revalidates the complete immutable guard.
   if(!g_initialized || !ResearchAuthorizationValid())
     {
      g_hard_failures++;
      return false;
     }
   return OrderSend(request,result);
  }

datetime ResearchDayStart(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   parts.hour=0; parts.min=0; parts.sec=0;
   return StructToTime(parts);
  }

datetime ResearchWeekStart(const datetime value)
  {
   datetime day=ResearchDayStart(value);
   MqlDateTime parts={};
   TimeToStruct(day,parts);
   int offset=(parts.day_of_week+6)%7;
   return day-offset*86400;
  }

datetime ResearchMonthStart(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   parts.day=1; parts.hour=0; parts.min=0; parts.sec=0;
   return StructToTime(parts);
  }

void ResearchUpdatePeriods(const datetime now)
  {
   double equity=ResearchEquity();
   datetime day=ResearchDayStart(now);
   datetime week=ResearchWeekStart(now);
   datetime month=ResearchMonthStart(now);
   bool changed_day=(g_day_start>0 && day!=g_day_start);
   bool changed_week=(g_week_start>0 && week!=g_week_start);
   bool changed_month=(g_month_start>0 && month!=g_month_start);
   if(day!=g_day_start)
     {
      if(g_day_start>0 && g_day_open>0.0)
        {
         int count=ArraySize(g_daily_returns);
         ArrayResize(g_daily_returns,count+1);
         g_daily_returns[count]=(equity-g_day_open)/g_day_open;
        }
      g_day_start=day;
      g_day_open=equity;
     }
   if(week!=g_week_start) { g_week_start=week; g_week_open=equity; }
   if(month!=g_month_start) { g_month_start=month; g_month_open=equity; }
   g_equity_high=MathMax(g_equity_high,equity);
   if(changed_day || changed_week || changed_month)
      ResearchProcessPeriodTransition(now,changed_day,changed_week,changed_month);
  }

void ResearchFinalizeClosedTrade()
  {
   if(!g_position.has_position || ResearchHasPosition())
      return;
   double equity=ResearchEquity();
   double profit=equity-g_entry_equity;
   int count=ArraySize(g_trade_returns);
   ArrayResize(g_trade_returns,count+1);
   ArrayResize(g_trade_r,count+1);
   ArrayResize(g_trade_net,count+1);
   g_trade_returns[count]=(g_entry_equity>0.0 ? profit/g_entry_equity : 0.0);
   g_trade_r[count]=(g_entry_risk_money>0.0 ? profit/g_entry_risk_money : 0.0);
   g_trade_net[count]=profit;
   KingEAAccountingEvent accounting=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_TRADE_GROUP_CLOSE,
      "CLOSE|"+g_trade_group_id+"|"+(string)(count+1),
      (long)TimeCurrent()*1000);
   accounting.order_ticket=g_close_order_ticket;
   accounting.deal_ticket=g_close_deal_ticket;
   accounting.position_ticket=g_position_ticket;
   accounting.direction=g_position.direction;
   accounting.volume=g_trade_volume;
   accounting.requested_price=0.0;
   accounting.executed_price=0.0;
   accounting.protective_stop=g_position.original_confirmed_stop;
   accounting.gross_profit=profit;
   accounting.net_return=g_trade_returns[count];
   accounting.net_r=g_trade_r[count];
   accounting.mae_r=g_trade_mae_r;
   accounting.mfe_r=g_trade_mfe_r;
   accounting.bars_held=g_trade_bars_held;
   accounting.reason_code="TRADE_GROUP_CLOSE";
   if(ResearchBufferAccounting(accounting))
      g_accounting_close_count++;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(TimeCurrent(),g_position.entry_price,
                        g_position.original_confirmed_stop,
                        g_position.direction,facts);
   KingEASafetyRequest closed={};
   closed.event=KINGEA_EVENT_CLOSED_TRADE_GROUP;
   closed.scope=KINGEA_SCOPE_SLEEVE;
   closed.closed_group_full_loss=(g_trade_r[count]<=-0.80);
   KingEASafetyDecision safety={};
   KingEAEvaluateSafety(closed,facts,g_safety_state,safety);
   g_safety_state=safety.next_state;
   if(safety.action==KINGEA_ACTION_QUARANTINE)
      g_hard_failures++;
   ZeroMemory(g_position);
   g_entry_equity=0.0;
   g_entry_risk_money=0.0;
   g_trade_group_id="";
   g_trade_mfe_r=0.0;
   g_trade_mae_r=0.0;
   g_trade_bars_held=0;
   g_open_order_ticket=0;
   g_open_deal_ticket=0;
   g_position_ticket=0;
   g_close_order_ticket=0;
   g_close_deal_ticket=0;
   g_trade_volume=0.0;
   g_spread_reduced=false;
  }

void ResearchAppendBar(const KingEASleeveBar &bar)
  {
   int count=ArraySize(g_bars);
   if(count>=5000)
     {
      for(int i=1;i<count;i++)
         g_bars[i-1]=g_bars[i];
      count--;
      ArrayResize(g_bars,count);
     }
   ArrayResize(g_bars,count+1);
   g_bars[count]=bar;
  }

bool ResearchBuildRegime(KingEARegimeDecision &decision,
                         const datetime evaluation_time)
  {
   int count=ArraySize(g_bars);
   KingEARegimeBar bars[];
   ArrayResize(bars,count);
   for(int i=0;i<count;i++)
     {
      bars[i].open_time=g_bars[i].open_time;
      bars[i].open=g_bars[i].open;
      bars[i].high=g_bars[i].high;
      bars[i].low=g_bars[i].low;
      bars[i].close=g_bars[i].close;
      bars[i].complete=g_bars[i].complete;
     }
   KingEARegimeRequest request={};
   request.evaluation_time=evaluation_time;
   request.expected_open_slots=4320;
   request.maximum_staleness_seconds=1800;
   KingEAEvaluateRegime(bars,request,g_regime_state,decision);
   g_regime_state=decision.next_state;
   return decision.healthy;
  }

void ResearchHealthyFacts(const datetime now,const double entry,
                          const double stop,const int direction,
                          KingEASafetyFacts &facts)
  {
   ZeroMemory(facts);
   double equity=ResearchEquity();
   double loss=0.0;
   ENUM_ORDER_TYPE type=(direction==KINGEA_DIRECTION_LONG ?
                         ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,_Symbol,1.0,entry,stop,loss))
      loss=0.0;
   double margin=0.0;
   if(!OrderCalcMargin(type,_Symbol,1.0,entry,margin))
      margin=0.0;
   double spread=MathAbs(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-
                         SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double slippage=spread*InpSpreadMultiplier*
                   InpSlippageSpreadFraction;
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
   double slippage_cost=(tick_size>0.0 ? slippage/tick_size*tick_value : 0.0);
   facts.now_server=now;
   facts.account_equity=equity;
   facts.account_day_open_equity=g_day_open;
   facts.account_week_open_equity=g_week_open;
   facts.account_month_open_equity=g_month_open;
   facts.account_equity_high=g_equity_high;
   facts.sleeve_equity=equity;
   facts.sleeve_week_open_equity=g_week_open;
   facts.sleeve_month_open_equity=g_month_open;
   facts.sleeve_equity_high=g_equity_high;
   MqlDateTime parts={};
   TimeToStruct(now,parts);
   bool weekend=(parts.day_of_week==0 || parts.day_of_week==6);
   facts.sleeve_tier_percent=1.10*(weekend ? InpWeekendRiskMultiplier : 1.0);
   facts.cluster_known=true;
   facts.volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   facts.volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   facts.volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   facts.stressed_loss_per_lot=MathAbs(loss)+
      (InpCommissionPerLotRoundTurn+InpSwapPerLotStress+slippage_cost)*
      InpCostMultiplier;
   facts.live_margin_per_lot=margin;
   facts.notional_per_lot=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)*entry;
   facts.current_used_margin=(ResearchUsesVirtual() ? 0.0 :
                              AccountInfoDouble(ACCOUNT_MARGIN));
   facts.spread_ratio=(g_latest_spread_ratio>0.0 ? g_latest_spread_ratio : 999.0);
   facts.stop_valid=true;
   facts.state_valid=true;
   facts.configuration_valid=true;
   facts.exposure_reconciled=true;
   facts.stops_confirmed=true;
   facts.connection_healthy=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   facts.specification_healthy=true;
   string market_kind="";
   bool market_blocked=ResearchMarketBlocked((long)now*1000,market_kind);
   facts.calendar_fresh=g_market_intervals_loaded;
   facts.market_open=!market_blocked;
   facts.external_cash_flow_reconciled=true;
  }

void ResearchProcessPeriodTransition(const datetime now,const bool new_day,
                                     const bool new_week,const bool new_month)
  {
   double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(entry<=0.0)
      entry=1.0;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(now,entry,entry*0.99,KINGEA_DIRECTION_LONG,facts);
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_PERIOD_TRANSITION;
   request.scope=KINGEA_SCOPE_ACCOUNT;
   request.new_broker_day=new_day;
   request.new_broker_week=new_week;
   request.new_broker_month=new_month;
   KingEASafetyDecision decision={};
   KingEAEvaluateSafety(request,facts,g_safety_state,decision);
   g_safety_state=decision.next_state;
   if(decision.action==KINGEA_ACTION_QUARANTINE)
      g_hard_failures++;
   if(new_day)
     {
      KingEAAccountingEvent valuation=ResearchAccountingBase(
         KINGEA_ACCOUNTING_EVENT_VALUATION,
         "DAY|"+(string)ResearchDayStart(now),(long)now*1000);
      valuation.reason_code="BROKER_DAY_TRANSITION";
      ResearchBufferAccounting(valuation);
     }
  }

bool ResearchOpen(const KingEASleeveDecision &intent,const MqlTick &tick)
  {
   if(ResearchHasPosition() || g_virtual_pending)
      return false;
   KingEAResearchStress stress={};
   stress.delay_ms=InpDelayMs;
   stress.spread_multiplier=InpSpreadMultiplier;
   stress.cost_multiplier=InpCostMultiplier;
   stress.slippage_spread_fraction=(InpVolatilityDependentSlippage ?
      (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
       g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
      InpSlippageSpreadFraction);
   stress.missed_entry_fraction=InpMissedEntryFraction;
   stress.seed=InpStressSeed;
   KingEAResearchVirtualFill virtual_fill={};
   KingEAResearchApplyVirtualStress(stress,intent.signal_identity,
                                    tick.bid,tick.ask,intent.direction,
                                    virtual_fill);
   if(!virtual_fill.healthy)
      return false;
   if(virtual_fill.missed)
     {
      g_missed++;
      KingEAAccountingEvent missed=ResearchAccountingBase(
         KINGEA_ACCOUNTING_EVENT_MISSED_SIGNAL,
         "MISSED|"+intent.signal_identity,(long)tick.time_msc);
      missed.signal_id=intent.signal_identity;
      missed.direction=intent.direction;
      missed.reason_code="DETERMINISTIC_STRESS_MISS";
      ResearchBufferAccounting(missed);
      return true;
     }
   double entry=(ResearchUsesVirtual() ? virtual_fill.entry_price :
                 (intent.direction==KINGEA_DIRECTION_LONG ? tick.ask : tick.bid));
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_ENTRY;
   request.scope=KINGEA_SCOPE_SLEEVE;
   request.direction=(intent.direction==KINGEA_DIRECTION_LONG ?
                      KINGEA_SAFETY_LONG : KINGEA_SAFETY_SHORT);
   request.entry_price=entry;
   request.technical_stop=intent.technical_stop;
   request.signal_present=true;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(tick.time,entry,intent.technical_stop,
                        intent.direction,facts);
   KingEASafetyDecision safety={};
   KingEAEvaluateSafety(request,facts,g_safety_state,safety);
   g_safety_state=safety.next_state;
   if(safety.action!=KINGEA_ACTION_APPROVE_ENTRY &&
      safety.action!=KINGEA_ACTION_DOWNSIZE_ENTRY)
     {
      if(safety.reason==KINGEA_REASON_MONTHLY_BREAKER ||
         safety.reason==KINGEA_REASON_PERMANENT_BREAKER ||
         safety.reason==KINGEA_REASON_CUMULATIVE_REVIEW ||
         safety.reason==KINGEA_REASON_THROTTLE_REVIEW ||
         safety.reason==KINGEA_REASON_UNKNOWN_EXPOSURE)
         g_hard_failures++;
      return false;
     }
   double equity_before=ResearchEquity();
   int adapter=(ResearchUsesVirtual() ? KINGEA_RESEARCH_ADAPTER_VIRTUAL :
                                       KINGEA_RESEARCH_ADAPTER_NATIVE);
   KingEAResearchStress routed_stress=stress;
   routed_stress.missed_entry_fraction=0.0; // Already decided before sizing/queueing.
   KingEAResearchEntryRoute route={};
   long expiry=((long)tick.time/1800+1)*1800*1000;
   KingEAResearchRouteEntry(adapter,routed_stress,intent.signal_identity,
                            tick.bid,tick.ask,intent.direction,
                            safety.required_stop,safety.permitted_volume,
                            (long)tick.time_msc,expiry,0.0,false,
                            g_virtual_position,route);
   if(!route.healthy)
      return false;
   if(route.outcome==KINGEA_RESEARCH_DELAY_QUEUED)
     {
      g_virtual_pending=true;
      g_pending_signal_identity=intent.signal_identity;
      g_pending_direction=intent.direction;
      g_pending_stop=safety.required_stop;
      g_pending_volume=safety.permitted_volume;
      g_pending_risk_money=safety.permitted_risk_money;
      g_pending_signal_bar=intent.signal_bar_time;
      g_pending_due_msc=route.due_time_msc;
      g_pending_expiry_msc=route.expiry_time_msc;
      g_pending_requested_price=entry;
      return true;
     }
   MqlTradeResult result={};
   if(route.native_order_required)
     {
      MqlTradeRequest order={};
      order.action=TRADE_ACTION_DEAL;
      order.symbol=_Symbol;
      order.volume=safety.permitted_volume;
      order.type=(intent.direction==KINGEA_DIRECTION_LONG ?
                  ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      order.price=entry;
      order.sl=safety.required_stop;
      order.tp=0.0;
      order.deviation=0;
      order.magic=12001;
      order.comment="KINGEA|CAND-ETH-ST-001|"+intent.signal_identity;
      order.type_filling=ORDER_FILLING_IOC;
      if(!ResearchOrderSend(order,result) ||
         (result.retcode!=TRADE_RETCODE_DONE &&
          result.retcode!=TRADE_RETCODE_PLACED))
         return false;
      KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_NATIVE,routed_stress,
                               intent.signal_identity,tick.bid,tick.ask,
                               intent.direction,safety.required_stop,
                               safety.permitted_volume,(long)tick.time_msc,
                               expiry,result.price>0.0 ? result.price : entry,
                               true,g_virtual_position,route);
      if(!route.healthy)
         return false;
     }
   g_position.has_position=true;
   g_position.direction=intent.direction;
   g_position.entry_signal_bar_time=intent.signal_bar_time;
   g_position.entry_price=route.fill_price;
   g_position.original_confirmed_stop=safety.required_stop;
   g_position.original_stop_confirmed=true;
   g_entry_equity=equity_before;
   g_entry_risk_money=safety.permitted_risk_money;
   g_trade_group_id=intent.signal_identity;
   g_open_order_ticket=(ResearchUsesVirtual() ? 0 : result.order);
   g_open_deal_ticket=(ResearchUsesVirtual() ? 0 : result.deal);
   g_position_ticket=(ResearchUsesVirtual() ? 0 :
                      (PositionSelect(_Symbol) ?
                       (ulong)PositionGetInteger(POSITION_TICKET) : result.order));
   g_trade_volume=safety.permitted_volume;
   g_spread_reduced=false;
   KingEAAccountingEvent accounting=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_DEAL,
      "ENTRY|"+intent.signal_identity,(long)tick.time_msc);
   accounting.signal_id=intent.signal_identity;
   accounting.order_ticket=g_open_order_ticket;
   accounting.deal_ticket=g_open_deal_ticket;
   accounting.position_ticket=g_position_ticket;
   accounting.direction=intent.direction;
   accounting.volume=safety.permitted_volume;
   accounting.requested_price=entry;
   accounting.executed_price=g_position.entry_price;
   accounting.protective_stop=safety.required_stop;
   accounting.spread_attribution=MathAbs(tick.ask-tick.bid);
   accounting.slippage_attribution=MathAbs(g_position.entry_price-entry);
   accounting.reason_code=(ResearchUsesVirtual() ? "VIRTUAL_FILL" :
                                                    "NATIVE_FILL");
   ResearchBufferAccounting(accounting);
   g_entries++;
   return true;
  }

bool ResearchClose(const int direction,const MqlTick &tick)
  {
   if(!ResearchHasPosition())
      return true;
   if(ResearchUsesVirtual())
     {
      double raw=(direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
      double spread=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
      double slippage_fraction=(InpVolatilityDependentSlippage ?
         (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
          g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
         InpSlippageSpreadFraction);
      double slippage=spread*slippage_fraction;
      double exit_price=(direction==KINGEA_DIRECTION_LONG ? raw-slippage :
                                                           raw+slippage);
      double profit=0.0;
      ENUM_ORDER_TYPE type=(direction==KINGEA_DIRECTION_LONG ?
                            ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      if(!OrderCalcProfit(type,_Symbol,g_virtual_position.volume,
                          g_virtual_position.entry_price,exit_price,profit))
        { g_hard_failures++; return false; }
      double explicit_cost=(InpCommissionPerLotRoundTurn+
                            InpSwapPerLotStress)*g_virtual_position.volume*
                            InpCostMultiplier;
      g_virtual_position.equity+=profit-explicit_cost;
      g_virtual_position.has_position=false;
      g_close_order_ticket=0;
      g_close_deal_ticket=0;
      g_exits++;
      ResearchFinalizeClosedTrade();
      return true;
     }
   ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
   double volume=PositionGetDouble(POSITION_VOLUME);
   MqlTradeRequest request={};
   MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL;
   request.position=ticket;
   request.symbol=_Symbol;
   request.volume=volume;
   request.type=(direction==KINGEA_DIRECTION_LONG ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   request.price=(direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
   request.deviation=0;
   request.magic=12001;
   request.comment="KINGEA|CAND-ETH-ST-001|EXIT";
   request.type_filling=ORDER_FILLING_IOC;
   if(!ResearchOrderSend(request,result) || result.retcode!=TRADE_RETCODE_DONE)
      return false;
   g_close_order_ticket=result.order;
   g_close_deal_ticket=result.deal;
   g_exits++;
   ResearchFinalizeClosedTrade();
   return true;
  }

bool ResearchReduceHalf(const MqlTick &tick)
  {
   if(!ResearchHasPosition() || g_spread_reduced)
      return true;
   double current=(ResearchUsesVirtual() ? g_virtual_position.volume :
                   PositionGetDouble(POSITION_VOLUME));
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(current<=0.0 || step<=0.0 || minimum<=0.0)
      return ResearchClose(g_position.direction,tick);
   double remaining=MathFloor((current*0.5+1e-12)/step)*step;
   remaining=NormalizeDouble(remaining,8);
   if(remaining<minimum)
      return ResearchClose(g_position.direction,tick);
   double reduction=NormalizeDouble(current-remaining,8);
   if(reduction<minimum)
      return ResearchClose(g_position.direction,tick);
   if(ResearchUsesVirtual())
     {
      double raw=(g_position.direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
      double spread=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
      double fraction=(InpVolatilityDependentSlippage ?
         (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
          g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
         InpSlippageSpreadFraction);
      double exit_price=(g_position.direction==KINGEA_DIRECTION_LONG ?
                         raw-spread*fraction : raw+spread*fraction);
      double profit=0.0;
      ENUM_ORDER_TYPE type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                            ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      if(!OrderCalcProfit(type,_Symbol,reduction,g_virtual_position.entry_price,
                          exit_price,profit))
         return false;
      double costs=(InpCommissionPerLotRoundTurn+InpSwapPerLotStress)*reduction*
                   InpCostMultiplier;
      g_virtual_position.equity+=profit-costs;
      g_virtual_position.volume=remaining;
     }
   else
     {
      MqlTradeRequest request={};
      MqlTradeResult result={};
      request.action=TRADE_ACTION_DEAL;
      request.position=(ulong)PositionGetInteger(POSITION_TICKET);
      request.symbol=_Symbol;
      request.volume=reduction;
      request.type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                    ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      request.price=(g_position.direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
      request.magic=12001;
      request.comment="KINGEA|EMERGENCY_SPREAD_REDUCTION";
      request.type_filling=ORDER_FILLING_IOC;
      if(!ResearchOrderSend(request,result) || result.retcode!=TRADE_RETCODE_DONE)
         return ResearchClose(g_position.direction,tick);
     }
   g_trade_volume=remaining;
   g_spread_reduced=true;
   KingEAAccountingEvent safety=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_SAFETY,"SPREAD_REDUCE|"+g_trade_group_id,
      (long)tick.time_msc);
   safety.direction=g_position.direction;
   safety.volume=reduction;
   safety.reason_code="SPREAD_ABOVE_2_5X_REDUCE_50_PERCENT";
   ResearchBufferAccounting(safety);
   return true;
  }

void ResearchClearVirtualPending()
  {
   g_virtual_pending=false;
   g_pending_signal_identity="";
   g_pending_direction=KINGEA_DIRECTION_NONE;
   g_pending_stop=0.0;
   g_pending_volume=0.0;
   g_pending_risk_money=0.0;
   g_pending_signal_bar=0;
   g_pending_due_msc=0;
   g_pending_expiry_msc=0;
   g_pending_requested_price=0.0;
  }

void ResearchProcessVirtualPending(const MqlTick &tick)
  {
   if(!ResearchUsesVirtual() || !g_virtual_pending)
      return;
   if((long)tick.time_msc<g_pending_due_msc)
      return;
   string market_kind="";
   bool market_blocked=ResearchMarketBlocked((long)tick.time_msc,market_kind);
   bool gates_healthy=(InpSpreadMultiplier<=2.0 && !market_blocked &&
                       TerminalInfoInteger(TERMINAL_CONNECTED));
   KingEAResearchStress stress={};
   stress.delay_ms=InpDelayMs;
   stress.spread_multiplier=InpSpreadMultiplier;
   stress.cost_multiplier=InpCostMultiplier;
   stress.slippage_spread_fraction=(InpVolatilityDependentSlippage ?
      (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
       g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
      InpSlippageSpreadFraction);
   stress.missed_entry_fraction=0.0;
   stress.seed=InpStressSeed;
   KingEAResearchEntryRoute route={};
   KingEAResearchCompleteDelayedEntry(stress,g_pending_signal_identity,
                                      tick.bid,tick.ask,g_pending_direction,
                                      g_pending_stop,g_pending_volume,
                                      (long)tick.time_msc,g_pending_due_msc,
                                      g_pending_expiry_msc,gates_healthy,true,
                                      g_virtual_position,route);
   if(route.outcome==KINGEA_RESEARCH_DELAY_QUEUED)
      return;
   if(route.outcome==KINGEA_RESEARCH_DELAY_EXPIRY)
      g_delay_expired++;
   else if(route.outcome==KINGEA_RESEARCH_GATE_REJECT_AFTER_DELAY)
      g_gate_rejected_after_delay++;
   else if(route.outcome==KINGEA_RESEARCH_VIRTUAL_EXECUTION_FAILURE ||
           !route.healthy)
      g_virtual_execution_failed++;
   else if(route.outcome==KINGEA_RESEARCH_VIRTUAL_FILL)
     {
      g_position.has_position=true;
      g_position.direction=g_pending_direction;
      g_position.entry_signal_bar_time=g_pending_signal_bar;
      g_position.entry_price=route.fill_price;
      g_position.original_confirmed_stop=g_pending_stop;
      g_position.original_stop_confirmed=true;
      g_entry_equity=g_virtual_position.entry_equity;
      g_entry_risk_money=g_pending_risk_money;
      g_trade_group_id=g_pending_signal_identity;
      g_trade_volume=g_pending_volume;
      g_spread_reduced=false;
      KingEAAccountingEvent accounting=ResearchAccountingBase(
         KINGEA_ACCOUNTING_EVENT_DEAL,"ENTRY|"+g_pending_signal_identity,
         (long)tick.time_msc);
      accounting.signal_id=g_pending_signal_identity;
      accounting.direction=g_pending_direction;
      accounting.volume=g_pending_volume;
      accounting.requested_price=g_pending_requested_price;
      accounting.executed_price=route.accounting_price;
      accounting.protective_stop=g_pending_stop;
      accounting.spread_attribution=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
      accounting.slippage_attribution=MathAbs(route.accounting_price-
                                               g_pending_requested_price);
      accounting.reason_code="VIRTUAL_FILL_AFTER_DELAY";
      ResearchBufferAccounting(accounting);
      g_entries++;
     }
   ResearchClearVirtualPending();
  }

void ResearchEvaluateClosedBar(const datetime evaluation_time,
                               const MqlTick &tick)
  {
   KingEARegimeDecision regime={};
   ResearchBuildRegime(regime,evaluation_time);
   g_current_volatility=regime.volatility_state;
   KingEASleeveRequest request={};
   request.evaluation_time=evaluation_time;
   request.parameters=g_parameters;
   request.regime=regime;
   request.position=g_position;
   request.has_open_trade_group=ResearchHasPosition();
   KingEASleeveDecision intent={};
   KingEAEvaluateSleeveEthSt001(g_bars,request,g_sleeve_state,intent);
   g_sleeve_state=intent.next_state;
   ResearchUpdateTradeExcursion();
   if(intent.action==KINGEA_SLEEVE_ACTION_ENTRY)
      ResearchOpen(intent,tick);
   else if(intent.action==KINGEA_SLEEVE_ACTION_EXIT)
      ResearchClose(g_position.direction,tick);
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("KingEA research adapter refused: Strategy Tester only.");
      return INIT_FAILED;
     }
   if(InpExpectedSymbol=="" || _Symbol!=InpExpectedSymbol ||
      (InpBranch=="RECORDED" && _Symbol!="ETHUSD.s") ||
      (InpBranch=="RSB3" && _Symbol!="KINGEA_ETHUSD_S_RSB3") ||
      (InpBranch!="RECORDED" && InpBranch!="RSB3"))
      return INIT_FAILED;
   if(!KingEAResearchDecodeConfiguration(InpConfigurationId,g_parameters))
      return INIT_PARAMETERS_INCORRECT;
   g_manifest_valid=ResearchAuthorizationValid();
   if(!g_manifest_valid)
     {
      Print("KingEA research adapter refused: manifest/authorization guard failed.");
      return INIT_FAILED;
     }
   g_market_intervals_loaded=ResearchLoadMarketIntervals();
   if(!g_market_intervals_loaded)
      return INIT_FAILED;
   if(ResearchUsesVirtual())
      g_virtual_position.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_initial_equity=ResearchEquity();
   if(g_initial_equity<=0.0)
      return INIT_FAILED;
   g_account_fingerprint=ResearchSha256String(
      AccountInfoString(ACCOUNT_SERVER)+"|"+
      (string)AccountInfoInteger(ACCOUNT_LOGIN));
   if(!ResearchHash(g_account_fingerprint))
      return INIT_FAILED;
   g_equity_high=g_initial_equity;
   ResearchUpdatePeriods(TimeCurrent());
   g_initialized=true;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!g_initialized)
      return;
   MqlTick tick={};
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0)
      return;
   ResearchUpdateSpreadState(tick);
   if(ResearchHasPosition() && g_latest_spread_ratio>2.5 &&
      !g_spread_reduced)
      ResearchReduceHalf(tick);
   if(ResearchHasPosition() && g_above_three_count>=3 &&
      (long)tick.time_msc-g_above_three_start_msc>=10000)
      ResearchClose(g_position.direction,tick);
   ResearchProcessVirtualPending(tick);
   string market_kind="";
   bool market_blocked=ResearchMarketBlocked((long)tick.time_msc,market_kind);
   if(ResearchHasPosition() && market_blocked &&
      (market_kind=="MAINTENANCE_FORCE_FLAT" ||
       (market_kind=="NEWS_BLOCK" && !ResearchProtectedForNews())))
      ResearchClose(g_position.direction,tick);
   if(ResearchUsesVirtual() && g_virtual_position.has_position)
     {
      bool stopped=(g_virtual_position.direction==KINGEA_DIRECTION_LONG ?
                    tick.bid<=g_virtual_position.protective_stop :
                    tick.ask>=g_virtual_position.protective_stop);
      if(stopped)
         ResearchClose(g_virtual_position.direction,tick);
     }
   ResearchFinalizeClosedTrade();
   ResearchUpdatePeriods(tick.time);
   datetime bucket=(datetime)((long)tick.time/1800*1800);
   if(!g_has_current)
     {
      g_current_bar.open_time=bucket;
      g_current_bar.open=tick.bid;
      g_current_bar.high=tick.bid;
      g_current_bar.low=tick.bid;
      g_current_bar.close=tick.bid;
      g_current_bar.complete=false;
      g_has_current=true;
      ResearchTrackSpread(tick);
      return;
     }
   if(bucket==g_current_bar.open_time)
     {
      g_current_bar.high=MathMax(g_current_bar.high,tick.bid);
      g_current_bar.low=MathMin(g_current_bar.low,tick.bid);
      g_current_bar.close=tick.bid;
      ResearchTrackSpread(tick);
      return;
     }
   if(bucket<g_current_bar.open_time)
     {
      g_hard_failures++;
      return;
     }
   g_current_bar.complete=true;
   ResearchFinalizeSpreadSlot(g_current_bar.open_time);
   ResearchAppendBar(g_current_bar);
   ResearchEvaluateClosedBar(tick.time,tick);
   g_current_bar.open_time=bucket;
   g_current_bar.open=tick.bid;
   g_current_bar.high=tick.bid;
   g_current_bar.low=tick.bid;
   g_current_bar.close=tick.bid;
   g_current_bar.complete=false;
   ResearchTrackSpread(tick);
  }

double OnTester()
  {
   ResearchFinalizeClosedTrade();
   if(g_day_start>0 && g_day_open>0.0)
     {
      int day_count=ArraySize(g_daily_returns);
      ArrayResize(g_daily_returns,day_count+1);
      g_daily_returns[day_count]=(ResearchEquity()-g_day_open)/g_day_open;
     }
   double legacy_net=0.0;
   for(int i=0;i<ArraySize(g_trade_net);i++)
      legacy_net+=g_trade_net[i];
   if(g_accounting_close_count!=ArraySize(g_trade_returns) ||
      MathAbs(legacy_net-g_accounting_checkpoint.strategy_net_pnl)>0.000001)
      g_hard_failures++;
   for(int i=0;i<ArraySize(g_accounting_payloads);i++)
     {
      uchar accounting_frame[];
      int bytes=StringToCharArray(g_accounting_payloads[i],accounting_frame,
                                  0,WHOLE_ARRAY,CP_UTF8);
      if(bytes>0) ArrayResize(accounting_frame,bytes-1);
      if(bytes<=0 || !FrameAdd("KINGEA_STAGE13_ACCOUNTING_EVENT",i+1,0.0,
                               accounting_frame))
         g_hard_failures++;
     }
   string accounting_complete=StringFormat(
      "schema=1|event_count=%d|close_count=%d|trade_return_count=%d|legacy_net=%.12f|ledger_net=%.12f|root=%s|complete=1",
      ArraySize(g_accounting_payloads),g_accounting_close_count,
      ArraySize(g_trade_returns),legacy_net,
      g_accounting_checkpoint.strategy_net_pnl,
      g_accounting_checkpoint.ledger_root_sha256);
   uchar accounting_summary[];
   int accounting_bytes=StringToCharArray(accounting_complete,
                                           accounting_summary,0,WHOLE_ARRAY,CP_UTF8);
   if(accounting_bytes>0) ArrayResize(accounting_summary,accounting_bytes-1);
   if(accounting_bytes<=0 ||
      !FrameAdd("KINGEA_STAGE13_ACCOUNTING_COMPLETE",InpConfigurationId,
                0.0,accounting_summary))
      g_hard_failures++;
   string payload=StringFormat("config=%d|branch=%s|partition=%s|entries=%d|exits=%d|missed=%d|delay_expiry=%d|gate_reject_after_delay=%d|virtual_execution_failure=%d|hard_failures=%d|complete=1",
                               InpConfigurationId,InpBranch,InpPartition,
                               g_entries,g_exits,g_missed,g_delay_expired,
                               g_gate_rejected_after_delay,
                               g_virtual_execution_failed,g_hard_failures);
   payload+="|trade_returns=";
   for(int i=0;i<ArraySize(g_trade_returns);i++)
      payload+=(i>0 ? ";" : "")+DoubleToString(g_trade_returns[i],12);
   payload+="|trade_r=";
   for(int i=0;i<ArraySize(g_trade_r);i++)
      payload+=(i>0 ? ";" : "")+DoubleToString(g_trade_r[i],12);
   payload+="|daily_returns=";
   for(int i=0;i<ArraySize(g_daily_returns);i++)
      payload+=(i>0 ? ";" : "")+DoubleToString(g_daily_returns[i],12);
   uchar frame[];
   int count=StringToCharArray(payload,frame,0,WHOLE_ARRAY,CP_UTF8);
   if(count>0)
      ArrayResize(frame,count-1);
   if(!FrameAdd("KINGEA_STAGE12_COMPLETE",InpConfigurationId,0.0,frame))
      g_hard_failures++;
   return g_hard_failures==0 ? 0.0 : -1.0;
  }

void ResearchDrainFrames()
  {
   ulong pass=0;
   string name="";
   long identifier=0;
   double value=0.0;
   uchar data[];
   while(FrameNext(pass,name,identifier,value,data))
     {
      string safe=name;
      StringReplace(safe,"\\","_");
      StringReplace(safe,"/","_");
      StringReplace(safe,":","_");
      StringReplace(safe,"|","_");
      string filename=StringFormat("KingEA\\stage14_spool\\%s\\%I64u_%s_%I64d.frame",
                                   InpManifestSha256,pass,safe,identifier);
      bool conflict=false;
      if(FileIsExist(filename,FILE_COMMON))
        {
         int existing=FileOpen(filename,FILE_READ|FILE_BIN|FILE_COMMON);
         if(existing==INVALID_HANDLE || FileSize(existing)!=(ulong)ArraySize(data))
            conflict=true;
         else
           {
            uchar prior[];
            ArrayResize(prior,ArraySize(data));
            if(FileReadArray(existing,prior,0,ArraySize(prior))!=(uint)ArraySize(prior))
               conflict=true;
            else
               for(int i=0;i<ArraySize(prior);i++)
                  if(prior[i]!=data[i]) { conflict=true; break; }
           }
         if(existing!=INVALID_HANDLE) FileClose(existing);
        }
      else
        {
         int output=FileOpen(filename,FILE_WRITE|FILE_BIN|FILE_COMMON);
         if(output==INVALID_HANDLE ||
            FileWriteArray(output,data,0,ArraySize(data))!=(uint)ArraySize(data))
            conflict=true;
         if(output!=INVALID_HANDLE) { FileFlush(output); FileClose(output); }
        }
      if(conflict)
         g_hard_failures++;
      PrintFormat("KINGEA_STAGE14_FRAME: pass=%I64u name=%s id=%I64d bytes=%d sha256=%s persisted=%s",
                  pass,name,identifier,ArraySize(data),ResearchSha256Bytes(data),
                  conflict ? "FAIL" : "PASS");
     }
  }

void OnTesterPass()
  {
   ResearchDrainFrames();
  }

void OnTesterDeinit()
  {
   // Drain frames that MT5 delivers after the last OnTesterPass callback.
   ResearchDrainFrames();
  }
