#property copyright "KingEA"
#property version   "2.00"
#property description "KingEA Sleeve 1 (CAND-ETH-ST-001) on ETHUSD.s M30."
#property description "Plain native EA for Strategy Tester and demo research. Not a live build."
#property tester_file "KingEA\\protection_intervals.csv"

// Reuses the pure strategy, regime and safety modules unchanged. Everything
// in this file is plumbing: bars, spreads, calendar gates, orders and results.

#include <Trade/Trade.mqh>
#include <KingEA/SleeveEthSt001.mqh>
#include <KingEA/SafetyKernel.mqh>
#include <KingEA/ResearchExecution.mqh>

#define KINGEA_WINDOW_BARS      4600
#define KINGEA_M30              1800
#define KINGEA_H4               14400
#define KINGEA_SPREAD_DAYS      90
#define KINGEA_SPREAD_MIN_MATCH 8

enum KingEACriterion
  {
   CRITERION_COMPOSITE=0,      // Bounded composite (design plan 13.4)
   CRITERION_PROFIT_FACTOR=1,  // Profit factor
   CRITERION_EXPECTANCY_R=2,   // Mean net R per trade
   CRITERION_NET_PROFIT=3      // Net profit (diagnostic only)
  };

input group "Strategy (CAND-ETH-ST-001 grid)"
input int    InpConfigurationId=-1;        // >=0 decodes the 19,440-point grid and overrides below
input int    InpAtrPeriod=14;              // ATR period: 10,14,18,22
input double InpSupertrendMultiplier=3.0;  // Supertrend multiplier: 2.0-4.0 step 0.5
input int    InpBreakoutLookback=12;       // Breakout lookback bars: 6,12,18,24
input double InpEntryBufferAtr=0.1;        // Entry buffer (ATR): 0,0.1,0.2
input double InpStopBufferAtr=0.25;        // Stop buffer (ATR): 0,0.25,0.5
input int    InpProgressCheckpointBars=12; // Progress checkpoint bars: 8,12,16
input double InpRequiredProgressR=0.5;     // Required progress (R): 0.25,0.5,0.75
input int    InpMaximumHoldingBars=72;     // Maximum holding bars: 48,72,96

input group "Evaluation window"
input datetime InpEvalStart=0;             // No entries before this time (0 = test start)
input datetime InpEvalEnd=0;               // Flatten and stop at this time (0 = test end)

input group "Risk and cost stress"
input double InpRiskPercent=1.10;          // Normal risk tier, % of equity
input double InpWeekendRiskMultiplier=0.50;
input double InpCommissionPerLotStress=0.0;// Extra round-turn cost per lot used for sizing
input double InpSlippageSpreadFraction=0.0;// Extra slippage (fraction of spread) used for sizing
input bool   InpApplyBreakers=true;       // false = measure raw signal edge (development only)

input group "Data and market gates"
input bool   InpFillDataGaps=true;         // Fill missing M30 slots with flat bars
input string InpProtectionFile="KingEA\\protection_intervals.csv";
input bool   InpRequireProtectionFile=false;
input int    InpSpreadSeedDays=90;         // Days of tick history used to seed spread baselines

input group "Output"
input KingEACriterion InpCriterion=CRITERION_COMPOSITE;
input string InpRunLabel="default";        // Common\Files\KingEA\results\<label>\
input bool   InpWriteOptimizationRows=false;
input ulong  InpMagic=12001;

struct KingEATrade
  {
   ulong    position_id;
   datetime entry_time;
   datetime exit_time;
   int      direction;
   double   entry_price;
   double   exit_price;
   double   stop;
   double   entry_equity;
   double   risk_money;
   double   net;
   double   r;
   string   exit_reason;
  };

CTrade g_trade;
KingEACandidateParameters g_parameters={};
KingEARegimeHysteresis g_regime_state={};
KingEASleeveState g_sleeve_state={};
KingEASafetyState g_safety_state={};
KingEASleevePositionContext g_position={};
ulong    g_position_ticket=0;
ulong    g_position_id=0;
double   g_entry_equity=0.0;
datetime g_entry_time=0;
double   g_risk_money=0.0;
bool     g_spread_reduced=false;
string   g_close_reason="";
datetime g_last_bar=0;
datetime g_last_closed_bar=0;
bool     g_eval_done=false;
bool     g_halted=false;
string   g_halt_reason="";

KingEATrade g_trades[];

// Equity periods.
double   g_initial_equity=0.0;
double   g_equity_high=0.0;
double   g_max_drawdown=0.0;
double   g_day_open=0.0,g_week_open=0.0,g_month_open=0.0;
datetime g_day_start=0,g_week_start=0,g_month_start=0;
datetime g_first_time=0,g_last_time=0;

// Spread baseline: per-M30 median spreads and the current bucket's spreads.
datetime g_slot_time[];
double   g_slot_median[];
double   g_bucket_spreads[];
datetime g_bucket=0;
datetime g_baseline_bucket=0;
double   g_baseline=0.0;
double   g_spread_ratio=0.0;
int      g_above_three_count=0;
long     g_above_three_start_msc=0;

// Protection calendar.
long     g_iv_start[],g_iv_end[],g_iv_prefix[];
string   g_iv_type[];
bool     g_iv_loaded=false;
KingEAResearchMarketIntervalSnapshot g_iv_snapshot={};

// Funnel diagnostics: why bars did or did not become trades.
int      g_bars_evaluated=0;
int      g_gap_events=0,g_gap_slots=0;
int      g_regime_reasons[32];
int      g_sleeve_reasons[32];
int      g_safety_reasons[32];
int      g_entry_signals=0,g_entries=0,g_order_failures=0,g_stop_too_close=0;
int      g_before_window=0;

string ConfigurationTag()
  {
   return StringFormat("A%d_M%.1f_L%d_E%.2f_S%.2f_C%d_P%.2f_H%d",
                       g_parameters.atr_period,g_parameters.supertrend_multiplier,
                       g_parameters.breakout_lookback_bars,g_parameters.entry_buffer_atr,
                       g_parameters.stop_buffer_atr,g_parameters.progress_checkpoint_bars,
                       g_parameters.required_progress_r,g_parameters.maximum_holding_bars);
  }

//--- Bars -------------------------------------------------------------------

void AddBar(KingEASleeveBar &bars[],const datetime t,const double o,
            const double h,const double l,const double c)
  {
   int n=ArraySize(bars);
   ArrayResize(bars,n+1,KINGEA_WINDOW_BARS+1024);
   bars[n].open_time=t;
   bars[n].open=o;
   bars[n].high=h;
   bars[n].low=l;
   bars[n].close=c;
   bars[n].complete=true;
  }

// Closed M30 bars, contiguous and starting on an H4 boundary. The sleeve and
// regime modules reject any non-contiguous window, and the sleeve's H4
// derivation requires an H4-aligned first bar. Broker quote gaps are filled
// with flat bars at the previous close so a gap cannot disable the strategy
// for the following 90 days.
bool LoadWindow(KingEASleeveBar &bars[])
  {
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied=CopyRates(_Symbol,PERIOD_M30,1,KINGEA_WINDOW_BARS,rates);
   if(copied<=0)
      return false;
   KingEASleeveBar raw[];
   ArrayResize(raw,0,copied+1024);
   for(int i=0;i<copied;i++)
     {
      int n=ArraySize(raw);
      if(n>0 && InpFillDataGaps)
        {
         double previous_close=raw[n-1].close;
         for(datetime t=raw[n-1].open_time+KINGEA_M30;t<rates[i].time;t+=KINGEA_M30)
            AddBar(raw,t,previous_close,previous_close,previous_close,previous_close);
        }
      AddBar(raw,rates[i].time,rates[i].open,rates[i].high,rates[i].low,rates[i].close);
     }
   int count=ArraySize(raw);
   int start=MathMax(0,count-KINGEA_WINDOW_BARS);
   while(start<count && ((long)raw[start].open_time%KINGEA_H4)!=0)
      start++;
   ArrayResize(bars,count-start);
   for(int i=start;i<count;i++)
      bars[i-start]=raw[i];
   return ArraySize(bars)>0;
  }

//--- Spread baseline --------------------------------------------------------

double Median(double &values[])
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

void StoreSlot(const datetime open_time,double &spreads[])
  {
   if(ArraySize(spreads)==0)
      return;
   int n=ArraySize(g_slot_time);
   ArrayResize(g_slot_time,n+1,4096);
   ArrayResize(g_slot_median,n+1,4096);
   g_slot_time[n]=open_time;
   g_slot_median[n]=Median(spreads);
   datetime cutoff=open_time-KINGEA_SPREAD_DAYS*86400;
   int first=0;
   while(first<ArraySize(g_slot_time) && g_slot_time[first]<cutoff)
      first++;
   if(first>0)
     {
      ArrayRemove(g_slot_time,0,first);
      ArrayRemove(g_slot_median,0,first);
     }
  }

// Median of the same weekday/hour/minute slot over the prior 90 days.
double SpreadBaseline(const datetime bucket)
  {
   if(bucket==g_baseline_bucket)
      return g_baseline;
   MqlDateTime now={};
   TimeToStruct(bucket,now);
   double matches[];
   datetime cutoff=bucket-KINGEA_SPREAD_DAYS*86400;
   for(int i=0;i<ArraySize(g_slot_time);i++)
     {
      if(g_slot_time[i]<cutoff || g_slot_time[i]>=bucket)
         continue;
      MqlDateTime prior={};
      TimeToStruct(g_slot_time[i],prior);
      if(prior.day_of_week==now.day_of_week && prior.hour==now.hour &&
         prior.min==now.min)
        {
         int n=ArraySize(matches);
         ArrayResize(matches,n+1);
         matches[n]=g_slot_median[i];
        }
     }
   g_baseline_bucket=bucket;
   g_baseline=(ArraySize(matches)>=KINGEA_SPREAD_MIN_MATCH ? Median(matches) : 0.0);
   return g_baseline;
  }

// Seeds slot medians from the tick history before the first tick so the
// spread gate does not block every entry for the first eight weeks.
void SeedSpreadHistory(const datetime now)
  {
   if(InpSpreadSeedDays<=0)
      return;
   datetime end=(datetime)((long)now/KINGEA_M30*KINGEA_M30);
   datetime from=end-(datetime)MathMin(InpSpreadSeedDays,KINGEA_SPREAD_DAYS)*86400;
   MqlTick ticks[];
   double spreads[];
   datetime current=0;
   for(datetime day=from;day<end;day+=86400)
     {
      datetime until=(datetime)MathMin((long)day+86400,(long)end);
      int copied=CopyTicksRange(_Symbol,ticks,COPY_TICKS_INFO,
                                (ulong)day*1000,(ulong)until*1000-1);
      for(int i=0;i<copied;i++)
        {
         if(ticks[i].bid<=0.0 || ticks[i].ask<=0.0)
            continue;
         datetime bucket=(datetime)((long)ticks[i].time/KINGEA_M30*KINGEA_M30);
         if(bucket!=current)
           {
            if(current>0)
               StoreSlot(current,spreads);
            ArrayResize(spreads,0,16384);
            current=bucket;
           }
         int n=ArraySize(spreads);
         ArrayResize(spreads,n+1,16384);
         spreads[n]=ticks[i].ask-ticks[i].bid;
        }
     }
   if(current>0)
      StoreSlot(current,spreads);
   PrintFormat("KingEA: seeded %d spread slots from %d days of tick history",
               ArraySize(g_slot_time),InpSpreadSeedDays);
  }

void TrackSpread(const MqlTick &tick)
  {
   datetime bucket=(datetime)((long)tick.time/KINGEA_M30*KINGEA_M30);
   if(bucket!=g_bucket)
     {
      if(g_bucket>0)
         StoreSlot(g_bucket,g_bucket_spreads);
      ArrayResize(g_bucket_spreads,0,16384);
      g_bucket=bucket;
     }
   double spread=tick.ask-tick.bid;
   if(KingEAResearchObservedSpreadValid(spread))
     {
      int n=ArraySize(g_bucket_spreads);
      ArrayResize(g_bucket_spreads,n+1,16384);
      g_bucket_spreads[n]=spread;
     }
   double baseline=SpreadBaseline(bucket);
   g_spread_ratio=(baseline>0.0 && spread>=0.0 ? spread/baseline : 0.0);
   if(g_spread_ratio>KINGEA_FLATTEN_SPREAD_RATIO)
     {
      if(g_above_three_count==0)
         g_above_three_start_msc=tick.time_msc;
      g_above_three_count++;
     }
   else
     {
      g_above_three_count=0;
      g_above_three_start_msc=0;
     }
  }

//--- Protection calendar ----------------------------------------------------

bool LoadProtectionIntervals()
  {
   ArrayResize(g_iv_start,0);
   ArrayResize(g_iv_end,0);
   ArrayResize(g_iv_prefix,0);
   ArrayResize(g_iv_type,0);
   int handle=FileOpen(InpProtectionFile,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE)
      return false;
   uchar bytes[];
   FileReadArray(handle,bytes,0,(int)FileSize(handle));
   FileClose(handle);
   string text=CharArrayToString(bytes,0,ArraySize(bytes),CP_UTF8);
   if(StringLen(text)>0 && StringGetCharacter(text,0)==0xFEFF)
      text=StringSubstr(text,1);
   StringReplace(text,"\r","");
   string lines[];
   int count=StringSplit(text,'\n',lines);
   if(count<2 || lines[0]!="type,start_msc,end_msc,identity")
      return false;
   for(int line=1;line<count;line++)
     {
      if(lines[line]=="")
         continue;
      string fields[];
      if(StringSplit(lines[line],',',fields)!=4)
         return false;
      string kind="";
      bool blocks_entry=false;
      long start=StringToInteger(fields[1]);
      long end=StringToInteger(fields[2]);
      if(!KingEAResearchNormalizeProtectionType(fields[0],kind,blocks_entry) ||
         start<=0 || end<=start)
         return false;
      if(!blocks_entry)
         continue;
      int n=ArraySize(g_iv_start);
      if(n>0 && start<g_iv_start[n-1])
         return false;
      ArrayResize(g_iv_start,n+1,8192);
      ArrayResize(g_iv_end,n+1,8192);
      ArrayResize(g_iv_prefix,n+1,8192);
      ArrayResize(g_iv_type,n+1,8192);
      g_iv_start[n]=start;
      g_iv_end[n]=end;
      g_iv_prefix[n]=(n==0 ? end : MathMax(g_iv_prefix[n-1],end));
      g_iv_type[n]=kind;
     }
   return ArraySize(g_iv_start)>0;
  }

// Returns the active protection kind ("" when the market is open).
string MarketBlockKind(const long now_msc)
  {
   if(!g_iv_loaded)
      return "";
   if(!(g_iv_snapshot.healthy && now_msc>=g_iv_snapshot.observed_at_msc &&
        now_msc<g_iv_snapshot.next_change_msc))
      if(!KingEAResearchResolveMarketInterval(g_iv_start,g_iv_end,g_iv_prefix,
                                              g_iv_type,now_msc,g_iv_snapshot))
         return "MARKET_INTERVALS_INVALID";
   return g_iv_snapshot.blocked ? g_iv_snapshot.kind : "";
  }

//--- Equity periods ---------------------------------------------------------

datetime DayStart(const datetime value)
  {
   return (datetime)((long)value/86400*86400);
  }

datetime WeekStart(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   return DayStart(value)-((parts.day_of_week+6)%7)*86400;
  }

datetime MonthStart(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   parts.day=1;
   parts.hour=0;
   parts.min=0;
   parts.sec=0;
   return StructToTime(parts);
  }

//--- Positions --------------------------------------------------------------

bool SelectOurPosition()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
         return true;
     }
   return false;
  }

bool HasPosition()
  {
   return g_position.has_position;
  }

bool ProtectedForNews()
  {
   if(!g_position.has_position || !SelectOurPosition())
      return false;
   double volume=PositionGetDouble(POSITION_VOLUME);
   double spread=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-
                  SymbolInfoDouble(_Symbol,SYMBOL_BID))*3.0;
   double stop=g_position.original_confirmed_stop;
   double worst=(g_position.direction==KINGEA_DIRECTION_LONG ?
                 stop-spread*(1.0+InpSlippageSpreadFraction) :
                 stop+spread*(1.0+InpSlippageSpreadFraction));
   double profit=0.0;
   ENUM_ORDER_TYPE type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                         ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,_Symbol,volume,g_position.entry_price,worst,profit))
      return false;
   return profit-InpCommissionPerLotStress*volume>0.0;
  }

void BuildFacts(const datetime now,const double entry,const double stop,
                const int direction,const bool for_entry,KingEASafetyFacts &facts)
  {
   ZeroMemory(facts);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   facts.now_server=now;
   // With breakers off, every period baseline is the current equity: sizing
   // stays risk-based but no drawdown breaker can pause or starve entries.
   bool breakers=InpApplyBreakers;
   facts.account_equity=equity;
   facts.account_day_open_equity=(breakers ? g_day_open : equity);
   facts.account_week_open_equity=(breakers ? g_week_open : equity);
   facts.account_month_open_equity=(breakers ? g_month_open : equity);
   facts.account_equity_high=(breakers ? g_equity_high : equity);
   facts.sleeve_equity=equity;
   facts.sleeve_week_open_equity=(breakers ? g_week_open : equity);
   facts.sleeve_month_open_equity=(breakers ? g_month_open : equity);
   facts.sleeve_equity_high=(breakers ? g_equity_high : equity);
   MqlDateTime parts={};
   TimeToStruct(now,parts);
   bool weekend=(parts.day_of_week==0 || parts.day_of_week==6);
   facts.sleeve_tier_percent=InpRiskPercent*(weekend ? InpWeekendRiskMultiplier : 1.0);
   facts.cluster_known=true;
   facts.volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   facts.volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   facts.volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   facts.current_used_margin=AccountInfoDouble(ACCOUNT_MARGIN);
   if(for_entry)
     {
      ENUM_ORDER_TYPE type=(direction==KINGEA_DIRECTION_LONG ?
                            ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double loss=0.0,margin=0.0;
      if(!OrderCalcProfit(type,_Symbol,1.0,entry,stop,loss))
         loss=0.0;
      if(!OrderCalcMargin(type,_Symbol,1.0,entry,margin))
         margin=0.0;
      double spread=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
      double slippage_cost=(tick_size>0.0 ?
                            spread*InpSlippageSpreadFraction/tick_size*tick_value : 0.0);
      facts.stressed_loss_per_lot=MathAbs(loss)+InpCommissionPerLotStress+slippage_cost;
      facts.live_margin_per_lot=margin;
      facts.notional_per_lot=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)*entry;
     }
   // An unknown baseline blocks entries but never forces a reduction.
   facts.spread_ratio=(for_entry && g_spread_ratio<=0.0 ? 999.0 : g_spread_ratio);
   facts.spread_above_three_persistent=
      (g_above_three_count>=3 &&
       SymbolInfoInteger(_Symbol,SYMBOL_TIME_MSC)-g_above_three_start_msc>=10000);
   string kind=MarketBlockKind((long)now*1000);
   facts.market_open=(kind=="");
   facts.maintenance_block=(kind=="MAINTENANCE_FORCE_FLAT");
   facts.news_block=(kind=="NEWS_BLOCK");
   facts.existing_news_position_safe=(facts.news_block && ProtectedForNews());
   facts.calendar_fresh=(g_iv_loaded || !InpRequireProtectionFile);
   facts.stop_valid=true;
   facts.state_valid=true;
   facts.configuration_valid=true;
   facts.exposure_reconciled=true;
   facts.stops_confirmed=true;
   facts.connection_healthy=true;
   facts.specification_healthy=true;
   facts.external_cash_flow_reconciled=true;
  }

void Halt(const string reason)
  {
   if(g_halted)
      return;
   g_halted=true;
   g_halt_reason=reason;
   PrintFormat("KingEA: trading halted at %s (%s)",TimeToString(TimeCurrent()),reason);
  }

void UpdatePeriods(const datetime now)
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_equity_high=MathMax(g_equity_high,equity);
   if(g_equity_high>0.0)
      g_max_drawdown=MathMax(g_max_drawdown,(g_equity_high-equity)/g_equity_high);
   datetime day=DayStart(now);
   if(day==g_day_start)
      return;
   datetime week=WeekStart(now);
   datetime month=MonthStart(now);
   bool new_day=(g_day_start>0);
   bool new_week=(g_week_start>0 && week!=g_week_start);
   bool new_month=(g_month_start>0 && month!=g_month_start);
   g_day_start=day;
   g_day_open=equity;
   if(week!=g_week_start) { g_week_start=week; g_week_open=equity; }
   if(month!=g_month_start) { g_month_start=month; g_month_open=equity; }
   if(!new_day)
      return;
   KingEASafetyFacts facts={};
   BuildFacts(now,0.0,0.0,KINGEA_DIRECTION_LONG,false,facts);
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
      Halt("SAFETY_QUARANTINE_AT_PERIOD_TRANSITION");
  }

void CountReason(int &counts[],const int reason)
  {
   if(reason>=0 && reason<ArraySize(counts))
      counts[reason]++;
  }

//--- Trade lifecycle --------------------------------------------------------

string DealReasonText(const long reason)
  {
   if(reason==DEAL_REASON_SL)     return "STOP_LOSS";
   if(reason==DEAL_REASON_TP)     return "TAKE_PROFIT";
   if(reason==DEAL_REASON_SO)     return "STOP_OUT";
   if(reason==DEAL_REASON_EXPERT) return "EXPERT";
   return "OTHER_"+(string)reason;
  }

// Net result of a position from its deals: profit, swap, commission and fee.
double PositionNet(const ulong position_id,double &exit_price,datetime &exit_time,
                   long &last_reason)
  {
   double net=0.0;
   exit_price=0.0;
   exit_time=0;
   last_reason=-1;
   if(!HistorySelectByPosition(position_id))
      return 0.0;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0)
         continue;
      net+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+
           HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_FEE);
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
        {
         exit_price=HistoryDealGetDouble(deal,DEAL_PRICE);
         exit_time=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
         last_reason=HistoryDealGetInteger(deal,DEAL_REASON);
        }
     }
   return net;
  }

void RecordTrade(const double net,const double exit_price,const datetime exit_time,
                 const string reason)
  {
   int n=ArraySize(g_trades);
   ArrayResize(g_trades,n+1,256);
   g_trades[n].position_id=g_position_id;
   g_trades[n].entry_time=g_entry_time;
   g_trades[n].exit_time=exit_time;
   g_trades[n].direction=g_position.direction;
   g_trades[n].entry_price=g_position.entry_price;
   g_trades[n].exit_price=exit_price;
   g_trades[n].stop=g_position.original_confirmed_stop;
   g_trades[n].entry_equity=g_entry_equity;
   g_trades[n].risk_money=g_risk_money;
   g_trades[n].net=net;
   g_trades[n].r=(g_risk_money>0.0 ? net/g_risk_money : 0.0);
   g_trades[n].exit_reason=reason;
  }

void ResetPosition()
  {
   ZeroMemory(g_position);
   g_position_ticket=0;
   g_position_id=0;
   g_entry_equity=0.0;
   g_entry_time=0;
   g_risk_money=0.0;
   g_spread_reduced=false;
   g_close_reason="";
  }

// Detects a position that has closed (our exit, broker stop, or stop-out),
// records it and tells the safety kernel about the closed trade group.
void SyncClosedPosition()
  {
   if(!g_position.has_position || SelectOurPosition())
      return;
   double exit_price=0.0;
   datetime exit_time=0;
   long deal_reason=-1;
   double net=PositionNet(g_position_id,exit_price,exit_time,deal_reason);
   string reason=(deal_reason==DEAL_REASON_EXPERT && g_close_reason!="" ?
                  g_close_reason : DealReasonText(deal_reason));
   RecordTrade(net,exit_price,exit_time,reason);
   double r=g_trades[ArraySize(g_trades)-1].r;
   KingEASafetyFacts facts={};
   BuildFacts(TimeCurrent(),0.0,0.0,g_position.direction,false,facts);
   KingEASafetyRequest closed={};
   closed.event=KINGEA_EVENT_CLOSED_TRADE_GROUP;
   closed.scope=KINGEA_SCOPE_SLEEVE;
   closed.closed_group_full_loss=InpApplyBreakers && (r<=-0.80 || deal_reason==DEAL_REASON_SL);
   KingEASafetyDecision decision={};
   KingEAEvaluateSafety(closed,facts,g_safety_state,decision);
   g_safety_state=decision.next_state;
   if(decision.action==KINGEA_ACTION_FLATTEN || decision.action==KINGEA_ACTION_QUARANTINE)
      Halt("SAFETY_THROTTLE_REVIEW");
   ResetPosition();
  }

void ClosePosition(const string reason)
  {
   if(!g_position.has_position || !SelectOurPosition())
      return;
   g_close_reason=reason;
   if(!g_trade.PositionClose(PositionGetInteger(POSITION_TICKET)))
      PrintFormat("KingEA: close failed (%s) retcode=%u",reason,g_trade.ResultRetcode());
   SyncClosedPosition();
  }

void ReducePosition(const double volume)
  {
   if(!SelectOurPosition())
      return;
   if(g_trade.PositionClosePartial(PositionGetInteger(POSITION_TICKET),volume))
      g_spread_reduced=true;
  }

void ReviewPosition()
  {
   if(!g_position.has_position || !SelectOurPosition())
      return;
   KingEASafetyFacts facts={};
   BuildFacts(TimeCurrent(),0.0,0.0,g_position.direction,false,facts);
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_POSITION_REVIEW;
   request.scope=KINGEA_SCOPE_SLEEVE;
   request.direction=(g_position.direction==KINGEA_DIRECTION_LONG ?
                      KINGEA_SAFETY_LONG : KINGEA_SAFETY_SHORT);
   request.position_present=true;
   request.position_volume=PositionGetDouble(POSITION_VOLUME);
   request.current_stop=PositionGetDouble(POSITION_SL);
   KingEASafetyDecision decision={};
   KingEAEvaluateSafety(request,facts,g_safety_state,decision);
   g_safety_state=decision.next_state;
   if(decision.action==KINGEA_ACTION_FLATTEN || decision.action==KINGEA_ACTION_QUARANTINE)
     {
      string reason="SAFETY_"+EnumToString(decision.reason);
      if(decision.reason==KINGEA_REASON_GATE_BLOCK && facts.maintenance_block)
         reason="MAINTENANCE_FLAT";
      else if(decision.reason==KINGEA_REASON_GATE_BLOCK && facts.news_block)
         reason="NEWS_FLAT";
      else if(decision.reason==KINGEA_REASON_SPREAD_FLATTEN)
         reason="SPREAD_FLAT";
      ClosePosition(reason);
      if(decision.quarantine)
         Halt(reason);
     }
   else if(decision.action==KINGEA_ACTION_REDUCE_POSITION && !g_spread_reduced)
      ReducePosition(decision.permitted_volume);
  }

void TryOpen(const KingEASleeveDecision &intent,const MqlTick &tick)
  {
   g_entry_signals++;
   double entry=(intent.direction==KINGEA_DIRECTION_LONG ? tick.ask : tick.bid);
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_ENTRY;
   request.scope=KINGEA_SCOPE_SLEEVE;
   request.direction=(intent.direction==KINGEA_DIRECTION_LONG ?
                      KINGEA_SAFETY_LONG : KINGEA_SAFETY_SHORT);
   request.entry_price=entry;
   request.technical_stop=intent.technical_stop;
   request.signal_present=true;
   KingEASafetyFacts facts={};
   BuildFacts(tick.time,entry,intent.technical_stop,intent.direction,true,facts);
   KingEASafetyDecision safety={};
   KingEAEvaluateSafety(request,facts,g_safety_state,safety);
   g_safety_state=safety.next_state;
   CountReason(g_safety_reasons,(int)safety.reason);
   if(safety.action==KINGEA_ACTION_QUARANTINE)
      Halt("SAFETY_"+EnumToString(safety.reason));
   if(safety.action!=KINGEA_ACTION_APPROVE_ENTRY &&
      safety.action!=KINGEA_ACTION_DOWNSIZE_ENTRY)
      return;

   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double stop=NormalizeDouble(safety.required_stop,digits);
   double stops_level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(MathAbs(entry-stop)<=stops_level)
     {
      g_stop_too_close++;
      return;
     }
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   int volume_digits=(int)MathMax(0.0,MathCeil(-MathLog10(step)-1e-9));
   double volume=NormalizeDouble(safety.permitted_volume,volume_digits);
   double equity_before=AccountInfoDouble(ACCOUNT_EQUITY);
   string comment="KINGEA|"+intent.signal_identity;
   bool sent=(intent.direction==KINGEA_DIRECTION_LONG ?
              g_trade.Buy(volume,_Symbol,0.0,stop,0.0,comment) :
              g_trade.Sell(volume,_Symbol,0.0,stop,0.0,comment));
   if(!sent || g_trade.ResultRetcode()!=TRADE_RETCODE_DONE || !SelectOurPosition())
     {
      g_order_failures++;
      PrintFormat("KingEA: entry failed retcode=%u %s",g_trade.ResultRetcode(),
                  g_trade.ResultRetcodeDescription());
      return;
     }
   g_position.has_position=true;
   g_position.direction=intent.direction;
   g_position.entry_signal_bar_time=intent.signal_bar_time;
   g_position.entry_price=PositionGetDouble(POSITION_PRICE_OPEN);
   g_position.original_confirmed_stop=PositionGetDouble(POSITION_SL);
   g_position.original_stop_confirmed=(g_position.original_confirmed_stop>0.0);
   g_position_ticket=(ulong)PositionGetInteger(POSITION_TICKET);
   g_position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   g_entry_equity=equity_before;
   g_entry_time=(datetime)PositionGetInteger(POSITION_TIME);
   g_risk_money=safety.permitted_risk_money;
   g_spread_reduced=false;
   g_entries++;
   if(!g_position.original_stop_confirmed)
      ClosePosition("STOP_NOT_CONFIRMED");
  }

void OnNewBar(const MqlTick &tick)
  {
   KingEASleeveBar bars[];
   if(!LoadWindow(bars))
      return;
   datetime last_closed=bars[ArraySize(bars)-1].open_time;
   MqlRates newest[];
   if(CopyRates(_Symbol,PERIOD_M30,1,1,newest)==1 && g_last_closed_bar>0 &&
      newest[0].time-g_last_closed_bar>KINGEA_M30)
     {
      g_gap_events++;
      g_gap_slots+=(int)((newest[0].time-g_last_closed_bar)/KINGEA_M30)-1;
     }
   g_last_closed_bar=last_closed;
   g_bars_evaluated++;

   int count=ArraySize(bars);
   KingEARegimeBar regime_bars[];
   ArrayResize(regime_bars,count);
   for(int i=0;i<count;i++)
     {
      regime_bars[i].open_time=bars[i].open_time;
      regime_bars[i].open=bars[i].open;
      regime_bars[i].high=bars[i].high;
      regime_bars[i].low=bars[i].low;
      regime_bars[i].close=bars[i].close;
      regime_bars[i].complete=true;
     }
   KingEARegimeRequest regime_request={};
   regime_request.evaluation_time=tick.time;
   regime_request.expected_open_slots=4320;
   regime_request.maximum_staleness_seconds=KINGEA_M30;
   KingEARegimeDecision regime={};
   KingEAEvaluateRegime(regime_bars,regime_request,g_regime_state,regime);
   g_regime_state=regime.next_state;
   CountReason(g_regime_reasons,(int)regime.reason);

   KingEASleeveRequest request={};
   request.evaluation_time=tick.time;
   request.parameters=g_parameters;
   request.regime=regime;
   request.position=g_position;
   request.has_open_trade_group=HasPosition();
   KingEASleeveDecision intent={};
   KingEAEvaluateSleeveEthSt001(bars,request,g_sleeve_state,intent);
   g_sleeve_state=intent.next_state;
   CountReason(g_sleeve_reasons,(int)intent.reason);

   if(intent.action==KINGEA_SLEEVE_ACTION_EXIT && HasPosition())
     {
      ClosePosition("STRATEGY_"+intent.candidate_reason);
      return;
     }
   if(intent.action!=KINGEA_SLEEVE_ACTION_ENTRY || HasPosition() ||
      g_halted || g_eval_done)
      return;
   if(InpEvalStart>0 && tick.time<InpEvalStart)
     {
      g_before_window++;
      return;
     }
   TryOpen(intent,tick);
  }

//--- Results ----------------------------------------------------------------

struct KingEAStats
  {
   int    trades;
   double net;
   double gross_win;
   double gross_loss;
   double profit_factor;
   double mean_r;
   double sd_r;
   double lcb_r;
   double downside_r;
   double sortino;
   double max_drawdown;
   double cagr;
   double mar;
   double win_rate;
   double composite;
  };

double Clamp01(const double value)
  {
   return MathMax(0.0,MathMin(1.0,value));
  }

void ComputeStats(KingEAStats &stats)
  {
   ZeroMemory(stats);
   int n=ArraySize(g_trades);
   stats.trades=n;
   double sum_r=0.0,sum_r2=0.0,down2=0.0;
   int wins=0;
   for(int i=0;i<n;i++)
     {
      stats.net+=g_trades[i].net;
      if(g_trades[i].net>0.0) { stats.gross_win+=g_trades[i].net; wins++; }
      else stats.gross_loss-=g_trades[i].net;
      sum_r+=g_trades[i].r;
      sum_r2+=g_trades[i].r*g_trades[i].r;
      if(g_trades[i].r<0.0)
         down2+=g_trades[i].r*g_trades[i].r;
     }
   stats.profit_factor=(stats.gross_loss>0.0 ? stats.gross_win/stats.gross_loss :
                        (stats.gross_win>0.0 ? 99.0 : 0.0));
   if(n>0)
     {
      stats.win_rate=(double)wins/n;
      stats.mean_r=sum_r/n;
      stats.downside_r=MathSqrt(down2/n);
      stats.sortino=(stats.downside_r>0.0 ? stats.mean_r/stats.downside_r : 0.0);
     }
   if(n>1)
     {
      stats.sd_r=MathSqrt(MathMax(0.0,(sum_r2-n*stats.mean_r*stats.mean_r)/(n-1)));
      stats.lcb_r=stats.mean_r-1.96*stats.sd_r/MathSqrt(n);
     }
   stats.max_drawdown=g_max_drawdown;
   double years=(double)(g_last_time-g_first_time)/(365.25*86400.0);
   double final_equity=g_initial_equity+stats.net;
   if(years>0.0 && g_initial_equity>0.0 && final_equity>0.0)
      stats.cagr=MathPow(final_equity/g_initial_equity,1.0/years)-1.0;
   stats.mar=(stats.max_drawdown>0.0 ? stats.cagr/stats.max_drawdown : 0.0);
   // Bounded in-sample ranking composite. OOS and stress results are gates,
   // never inputs to this number.
   if(n>=10)
      stats.composite=Clamp01(n/150.0)*
                      (Clamp01(stats.mar/3.0)+Clamp01(stats.sortino/3.0)+
                       Clamp01((MathMin(stats.profit_factor,3.0)-1.0)/2.0)+
                       Clamp01(stats.lcb_r/0.5))/4.0;
  }

string ResultsFolder()
  {
   string folder="KingEA\\results\\"+(InpRunLabel=="" ? "default" : InpRunLabel);
   FolderCreate(folder,FILE_COMMON);
   return folder;
  }

void WriteSummaryRow(const string file,const KingEAStats &stats)
  {
   bool exists=FileIsExist(file,FILE_COMMON);
   int handle=FileOpen(file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',');
   if(handle==INVALID_HANDLE)
      return;
   FileSeek(handle,0,SEEK_END);
   if(!exists)
      FileWrite(handle,"configuration","from","to","trades","net","profit_factor",
                "mean_r","lcb_r","win_rate","max_drawdown","cagr","mar","sortino",
                "composite","gap_events","gap_slots","breakers","halted");
   FileWrite(handle,ConfigurationTag(),TimeToString(g_first_time),TimeToString(g_last_time),
             stats.trades,DoubleToString(stats.net,2),DoubleToString(stats.profit_factor,4),
             DoubleToString(stats.mean_r,4),DoubleToString(stats.lcb_r,4),
             DoubleToString(stats.win_rate,4),DoubleToString(stats.max_drawdown,4),
             DoubleToString(stats.cagr,4),DoubleToString(stats.mar,4),
             DoubleToString(stats.sortino,4),DoubleToString(stats.composite,6),
             g_gap_events,g_gap_slots,(InpApplyBreakers ? "on" : "off"),(g_halted ? g_halt_reason : ""));
   FileClose(handle);
  }

void WriteTrades(const string file)
  {
   int handle=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(handle==INVALID_HANDLE)
      return;
   FileWrite(handle,"position_id","entry_time","exit_time","direction","entry_price",
             "exit_price","stop","entry_equity","risk_money","net","r","exit_reason");
   for(int i=0;i<ArraySize(g_trades);i++)
      FileWrite(handle,g_trades[i].position_id,TimeToString(g_trades[i].entry_time,TIME_DATE|TIME_SECONDS),
                TimeToString(g_trades[i].exit_time,TIME_DATE|TIME_SECONDS),
                (g_trades[i].direction==KINGEA_DIRECTION_LONG ? "LONG" : "SHORT"),
                DoubleToString(g_trades[i].entry_price,_Digits),
                DoubleToString(g_trades[i].exit_price,_Digits),
                DoubleToString(g_trades[i].stop,_Digits),
                DoubleToString(g_trades[i].entry_equity,2),
                DoubleToString(g_trades[i].risk_money,2),
                DoubleToString(g_trades[i].net,2),DoubleToString(g_trades[i].r,4),
                g_trades[i].exit_reason);
   FileClose(handle);
  }

void PrintFunnel()
  {
   string regime="",sleeve="",safety="";
   for(int i=0;i<32;i++)
     {
      if(g_regime_reasons[i]>0) regime+=StringFormat(" %s=%d",EnumToString((KingEARegimeReason)i),g_regime_reasons[i]);
      if(g_sleeve_reasons[i]>0) sleeve+=StringFormat(" %s=%d",EnumToString((KingEASleeveReason)i),g_sleeve_reasons[i]);
      if(g_safety_reasons[i]>0) safety+=StringFormat(" %s=%d",EnumToString((KingEASafetyReason)i),g_safety_reasons[i]);
     }
   PrintFormat("KingEA funnel: bars=%d gap_events=%d gap_slots=%d signals=%d before_window=%d entries=%d order_failures=%d stop_too_close=%d trades=%d halted=%s",
               g_bars_evaluated,g_gap_events,g_gap_slots,g_entry_signals,g_before_window,
               g_entries,g_order_failures,g_stop_too_close,ArraySize(g_trades),
               (g_halted ? g_halt_reason : "no"));
   Print("KingEA regime:",regime);
   Print("KingEA sleeve:",sleeve);
   Print("KingEA safety:",safety);
  }

//--- Event handlers ---------------------------------------------------------

int OnInit()
  {
   if(InpConfigurationId>=0)
     {
      if(!KingEAResearchDecodeConfiguration(InpConfigurationId,g_parameters))
         return INIT_PARAMETERS_INCORRECT;
     }
   else
     {
      g_parameters.atr_period=InpAtrPeriod;
      g_parameters.supertrend_multiplier=InpSupertrendMultiplier;
      g_parameters.breakout_lookback_bars=InpBreakoutLookback;
      g_parameters.entry_buffer_atr=InpEntryBufferAtr;
      g_parameters.stop_buffer_atr=InpStopBufferAtr;
      g_parameters.progress_checkpoint_bars=InpProgressCheckpointBars;
      g_parameters.required_progress_r=InpRequiredProgressR;
      g_parameters.maximum_holding_bars=InpMaximumHoldingBars;
     }
   if(!KingEASleeveFrozenParameters(g_parameters))
     {
      Print("KingEA: parameters are outside the registered CAND-ETH-ST-001 grid");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpEvalEnd>0 && InpEvalStart>=InpEvalEnd)
      return INIT_PARAMETERS_INCORRECT;
   if(SelectOurPosition())
     {
      Print("KingEA: refusing to start with an existing position for this magic number");
      return INIT_FAILED;
     }
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(0);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   g_iv_loaded=LoadProtectionIntervals();
   if(!g_iv_loaded)
     {
      if(InpRequireProtectionFile)
        {
         PrintFormat("KingEA: protection calendar %s missing or invalid",InpProtectionFile);
         return INIT_FAILED;
        }
      PrintFormat("KingEA: WARNING protection calendar %s not loaded; news/maintenance gates are off",
                  InpProtectionFile);
     }
   SeedSpreadHistory(TimeCurrent());
   g_initial_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_equity_high=g_initial_equity;
   if(!InpApplyBreakers)
      Print("KingEA: WARNING breakers disabled; results measure signal edge, not the account");
   PrintFormat("KingEA: %s %s window=[%s, %s)",_Symbol,ConfigurationTag(),
               (InpEvalStart>0 ? TimeToString(InpEvalStart) : "test start"),
               (InpEvalEnd>0 ? TimeToString(InpEvalEnd) : "test end"));
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   MqlTick tick={};
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
      return;
   if(g_first_time==0)
      g_first_time=tick.time;
   g_last_time=tick.time;
   UpdatePeriods(tick.time);
   TrackSpread(tick);
   SyncClosedPosition();

   // End of the evaluation window: close any open exposure at market like any
   // other exit and stop trading. The trade is recorded with reason EVAL_END.
   if(InpEvalEnd>0 && tick.time>=InpEvalEnd && !g_eval_done)
     {
      g_eval_done=true;
      ClosePosition("EVAL_END");
     }
   if(HasPosition())
      ReviewPosition();

   datetime bar=iTime(_Symbol,PERIOD_M30,0);
   if(bar!=g_last_bar)
     {
      bool first=(g_last_bar==0);
      g_last_bar=bar;
      if(!first && !g_eval_done)
         OnNewBar(tick);
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
      SyncClosedPosition();
  }

double OnTester()
  {
   // A position still open when the test stops (no EVAL_END reached) never
   // invalidates the run. The tester force-closes it at the last prices
   // before OnTester; that close is recorded as TEST_END_CLOSE. If the
   // position is somehow still open here, it is marked to market instead.
   if(g_position.has_position && !SelectOurPosition())
     {
      g_close_reason="TEST_END_CLOSE";
      double exit_price=0.0;
      datetime exit_time=0;
      long reason=-1;
      double net=PositionNet(g_position_id,exit_price,exit_time,reason);
      RecordTrade(net,exit_price,exit_time,"TEST_END_CLOSE");
      ResetPosition();
     }
   else if(g_position.has_position)
     {
      double exit_price=0.0;
      datetime exit_time=0;
      long reason=-1;
      double realized=PositionNet(g_position_id,exit_price,exit_time,reason);
      SelectOurPosition();
      double floating=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      double price=PositionGetDouble(POSITION_PRICE_CURRENT);
      RecordTrade(realized+floating,price,TimeCurrent(),"OPEN_AT_TEST_END");
     }
   KingEAStats stats={};
   ComputeStats(stats);
   PrintFunnel();
   PrintFormat("KingEA result: trades=%d net=%.2f pf=%.3f mean_r=%.3f lcb_r=%.3f win=%.1f%% maxdd=%.2f%% cagr=%.2f%% composite=%.4f",
               stats.trades,stats.net,stats.profit_factor,stats.mean_r,stats.lcb_r,
               stats.win_rate*100.0,stats.max_drawdown*100.0,stats.cagr*100.0,stats.composite);
   if(stats.trades==0)
      Print("KingEA WARNING: zero trades. Check the funnel lines above before trusting this pass.");
   bool optimizing=(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(!optimizing || InpWriteOptimizationRows)
     {
      string folder=ResultsFolder();
      WriteSummaryRow(folder+"\\summary.csv",stats);
      if(!optimizing)
         WriteTrades(folder+"\\trades_"+ConfigurationTag()+".csv");
     }
   switch(InpCriterion)
     {
      case CRITERION_PROFIT_FACTOR: return stats.profit_factor;
      case CRITERION_EXPECTANCY_R:  return stats.mean_r;
      case CRITERION_NET_PROFIT:    return stats.net;
      default:                      return stats.composite;
     }
  }
