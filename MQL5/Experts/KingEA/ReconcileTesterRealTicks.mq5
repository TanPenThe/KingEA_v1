#property copyright "KingEA"
#property version   "1.00"
#property tester_everytick_calculate
#property description "Non-trading Strategy Tester real-tick reconciliation harness."
#property description "Compares OnTick replay with CopyTicksRange for one frozen window."
#property description "Build ID: TESTER-RECON-20260724-A."

input string InpRunLabel = "SET_RUN_LABEL";
input string InpExpectedSymbol = "";
input string InpWindowStart = "2021.07.01 00:00:00";
input string InpWindowEnd = "2021.07.02 00:00:00";
input long InpExpectedTicks = 0;

long g_start_msc=0;
long g_end_msc=0;
long g_replay_count=0;
long g_replay_first=0;
long g_replay_last=0;
long g_out_of_order=0;
ulong g_replay_fieldhash=1469598103934665603;
ulong g_replay_mix=0x243F6A8885A308D3;
ulong g_replay_flaghash=1469598103934665603;
double g_point=0.0;
bool g_initialized=false;

void MixU64(ulong &fnv,ulong &mix,const ulong value)
  {
   fnv^=value;
   fnv*=1099511628211;
   mix^=value+0x9E3779B97F4A7C15+(mix<<6)+(mix>>2);
  }

long PriceUnits(const double value)
  {
   return (long)MathRound(value/g_point);
  }

void MixMarketTick(ulong &fnv,ulong &mix,const MqlTick &tick)
  {
   MixU64(fnv,mix,(ulong)tick.time_msc);
   MixU64(fnv,mix,(ulong)PriceUnits(tick.bid));
   MixU64(fnv,mix,(ulong)PriceUnits(tick.ask));
   MixU64(fnv,mix,(ulong)PriceUnits(tick.last));
   MixU64(fnv,mix,(ulong)tick.volume);
   MixU64(fnv,mix,(ulong)((long)MathRound(tick.volume_real*100000000.0)));
  }

void MixFlag(ulong &fnv,const uint flags)
  {
   fnv^=(ulong)flags;
   fnv*=1099511628211;
  }

string SafeLabel(string value)
  {
   StringReplace(value,"\\","_");
   StringReplace(value,"/","_");
   StringReplace(value,":","-");
   StringReplace(value," ","_");
   return value;
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("KingEA tester reconciliation refused: run only in MT5 Strategy Tester.");
      return INIT_FAILED;
     }
   if(InpExpectedSymbol!="" && _Symbol!=InpExpectedSymbol)
     {
      PrintFormat("KingEA tester reconciliation refused: expected symbol=%s actual=%s",InpExpectedSymbol,_Symbol);
      return INIT_FAILED;
     }
   if(InpRunLabel=="" || InpRunLabel=="SET_RUN_LABEL")
     {
      Print("KingEA tester reconciliation refused: set an explicit registered run label.");
      return INIT_FAILED;
     }
   datetime start_time=StringToTime(InpWindowStart);
   datetime end_time=StringToTime(InpWindowEnd);
   if(start_time<=0 || end_time<=start_time)
     {
      Print("KingEA tester reconciliation refused: invalid half-open window.");
      return INIT_FAILED;
     }
   g_start_msc=(long)start_time*1000;
   g_end_msc=(long)end_time*1000;
   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(g_point<=0.0)
     {
      Print("KingEA tester reconciliation refused: invalid symbol point.");
      return INIT_FAILED;
     }
   g_initialized=true;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!g_initialized)
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;
   if(tick.time_msc<g_start_msc || tick.time_msc>=g_end_msc)
      return;
   if(g_replay_first==0)
      g_replay_first=tick.time_msc;
   if(g_replay_last>tick.time_msc)
      g_out_of_order++;
   g_replay_last=tick.time_msc;
   g_replay_count++;
   MixMarketTick(g_replay_fieldhash,g_replay_mix,tick);
   MixFlag(g_replay_flaghash,tick.flags);
  }

void OnDeinit(const int reason)
  {
   if(!g_initialized)
      return;

   MqlTick source[];
   int copied=CopyTicksRange(_Symbol,source,COPY_TICKS_ALL,(ulong)g_start_msc,(ulong)(g_end_msc-1));
   int copy_error=GetLastError();
   long source_first=0;
   long source_last=0;
   ulong source_fieldhash=1469598103934665603;
   ulong source_mix=0x243F6A8885A308D3;
   ulong source_flaghash=1469598103934665603;
   if(copied>0)
     {
      source_first=source[0].time_msc;
      source_last=source[copied-1].time_msc;
      for(int i=0;i<copied;i++)
        {
         MixMarketTick(source_fieldhash,source_mix,source[i]);
         MixFlag(source_flaghash,source[i].flags);
        }
     }

   bool expected_count_ok=(InpExpectedTicks<=0 || g_replay_count==InpExpectedTicks);
   bool result=(copied>0 &&
                g_replay_count==copied &&
                g_replay_first==source_first &&
                g_replay_last==source_last &&
                g_out_of_order==0 &&
                g_replay_fieldhash==source_fieldhash &&
                g_replay_mix==source_mix &&
                g_replay_flaghash==source_flaghash &&
                expected_count_ok);

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\tester_tick_reconciliation_"+SafeLabel(InpRunLabel)+"_"+SafeLabel(_Symbol)+"_"+SafeLabel(utc)+".csv";
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA tester reconciliation failed: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"section","key","value","notes");
   FileWrite(report,"run","build_id","TESTER-RECON-20260724-A","");
   FileWrite(report,"run","label",InpRunLabel,"");
   FileWrite(report,"run","server",AccountInfoString(ACCOUNT_SERVER),"");
   FileWrite(report,"run","symbol",_Symbol,"");
   FileWrite(report,"run","window_start",InpWindowStart,"inclusive");
   FileWrite(report,"run","window_end",InpWindowEnd,"exclusive");
   FileWrite(report,"run","deinit_reason",reason,"");
   FileWrite(report,"source","copy_error",copy_error,"");
   FileWrite(report,"source","ticks",copied,"");
   FileWrite(report,"source","first_time_msc",source_first,"");
   FileWrite(report,"source","last_time_msc",source_last,"");
   FileWrite(report,"source","fieldhash64",StringFormat("%I64u",source_fieldhash),"excludes flags");
   FileWrite(report,"source","mix64",StringFormat("%I64u",source_mix),"excludes flags");
   FileWrite(report,"source","flaghash64",StringFormat("%I64u",source_flaghash),"metadata only");
   FileWrite(report,"replay","ticks",g_replay_count,"");
   FileWrite(report,"replay","first_time_msc",g_replay_first,"");
   FileWrite(report,"replay","last_time_msc",g_replay_last,"");
   FileWrite(report,"replay","out_of_order",g_out_of_order,"");
   FileWrite(report,"replay","fieldhash64",StringFormat("%I64u",g_replay_fieldhash),"excludes flags");
   FileWrite(report,"replay","mix64",StringFormat("%I64u",g_replay_mix),"excludes flags");
   FileWrite(report,"replay","flaghash64",StringFormat("%I64u",g_replay_flaghash),"metadata only");
   FileWrite(report,"gate","expected_ticks",InpExpectedTicks,InpExpectedTicks<=0 ? "not enforced" : "enforced");
   FileWrite(report,"gate","expected_count_ok",expected_count_ok ? "1" : "0","");
   FileWrite(report,"result","status",result ? "PASS" : "FAIL","non-trading; no performance authorization");
   FileFlush(report);
   FileClose(report);

   PrintFormat("KingEA tester tick reconciliation report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; symbol=%s; replay_ticks=%I64d; source_ticks=%d; out_of_order=%I64d. Non-trading; no performance authorization.",
               result ? "PASS" : "FAIL",_Symbol,g_replay_count,copied,g_out_of_order);
  }
