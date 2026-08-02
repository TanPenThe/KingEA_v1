#property copyright "KingEA"
#property version   "1.00"
#property description "Deterministic non-performance tests for the pure Candidate 001 signal contract."
#property description "No history access; orders; returns; ranking; or optimization."
#property description "Build ID: CAND-ETH-ST-001-CONTRACT-TEST-20260726-A."

#include <KingEA/CandidateEthSt001.mqh>

int g_failures=0;

void Check(const bool condition,const string label)
  {
   if(condition) return;
   g_failures++;
   PrintFormat("CANDIDATE_CONTRACT_TEST_FAIL: %s",label);
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

KingEAClosedBarFacts BaseFacts()
  {
   KingEAClosedBarFacts facts={};
   facts.signal_bar_time=D'2026.07.26 12:00:00';
   facts.inputs_complete=true;
   facts.inputs_fresh=true;
   facts.has_open_trade_group=false;
   facts.trend_regime=KINGEA_TREND_TRENDING;
   facts.volatility_regime=KINGEA_VOLATILITY_NORMAL;
   facts.atr=10.0;
   facts.previous_atr=10.0;
   facts.signal_bar_high=201.0;
   facts.signal_bar_low=190.0;
   return facts;
  }

void OnStart()
  {
   KingEACandidateParameters parameters=DefaultParameters();
   KingEAClosedBarFacts facts=BaseFacts();
   KingEAPositionFacts position={};
   KingEASignalIntent intent={};

   facts.m30_supertrend_direction=KINGEA_DIRECTION_LONG;
   facts.h4_supertrend_direction=KINGEA_DIRECTION_LONG;
   facts.close_price=202.0;
   facts.previous_close_price=199.0;
   facts.breakout_high=200.0;
   facts.previous_breakout_high=200.0;
   facts.m30_supertrend_line=192.0;
   KingEAEvaluateCandidateEthSt001(facts,position,parameters,intent);
   Check(intent.entry_intent && intent.direction==KINGEA_DIRECTION_LONG,"fresh long breakout");
   Check(intent.technical_stop==187.5,"long stop uses farther structure minus ATR buffer");

   facts.previous_close_price=202.0;
   KingEAEvaluateCandidateEthSt001(facts,position,parameters,intent);
   Check(!intent.entry_intent && intent.reason=="NO_FRESH_BREAKOUT","stale breakout expires");

   facts=BaseFacts();
   facts.m30_supertrend_direction=KINGEA_DIRECTION_SHORT;
   facts.h4_supertrend_direction=KINGEA_DIRECTION_SHORT;
   facts.close_price=188.0;
   facts.previous_close_price=201.0;
   facts.breakout_low=190.0;
   facts.previous_breakout_low=190.0;
   facts.m30_supertrend_line=198.0;
   KingEAEvaluateCandidateEthSt001(facts,position,parameters,intent);
   Check(intent.entry_intent && intent.direction==KINGEA_DIRECTION_SHORT,"fresh short breakout");
   Check(intent.technical_stop==203.5,"short stop uses farther structure plus ATR buffer");

   facts.volatility_regime=KINGEA_VOLATILITY_EXTREME;
   KingEAEvaluateCandidateEthSt001(facts,position,parameters,intent);
   Check(!intent.entry_intent && intent.reason=="REGIME_BLOCK","extreme volatility blocks");

   facts=BaseFacts();
   position.has_position=true;
   position.direction=KINGEA_DIRECTION_LONG;
   position.bars_held=12;
   position.maximum_favourable_excursion_r=0.49;
   KingEAEvaluateCandidateEthSt001(facts,position,parameters,intent);
   Check(intent.exit_intent && intent.reason=="INSUFFICIENT_PROGRESS","progress exit");

   position.bars_held=72;
   position.maximum_favourable_excursion_r=1.0;
   KingEAEvaluateCandidateEthSt001(facts,position,parameters,intent);
   Check(intent.exit_intent && intent.reason=="MAXIMUM_HOLDING_PERIOD","absolute time exit");

   PrintFormat("CANDIDATE_CONTRACT_TEST_%s: failures=%d; non-performance; no performance authorization.",
               g_failures==0 ? "PASS" : "FAIL",g_failures);
  }
