#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only probe for partial custom tick-history reads."
#property description "No custom-symbol mutation; orders; signals; indicators; returns; or optimizer logic."

input string InpOriginSymbol = "ETHUSD.s";
input string InpCustomSymbol = "KINGEA_ETHUSD_S_RSB2";

const long EARLY_FROM = 1625097600000;      // 2021-07-01
const long TRANSITION_FROM = 1694390400000; // 2023-09-11
const long DAY_MSC = 86400000;

void ProbeRange(const int handle,const string label,const string symbol,
                const long from_msc,const long to_msc_exclusive,const int attempts)
  {
   for(int attempt=1;attempt<=attempts;attempt++)
     {
      MqlTick ticks[];
      ResetLastError();
      ulong started=GetTickCount64();
      int copied=CopyTicksRange(symbol,ticks,COPY_TICKS_ALL,(ulong)from_msc,(ulong)(to_msc_exclusive-1));
      ulong elapsed=GetTickCount64()-started;
      int error=GetLastError();
      long first=(copied>0 ? ticks[0].time_msc : 0);
      long last=(copied>0 ? ticks[copied-1].time_msc : 0);
      FileWrite(handle,label,symbol,attempt,from_msc,to_msc_exclusive,copied,error,elapsed,first,last);
      ArrayFree(ticks);
      if(attempt<attempts) Sleep(1000);
     }
  }

void ProbeDay(const int handle,const string day_label,const long day_from)
  {
   long day_to=day_from+DAY_MSC;
   ProbeRange(handle,day_label+"_origin_full",InpOriginSymbol,day_from,day_to,2);
   ProbeRange(handle,day_label+"_custom_full",InpCustomSymbol,day_from,day_to,5);
   ProbeRange(handle,day_label+"_custom_first_half",InpCustomSymbol,day_from,day_from+DAY_MSC/2,2);
   ProbeRange(handle,day_label+"_custom_second_half",InpCustomSymbol,day_from+DAY_MSC/2,day_to,2);
   for(int hour=0;hour<24;hour++)
     {
      long from=day_from+(long)hour*60*60*1000;
      ProbeRange(handle,day_label+StringFormat("_custom_hour_%02d",hour),InpCustomSymbol,from,from+60*60*1000,1);
     }
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA retention diagnostic refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !SymbolSelect(InpCustomSymbol,true))
     {
      PrintFormat("KingEA retention diagnostic failed: symbols unavailable; error=%d",GetLastError());
      return;
     }
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\custom_tick_retention_diagnostic_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA retention diagnostic failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"label","symbol","attempt","from_msc","to_msc_exclusive","copied","error","elapsed_ms","first_tick_msc","last_tick_msc");
   ProbeDay(handle,"early_2021_07_01",EARLY_FROM);
   ProbeDay(handle,"transition_2023_09_11",TRANSITION_FROM);
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA custom tick retention diagnostic: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   Print("Result: COMPLETE. Read-only probe; RSB1 and RSB2 untouched. Send the CSV to Codex.");
  }
