#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only reproduction of the native reduced-build failing daily batch."
#property description "No custom-symbol mutation; orders; signals; indicators; returns; or optimizer logic."

input string InpSymbol = "ETHUSD.s";

const long REPRO_FROM_MSC = 1669507200000; // 2022-11-27 00:00:00 broker time
const long REPRO_TO_MSC = 1669593600000;   // 2022-11-28 00:00:00 broker time; exclusive

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

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA diagnostic refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpSymbol,true))
     {
      PrintFormat("KingEA diagnostic failed: cannot select %s; error=%d",InpSymbol,GetLastError());
      return;
     }

   MqlTick ticks[];
   ResetLastError();
   int copied=CopyTicksRange(InpSymbol,ticks,COPY_TICKS_ALL,(ulong)REPRO_FROM_MSC,(ulong)(REPRO_TO_MSC-1));
   int copy_error=GetLastError();
   if(copied<0)
     {
      PrintFormat("KingEA diagnostic failed: CopyTicksRange error=%d",copy_error);
      return;
     }

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\native_build_failure_diagnostic_"+SafeName(InpSymbol)+"_"+SafeName(utc)+".csv";
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA diagnostic failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"section","index","reason","time_msc","server_time","previous_time_msc","bid","ask","spread","last","flags");
   FileWrite(handle,"scope","","READ_ONLY_EXACT_DAILY_BUILD_REPRO",REPRO_FROM_MSC,TickTimeText(REPRO_FROM_MSC),"","","","","","");

   long previous=0;
   int violations=0;
   int backward=0;
   int invalid_number=0;
   int nonpositive_bid=0;
   int nonpositive_spread=0;
   int out_of_range=0;
   int same_millisecond=0;
   for(int i=0;i<copied;i++)
     {
      string reason="";
      if(!MathIsValidNumber(ticks[i].bid) || !MathIsValidNumber(ticks[i].ask))
        {
         reason="INVALID_NUMBER";
         invalid_number++;
        }
      else if(ticks[i].time_msc<REPRO_FROM_MSC || ticks[i].time_msc>=REPRO_TO_MSC)
        {
         reason="OUT_OF_RANGE";
         out_of_range++;
        }
      else if(previous>0 && ticks[i].time_msc<previous)
        {
         reason="BACKWARD_TIMESTAMP";
         backward++;
        }
      else if(ticks[i].bid<=0.0)
        {
         reason="NONPOSITIVE_BID";
         nonpositive_bid++;
        }
      else if(ticks[i].ask<=ticks[i].bid)
        {
         reason=(ticks[i].ask==ticks[i].bid ? "ZERO_SPREAD" : "REVERSED_SPREAD");
         nonpositive_spread++;
        }

      if(previous>0 && ticks[i].time_msc==previous)
         same_millisecond++;
      if(StringLen(reason)>0)
        {
         violations++;
         FileWrite(handle,"violation",i,reason,ticks[i].time_msc,TickTimeText(ticks[i].time_msc),previous,
                   DoubleToString(ticks[i].bid,8),DoubleToString(ticks[i].ask,8),
                   DoubleToString(ticks[i].ask-ticks[i].bid,8),DoubleToString(ticks[i].last,8),ticks[i].flags);
        }
      previous=ticks[i].time_msc;
     }

   FileWrite(handle,"summary","","copied_ticks",copied,"","","","","","","");
   FileWrite(handle,"summary","","violations",violations,"","","","","","","");
   FileWrite(handle,"summary","","invalid_number",invalid_number,"","","","","","","");
   FileWrite(handle,"summary","","out_of_range",out_of_range,"","","","","","","");
   FileWrite(handle,"summary","","backward_timestamp",backward,"","","","","","","");
   FileWrite(handle,"summary","","nonpositive_bid",nonpositive_bid,"","","","","","","");
   FileWrite(handle,"summary","","nonpositive_spread",nonpositive_spread,"","","","","","","");
   FileWrite(handle,"summary","","same_millisecond_informational",same_millisecond,"","","","","","","");
   FileWrite(handle,"result","",violations>0 ? "REPRODUCED" : "NOT_REPRODUCED",violations,"","","","","","","");
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA native build diagnostic complete: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; ticks=%d; violations=%d. Read-only diagnostic; partial custom symbol untouched.",
               violations>0 ? "REPRODUCED" : "NOT_REPRODUCED",copied,violations);
  }
