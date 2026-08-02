#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only targeted M30 gap and sampled real-tick quality audit."
#property description "No trading; signals; indicators; returns; or optimizer logic."

input string          InpSymbol               = "ETHUSD.s";
input int             InpYears                = 5;
input ENUM_TIMEFRAMES InpGapTimeframe         = PERIOD_M30;
input int             InpGapThresholdBars     = 2;
input int             InpTickSampleMinutes    = 60;

struct TickQuality
  {
   long count;
   long invalid_quote_count;
   long reversed_spread_count;
   long zero_spread_count;
   long out_of_order_count;
   long same_millisecond_count;
   long exact_consecutive_duplicate_count;
   double spread_min;
   double spread_median;
   double spread_p95;
   double spread_p99;
   double spread_max;
  };

string g_symbol;
string g_utc_time;
string g_server_time;
double g_sample_spreads[];
int g_sample_spread_count=0;

string SafeName(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,"/","-");
   StringReplace(value,"\\","-");
   return value;
  }

string DateText(const datetime value)
  {
   return value>0 ? TimeToString(value,TIME_DATE|TIME_SECONDS) : "UNAVAILABLE";
  }

string BoolText(const bool value)
  {
   return value ? "1" : "0";
  }

void WriteRow(const int handle,
              const string section,
              const string key,
              const string value,
              const string unit="",
              const string notes="")
  {
   // Do not put commas in text fields because comma is the exported delimiter.
   FileWrite(handle,g_utc_time,g_server_time,section,key,value,unit,notes);
  }

datetime YearsBefore(const datetime value,const int years)
  {
   MqlDateTime parts={};
   if(!TimeToStruct(value,parts))
      return 0;
   parts.year-=years;
   return StructToTime(parts);
  }

datetime MonthlySampleStart(const datetime target_start,const int month_offset)
  {
   MqlDateTime base={};
   if(!TimeToStruct(target_start,base))
      return 0;

   int absolute_month=(base.year*12)+(base.mon-1)+month_offset;
   MqlDateTime sample={};
   sample.year=absolute_month/12;
   sample.mon=(absolute_month%12)+1;
   sample.day=15;
   sample.hour=12;
   datetime result=StructToTime(sample);

   MqlDateTime normalized={};
   if(!TimeToStruct(result,normalized))
      return 0;
   if(normalized.day_of_week==0)
      result+=24*60*60;
   else if(normalized.day_of_week==6)
      result+=2*24*60*60;
   return result;
  }

int CopyTickWindow(const datetime from,
                   const datetime to,
                   MqlTick &ticks[],
                   int &copy_error)
  {
   int copied=-1;
   copy_error=0;
   for(int attempt=1;attempt<=2;attempt++)
     {
      ResetLastError();
      ulong from_msc=((ulong)from)*1000;
      ulong to_msc=((ulong)to)*1000;
      if(to_msc>0)
         to_msc--;
      copied=CopyTicksRange(g_symbol,ticks,COPY_TICKS_ALL,from_msc,to_msc);
      copy_error=GetLastError();
      if(copied>=0)
         break;
      Sleep(250);
     }
   return copied;
  }

double Percentile(const double &sorted[],const int count,const double fraction)
  {
   if(count<=0)
      return 0.0;
   int index=(int)MathFloor(fraction*(count-1));
   index=MathMax(0,MathMin(index,count-1));
   return sorted[index];
  }

bool SameTick(const MqlTick &left,const MqlTick &right)
  {
   return (left.time_msc==right.time_msc &&
           left.bid==right.bid && left.ask==right.ask && left.last==right.last &&
           left.volume==right.volume && left.volume_real==right.volume_real &&
           left.flags==right.flags);
  }

void AnalyzeTicks(const MqlTick &ticks[],const int copied,TickQuality &quality)
  {
   ZeroMemory(quality);
   quality.count=copied;
   double spreads[];
   ArrayResize(spreads,MathMax(0,copied));
   int valid_spreads=0;

   for(int i=0;i<copied;i++)
     {
      if(ticks[i].bid<=0.0 || ticks[i].ask<=0.0)
        {
         quality.invalid_quote_count++;
        }
      else
        {
         double spread=ticks[i].ask-ticks[i].bid;
         if(spread<0.0)
           {
            quality.reversed_spread_count++;
            quality.invalid_quote_count++;
           }
         else
           {
            if(spread==0.0)
               quality.zero_spread_count++;
            spreads[valid_spreads++]=spread;

            int new_size=g_sample_spread_count+1;
            ArrayResize(g_sample_spreads,new_size,500000);
            g_sample_spreads[g_sample_spread_count++]=spread;
           }
        }

      if(i<=0)
         continue;
      if(ticks[i].time_msc<ticks[i-1].time_msc)
         quality.out_of_order_count++;
      if(ticks[i].time_msc==ticks[i-1].time_msc)
         quality.same_millisecond_count++;
      if(SameTick(ticks[i],ticks[i-1]))
         quality.exact_consecutive_duplicate_count++;
     }

   ArrayResize(spreads,valid_spreads);
   if(valid_spreads>0)
     {
      ArraySort(spreads);
      quality.spread_min=spreads[0];
      quality.spread_median=Percentile(spreads,valid_spreads,0.50);
      quality.spread_p95=Percentile(spreads,valid_spreads,0.95);
      quality.spread_p99=Percentile(spreads,valid_spreads,0.99);
      quality.spread_max=spreads[valid_spreads-1];
     }
   ArrayFree(spreads);
  }

void WriteTickQuality(const int handle,
                      const string key,
                      const TickQuality &quality,
                      const double point)
  {
   WriteRow(handle,"tick_quality",key+"_count",StringFormat("%I64d",quality.count),"ticks");
   WriteRow(handle,"tick_quality",key+"_invalid_quotes",StringFormat("%I64d",quality.invalid_quote_count),"ticks");
   WriteRow(handle,"tick_quality",key+"_reversed_spreads",StringFormat("%I64d",quality.reversed_spread_count),"ticks");
   WriteRow(handle,"tick_quality",key+"_zero_spreads",StringFormat("%I64d",quality.zero_spread_count),"ticks");
   WriteRow(handle,"tick_quality",key+"_out_of_order",StringFormat("%I64d",quality.out_of_order_count),"ticks");
   WriteRow(handle,"tick_quality",key+"_same_millisecond",StringFormat("%I64d",quality.same_millisecond_count),"ticks","Informational because multiple legitimate quote updates can share a millisecond.");
   WriteRow(handle,"tick_quality",key+"_exact_consecutive_duplicates",StringFormat("%I64d",quality.exact_consecutive_duplicate_count),"ticks","Reported for review and not automatically rejected.");
   int digits=(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS);
   WriteRow(handle,"tick_quality",key+"_spread_min",DoubleToString(quality.spread_min,digits),"price");
   WriteRow(handle,"tick_quality",key+"_spread_median",DoubleToString(quality.spread_median,digits),"price");
   WriteRow(handle,"tick_quality",key+"_spread_p95",DoubleToString(quality.spread_p95,digits),"price");
   WriteRow(handle,"tick_quality",key+"_spread_p99",DoubleToString(quality.spread_p99,digits),"price");
   WriteRow(handle,"tick_quality",key+"_spread_max",DoubleToString(quality.spread_max,digits),"price");
   if(point>0.0)
     {
      WriteRow(handle,"tick_quality",key+"_spread_median_points",DoubleToString(quality.spread_median/point,2),"points");
      WriteRow(handle,"tick_quality",key+"_spread_p99_points",DoubleToString(quality.spread_p99/point,2),"points");
      WriteRow(handle,"tick_quality",key+"_spread_max_points",DoubleToString(quality.spread_max/point,2),"points");
     }
  }

void OnStart()
  {
   g_symbol=(StringLen(InpSymbol)>0 ? InpSymbol : _Symbol);
   datetime now=TimeTradeServer();
   g_utc_time=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   g_server_time=TimeToString(now,TIME_DATE|TIME_SECONDS);

   if(InpYears<1 || InpYears>20 || InpGapThresholdBars<1 ||
      InpTickSampleMinutes<5 || InpTickSampleMinutes>360)
     {
      Print("KingEA history quality audit failed: invalid input range.");
      return;
     }
   if(now<=0 || !SymbolSelect(g_symbol,true))
     {
      PrintFormat("KingEA history quality audit failed: cannot initialize symbol '%s'; error=%d",g_symbol,GetLastError());
      return;
     }

   datetime target_start=YearsBefore(now,InpYears);
   long period_seconds=PeriodSeconds(InpGapTimeframe);
   if(target_start<=0 || period_seconds<=0)
     {
      Print("KingEA history quality audit failed: invalid time boundary or timeframe.");
      return;
     }

   string stamp=SafeName(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   string filename="KingEA\\history_quality_"+SafeName(g_symbol)+"_"+IntegerToString(InpYears)+"Y_"+stamp+".csv";
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA history quality audit failed: FileOpen('%s') error=%d",filename,GetLastError());
      return;
     }

   FileWrite(handle,"snapshot_utc","snapshot_server","section","key","value","unit","notes");
   WriteRow(handle,"audit","scope","NON_PERFORMANCE_TARGETED_HISTORY_QUALITY_AUDIT");
   WriteRow(handle,"audit","prohibited","No orders; signals; indicators; OHLC analysis; returns; win rate; expectancy; parameters; ranking; or optimization.");
   WriteRow(handle,"audit","symbol",g_symbol);
   WriteRow(handle,"audit","target_start",DateText(target_start),"server_time");
   WriteRow(handle,"audit","gap_timeframe",EnumToString(InpGapTimeframe));
   WriteRow(handle,"audit","gap_rule",StringFormat("gap greater than %d nominal bars",InpGapThresholdBars));
   WriteRow(handle,"audit","coverage_limit","TARGETED_NOT_EXHAUSTIVE","","Monthly quote samples and detected bar-gap windows only; full tester synchronization remains mandatory.");

   datetime times[];
   ResetLastError();
   int bars=CopyTime(g_symbol,InpGapTimeframe,target_start,now,times);
   int bar_error=GetLastError();
   WriteRow(handle,"bar_quality","bars_copied",IntegerToString(bars),"bars",bars<0 ? "error="+IntegerToString(bar_error) : "Timestamps only.");

   long duplicate_bar_times=0;
   long out_of_order_bar_times=0;
   int gap_count=0;
   int gaps_with_ticks=0;
   int gaps_without_ticks=0;
   int gap_query_errors=0;
   long missing_bar_slots=0;
   long maximum_gap=0;

   if(bars>1)
     {
      WriteRow(handle,"bar_quality","earliest",DateText(times[0]),"server_time");
      WriteRow(handle,"bar_quality","latest",DateText(times[bars-1]),"server_time");
      for(int i=1;i<bars;i++)
        {
         long gap=(long)(times[i]-times[i-1]);
         if(gap==0)
            duplicate_bar_times++;
         else if(gap<0)
            out_of_order_bar_times++;

         if(gap<=InpGapThresholdBars*period_seconds)
            continue;

         gap_count++;
         maximum_gap=MathMax(maximum_gap,gap);
         long missing=MathMax(0,(gap/period_seconds)-1);
         missing_bar_slots+=missing;
         datetime missing_start=(datetime)(times[i-1]+period_seconds);
         datetime missing_end=times[i];
         MqlTick gap_ticks[];
         int copy_error=0;
         int copied=CopyTickWindow(missing_start,missing_end,gap_ticks,copy_error);
         string classification;
         if(copied<0)
           {
            classification="TICK_QUERY_ERROR";
            gap_query_errors++;
           }
         else if(copied==0)
           {
            classification="NO_TICKS_QUOTE_GAP";
            gaps_without_ticks++;
           }
         else
           {
            classification="TICKS_PRESENT_BAR_GAP";
            gaps_with_ticks++;
           }

         string key=StringFormat("gap_%03d_",gap_count);
         WriteRow(handle,"gap",key+"previous_bar",DateText(times[i-1]),"server_time");
         WriteRow(handle,"gap",key+"next_bar",DateText(times[i]),"server_time");
         WriteRow(handle,"gap",key+"duration",StringFormat("%I64d",gap),"seconds");
         WriteRow(handle,"gap",key+"missing_bar_slots",StringFormat("%I64d",missing),"bars");
         WriteRow(handle,"gap",key+"ticks_inside",IntegerToString(copied),"ticks",copied<0 ? "error="+IntegerToString(copy_error) : "");
         WriteRow(handle,"gap",key+"classification",classification,"",classification=="NO_TICKS_QUOTE_GAP" ? "Manual schedule or outage explanation required." : "");
         if(copied>0)
           {
            WriteRow(handle,"gap",key+"first_tick_inside",DateText((datetime)gap_ticks[0].time),"server_time");
            WriteRow(handle,"gap",key+"last_tick_inside",DateText((datetime)gap_ticks[copied-1].time),"server_time");
           }
         ArrayFree(gap_ticks);
        }
     }

   WriteRow(handle,"bar_quality","duplicate_timestamps",StringFormat("%I64d",duplicate_bar_times),"bars");
   WriteRow(handle,"bar_quality","out_of_order_timestamps",StringFormat("%I64d",out_of_order_bar_times),"bars");
   WriteRow(handle,"bar_quality","large_gap_count",IntegerToString(gap_count),"gaps");
   WriteRow(handle,"bar_quality","missing_bar_slots",StringFormat("%I64d",missing_bar_slots),"bars");
   WriteRow(handle,"bar_quality","maximum_gap",StringFormat("%I64d",maximum_gap),"seconds");
   ArrayFree(times);

   int requested=InpYears*12;
   int samples_present=0;
   long invalid_quotes=0;
   long reversed_spreads=0;
   long out_of_order_ticks=0;
   long exact_duplicates=0;
   double point=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   for(int month=0;month<requested;month++)
     {
      datetime sample_start=MonthlySampleStart(target_start,month);
      datetime sample_end=sample_start+(InpTickSampleMinutes*60);
      PrintFormat("KingEA history quality: sample %d/%d at %s",month+1,requested,DateText(sample_start));
      MqlTick sample_ticks[];
      int copy_error=0;
      int copied=CopyTickWindow(sample_start,sample_end,sample_ticks,copy_error);
      string key=StringFormat("sample_%02d",month+1);
      WriteRow(handle,"tick_sample",key+"_start",DateText(sample_start),"server_time");
      WriteRow(handle,"tick_sample",key+"_end",DateText(sample_end),"server_time");
      if(copied<=0)
        {
         WriteRow(handle,"tick_sample",key+"_status",copied<0 ? "QUERY_ERROR" : "NO_TICKS","",copied<0 ? "error="+IntegerToString(copy_error) : "");
         ArrayFree(sample_ticks);
         continue;
        }

      samples_present++;
      TickQuality quality={};
      AnalyzeTicks(sample_ticks,copied,quality);
      WriteRow(handle,"tick_sample",key+"_status","PRESENT");
      WriteRow(handle,"tick_sample",key+"_first_tick",DateText((datetime)sample_ticks[0].time),"server_time");
      WriteRow(handle,"tick_sample",key+"_last_tick",DateText((datetime)sample_ticks[copied-1].time),"server_time");
      WriteTickQuality(handle,key,quality,point);
      invalid_quotes+=quality.invalid_quote_count;
      reversed_spreads+=quality.reversed_spread_count;
      out_of_order_ticks+=quality.out_of_order_count;
      exact_duplicates+=quality.exact_consecutive_duplicate_count;
      ArrayFree(sample_ticks);
     }

   double overall_min=0.0,overall_median=0.0,overall_p95=0.0,overall_p99=0.0,overall_max=0.0;
   if(g_sample_spread_count>0)
     {
      ArraySort(g_sample_spreads);
      overall_min=g_sample_spreads[0];
      overall_median=Percentile(g_sample_spreads,g_sample_spread_count,0.50);
      overall_p95=Percentile(g_sample_spreads,g_sample_spread_count,0.95);
      overall_p99=Percentile(g_sample_spreads,g_sample_spread_count,0.99);
      overall_max=g_sample_spreads[g_sample_spread_count-1];
     }

   long hard_anomalies=duplicate_bar_times+out_of_order_bar_times+gaps_with_ticks+
                       invalid_quotes+reversed_spreads+out_of_order_ticks;
   string status;
   if(bars<=1 || samples_present<requested || gap_query_errors>0 || hard_anomalies>0)
      status="FAIL_OR_INVESTIGATE_HARD_ANOMALY";
   else if(gaps_without_ticks>0 || exact_duplicates>0)
      status="PASS_TARGETED_CHECKS_WITH_MANUAL_REVIEW";
   else
      status="PASS_TARGETED_CHECKS";

   WriteRow(handle,"summary","status",status);
   WriteRow(handle,"summary","gap_count",IntegerToString(gap_count),"gaps");
   WriteRow(handle,"summary","gaps_with_ticks",IntegerToString(gaps_with_ticks),"gaps","Ticks inside a missing bar interval are a hard anomaly.");
   WriteRow(handle,"summary","gaps_without_ticks",IntegerToString(gaps_without_ticks),"gaps","Manual maintenance or outage classification is required.");
   WriteRow(handle,"summary","gap_query_errors",IntegerToString(gap_query_errors),"gaps");
   WriteRow(handle,"summary","tick_samples_present",IntegerToString(samples_present),"months");
   WriteRow(handle,"summary","tick_samples_requested",IntegerToString(requested),"months");
   WriteRow(handle,"summary","sampled_valid_spreads",IntegerToString(g_sample_spread_count),"ticks");
   WriteRow(handle,"summary","invalid_quotes",StringFormat("%I64d",invalid_quotes),"ticks");
   WriteRow(handle,"summary","reversed_spreads",StringFormat("%I64d",reversed_spreads),"ticks");
   WriteRow(handle,"summary","out_of_order_ticks",StringFormat("%I64d",out_of_order_ticks),"ticks");
   WriteRow(handle,"summary","exact_consecutive_duplicates",StringFormat("%I64d",exact_duplicates),"ticks","Informational pending pattern review.");
   int digits=(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS);
   WriteRow(handle,"summary","spread_min",DoubleToString(overall_min,digits),"price");
   WriteRow(handle,"summary","spread_median",DoubleToString(overall_median,digits),"price");
   WriteRow(handle,"summary","spread_p95",DoubleToString(overall_p95,digits),"price");
   WriteRow(handle,"summary","spread_p99",DoubleToString(overall_p99,digits),"price");
   WriteRow(handle,"summary","spread_max",DoubleToString(overall_max,digits),"price");
   WriteRow(handle,"summary","full_continuity_accepted","0","bool","This targeted audit cannot prove full five-year tick continuity.");

   FileFlush(handle);
   FileClose(handle);
   ArrayFree(g_sample_spreads);

   string full_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename;
   PrintFormat("KingEA history quality audit complete: %s",full_path);
   PrintFormat("Result: %s; gaps=%d; gaps_with_ticks=%d; monthly_samples=%d/%d. Send the CSV to Codex.",
               status,gap_count,gaps_with_ticks,samples_present,requested);
  }
