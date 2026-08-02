#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Deterministic non-trading Stage 11 frozen Sleeve 1 contract tests."
#property description "No broker history, native indicators, performance, optimization, or orders."

#include <KingEA/SleeveEthSt001.mqh>

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

bool Near(const double actual,const double expected,
          const double tolerance=1e-8)
  {
   return MathAbs(actual-expected)<=tolerance;
  }

KingEACandidateParameters DefaultParameters()
  {
   KingEACandidateParameters parameters={};
   parameters.atr_period=14;
   parameters.supertrend_multiplier=3.0;
   parameters.breakout_lookback_bars=12;
   parameters.entry_buffer_atr=0.1;
   parameters.stop_buffer_atr=0.25;
   parameters.progress_checkpoint_bars=12;
   parameters.required_progress_r=0.5;
   parameters.maximum_holding_bars=72;
   return parameters;
  }

void SetAllowedRegime(KingEASleeveRequest &request,
                      const datetime observation_time)
  {
   ZeroMemory(request.regime);
   request.regime.healthy=true;
   request.regime.entry_eligible=true;
   request.regime.trend_state=KINGEA_STAGE10_TREND_TRENDING;
   request.regime.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
   request.regime.next_state.last_observation_time=observation_time;
  }

void BuildUniformTrend(KingEASleeveBar &bars[],const int count,
                       const datetime start,const int direction)
  {
   ArrayResize(bars,count);
   double previous=1000.0;
   for(int i=0;i<count;i++)
     {
      bars[i].open_time=start+(i*KINGEA_SLEEVE_M30_SECONDS);
      bars[i].open=previous;
      bars[i].close=previous+direction;
      bars[i].high=MathMax(bars[i].open,bars[i].close)+0.5;
      bars[i].low=MathMin(bars[i].open,bars[i].close)-0.5;
      bars[i].complete=true;
      previous=bars[i].close;
     }
  }

void BuildContinuation(KingEASleeveBar &bars[],const int direction)
  {
   const int count=200;
   ArrayResize(bars,count);
   double previous=1000.0;
   for(int i=0;i<count;i++)
     {
      double change=direction*0.20;
      if(i>=count-13 && i<count-1)
         change=direction*(i%2==0 ? 0.05 : -0.05);
      if(i==count-1)
         change=direction*5.0;
      bars[i].open_time=D'2026.01.01 00:00:00'+
                        (i*KINGEA_SLEEVE_M30_SECONDS);
      bars[i].open=previous;
      bars[i].close=previous+change;
      bars[i].high=MathMax(bars[i].open,bars[i].close)+0.20;
      bars[i].low=MathMin(bars[i].open,bars[i].close)-0.20;
      bars[i].complete=true;
      previous=bars[i].close;
     }
  }

KingEASleeveRequest RequestFor(const KingEASleeveBar &bars[])
  {
   KingEASleeveRequest request={};
   int last=ArraySize(bars)-1;
   request.evaluation_time=bars[last].open_time+KINGEA_SLEEVE_M30_SECONDS;
   request.parameters=DefaultParameters();
   SetAllowedRegime(request,bars[last].open_time);
   return request;
  }

double ClosedBarMfe(const KingEASleeveBar &bars[],
                    const datetime after_time,
                    const int direction,
                    const double entry,
                    const double original_stop)
  {
   double best=entry;
   for(int i=0;i<ArraySize(bars);i++)
     {
      if(bars[i].open_time<=after_time)
         continue;
      if(direction==KINGEA_DIRECTION_LONG)
         best=MathMax(best,bars[i].high);
      else
         best=MathMin(best,bars[i].low);
     }
   double risk=MathAbs(entry-original_stop);
   return (direction==KINGEA_DIRECTION_LONG ?
           (best-entry)/risk : (entry-best)/risk);
  }

void WriteContractReport(const KingEASleeveDecision &representative)
  {
   string stamp=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   StringReplace(stamp,".","-");
   StringReplace(stamp,":","-");
   StringReplace(stamp," ","_");
   string relative="KingEA\\sleeve_eth_st_001_contract_"+stamp+".csv";
   int handle=FileOpen(relative,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|
                       FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      g_failures++;
      PrintFormat("FAIL: contract report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"key","value");
   FileWrite(handle,"stage","11");
   FileWrite(handle,"scope","DETERMINISTIC_NON_PERFORMANCE_CONTRACT");
   FileWrite(handle,"fixture_identity","KINGEA_STAGE11_SLEEVE_ETH_ST_001_V1");
   FileWrite(handle,"result",(g_failures==0 ? "PASS" : "FAIL"));
   FileWrite(handle,"checks",IntegerToString(g_checks));
   FileWrite(handle,"failures",IntegerToString(g_failures));
   FileWrite(handle,"sample_action",IntegerToString(representative.action));
   FileWrite(handle,"sample_direction",IntegerToString(representative.direction));
   FileWrite(handle,"sample_reason",IntegerToString(representative.reason));
   FileWrite(handle,"sample_signal_identity",representative.signal_identity);
   FileWrite(handle,"sample_m30_atr",DoubleToString(representative.trace.m30_atr,8));
   FileWrite(handle,"sample_h4_direction",
             IntegerToString(representative.trace.h4_supertrend_direction));
   FileWrite(handle,"candidate_budget_consumed","0");
   FileWrite(handle,"order_capability","PROHIBITED_AND_ABSENT");
   FileWrite(handle,"performance_authorization","DENIED");
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA Stage 11 contract report: %s\\Files\\%s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH),relative);
  }

void TestRequestAndGrid()
  {
   KingEASleeveRequest request={};
   KingEASleeveState prior={};
   KingEASleeveDecision decision={};
   KingEASleeveBar bars[];
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_INVALID_REQUEST,
         "empty request fails closed through the public sleeve interface");

   ArrayResize(bars,1);
   bars[0].open_time=D'2026.01.01 00:00:00';
   bars[0].open=100.0;
   bars[0].high=101.0;
   bars[0].low=99.0;
   bars[0].close=100.5;
   bars[0].complete=true;
   request=RequestFor(bars);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_INSUFFICIENT_HISTORY,
         "frozen default parameters are accepted before history is evaluated");
   request.parameters.atr_period=15;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_INVALID_PARAMETERS,
         "off-grid parameters fail closed");
   request.parameters=DefaultParameters();
   request.parameters.supertrend_multiplier=MathSqrt(-1.0);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_INVALID_PARAMETERS,
         "non-finite parameters fail closed");

   int atr_periods[]={10,14,18,22};
   double multipliers[]={2.0,2.5,3.0,3.5,4.0};
   int lookbacks[]={6,12,18,24};
   double entry_buffers[]={0.0,0.1,0.2};
   double stop_buffers[]={0.0,0.25,0.5};
   int checkpoints[]={8,12,16};
   double progresses[]={0.25,0.5,0.75};
   int holdings[]={48,72,96};
   int accepted=0;
   for(int a=0;a<ArraySize(atr_periods);a++)
      for(int b=0;b<ArraySize(multipliers);b++)
         for(int c=0;c<ArraySize(lookbacks);c++)
            for(int d=0;d<ArraySize(entry_buffers);d++)
               for(int e=0;e<ArraySize(stop_buffers);e++)
                  for(int f=0;f<ArraySize(checkpoints);f++)
                     for(int g=0;g<ArraySize(progresses);g++)
                        for(int h=0;h<ArraySize(holdings);h++)
                          {
                           request.parameters.atr_period=atr_periods[a];
                           request.parameters.supertrend_multiplier=multipliers[b];
                           request.parameters.breakout_lookback_bars=lookbacks[c];
                           request.parameters.entry_buffer_atr=entry_buffers[d];
                           request.parameters.stop_buffer_atr=stop_buffers[e];
                           request.parameters.progress_checkpoint_bars=checkpoints[f];
                           request.parameters.required_progress_r=progresses[g];
                           request.parameters.maximum_holding_bars=holdings[h];
                           KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
                           if(decision.reason!=
                              KINGEA_SLEEVE_REASON_INVALID_PARAMETERS)
                              accepted++;
                          }
   Check(accepted==19440,
         "all 19440 frozen configurations are valid contract inputs without returns");
  }

void TestIndicatorsAndEntries(KingEASleeveDecision &representative)
  {
   KingEASleeveBar bars[];
   BuildUniformTrend(bars,200,D'2026.01.01 00:00:00',
                     KINGEA_DIRECTION_LONG);
   KingEASleeveRequest request=RequestFor(bars);
   request.regime.entry_eligible=false;
   request.regime.trend_state=KINGEA_STAGE10_TREND_RANGING;
   KingEASleeveState prior={};
   KingEASleeveDecision decision={};
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.healthy && Near(decision.trace.m30_atr,2.0),
         "Wilder ATR golden vector remains exactly two");
   Check(decision.trace.m30_supertrend_direction==KINGEA_DIRECTION_LONG &&
         decision.trace.h4_supertrend_direction==KINGEA_DIRECTION_LONG,
         "M30 and server-aligned H4 Supertrend confirm the uniform uptrend");
   Check(decision.reason==KINGEA_SLEEVE_REASON_REGIME_BLOCK &&
         decision.next_state.last_evaluated_m30_bar==
            bars[ArraySize(bars)-1].open_time,
         "a regime-blocked valid bar is consumed and not queued");

   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   ZeroMemory(prior);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.action==KINGEA_SLEEVE_ACTION_ENTRY &&
         decision.direction==KINGEA_DIRECTION_LONG &&
         decision.candidate_reason=="LONG_CONTINUATION_BREAKOUT",
         "fresh symmetric long continuation emits entry intent");
   Check(decision.technical_stop<bars[ArraySize(bars)-1].close &&
         StringFind(decision.signal_identity,"CAND-ETH-ST-001|")==0,
         "long intent carries structural stop and deterministic identity");
   representative=decision;

   KingEASleeveState consumed=decision.next_state;
   KingEAEvaluateSleeveEthSt001(bars,request,consumed,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_DUPLICATE_OR_BACKWARD &&
         decision.action==KINGEA_SLEEVE_ACTION_NONE,
         "the same closed bar cannot emit a second intent");

   ArrayResize(bars,201);
   bars[200]=bars[199];
   bars[200].open_time=bars[199].open_time+KINGEA_SLEEVE_M30_SECONDS;
   bars[200].open=bars[199].close;
   bars[200].close=bars[200].open+0.1;
   bars[200].high=bars[200].close+0.2;
   bars[200].low=bars[200].open-0.2;
   request=RequestFor(bars);
   KingEAEvaluateSleeveEthSt001(bars,request,consumed,decision);
   Check(decision.action==KINGEA_SLEEVE_ACTION_NONE &&
         decision.reason==KINGEA_SLEEVE_REASON_NO_FRESH_BREAKOUT,
         "a consumed breakout is not queued onto the next bar");

   BuildContinuation(bars,KINGEA_DIRECTION_SHORT);
   request=RequestFor(bars);
   ZeroMemory(prior);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.action==KINGEA_SLEEVE_ACTION_ENTRY &&
         decision.direction==KINGEA_DIRECTION_SHORT &&
         decision.candidate_reason=="SHORT_CONTINUATION_BREAKOUT",
         "fresh symmetric short continuation emits entry intent");
   Check(decision.technical_stop>bars[ArraySize(bars)-1].close,
         "short intent carries a stop above price");

   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   request.regime.next_state.last_observation_time-=KINGEA_SLEEVE_M30_SECONDS;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_REGIME_MISMATCH,
         "Stage 10 observation mismatch blocks entry");

   request=RequestFor(bars);
   request.has_open_trade_group=true;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_OPEN_GROUP_EXISTS,
         "one-trade-group invariant blocks another entry");

   BuildUniformTrend(bars,200,D'2021.02.01 00:00:00',
                     KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_WARMUP_ONLY &&
         decision.next_state.last_evaluated_m30_bar==
            bars[ArraySize(bars)-1].open_time,
         "pre-July-2021 bars initialize indicators but cannot signal");
  }

void TestH4BreakoutAndInputFailures()
  {
   KingEASleeveBar bars[];
   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   KingEASleeveRequest request=RequestFor(bars);
   KingEASleeveState prior={};
   KingEASleeveDecision base={};
   KingEAEvaluateSleeveEthSt001(bars,request,prior,base);

   int last=ArraySize(bars)-1;
   double expected_high=bars[last-request.parameters.breakout_lookback_bars].high;
   double expected_previous_high=
      bars[last-request.parameters.breakout_lookback_bars-1].high;
   for(int i=last-request.parameters.breakout_lookback_bars;i<=last-1;i++)
      expected_high=MathMax(expected_high,bars[i].high);
   for(int i=last-request.parameters.breakout_lookback_bars-1;i<=last-2;i++)
      expected_previous_high=MathMax(expected_previous_high,bars[i].high);
   Check(Near(base.trace.breakout_high,expected_high) &&
         Near(base.trace.previous_breakout_high,expected_previous_high),
         "current and previous breakout windows exclude their signal bars");

   int prior_h4_direction=base.trace.h4_supertrend_direction;
   ArrayResize(bars,201);
   bars[200]=bars[199];
   bars[200].open_time=bars[199].open_time+KINGEA_SLEEVE_M30_SECONDS;
   bars[200].open=bars[199].close;
   bars[200].close=bars[200].open+0.1;
   bars[200].high=bars[200].close+0.2;
   bars[200].low=bars[200].open-0.2;
   request=RequestFor(bars);
   KingEASleeveDecision partial={};
   KingEAEvaluateSleeveEthSt001(bars,request,prior,partial);
   Check(partial.trace.h4_supertrend_direction==prior_h4_direction,
         "an incomplete H4 bucket is excluded from confirmation");

   bool all_boundaries=true;
   for(int hour=0;hour<24;hour+=4)
     {
      BuildUniformTrend(bars,200,D'2026.01.01 00:00:00'+hour*3600,
                        KINGEA_DIRECTION_LONG);
      request=RequestFor(bars);
      request.regime.entry_eligible=false;
      request.regime.trend_state=KINGEA_STAGE10_TREND_RANGING;
      KingEASleeveDecision boundary={};
      KingEAEvaluateSleeveEthSt001(bars,request,prior,boundary);
      if(!boundary.healthy ||
         boundary.trace.h4_supertrend_direction!=KINGEA_DIRECTION_LONG)
         all_boundaries=false;
     }
   Check(all_boundaries,
         "server H4 boundaries 00 04 08 12 16 and 20 derive deterministically");

   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   bars[10].open_time+=60;
   KingEASleeveDecision failed={};
   KingEAEvaluateSleeveEthSt001(bars,request,prior,failed);
   Check(failed.reason==KINGEA_SLEEVE_REASON_BAR_MISALIGNED,
         "misaligned M30 input fails closed");
   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   bars[10].open_time=bars[9].open_time;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,failed);
   Check(failed.reason==KINGEA_SLEEVE_REASON_TIMESTAMP_ORDER,
         "duplicate timestamp fails closed");
   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   request.evaluation_time=bars[199].open_time+100;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,failed);
   Check(failed.reason==KINGEA_SLEEVE_REASON_FORMING_BAR,
         "forming signal bar fails closed");
   request.evaluation_time=bars[199].open_time+
                           (KINGEA_SLEEVE_M30_SECONDS*3);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,failed);
   Check(failed.reason==KINGEA_SLEEVE_REASON_STALE,
         "stale closed-bar evaluation fails closed");
   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   request=RequestFor(bars);
   bars[20].high=MathSqrt(-1.0);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,failed);
   Check(failed.reason==KINGEA_SLEEVE_REASON_MALFORMED_BAR,
         "non-finite OHLC input fails closed");
  }

void TestPositionProgressAndExpiry()
  {
   KingEASleeveBar bars[];
   BuildContinuation(bars,KINGEA_DIRECTION_LONG);
   KingEASleeveRequest request=RequestFor(bars);
   KingEASleeveState prior={};
   KingEASleeveDecision direction_probe={};
   request.regime.entry_eligible=false;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,direction_probe);
   int direction=direction_probe.trace.m30_supertrend_direction;
   int last=ArraySize(bars)-1;

   request=RequestFor(bars);
   request.position.has_position=true;
   request.position.direction=direction;
   request.position.entry_signal_bar_time=bars[last-12].open_time;
   request.position.entry_price=bars[last-12].close;
   request.position.original_confirmed_stop=
      request.position.entry_price-
      (direction==KINGEA_DIRECTION_LONG ? 100.0 : -100.0);
   request.position.original_stop_confirmed=true;
   KingEASleeveDecision decision={};
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   double expected=ClosedBarMfe(bars,
                                request.position.entry_signal_bar_time,
                                direction,
                                request.position.entry_price,
                                request.position.original_confirmed_stop);
   Check(decision.bars_held==12 &&
         Near(decision.maximum_favourable_excursion_r,expected),
         "MFE uses closed bars after entry and fixed original R");
   Check(decision.action==KINGEA_SLEEVE_ACTION_EXIT &&
         decision.candidate_reason=="INSUFFICIENT_PROGRESS",
         "checkpoint boundary emits insufficient-progress exit");

   double favourable_distance=expected*100.0;
   request.position.original_confirmed_stop=
      request.position.entry_price-
      (direction==KINGEA_DIRECTION_LONG ?
       favourable_distance/0.5 : -favourable_distance/0.5);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(Near(decision.maximum_favourable_excursion_r,0.5) &&
         decision.action==KINGEA_SLEEVE_ACTION_HOLD,
         "progress exactly equal to required R does not exit");

   int entry_index=last-12;
   double original_entry_high=bars[entry_index].high;
   bars[entry_index].high=request.position.entry_price+1000.0;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(Near(decision.maximum_favourable_excursion_r,0.5),
         "entry signal-bar high is excluded from closed-bar MFE");
   bars[entry_index].high=original_entry_high;

   request.position.entry_signal_bar_time=bars[last-72].open_time;
   request.position.entry_price=bars[last-72].close;
   request.position.original_confirmed_stop=
      request.position.entry_price-
      (direction==KINGEA_DIRECTION_LONG ? 1.0 : -1.0);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.bars_held==72 &&
         decision.action==KINGEA_SLEEVE_ACTION_EXIT &&
         decision.candidate_reason=="MAXIMUM_HOLDING_PERIOD",
         "maximum holding boundary has priority over progress");

   request.position.entry_signal_bar_time=bars[last-1].open_time;
   request.position.entry_price=bars[last-1].close;
   request.position.original_confirmed_stop=
      request.position.entry_price+
      (direction==KINGEA_DIRECTION_LONG ? 10.0 : -10.0);
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_INVALID_POSITION,
         "wrong-side original stop fails closed");

   request.position.original_stop_confirmed=false;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.reason==KINGEA_SLEEVE_REASON_INVALID_POSITION,
         "unconfirmed original protective stop fails closed");

   request=RequestFor(bars);
   request.position.has_position=true;
   request.position.direction=-direction;
   request.position.entry_signal_bar_time=bars[last-1].open_time;
   request.position.entry_price=bars[last-1].close;
   request.position.original_confirmed_stop=
      request.position.entry_price+
      (request.position.direction==KINGEA_DIRECTION_SHORT ? 10.0 : -10.0);
   request.position.original_stop_confirmed=true;
   KingEAEvaluateSleeveEthSt001(bars,request,prior,decision);
   Check(decision.action==KINGEA_SLEEVE_ACTION_EXIT &&
         decision.candidate_reason=="OPPOSITE_M30_SUPERTREND",
         "opposite M30 Supertrend exits before time rules");
  }

void OnStart()
  {
   TestRequestAndGrid();
   KingEASleeveDecision representative={};
   TestIndicatorsAndEntries(representative);
   TestH4BreakoutAndInputFailures();
   TestPositionProgressAndExpiry();
   WriteContractReport(representative);
   PrintFormat("SLEEVE_ETH_ST_001_TEST_%s: checks=%d; failures=%d; non-performance; no performance authorization.",
               g_failures==0 ? "PASS" : "FAIL",g_checks,g_failures);
  }
