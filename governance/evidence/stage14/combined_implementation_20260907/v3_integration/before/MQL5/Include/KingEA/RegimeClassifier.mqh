#ifndef KINGEA_REGIME_CLASSIFIER_MQH
#define KINGEA_REGIME_CLASSIFIER_MQH

#define KINGEA_REGIME_ATR_PERIOD 14
#define KINGEA_REGIME_ADX_PERIOD 14
#define KINGEA_REGIME_M30_SECONDS 1800
#define KINGEA_REGIME_LOOKBACK_SECONDS 7776000

enum KingEAStage10TrendRegime
  {
   KINGEA_STAGE10_TREND_TRANSITIONAL=0,
   KINGEA_STAGE10_TREND_TRENDING=1,
   KINGEA_STAGE10_TREND_RANGING=2
  };

enum KingEAStage10VolatilityRegime
  {
   KINGEA_STAGE10_VOLATILITY_INVALID=0,
   KINGEA_STAGE10_VOLATILITY_NORMAL=1,
   KINGEA_STAGE10_VOLATILITY_HIGH=2,
   KINGEA_STAGE10_VOLATILITY_EXTREME=3
  };

enum KingEARegimeReason
  {
   KINGEA_REGIME_REASON_OK=0,
   KINGEA_REGIME_REASON_INVALID_REQUEST=1,
   KINGEA_REGIME_REASON_MALFORMED_BAR=2,
   KINGEA_REGIME_REASON_TIMESTAMP_ORDER=3,
   KINGEA_REGIME_REASON_BAR_MISALIGNED=4,
   KINGEA_REGIME_REASON_FORMING_BAR=5,
   KINGEA_REGIME_REASON_STALE=6,
   KINGEA_REGIME_REASON_UNDEFINED_INDICATOR=7,
   KINGEA_REGIME_REASON_INSUFFICIENT_COVERAGE=8,
   KINGEA_REGIME_REASON_TREND_TRANSITION=9,
   KINGEA_REGIME_REASON_VOLATILITY_TRANSITION=10,
   KINGEA_REGIME_REASON_REGIME_BLOCK=11,
   KINGEA_REGIME_REASON_DATA_GAP=12
  };

struct KingEARegimeBar
  {
   datetime open_time;
   double open;
   double high;
   double low;
   double close;
   bool complete;
  };

struct KingEARegimeRequest
  {
   datetime evaluation_time;
   int expected_open_slots;
   int maximum_staleness_seconds;
  };

struct KingEARegimeHysteresis
  {
   int trend_state;
   int trend_pending_state;
   int trend_pending_count;
   int volatility_state;
   int volatility_pending_state;
   int volatility_pending_count;
   datetime last_observation_time;
  };

struct KingEARegimeDecision
  {
   int trend_state;
   int volatility_state;
   double atr;
   double adx;
   double normalized_atr;
   double percentile;
   int valid_percentile_samples;
   int strictly_less_samples;
   bool healthy;
   bool entry_eligible;
   KingEARegimeReason reason;
   KingEARegimeHysteresis next_state;
  };

bool KingEARegimeFinite(const double value)
  {
   return MathIsValidNumber(value);
  }

bool KingEARegimeStrictlyLess(const double historical,const double current)
  {
   double tolerance=MathMax(1e-15,
                            1e-12*MathMax(MathAbs(historical),
                                          MathAbs(current)));
   return historical<current-tolerance;
  }

bool KingEARegimeBarValid(const KingEARegimeBar &bar)
  {
   return bar.complete && bar.open_time>0 &&
          KingEARegimeFinite(bar.open) && KingEARegimeFinite(bar.high) &&
          KingEARegimeFinite(bar.low) && KingEARegimeFinite(bar.close) &&
          bar.open>0.0 && bar.high>0.0 && bar.low>0.0 && bar.close>0.0 &&
          bar.high>=bar.low && bar.high>=bar.open && bar.high>=bar.close &&
          bar.low<=bar.open && bar.low<=bar.close;
  }

double KingEARegimeTrueRange(const KingEARegimeBar &current,
                            const KingEARegimeBar &previous)
  {
   double high_low=current.high-current.low;
   double high_close=MathAbs(current.high-previous.close);
   double low_close=MathAbs(current.low-previous.close);
   return MathMax(high_low,MathMax(high_close,low_close));
  }

void KingEARegimeCalculateIndicators(const KingEARegimeBar &bars[],
                                     double &atr[],
                                     double &adx[],
                                     bool &ok)
  {
   ok=false;
   int count=ArraySize(bars);
   ArrayResize(atr,count);
   ArrayResize(adx,count);
   ArrayInitialize(atr,0.0);
   ArrayInitialize(adx,0.0);
   if(count<(KINGEA_REGIME_ATR_PERIOD+KINGEA_REGIME_ADX_PERIOD))
      return;

   double tr[],plus_dm[],minus_dm[],dx[];
   ArrayResize(tr,count);
   ArrayResize(plus_dm,count);
   ArrayResize(minus_dm,count);
   ArrayResize(dx,count);
   ArrayInitialize(tr,0.0);
   ArrayInitialize(plus_dm,0.0);
   ArrayInitialize(minus_dm,0.0);
   ArrayInitialize(dx,0.0);

   for(int i=1;i<count;i++)
     {
      tr[i]=KingEARegimeTrueRange(bars[i],bars[i-1]);
      double up=bars[i].high-bars[i-1].high;
      double down=bars[i-1].low-bars[i].low;
      plus_dm[i]=(up>down && up>0.0 ? up : 0.0);
      minus_dm[i]=(down>up && down>0.0 ? down : 0.0);
     }

   double smoothed_tr=0.0;
   double smoothed_plus=0.0;
   double smoothed_minus=0.0;
   for(int i=1;i<=KINGEA_REGIME_ATR_PERIOD;i++)
     {
      smoothed_tr+=tr[i];
      smoothed_plus+=plus_dm[i];
      smoothed_minus+=minus_dm[i];
     }
   atr[KINGEA_REGIME_ATR_PERIOD]=smoothed_tr/KINGEA_REGIME_ATR_PERIOD;
   if(smoothed_tr<=0.0)
      return;
   double plus_di=100.0*smoothed_plus/smoothed_tr;
   double minus_di=100.0*smoothed_minus/smoothed_tr;
   double denominator=plus_di+minus_di;
   if(denominator<=0.0)
      return;
   dx[KINGEA_REGIME_ATR_PERIOD]=
      100.0*MathAbs(plus_di-minus_di)/denominator;

   for(int i=KINGEA_REGIME_ATR_PERIOD+1;i<count;i++)
     {
      smoothed_tr=smoothed_tr-(smoothed_tr/KINGEA_REGIME_ATR_PERIOD)+tr[i];
      smoothed_plus=smoothed_plus-
                    (smoothed_plus/KINGEA_REGIME_ATR_PERIOD)+plus_dm[i];
      smoothed_minus=smoothed_minus-
                     (smoothed_minus/KINGEA_REGIME_ATR_PERIOD)+minus_dm[i];
      atr[i]=smoothed_tr/KINGEA_REGIME_ATR_PERIOD;
      if(smoothed_tr<=0.0)
         return;
      plus_di=100.0*smoothed_plus/smoothed_tr;
      minus_di=100.0*smoothed_minus/smoothed_tr;
      denominator=plus_di+minus_di;
      if(denominator<=0.0)
         return;
      dx[i]=100.0*MathAbs(plus_di-minus_di)/denominator;
     }

   int adx_seed_index=(KINGEA_REGIME_ADX_PERIOD*2)-1;
   double adx_sum=0.0;
   for(int i=KINGEA_REGIME_ATR_PERIOD;i<=adx_seed_index;i++)
      adx_sum+=dx[i];
   adx[adx_seed_index]=adx_sum/KINGEA_REGIME_ADX_PERIOD;
   for(int i=adx_seed_index+1;i<count;i++)
      adx[i]=((adx[i-1]*(KINGEA_REGIME_ADX_PERIOD-1))+dx[i])/
             KINGEA_REGIME_ADX_PERIOD;
   ok=KingEARegimeFinite(atr[count-1]) &&
      KingEARegimeFinite(adx[count-1]) &&
      atr[count-1]>0.0;
  }

int KingEARegimeRawTrend(const double adx)
  {
   if(adx>=25.0)
      return KINGEA_STAGE10_TREND_TRENDING;
   if(adx<20.0)
      return KINGEA_STAGE10_TREND_RANGING;
   return KINGEA_STAGE10_TREND_TRANSITIONAL;
  }

int KingEARegimeRawVolatility(const double percentile)
  {
   if(percentile<80.0)
      return KINGEA_STAGE10_VOLATILITY_NORMAL;
   if(percentile<=95.0)
      return KINGEA_STAGE10_VOLATILITY_HIGH;
   return KINGEA_STAGE10_VOLATILITY_EXTREME;
  }

int KingEARegimeApplyTrendHysteresis(const int raw,
                                     const datetime observation_time,
                                     const KingEARegimeHysteresis &prior,
                                     KingEARegimeHysteresis &next)
  {
   next=prior;
   if(prior.last_observation_time>0 &&
      observation_time<=prior.last_observation_time)
      return KINGEA_STAGE10_TREND_TRANSITIONAL;
   bool established=(prior.trend_state==KINGEA_STAGE10_TREND_TRENDING ||
                     prior.trend_state==KINGEA_STAGE10_TREND_RANGING);
   if(raw==KINGEA_STAGE10_TREND_TRANSITIONAL)
     {
      next.trend_pending_state=KINGEA_STAGE10_TREND_TRANSITIONAL;
      next.trend_pending_count=0;
      return established ? prior.trend_state : KINGEA_STAGE10_TREND_TRANSITIONAL;
     }
   if(established && raw==prior.trend_state)
     {
      next.trend_pending_state=KINGEA_STAGE10_TREND_TRANSITIONAL;
      next.trend_pending_count=0;
      return prior.trend_state;
     }
   bool consecutive=(prior.last_observation_time==0 ||
                     observation_time-prior.last_observation_time==
                        KINGEA_REGIME_M30_SECONDS);
   if(prior.trend_pending_state==raw && consecutive)
      next.trend_pending_count=prior.trend_pending_count+1;
   else
     {
      next.trend_pending_state=raw;
      next.trend_pending_count=1;
     }
   if(next.trend_pending_count>=2)
     {
      next.trend_state=raw;
      next.trend_pending_state=KINGEA_STAGE10_TREND_TRANSITIONAL;
      next.trend_pending_count=0;
      return raw;
     }
   return KINGEA_STAGE10_TREND_TRANSITIONAL;
  }

int KingEARegimeApplyVolatilityHysteresis(const int raw,
                                          const datetime observation_time,
                                          const KingEARegimeHysteresis &prior,
                                          KingEARegimeHysteresis &next)
  {
   if(prior.last_observation_time>0 &&
      observation_time<=prior.last_observation_time)
      return KINGEA_STAGE10_VOLATILITY_INVALID;
   bool established=(prior.volatility_state>=KINGEA_STAGE10_VOLATILITY_NORMAL &&
                     prior.volatility_state<=KINGEA_STAGE10_VOLATILITY_EXTREME);
   if(established && raw==prior.volatility_state)
     {
      next.volatility_pending_state=KINGEA_STAGE10_VOLATILITY_INVALID;
      next.volatility_pending_count=0;
      return prior.volatility_state;
     }
   bool consecutive=(prior.last_observation_time==0 ||
                     observation_time-prior.last_observation_time==
                        KINGEA_REGIME_M30_SECONDS);
   if(prior.volatility_pending_state==raw && consecutive)
      next.volatility_pending_count=prior.volatility_pending_count+1;
   else
     {
      next.volatility_pending_state=raw;
      next.volatility_pending_count=1;
     }
   if(next.volatility_pending_count>=2)
     {
      next.volatility_state=raw;
      next.volatility_pending_state=KINGEA_STAGE10_VOLATILITY_INVALID;
      next.volatility_pending_count=0;
      return raw;
     }
   return KINGEA_STAGE10_VOLATILITY_INVALID;
  }

void KingEARegimeFail(KingEARegimeDecision &decision,
                      const KingEARegimeReason reason,
                      const KingEARegimeHysteresis &prior)
  {
   ZeroMemory(decision);
   decision.trend_state=KINGEA_STAGE10_TREND_TRANSITIONAL;
   decision.volatility_state=KINGEA_STAGE10_VOLATILITY_INVALID;
   decision.reason=reason;
   decision.next_state=prior;
  }

// Sole Stage 10 regime-classifier interface.
void KingEAEvaluateRegime(const KingEARegimeBar &bars[],
                          const KingEARegimeRequest &request,
                          const KingEARegimeHysteresis &prior,
                          KingEARegimeDecision &decision)
  {
   KingEARegimeFail(decision,KINGEA_REGIME_REASON_INVALID_REQUEST,prior);
   int count=ArraySize(bars);
   if(request.evaluation_time<=0 || request.expected_open_slots<=0 ||
      request.maximum_staleness_seconds<0 ||
      count<(KINGEA_REGIME_ATR_PERIOD+KINGEA_REGIME_ADX_PERIOD))
      return;
   for(int i=0;i<count;i++)
     {
      if(!KingEARegimeBarValid(bars[i]))
        {
         decision.reason=KINGEA_REGIME_REASON_MALFORMED_BAR;
         return;
        }
      if(((long)bars[i].open_time%KINGEA_REGIME_M30_SECONDS)!=0)
        {
         decision.reason=KINGEA_REGIME_REASON_BAR_MISALIGNED;
         return;
        }
      if(i>0 && bars[i].open_time<=bars[i-1].open_time)
        {
         decision.reason=KINGEA_REGIME_REASON_TIMESTAMP_ORDER;
         return;
        }
      if(i>0 && bars[i].open_time-bars[i-1].open_time!=
                KINGEA_REGIME_M30_SECONDS)
        {
         decision.reason=KINGEA_REGIME_REASON_DATA_GAP;
         return;
        }
     }
   datetime closed_at=bars[count-1].open_time+KINGEA_REGIME_M30_SECONDS;
   if(closed_at>request.evaluation_time)
     {
      decision.reason=KINGEA_REGIME_REASON_FORMING_BAR;
      return;
     }
   if((long)(request.evaluation_time-closed_at)>
      (long)request.maximum_staleness_seconds)
     {
      decision.reason=KINGEA_REGIME_REASON_STALE;
      return;
     }

   double atr[],adx[];
   bool indicators_ok=false;
   KingEARegimeCalculateIndicators(bars,atr,adx,indicators_ok);
   if(!indicators_ok)
     {
      decision.reason=KINGEA_REGIME_REASON_UNDEFINED_INDICATOR;
      return;
     }

   int current=count-1;
   double current_normalized=atr[current]/bars[current].close;
   if(!KingEARegimeFinite(current_normalized) || current_normalized<=0.0)
     {
      decision.reason=KINGEA_REGIME_REASON_UNDEFINED_INDICATOR;
      return;
     }
   datetime window_start=bars[current].open_time-KINGEA_REGIME_LOOKBACK_SECONDS;
   int valid=0;
   int strictly_less=0;
   for(int i=KINGEA_REGIME_ATR_PERIOD;i<current;i++)
     {
      if(bars[i].open_time<window_start)
         continue;
      double historical=atr[i]/bars[i].close;
      if(!KingEARegimeFinite(historical) || historical<=0.0)
         continue;
      valid++;
      if(KingEARegimeStrictlyLess(historical,current_normalized))
         strictly_less++;
     }
   int required=(int)MathCeil(request.expected_open_slots*0.95);
   if(valid<required)
     {
      decision.valid_percentile_samples=valid;
      decision.reason=KINGEA_REGIME_REASON_INSUFFICIENT_COVERAGE;
      return;
     }

   decision.atr=atr[current];
   decision.adx=adx[current];
   decision.normalized_atr=current_normalized;
   decision.valid_percentile_samples=valid;
   decision.strictly_less_samples=strictly_less;
   decision.percentile=100.0*strictly_less/valid;
   int raw_trend=KingEARegimeRawTrend(decision.adx);
   int raw_volatility=KingEARegimeRawVolatility(decision.percentile);
   decision.next_state=prior;
   decision.trend_state=
      KingEARegimeApplyTrendHysteresis(raw_trend,bars[current].open_time,
                                       prior,decision.next_state);
   KingEARegimeHysteresis trend_applied=decision.next_state;
   decision.volatility_state=
      KingEARegimeApplyVolatilityHysteresis(raw_volatility,
                                            bars[current].open_time,
                                            trend_applied,
                                            decision.next_state);
   decision.next_state.last_observation_time=bars[current].open_time;
   decision.healthy=true;
   decision.entry_eligible=
      decision.trend_state==KINGEA_STAGE10_TREND_TRENDING &&
      (decision.volatility_state==KINGEA_STAGE10_VOLATILITY_NORMAL ||
       decision.volatility_state==KINGEA_STAGE10_VOLATILITY_HIGH);
   if(decision.trend_state==KINGEA_STAGE10_TREND_TRANSITIONAL)
      decision.reason=KINGEA_REGIME_REASON_TREND_TRANSITION;
   else if(decision.volatility_state==KINGEA_STAGE10_VOLATILITY_INVALID)
      decision.reason=KINGEA_REGIME_REASON_VOLATILITY_TRANSITION;
   else if(!decision.entry_eligible)
      decision.reason=KINGEA_REGIME_REASON_REGIME_BLOCK;
   else
      decision.reason=KINGEA_REGIME_REASON_OK;
  }

#endif
