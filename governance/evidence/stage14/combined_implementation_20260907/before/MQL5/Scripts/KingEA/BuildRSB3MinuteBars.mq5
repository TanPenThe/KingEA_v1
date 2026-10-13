#property copyright "KingEA"
#property version   "1.03"
#property script_show_inputs
#property description "Five-year RSB3 M1-bar preflight and explicitly authorized builder."
#property description "No orders, signals, indicators, returns, optimizer logic, or tick-history mutation."
#property description "Build ID: RSB3-M1-BARS-20260725-D."

input string InpCustomSymbol = "KINGEA_ETHUSD_S_RSB3";
input string InpAuthorizationToken = "";

const string REQUIRED_AUTHORIZATION = "AUTHORIZE_RSB3_M1_BARS_20260724";
const long DATASET_START_MSC = 1625097600000;
const long DATASET_END_MSC = 1782864000000;
const long EXPECTED_TOTAL_TICKS = 327417608;

double g_point=0.0;

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

void MixTick(ulong &fnv,ulong &mix,const MqlTick &tick)
  {
   MixU64(fnv,mix,(ulong)tick.time_msc);
   MixU64(fnv,mix,(ulong)PriceUnits(tick.bid));
   MixU64(fnv,mix,(ulong)PriceUnits(tick.ask));
   MixU64(fnv,mix,(ulong)PriceUnits(tick.last));
   MixU64(fnv,mix,(ulong)tick.volume);
   MixU64(fnv,mix,(ulong)((long)MathRound(tick.volume_real*100000000.0)));
  }

void HashTicks(const MqlTick &ticks[],const int count,ulong &fnv,ulong &mix)
  {
   fnv=1469598103934665603;
   mix=0x243F6A8885A308D3;
   for(int i=0;i<count;i++)
      MixTick(fnv,mix,ticks[i]);
  }

void StartBar(MqlRates &bar,const datetime time,const MqlTick &tick)
  {
   bar.time=time;
   bar.open=tick.bid;
   bar.high=tick.bid;
   bar.low=tick.bid;
   bar.close=tick.bid;
   bar.tick_volume=1;
   int spread_points=(int)MathRound((tick.ask-tick.bid)/g_point);
   bar.spread=(spread_points>0 ? spread_points : 0);
   bar.real_volume=(long)MathRound(tick.volume_real);
  }

void UpdateBar(MqlRates &bar,const MqlTick &tick)
  {
   bar.high=MathMax(bar.high,tick.bid);
   bar.low=MathMin(bar.low,tick.bid);
   bar.close=tick.bid;
   bar.tick_volume++;
   int spread_points=(int)MathRound((tick.ask-tick.bid)/g_point);
   if(spread_points>0 && (bar.spread<=0 || spread_points<bar.spread))
      bar.spread=spread_points;
   bar.real_volume+=(long)MathRound(tick.volume_real);
  }

int BuildRatesFromTicks(const MqlTick &ticks[],const int tick_count,
                        const int period_seconds,MqlRates &rates[])
  {
   ArrayResize(rates,0);
   if(tick_count<=0)
      return 0;
   int count=0;
   datetime current_bucket=0;
   for(int i=0;i<tick_count;i++)
     {
      datetime bucket=(datetime)(((long)ticks[i].time/period_seconds)*period_seconds);
      if(count==0 || bucket!=current_bucket)
        {
         current_bucket=bucket;
         ArrayResize(rates,count+1,2048);
         StartBar(rates[count],bucket,ticks[i]);
         count++;
        }
      else
         UpdateBar(rates[count-1],ticks[i]);
     }
   ArrayResize(rates,count);
   return count;
  }

bool RatesEqual(const MqlRates &expected,const MqlRates &stored)
  {
   return (expected.time==stored.time &&
           expected.open==stored.open &&
           expected.high==stored.high &&
           expected.low==stored.low &&
           expected.close==stored.close &&
           expected.tick_volume==stored.tick_volume &&
           expected.spread==stored.spread &&
           expected.real_volume==stored.real_volume);
  }

long CountRateMismatches(const MqlRates &expected[],const int expected_count,
                         const MqlRates &stored[],const int stored_count)
  {
   if(expected_count!=stored_count)
      return MathAbs(expected_count-stored_count)+1;
   long mismatches=0;
   for(int i=0;i<expected_count;i++)
      if(!RatesEqual(expected[i],stored[i]))
         mismatches++;
   return mismatches;
  }

int CopyRatesExpected(const string symbol,const ENUM_TIMEFRAMES period,
                      const datetime from,const datetime to,const int expected_count,
                      MqlRates &rates[],int &last_error)
  {
   int copied=-1;
   last_error=0;
   for(int attempt=0;attempt<300;attempt++)
     {
      ResetLastError();
      copied=CopyRates(symbol,period,from,to,rates);
      last_error=GetLastError();
      if(copied==expected_count || copied>expected_count)
         return copied;
      if(attempt<299)
         Sleep(100);
     }
   return copied;
  }

string ResultFilename(const bool authorized)
  {
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string mode=(authorized ? "BUILD" : "PREFLIGHT");
   string filename="KingEA\\rsb3_m1_"+mode+"_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   return filename;
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA RSB3 M1 tool refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   bool custom=false;
   if(!SymbolExist(InpCustomSymbol,custom) || !custom || !SymbolSelect(InpCustomSymbol,true))
     {
      Print("KingEA RSB3 M1 tool failed: accepted custom symbol unavailable.");
      return;
     }
   bool authorized=(InpAuthorizationToken==REQUIRED_AUTHORIZATION);
   if(InpAuthorizationToken!="" && !authorized)
     {
      Print("KingEA RSB3 M1 tool refused: authorization token is invalid.");
      return;
     }
   g_point=SymbolInfoDouble(InpCustomSymbol,SYMBOL_POINT);
   if(g_point<=0.0)
     {
      Print("KingEA RSB3 M1 tool failed: invalid symbol point.");
      return;
     }

   string filename=ResultFilename(authorized);
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA RSB3 M1 tool failed: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"phase","day_start_msc","ticks","derived_m1","derived_m30","stored_m30","rate_mismatches","tick_hash_match","notes");
   long terminal_max_bars=TerminalInfoInteger(TERMINAL_MAXBARS);
   FileWrite(report,"run",0,0,0,0,0,0,0,StringFormat("build_id=RSB3-M1-BARS-20260725-D|server=%s|symbol=%s|authorized=%d|max_bars=%I64d",server,InpCustomSymbol,authorized ? 1 : 0,terminal_max_bars));

   const long DAY_MSC=86400000;
   long total_ticks=0;
   long total_m1=0;
   long total_m30=0;
   long preflight_mismatches=0;
   long copy_failures=0;

   for(long day=DATASET_START_MSC;day<DATASET_END_MSC;day+=DAY_MSC)
     {
      long day_to=MathMin(day+DAY_MSC,DATASET_END_MSC);
      MqlTick ticks[];
      ResetLastError();
      int tick_count=CopyTicksRange(InpCustomSymbol,ticks,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      int tick_error=GetLastError();
      if(tick_count<0)
        {
         copy_failures++;
         FileWrite(report,"preflight",day,tick_count,0,0,0,0,0,StringFormat("TICK_COPY_FAILED=%d",tick_error));
         ArrayFree(ticks);
         continue;
        }
      MqlRates derived_m1[];
      MqlRates derived_m30[];
      int m1_count=BuildRatesFromTicks(ticks,tick_count,60,derived_m1);
      int m30_count=BuildRatesFromTicks(ticks,tick_count,1800,derived_m30);
      MqlRates stored_m30[];
      int m30_error=0;
      int stored_m30_count=CopyRatesExpected(InpCustomSymbol,PERIOD_M30,
                                             (datetime)(day/1000),(datetime)((day_to-1)/1000),
                                             m30_count,stored_m30,m30_error);
      long mismatches=(stored_m30_count<0 ? m30_count+1 :
                       CountRateMismatches(derived_m30,m30_count,stored_m30,stored_m30_count));
      if(mismatches>0)
         preflight_mismatches+=mismatches;
      total_ticks+=tick_count;
      total_m1+=m1_count;
      total_m30+=m30_count;
      FileWrite(report,"preflight",day,tick_count,m1_count,m30_count,stored_m30_count,mismatches,0,
                stored_m30_count<0 ? StringFormat("M30_COPY_FAILED=%d",m30_error) : "");
      ArrayFree(ticks);
      ArrayFree(derived_m1);
      ArrayFree(derived_m30);
      ArrayFree(stored_m30);
      if((total_ticks%10000000)<tick_count)
         PrintFormat("KingEA RSB3 M1 preflight progress: ticks=%I64d",total_ticks);
     }

   bool maxbars_ok=(terminal_max_bars>=total_m1);
   bool preflight_ok=(copy_failures==0 &&
                      total_ticks==EXPECTED_TOTAL_TICKS &&
                      total_m1>0 &&
                      total_m30>0 &&
                      preflight_mismatches==0 &&
                      maxbars_ok);
   FileWrite(report,"preflight_summary",0,total_ticks,total_m1,total_m30,0,preflight_mismatches,0,
             StringFormat("copy_failures=%I64d|expected_ticks=%I64d|max_bars=%I64d|required_max_bars=%I64d|maxbars_ok=%d|status=%s",
                          copy_failures,EXPECTED_TOTAL_TICKS,terminal_max_bars,total_m1,maxbars_ok ? 1 : 0,preflight_ok ? "PASS" : "FAIL"));

   if(!preflight_ok || !authorized)
     {
      string status=(preflight_ok ? "PREFLIGHT_PASS_BUILD_NOT_AUTHORIZED" : "PREFLIGHT_FAIL");
      FileWrite(report,"result",0,total_ticks,total_m1,total_m30,0,preflight_mismatches,0,status);
      FileFlush(report);
      FileClose(report);
      PrintFormat("KingEA RSB3 M1 report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
      PrintFormat("Result: %s; ticks=%I64d; derived_m1=%I64d; derived_m30=%I64d; mismatches=%I64d. RSB3 ticks untouched; no performance authorization.",
                  status,total_ticks,total_m1,total_m30,preflight_mismatches);
      return;
     }

   long written_m1=0;
   long readback_mismatches=0;
   long tick_integrity_failures=0;
   long post_m30_mismatches=0;
   bool build_ok=true;
   for(long day=DATASET_START_MSC;day<DATASET_END_MSC;day+=DAY_MSC)
     {
      long day_to=MathMin(day+DAY_MSC,DATASET_END_MSC);
      MqlTick before_ticks[];
      int before_count=CopyTicksRange(InpCustomSymbol,before_ticks,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      if(before_count<0)
        {
         build_ok=false;
         FileWrite(report,"build",day,before_count,0,0,0,0,0,"PREWRITE_TICK_COPY_FAILED");
         break;
        }
      ulong before_fnv=0;
      ulong before_mix=0;
      HashTicks(before_ticks,before_count,before_fnv,before_mix);
      MqlRates expected_m1[];
      MqlRates expected_m30[];
      int expected_m1_count=BuildRatesFromTicks(before_ticks,before_count,60,expected_m1);
      int expected_m30_count=BuildRatesFromTicks(before_ticks,before_count,1800,expected_m30);

      ResetLastError();
      int replaced=CustomRatesReplace(InpCustomSymbol,(datetime)(day/1000),
                                      (datetime)((day_to-1)/1000),expected_m1);
      int replace_error=GetLastError();
      if(replaced!=expected_m1_count)
        {
         build_ok=false;
         FileWrite(report,"build",day,before_count,expected_m1_count,expected_m30_count,0,0,0,
                   StringFormat("RATES_REPLACE_FAILED result=%d error=%d",replaced,replace_error));
         break;
        }

      MqlRates stored_m1[];
      int m1_read_error=0;
      int stored_m1_count=CopyRatesExpected(InpCustomSymbol,PERIOD_M1,
                                            (datetime)(day/1000),(datetime)((day_to-1)/1000),
                                            expected_m1_count,stored_m1,m1_read_error);
      long day_readback=CountRateMismatches(expected_m1,expected_m1_count,stored_m1,MathMax(0,stored_m1_count));
      readback_mismatches+=day_readback;

      MqlTick after_ticks[];
      int after_count=CopyTicksRange(InpCustomSymbol,after_ticks,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      ulong after_fnv=0;
      ulong after_mix=0;
      if(after_count>=0)
         HashTicks(after_ticks,after_count,after_fnv,after_mix);
      bool tick_hash_match=(after_count==before_count && after_fnv==before_fnv && after_mix==before_mix);
      if(!tick_hash_match)
         tick_integrity_failures++;

      MqlRates stored_m30[];
      int m30_read_error=0;
      int stored_m30_count=CopyRatesExpected(InpCustomSymbol,PERIOD_M30,
                                             (datetime)(day/1000),(datetime)((day_to-1)/1000),
                                             expected_m30_count,stored_m30,m30_read_error);
      long day_m30=CountRateMismatches(expected_m30,expected_m30_count,stored_m30,MathMax(0,stored_m30_count));
      post_m30_mismatches+=day_m30;
      written_m1+=replaced;
      string notes="";
      if(day_readback>0) notes=StringFormat("M1_READBACK_MISMATCH=%I64d",day_readback);
      if(!tick_hash_match) notes=StringFormat("%s%sTICK_INTEGRITY_FAIL",notes,notes=="" ? "" : "|");
      if(day_m30>0) notes=StringFormat("%s%sM30_MISMATCH=%I64d",notes,notes=="" ? "" : "|",day_m30);
      FileWrite(report,"build",day,before_count,expected_m1_count,expected_m30_count,stored_m30_count,
                day_readback+day_m30,tick_hash_match ? 1 : 0,notes);
      ArrayFree(before_ticks);
      ArrayFree(after_ticks);
      ArrayFree(expected_m1);
      ArrayFree(expected_m30);
      ArrayFree(stored_m1);
      ArrayFree(stored_m30);
      if(day_readback>0 || !tick_hash_match || day_m30>0)
        {
         build_ok=false;
         break;
        }
      if((written_m1%100000)<replaced)
         PrintFormat("KingEA RSB3 M1 build progress: bars=%I64d",written_m1);
     }

   bool result=(build_ok &&
                written_m1==total_m1 &&
                readback_mismatches==0 &&
                tick_integrity_failures==0 &&
                post_m30_mismatches==0);
   FileWrite(report,"build_summary",0,total_ticks,written_m1,total_m30,0,
             readback_mismatches+post_m30_mismatches,
             tick_integrity_failures==0 ? 1 : 0,
             StringFormat("tick_integrity_failures=%I64d|status=%s",tick_integrity_failures,result ? "PASS" : "FAIL"));
   FileWrite(report,"result",0,total_ticks,written_m1,total_m30,0,
             readback_mismatches+post_m30_mismatches,
             tick_integrity_failures==0 ? 1 : 0,result ? "PASS" : "FAIL");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA RSB3 M1 report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; ticks=%I64d; written_m1=%I64d; rate_mismatches=%I64d; tick_integrity_failures=%I64d. No performance authorization.",
               result ? "PASS" : "FAIL",total_ticks,written_m1,
               readback_mismatches+post_m30_mismatches,tick_integrity_failures);
  }
