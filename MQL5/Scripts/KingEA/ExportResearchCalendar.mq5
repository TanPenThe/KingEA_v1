#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only Stage 14 high-impact USD calendar exporter."

input string InpExpectedServerContains="Demo2";
input string InpAuthorization="";
input datetime InpStart=0;
input datetime InpEnd=0;
input int InpConnectionTimeoutSeconds=60;

bool ContainsInsensitive(string value,string expected)
  {
   StringToUpper(value);
   StringToUpper(expected);
   return expected!="" && StringFind(value,expected)>=0;
  }

bool WaitForCalendarConnection()
  {
   if(InpConnectionTimeoutSeconds<1 || InpConnectionTimeoutSeconds>300)
      return false;
   ulong deadline=GetTickCount64()+(ulong)InpConnectionTimeoutSeconds*1000;
   while(!TerminalInfoInteger(TERMINAL_CONNECTED) && !IsStopped())
     {
      if(GetTickCount64()>=deadline)
         return false;
      Sleep(250);
     }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) || IsStopped())
      return false;
   // The account connection can become visible slightly before the terminal's
   // calendar service finishes synchronizing. This bounded pause prevents the
   // startup race reproduced in the first two Stage 14 attempts.
   Sleep(2000);
   return TerminalInfoInteger(TERMINAL_CONNECTED) &&
          ContainsInsensitive(AccountInfoString(ACCOUNT_SERVER),
                              InpExpectedServerContains);
  }

void OnStart()
  {
   if(InpAuthorization!="AUTHORIZE_STAGE14_CALENDAR_EXPORT_20260802" ||
      InpStart<=0 || InpEnd<=InpStart)
     {
      PrintFormat("KingEA Stage 14 calendar export refused: authorization_ok=%d start=%s end=%s.",
                  (InpAuthorization=="AUTHORIZE_STAGE14_CALENDAR_EXPORT_20260802"),
                  TimeToString(InpStart,TIME_DATE|TIME_SECONDS),
                  TimeToString(InpEnd,TIME_DATE|TIME_SECONDS));
      return;
     }
   if(!WaitForCalendarConnection())
     {
      PrintFormat("KingEA Stage 14 calendar export FAIL: Demo2 connection/calendar synchronization timeout after %d seconds.",
                  InpConnectionTimeoutSeconds);
      return;
     }
   if(InpEnd>TimeTradeServer()+86400)
     {
      Print("KingEA Stage 14 calendar export refused: range ends beyond the connected trade-server allowance.");
      return;
     }
   MqlCalendarCountry countries[];
   ResetLastError();
   int country_count=CalendarCountries(countries);
   int country_error=GetLastError();
   MqlCalendarEvent usd_events[];
   ResetLastError();
   int event_count=CalendarEventByCurrency("USD",usd_events);
   int event_error=GetLastError();
   datetime recent_end=TimeTradeServer()+7*86400;
   datetime recent_start=TimeTradeServer()-30*86400;
   MqlCalendarValue recent_values[];
   ResetLastError();
   int recent_count=CalendarValueHistory(recent_values,recent_start,recent_end,"US","USD");
   int recent_error=GetLastError();
   PrintFormat("KingEA Stage 14 calendar diagnostic: countries=%d country_error=%d USD_events=%d event_error=%d recent_values=%d recent_error=%d.",
               country_count,country_error,event_count,event_error,recent_count,recent_error);

   MqlCalendarValue values[];
   int count=0,query_error=0;
   for(int attempt=1;attempt<=5;attempt++)
     {
      ResetLastError();
      count=CalendarValueHistory(values,InpStart,InpEnd,"US","USD");
      query_error=GetLastError();
      PrintFormat("KingEA Stage 14 calendar history attempt %d/5: count=%d error=%d.",
                  attempt,count,query_error);
      if(count!=0 || query_error!=0)
         break;
      if(attempt<5)
         Sleep(3000);
     }
   if(count<0 || query_error!=0)
     {
      PrintFormat("KingEA Stage 14 calendar export FAIL: count=%d error=%d",count,query_error);
      return;
     }
   string stamp=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   StringReplace(stamp,".","-");
   StringReplace(stamp,":","-");
   StringReplace(stamp," ","_");
   string filename="KingEA\\research_calendar_raw_USD_HIGH_"+stamp+".csv";
   int file=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,
                     ',',CP_UTF8);
   if(file==INVALID_HANDLE)
     {
      PrintFormat("KingEA Stage 14 calendar export FAIL: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(file,"schema","event_id","value_id","time","time_msc",
             "importance","event_type","sector","time_mode","country_id",
             "name","source_url");
   int written=0,event_failures=0;
   for(int i=0;i<count;i++)
     {
      MqlCalendarEvent event={};
      if(!CalendarEventById(values[i].event_id,event))
        { event_failures++; continue; }
      if(event.importance!=CALENDAR_IMPORTANCE_HIGH)
         continue;
      FileWrite(file,1,(string)event.id,(string)values[i].id,
                TimeToString(values[i].time,TIME_DATE|TIME_SECONDS),
                (string)((long)values[i].time*1000),
                IntegerToString((int)event.importance),
                IntegerToString((int)event.type),
                IntegerToString((int)event.sector),
                IntegerToString((int)event.time_mode),
                (string)event.country_id,event.name,event.source_url);
      written++;
     }
   FileFlush(file);
   FileClose(file);
   PrintFormat("KingEA Stage 14 calendar export complete: %s\\Files\\%s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH),filename);
   PrintFormat("Result: %s; countries=%d; USD_events=%d; recent_values=%d; query_values=%d; high_impact_written=%d; event_failures=%d; query_error=%d; read-only; no research authorization.",
               (written>0 && event_failures==0 ? "PASS" : "FAIL"),country_count,
               event_count,recent_count,count,written,
               event_failures,query_error);
  }
