#property copyright "KingEA"
#property version   "1.05"
#property script_show_inputs
#property description "Read-only validation of deterministic M1-from-ticks aggregation against stored M30 bars."
#property description "No custom-history mutation; orders; signals; indicators; returns; or optimizer logic."
#property description "Build ID: M1-DERIVATION-DIAG-20260724-F."

input string InpSymbol = "KINGEA_ETHUSD_S_RSB3";
input string InpWindowStart = "2024.03.02 00:00:00";
input string InpWindowEnd = "2024.03.03 00:00:00";

double g_point=0.0;

void StartBar(MqlRates &bar,const datetime time,const MqlTick &tick)
  {
   bar.time=time;
   bar.open=tick.bid;
   bar.high=tick.bid;
   bar.low=tick.bid;
   bar.close=tick.bid;
   bar.tick_volume=1;
   int spread_points=(int)MathRound((tick.ask-tick.bid)/g_point);
   bar.spread=(spread_points>0 ? spread_points : 0);
   bar.real_volume=(long)MathRound(tick.volume_real);
  }

void UpdateBar(MqlRates &bar,const MqlTick &tick)
  {
   bar.high=MathMax(bar.high,tick.bid);
   bar.low=MathMin(bar.low,tick.bid);
   bar.close=tick.bid;
   bar.tick_volume++;
   int spread_points=(int)MathRound((tick.ask-tick.bid)/g_point);
   if(spread_points>0 && (bar.spread<=0 || spread_points<bar.spread))
      bar.spread=spread_points;
   bar.real_volume+=(long)MathRound(tick.volume_real);
  }

int BuildRatesFromTicks(const MqlTick &ticks[],const int tick_count,
                        const int period_seconds,MqlRates &rates[])
  {
   ArrayResize(rates,0);
   if(tick_count<=0)
      return 0;
   int count=0;
   datetime current_bucket=0;
   for(int i=0;i<tick_count;i++)
     {
      datetime bucket=(datetime)(((long)ticks[i].time/period_seconds)*period_seconds);
      if(count==0 || bucket!=current_bucket)
        {
         current_bucket=bucket;
         ArrayResize(rates,count+1,2048);
         StartBar(rates[count],bucket,ticks[i]);
         count++;
        }
      else
         UpdateBar(rates[count-1],ticks[i]);
     }
   ArrayResize(rates,count);
   return count;
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA M1 derivation diagnostic refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   bool custom=false;
   if(!SymbolExist(InpSymbol,custom) || !custom || !SymbolSelect(InpSymbol,true))
     {
      Print("KingEA M1 derivation diagnostic failed: RSB3 custom symbol unavailable.");
      return;
     }
   datetime start_time=StringToTime(InpWindowStart);
   datetime end_time=StringToTime(InpWindowEnd);
   if(start_time<=0 || end_time<=start_time)
     {
      Print("KingEA M1 derivation diagnostic failed: invalid half-open window.");
      return;
     }
   g_point=SymbolInfoDouble(InpSymbol,SYMBOL_POINT);
   if(g_point<=0.0)
     {
      Print("KingEA M1 derivation diagnostic failed: invalid point.");
      return;
     }

   MqlTick ticks[];
   ResetLastError();
   int tick_count=CopyTicksRange(InpSymbol,ticks,COPY_TICKS_ALL,
                                 (ulong)((long)start_time*1000),
                                 (ulong)((long)end_time*1000-1));
   int tick_error=GetLastError();
   MqlRates derived_m1[];
   MqlRates derived_m30[];
   int m1_count=BuildRatesFromTicks(ticks,MathMax(0,tick_count),60,derived_m1);
   int derived_m30_count=BuildRatesFromTicks(ticks,MathMax(0,tick_count),1800,derived_m30);

   MqlRates stored_m30[];
   ResetLastError();
   int stored_m30_count=CopyRates(InpSymbol,PERIOD_M30,start_time,end_time-1,stored_m30);
   int m30_error=GetLastError();

   long time_mismatch=0;
   long ohlc_mismatch=0;
   long tick_volume_mismatch=0;
   long spread_mismatch=0;
   long real_volume_mismatch=0;
   int compare_count=MathMin(MathMax(0,derived_m30_count),MathMax(0,stored_m30_count));
   int spread_first[];
   int spread_last[];
   int spread_min[];
   int spread_max[];
   int spread_avg_floor[];
   int spread_avg_round[];
   int spread_avg_ceil[];
   int spread_median[];
   int spread_mode[];
   int exact_point_min[];
   int minimum_positive[];
   int minimum_nonnegative[];
   int negative_spread_ticks[];
   ArrayResize(spread_first,compare_count);
   ArrayResize(spread_last,compare_count);
   ArrayResize(spread_min,compare_count);
   ArrayResize(spread_max,compare_count);
   ArrayResize(spread_avg_floor,compare_count);
   ArrayResize(spread_avg_round,compare_count);
   ArrayResize(spread_avg_ceil,compare_count);
   ArrayResize(spread_median,compare_count);
   ArrayResize(spread_mode,compare_count);
   ArrayResize(exact_point_min,compare_count);
   ArrayResize(minimum_positive,compare_count);
   ArrayResize(minimum_nonnegative,compare_count);
   ArrayResize(negative_spread_ticks,compare_count);
   int tick_cursor=0;
   for(int i=0;i<compare_count;i++)
     {
      long bar_from_msc=(long)derived_m30[i].time*1000;
      long bar_to_msc=bar_from_msc+1800000;
      while(tick_cursor<tick_count && ticks[tick_cursor].time_msc<bar_from_msc)
         tick_cursor++;
      int bar_tick_start=tick_cursor;
      int bar_tick_count=0;
      int minimum=2147483647;
      int maximum=-2147483647;
      int exact_minimum=2147483647;
      int positive_minimum=2147483647;
      int nonnegative_minimum=2147483647;
      int negative_count=0;
      double spread_sum=0.0;
      int local_spreads[];
      while(tick_cursor<tick_count && ticks[tick_cursor].time_msc<bar_to_msc)
        {
         int rounded=(int)MathRound((ticks[tick_cursor].ask-ticks[tick_cursor].bid)/g_point);
         int exact_points=(int)(MathRound(ticks[tick_cursor].ask/g_point)-MathRound(ticks[tick_cursor].bid/g_point));
         ArrayResize(local_spreads,bar_tick_count+1,4096);
         local_spreads[bar_tick_count]=rounded;
         if(bar_tick_count==0)
            spread_first[i]=rounded;
         spread_last[i]=rounded;
         minimum=MathMin(minimum,rounded);
         maximum=MathMax(maximum,rounded);
         exact_minimum=MathMin(exact_minimum,exact_points);
         if(rounded>0)
            positive_minimum=MathMin(positive_minimum,rounded);
         if(rounded>=0)
            nonnegative_minimum=MathMin(nonnegative_minimum,rounded);
         if(rounded<0)
            negative_count++;
         spread_sum+=(double)rounded;
         bar_tick_count++;
         tick_cursor++;
        }
      ArrayResize(local_spreads,bar_tick_count);
      spread_min[i]=(bar_tick_count>0 ? minimum : 0);
      spread_max[i]=(bar_tick_count>0 ? maximum : 0);
      exact_point_min[i]=(bar_tick_count>0 ? exact_minimum : 0);
      minimum_positive[i]=(positive_minimum<2147483647 ? positive_minimum : 0);
      minimum_nonnegative[i]=(nonnegative_minimum<2147483647 ? nonnegative_minimum : 0);
      negative_spread_ticks[i]=negative_count;
      double spread_average=(bar_tick_count>0 ? spread_sum/(double)bar_tick_count : 0.0);
      spread_avg_floor[i]=(int)MathFloor(spread_average);
      spread_avg_round[i]=(int)MathRound(spread_average);
      spread_avg_ceil[i]=(int)MathCeil(spread_average);
      if(bar_tick_count>0)
        {
         ArraySort(local_spreads);
         spread_median[i]=local_spreads[(bar_tick_count-1)/2];
         int best_value=local_spreads[0];
         int best_count=1;
         int run_value=local_spreads[0];
         int run_count=1;
         for(int j=1;j<bar_tick_count;j++)
           {
            if(local_spreads[j]==run_value)
               run_count++;
            else
              {
               if(run_count>best_count)
                 {
                  best_count=run_count;
                  best_value=run_value;
                 }
               run_value=local_spreads[j];
               run_count=1;
              }
           }
         if(run_count>best_count)
            best_value=run_value;
         spread_mode[i]=best_value;
        }
      ArrayFree(local_spreads);
      if(bar_tick_start==tick_cursor)
        {
         spread_first[i]=0;
         spread_last[i]=0;
        }
      if(derived_m30[i].time!=stored_m30[i].time)
         time_mismatch++;
      if(derived_m30[i].open!=stored_m30[i].open ||
         derived_m30[i].high!=stored_m30[i].high ||
         derived_m30[i].low!=stored_m30[i].low ||
         derived_m30[i].close!=stored_m30[i].close)
         ohlc_mismatch++;
      if(derived_m30[i].tick_volume!=stored_m30[i].tick_volume)
         tick_volume_mismatch++;
      if(derived_m30[i].spread!=stored_m30[i].spread)
         spread_mismatch++;
      if(derived_m30[i].real_volume!=stored_m30[i].real_volume)
         real_volume_mismatch++;
     }

   bool result=(tick_count>0 &&
                m1_count>0 &&
                derived_m30_count==stored_m30_count &&
                time_mismatch==0 &&
                ohlc_mismatch==0 &&
                tick_volume_mismatch==0 &&
                spread_mismatch==0 &&
                real_volume_mismatch==0);

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\minute_bar_derivation_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA M1 derivation diagnostic failed: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"section","key","value","notes");
   FileWrite(report,"run","build_id","M1-DERIVATION-DIAG-20260724-F","");
   FileWrite(report,"run","server",server,"");
   FileWrite(report,"run","symbol",InpSymbol,"");
   FileWrite(report,"run","window_start",InpWindowStart,"inclusive");
   FileWrite(report,"run","window_end",InpWindowEnd,"exclusive");
   FileWrite(report,"source","ticks",tick_count,StringFormat("error=%d",tick_error));
   FileWrite(report,"derived","m1_bars",m1_count,"one bar per non-empty minute");
   FileWrite(report,"derived","m30_bars",derived_m30_count,"directly aggregated from accepted ticks");
   FileWrite(report,"stored","m30_bars",stored_m30_count,StringFormat("error=%d",m30_error));
   FileWrite(report,"comparison","time_mismatches",time_mismatch,"");
   FileWrite(report,"comparison","ohlc_mismatches",ohlc_mismatch,"");
   FileWrite(report,"comparison","tick_volume_mismatches",tick_volume_mismatch,"");
   FileWrite(report,"comparison","spread_mismatches",spread_mismatch,"");
   FileWrite(report,"comparison","real_volume_mismatches",real_volume_mismatch,"");
   for(int i=0;i<compare_count;i++)
     {
      if(derived_m30[i].spread==stored_m30[i].spread)
         continue;
      FileWrite(report,"spread_detail",TimeToString(stored_m30[i].time,TIME_DATE|TIME_MINUTES),
                stored_m30[i].spread,
                StringFormat("first=%d|last=%d|min=%d|max=%d|avg_floor=%d|avg_round=%d|avg_ceil=%d|median=%d|mode=%d|exact_point_min=%d|minimum_positive=%d|minimum_nonnegative=%d|negative_spread_ticks=%d",
                             spread_first[i],spread_last[i],spread_min[i],spread_max[i],
                             spread_avg_floor[i],spread_avg_round[i],spread_avg_ceil[i],
                             spread_median[i],spread_mode[i],exact_point_min[i],
                             minimum_positive[i],minimum_nonnegative[i],negative_spread_ticks[i]));
     }
   FileWrite(report,"result","status",result ? "PASS" : "FAIL","read-only; RSB3 untouched; no performance authorization");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA minute-bar derivation report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; ticks=%d; derived_m1=%d; derived_m30=%d; stored_m30=%d; OHLC_mismatches=%I64d; volume_mismatches=%I64d; spread_mismatches=%I64d. Read-only; RSB3 untouched.",
               result ? "PASS" : "FAIL",tick_count,m1_count,derived_m30_count,stored_m30_count,
               ohlc_mismatch,tick_volume_mismatch,spread_mismatch);
  }
