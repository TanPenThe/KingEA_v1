#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only exact-day diagnostic for the RSB2 reversed-spread preflight failure."
#property description "No custom-symbol mutation; orders; signals; indicators; returns; or optimizer logic."

input string InpSymbol = "ETHUSD.s";

const long REPRO_FROM_MSC = 1709337600000; // 2024-03-02 00:00:00 broker time
const long REPRO_TO_MSC = 1709424000000;   // 2024-03-03 00:00:00 broker time; exclusive
const int CONTEXT_TICKS = 3;

string SafeName(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,"/","-");
   StringReplace(value,"\\","-");
   return value;
  }

string TickTimeText(const long time_msc)
  {
   return TimeToString((datetime)(time_msc/1000),TIME_DATE|TIME_SECONDS)+StringFormat(".%03d",(int)(time_msc%1000));
  }

void WriteTick(const int handle,const string section,const int violation_index,
               const int tick_index,const MqlTick &tick)
  {
   FileWrite(handle,section,violation_index,tick_index,tick.time_msc,TickTimeText(tick.time_msc),
             DoubleToString(tick.bid,8),DoubleToString(tick.ask,8),
             DoubleToString(tick.ask-tick.bid,8),DoubleToString(tick.last,8),tick.flags);
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA reversed-spread diagnostic refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpSymbol,true))
     {
      PrintFormat("KingEA reversed-spread diagnostic failed: cannot select %s; error=%d",InpSymbol,GetLastError());
      return;
     }

   MqlTick ticks[];
   ResetLastError();
   int copied=CopyTicksRange(InpSymbol,ticks,COPY_TICKS_ALL,(ulong)REPRO_FROM_MSC,(ulong)(REPRO_TO_MSC-1));
   int copy_error=GetLastError();
   if(copied<0)
     {
      PrintFormat("KingEA reversed-spread diagnostic failed: CopyTicksRange error=%d",copy_error);
      return;
     }

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\reversed_spread_diagnostic_"+SafeName(InpSymbol)+"_"+SafeName(utc)+".csv";
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA reversed-spread diagnostic failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"section","violation_index","tick_index","time_msc","server_time","bid","ask","spread","last","flags");

   int reversed=0;
   int zero=0;
   int backward=0;
   int invalid=0;
   double most_negative=0.0;
   long first_reversed_msc=0;
   long last_reversed_msc=0;
   long previous=0;
   for(int i=0;i<copied;i++)
     {
      if(!MathIsValidNumber(ticks[i].bid) || !MathIsValidNumber(ticks[i].ask) || ticks[i].bid<=0.0)
         invalid++;
      if(previous>0 && ticks[i].time_msc<previous)
         backward++;
      previous=ticks[i].time_msc;
      double spread=ticks[i].ask-ticks[i].bid;
      if(spread==0.0)
         zero++;
      if(spread>=0.0)
         continue;

      if(first_reversed_msc==0)
         first_reversed_msc=ticks[i].time_msc;
      last_reversed_msc=ticks[i].time_msc;
      most_negative=MathMin(most_negative,spread);
      int violation_index=reversed;
      reversed++;
      int context_from=MathMax(0,i-CONTEXT_TICKS);
      int context_to=MathMin(copied-1,i+CONTEXT_TICKS);
      for(int j=context_from;j<=context_to;j++)
         WriteTick(handle,j==i ? "violation" : "context",violation_index,j,ticks[j]);
     }

   FileWrite(handle,"summary",-1,-1,REPRO_FROM_MSC,TickTimeText(REPRO_FROM_MSC),"copied_ticks",copied,"","","");
   FileWrite(handle,"summary",-1,-1,REPRO_TO_MSC,TickTimeText(REPRO_TO_MSC),"reversed_spreads",reversed,"","","");
   FileWrite(handle,"summary",-1,-1,first_reversed_msc,first_reversed_msc>0 ? TickTimeText(first_reversed_msc) : "UNAVAILABLE","first_reversed_msc",first_reversed_msc,"","","");
   FileWrite(handle,"summary",-1,-1,last_reversed_msc,last_reversed_msc>0 ? TickTimeText(last_reversed_msc) : "UNAVAILABLE","last_reversed_msc",last_reversed_msc,"","","");
   FileWrite(handle,"summary",-1,-1,0,"","most_negative_spread",DoubleToString(most_negative,8),"","","");
   FileWrite(handle,"summary",-1,-1,0,"","zero_spreads",zero,"","","");
   FileWrite(handle,"summary",-1,-1,0,"","backward_timestamps",backward,"","","");
   FileWrite(handle,"summary",-1,-1,0,"","invalid_quotes",invalid,"","","");
   FileWrite(handle,"result",-1,-1,0,"",reversed>0 ? "REPRODUCED" : "NOT_REPRODUCED",reversed,"","","");
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA reversed-spread diagnostic complete: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; ticks=%d; reversed=%d. Read-only; RSB1 and RSB2 untouched.",
               reversed>0 ? "REPRODUCED" : "NOT_REPRODUCED",copied,reversed);
  }
