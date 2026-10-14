#ifndef KINGEA_EXIT_ETH_ST_002_MQH
#define KINGEA_EXIT_ETH_ST_002_MQH

// Pure CAND-ETH-ST-002 exit policy, evaluated once per closed M30 bar.
// No terminal I/O and no order capability. See docs/candidates/CAND-ETH-ST-002.md.

#include <KingEA/CandidateEthSt001.mqh>

struct KingEAExit002Parameters
  {
   double trail_atr;
   double trail_activation_r;
   int    max_holding_bars;
  };

struct KingEAExit002Facts
  {
   int    direction;
   double entry_price;
   double initial_stop;
   double current_stop;
   double highest_high;   // since entry, closed bars only
   double lowest_low;     // since entry, closed bars only
   double atr;            // M30 ATR on the last closed bar
   int    h4_direction;
   int    bars_held;
  };

struct KingEAExit002Decision
  {
   bool   valid;
   bool   exit;
   bool   move_stop;
   double new_stop;
   string reason;
  };

bool KingEAExit002ParametersValid(const KingEAExit002Parameters &parameters)
  {
   return MathIsValidNumber(parameters.trail_atr) && parameters.trail_atr>0.0 &&
          MathIsValidNumber(parameters.trail_activation_r) && parameters.trail_activation_r>=0.0 &&
          parameters.max_holding_bars>0;
  }

void KingEAEvaluateExit002(const KingEAExit002Parameters &parameters,
                           const KingEAExit002Facts &facts,
                           KingEAExit002Decision &decision)
  {
   ZeroMemory(decision);
   decision.reason="INVALID";
   bool is_long=(facts.direction==KINGEA_DIRECTION_LONG);
   double risk=MathAbs(facts.entry_price-facts.initial_stop);
   if(!KingEAExit002ParametersValid(parameters) ||
      (!is_long && facts.direction!=KINGEA_DIRECTION_SHORT) ||
      !(risk>0.0) || !(facts.atr>0.0) || facts.bars_held<0 ||
      facts.highest_high<facts.lowest_low)
      return;
   decision.valid=true;
   decision.new_stop=facts.current_stop;
   decision.reason="HOLD";
   if(facts.bars_held>=parameters.max_holding_bars)
     {
      decision.exit=true;
      decision.reason="MAXIMUM_HOLDING_PERIOD";
      return;
     }
   if(facts.h4_direction==-facts.direction)
     {
      decision.exit=true;
      decision.reason="H4_TREND_FLIP";
      return;
     }
   double mfe_r=(is_long ? facts.highest_high-facts.entry_price :
                           facts.entry_price-facts.lowest_low)/risk;
   if(mfe_r<parameters.trail_activation_r)
      return;
   double trail=(is_long ? facts.highest_high-parameters.trail_atr*facts.atr :
                           facts.lowest_low+parameters.trail_atr*facts.atr);
   bool tighter=(is_long ? trail>facts.current_stop : trail<facts.current_stop);
   if(tighter)
     {
      decision.move_stop=true;
      decision.new_stop=trail;
      decision.reason="TRAIL";
     }
  }

#endif
