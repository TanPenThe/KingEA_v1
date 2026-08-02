#property copyright "KingEA"
#property version   "1.02"
#property script_show_inputs
#property description "Read-only comparison of native/custom tick and bar readiness for Strategy Tester."
#property description "No custom-history mutation; orders; signals; indicators; returns; or optimizer logic."
#property description "Build ID: TESTER-READINESS-20260725-C."

input string InpOriginSymbol = "ETHUSD.s";
input string InpCustomSymbol = "KINGEA_ETHUSD_S_RSB3";
input string InpWindowStart = "2021.07.01 00:00:00";
input string InpWindowEnd = "2021.07.02 00:00:00";

int CopyRatesReady(const string symbol,const ENUM_TIMEFRAMES period,
                   const datetime start_time,const datetime end_time,
                   MqlRates &rates[],int &copy_error)
  {
   int copied=-1;
   copy_error=0;
   for(int attempt=0;attempt<300;attempt++)
     {
      ResetLastError();
      copied=CopyRates(symbol,period,start_time,end_time-1,rates);
      copy_error=GetLastError();
      if(copied>0)
         return copied;
      if(attempt<299)
         Sleep(100);
     }
   return copied;
  }

int WriteSeries(int report,const string symbol,const ENUM_TIMEFRAMES period,
                const datetime start_time,const datetime end_time)
  {
   MqlRates rates[];
   int copy_error=0;
   int copied=CopyRatesReady(symbol,period,start_time,end_time,rates,copy_error);
   long first_time=(copied>0 ? (long)rates[0].time : 0);
   long last_time=(copied>0 ? (long)rates[copied-1].time : 0);
   long synchronized=0;
   long series_first=0;
   ResetLastError();
   bool sync_ok=SeriesInfoInteger(symbol,period,SERIES_SYNCHRONIZED,synchronized);
   int sync_error=GetLastError();
   SeriesInfoInteger(symbol,period,SERIES_FIRSTDATE,series_first);
   FileWrite(report,"series",symbol,EnumToString(period),"copied",copied,StringFormat("copy_error=%d",copy_error));
   FileWrite(report,"series",symbol,EnumToString(period),"first_time",first_time,"");
   FileWrite(report,"series",symbol,EnumToString(period),"last_time",last_time,"");
   FileWrite(report,"series",symbol,EnumToString(period),"synchronized",synchronized,StringFormat("query_ok=%d|error=%d",sync_ok ? 1 : 0,sync_error));
   FileWrite(report,"series",symbol,EnumToString(period),"series_firstdate",series_first,"");
   return copied;
  }

int CountSessions(const string symbol,const ENUM_DAY_OF_WEEK day,const bool trade)
  {
   int count=0;
   for(uint index=0;index<64;index++)
     {
      datetime from=0;
      datetime to=0;
      bool found=(trade ? SymbolInfoSessionTrade(symbol,day,index,from,to)
                         : SymbolInfoSessionQuote(symbol,day,index,from,to));
      if(!found)
         break;
      count++;
     }
   return count;
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA tester-readiness diagnostic refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !SymbolSelect(InpCustomSymbol,true))
     {
      PrintFormat("KingEA tester-readiness diagnostic failed: symbols unavailable; error=%d",GetLastError());
      return;
     }
   bool is_custom=false;
   if(!SymbolExist(InpCustomSymbol,is_custom) || !is_custom)
     {
      Print("KingEA tester-readiness diagnostic failed: target is not a local custom symbol.");
      return;
     }
   datetime start_time=StringToTime(InpWindowStart);
   datetime end_time=StringToTime(InpWindowEnd);
   if(start_time<=0 || end_time<=start_time)
     {
      Print("KingEA tester-readiness diagnostic failed: invalid half-open window.");
      return;
     }
   long start_msc=(long)start_time*1000;
   long end_msc=(long)end_time*1000;

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\custom_tester_readiness_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA tester-readiness diagnostic failed: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"section","symbol","scope","key","value","notes");
   FileWrite(report,"run","",server,"build_id","TESTER-READINESS-20260725-C","");
   FileWrite(report,"run","",server,"window_start",InpWindowStart,"inclusive");
   FileWrite(report,"run","",server,"window_end",InpWindowEnd,"exclusive");

   string symbols[2]={InpOriginSymbol,InpCustomSymbol};
   int tick_counts[2]={0,0};
   int m1_counts[2]={0,0};
   int m30_counts[2]={0,0};
   bool pass=true;
   for(int s=0;s<2;s++)
     {
      string symbol=symbols[s];
      bool custom=false;
      SymbolExist(symbol,custom);
      ResetLastError();
      MqlTick ticks[];
      int tick_count=CopyTicksRange(symbol,ticks,COPY_TICKS_ALL,(ulong)start_msc,(ulong)(end_msc-1));
      tick_counts[s]=tick_count;
      int tick_error=GetLastError();
      FileWrite(report,"symbol",symbol,"property","custom",custom ? "1" : "0","");
      FileWrite(report,"ticks",symbol,"window","count",tick_count,StringFormat("error=%d",tick_error));
      FileWrite(report,"ticks",symbol,"window","first_time_msc",tick_count>0 ? ticks[0].time_msc : 0,"");
      FileWrite(report,"ticks",symbol,"window","last_time_msc",tick_count>0 ? ticks[tick_count-1].time_msc : 0,"");
      int m1_count=WriteSeries(report,symbol,PERIOD_M1,start_time,end_time);
      int m30_count=WriteSeries(report,symbol,PERIOD_M30,start_time,end_time);
      m1_counts[s]=m1_count;
      m30_counts[s]=m30_count;
      for(int day=MONDAY;day<=SUNDAY;day++)
        {
         int quote_sessions=CountSessions(symbol,(ENUM_DAY_OF_WEEK)day,false);
         int trade_sessions=CountSessions(symbol,(ENUM_DAY_OF_WEEK)day,true);
         FileWrite(report,"sessions",symbol,EnumToString((ENUM_DAY_OF_WEEK)day),"quote_count",quote_sessions,"");
         FileWrite(report,"sessions",symbol,EnumToString((ENUM_DAY_OF_WEEK)day),"trade_count",trade_sessions,"");
        }
      if(tick_count<=0 || m1_count<=0 || m30_count<=0)
         pass=false;
     }
   bool counts_match=(tick_counts[0]==tick_counts[1] &&
                      m1_counts[0]==m1_counts[1] &&
                      m30_counts[0]==m30_counts[1]);
   FileWrite(report,"comparison","","window","tick_count_match",tick_counts[0]==tick_counts[1] ? "1" : "0",
             StringFormat("origin=%d|custom=%d",tick_counts[0],tick_counts[1]));
   FileWrite(report,"comparison","","window","m1_count_match",m1_counts[0]==m1_counts[1] ? "1" : "0",
             StringFormat("origin=%d|custom=%d",m1_counts[0],m1_counts[1]));
   FileWrite(report,"comparison","","window","m30_count_match",m30_counts[0]==m30_counts[1] ? "1" : "0",
             StringFormat("origin=%d|custom=%d",m30_counts[0],m30_counts[1]));
   if(!counts_match)
      pass=false;
   FileWrite(report,"result","","","status",pass ? "PASS" : "FAIL","read-only; RSB3 untouched; no performance authorization");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA custom tester-readiness report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s. Read-only; RSB3 untouched; no performance authorization.",pass ? "PASS" : "FAIL");
  }
