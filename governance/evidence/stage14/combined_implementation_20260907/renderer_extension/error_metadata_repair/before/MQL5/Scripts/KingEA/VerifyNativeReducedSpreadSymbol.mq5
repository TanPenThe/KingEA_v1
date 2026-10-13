#property copyright "KingEA"
#property version   "1.02"
#property script_show_inputs
#property description "Read-only full-dataset invariant verifier for RSB3."
#property description "No custom-symbol mutation; orders; signals; indicators; returns; or optimizer logic."
#property description "Build ID: RSB3-VERIFY-20260723-B."

input string InpOriginSymbol = "ETHUSD.s";
input string InpReducedSymbol = "KINGEA_ETHUSD_S_RSB3";
input string InpLiveEvidenceFile = "KingEA\\spread_bracket_evidence_ETHUSD.s_LIVE2_REFERENCE_2026.07.22_01-07-55.csv";
input string InpDemoEvidenceFile = "KingEA\\spread_bracket_evidence_ETHUSD.s_DEMO2_BOUNDARY_2026.07.22_01-08-55.csv";

const long DATASET_START_MSC = 1625097600000;
const long DATASET_END_MSC = 1782864000000;
const long BOUNDARY_MSC = 1685801408062;
const long EXPECTED_TOTAL = 327417608;
const long EXPECTED_TRANSFORMED = 96218891;
const long EXPECTED_UNCHANGED = 231198717;
const long EXPECTED_ZERO_SOURCE = 759;
const int EXPECTED_LIVE_COUNT = 156919;
const int EXPECTED_DEMO_COUNT = 128479;
int g_digits;
double g_point;

double Percentile(const double &sorted[],const int count,const double fraction)
  {
   if(count<=0)
      return 0.0;
   int index=(int)MathFloor(fraction*(count-1));
   index=MathMax(0,MathMin(index,count-1));
   return sorted[index];
  }

bool LoadDistribution(const string filename,const string expected_server,
                      const string expected_role,const string key_prefix,
                      const int expected_count,const double expected_median,
                      double &values[])
  {
   int handle=FileOpen(filename,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA RSB3 verification failed: cannot open %s; error=%d",filename,GetLastError());
      return false;
     }
   bool header=true;
   string server="";
   string role="";
   string result="";
   int count=0;
   while(!FileIsEnding(handle))
     {
      string snapshot_utc=FileReadString(handle);
      string snapshot_server=FileReadString(handle);
      string section=FileReadString(handle);
      string key=FileReadString(handle);
      string value=FileReadString(handle);
      string unit=FileReadString(handle);
      string notes=FileReadString(handle);
      if(header)
        {
         header=false;
         continue;
        }
      if(section=="audit" && key=="server") server=value;
      else if(section=="audit" && key=="role") role=value;
      else if(section=="audit" && key=="result") result=value;
      else if(section=="raw_sorted_spread" && StringFind(key,key_prefix)==0)
        {
         double spread=StringToDouble(value);
         if(!MathIsValidNumber(spread) || spread<=0.0)
           {
            FileClose(handle);
            return false;
           }
         if(count>=ArraySize(values)) ArrayResize(values,count+1,250000);
         values[count++]=spread;
        }
     }
   FileClose(handle);
   ArrayResize(values,count);
   if(server!=expected_server || role!=expected_role || result!="PASS" || count!=expected_count)
      return false;
   for(int i=1;i<count;i++) if(values[i]<values[i-1]) return false;
   return MathAbs(Percentile(values,count,0.50)-expected_median)<=g_point/2.0;
  }

int UpperBound(const double &sorted[],const int count,const double value)
  {
   int low=0;
   int high=count;
   while(low<high)
     {
      int mid=(low+high)/2;
      if(sorted[mid]<=value) low=mid+1;
      else high=mid;
     }
   return low;
  }

double ExpectedMappedSpread(const double recorded,const double &demo_sorted[],const double &live_sorted[])
  {
   int demo_count=ArraySize(demo_sorted);
   int live_count=ArraySize(live_sorted);
   int demo_index=UpperBound(demo_sorted,demo_count,recorded)-1;
   demo_index=MathMax(0,MathMin(demo_index,demo_count-1));
   double percentile=(double)demo_index/(double)(demo_count-1);
   int live_index=(int)MathFloor(percentile*(live_count-1));
   live_index=MathMax(0,MathMin(live_index,live_count-1));
   double mapped=live_sorted[live_index];
   return NormalizeDouble(MathCeil((mapped/g_point)-1e-10)*g_point,g_digits);
  }

uint ExpectedPersistedFlags(const uint origin_flags)
  {
   // MT5 custom-history persistence deterministically clears bit 128.
   // Every other flag bit remains part of the invariant.
   return (origin_flags & 0xFFFFFF7F);
  }

void MixU64(ulong &fnv,ulong &mix,const ulong value)
  {
   // Field-wise FNV-style mixing avoids a prohibitively expensive byte loop
   // across more than 327 million ticks. The independent mix accumulator
   // supplies a second deterministic fingerprint.
   fnv^=value;
   fnv*=1099511628211;
   mix^=value+0x9E3779B97F4A7C15+(mix<<6)+(mix>>2);
  }

long PriceUnits(const double value)
  {
   return (long)MathRound(value/g_point);
  }

void MixCanonicalTick(ulong &fnv,ulong &mix,const MqlTick &tick,const double ask_override)
  {
   MixU64(fnv,mix,(ulong)tick.time_msc);
   MixU64(fnv,mix,(ulong)PriceUnits(tick.bid));
   MixU64(fnv,mix,(ulong)PriceUnits(ask_override));
   MixU64(fnv,mix,(ulong)PriceUnits(tick.last));
   MixU64(fnv,mix,(ulong)tick.volume);
   MixU64(fnv,mix,(ulong)((long)MathRound(tick.volume_real*100000000.0)));
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA RSB3 verification refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !SymbolSelect(InpReducedSymbol,true))
     {
      PrintFormat("KingEA RSB3 verification failed: required symbols unavailable; error=%d",GetLastError());
      return;
     }
   bool custom=false;
   if(!SymbolExist(InpReducedSymbol,custom) || !custom)
     {
      Print("KingEA RSB3 verification failed: reduced target is not a local custom symbol.");
      return;
     }
   g_digits=(int)SymbolInfoInteger(InpOriginSymbol,SYMBOL_DIGITS);
   g_point=SymbolInfoDouble(InpOriginSymbol,SYMBOL_POINT);
   if(g_point<=0.0) return;

   double live_sorted[];
   double demo_sorted[];
   if(!LoadDistribution(InpLiveEvidenceFile,"JustMarkets-Live2","LIVE2_REFERENCE","live_reference_rank_",EXPECTED_LIVE_COUNT,1.26,live_sorted) ||
      !LoadDistribution(InpDemoEvidenceFile,"JustMarkets-Demo2","DEMO2_BOUNDARY","demo_old_reference_rank_",EXPECTED_DEMO_COUNT,23.76,demo_sorted))
     {
      Print("KingEA RSB3 verification failed: evidence distribution validation failed.");
      return;
     }

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\native_reduced_verify_"+InpReducedSymbol+"_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA RSB3 verification failed: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"section","day_start_msc","origin_ticks","stored_ticks","transformed","unchanged","nonflag_mismatches","raw_flag_changes","valid_flag_normalizations","notes");

   long total=0;
   long transformed=0;
   long unchanged=0;
   long zero_source=0;
   long nonflag_mismatches=0;
   long flag_mismatches=0;
   long allowed_flags=0;
   long invalid_flags=0;
   long count_mismatch_days=0;
   long first_time=0;
   long last_time=0;
   ulong origin_fnv=1469598103934665603;
   ulong origin_mix=0x243F6A8885A308D3;
   ulong expected_fnv=1469598103934665603;
   ulong expected_mix=0x243F6A8885A308D3;
   ulong stored_fnv=1469598103934665603;
   ulong stored_mix=0x243F6A8885A308D3;
   bool ok=true;
   const long DAY_MSC=86400000;

   for(long day=DATASET_START_MSC;day<DATASET_END_MSC;day+=DAY_MSC)
     {
      long day_to=MathMin(day+DAY_MSC,DATASET_END_MSC);
      MqlTick origin[];
      MqlTick stored[];
      int origin_count=CopyTicksRange(InpOriginSymbol,origin,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      int origin_error=GetLastError();
      int stored_count=CopyTicksRange(InpReducedSymbol,stored,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      int stored_error=GetLastError();
      long day_transformed=0;
      long day_unchanged=0;
      long day_nonflag=0;
      long day_flags=0;
      long day_allowed_flags=0;
      long day_invalid_flags=0;
      string notes="";
      if(origin_count<0 || stored_count<0)
        {
         ok=false;
         notes=StringFormat("COPY_FAILED origin_error=%d stored_error=%d",origin_error,stored_error);
        }
      else if(origin_count!=stored_count)
        {
         ok=false;
         count_mismatch_days++;
         notes="COUNT_MISMATCH";
        }

      int compare_count=MathMin(MathMax(0,origin_count),MathMax(0,stored_count));
      for(int i=0;i<compare_count;i++)
        {
         if(first_time==0) first_time=origin[i].time_msc;
         last_time=origin[i].time_msc;
         double recorded_spread=origin[i].ask-origin[i].bid;
         if(recorded_spread==0.0) zero_source++;
         double expected_ask=origin[i].ask;
         if(origin[i].time_msc<BOUNDARY_MSC)
           {
            expected_ask=NormalizeDouble(origin[i].bid+ExpectedMappedSpread(recorded_spread,demo_sorted,live_sorted),g_digits);
            day_transformed++;
           }
         else day_unchanged++;

         bool nonflag_equal=(origin[i].time_msc==stored[i].time_msc &&
                             origin[i].time==stored[i].time &&
                             origin[i].bid==stored[i].bid &&
                             stored[i].ask==expected_ask &&
                             origin[i].last==stored[i].last &&
                             origin[i].volume==stored[i].volume &&
                             origin[i].volume_real==stored[i].volume_real);
         if(!nonflag_equal)
           {
            day_nonflag++;
            nonflag_mismatches++;
            if(nonflag_mismatches<=20)
               PrintFormat("KingEA RSB3 mismatch: day=%I64d index=%d time_origin=%I64d time_stored=%I64d bid_origin=%s bid_stored=%s ask_expected=%s ask_stored=%s",
                           day,i,origin[i].time_msc,stored[i].time_msc,
                           DoubleToString(origin[i].bid,g_digits),DoubleToString(stored[i].bid,g_digits),
                           DoubleToString(expected_ask,g_digits),DoubleToString(stored[i].ask,g_digits));
           }
         if(origin[i].flags!=stored[i].flags)
           {
            day_flags++;
            flag_mismatches++;
            if(stored[i].flags==ExpectedPersistedFlags(origin[i].flags))
              {
               day_allowed_flags++;
               allowed_flags++;
              }
            else
              {
               day_invalid_flags++;
               invalid_flags++;
               if(invalid_flags<=20)
                  PrintFormat("KingEA RSB3 invalid flag normalization: day=%I64d index=%d time=%I64d origin_flags=%u expected_flags=%u stored_flags=%u",
                              day,i,origin[i].time_msc,origin[i].flags,ExpectedPersistedFlags(origin[i].flags),stored[i].flags);
              }
           }

         MixCanonicalTick(origin_fnv,origin_mix,origin[i],origin[i].ask);
         MixCanonicalTick(expected_fnv,expected_mix,origin[i],expected_ask);
         MixCanonicalTick(stored_fnv,stored_mix,stored[i],stored[i].ask);
        }
      total+=compare_count;
      transformed+=day_transformed;
      unchanged+=day_unchanged;
      if(day_invalid_flags>0)
         notes=StringFormat("%s%sINVALID_FLAG_NORMALIZATION=%I64d",notes,notes=="" ? "" : "|",day_invalid_flags);
      FileWrite(report,"day",day,origin_count,stored_count,day_transformed,day_unchanged,day_nonflag,day_flags,day_allowed_flags,notes);
      ArrayFree(origin);
      ArrayFree(stored);
      if((total%10000000)<compare_count)
         PrintFormat("KingEA RSB3 verification progress: ticks=%I64d",total);
     }

   bool counts_ok=(total==EXPECTED_TOTAL && transformed==EXPECTED_TRANSFORMED && unchanged==EXPECTED_UNCHANGED && zero_source==EXPECTED_ZERO_SOURCE);
   bool fingerprint_ok=(expected_fnv==stored_fnv && expected_mix==stored_mix);
   bool flag_policy_ok=(invalid_flags==0);
   bool result=(ok && count_mismatch_days==0 && nonflag_mismatches==0 && flag_policy_ok && counts_ok && fingerprint_ok);
   FileWrite(report,"summary",0,total,total,transformed,unchanged,nonflag_mismatches,flag_mismatches,allowed_flags,StringFormat("count_mismatch_days=%I64d|zero_source=%I64d",count_mismatch_days,zero_source));
   FileWrite(report,"fingerprint",0,"origin_fieldhash64",StringFormat("%I64u",origin_fnv),"origin_mix64",StringFormat("%I64u",origin_mix),"","","","");
   FileWrite(report,"fingerprint",0,"expected_fieldhash64",StringFormat("%I64u",expected_fnv),"expected_mix64",StringFormat("%I64u",expected_mix),"","","","");
   FileWrite(report,"fingerprint",0,"stored_fieldhash64",StringFormat("%I64u",stored_fnv),"stored_mix64",StringFormat("%I64u",stored_mix),"","","","");
   FileWrite(report,"boundary",0,"first_time_msc",first_time,"last_time_msc",last_time,"","","","");
   FileWrite(report,"result",0,result ? "PASS" : "FAIL","counts_ok",counts_ok ? "1" : "0","fingerprint_ok",fingerprint_ok ? "1" : "0","invalid_flags",invalid_flags,flag_policy_ok ? "flag_policy=PASS" : "flag_policy=FAIL");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA RSB3 verification report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; ticks=%I64d; nonflag_mismatches=%I64d; raw_flag_changes=%I64d; valid_flag_normalizations=%I64d; invalid_flags=%I64d. Read-only; no performance authorization.",
               result ? "PASS" : "FAIL",total,nonflag_mismatches,flag_mismatches,allowed_flags,invalid_flags);
  }
