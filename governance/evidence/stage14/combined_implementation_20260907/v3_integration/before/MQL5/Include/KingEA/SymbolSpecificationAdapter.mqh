#ifndef KINGEA_SYMBOL_SPECIFICATION_ADAPTER_MQH
#define KINGEA_SYMBOL_SPECIFICATION_ADAPTER_MQH

// Read-only MT5 adapter for Stage 8.
// OrderCalcMargin and OrderCalcProfit are calculators only. This adapter has
// no order submission, position modification, history, indicator, performance,
// optimizer, OOS, holdout, DLL, network, or tick-flag capability.

#include <KingEA/SpecificationMonitor.mqh>

bool KingEAAddSpecificationSession(KingEASymbolSpecification &spec,
                                   const int from_second,
                                   const int to_second)
  {
   if(spec.session_count>=KINGEA_MAX_SPEC_SESSIONS ||
      from_second<0 || to_second<=from_second || to_second>604800)
      return false;
   spec.sessions[spec.session_count].from_second=from_second;
   spec.sessions[spec.session_count].to_second=to_second;
   spec.session_count++;
   return true;
  }

int KingEATimeOfDaySeconds(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   return parts.hour*3600+parts.min*60+parts.sec;
  }

bool KingEACaptureTradeSessions(const string symbol,
                                KingEASymbolSpecification &spec,
                                string &reason)
  {
   spec.session_count=0;
   for(int day=0;day<7;day++)
     {
      for(uint index=0;index<KINGEA_MAX_SPEC_SESSIONS;index++)
        {
         datetime from=0,to=0;
         ResetLastError();
         if(!SymbolInfoSessionTrade(symbol,(ENUM_DAY_OF_WEEK)day,index,from,to))
            break;
         int from_day=day*86400;
         int from_second=from_day+KingEATimeOfDaySeconds(from);
         int to_time=KingEATimeOfDaySeconds(to);
         int to_second=from_day+to_time;
         if(to_second<=from_second)
            to_second+=86400;
         if(!KingEAAddSpecificationSession(spec,from_second,to_second))
           {
            reason="SESSION_TABLE_INVALID_OR_TRUNCATED";
            return false;
           }
        }
     }
   reason="OK";
   return true;
  }

bool KingEACaptureSymbolSpecification(const string symbol,
                                      KingEASymbolSpecification &spec,
                                      KingEASpecificationRequest &request,
                                      string &reason)
  {
   ZeroMemory(spec);
   spec.valid=false;
   request.observed_at=TimeTradeServer();
   request.observed_server_class=AccountInfoString(ACCOUNT_SERVER);
   request.connected=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   request.facts_fresh=false;

   if(symbol=="" || !request.connected || !SymbolSelect(symbol,true) ||
      !SymbolIsSynchronized(symbol))
     {
      reason="SYMBOL_UNAVAILABLE_OR_UNSYNCHRONIZED";
      return false;
     }

   spec.symbol_id=symbol;
   spec.description=SymbolInfoString(symbol,SYMBOL_DESCRIPTION);
   spec.path=SymbolInfoString(symbol,SYMBOL_PATH);
   spec.currency_base=SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);
   spec.currency_profit=SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);
   spec.currency_margin=SymbolInfoString(symbol,SYMBOL_CURRENCY_MARGIN);
   spec.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   spec.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   spec.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   spec.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   spec.tick_value_profit=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
   spec.tick_value_loss=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
   spec.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   spec.calc_mode=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE);
   spec.execution_mode=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);
   spec.filling_mode=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   spec.order_mode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
   spec.expiration_mode=SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);
   spec.trade_mode=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   spec.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   spec.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   spec.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   spec.volume_limit=SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   spec.stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   spec.freeze_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   spec.margin_initial=SymbolInfoDouble(symbol,SYMBOL_MARGIN_INITIAL);
   spec.margin_maintenance=SymbolInfoDouble(symbol,SYMBOL_MARGIN_MAINTENANCE);
   spec.margin_hedged=SymbolInfoDouble(symbol,SYMBOL_MARGIN_HEDGED);

   double maintenance=0.0;
   if(!SymbolInfoMarginRate(symbol,ORDER_TYPE_BUY,spec.margin_rate_buy,maintenance))
     {
      reason="BUY_MARGIN_RATE_UNAVAILABLE";
      return false;
     }
   if(!SymbolInfoMarginRate(symbol,ORDER_TYPE_SELL,spec.margin_rate_sell,maintenance))
     {
      reason="SELL_MARGIN_RATE_UNAVAILABLE";
      return false;
     }
   if(!KingEACaptureTradeSessions(symbol,spec,reason))
      return false;

   double ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
   double minimum=spec.volume_min;
   if(ask<=0.0 || minimum<=0.0 || spec.tick_size<=0.0)
     {
      reason="CALCULATOR_INPUT_INVALID";
      return false;
     }

   double desired_probe=MathMin(spec.volume_max,MathMax(minimum,1.0));
   double probe_steps=MathFloor(((desired_probe-minimum)/spec.volume_step)+1e-9);
   double probe_volume=minimum+probe_steps*spec.volume_step;
   double profit=0.0;
   request.tick_probe_available=OrderCalcProfit(ORDER_TYPE_BUY,symbol,probe_volume,
                                                ask,ask+spec.tick_size,profit);
   if(!request.tick_probe_available)
     {
      reason="TICK_PROFIT_PROBE_FAILED";
      return false;
     }
   request.tick_probe_reported=spec.tick_value_profit;
   request.tick_probe_calculated=MathAbs(profit)/probe_volume;

   double margin=0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY,symbol,minimum,ask,margin))
     {
      reason="MARGIN_PROBE_FAILED";
      return false;
     }
   request.live_margin_per_lot=margin/minimum;
   request.hmr_proxy_margin_per_lot=spec.contract_size*ask/200.0;
   request.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double current_margin=AccountInfoDouble(ACCOUNT_MARGIN);
   double stressed_new_margin=MathMax(request.live_margin_per_lot,
                                      request.hmr_proxy_margin_per_lot)*minimum;
   double stressed_margin=current_margin+stressed_new_margin;
   request.stressed_margin_level_percent=(stressed_margin>0.0
                                          ? request.equity/stressed_margin*100.0
                                          : DBL_MAX);
   request.stressed_free_margin_ratio=(request.equity>0.0
                                       ? (request.equity-stressed_margin)/request.equity
                                       : 0.0);
   request.facts_fresh=true;
   spec.valid=true;
   reason="OK";
   return true;
  }

#endif
