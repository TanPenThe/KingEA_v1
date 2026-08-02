#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Local two-day round-trip probe for CustomTicksReplace bulk history."
#property description "No orders; signals; indicators; returns; optimizer logic; deletion; or RSB mutation."

input bool   InpAuthorizeLocalProbe = false;
input string InpOriginSymbol = "ETHUSD.s";
input string InpProbeSymbol = "KINGEA_DIAG_REPLACE_V1";
input string InpProbePath = "KingEA\\Diagnostics";

const long DAYS[2] = {1625097600000,1694390400000}; // 2021-07-01 and 2023-09-11
const long DAY_MSC = 86400000;

bool PrepareProbe()
  {
   bool is_custom=false;
   bool exists=SymbolExist(InpProbeSymbol,is_custom);
   if(exists && !is_custom)
     {
      Print("KingEA Replace probe refused: probe name belongs to a broker symbol.");
      return false;
     }
   if(!exists && !CustomSymbolCreate(InpProbeSymbol,InpProbePath,InpOriginSymbol))
     {
      PrintFormat("KingEA Replace probe failed: CustomSymbolCreate error=%d",GetLastError());
      return false;
     }
   if(!SymbolSelect(InpProbeSymbol,true)) return false;
   MqlTick existing[];
   if(CopyTicks(InpProbeSymbol,existing,COPY_TICKS_ALL,0,1)>0)
     {
      Print("KingEA Replace probe refused: target already contains ticks. Do not delete it; use a reviewed new version.");
      return false;
     }
   return true;
  }

void OnStart()
  {
   if(!InpAuthorizeLocalProbe)
     {
      Print("KingEA Replace probe refused: set InpAuthorizeLocalProbe=true for this registered local diagnostic only.");
      return;
     }
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA Replace probe refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !PrepareProbe()) return;

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\custom_ticks_replace_probe_"+InpProbeSymbol+"_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE) return;
   FileWrite(report,"day_start_msc","origin_count","replace_result","replace_error","stored_count","read_error","nonflag_mismatches","flag_mismatches","first_match","last_match","result");

   bool overall=true;
   for(int d=0;d<2;d++)
     {
      long from=DAYS[d];
      long to=from+DAY_MSC;
      MqlTick origin[];
      ResetLastError();
      int origin_count=CopyTicksRange(InpOriginSymbol,origin,COPY_TICKS_ALL,(ulong)from,(ulong)(to-1));
      int origin_error=GetLastError();
      if(origin_count<0)
        {
         FileWrite(report,from,origin_count,-1,origin_error,-1,0,0,0,0,0,"ORIGIN_COPY_FAIL");
         overall=false;
         continue;
        }

      ResetLastError();
      int replaced=CustomTicksReplace(InpProbeSymbol,(ulong)from,(ulong)(to-1),origin);
      int replace_error=GetLastError();
      MqlTick stored[];
      ResetLastError();
      int stored_count=CopyTicksRange(InpProbeSymbol,stored,COPY_TICKS_ALL,(ulong)from,(ulong)(to-1));
      int read_error=GetLastError();
      long nonflag=0;
      long flags=0;
      int compare_count=MathMin(MathMax(0,origin_count),MathMax(0,stored_count));
      for(int i=0;i<compare_count;i++)
        {
         bool same=(origin[i].time_msc==stored[i].time_msc && origin[i].time==stored[i].time &&
                    origin[i].bid==stored[i].bid && origin[i].ask==stored[i].ask &&
                    origin[i].last==stored[i].last && origin[i].volume==stored[i].volume &&
                    origin[i].volume_real==stored[i].volume_real);
         if(!same) nonflag++;
         if(origin[i].flags!=stored[i].flags) flags++;
        }
      bool first_match=(origin_count>0 && stored_count>0 && origin[0].time_msc==stored[0].time_msc);
      bool last_match=(origin_count>0 && stored_count>0 && origin[origin_count-1].time_msc==stored[stored_count-1].time_msc);
      bool pass=(replaced==origin_count && stored_count==origin_count && nonflag==0 && first_match && last_match);
      FileWrite(report,from,origin_count,replaced,replace_error,stored_count,read_error,nonflag,flags,first_match ? 1 : 0,last_match ? 1 : 0,pass ? "PASS" : "FAIL");
      if(!pass) overall=false;
      ArrayFree(origin);
      ArrayFree(stored);
     }
   FileWrite(report,0,0,0,0,0,0,0,0,0,0,overall ? "PASS" : "FAIL");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA CustomTicksReplace probe: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s. Diagnostic symbol only; RSB1 and RSB2 untouched.",overall ? "PASS" : "FAIL");
  }
