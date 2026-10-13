#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Deterministic non-trading Stage 10 market-context contract tests."
#property description "No broker history, indicators, performance, optimization, or order capability."

#include <KingEA/RegimeClassifier.mqh>
#include <KingEA/CorrelationClustering.mqh>

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

bool Near(const double actual,const double expected,const double tolerance=1e-8)
  {
   return MathAbs(actual-expected)<=tolerance;
  }

string SafeStamp(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,".","-");
   return value;
  }

void WriteContractReport(const KingEARegimeDecision &regime,
                         const KingEACorrelationDecision &correlation)
  {
   string relative="KingEA\\market_context_contract_"+
                   SafeStamp(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS))+".csv";
   int handle=FileOpen(relative,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|
                       FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      g_failures++;
      PrintFormat("FAIL: contract report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"key","value");
   FileWrite(handle,"stage","10");
   FileWrite(handle,"scope","DETERMINISTIC_NON_PERFORMANCE_CONTRACT");
   FileWrite(handle,"fixture_identity","KINGEA_STAGE10_CONTRACT_V1");
   FileWrite(handle,"result",(g_failures==0 ? "PASS" : "FAIL"));
   FileWrite(handle,"checks",IntegerToString(g_checks));
   FileWrite(handle,"failures",IntegerToString(g_failures));
   FileWrite(handle,"sample_trend_state",IntegerToString(regime.trend_state));
   FileWrite(handle,"sample_volatility_state",IntegerToString(regime.volatility_state));
   FileWrite(handle,"sample_cluster_known",(correlation.cluster_known ? "true" : "false"));
   FileWrite(handle,"sample_cluster_member_count",
             IntegerToString(correlation.member_count));
   for(int i=0;i<correlation.member_count;i++)
      FileWrite(handle,"cluster_"+correlation.members[i].symbol_id,
                correlation.members[i].cluster_key);
   FileWrite(handle,"order_capability","PROHIBITED_AND_ABSENT");
   FileWrite(handle,"performance_authorization","DENIED");
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA Stage 10 contract report: %s\\Files\\%s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH),relative);
  }

void BuildTrendBars(KingEARegimeBar &bars[],const int count,
                    const datetime start)
  {
   ArrayResize(bars,count);
   double previous_close=1000.0;
   for(int i=0;i<count;i++)
     {
      bars[i].open_time=start+(i*KINGEA_REGIME_M30_SECONDS);
      bars[i].open=previous_close;
      bars[i].close=previous_close+1.0;
      bars[i].high=bars[i].close+0.5;
      bars[i].low=bars[i].open-0.5;
      bars[i].complete=true;
      previous_close=bars[i].close;
     }
  }

void BuildRangeBars(KingEARegimeBar &bars[],const int count,
                    const datetime start)
  {
   ArrayResize(bars,count);
   double previous_close=1000.0;
   for(int i=0;i<count;i++)
     {
      double direction=(i%2==0 ? 1.0 : -1.0);
      bars[i].open_time=start+(i*KINGEA_REGIME_M30_SECONDS);
      bars[i].open=previous_close;
      bars[i].close=previous_close+direction;
      bars[i].high=MathMax(bars[i].open,bars[i].close)+
                   (direction>0.0 ? 0.6 : 0.4);
      bars[i].low=MathMin(bars[i].open,bars[i].close)-
                  (direction>0.0 ? 0.4 : 0.6);
      bars[i].complete=true;
      previous_close=bars[i].close;
     }
  }

void BuildPercentileBars(KingEARegimeBar &bars[],const double current_range)
  {
   const int count=35;
   ArrayResize(bars,count);
   datetime start=D'2026.01.01 00:00:00';
   double previous_close=1000.0;
   for(int i=0;i<count;i++)
     {
      double range=(i==count-1 ? current_range : 40.0-i);
      bars[i].open_time=start+(i*KINGEA_REGIME_M30_SECONDS);
      bars[i].open=previous_close;
      bars[i].close=previous_close+2.0;
      bars[i].high=bars[i].close+(range/2.0);
      bars[i].low=bars[i].open-(range/2.0);
      bars[i].complete=true;
      previous_close=bars[i].close;
     }
  }

KingEARegimeRequest RegimeRequestFor(const KingEARegimeBar &bars[],
                                     const int expected_slots=20)
  {
   KingEARegimeRequest request={};
   int last=ArraySize(bars)-1;
   request.evaluation_time=bars[last].open_time+KINGEA_REGIME_M30_SECONDS;
   request.expected_open_slots=expected_slots;
   request.maximum_staleness_seconds=KINGEA_REGIME_M30_SECONDS;
   return request;
  }

bool FindPercentileFixture(const double target,
                           KingEARegimeBar &bars[],
                           KingEARegimeDecision &decision)
  {
   KingEARegimeHysteresis established={};
   established.trend_state=KINGEA_STAGE10_TREND_TRENDING;
   established.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
   double minimum_seen=101.0;
   double maximum_seen=-1.0;
   int healthy_seen=0;
   for(int step=1;step<=10000;step++)
     {
      BuildPercentileBars(bars,step*0.10);
      established.last_observation_time=bars[33].open_time;
      KingEARegimeRequest request=RegimeRequestFor(bars);
      KingEAEvaluateRegime(bars,request,established,decision);
      if(decision.healthy)
        {
         healthy_seen++;
         minimum_seen=MathMin(minimum_seen,decision.percentile);
         maximum_seen=MathMax(maximum_seen,decision.percentile);
         if(Near(decision.percentile,target,1e-10))
            return true;
        }
     }
   PrintFormat("PERCENTILE_FIXTURE_DIAGNOSTIC target=%.2f healthy=%d min=%.2f max=%.2f reason=%d",
               target,healthy_seen,minimum_seen,maximum_seen,(int)decision.reason);
   return false;
  }

void SetSeriesFromReturns(KingEADailyCloseSeries &series,
                          const string symbol,
                          const datetime start,
                          const double &returns[],
                          const bool fresh=true)
  {
   ZeroMemory(series);
   series.symbol_id=symbol;
   series.point_count=ArraySize(returns)+1;
   series.fresh=fresh;
   series.close_times[0]=start;
   series.closes[0]=100.0;
   for(int i=0;i<ArraySize(returns);i++)
     {
      series.close_times[i+1]=start+((i+1)*86400);
      series.closes[i+1]=series.closes[i]*MathExp(returns[i]);
     }
  }

void BuildCorrelationReturns(double &first[],double &second[],
                             const int count,const double rho)
  {
   ArrayResize(first,count);
   ArrayResize(second,count);
   double scale=0.001;
   double orthogonal_weight=MathSqrt(MathMax(0.0,1.0-(rho*rho)));
   for(int i=0;i<count;i++)
     {
      int phase=i%4;
      double x=(phase==0 || phase==2 ? -1.0 : 1.0);
      double z=(phase<2 ? -1.0 : 1.0);
      first[i]=scale*x;
      second[i]=scale*((rho*x)+(orthogonal_weight*z));
     }
  }

KingEACorrelationRequest PairRequest(const double rho,
                                     const datetime start,
                                     const bool second_fresh=true)
  {
   KingEACorrelationRequest request={};
   request.symbol_count=2;
   double first[],second[];
   BuildCorrelationReturns(first,second,60,rho);
   SetSeriesFromReturns(request.series[0],"ETHUSD.s",start,first,true);
   SetSeriesFromReturns(request.series[1],"SYNTH-B",start,second,second_fresh);
   request.expected_latest_close_time=start+(60*86400);
   return request;
  }

KingEACorrelationRequest PiecewisePairRequest(const double first_40_rho,
                                              const double last_20_rho,
                                              const datetime start)
  {
   KingEACorrelationRequest request={};
   request.symbol_count=2;
   double first[],second[];
   ArrayResize(first,60);
   ArrayResize(second,60);
   for(int i=0;i<60;i++)
     {
      int phase=i%4;
      double x=(phase==0 || phase==2 ? -1.0 : 1.0);
      double z=(phase<2 ? -1.0 : 1.0);
      double rho=(i<40 ? first_40_rho : last_20_rho);
      first[i]=0.001*x;
      second[i]=0.001*((rho*x)+
                  (MathSqrt(MathMax(0.0,1.0-rho*rho))*z));
     }
   SetSeriesFromReturns(request.series[0],"ETHUSD.s",start,first,true);
   SetSeriesFromReturns(request.series[1],"SYNTH-B",start,second,true);
   request.expected_latest_close_time=start+(60*86400);
   return request;
  }

int FindPair(const KingEACorrelationDecision &decision,const string key)
  {
   for(int i=0;i<decision.pair_count;i++)
      if(decision.pairs[i].pair_key==key)
         return i;
   return -1;
  }

void TestRegimeClassifier(KingEARegimeDecision &representative)
  {
   KingEARegimeBar bars[];
   BuildTrendBars(bars,35,D'2026.01.01 00:00:00');
   KingEARegimeRequest request=RegimeRequestFor(bars);
   KingEARegimeHysteresis prior={};
   prior.trend_state=KINGEA_STAGE10_TREND_TRENDING;
   prior.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
   prior.last_observation_time=bars[33].open_time;
   KingEARegimeDecision decision={};
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.healthy && Near(decision.atr,2.0) &&
         Near(decision.adx,100.0),
         "Wilder seed and recursive golden vector returns ATR 2 and ADX 100");
   Check(decision.valid_percentile_samples==20 &&
         decision.strictly_less_samples==0 &&
         Near(decision.percentile,0.0),
         "current observation is excluded and strict-less rank is zero");
   Check(decision.entry_eligible &&
         decision.trend_state==KINGEA_STAGE10_TREND_TRENDING &&
         decision.volatility_state==KINGEA_STAGE10_VOLATILITY_NORMAL,
         "established trending normal regime permits entry");
   representative=decision;

   KingEARegimeHysteresis startup={};
   KingEAEvaluateRegime(bars,request,startup,decision);
   Check(decision.healthy && !decision.entry_eligible &&
         decision.trend_state==KINGEA_STAGE10_TREND_TRANSITIONAL &&
         decision.volatility_state==KINGEA_STAGE10_VOLATILITY_INVALID,
         "startup first observation remains transitional");
   KingEARegimeHysteresis repeated_state=decision.next_state;
   KingEARegimeDecision repeated={};
   KingEAEvaluateRegime(bars,request,repeated_state,repeated);
   Check(repeated.trend_state==KINGEA_STAGE10_TREND_TRANSITIONAL &&
         repeated.volatility_state==KINGEA_STAGE10_VOLATILITY_INVALID &&
         repeated.next_state.trend_pending_count==1 &&
         repeated.next_state.volatility_pending_count==1,
         "re-evaluating the same closed bar cannot confirm hysteresis");
   ArrayResize(bars,36);
   bars[35]=bars[34];
   bars[35].open_time=bars[34].open_time+KINGEA_REGIME_M30_SECONDS;
   bars[35].open=bars[34].close;
   bars[35].close=bars[35].open+1.0;
   bars[35].high=bars[35].close+0.5;
   bars[35].low=bars[35].open-0.5;
   request=RegimeRequestFor(bars);
   KingEARegimeHysteresis startup_second=decision.next_state;
   KingEAEvaluateRegime(bars,request,startup_second,decision);
   Check(decision.trend_state==KINGEA_STAGE10_TREND_TRENDING &&
         decision.volatility_state==KINGEA_STAGE10_VOLATILITY_NORMAL,
         "second distinct observation confirms startup regimes");
   KingEARegimeBar skipped[];
   BuildTrendBars(skipped,37,D'2026.01.01 00:00:00');
   request=RegimeRequestFor(skipped);
   KingEARegimeHysteresis skipped_prior=repeated_state;
   KingEAEvaluateRegime(skipped,request,skipped_prior,repeated);
   Check(repeated.trend_state==KINGEA_STAGE10_TREND_TRANSITIONAL &&
         repeated.next_state.trend_pending_count==1,
         "non-consecutive observation cannot complete hysteresis");

   BuildRangeBars(bars,100,D'2026.02.01 00:00:00');
   request=RegimeRequestFor(bars,60);
   prior=decision.next_state;
   prior.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
   prior.volatility_pending_state=KINGEA_STAGE10_VOLATILITY_INVALID;
   prior.volatility_pending_count=0;
   prior.trend_state=KINGEA_STAGE10_TREND_TRENDING;
   prior.trend_pending_state=KINGEA_STAGE10_TREND_TRANSITIONAL;
   prior.trend_pending_count=0;
   prior.last_observation_time=bars[98].open_time;
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.healthy && decision.adx<20.0 &&
         decision.trend_state==KINGEA_STAGE10_TREND_TRANSITIONAL &&
         !decision.entry_eligible,
         "first opposing trend observation blocks as transitional");
   ArrayResize(bars,101);
   bars[100]=bars[99];
   bars[100].open_time=bars[99].open_time+KINGEA_REGIME_M30_SECONDS;
   bars[100].open=bars[99].close;
   bars[100].close=bars[100].open+1.0;
   bars[100].high=bars[100].close+0.5;
   bars[100].low=bars[100].open-0.5;
   request=RegimeRequestFor(bars,60);
   KingEARegimeHysteresis ranging_second=decision.next_state;
   KingEAEvaluateRegime(bars,request,ranging_second,decision);
   Check(decision.trend_state==KINGEA_STAGE10_TREND_RANGING,
         "second opposing trend observation confirms ranging");

   KingEARegimeDecision p75={},p80={},p95={},p100={};
   Check(FindPercentileFixture(75.0,bars,p75) &&
         p75.strictly_less_samples==15,
         "percentile fixture reaches just below 80");
   Check(FindPercentileFixture(80.0,bars,p80) &&
         p80.strictly_less_samples==16 &&
         p80.volatility_state!=KINGEA_STAGE10_VOLATILITY_NORMAL,
         "exact 80 is high-bin input, not normal");
   Check(FindPercentileFixture(95.0,bars,p95) &&
         p95.strictly_less_samples==19 &&
         p95.volatility_state!=KINGEA_STAGE10_VOLATILITY_EXTREME,
         "exact 95 remains high-bin input");
   Check(FindPercentileFixture(100.0,bars,p100) &&
         p100.strictly_less_samples==20 &&
         p100.volatility_state!=KINGEA_STAGE10_VOLATILITY_HIGH,
         "just above 95 is extreme-bin input");

   KingEARegimeBar high_confirmation[];
   FindPercentileFixture(80.0,high_confirmation,p80);
   for(int i=0;i<ArraySize(high_confirmation);i++)
      high_confirmation[i].open_time+=KINGEA_REGIME_M30_SECONDS;
   request=RegimeRequestFor(high_confirmation);
   KingEARegimeHysteresis high_second=p80.next_state;
   KingEAEvaluateRegime(high_confirmation,request,high_second,decision);
   Check(decision.volatility_state==KINGEA_STAGE10_VOLATILITY_HIGH,
         "second distinct exact-80 observation confirms high volatility");

   KingEARegimeBar extreme_confirmation[];
   FindPercentileFixture(100.0,extreme_confirmation,p100);
   for(int i=0;i<ArraySize(extreme_confirmation);i++)
      extreme_confirmation[i].open_time+=KINGEA_REGIME_M30_SECONDS;
   request=RegimeRequestFor(extreme_confirmation);
   KingEARegimeHysteresis extreme_second=p100.next_state;
   KingEAEvaluateRegime(extreme_confirmation,request,extreme_second,decision);
   Check(decision.volatility_state==KINGEA_STAGE10_VOLATILITY_EXTREME &&
         !decision.entry_eligible,
         "second distinct above-95 observation confirms extreme and blocks");

   // Construct an exact normalized-ATR tie with the immediately prior bar.
   BuildPercentileBars(bars,1.0);
   ArrayResize(bars,34);
   request=RegimeRequestFor(bars,20);
   prior.trend_state=KINGEA_STAGE10_TREND_TRENDING;
   prior.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
   prior.last_observation_time=bars[32].open_time;
   KingEARegimeDecision before_tie={};
   KingEAEvaluateRegime(bars,request,prior,before_tie);
   ArrayResize(bars,35);
   bars[34].open_time=bars[33].open_time+KINGEA_REGIME_M30_SECONDS;
   bars[34].open=bars[33].close;
   bars[34].close=bars[33].close;
   bars[34].high=bars[34].close+(before_tie.atr/2.0);
   bars[34].low=bars[34].close-(before_tie.atr/2.0);
   bars[34].complete=true;
   request=RegimeRequestFor(bars,20);
   prior.last_observation_time=bars[33].open_time;
   KingEARegimeDecision tied={};
   KingEAEvaluateRegime(bars,request,prior,tied);
   Check(tied.healthy &&
         Near(tied.normalized_atr,before_tie.normalized_atr,1e-12) &&
         tied.valid_percentile_samples==
            before_tie.valid_percentile_samples+1,
         "tie fixture reproduces the prior normalized ATR");
   Check(tied.strictly_less_samples==before_tie.strictly_less_samples,
         "strict-less percentile excludes an equal historical value");

   bool midband_found=false;
   for(int trend_bars=1;trend_bars<=50 && !midband_found;trend_bars++)
     {
      BuildRangeBars(bars,100,D'2026.04.01 00:00:00');
      ArrayResize(bars,100+trend_bars);
      for(int i=100;i<100+trend_bars;i++)
        {
         bars[i].open_time=bars[i-1].open_time+
                           KINGEA_REGIME_M30_SECONDS;
         bars[i].open=bars[i-1].close;
         bars[i].close=bars[i].open+1.0;
         bars[i].high=bars[i].close+0.6;
         bars[i].low=bars[i].open-0.4;
         bars[i].complete=true;
        }
      request=RegimeRequestFor(bars,80);
      prior.trend_state=KINGEA_STAGE10_TREND_TRENDING;
      prior.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
      prior.last_observation_time=bars[ArraySize(bars)-2].open_time;
      KingEAEvaluateRegime(bars,request,prior,decision);
      if(decision.healthy && decision.adx>=20.0 && decision.adx<25.0)
         midband_found=true;
     }
   Check(midband_found &&
         decision.trend_state==KINGEA_STAGE10_TREND_TRENDING,
         "established trend persists inside the 20-to-25 hysteresis band");

   BuildTrendBars(bars,4118,D'2025.10.01 00:00:00');
   request=RegimeRequestFor(bars,4320);
   ZeroMemory(prior);
   prior.trend_state=KINGEA_STAGE10_TREND_TRENDING;
   prior.volatility_state=KINGEA_STAGE10_VOLATILITY_NORMAL;
   prior.last_observation_time=bars[4116].open_time;
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(!decision.healthy &&
         decision.reason==KINGEA_REGIME_REASON_INSUFFICIENT_COVERAGE &&
         decision.valid_percentile_samples==4103,
         "4103 of 4320 samples fails the 95 percent coverage floor");
   BuildTrendBars(bars,4119,D'2025.10.01 00:00:00');
   request=RegimeRequestFor(bars,4320);
   prior.last_observation_time=bars[4117].open_time;
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.healthy && decision.valid_percentile_samples==4104,
         "4104 of 4320 samples passes the 95 percent coverage floor");

   BuildTrendBars(bars,35,D'2026.01.01 00:00:00');
   request=RegimeRequestFor(bars);
   prior.last_observation_time=bars[33].open_time;
   bars[10].open_time=bars[9].open_time;
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.reason==KINGEA_REGIME_REASON_TIMESTAMP_ORDER,
         "duplicate timestamp fails closed");
   BuildTrendBars(bars,35,D'2026.01.01 00:00:00');
   bars[10].open_time+=60;
   request=RegimeRequestFor(bars);
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.reason==KINGEA_REGIME_REASON_BAR_MISALIGNED,
         "misaligned timestamp fails closed");
   BuildTrendBars(bars,35,D'2026.01.01 00:00:00');
   bars[10].open_time+=KINGEA_REGIME_M30_SECONDS;
   request=RegimeRequestFor(bars);
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.reason==KINGEA_REGIME_REASON_DATA_GAP ||
         decision.reason==KINGEA_REGIME_REASON_TIMESTAMP_ORDER,
         "data gap fails closed");
   BuildTrendBars(bars,35,D'2026.01.01 00:00:00');
   request=RegimeRequestFor(bars);
   request.evaluation_time=bars[34].open_time+100;
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.reason==KINGEA_REGIME_REASON_FORMING_BAR,
         "forming bar fails closed");
   request.evaluation_time=bars[34].open_time+
                           KINGEA_REGIME_M30_SECONDS*3;
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.reason==KINGEA_REGIME_REASON_STALE,
         "stale input fails closed");
   BuildTrendBars(bars,35,D'2026.01.01 00:00:00');
   bars[5].high=MathSqrt(-1.0);
   request=RegimeRequestFor(bars);
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(decision.reason==KINGEA_REGIME_REASON_MALFORMED_BAR,
         "non-finite bar fails closed");

   ArrayResize(bars,64);
   datetime flat_start=D'2026.03.01 00:00:00';
   for(int i=0;i<ArraySize(bars);i++)
     {
      bars[i].open_time=flat_start+(i*KINGEA_REGIME_M30_SECONDS);
      bars[i].open=100.0;
      bars[i].high=100.0;
      bars[i].low=100.0;
      bars[i].close=100.0;
      bars[i].complete=true;
     }
   request=RegimeRequestFor(bars,20);
   KingEAEvaluateRegime(bars,request,prior,decision);
   Check(!decision.healthy && !decision.entry_eligible &&
         decision.reason==KINGEA_REGIME_REASON_UNDEFINED_INDICATOR,
         "flat market fails closed when Wilder denominator is zero");

   Check(KINGEA_STAGE10_TREND_TRANSITIONAL==0 &&
         KINGEA_STAGE10_TREND_TRENDING==1 &&
         KINGEA_STAGE10_TREND_RANGING==2 &&
         KINGEA_STAGE10_VOLATILITY_INVALID==0 &&
         KINGEA_STAGE10_VOLATILITY_NORMAL==1 &&
         KINGEA_STAGE10_VOLATILITY_HIGH==2 &&
         KINGEA_STAGE10_VOLATILITY_EXTREME==3,
         "Stage 10 enums map exactly to Candidate 001 integer contract");
  }

void TestCorrelationClustering(KingEACorrelationDecision &representative)
  {
   datetime start=D'2025.01.01 00:00:00';
   KingEACorrelationState prior={};
   KingEACorrelationDecision decision={};
   KingEACorrelationRequest request=PairRequest(0.60,start);
   KingEAEvaluateCorrelation(request,prior,decision);
   int pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && decision.pairs[pair].correlation_valid &&
         Near(decision.pairs[pair].correlation_60,0.60,1e-8) &&
         decision.pairs[pair].edge_active,
         "exact positive 0.60 primary correlation activates edge");
   representative=decision;

   request=PairRequest(-0.60,start);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && Near(decision.pairs[pair].correlation_60,-0.60,1e-8) &&
         decision.pairs[pair].edge_active,
         "absolute negative 0.60 primary correlation activates edge");
   request=PairRequest(0.70,start);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && Near(decision.pairs[pair].correlation_20,0.70,1e-8) &&
         decision.pairs[pair].edge_active,
         "exact 0.70 shock correlation activates edge");

   request=PiecewisePairRequest(0.0,0.90,start);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 &&
         MathAbs(decision.pairs[pair].correlation_60)<0.60 &&
         MathAbs(decision.pairs[pair].correlation_20)>=0.70 &&
         decision.pairs[pair].edge_active,
         "20-day shock window independently activates an edge");
   request=PiecewisePairRequest(0.90,0.50,start);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 &&
         MathAbs(decision.pairs[pair].correlation_60)>=0.60 &&
         MathAbs(decision.pairs[pair].correlation_20)<0.70 &&
         decision.pairs[pair].edge_active,
         "60-day primary window independently activates an edge");

   ZeroMemory(request);
   request.symbol_count=2;
   double aligned_first[],aligned_second[];
   BuildCorrelationReturns(aligned_first,aligned_second,61,0.20);
   SetSeriesFromReturns(request.series[0],"ETHUSD.s",start,
                        aligned_first,true);
   double shifted_returns[];
   ArrayResize(shifted_returns,60);
   for(int i=0;i<60;i++)
      shifted_returns[i]=aligned_second[i+1];
   SetSeriesFromReturns(request.series[1],"SYNTH-B",start+86400,
                        shifted_returns,true);
   request.expected_latest_close_time=start+(61*86400);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && decision.pairs[pair].correlation_valid,
         "correlation selects the latest 60 aligned return dates");

   // Release is slow: exact 0.45 resets, then ten distinct below-threshold days.
   request=PairRequest(0.45,start);
   ZeroMemory(prior);
   prior.pair_count=1;
   prior.pairs[0].pair_key="ETHUSD.s|SYNTH-B";
   prior.pairs[0].edge_active=true;
   prior.pairs[0].release_clean_days=7;
   prior.pairs[0].last_evaluation_day=request.expected_latest_close_time-86400;
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && decision.pairs[pair].edge_active &&
         decision.pairs[pair].release_clean_days==0,
         "exact 0.45 resets release counter and retains edge");

   ZeroMemory(prior);
   prior.pair_count=1;
   prior.pairs[0].pair_key="ETHUSD.s|SYNTH-B";
   prior.pairs[0].edge_active=true;
   for(int day=1;day<=10;day++)
     {
      request=PairRequest(0.44,start+(day*86400));
      prior.pairs[0].last_evaluation_day=
         request.expected_latest_close_time-86400;
      if(day>1)
         prior.pairs[0].release_clean_days=day-1;
      KingEAEvaluateCorrelation(request,prior,decision);
      pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
      prior=decision.next_state;
      if(day==9)
         Check(decision.pairs[pair].edge_active &&
               decision.pairs[pair].release_clean_days==9,
               "nine clean days do not release an active edge");
      if(day==10)
         Check(!decision.pairs[pair].edge_active &&
               decision.pairs[pair].release_clean_days==10,
               "ten distinct clean days release a dynamic edge");
     }

   // Static A-B and B-C overrides prove transitive, deterministic clustering.
   ZeroMemory(request);
   request.symbol_count=3;
   double first[],second[];
   BuildCorrelationReturns(first,second,60,0.10);
   SetSeriesFromReturns(request.series[0],"SYNTH-C",start,second);
   SetSeriesFromReturns(request.series[1],"ETHUSD.s",start,first);
   BuildCorrelationReturns(first,second,60,-0.10);
   SetSeriesFromReturns(request.series[2],"SYNTH-B",start,second);
   request.expected_latest_close_time=start+(60*86400);
   request.override_count=2;
   request.overrides[0].first_symbol="ETHUSD.s";
   request.overrides[0].second_symbol="SYNTH-B";
   request.overrides[1].first_symbol="SYNTH-B";
   request.overrides[1].second_symbol="SYNTH-C";
   ZeroMemory(prior);
   KingEAEvaluateCorrelation(request,prior,decision);
   Check(decision.healthy && decision.member_count==3 &&
         decision.members[0].symbol_id=="ETHUSD.s" &&
         decision.members[0].cluster_key=="ETHUSD.s" &&
         decision.members[1].cluster_key=="ETHUSD.s" &&
         decision.members[2].cluster_key=="ETHUSD.s",
         "static overrides form a transitive lexicographic cluster");

   request=PairRequest(0.20,start,false);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(!decision.cluster_known && pair>=0 &&
         decision.pairs[pair].edge_active,
         "stale synthetic symbol defaults to correlated and unknown");
   request=PairRequest(0.20,start);
   request.series[1].point_count=0;
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(!decision.cluster_known && pair>=0 &&
         decision.pairs[pair].edge_active,
         "missing synthetic series defaults to correlated and unknown");
   request=PairRequest(0.20,start);
   double short_returns[];
   ArrayResize(short_returns,29);
   for(int i=0;i<29;i++)
      short_returns[i]=(i%2==0 ? 0.001 : -0.001);
   SetSeriesFromReturns(request.series[1],"SYNTH-B",start+(31*86400),
                        short_returns,true);
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(!decision.cluster_known && pair>=0 &&
         decision.pairs[pair].reason==
            KINGEA_CORRELATION_REASON_INSUFFICIENT_OVERLAP &&
         decision.pairs[pair].edge_active,
         "insufficient synthetic history defaults to correlated");
   request=PairRequest(0.20,start);
   for(int i=0;i<request.series[1].point_count;i++)
      request.series[1].closes[i]=100.0;
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(!decision.cluster_known && pair>=0 &&
         decision.pairs[pair].reason==KINGEA_CORRELATION_REASON_ZERO_VARIANCE &&
         decision.pairs[pair].edge_active,
         "zero-variance synthetic history defaults to correlated");
   request=PairRequest(0.20,start);
   request.series[1].close_times[20]=request.series[1].close_times[19];
   KingEAEvaluateCorrelation(request,prior,decision);
   Check(!decision.cluster_known,
         "timestamp conflict defaults to correlated and unknown");

   request=PairRequest(0.20,start);
   request.override_count=1;
   request.overrides[0].first_symbol="ETHUSD.s";
   request.overrides[0].second_symbol="SYNTH-B";
   prior.pair_count=1;
   prior.pairs[0].pair_key="ETHUSD.s|SYNTH-B";
   prior.pairs[0].edge_active=true;
   prior.pairs[0].release_clean_days=9;
   prior.pairs[0].last_evaluation_day=request.expected_latest_close_time-86400;
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && decision.pairs[pair].edge_active &&
         decision.pairs[pair].release_clean_days==0,
         "static override cannot be released dynamically");

   request=PairRequest(0.20,start);
   prior.pair_count=1;
   prior.pairs[0].pair_key="OTHER-A|OTHER-B";
   prior.pairs[0].edge_active=true;
   prior.pairs[0].release_clean_days=9;
   prior.pairs[0].last_evaluation_day=request.expected_latest_close_time-86400;
   KingEAEvaluateCorrelation(request,prior,decision);
   pair=FindPair(decision,"ETHUSD.s|SYNTH-B");
   Check(pair>=0 && !decision.pairs[pair].edge_active &&
         decision.pairs[pair].release_clean_days==0,
         "pair state is isolated by stable pair key");

   ZeroMemory(request);
   request.symbol_count=1;
   double singleton_returns[];
   ArrayResize(singleton_returns,60);
   for(int i=0;i<60;i++)
      singleton_returns[i]=(i%2==0 ? 0.001 : -0.001);
   SetSeriesFromReturns(request.series[0],"ETHUSD.s",start,singleton_returns);
   request.expected_latest_close_time=start+(60*86400);
   KingEAEvaluateCorrelation(request,prior,decision);
   Check(decision.healthy && decision.cluster_known &&
         decision.member_count==1 &&
         decision.members[0].symbol_id=="ETHUSD.s" &&
         decision.members[0].cluster_key=="ETHUSD.s",
         "operational ETHUSD.s registration is a healthy singleton");
  }

void OnStart()
  {
   KingEARegimeDecision regime={};
   KingEACorrelationDecision correlation={};
   TestRegimeClassifier(regime);
   TestCorrelationClustering(correlation);
   WriteContractReport(regime,correlation);
   PrintFormat("KINGEA_STAGE10_TEST_RESULT=%s; checks=%d; failures=%d; order_capability=PROHIBITED_AND_ABSENT",
               (g_failures==0 ? "PASS" : "FAIL"),g_checks,g_failures);
  }
