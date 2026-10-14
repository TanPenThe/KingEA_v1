#property script_show_inputs
#property description "Unit tests for the CAND-ETH-ST-002 exit policy."

#include <KingEA/ExitEthSt002.mqh>

int g_failures=0;

void Check(const bool condition,const string name)
  {
   if(!condition)
     {
      g_failures++;
      Print("FAIL: ",name);
     }
  }

KingEAExit002Parameters Params()
  {
   KingEAExit002Parameters p={};
   p.trail_atr=3.0;
   p.trail_activation_r=1.0;
   p.max_holding_bars=192;
   return p;
  }

KingEAExit002Facts LongFacts()
  {
   KingEAExit002Facts f={};
   f.direction=KINGEA_DIRECTION_LONG;
   f.entry_price=100.0;
   f.initial_stop=90.0;    // risk 10
   f.current_stop=90.0;
   f.highest_high=105.0;
   f.lowest_low=98.0;
   f.atr=2.0;
   f.h4_direction=KINGEA_DIRECTION_LONG;
   f.bars_held=10;
   return f;
  }

void OnStart()
  {
   KingEAExit002Decision d={};
   KingEAExit002Parameters p=Params();
   KingEAExit002Facts f=LongFacts();

   KingEAEvaluateExit002(p,f,d);
   Check(d.valid && !d.exit && !d.move_stop && d.reason=="HOLD","below activation holds");

   f.highest_high=112.0;   // MFE 1.2R -> trail 112-6=106
   KingEAEvaluateExit002(p,f,d);
   Check(d.move_stop && MathAbs(d.new_stop-106.0)<1e-9,"long trail after activation");

   f.current_stop=107.0;   // never loosen
   KingEAEvaluateExit002(p,f,d);
   Check(!d.move_stop && MathAbs(d.new_stop-107.0)<1e-9,"long trail never widens");

   f=LongFacts();
   f.h4_direction=KINGEA_DIRECTION_SHORT;
   KingEAEvaluateExit002(p,f,d);
   Check(d.exit && d.reason=="H4_TREND_FLIP","long exits on H4 flip");

   f=LongFacts();
   f.bars_held=192;
   f.h4_direction=KINGEA_DIRECTION_SHORT;
   KingEAEvaluateExit002(p,f,d);
   Check(d.exit && d.reason=="MAXIMUM_HOLDING_PERIOD","max holding checked first");

   f=LongFacts();
   f.h4_direction=KINGEA_DIRECTION_NONE;
   KingEAEvaluateExit002(p,f,d);
   Check(!d.exit,"unknown H4 direction is not a flip");

   // Short mirror: entry 100, stop 110, low 88 -> MFE 1.2R, trail 88+6=94.
   KingEAExit002Facts s={};
   s.direction=KINGEA_DIRECTION_SHORT;
   s.entry_price=100.0;
   s.initial_stop=110.0;
   s.current_stop=110.0;
   s.highest_high=101.0;
   s.lowest_low=88.0;
   s.atr=2.0;
   s.h4_direction=KINGEA_DIRECTION_SHORT;
   s.bars_held=5;
   KingEAEvaluateExit002(p,s,d);
   Check(d.move_stop && MathAbs(d.new_stop-94.0)<1e-9,"short trail after activation");

   p.trail_activation_r=0.0;  // trail from the first bar, still only tightening
   s.lowest_low=99.0;         // trail 105 < 110
   KingEAEvaluateExit002(p,s,d);
   Check(d.move_stop && MathAbs(d.new_stop-105.0)<1e-9,"activation 0 trails immediately");

   KingEAExit002Parameters bad=Params();
   bad.trail_atr=0.0;
   KingEAEvaluateExit002(bad,LongFacts(),d);
   Check(!d.valid && !d.exit,"invalid parameters fail closed");

   f=LongFacts();
   f.atr=0.0;
   KingEAEvaluateExit002(Params(),f,d);
   Check(!d.valid,"missing ATR fails closed");

   PrintFormat("TestExitEthSt002: %s (%d failures)",g_failures==0 ? "PASS" : "FAIL",g_failures);
  }
