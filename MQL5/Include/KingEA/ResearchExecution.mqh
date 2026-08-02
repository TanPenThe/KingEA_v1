#ifndef KINGEA_RESEARCH_EXECUTION_MQH
#define KINGEA_RESEARCH_EXECUTION_MQH

// Pure Stage 12 tester-execution contract.  This module has no terminal I/O,
// broker history, tester statistics, optimization, or order capability.

#include <KingEA/CandidateEthSt001.mqh>

struct KingEAResearchAuthorization
  {
   bool in_tester;
   bool every_tick_real;
   bool local_agents_only;
   bool manifest_hash_valid;
   bool detached_authorization_valid;
   bool status_running;
   bool partition_authorized;
  };

struct KingEAResearchStress
  {
   int delay_ms;
   double spread_multiplier;
   double cost_multiplier;
   double slippage_spread_fraction;
   double missed_entry_fraction;
   uint seed;
  };

struct KingEAResearchVirtualFill
  {
   bool healthy;
   bool missed;
   double stressed_spread;
   double entry_price;
   double cost_multiplier;
  };

enum KingEAResearchExecutionAdapter
  {
   KINGEA_RESEARCH_ADAPTER_INVALID=0,
   KINGEA_RESEARCH_ADAPTER_NATIVE=1,
   KINGEA_RESEARCH_ADAPTER_VIRTUAL=2
  };

enum KingEAResearchExecutionOutcome
  {
   KINGEA_RESEARCH_OUTCOME_INVALID=0,
   KINGEA_RESEARCH_NATIVE_ORDER_REQUIRED=1,
   KINGEA_RESEARCH_VIRTUAL_FILL=2,
   KINGEA_RESEARCH_SEEDED_MISS=3,
   KINGEA_RESEARCH_DELAY_QUEUED=4,
   KINGEA_RESEARCH_DELAY_EXPIRY=5,
   KINGEA_RESEARCH_GATE_REJECT_AFTER_DELAY=6,
   KINGEA_RESEARCH_VIRTUAL_EXECUTION_FAILURE=7
  };

struct KingEAResearchVirtualPosition
  {
   bool     has_position;
   int      direction;
   double   volume;
   double   entry_price;
   double   protective_stop;
   double   equity;
   double   entry_equity;
   long     opened_time_msc;
   string   signal_identity;
  };

struct KingEAResearchEntryRoute
  {
   bool     healthy;
   bool     native_order_required;
   bool     enqueued;
   int      outcome;
   double   fill_price;
   double   accounting_price;
   long     due_time_msc;
   long     expiry_time_msc;
   string   reason;
  };

bool KingEAResearchAuthorized(const KingEAResearchAuthorization &authorization)
  {
   return authorization.in_tester &&
          authorization.every_tick_real &&
          authorization.local_agents_only &&
          authorization.manifest_hash_valid &&
          authorization.detached_authorization_valid &&
          authorization.status_running &&
          authorization.partition_authorized;
  }

bool KingEAResearchDecodeConfiguration(const int identifier,
                                       KingEACandidateParameters &parameters)
  {
   if(identifier<0 || identifier>=19440)
      return false;
   int remaining=identifier;
   int holding[]={48,72,96};
   double progress[]={0.25,0.50,0.75};
   int checkpoints[]={8,12,16};
   double stop_buffers[]={0.0,0.25,0.50};
   double entry_buffers[]={0.0,0.1,0.2};
   int lookbacks[]={6,12,18,24};
   double multipliers[]={2.0,2.5,3.0,3.5,4.0};
   int periods[]={10,14,18,22};
   parameters.maximum_holding_bars=holding[remaining%3]; remaining/=3;
   parameters.required_progress_r=progress[remaining%3]; remaining/=3;
   parameters.progress_checkpoint_bars=checkpoints[remaining%3]; remaining/=3;
   parameters.stop_buffer_atr=stop_buffers[remaining%3]; remaining/=3;
   parameters.entry_buffer_atr=entry_buffers[remaining%3]; remaining/=3;
   parameters.breakout_lookback_bars=lookbacks[remaining%4]; remaining/=4;
   parameters.supertrend_multiplier=multipliers[remaining%5]; remaining/=5;
   parameters.atr_period=periods[remaining%4];
   return true;
  }

double KingEAResearchDeterministicUnit(const string identity,const uint seed)
  {
   uint hash=2166136261^seed;
   for(int i=0;i<StringLen(identity);i++)
     {
      hash^=(uint)StringGetCharacter(identity,i);
      hash*=16777619;
     }
   return (double)(hash%1000000)/1000000.0;
  }

void KingEAResearchApplyVirtualStress(const KingEAResearchStress &stress,
                                      const string signal_identity,
                                      const double bid,const double ask,
                                      const int direction,
                                      KingEAResearchVirtualFill &fill)
  {
   ZeroMemory(fill);
   if(signal_identity=="" || !MathIsValidNumber(bid) ||
      !MathIsValidNumber(ask) || bid<=0.0 || ask<bid ||
      !MathIsValidNumber(stress.spread_multiplier) ||
      !MathIsValidNumber(stress.cost_multiplier) ||
      !MathIsValidNumber(stress.slippage_spread_fraction) ||
      !MathIsValidNumber(stress.missed_entry_fraction) ||
      stress.spread_multiplier<1.0 || stress.cost_multiplier<1.0 ||
      stress.slippage_spread_fraction<0.0 ||
      stress.missed_entry_fraction<0.0 || stress.missed_entry_fraction>1.0 ||
      (direction!=KINGEA_DIRECTION_LONG && direction!=KINGEA_DIRECTION_SHORT))
      return;
   fill.healthy=true;
   fill.stressed_spread=(ask-bid)*stress.spread_multiplier;
   fill.missed=KingEAResearchDeterministicUnit(signal_identity,stress.seed)<
               stress.missed_entry_fraction;
   double stressed_bid=ask-fill.stressed_spread;
   double stressed_ask=bid+fill.stressed_spread;
   double slippage=fill.stressed_spread*stress.slippage_spread_fraction;
   fill.entry_price=(direction==KINGEA_DIRECTION_LONG
                     ? stressed_ask+slippage
                     : stressed_bid-slippage);
   fill.cost_multiplier=stress.cost_multiplier;
  }

void KingEAResearchRouteEntry(const int adapter,
                              const KingEAResearchStress &stress,
                              const string signal_identity,
                              const double bid,const double ask,
                              const int direction,
                              const double protective_stop,
                              const double volume,
                              const long signal_time_msc,
                              const long next_m30_boundary_msc,
                              const double native_result_price,
                              const bool native_result_valid,
                              KingEAResearchVirtualPosition &position,
                              KingEAResearchEntryRoute &route)
  {
   ZeroMemory(route);
   if(adapter!=KINGEA_RESEARCH_ADAPTER_NATIVE &&
      adapter!=KINGEA_RESEARCH_ADAPTER_VIRTUAL)
     { route.reason="EXECUTION_ADAPTER_INVALID"; return; }
   if(signal_identity=="" || signal_time_msc<=0 ||
      next_m30_boundary_msc<=signal_time_msc ||
      !MathIsValidNumber(protective_stop) || protective_stop<=0.0 ||
      !MathIsValidNumber(volume) || volume<=0.0)
     { route.reason="ENTRY_ROUTE_FACTS_INVALID"; return; }
   if(adapter==KINGEA_RESEARCH_ADAPTER_NATIVE)
     {
      route.native_order_required=true;
      route.outcome=KINGEA_RESEARCH_NATIVE_ORDER_REQUIRED;
      route.reason="NATIVE_ORDER_REQUIRED";
      if(!native_result_valid)
        { route.healthy=true; return; }
      if(!MathIsValidNumber(native_result_price) || native_result_price<=0.0)
        { route.reason="NATIVE_RESULT_PRICE_INVALID"; return; }
      route.healthy=true;
      route.fill_price=native_result_price;
      route.accounting_price=native_result_price;
      return;
     }
   if(position.has_position)
     { route.reason="VIRTUAL_POSITION_ALREADY_OPEN"; return; }
   KingEAResearchVirtualFill fill={};
   KingEAResearchApplyVirtualStress(stress,signal_identity,bid,ask,direction,fill);
   if(!fill.healthy)
     { route.reason="VIRTUAL_STRESS_INVALID"; return; }
   if(fill.missed)
     {
      route.healthy=true;
      route.outcome=KINGEA_RESEARCH_SEEDED_MISS;
      route.reason="SEEDED_MISS";
      return;
     }
   if(stress.delay_ms>0)
     {
      route.healthy=true;
      route.enqueued=true;
      route.outcome=KINGEA_RESEARCH_DELAY_QUEUED;
      route.due_time_msc=signal_time_msc+(long)stress.delay_ms;
      route.expiry_time_msc=next_m30_boundary_msc;
      route.reason="DELAY_QUEUED";
      return;
     }
   position.has_position=true;
   position.direction=direction;
   position.volume=volume;
   position.entry_price=fill.entry_price;
   position.protective_stop=protective_stop;
   position.entry_equity=position.equity;
   position.opened_time_msc=signal_time_msc;
   position.signal_identity=signal_identity;
   route.healthy=true;
   route.outcome=KINGEA_RESEARCH_VIRTUAL_FILL;
   route.fill_price=fill.entry_price;
   route.accounting_price=fill.entry_price;
   route.reason="VIRTUAL_FILL";
  }

void KingEAResearchCompleteDelayedEntry(const KingEAResearchStress &stress,
                                        const string signal_identity,
                                        const double bid,const double ask,
                                        const int direction,
                                        const double protective_stop,
                                        const double volume,
                                        const long now_msc,
                                        const long due_time_msc,
                                        const long expiry_time_msc,
                                        const bool gates_healthy,
                                        const bool execution_healthy,
                                        KingEAResearchVirtualPosition &position,
                                        KingEAResearchEntryRoute &route)
  {
   ZeroMemory(route);
   route.enqueued=true;
   if(now_msc<due_time_msc)
     { route.healthy=true; route.outcome=KINGEA_RESEARCH_DELAY_QUEUED; route.reason="DELAY_PENDING"; return; }
   if(now_msc>=expiry_time_msc)
     { route.healthy=true; route.outcome=KINGEA_RESEARCH_DELAY_EXPIRY; route.reason="DELAY_EXPIRY"; return; }
   if(!gates_healthy)
     { route.healthy=true; route.outcome=KINGEA_RESEARCH_GATE_REJECT_AFTER_DELAY; route.reason="GATE_REJECT_AFTER_DELAY"; return; }
   if(!execution_healthy)
     { route.healthy=true; route.outcome=KINGEA_RESEARCH_VIRTUAL_EXECUTION_FAILURE; route.reason="VIRTUAL_EXECUTION_FAILURE"; return; }
   KingEAResearchStress immediate=stress;
   immediate.delay_ms=0;
   immediate.missed_entry_fraction=0.0; // Seeded miss was already decided before queueing.
   KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_VIRTUAL,immediate,
                            signal_identity,bid,ask,direction,protective_stop,
                            volume,now_msc,expiry_time_msc,0.0,false,
                            position,route);
   route.enqueued=true;
  }

#endif
