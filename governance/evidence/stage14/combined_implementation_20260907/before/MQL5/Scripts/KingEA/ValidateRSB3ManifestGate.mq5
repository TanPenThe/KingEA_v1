#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only full-population RSB3 and pre-dataset warm-up manifest gate."
#property description "No mutation; orders; signals; indicators; returns; or optimizer logic."
#property description "Build ID: RSB3-MANIFEST-GATE-20260726-A."

input string InpOriginSymbol = "ETHUSD.s";
input string InpReducedSymbol = "KINGEA_ETHUSD_S_RSB3";
input string InpLiveEvidenceFile = "KingEA\\spread_bracket_evidence_ETHUSD.s_LIVE2_REFERENCE_2026.07.22_01-07-55.csv";
input string InpDemoEvidenceFile = "KingEA\\spread_bracket_evidence_ETHUSD.s_DEMO2_BOUNDARY_2026.07.22_01-08-55.csv";

const long DATASET_START_MSC = 1625097600000;
const long DATASET_END_MSC = 1782864000000;
const long BOUNDARY_MSC = 1685801408062;
const long WARMUP_START_MSC = 1617235200000;
const long WARMUP_END_MSC = 1625097600000;
const long REGISTERED_1_MSC = 1709374488223;
const long REGISTERED_2_MSC = 1709375322820;
const long EXPECTED_TOTAL = 327417608;
const long EXPECTED_TRANSFORMED = 96218891;
const long EXPECTED_UNCHANGED = 231198717;
const int EXPECTED_LIVE_COUNT = 156919;
const int EXPECTED_DEMO_COUNT = 128479;
const int EXPECTED_WARMUP_M30_SLOTS = 4368;
const double MIN_WARMUP_COVERAGE = 0.95;

int g_digits;
double g_point;

void WriteRow(const int handle,const string section,const string key,
              const string value,const string unit="",const string notes="")
  {
   FileWrite(handle,section,key,value,unit,notes);
  }

double Percentile(const double &sorted[],const int count,const double fraction)
  {
   if(count<=0) return 0.0;
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
   if(handle==INVALID_HANDLE) return false;
   bool header=true;
   string server="";
   string role="";
   string result="";
   int count=0;
   while(!FileIsEnding(handle))
     {
      FileReadString(handle);
      FileReadString(handle);
      string section=FileReadString(handle);
      string key=FileReadString(handle);
      string value=FileReadString(handle);
      FileReadString(handle);
      FileReadString(handle);
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
      int middle=(low+high)/2;
      if(sorted[middle]<=value) low=middle+1;
      else high=middle;
     }
   return low;
  }

double ExpectedMappedSpread(const double recorded,const double &demo_sorted[],
                            const double &live_sorted[])
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
   return (origin_flags & 0xFFFFFF7F);
  }

int RegisteredIndex(const MqlTick &tick)
  {
   if(tick.time_msc==REGISTERED_1_MSC && tick.bid==3427.62 && tick.ask==3427.36)
      return 0;
   if(tick.time_msc==REGISTERED_2_MSC && tick.bid==3418.20 && tick.ask==3418.16)
      return 1;
   return -1;
  }

bool DeriveWarmup(const int report,const string warmup_filename)
  {
   MqlRates rates[];
   int copied=CopyRates(InpOriginSymbol,PERIOD_M30,
                        (datetime)(WARMUP_START_MSC/1000),
                        (datetime)((WARMUP_END_MSC/1000)-1),rates);
   int copy_error=GetLastError();
   int warmup=FileOpen(warmup_filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(warmup==INVALID_HANDLE)
     {
      WriteRow(report,"warmup","status","FAIL","","warmup_export_open_failed");
      return false;
     }
   FileWrite(warmup,"time_server","open","high","low","close","tick_volume","spread","real_volume");
   for(int i=0;i<copied;i++)
      FileWrite(warmup,TimeToString(rates[i].time,TIME_DATE|TIME_SECONDS),
                DoubleToString(rates[i].open,g_digits),DoubleToString(rates[i].high,g_digits),
                DoubleToString(rates[i].low,g_digits),DoubleToString(rates[i].close,g_digits),
                rates[i].tick_volume,rates[i].spread,DoubleToString(rates[i].real_volume,8));
   FileFlush(warmup);
   FileClose(warmup);

   double coverage=(EXPECTED_WARMUP_M30_SLOTS>0 ? (double)copied/(double)EXPECTED_WARMUP_M30_SLOTS : 0.0);
   long expected_first=WARMUP_START_MSC;
   long expected_last=WARMUP_END_MSC-(30*60*1000);
   int terminal_gaps=0;
   if(copied<=0 || ((long)rates[0].time)*1000>expected_first+(30*60*1000)) terminal_gaps++;
   if(copied<=0 || ((long)rates[copied-1].time)*1000<expected_last) terminal_gaps++;

   int h4_bars=0;
   long previous_h4=-1;
   for(int i=0;i<copied;i++)
     {
      long bucket=((long)rates[i].time)/(4*60*60);
      if(bucket!=previous_h4)
        {
         h4_bars++;
         previous_h4=bucket;
        }
     }
   bool pass=(copy_error==0 && copied>0 && coverage>=MIN_WARMUP_COVERAGE && terminal_gaps==0);
   WriteRow(report,"warmup","from","2021.04.01 00:00:00","broker_server_time");
   WriteRow(report,"warmup","to_exclusive","2021.07.01 00:00:00","broker_server_time");
   WriteRow(report,"warmup","m30_bars",IntegerToString(copied),"bars");
   WriteRow(report,"warmup","expected_m30_slots",IntegerToString(EXPECTED_WARMUP_M30_SLOTS),"bars");
   WriteRow(report,"warmup","coverage_ratio",DoubleToString(coverage,8),"ratio");
   WriteRow(report,"warmup","derived_h4_bars",IntegerToString(h4_bars),"bars");
   WriteRow(report,"warmup","unexplained_terminal_gaps",IntegerToString(terminal_gaps),"gaps");
   WriteRow(report,"warmup","export_file",warmup_filename);
   WriteRow(report,"warmup","status",pass ? "PASS" : "FAIL","",
            StringFormat("copy_error=%d",copy_error));
   return pass;
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA manifest gate refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true) || !SymbolSelect(InpReducedSymbol,true))
     {
      PrintFormat("KingEA manifest gate failed: required symbols unavailable; error=%d",GetLastError());
      return;
     }
   bool is_custom=false;
   if(!SymbolExist(InpReducedSymbol,is_custom) || !is_custom)
     {
      Print("KingEA manifest gate failed: reduced symbol is not a local custom symbol.");
      return;
     }
   g_digits=(int)SymbolInfoInteger(InpOriginSymbol,SYMBOL_DIGITS);
   g_point=SymbolInfoDouble(InpOriginSymbol,SYMBOL_POINT);
   if(g_point<=0.0) return;

   double live_sorted[];
   double demo_sorted[];
   if(!LoadDistribution(InpLiveEvidenceFile,"JustMarkets-Live2","LIVE2_REFERENCE",
                        "live_reference_rank_",EXPECTED_LIVE_COUNT,1.26,live_sorted) ||
      !LoadDistribution(InpDemoEvidenceFile,"JustMarkets-Demo2","DEMO2_BOUNDARY",
                        "demo_old_reference_rank_",EXPECTED_DEMO_COUNT,23.76,demo_sorted))
     {
      Print("KingEA manifest gate failed: spread evidence validation failed.");
      return;
     }

   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string safe_utc=utc;
   StringReplace(safe_utc,":","-");
   StringReplace(safe_utc," ","_");
   string filename="KingEA\\rsb3_manifest_gate_"+safe_utc+".csv";
   string warmup_filename="KingEA\\rsb3_warmup_m30_"+safe_utc+".csv";
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA manifest gate failed: report open error=%d",GetLastError());
      return;
     }
   FileWrite(report,"section","key","value","unit","notes");
   WriteRow(report,"audit","scope","NON_PERFORMANCE_RSB3_MANIFEST_GATE");
   WriteRow(report,"audit","build_id","RSB3-MANIFEST-GATE-20260726-A");
   WriteRow(report,"audit","server",server);
   WriteRow(report,"audit","origin_symbol",InpOriginSymbol);
   WriteRow(report,"audit","reduced_symbol",InpReducedSymbol);

   long total=0;
   long transformed=0;
   long unchanged=0;
   long backward=0;
   long invalid_quotes=0;
   long unexpected_crossed=0;
   long nonflag_mismatches=0;
   long invalid_flags=0;
   long native_registered[2]={0,0};
   long custom_registered[2]={0,0};
   long previous_origin=0;
   long previous_custom=0;
   long count_mismatch_days=0;
   bool copy_ok=true;
   const long DAY_MSC=86400000;

   for(long day=DATASET_START_MSC;day<DATASET_END_MSC;day+=DAY_MSC)
     {
      long day_to=MathMin(day+DAY_MSC,DATASET_END_MSC);
      MqlTick origin[];
      MqlTick stored[];
      ResetLastError();
      int origin_count=CopyTicksRange(InpOriginSymbol,origin,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      int origin_error=GetLastError();
      ResetLastError();
      int stored_count=CopyTicksRange(InpReducedSymbol,stored,COPY_TICKS_ALL,(ulong)day,(ulong)(day_to-1));
      int stored_error=GetLastError();
      if(origin_count<0 || stored_count<0)
        {
         copy_ok=false;
         WriteRow(report,"failure","copy",StringFormat("%I64d",day),"",
                  StringFormat("origin_error=%d|stored_error=%d",origin_error,stored_error));
         break;
        }
      if(origin_count!=stored_count) count_mismatch_days++;
      int compare_count=MathMin(origin_count,stored_count);
      for(int i=0;i<compare_count;i++)
        {
         if(origin[i].time_msc<previous_origin || stored[i].time_msc<previous_custom) backward++;
         previous_origin=origin[i].time_msc;
         previous_custom=stored[i].time_msc;

         if(!MathIsValidNumber(origin[i].bid) || !MathIsValidNumber(origin[i].ask) ||
            origin[i].bid<=0.0 || origin[i].ask<=0.0)
            invalid_quotes++;

         int origin_registered=RegisteredIndex(origin[i]);
         int custom_registered_index=RegisteredIndex(stored[i]);
         if(origin_registered>=0) native_registered[origin_registered]++;
         if(custom_registered_index>=0) custom_registered[custom_registered_index]++;
         if(origin[i].ask<origin[i].bid && origin_registered<0) unexpected_crossed++;
         if(stored[i].ask<stored[i].bid && custom_registered_index<0) unexpected_crossed++;

         double expected_ask=origin[i].ask;
         if(origin[i].time_msc<BOUNDARY_MSC)
           {
            expected_ask=NormalizeDouble(origin[i].bid+
                         ExpectedMappedSpread(origin[i].ask-origin[i].bid,demo_sorted,live_sorted),g_digits);
            transformed++;
           }
         else unchanged++;

         if(origin[i].time_msc!=stored[i].time_msc ||
            origin[i].time!=stored[i].time ||
            origin[i].bid!=stored[i].bid ||
            stored[i].ask!=expected_ask ||
            origin[i].last!=stored[i].last ||
            origin[i].volume!=stored[i].volume ||
            origin[i].volume_real!=stored[i].volume_real)
            nonflag_mismatches++;

         if(stored[i].flags!=ExpectedPersistedFlags(origin[i].flags))
            invalid_flags++;
        }
      total+=compare_count;
      ArrayFree(origin);
      ArrayFree(stored);
      if((total%10000000)<compare_count)
         PrintFormat("KingEA manifest gate progress: ticks=%I64d",total);
     }

   WriteRow(report,"crossed","registered_1_time_msc",StringFormat("%I64d",REGISTERED_1_MSC));
   WriteRow(report,"crossed","registered_1_bid","3427.62","price");
   WriteRow(report,"crossed","registered_1_ask","3427.36","price");
   WriteRow(report,"crossed","registered_1_native_count",StringFormat("%I64d",native_registered[0]),"ticks");
   WriteRow(report,"crossed","registered_1_custom_count",StringFormat("%I64d",custom_registered[0]),"ticks");
   WriteRow(report,"crossed","registered_2_time_msc",StringFormat("%I64d",REGISTERED_2_MSC));
   WriteRow(report,"crossed","registered_2_bid","3418.20","price");
   WriteRow(report,"crossed","registered_2_ask","3418.16","price");
   WriteRow(report,"crossed","registered_2_native_count",StringFormat("%I64d",native_registered[1]),"ticks");
   WriteRow(report,"crossed","registered_2_custom_count",StringFormat("%I64d",custom_registered[1]),"ticks");
   WriteRow(report,"summary","total_ticks",StringFormat("%I64d",total),"ticks");
   WriteRow(report,"summary","transformed_ticks",StringFormat("%I64d",transformed),"ticks");
   WriteRow(report,"summary","unchanged_ticks",StringFormat("%I64d",unchanged),"ticks");
   WriteRow(report,"summary","unexpected_crossed",StringFormat("%I64d",unexpected_crossed),"ticks");
   WriteRow(report,"summary","backward_timestamps",StringFormat("%I64d",backward),"ticks");
   WriteRow(report,"summary","invalid_quotes",StringFormat("%I64d",invalid_quotes),"ticks");
   WriteRow(report,"summary","count_mismatch_days",StringFormat("%I64d",count_mismatch_days),"days");
   WriteRow(report,"summary","nonflag_mismatches",StringFormat("%I64d",nonflag_mismatches),"ticks");
   WriteRow(report,"summary","invalid_flag_normalizations",StringFormat("%I64d",invalid_flags),"ticks");

   bool warmup_ok=DeriveWarmup(report,warmup_filename);
   bool result=(copy_ok &&
                total==EXPECTED_TOTAL &&
                transformed==EXPECTED_TRANSFORMED &&
                unchanged==EXPECTED_UNCHANGED &&
                native_registered[0]==1 && native_registered[1]==1 &&
                custom_registered[0]==1 && custom_registered[1]==1 &&
                unexpected_crossed==0 && backward==0 && invalid_quotes==0 &&
                count_mismatch_days==0 && nonflag_mismatches==0 && invalid_flags==0 &&
                warmup_ok);
   WriteRow(report,"result","status",result ? "PASS" : "FAIL");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA RSB3 manifest gate report: %s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; ticks=%I64d; crossed_native=%I64d/%I64d; crossed_custom=%I64d/%I64d; unexpected=%I64d; nonflag=%I64d; invalid_flags=%I64d; warmup=%s. Read-only; no performance authorization.",
               result ? "PASS" : "FAIL",total,native_registered[0],native_registered[1],
               custom_registered[0],custom_registered[1],unexpected_crossed,
               nonflag_mismatches,invalid_flags,warmup_ok ? "PASS" : "FAIL");
  }
