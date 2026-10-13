#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only five-year bar and sampled real-tick history availability smoke test."
#property description "This script contains no trading, signal, indicator, return, or optimizer logic."

input string InpSymbol            = "ETHUSD.s";
input int    InpYears             = 5;
input int    InpTickSampleMinutes = 60;

string g_symbol;
string g_utc_time;
string g_server_time;

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
   if(value<=0)
      return "UNAVAILABLE";
   return TimeToString(value,TIME_DATE|TIME_SECONDS);
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
   FileWrite(handle,g_utc_time,g_server_time,section,key,value,unit,notes);
  }

datetime YearsBefore(const datetime value,const int years)
  {
   MqlDateTime parts={};
   if(!TimeToStruct(value,parts))
      return 0;

   parts.year-=years;
   // StructToTime normalizes 29 February automatically where necessary.
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
      result+=24*60*60;       // Sunday -> Monday
   else if(normalized.day_of_week==6)
      result+=2*24*60*60;    // Saturday -> Monday
   return result;
  }

void WriteSeriesSnapshot(const int handle,
                         const string phase,
                         const ENUM_TIMEFRAMES period)
  {
   const string prefix=phase+"_"+EnumToString(period)+"_";
   long value=0;
   ResetLastError();
   if(SeriesInfoInteger(g_symbol,period,SERIES_SERVER_FIRSTDATE,value))
      WriteRow(handle,"series",prefix+"server_first_date",DateText((datetime)value),"server_time");
   else
      WriteRow(handle,"series",prefix+"server_first_date","ERROR","","error="+IntegerToString(GetLastError()));

   ResetLastError();
   if(SeriesInfoInteger(g_symbol,period,SERIES_TERMINAL_FIRSTDATE,value))
      WriteRow(handle,"series",prefix+"terminal_first_date",DateText((datetime)value),"server_time");
   else
      WriteRow(handle,"series",prefix+"terminal_first_date","ERROR","","error="+IntegerToString(GetLastError()));

   ResetLastError();
   if(SeriesInfoInteger(g_symbol,period,SERIES_FIRSTDATE,value))
      WriteRow(handle,"series",prefix+"chart_first_date",DateText((datetime)value),"server_time");
   else
      WriteRow(handle,"series",prefix+"chart_first_date","ERROR","","error="+IntegerToString(GetLastError()));

   ResetLastError();
   if(SeriesInfoInteger(g_symbol,period,SERIES_SYNCHRONIZED,value))
      WriteRow(handle,"series",prefix+"synchronized",StringFormat("%I64d",value),"bool");
  }

bool ScanBars(const int handle,
              const ENUM_TIMEFRAMES period,
              const datetime target_start,
              const datetime now)
  {
   datetime times[];
   ResetLastError();
   int copied=CopyTime(g_symbol,period,target_start,now,times);
   int copy_error=GetLastError();
   string prefix=EnumToString(period)+"_";

   WriteRow(handle,"bar_scan",prefix+"copied",IntegerToString(copied),"bars",
            copied<0 ? "error="+IntegerToString(copy_error) : "Timestamps only; OHLC and returns are not evaluated.");
   if(copied<=0)
     {
      ArrayFree(times);
      WriteRow(handle,"bar_scan",prefix+"target_reached","0","bool","No timestamps returned.");
      return false;
     }

   datetime earliest=times[0];
   datetime latest=times[copied-1];
   long nominal_seconds=PeriodSeconds(period);
   long maximum_gap=0;
   int large_gap_count=0;
   for(int i=1;i<copied;i++)
     {
      long gap=(long)(times[i]-times[i-1]);
      if(gap>maximum_gap)
         maximum_gap=gap;
      if(nominal_seconds>0 && gap>(2*nominal_seconds))
         large_gap_count++;
     }

   // Permit one complete timeframe because the requested boundary may be inside a bar.
   bool target_reached=(earliest<=target_start+nominal_seconds);
   WriteRow(handle,"bar_scan",prefix+"earliest",DateText(earliest),"server_time");
   WriteRow(handle,"bar_scan",prefix+"latest",DateText(latest),"server_time");
   WriteRow(handle,"bar_scan",prefix+"target_reached",BoolText(target_reached),"bool",
            "Boundary tolerance is one complete timeframe.");
   WriteRow(handle,"bar_scan",prefix+"large_gap_count",IntegerToString(large_gap_count),"gaps",
            "A large gap is greater than twice the nominal timeframe; investigate rather than automatically reject.");
   WriteRow(handle,"bar_scan",prefix+"maximum_gap",StringFormat("%I64d",maximum_gap),"seconds");
   ArrayFree(times);
   return target_reached;
  }

bool SampleTickMonth(const int handle,
                     const int sample_number,
                     const datetime sample_start,
                     const int sample_minutes)
  {
   datetime sample_end=sample_start+(sample_minutes*60);
   MqlTick ticks[];
   int copied=-1;
   int copy_error=0;

   for(int attempt=1;attempt<=2;attempt++)
     {
      ResetLastError();
      copied=CopyTicksRange(g_symbol,ticks,COPY_TICKS_ALL,
                            ((ulong)sample_start)*1000,
                            ((ulong)sample_end)*1000);
      copy_error=GetLastError();
      if(copied>=0)
         break;
      Sleep(250);
     }

   string key=StringFormat("month_%02d_",sample_number+1);
   WriteRow(handle,"tick_sample",key+"window_start",DateText(sample_start),"server_time");
   WriteRow(handle,"tick_sample",key+"window_end",DateText(sample_end),"server_time");
   WriteRow(handle,"tick_sample",key+"count",IntegerToString(copied),"ticks",
            copied<0 ? "error="+IntegerToString(copy_error) : "Presence sample only; prices and returns are not evaluated.");

   bool passed=(copied>0);
   WriteRow(handle,"tick_sample",key+"present",BoolText(passed),"bool");
   if(passed)
     {
      WriteRow(handle,"tick_sample",key+"first_tick",DateText((datetime)ticks[0].time),"server_time");
      WriteRow(handle,"tick_sample",key+"last_tick",DateText((datetime)ticks[copied-1].time),"server_time");
     }
   ArrayFree(ticks);
   return passed;
  }

void OnStart()
  {
   g_symbol=(StringLen(InpSymbol)>0 ? InpSymbol : _Symbol);
   datetime now=TimeTradeServer();
   g_utc_time=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   g_server_time=TimeToString(now,TIME_DATE|TIME_SECONDS);

   if(InpYears<1 || InpYears>20)
     {
      Print("KingEA history smoke test failed: InpYears must be between 1 and 20.");
      return;
     }
   if(InpTickSampleMinutes<5 || InpTickSampleMinutes>360)
     {
      Print("KingEA history smoke test failed: InpTickSampleMinutes must be between 5 and 360.");
      return;
     }
   if(now<=0 || !SymbolSelect(g_symbol,true))
     {
      PrintFormat("KingEA history smoke test failed: cannot initialize symbol '%s'; error=%d",g_symbol,GetLastError());
      return;
     }

   datetime target_start=YearsBefore(now,InpYears);
   if(target_start<=0)
     {
      Print("KingEA history smoke test failed: invalid target boundary.");
      return;
     }

   string stamp=SafeName(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   string filename="KingEA\\history_smoke_"+SafeName(g_symbol)+"_"+IntegerToString(InpYears)+"Y_"+stamp+".csv";
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA history smoke test failed: FileOpen('%s') error=%d",filename,GetLastError());
      return;
     }

   FileWrite(handle,"snapshot_utc","snapshot_server","section","key","value","unit","notes");
   WriteRow(handle,"audit","scope","NON_PERFORMANCE_HISTORY_AVAILABILITY_SMOKE_TEST");
   WriteRow(handle,"audit","prohibited","No orders, signals, indicators, OHLC analysis, returns, win rate, expectancy, parameter testing, ranking, or optimization.");
   WriteRow(handle,"audit","symbol",g_symbol);
   WriteRow(handle,"audit","years_requested",IntegerToString(InpYears),"years");
   WriteRow(handle,"audit","target_start",DateText(target_start),"server_time");
   WriteRow(handle,"audit","tick_sampling","ONE_FIXED_WINDOW_PER_MONTH","",
            "A passing sample does not prove complete real-tick continuity; final tester synchronization and gap validation remain mandatory.");

   ENUM_TIMEFRAMES snapshot_periods[4]={PERIOD_M1,PERIOD_M30,PERIOD_H4,PERIOD_D1};
   for(int i=0;i<ArraySize(snapshot_periods);i++)
      WriteSeriesSnapshot(handle,"before",snapshot_periods[i]);

   bool m30_ok=ScanBars(handle,PERIOD_M30,target_start,now);
   bool h4_ok=ScanBars(handle,PERIOD_H4,target_start,now);
   bool d1_ok=ScanBars(handle,PERIOD_D1,target_start,now);

   int requested=InpYears*12;
   int passed=0;
   for(int month=0;month<requested;month++)
     {
      datetime sample_start=MonthlySampleStart(target_start,month);
      PrintFormat("KingEA history smoke: tick sample %d/%d at %s",month+1,requested,DateText(sample_start));
      if(sample_start>0 && sample_start<=now && SampleTickMonth(handle,month,sample_start,InpTickSampleMinutes))
         passed++;
     }

   for(int i=0;i<ArraySize(snapshot_periods);i++)
      WriteSeriesSnapshot(handle,"after",snapshot_periods[i]);

   int failed=requested-passed;
   bool bar_pass=(m30_ok && h4_ok && d1_ok);
   bool tick_sample_pass=(failed==0);
   WriteRow(handle,"summary","bar_boundary_pass",BoolText(bar_pass),"bool","Requires M30, H4, and D1 to reach the five-year boundary.");
   WriteRow(handle,"summary","tick_months_requested",IntegerToString(requested),"months");
   WriteRow(handle,"summary","tick_months_present",IntegerToString(passed),"months");
   WriteRow(handle,"summary","tick_months_missing_or_error",IntegerToString(failed),"months");
   WriteRow(handle,"summary","tick_sample_pass",BoolText(tick_sample_pass),"bool","All fixed monthly sample windows must contain at least one real tick.");
   WriteRow(handle,"summary","smoke_test_pass",BoolText(bar_pass && tick_sample_pass),"bool",
            "Smoke pass means history appears available; it is not a continuity, quality, or strategy-performance acceptance result.");

   FileFlush(handle);
   FileClose(handle);

   string full_path=TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename;
   PrintFormat("KingEA history smoke test complete: %s",full_path);
   PrintFormat("Result: bars=%s, sampled_tick_months=%d/%d. Send the CSV to Codex for the audit.",
               bar_pass ? "PASS" : "FAIL",passed,requested);
  }
