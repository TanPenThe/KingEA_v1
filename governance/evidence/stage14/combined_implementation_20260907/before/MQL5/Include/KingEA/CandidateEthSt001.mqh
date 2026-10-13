#ifndef KINGEA_CANDIDATE_ETH_ST_001_MQH
#define KINGEA_CANDIDATE_ETH_ST_001_MQH

enum KingEADirection
  {
   KINGEA_DIRECTION_NONE=0,
   KINGEA_DIRECTION_LONG=1,
   KINGEA_DIRECTION_SHORT=-1
  };

enum KingEATrendRegime
  {
   KINGEA_TREND_TRANSITIONAL=0,
   KINGEA_TREND_TRENDING=1,
   KINGEA_TREND_RANGING=2
  };

enum KingEAVolatilityRegime
  {
   KINGEA_VOLATILITY_INVALID=0,
   KINGEA_VOLATILITY_NORMAL=1,
   KINGEA_VOLATILITY_HIGH=2,
   KINGEA_VOLATILITY_EXTREME=3
  };

struct KingEACandidateParameters
  {
   int atr_period;
   double supertrend_multiplier;
   int breakout_lookback_bars;
   double entry_buffer_atr;
   double stop_buffer_atr;
   int progress_checkpoint_bars;
   double required_progress_r;
   int maximum_holding_bars;
  };

struct KingEAClosedBarFacts
  {
   datetime signal_bar_time;
   bool inputs_complete;
   bool inputs_fresh;
   bool has_open_trade_group;
   int m30_supertrend_direction;
   int h4_supertrend_direction;
   int trend_regime;
   int volatility_regime;
   double close_price;
   double previous_close_price;
   double breakout_high;
   double previous_breakout_high;
   double breakout_low;
   double previous_breakout_low;
   double atr;
   double previous_atr;
   double signal_bar_high;
   double signal_bar_low;
   double m30_supertrend_line;
  };

struct KingEAPositionFacts
  {
   bool has_position;
   int direction;
   int bars_held;
   double maximum_favourable_excursion_r;
   bool opposite_m30_supertrend;
  };

struct KingEASignalIntent
  {
   datetime signal_bar_time;
   int direction;
   bool entry_intent;
   double technical_stop;
   bool exit_intent;
   string reason;
  };

void KingEAResetIntent(KingEASignalIntent &intent)
  {
   intent.signal_bar_time=0;
   intent.direction=KINGEA_DIRECTION_NONE;
   intent.entry_intent=false;
   intent.technical_stop=0.0;
   intent.exit_intent=false;
   intent.reason="NO_ACTION";
  }

bool KingEAValidParameters(const KingEACandidateParameters &parameters)
  {
   return (parameters.atr_period>0 &&
           parameters.supertrend_multiplier>0.0 &&
           parameters.breakout_lookback_bars>0 &&
           parameters.entry_buffer_atr>=0.0 &&
           parameters.stop_buffer_atr>=0.0 &&
           parameters.progress_checkpoint_bars>0 &&
           parameters.required_progress_r>0.0 &&
           parameters.maximum_holding_bars>=parameters.progress_checkpoint_bars);
  }

bool KingEAEntryRegimeAllowed(const KingEAClosedBarFacts &facts)
  {
   return (facts.trend_regime==KINGEA_TREND_TRENDING &&
           (facts.volatility_regime==KINGEA_VOLATILITY_NORMAL ||
            facts.volatility_regime==KINGEA_VOLATILITY_HIGH));
  }

bool KingEAFreshLongBreakout(const KingEAClosedBarFacts &facts,
                            const KingEACandidateParameters &parameters)
  {
   double current_threshold=facts.breakout_high+(parameters.entry_buffer_atr*facts.atr);
   double previous_threshold=facts.previous_breakout_high+
                             (parameters.entry_buffer_atr*facts.previous_atr);
   return facts.close_price>current_threshold &&
          facts.previous_close_price<=previous_threshold;
  }

bool KingEAFreshShortBreakout(const KingEAClosedBarFacts &facts,
                             const KingEACandidateParameters &parameters)
  {
   double current_threshold=facts.breakout_low-(parameters.entry_buffer_atr*facts.atr);
   double previous_threshold=facts.previous_breakout_low-
                             (parameters.entry_buffer_atr*facts.previous_atr);
   return facts.close_price<current_threshold &&
          facts.previous_close_price>=previous_threshold;
  }

double KingEATechnicalStop(const int direction,
                          const KingEAClosedBarFacts &facts,
                          const KingEACandidateParameters &parameters)
  {
   if(direction==KINGEA_DIRECTION_LONG)
      return MathMin(facts.signal_bar_low,facts.m30_supertrend_line)-
             (parameters.stop_buffer_atr*facts.atr);
   if(direction==KINGEA_DIRECTION_SHORT)
      return MathMax(facts.signal_bar_high,facts.m30_supertrend_line)+
             (parameters.stop_buffer_atr*facts.atr);
   return 0.0;
  }

void KingEAEvaluateCandidateEthSt001(const KingEAClosedBarFacts &facts,
                                    const KingEAPositionFacts &position,
                                    const KingEACandidateParameters &parameters,
                                    KingEASignalIntent &intent)
  {
   KingEAResetIntent(intent);
   intent.signal_bar_time=facts.signal_bar_time;
   if(!KingEAValidParameters(parameters))
     {
      intent.reason="INVALID_PARAMETERS";
      return;
     }

   if(position.has_position)
     {
      intent.direction=position.direction;
      if(position.opposite_m30_supertrend)
        {
         intent.exit_intent=true;
         intent.reason="OPPOSITE_M30_SUPERTREND";
         return;
        }
      if(position.bars_held>=parameters.maximum_holding_bars)
        {
         intent.exit_intent=true;
         intent.reason="MAXIMUM_HOLDING_PERIOD";
         return;
        }
      if(position.bars_held>=parameters.progress_checkpoint_bars &&
         position.maximum_favourable_excursion_r<parameters.required_progress_r)
        {
         intent.exit_intent=true;
         intent.reason="INSUFFICIENT_PROGRESS";
         return;
        }
      intent.reason="HOLD";
      return;
     }

   if(!facts.inputs_complete || !facts.inputs_fresh)
     {
      intent.reason="INCOMPLETE_OR_STALE_INPUT";
      return;
     }
   if(facts.has_open_trade_group)
     {
      intent.reason="OPEN_GROUP_EXISTS";
      return;
     }
   if(!KingEAEntryRegimeAllowed(facts))
     {
      intent.reason="REGIME_BLOCK";
      return;
     }

   if(facts.m30_supertrend_direction==KINGEA_DIRECTION_LONG &&
      facts.h4_supertrend_direction==KINGEA_DIRECTION_LONG &&
      KingEAFreshLongBreakout(facts,parameters))
     {
      intent.direction=KINGEA_DIRECTION_LONG;
      intent.entry_intent=true;
      intent.technical_stop=KingEATechnicalStop(intent.direction,facts,parameters);
      intent.reason="LONG_CONTINUATION_BREAKOUT";
      return;
     }
   if(facts.m30_supertrend_direction==KINGEA_DIRECTION_SHORT &&
      facts.h4_supertrend_direction==KINGEA_DIRECTION_SHORT &&
      KingEAFreshShortBreakout(facts,parameters))
     {
      intent.direction=KINGEA_DIRECTION_SHORT;
      intent.entry_intent=true;
      intent.technical_stop=KingEATechnicalStop(intent.direction,facts,parameters);
      intent.reason="SHORT_CONTINUATION_BREAKOUT";
      return;
     }
   intent.reason="NO_FRESH_BREAKOUT";
  }

#endif
