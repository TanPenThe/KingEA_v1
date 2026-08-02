#property copyright "KingEA"
#property version   "1.02"
#property script_show_inputs
#property description "Exports non-performance symbol, account, margin, session, and lot/stop feasibility data."
#property description "This script never sends, modifies, or closes an order."

#define MAX_SESSION_ENTRIES_PER_DAY 64

input string InpSymbol                 = "ETHUSD.s";
input string InpSnapshotLabel          = "HMR"; // Run again with HMR when broker HMR is active.
input string InpRequiredServerFragment = "Demo2";
input int    InpReadinessTimeoutSeconds= 30;
input double InpReferenceEquityUSD     = 1000.0;
input double InpHMRLeverageReference   = 200.0;    // Informational proxy only; live OrderCalcMargin is authoritative.

string g_symbol;
string g_label;
string g_server_time;
string g_utc_time;

bool WaitForCaptureReadiness(const string symbol,string &reason)
  {
   ulong deadline=GetTickCount64()+(ulong)MathMax(1,InpReadinessTimeoutSeconds)*1000;
   while(GetTickCount64()<=deadline)
     {
      string server=AccountInfoString(ACCOUNT_SERVER);
      bool identity_ok=(InpRequiredServerFragment=="" ||
                        StringFind(server,InpRequiredServerFragment)>=0);
      bool demo_ok=(InpRequiredServerFragment=="" ||
                    AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO);
      if((bool)TerminalInfoInteger(TERMINAL_CONNECTED) && identity_ok && demo_ok &&
         SymbolSelect(symbol,true) && SymbolIsSynchronized(symbol) &&
         AccountInfoDouble(ACCOUNT_EQUITY)>0.0 && AccountInfoDouble(ACCOUNT_BALANCE)>0.0)
        {
         reason="OK";
         return true;
        }
      Sleep(250);
     }
   reason="CAPTURE_NOT_READY";
   return false;
  }

void WriteRow(const int handle,
              const string section,
              const string key,
              const string value,
              const string unit="",
              const string notes="")
  {
   FileWrite(handle,g_utc_time,g_server_time,g_label,section,key,value,unit,notes);
  }

void WriteDouble(const int handle,
                 const string section,
                 const string key,
                 const double value,
                 const int digits=8,
                 const string unit="",
                 const string notes="")
  {
   WriteRow(handle,section,key,DoubleToString(value,digits),unit,notes);
  }

void WriteLong(const int handle,
               const string section,
               const string key,
               const long value,
               const string unit="",
               const string notes="")
  {
   WriteRow(handle,section,key,StringFormat("%I64d",value),unit,notes);
  }

string SafeLabel(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,"/","-");
   StringReplace(value,"\\","-");
   return value;
  }

double NormalizeVolumeDown(const double requested,
                           const double minimum,
                           const double maximum,
                           const double step)
  {
   if(step<=0.0 || maximum<minimum)
      return 0.0;

   double bounded=MathMin(requested,maximum);
   if(bounded<minimum)
      return 0.0;

   double steps=MathFloor(((bounded-minimum)/step)+1e-9);
   double normalized=minimum+(steps*step);
   return MathMax(minimum,MathMin(normalized,maximum));
  }

bool AlreadyIncluded(const double &values[],const int count,const double candidate,const double tolerance)
  {
   for(int i=0;i<count;i++)
      if(MathAbs(values[i]-candidate)<=tolerance)
         return true;
   return false;
  }

void ExportAccount(const int handle)
  {
   WriteRow(handle,"account","server",AccountInfoString(ACCOUNT_SERVER));
   WriteRow(handle,"account","company",AccountInfoString(ACCOUNT_COMPANY));
   WriteRow(handle,"account","currency",AccountInfoString(ACCOUNT_CURRENCY));
   WriteLong(handle,"account","leverage",AccountInfoInteger(ACCOUNT_LEVERAGE),"ratio");
   WriteLong(handle,"account","margin_mode",AccountInfoInteger(ACCOUNT_MARGIN_MODE),"enum");
   WriteLong(handle,"account","stopout_mode",AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE),"enum");
   WriteDouble(handle,"account","margin_call_level",AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL),4,"percent_or_money","Interpret using stopout_mode.");
   WriteDouble(handle,"account","stopout_level",AccountInfoDouble(ACCOUNT_MARGIN_SO_SO),4,"percent_or_money","Interpret using stopout_mode.");
   WriteDouble(handle,"account","balance_snapshot",AccountInfoDouble(ACCOUNT_BALANCE),2,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"account","equity_snapshot",AccountInfoDouble(ACCOUNT_EQUITY),2,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"account","margin_used_snapshot",AccountInfoDouble(ACCOUNT_MARGIN),2,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"account","margin_free_snapshot",AccountInfoDouble(ACCOUNT_MARGIN_FREE),2,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"account","margin_level_snapshot",AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),4,"percent");
   WriteDouble(handle,"account","reference_equity",InpReferenceEquityUSD,2,"USD","Feasibility reference only; no strategy performance calculation.");
  }

void ExportTerminal(const int handle)
  {
   WriteRow(handle,"terminal","name",TerminalInfoString(TERMINAL_NAME));
   WriteRow(handle,"terminal","company",TerminalInfoString(TERMINAL_COMPANY));
   WriteLong(handle,"terminal","build",TerminalInfoInteger(TERMINAL_BUILD));
   WriteLong(handle,"terminal","connected",TerminalInfoInteger(TERMINAL_CONNECTED),"bool");
   WriteLong(handle,"terminal","trade_allowed",TerminalInfoInteger(TERMINAL_TRADE_ALLOWED),"bool");
   WriteLong(handle,"terminal","dlls_allowed",TerminalInfoInteger(TERMINAL_DLLS_ALLOWED),"bool");
  }

void ExportSymbolStrings(const int handle)
  {
   WriteRow(handle,"symbol","name",g_symbol);
   WriteRow(handle,"symbol","description",SymbolInfoString(g_symbol,SYMBOL_DESCRIPTION));
   WriteRow(handle,"symbol","path",SymbolInfoString(g_symbol,SYMBOL_PATH));
   WriteRow(handle,"symbol","currency_base",SymbolInfoString(g_symbol,SYMBOL_CURRENCY_BASE));
   WriteRow(handle,"symbol","currency_profit",SymbolInfoString(g_symbol,SYMBOL_CURRENCY_PROFIT));
   WriteRow(handle,"symbol","currency_margin",SymbolInfoString(g_symbol,SYMBOL_CURRENCY_MARGIN));
   WriteRow(handle,"symbol","formula",SymbolInfoString(g_symbol,SYMBOL_FORMULA));
  }

void ExportSymbolIntegers(const int handle)
  {
   WriteLong(handle,"symbol","synchronized",SymbolIsSynchronized(g_symbol),"bool");
   WriteLong(handle,"symbol","digits",SymbolInfoInteger(g_symbol,SYMBOL_DIGITS));
   WriteLong(handle,"symbol","spread_property",SymbolInfoInteger(g_symbol,SYMBOL_SPREAD),"points");
   WriteLong(handle,"symbol","spread_float",SymbolInfoInteger(g_symbol,SYMBOL_SPREAD_FLOAT),"bool");
   WriteLong(handle,"symbol","trade_mode",SymbolInfoInteger(g_symbol,SYMBOL_TRADE_MODE),"enum");
   WriteLong(handle,"symbol","calc_mode",SymbolInfoInteger(g_symbol,SYMBOL_TRADE_CALC_MODE),"enum");
   WriteLong(handle,"symbol","execution_mode",SymbolInfoInteger(g_symbol,SYMBOL_TRADE_EXEMODE),"enum");
   WriteLong(handle,"symbol","filling_mode_flags",SymbolInfoInteger(g_symbol,SYMBOL_FILLING_MODE),"flags");
   WriteLong(handle,"symbol","order_mode_flags",SymbolInfoInteger(g_symbol,SYMBOL_ORDER_MODE),"flags");
   WriteLong(handle,"symbol","expiration_mode_flags",SymbolInfoInteger(g_symbol,SYMBOL_EXPIRATION_MODE),"flags");
   WriteLong(handle,"symbol","stops_level",SymbolInfoInteger(g_symbol,SYMBOL_TRADE_STOPS_LEVEL),"points");
   WriteLong(handle,"symbol","freeze_level",SymbolInfoInteger(g_symbol,SYMBOL_TRADE_FREEZE_LEVEL),"points");
   WriteLong(handle,"symbol","swap_mode",SymbolInfoInteger(g_symbol,SYMBOL_SWAP_MODE),"enum");
   WriteLong(handle,"symbol","swap_rollover_3days",SymbolInfoInteger(g_symbol,SYMBOL_SWAP_ROLLOVER3DAYS),"enum_day");
  }

void ExportSymbolDoubles(const int handle)
  {
   WriteDouble(handle,"symbol","point",SymbolInfoDouble(g_symbol,SYMBOL_POINT),12,"price");
   WriteDouble(handle,"symbol","tick_size",SymbolInfoDouble(g_symbol,SYMBOL_TRADE_TICK_SIZE),12,"price");
   WriteDouble(handle,"symbol","tick_value",SymbolInfoDouble(g_symbol,SYMBOL_TRADE_TICK_VALUE),8,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"symbol","tick_value_profit",SymbolInfoDouble(g_symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT),8,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"symbol","tick_value_loss",SymbolInfoDouble(g_symbol,SYMBOL_TRADE_TICK_VALUE_LOSS),8,AccountInfoString(ACCOUNT_CURRENCY));
   WriteDouble(handle,"symbol","contract_size",SymbolInfoDouble(g_symbol,SYMBOL_TRADE_CONTRACT_SIZE),8,"units_per_lot");
   WriteDouble(handle,"symbol","volume_min",SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN),8,"lots");
   WriteDouble(handle,"symbol","volume_max",SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MAX),8,"lots");
   WriteDouble(handle,"symbol","volume_step",SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP),8,"lots");
   WriteDouble(handle,"symbol","volume_limit",SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_LIMIT),8,"lots");
   WriteDouble(handle,"symbol","margin_initial",SymbolInfoDouble(g_symbol,SYMBOL_MARGIN_INITIAL),8,"margin_currency_per_lot");
   WriteDouble(handle,"symbol","margin_maintenance",SymbolInfoDouble(g_symbol,SYMBOL_MARGIN_MAINTENANCE),8,"margin_currency_per_lot");
   WriteDouble(handle,"symbol","margin_hedged",SymbolInfoDouble(g_symbol,SYMBOL_MARGIN_HEDGED),8,"margin_currency_per_lot");
   WriteDouble(handle,"symbol","swap_long",SymbolInfoDouble(g_symbol,SYMBOL_SWAP_LONG),8,"symbol_defined");
   WriteDouble(handle,"symbol","swap_short",SymbolInfoDouble(g_symbol,SYMBOL_SWAP_SHORT),8,"symbol_defined");
  }

void ExportTick(const int handle,MqlTick &tick)
  {
   double point=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   double spread_points=(point>0.0 ? (tick.ask-tick.bid)/point : 0.0);
   WriteRow(handle,"tick","time_server",TimeToString((datetime)tick.time,TIME_DATE|TIME_SECONDS));
   WriteLong(handle,"tick","time_msc",tick.time_msc,"unix_ms");
   WriteDouble(handle,"tick","bid",tick.bid,(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS),"price");
   WriteDouble(handle,"tick","ask",tick.ask,(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS),"price");
   WriteDouble(handle,"tick","last",tick.last,(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS),"price");
   WriteDouble(handle,"tick","spread",tick.ask-tick.bid,12,"price");
   WriteDouble(handle,"tick","spread_points",spread_points,4,"points");
   WriteDouble(handle,"tick","volume_real",tick.volume_real,4,"broker_units");
  }

void ExportMarginRates(const int handle)
  {
   ENUM_ORDER_TYPE types[2]={ORDER_TYPE_BUY,ORDER_TYPE_SELL};
   for(int i=0;i<2;i++)
     {
      double initial=0.0,maintenance=0.0;
      ResetLastError();
      bool ok=SymbolInfoMarginRate(g_symbol,types[i],initial,maintenance);
      string side=(types[i]==ORDER_TYPE_BUY ? "buy" : "sell");
      WriteLong(handle,"margin_rate",side+"_ok",ok,"bool",ok ? "" : "error="+IntegerToString(GetLastError()));
      if(ok)
        {
         WriteDouble(handle,"margin_rate",side+"_initial_rate",initial,10,"multiplier");
         WriteDouble(handle,"margin_rate",side+"_maintenance_rate",maintenance,10,"multiplier");
        }
     }
  }

void ExportSessions(const int handle)
  {
   for(int d=0;d<7;d++)
     {
      ENUM_DAY_OF_WEEK day=(ENUM_DAY_OF_WEEK)d;
      uint sessions_found=0;
      for(uint index=0;index<MAX_SESSION_ENTRIES_PER_DAY;index++)
        {
         datetime from=0,to=0;
         ResetLastError();
         if(!SymbolInfoSessionTrade(g_symbol,day,index,from,to))
            break;
         sessions_found++;
         string prefix=EnumToString(day)+"_"+IntegerToString((int)index);
         WriteRow(handle,"trade_session",prefix+"_from",TimeToString(from,TIME_MINUTES),"server_time");
         WriteRow(handle,"trade_session",prefix+"_to",TimeToString(to,TIME_MINUTES),"server_time");
        }
      WriteLong(handle,"trade_session",EnumToString(day)+"_entries_found",sessions_found,"sessions");
      if(sessions_found>=MAX_SESSION_ENTRIES_PER_DAY)
         WriteRow(handle,"trade_session",EnumToString(day)+"_scan_truncated","1","bool","Reached defensive scan ceiling; audit session table manually before use.");
     }
  }

void ExportHistoryAvailability(const int handle)
  {
   ENUM_TIMEFRAMES periods[4]={PERIOD_M1,PERIOD_M30,PERIOD_H4,PERIOD_D1};
   for(int i=0;i<4;i++)
     {
      long first=0,bars=0,sync=0;
      string name=EnumToString(periods[i]);
      if(SeriesInfoInteger(g_symbol,periods[i],SERIES_FIRSTDATE,first))
         WriteRow(handle,"history",name+"_first_date",TimeToString((datetime)first,TIME_DATE|TIME_SECONDS),"server_time");
      else
         WriteRow(handle,"history",name+"_first_date","ERROR","","error="+IntegerToString(GetLastError()));
      if(SeriesInfoInteger(g_symbol,periods[i],SERIES_BARS_COUNT,bars))
         WriteLong(handle,"history",name+"_bars",bars,"bars");
      if(SeriesInfoInteger(g_symbol,periods[i],SERIES_SYNCHRONIZED,sync))
         WriteLong(handle,"history",name+"_synchronized",sync,"bool");
     }
  }

void ExportMarginMatrix(const int handle,const MqlTick &tick)
  {
   double minimum=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_STEP);
   double requested[6]={minimum,minimum+step,0.01,0.02,0.05,0.10};
   double volumes[];
   ArrayResize(volumes,0);
   int count=0;

   for(int i=0;i<ArraySize(requested);i++)
     {
      double normalized=NormalizeVolumeDown(requested[i],minimum,maximum,step);
      if(normalized<=0.0 || AlreadyIncluded(volumes,count,normalized,MathMax(step*0.1,1e-10)))
         continue;
      ArrayResize(volumes,count+1);
      volumes[count++]=normalized;
     }

   ENUM_ORDER_TYPE types[2]={ORDER_TYPE_BUY,ORDER_TYPE_SELL};
   for(int t=0;t<2;t++)
     {
      string side=(types[t]==ORDER_TYPE_BUY ? "buy" : "sell");
      double price=(types[t]==ORDER_TYPE_BUY ? tick.ask : tick.bid);
      for(int v=0;v<count;v++)
        {
         double margin=0.0;
         ResetLastError();
         bool ok=OrderCalcMargin(types[t],g_symbol,volumes[v],price,margin);
         string key=side+"_vol_"+DoubleToString(volumes[v],8);
         WriteLong(handle,"margin_matrix",key+"_ok",ok,"bool",ok ? "" : "error="+IntegerToString(GetLastError()));
         if(!ok)
            continue;
         WriteDouble(handle,"margin_matrix",key+"_live_margin",margin,4,AccountInfoString(ACCOUNT_CURRENCY),"OrderCalcMargin at snapshot conditions; rerun during actual HMR.");
         if(InpReferenceEquityUSD>0.0)
            WriteDouble(handle,"margin_matrix",key+"_pct_reference_equity",100.0*margin/InpReferenceEquityUSD,4,"percent");

         double contract=SymbolInfoDouble(g_symbol,SYMBOL_TRADE_CONTRACT_SIZE);
         double notional_proxy=volumes[v]*contract*price;
         WriteDouble(handle,"margin_matrix",key+"_notional_proxy",notional_proxy,4,SymbolInfoString(g_symbol,SYMBOL_CURRENCY_MARGIN),"Proxy; interpretation depends on symbol calculation mode.");
         if(margin>0.0)
           {
            double effective_leverage_proxy=notional_proxy/margin;
            WriteDouble(handle,"margin_matrix",key+"_effective_leverage_proxy",effective_leverage_proxy,4,"ratio","Derived from notional proxy/live OrderCalcMargin; verify against symbol calculation mode.");
            if(v==0 && types[t]==ORDER_TYPE_BUY && StringFind(g_label,"HMR")>=0 && InpHMRLeverageReference>0.0)
              {
               double upper_tolerance=InpHMRLeverageReference*1.10;
               string verification=(effective_leverage_proxy<=upper_tolerance
                                    ? "CONSISTENT_WITH_HMR_REFERENCE"
                                    : "NOT_CONSISTENT_WITH_HMR_REFERENCE");
               WriteRow(handle,"audit","hmr_snapshot_verification",verification,"",StringFormat("effective_leverage_proxy=%.4f expected_reference=%.4f tolerance_max=%.4f",effective_leverage_proxy,InpHMRLeverageReference,upper_tolerance));
              }
           }
         if(InpHMRLeverageReference>0.0)
            WriteDouble(handle,"margin_matrix",key+"_hmr_margin_proxy",notional_proxy/InpHMRLeverageReference,4,SymbolInfoString(g_symbol,SYMBOL_CURRENCY_MARGIN),"Informational only. Actual HMR snapshot via OrderCalcMargin is authoritative.");
        }
     }
  }

void ExportStopRiskMatrix(const int handle,const MqlTick &tick)
  {
   double minimum=SymbolInfoDouble(g_symbol,SYMBOL_VOLUME_MIN);
   if(minimum<=0.0)
      return;

   double distances_pct[8]={0.10,0.25,0.50,1.00,2.00,3.00,5.00,10.00};
   ENUM_ORDER_TYPE types[2]={ORDER_TYPE_BUY,ORDER_TYPE_SELL};
   for(int t=0;t<2;t++)
     {
      string side=(types[t]==ORDER_TYPE_BUY ? "buy" : "sell");
      double open_price=(types[t]==ORDER_TYPE_BUY ? tick.ask : tick.bid);
      for(int i=0;i<ArraySize(distances_pct);i++)
        {
         double close_price=(types[t]==ORDER_TYPE_BUY
                             ? open_price*(1.0-distances_pct[i]/100.0)
                             : open_price*(1.0+distances_pct[i]/100.0));
         double profit=0.0;
         ResetLastError();
         bool ok=OrderCalcProfit(types[t],g_symbol,minimum,open_price,close_price,profit);
         string key=side+"_minlot_"+DoubleToString(minimum,8)+"_distance_"+DoubleToString(distances_pct[i],2)+"pct";
         WriteLong(handle,"stop_risk_matrix",key+"_ok",ok,"bool",ok ? "" : "error="+IntegerToString(GetLastError()));
         if(!ok)
            continue;
         double gross_loss=MathMax(0.0,-profit);
         WriteDouble(handle,"stop_risk_matrix",key+"_gross_loss",gross_loss,4,AccountInfoString(ACCOUNT_CURRENCY),"OrderCalcProfit; excludes commission, swap, and added slippage stress.");
         if(InpReferenceEquityUSD>0.0)
            WriteDouble(handle,"stop_risk_matrix",key+"_pct_reference_equity",100.0*gross_loss/InpReferenceEquityUSD,4,"percent","Mechanical feasibility only; not a strategy test.");
        }
     }
  }

void OnStart()
  {
   g_symbol=(StringLen(InpSymbol)>0 ? InpSymbol : _Symbol);
   string readiness_reason="";
   if(!WaitForCaptureReadiness(g_symbol,readiness_reason))
     {
      PrintFormat("KingEA feasibility export failed: %s; server='%s' equity=%.2f balance=%.2f",
                  readiness_reason,AccountInfoString(ACCOUNT_SERVER),
                  AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_BALANCE));
      return;
     }
   g_label=SafeLabel(InpSnapshotLabel);
   g_server_time=TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS);
   g_utc_time=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);

   if(!SymbolSelect(g_symbol,true))
     {
      PrintFormat("KingEA feasibility export failed: cannot select symbol '%s'; error=%d",g_symbol,GetLastError());
      return;
     }

   MqlTick tick={};
   if(!SymbolInfoTick(g_symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
     {
      PrintFormat("KingEA feasibility export failed: no valid tick for '%s'; error=%d",g_symbol,GetLastError());
      return;
     }

   string stamp=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   stamp=SafeLabel(stamp);
   string filename="KingEA\\feasibility_"+SafeLabel(g_symbol)+"_"+g_label+"_"+stamp+".csv";
   int flags=FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ;
   ResetLastError();
   int handle=FileOpen(filename,flags,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA feasibility export failed: FileOpen('%s') error=%d",filename,GetLastError());
      return;
     }

   FileWrite(handle,"snapshot_utc","snapshot_server","label","section","key","value","unit","notes");
   WriteRow(handle,"audit","scope","NON_PERFORMANCE_FEASIBILITY_ONLY");
   WriteRow(handle,"audit","prohibited","No signals, historical returns, win rate, expectancy, ATR optimization, parameter ranking, or order submission.");
   WriteRow(handle,"audit","symbol",g_symbol);
   WriteRow(handle,"audit","snapshot_label",g_label);

   ExportTerminal(handle);
   ExportAccount(handle);
   ExportSymbolStrings(handle);
   ExportSymbolIntegers(handle);
   ExportSymbolDoubles(handle);
   ExportTick(handle,tick);
   ExportMarginRates(handle);
   ExportSessions(handle);
   ExportHistoryAvailability(handle);
   ExportMarginMatrix(handle,tick);
   ExportStopRiskMatrix(handle,tick);

   FileFlush(handle);
   FileClose(handle);

   string full_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename;
   PrintFormat("KingEA feasibility export complete: %s",full_path);
   Print("Run once under NORMAL conditions and again while JustMarkets HMR is actually active. Compare live OrderCalcMargin rows; do not treat the HMR proxy as authoritative.");
  }
