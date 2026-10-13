#ifndef KINGEA_SLEEVE_ETH_ST_001_MQH
#define KINGEA_SLEEVE_ETH_ST_001_MQH

#include <KingEA/CandidateEthSt001.mqh>
#include <KingEA/RegimeClassifier.mqh>

#define KINGEA_SLEEVE_M30_SECONDS 1800
#define KINGEA_SLEEVE_H4_SECONDS 14400
#define KINGEA_SLEEVE_FIRST_SIGNAL D'2021.07.01 00:00:00'

enum KingEASleeveAction
  {
   KINGEA_SLEEVE_ACTION_NONE=0,
   KINGEA_SLEEVE_ACTION_ENTRY=1,
   KINGEA_SLEEVE_ACTION_EXIT=2,
   KINGEA_SLEEVE_ACTION_HOLD=3
  };

enum KingEASleeveReason
  {
   KINGEA_SLEEVE_REASON_OK=0,
   KINGEA_SLEEVE_REASON_INVALID_REQUEST=1,
   KINGEA_SLEEVE_REASON_INVALID_PARAMETERS=2,
   KINGEA_SLEEVE_REASON_MALFORMED_BAR=3,
   KINGEA_SLEEVE_REASON_TIMESTAMP_ORDER=4,
   KINGEA_SLEEVE_REASON_BAR_MISALIGNED=5,
   KINGEA_SLEEVE_REASON_FORMING_BAR=6,
   KINGEA_SLEEVE_REASON_STALE=7,
   KINGEA_SLEEVE_REASON_DUPLICATE_OR_BACKWARD=8,
   KINGEA_SLEEVE_REASON_WARMUP_ONLY=9,
   KINGEA_SLEEVE_REASON_INSUFFICIENT_HISTORY=10,
   KINGEA_SLEEVE_REASON_H4_DERIVATION_FAILED=11,
   KINGEA_SLEEVE_REASON_INDICATOR_FAILED=12,
   KINGEA_SLEEVE_REASON_REGIME_MISMATCH=13,
   KINGEA_SLEEVE_REASON_REGIME_BLOCK=14,
   KINGEA_SLEEVE_REASON_INVALID_POSITION=15,
   KINGEA_SLEEVE_REASON_OPEN_GROUP_EXISTS=16,
   KINGEA_SLEEVE_REASON_NO_FRESH_BREAKOUT=17,
   KINGEA_SLEEVE_REASON_ENTRY=18,
   KINGEA_SLEEVE_REASON_EXIT=19,
   KINGEA_SLEEVE_REASON_HOLD=20
  };

struct KingEASleeveBar
  {
   datetime open_time;
   double open;
   double high;
   double low;
   double close;
   bool complete;
  };

struct KingEASleevePositionContext
  {
   bool has_position;
   int direction;
   datetime entry_signal_bar_time;
   double entry_price;
   double original_confirmed_stop;
   bool original_stop_confirmed;
  };

struct KingEASleeveRequest
  {
   datetime evaluation_time;
   KingEACandidateParameters parameters;
   KingEARegimeDecision regime;
   KingEASleevePositionContext position;
   bool has_open_trade_group;
  };

struct KingEASleeveState
  {
   datetime last_evaluated_m30_bar;
  };

struct KingEASleeveTrace
  {
   double m30_atr;
   double previous_m30_atr;
   int m30_supertrend_direction;
   double m30_supertrend_line;
   int h4_supertrend_direction;
   double breakout_high;
   double previous_breakout_high;
   double breakout_low;
   double previous_breakout_low;
  };

struct KingEASleeveDecision
  {
   bool healthy;
   bool blocked;
   KingEASleeveAction action;
   int direction;
   double technical_stop;
   datetime signal_bar_time;
   string signal_identity;
   int bars_held;
   double maximum_favourable_excursion_r;
   KingEASleeveReason reason;
   string candidate_reason;
   KingEASleeveState next_state;
   KingEASleeveTrace trace;
  };

bool KingEASleeveFinite(const double value)
  {
   return MathIsValidNumber(value);
  }

bool KingEASleeveNear(const double first,const double second)
  {
   return MathAbs(first-second)<=1e-10;
  }

bool KingEASleeveIntIn(const int value,const int &values[])
  {
   for(int i=0;i<ArraySize(values);i++)
      if(value==values[i])
         return true;
   return false;
  }

bool KingEASleeveDoubleIn(const double value,const double &values[])
  {
   if(!KingEASleeveFinite(value))
      return false;
   for(int i=0;i<ArraySize(values);i++)
      if(KingEASleeveNear(value,values[i]))
         return true;
   return false;
  }

bool KingEASleeveFrozenParameters(const KingEACandidateParameters &parameters)
  {
   int atr_periods[]={10,14,18,22};
   double multipliers[]={2.0,2.5,3.0,3.5,4.0};
   int lookbacks[]={6,12,18,24};
   double entry_buffers[]={0.0,0.1,0.2};
   double stop_buffers[]={0.0,0.25,0.5};
   int checkpoints[]={8,12,16};
   double progress_values[]={0.25,0.5,0.75};
   int holding_periods[]={48,72,96};
   return KingEASleeveIntIn(parameters.atr_period,atr_periods) &&
          KingEASleeveDoubleIn(parameters.supertrend_multiplier,multipliers) &&
          KingEASleeveIntIn(parameters.breakout_lookback_bars,lookbacks) &&
          KingEASleeveDoubleIn(parameters.entry_buffer_atr,entry_buffers) &&
          KingEASleeveDoubleIn(parameters.stop_buffer_atr,stop_buffers) &&
          KingEASleeveIntIn(parameters.progress_checkpoint_bars,checkpoints) &&
          KingEASleeveDoubleIn(parameters.required_progress_r,progress_values) &&
          KingEASleeveIntIn(parameters.maximum_holding_bars,holding_periods);
  }

bool KingEASleeveBarValid(const KingEASleeveBar &bar)
  {
   return bar.complete && bar.open_time>0 &&
          KingEASleeveFinite(bar.open) && KingEASleeveFinite(bar.high) &&
          KingEASleeveFinite(bar.low) && KingEASleeveFinite(bar.close) &&
          bar.open>0.0 && bar.high>0.0 && bar.low>0.0 && bar.close>0.0 &&
          bar.high>=bar.low && bar.high>=bar.open && bar.high>=bar.close &&
          bar.low<=bar.open && bar.low<=bar.close;
  }

double KingEASleeveTrueRange(const KingEASleeveBar &current,
                             const KingEASleeveBar &previous)
  {
   return MathMax(current.high-current.low,
                  MathMax(MathAbs(current.high-previous.close),
                          MathAbs(current.low-previous.close)));
  }

bool KingEASleeveCalculateAtr(const KingEASleeveBar &bars[],
                              const int period,
                              double &atr[])
  {
   int count=ArraySize(bars);
   ArrayResize(atr,count);
   ArrayInitialize(atr,0.0);
   if(period<=0 || count<=period)
      return false;
   double sum=0.0;
   for(int i=1;i<=period;i++)
      sum+=KingEASleeveTrueRange(bars[i],bars[i-1]);
   atr[period]=sum/period;
   if(!KingEASleeveFinite(atr[period]) || atr[period]<=0.0)
      return false;
   for(int i=period+1;i<count;i++)
     {
      double tr=KingEASleeveTrueRange(bars[i],bars[i-1]);
      atr[i]=((atr[i-1]*(period-1))+tr)/period;
      if(!KingEASleeveFinite(atr[i]) || atr[i]<=0.0)
         return false;
     }
   return true;
  }

bool KingEASleeveCalculateSupertrend(const KingEASleeveBar &bars[],
                                     const double &atr[],
                                     const int period,
                                     const double multiplier,
                                     int &directions[],
                                     double &lines[])
  {
   int count=ArraySize(bars);
   if(count<=period || ArraySize(atr)!=count)
      return false;
   ArrayResize(directions,count);
   ArrayResize(lines,count);
   ArrayInitialize(directions,KINGEA_DIRECTION_NONE);
   ArrayInitialize(lines,0.0);
   double final_upper[],final_lower[];
   ArrayResize(final_upper,count);
   ArrayResize(final_lower,count);
   ArrayInitialize(final_upper,0.0);
   ArrayInitialize(final_lower,0.0);

   for(int i=period;i<count;i++)
     {
      double midpoint=(bars[i].high+bars[i].low)/2.0;
      double basic_upper=midpoint+(multiplier*atr[i]);
      double basic_lower=midpoint-(multiplier*atr[i]);
      if(i==period)
        {
         final_upper[i]=basic_upper;
         final_lower[i]=basic_lower;
         directions[i]=(bars[i].close>=midpoint ?
                        KINGEA_DIRECTION_LONG : KINGEA_DIRECTION_SHORT);
        }
      else
        {
         final_upper[i]=(basic_upper<final_upper[i-1] ||
                         bars[i-1].close>final_upper[i-1] ?
                         basic_upper : final_upper[i-1]);
         final_lower[i]=(basic_lower>final_lower[i-1] ||
                         bars[i-1].close<final_lower[i-1] ?
                         basic_lower : final_lower[i-1]);
         if(directions[i-1]==KINGEA_DIRECTION_LONG)
            directions[i]=(bars[i].close<final_lower[i] ?
                           KINGEA_DIRECTION_SHORT : KINGEA_DIRECTION_LONG);
         else if(directions[i-1]==KINGEA_DIRECTION_SHORT)
            directions[i]=(bars[i].close>final_upper[i] ?
                           KINGEA_DIRECTION_LONG : KINGEA_DIRECTION_SHORT);
         else
            return false;
        }
      lines[i]=(directions[i]==KINGEA_DIRECTION_LONG ?
                final_lower[i] : final_upper[i]);
      if(!KingEASleeveFinite(lines[i]))
         return false;
     }
   return true;
  }

bool KingEASleeveBuildH4(const KingEASleeveBar &m30[],
                          const datetime evaluation_time,
                          KingEASleeveBar &h4[])
  {
   ArrayResize(h4,0);
   int count=ArraySize(m30);
   if(count<8 || ((long)m30[0].open_time%KINGEA_SLEEVE_H4_SECONDS)!=0)
      return false;
   int output=0;
   for(int start=0;start+7<count;start+=8)
     {
      datetime bucket=m30[start].open_time;
      if(((long)bucket%KINGEA_SLEEVE_H4_SECONDS)!=0)
         return false;
      if(bucket+KINGEA_SLEEVE_H4_SECONDS>evaluation_time)
         break;
      for(int j=0;j<8;j++)
         if(m30[start+j].open_time!=bucket+(j*KINGEA_SLEEVE_M30_SECONDS))
            return false;
      ArrayResize(h4,output+1);
      h4[output].open_time=bucket;
      h4[output].open=m30[start].open;
      h4[output].high=m30[start].high;
      h4[output].low=m30[start].low;
      h4[output].close=m30[start+7].close;
      h4[output].complete=true;
      for(int j=1;j<8;j++)
        {
         h4[output].high=MathMax(h4[output].high,m30[start+j].high);
         h4[output].low=MathMin(h4[output].low,m30[start+j].low);
        }
      output++;
     }
   return output>0;
  }

bool KingEASleeveBreakoutLevels(const KingEASleeveBar &bars[],
                                 const int lookback,
                                 double &current_high,
                                 double &previous_high,
                                 double &current_low,
                                 double &previous_low)
  {
   int current=ArraySize(bars)-1;
   if(lookback<=0 || current<lookback+1)
      return false;
   current_high=bars[current-lookback].high;
   current_low=bars[current-lookback].low;
   previous_high=bars[current-lookback-1].high;
   previous_low=bars[current-lookback-1].low;
   for(int i=current-lookback;i<=current-1;i++)
     {
      current_high=MathMax(current_high,bars[i].high);
      current_low=MathMin(current_low,bars[i].low);
     }
   for(int i=current-lookback-1;i<=current-2;i++)
     {
      previous_high=MathMax(previous_high,bars[i].high);
      previous_low=MathMin(previous_low,bars[i].low);
     }
   return true;
  }

bool KingEASleeveMapRegime(const KingEARegimeDecision &regime,
                            int &trend,
                            int &volatility)
  {
   trend=KINGEA_TREND_TRANSITIONAL;
   volatility=KINGEA_VOLATILITY_INVALID;
   if(regime.trend_state==KINGEA_STAGE10_TREND_TRENDING)
      trend=KINGEA_TREND_TRENDING;
   else if(regime.trend_state==KINGEA_STAGE10_TREND_RANGING)
      trend=KINGEA_TREND_RANGING;
   else if(regime.trend_state!=KINGEA_STAGE10_TREND_TRANSITIONAL)
      return false;
   if(regime.volatility_state==KINGEA_STAGE10_VOLATILITY_NORMAL)
      volatility=KINGEA_VOLATILITY_NORMAL;
   else if(regime.volatility_state==KINGEA_STAGE10_VOLATILITY_HIGH)
      volatility=KINGEA_VOLATILITY_HIGH;
   else if(regime.volatility_state==KINGEA_STAGE10_VOLATILITY_EXTREME)
      volatility=KINGEA_VOLATILITY_EXTREME;
   else if(regime.volatility_state!=KINGEA_STAGE10_VOLATILITY_INVALID)
      return false;
   return true;
  }

bool KingEASleevePositionFacts(const KingEASleeveBar &bars[],
                                const KingEASleevePositionContext &context,
                                const int m30_direction,
                                KingEAPositionFacts &facts,
                                int &bars_held,
                                double &mfe_r)
  {
   ZeroMemory(facts);
   bars_held=0;
   mfe_r=0.0;
   if(!context.has_position)
      return true;
   if((context.direction!=KINGEA_DIRECTION_LONG &&
       context.direction!=KINGEA_DIRECTION_SHORT) ||
      context.entry_signal_bar_time<=0 ||
      !context.original_stop_confirmed ||
      !KingEASleeveFinite(context.entry_price) ||
      !KingEASleeveFinite(context.original_confirmed_stop) ||
      context.entry_price<=0.0 ||
      (context.direction==KINGEA_DIRECTION_LONG &&
       context.original_confirmed_stop>=context.entry_price) ||
      (context.direction==KINGEA_DIRECTION_SHORT &&
       context.original_confirmed_stop<=context.entry_price))
      return false;
   int last=ArraySize(bars)-1;
   if(context.entry_signal_bar_time>=bars[last].open_time)
      return false;
   double original_r=MathAbs(context.entry_price-
                             context.original_confirmed_stop);
   if(!KingEASleeveFinite(original_r) || original_r<=0.0)
      return false;
   double best=context.entry_price;
   for(int i=0;i<=last;i++)
     {
      if(bars[i].open_time<=context.entry_signal_bar_time)
         continue;
      bars_held++;
      if(context.direction==KINGEA_DIRECTION_LONG)
         best=MathMax(best,bars[i].high);
      else
         best=MathMin(best,bars[i].low);
     }
   mfe_r=(context.direction==KINGEA_DIRECTION_LONG ?
          (best-context.entry_price)/original_r :
          (context.entry_price-best)/original_r);
   facts.has_position=true;
   facts.direction=context.direction;
   facts.bars_held=bars_held;
   facts.maximum_favourable_excursion_r=mfe_r;
   facts.opposite_m30_supertrend=(m30_direction!=context.direction);
   return KingEASleeveFinite(mfe_r) && mfe_r>=0.0;
  }

string KingEASleeveSignalIdentity(const datetime signal_time,
                                   const int direction)
  {
   return "CAND-ETH-ST-001|"+
          IntegerToString((long)signal_time)+"|"+
          IntegerToString(direction);
  }

void KingEASleeveResetDecision(const KingEASleeveState &prior,
                                KingEASleeveDecision &decision)
  {
   ZeroMemory(decision);
   decision.blocked=true;
   decision.action=KINGEA_SLEEVE_ACTION_NONE;
   decision.reason=KINGEA_SLEEVE_REASON_INVALID_REQUEST;
   decision.next_state=prior;
  }

// Sole Stage 11 Sleeve 1 interface.
void KingEAEvaluateSleeveEthSt001(const KingEASleeveBar &bars[],
                                  const KingEASleeveRequest &request,
                                  const KingEASleeveState &prior,
                                  KingEASleeveDecision &decision)
  {
   KingEASleeveResetDecision(prior,decision);
   int count=ArraySize(bars);
   if(request.evaluation_time<=0 || count<=0)
      return;
   for(int i=0;i<count;i++)
     {
      if(!KingEASleeveBarValid(bars[i]))
        {
         decision.reason=KINGEA_SLEEVE_REASON_MALFORMED_BAR;
         return;
        }
      if(((long)bars[i].open_time%KINGEA_SLEEVE_M30_SECONDS)!=0)
        {
         decision.reason=KINGEA_SLEEVE_REASON_BAR_MISALIGNED;
         return;
        }
      if(i>0 && bars[i].open_time<=bars[i-1].open_time)
        {
         decision.reason=KINGEA_SLEEVE_REASON_TIMESTAMP_ORDER;
         return;
        }
      if(i>0 && bars[i].open_time-bars[i-1].open_time!=
                KINGEA_SLEEVE_M30_SECONDS)
        {
         decision.reason=KINGEA_SLEEVE_REASON_TIMESTAMP_ORDER;
         return;
        }
     }
   int current=count-1;
   datetime signal_time=bars[current].open_time;
   datetime closed_at=signal_time+KINGEA_SLEEVE_M30_SECONDS;
   decision.signal_bar_time=signal_time;
   if(closed_at>request.evaluation_time)
     {
      decision.reason=KINGEA_SLEEVE_REASON_FORMING_BAR;
      return;
     }
   if(request.evaluation_time-closed_at>KINGEA_SLEEVE_M30_SECONDS)
     {
      decision.reason=KINGEA_SLEEVE_REASON_STALE;
      return;
     }
   if(prior.last_evaluated_m30_bar>0 &&
      signal_time<=prior.last_evaluated_m30_bar)
     {
      decision.reason=KINGEA_SLEEVE_REASON_DUPLICATE_OR_BACKWARD;
      return;
     }

   // A well-formed newly closed bar is consumed before downstream gates.
   decision.next_state.last_evaluated_m30_bar=signal_time;
   if(!KingEASleeveFrozenParameters(request.parameters))
     {
      decision.reason=KINGEA_SLEEVE_REASON_INVALID_PARAMETERS;
      return;
     }
   if(signal_time<KINGEA_SLEEVE_FIRST_SIGNAL)
     {
      decision.reason=KINGEA_SLEEVE_REASON_WARMUP_ONLY;
      return;
     }
   int required_h4=(request.parameters.atr_period+1)*8;
   int required_m30=MathMax(request.parameters.atr_period+2,
                            request.parameters.breakout_lookback_bars+2);
   if(count<MathMax(required_h4,required_m30))
     {
      decision.reason=KINGEA_SLEEVE_REASON_INSUFFICIENT_HISTORY;
      return;
     }

   double m30_atr[];
   int m30_directions[];
   double m30_lines[];
   if(!KingEASleeveCalculateAtr(bars,request.parameters.atr_period,m30_atr) ||
      !KingEASleeveCalculateSupertrend(bars,m30_atr,
                                       request.parameters.atr_period,
                                       request.parameters.supertrend_multiplier,
                                       m30_directions,m30_lines))
     {
      decision.reason=KINGEA_SLEEVE_REASON_INDICATOR_FAILED;
      return;
     }
   KingEASleeveBar h4[];
   if(!KingEASleeveBuildH4(bars,request.evaluation_time,h4) ||
      ArraySize(h4)<=request.parameters.atr_period)
     {
      decision.reason=KINGEA_SLEEVE_REASON_H4_DERIVATION_FAILED;
      return;
     }
   double h4_atr[];
   int h4_directions[];
   double h4_lines[];
   if(!KingEASleeveCalculateAtr(h4,request.parameters.atr_period,h4_atr) ||
      !KingEASleeveCalculateSupertrend(h4,h4_atr,
                                       request.parameters.atr_period,
                                       request.parameters.supertrend_multiplier,
                                       h4_directions,h4_lines))
     {
      decision.reason=KINGEA_SLEEVE_REASON_INDICATOR_FAILED;
      return;
     }
   if(!KingEASleeveBreakoutLevels(bars,
                                  request.parameters.breakout_lookback_bars,
                                  decision.trace.breakout_high,
                                  decision.trace.previous_breakout_high,
                                  decision.trace.breakout_low,
                                  decision.trace.previous_breakout_low))
     {
      decision.reason=KINGEA_SLEEVE_REASON_INSUFFICIENT_HISTORY;
      return;
     }

   int h4_last=ArraySize(h4)-1;
   decision.trace.m30_atr=m30_atr[current];
   decision.trace.previous_m30_atr=m30_atr[current-1];
   decision.trace.m30_supertrend_direction=m30_directions[current];
   decision.trace.m30_supertrend_line=m30_lines[current];
   decision.trace.h4_supertrend_direction=h4_directions[h4_last];

   int mapped_trend=0;
   int mapped_volatility=0;
   bool regime_valid=KingEASleeveMapRegime(request.regime,
                                            mapped_trend,
                                            mapped_volatility);
   bool regime_same_observation=
      request.regime.next_state.last_observation_time==signal_time;

   KingEAPositionFacts position={};
   if(!KingEASleevePositionFacts(bars,request.position,
                                 m30_directions[current],
                                 position,decision.bars_held,
                                 decision.maximum_favourable_excursion_r))
     {
      decision.reason=KINGEA_SLEEVE_REASON_INVALID_POSITION;
      return;
     }

   KingEAClosedBarFacts facts={};
   facts.signal_bar_time=signal_time;
   facts.inputs_complete=true;
   facts.inputs_fresh=true;
   facts.has_open_trade_group=request.has_open_trade_group;
   facts.m30_supertrend_direction=m30_directions[current];
   facts.h4_supertrend_direction=h4_directions[h4_last];
   facts.trend_regime=mapped_trend;
   facts.volatility_regime=mapped_volatility;
   facts.close_price=bars[current].close;
   facts.previous_close_price=bars[current-1].close;
   facts.breakout_high=decision.trace.breakout_high;
   facts.previous_breakout_high=decision.trace.previous_breakout_high;
   facts.breakout_low=decision.trace.breakout_low;
   facts.previous_breakout_low=decision.trace.previous_breakout_low;
   facts.atr=m30_atr[current];
   facts.previous_atr=m30_atr[current-1];
   facts.signal_bar_high=bars[current].high;
   facts.signal_bar_low=bars[current].low;
   facts.m30_supertrend_line=m30_lines[current];

   if(!request.position.has_position &&
      (!regime_valid || !request.regime.healthy ||
       !request.regime.entry_eligible || !regime_same_observation))
     {
      decision.healthy=true;
      decision.reason=(!regime_valid || !regime_same_observation ?
                       KINGEA_SLEEVE_REASON_REGIME_MISMATCH :
                       KINGEA_SLEEVE_REASON_REGIME_BLOCK);
      return;
     }

   KingEASignalIntent intent={};
   KingEAEvaluateCandidateEthSt001(facts,position,
                                   request.parameters,intent);
   decision.healthy=true;
   decision.candidate_reason=intent.reason;
   decision.direction=intent.direction;
   decision.technical_stop=intent.technical_stop;
   if(intent.entry_intent)
     {
      decision.blocked=false;
      decision.action=KINGEA_SLEEVE_ACTION_ENTRY;
      decision.reason=KINGEA_SLEEVE_REASON_ENTRY;
      decision.signal_identity=
         KingEASleeveSignalIdentity(signal_time,intent.direction);
     }
   else if(intent.exit_intent)
     {
      decision.blocked=false;
      decision.action=KINGEA_SLEEVE_ACTION_EXIT;
      decision.reason=KINGEA_SLEEVE_REASON_EXIT;
      decision.signal_identity=
         KingEASleeveSignalIdentity(signal_time,intent.direction);
     }
   else if(intent.reason=="HOLD")
     {
      decision.blocked=false;
      decision.action=KINGEA_SLEEVE_ACTION_HOLD;
      decision.reason=KINGEA_SLEEVE_REASON_HOLD;
     }
   else if(intent.reason=="OPEN_GROUP_EXISTS")
      decision.reason=KINGEA_SLEEVE_REASON_OPEN_GROUP_EXISTS;
   else if(intent.reason=="REGIME_BLOCK")
      decision.reason=KINGEA_SLEEVE_REASON_REGIME_BLOCK;
   else
      decision.reason=KINGEA_SLEEVE_REASON_NO_FRESH_BREAKOUT;
  }

#endif
