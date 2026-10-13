#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only field comparator for origin and stored crossed-tick probe."
#property description "No custom-symbol mutation; orders; signals; indicators; returns; or optimizer logic."

input string InpOriginSymbol = "ETHUSD.s";
input string InpProbeSymbol = "KINGEA_DIAG_CROSSED_V1";

const long TIMES_MSC[2] = {1709374488223,1709375322820};

bool CopyExact(const string symbol,const long time_msc,MqlTick &result)
  {
   MqlTick ticks[];
   ResetLastError();
   int copied=CopyTicksRange(symbol,ticks,COPY_TICKS_ALL,(ulong)time_msc,(ulong)time_msc);
   if(copied!=1)
     {
      PrintFormat("KingEA field comparison failed: symbol=%s time=%I64d copied=%d error=%d",symbol,time_msc,copied,GetLastError());
      return false;
     }
   result=ticks[0];
   return true;
  }

void WriteField(const int handle,const int tick_number,const string field,
                const string origin,const string stored)
  {
   FileWrite(handle,tick_number,field,origin,stored,origin==stored ? "MATCH" : "DIFF");
  }

void OnStart()
  {
   if(StringFind(AccountInfoString(ACCOUNT_SERVER),"Demo2")<0)
     {
      Print("KingEA field comparison refused: run on JustMarkets-Demo2.");
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !SymbolSelect(InpProbeSymbol,true))
     {
      PrintFormat("KingEA field comparison failed: symbols unavailable; error=%d",GetLastError());
      return;
     }
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\crossed_tick_field_comparison_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA field comparison failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"tick_number","field","origin","stored","result");
   int diffs=0;
   int nonflag_diffs=0;
   for(int i=0;i<2;i++)
     {
      MqlTick origin={};
      MqlTick stored={};
      if(!CopyExact(InpOriginSymbol,TIMES_MSC[i],origin) || !CopyExact(InpProbeSymbol,TIMES_MSC[i],stored))
        {
         FileClose(report);
         return;
        }
      string fields[9]={"time_msc","time","bid","ask","last","volume","volume_real","flags","spread"};
      string left[9];
      string right[9];
      left[0]=StringFormat("%I64d",origin.time_msc); right[0]=StringFormat("%I64d",stored.time_msc);
      left[1]=StringFormat("%I64d",(long)origin.time); right[1]=StringFormat("%I64d",(long)stored.time);
      left[2]=DoubleToString(origin.bid,12); right[2]=DoubleToString(stored.bid,12);
      left[3]=DoubleToString(origin.ask,12); right[3]=DoubleToString(stored.ask,12);
      left[4]=DoubleToString(origin.last,12); right[4]=DoubleToString(stored.last,12);
      left[5]=StringFormat("%I64d",origin.volume); right[5]=StringFormat("%I64d",stored.volume);
      left[6]=DoubleToString(origin.volume_real,12); right[6]=DoubleToString(stored.volume_real,12);
      left[7]=IntegerToString((int)origin.flags); right[7]=IntegerToString((int)stored.flags);
      left[8]=DoubleToString(origin.ask-origin.bid,12); right[8]=DoubleToString(stored.ask-stored.bid,12);
      for(int j=0;j<9;j++)
        {
         WriteField(report,i+1,fields[j],left[j],right[j]);
         if(left[j]!=right[j])
           {
            diffs++;
            if(fields[j]!="flags")
               nonflag_diffs++;
           }
        }
     }
   string result=(diffs==2 && nonflag_diffs==0 ? "FLAGS_ONLY" : (diffs==0 ? "EXACT" : "OTHER_DIFFERENCES"));
   FileWrite(report,0,"summary_differences",IntegerToString(diffs),IntegerToString(nonflag_diffs),result);
   FileWrite(report,0,"result",result,"","No mutation or performance authorization");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA crossed-tick field comparison: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; differences=%d; nonflag_differences=%d. Read-only.",result,diffs,nonflag_diffs);
  }
