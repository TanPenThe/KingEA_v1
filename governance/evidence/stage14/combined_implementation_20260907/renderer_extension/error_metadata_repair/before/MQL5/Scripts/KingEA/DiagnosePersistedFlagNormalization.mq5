#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only mapping audit for persisted custom-history tick flags."
#property description "No custom-symbol mutation; orders; signals; indicators; returns; or optimizer logic."

input string InpOriginSymbol = "ETHUSD.s";
input string InpCustomSymbol = "KINGEA_ETHUSD_S_RSB3";

const long DAYS[2] = {1625097600000,1782777600000}; // transformed 2021-07-01; unchanged 2026-06-30
const long DAY_MSC = 86400000;

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA flag diagnostic refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !SymbolSelect(InpCustomSymbol,true))
     {
      PrintFormat("KingEA flag diagnostic failed: symbols unavailable; error=%d",GetLastError());
      return;
     }
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\persisted_flag_normalization_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE) return;
   FileWrite(report,"section","day_start_msc","origin_flag","stored_flag","count","origin_ticks","stored_ticks","nonflag_mismatches","flag_mismatches","notes");

   bool overall=true;
   for(int d=0;d<2;d++)
     {
      long from=DAYS[d];
      long to=from+DAY_MSC;
      MqlTick origin[];
      MqlTick stored[];
      int origin_count=CopyTicksRange(InpOriginSymbol,origin,COPY_TICKS_ALL,(ulong)from,(ulong)(to-1));
      int stored_count=CopyTicksRange(InpCustomSymbol,stored,COPY_TICKS_ALL,(ulong)from,(ulong)(to-1));
      long mapping[256][256];
      ArrayInitialize(mapping,0);
      long nonflag=0;
      long flags=0;
      int compare_count=MathMin(MathMax(0,origin_count),MathMax(0,stored_count));
      for(int i=0;i<compare_count;i++)
        {
         bool same=(origin[i].time_msc==stored[i].time_msc && origin[i].time==stored[i].time &&
                    origin[i].bid==stored[i].bid && origin[i].last==stored[i].last &&
                    origin[i].volume==stored[i].volume && origin[i].volume_real==stored[i].volume_real);
         // Ask differs by design on the transformed day and is therefore not
         // part of this narrow persisted-flag diagnostic.
         if(!same) nonflag++;
         int left=(int)origin[i].flags;
         int right=(int)stored[i].flags;
         if(left>=0 && left<256 && right>=0 && right<256)
            mapping[left][right]++;
         else
           {
            nonflag++;
            overall=false;
           }
         if(left!=right) flags++;
        }
      if(origin_count!=stored_count || nonflag!=0) overall=false;
      FileWrite(report,"day_summary",from,-1,-1,0,origin_count,stored_count,nonflag,flags,origin_count==stored_count && nonflag==0 ? "PASS" : "FAIL");
      for(int left=0;left<256;left++)
         for(int right=0;right<256;right++)
            if(mapping[left][right]>0)
               FileWrite(report,"flag_map",from,left,right,mapping[left][right],origin_count,stored_count,nonflag,flags,"");
      ArrayFree(origin);
      ArrayFree(stored);
     }
   FileWrite(report,"result",0,-1,-1,0,0,0,0,0,overall ? "PASS" : "FAIL");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA persisted flag diagnostic: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s. Read-only; RSB3 untouched; no performance authorization.",overall ? "PASS" : "FAIL");
  }
