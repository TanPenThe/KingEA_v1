#property copyright "KingEA"
#property version   "1.03"
#property script_show_inputs
#property description "Builds the frozen native reduced-spread custom symbol."
#property description "No orders; signals; indicators; returns; or optimizer logic."
#property description "Build ID: RSB3-REPLACE-20260723-A; daily CustomTicksReplace plus immediate readback."

input bool   InpAuthorizeLocalCustomSymbolBuild = false;
input string InpOriginSymbol = "ETHUSD.s";
input string InpCustomSymbol = "KINGEA_ETHUSD_S_RSB3";
input string InpCustomPath = "KingEA\\NativeSensitivity";
input string InpLiveEvidenceFile = "KingEA\\spread_bracket_evidence_ETHUSD.s_LIVE2_REFERENCE_2026.07.22_01-07-55.csv";
input string InpDemoEvidenceFile = "KingEA\\spread_bracket_evidence_ETHUSD.s_DEMO2_BOUNDARY_2026.07.22_01-08-55.csv";

const long DATASET_START_MSC = 1625097600000; // 2021-07-01 00:00:00 broker time
const long DATASET_END_MSC = 1782864000000;   // 2026-07-01 00:00:00 broker time; exclusive
const long BOUNDARY_MSC = 1685801408062;      // 2023-06-03 14:10:08.062 broker time
const int EXPECTED_LIVE_COUNT = 156919;
const int EXPECTED_DEMO_COUNT = 128479;
const double EXPECTED_LIVE_MEDIAN = 1.26;
const double EXPECTED_DEMO_MEDIAN = 23.76;
const long REGISTERED_CROSSED_1_MSC = 1709374488223;
const long REGISTERED_CROSSED_2_MSC = 1709375322820;

string g_utc;
string g_server_time;
int g_digits;
double g_point;

string SafeName(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,"/","-");
   StringReplace(value,"\\","-");
   return value;
  }

void WriteRow(const int handle,const string section,const string key,
              const string value,const string unit="",const string notes="")
  {
   FileWrite(handle,g_utc,g_server_time,section,key,value,unit,notes);
  }

double Percentile(const double &sorted[],const int count,const double fraction)
  {
   if(count<=0)
      return 0.0;
   int index=(int)MathFloor(fraction*(count-1));
   index=MathMax(0,MathMin(index,count-1));
   return sorted[index];
  }

bool LoadEvidenceDistribution(const string filename,const string expected_server,
                              const string expected_role,const string key_prefix,
                              const int expected_count,const double expected_median,
                              double &values[])
  {
   int handle=FileOpen(filename,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA reduced-spread build failed: cannot open %s; error=%d",filename,GetLastError());
      return false;
     }

   int count=0;
   bool header=true;
   string found_server="";
   string found_role="";
   string found_result="";
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
      if(section=="audit" && key=="server")
         found_server=value;
      else if(section=="audit" && key=="role")
         found_role=value;
      else if(section=="audit" && key=="result")
         found_result=value;
      else if(section=="raw_sorted_spread" && StringFind(key,key_prefix)==0)
        {
         double spread=StringToDouble(value);
         if(!MathIsValidNumber(spread) || spread<=0.0)
           {
            FileClose(handle);
            PrintFormat("KingEA reduced-spread build failed: invalid raw spread at rank %d in %s",count,filename);
            return false;
           }
         if(count>=ArraySize(values))
            ArrayResize(values,count+1,250000);
         values[count++]=spread;
        }
     }
   FileClose(handle);
   ArrayResize(values,count);

   if(found_server!=expected_server || found_role!=expected_role || found_result!="PASS" || count!=expected_count)
     {
      PrintFormat("KingEA reduced-spread build failed: evidence identity/count mismatch file=%s server=%s role=%s result=%s count=%d",
                  filename,found_server,found_role,found_result,count);
      return false;
     }
   for(int i=1;i<count;i++)
      if(values[i]<values[i-1])
        {
         PrintFormat("KingEA reduced-spread build failed: distribution is not sorted in %s at rank %d",filename,i);
         return false;
        }
   double median=Percentile(values,count,0.50);
   if(MathAbs(median-expected_median)>g_point/2.0)
     {
      PrintFormat("KingEA reduced-spread build failed: median mismatch in %s; got=%s expected=%s",
                  filename,DoubleToString(median,g_digits),DoubleToString(expected_median,g_digits));
      return false;
     }
   return true;
  }

int UpperBound(const double &sorted[],const int count,const double value)
  {
   int low=0;
   int high=count;
   while(low<high)
     {
      int mid=(low+high)/2;
      if(sorted[mid]<=value)
         low=mid+1;
      else
         high=mid;
     }
   return low;
  }

double MapSpread(const double recorded,const double &demo_sorted[],const double &live_sorted[])
  {
   int demo_count=ArraySize(demo_sorted);
   int live_count=ArraySize(live_sorted);
   int demo_index=UpperBound(demo_sorted,demo_count,recorded)-1;
   demo_index=MathMax(0,MathMin(demo_index,demo_count-1));
   double percentile=(demo_count>1 ? (double)demo_index/(double)(demo_count-1) : 0.0);
   int live_index=(int)MathFloor(percentile*(live_count-1));
   live_index=MathMax(0,MathMin(live_index,live_count-1));
   double mapped=live_sorted[live_index];
   double points=MathCeil((mapped/g_point)-1e-10);
   return NormalizeDouble(points*g_point,g_digits);
  }

bool PrepareTarget()
  {
   bool is_custom=false;
   bool exists=SymbolExist(InpCustomSymbol,is_custom);
   if(exists && !is_custom)
     {
      Print("KingEA reduced-spread build refused: target name belongs to a broker symbol.");
      return false;
     }
   if(!exists && !CustomSymbolCreate(InpCustomSymbol,InpCustomPath,InpOriginSymbol))
     {
      PrintFormat("KingEA reduced-spread build failed: CustomSymbolCreate error=%d",GetLastError());
      return false;
     }
   if(!SymbolSelect(InpCustomSymbol,true))
     {
      PrintFormat("KingEA reduced-spread build failed: cannot select target; error=%d",GetLastError());
      return false;
     }
   MqlTick existing[];
   if(CopyTicks(InpCustomSymbol,existing,COPY_TICKS_ALL,0,1)>0)
     {
      Print("KingEA reduced-spread build refused: target already contains ticks. Use a new versioned symbol name; existing data will not be overwritten.");
      return false;
     }
   return true;
  }

bool IsRegisteredCrossedTick(const MqlTick &tick)
  {
   if(tick.time_msc==REGISTERED_CROSSED_1_MSC)
      return tick.bid==3427.62 && tick.ask==3427.36;
   if(tick.time_msc==REGISTERED_CROSSED_2_MSC)
      return tick.bid==3418.20 && tick.ask==3418.16;
   return false;
  }

bool PreflightSource(long &total_ticks,long &zero_spread_ticks,
                     long &registered_crossed_ticks,long &unexpected_reversed_ticks)
  {
   total_ticks=0;
   zero_spread_ticks=0;
   registered_crossed_ticks=0;
   unexpected_reversed_ticks=0;
   long previous_time_msc=0;
   const long DAY_MSC=86400000;
   for(long chunk_from=DATASET_START_MSC;chunk_from<DATASET_END_MSC;chunk_from+=DAY_MSC)
     {
      long chunk_to=MathMin(chunk_from+DAY_MSC,DATASET_END_MSC);
      MqlTick ticks[];
      ResetLastError();
      int copied=CopyTicksRange(InpOriginSymbol,ticks,COPY_TICKS_ALL,(ulong)chunk_from,(ulong)(chunk_to-1));
      int copy_error=GetLastError();
      if(copied<0)
        {
         PrintFormat("KingEA RSB2 preflight failed: copy from=%I64d error=%d",chunk_from,copy_error);
         return false;
        }
      for(int i=0;i<copied;i++)
        {
         string reason="";
         if(!MathIsValidNumber(ticks[i].bid) || !MathIsValidNumber(ticks[i].ask))
            reason="INVALID_NUMBER";
         else if(ticks[i].time_msc<chunk_from || ticks[i].time_msc>=chunk_to)
            reason="OUT_OF_RANGE";
         else if(ticks[i].time_msc<previous_time_msc)
            reason="BACKWARD_TIMESTAMP";
         else if(ticks[i].bid<=0.0)
            reason="NONPOSITIVE_BID";
         else if(ticks[i].ask<=0.0)
            reason="NONPOSITIVE_ASK";
         if(StringLen(reason)>0)
           {
            PrintFormat("KingEA RSB2 preflight failed: reason=%s index=%d time_msc=%I64d bid=%s ask=%s",
                        reason,i,ticks[i].time_msc,DoubleToString(ticks[i].bid,g_digits),DoubleToString(ticks[i].ask,g_digits));
            return false;
           }
         if(ticks[i].ask==ticks[i].bid)
            zero_spread_ticks++;
         else if(ticks[i].ask<ticks[i].bid)
           {
            if(IsRegisteredCrossedTick(ticks[i]))
               registered_crossed_ticks++;
            else
              {
               unexpected_reversed_ticks++;
               if(unexpected_reversed_ticks<=20)
                  PrintFormat("KingEA RSB2 preflight unexpected reversed spread: time_msc=%I64d bid=%s ask=%s",
                              ticks[i].time_msc,DoubleToString(ticks[i].bid,g_digits),DoubleToString(ticks[i].ask,g_digits));
              }
           }
         previous_time_msc=ticks[i].time_msc;
        }
      total_ticks+=copied;
      ArrayFree(ticks);
     }
   if(registered_crossed_ticks!=2 || unexpected_reversed_ticks!=0)
     {
      PrintFormat("KingEA RSB2 preflight failed: registered_crossed=%I64d expected=2 unexpected_reversed=%I64d",
                  registered_crossed_ticks,unexpected_reversed_ticks);
      return false;
     }
   PrintFormat("KingEA RSB2 preflight PASS: ticks=%I64d zero_spread_ticks=%I64d registered_crossed=2 unexpected_reversed=0.",
               total_ticks,zero_spread_ticks);
   return total_ticks>0;
  }

void OnStart()
  {
   if(!InpAuthorizeLocalCustomSymbolBuild)
     {
      Print("KingEA reduced-spread build refused: set InpAuthorizeLocalCustomSymbolBuild=true only for the registered non-trading sensitivity dataset build.");
      return;
     }
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA reduced-spread build refused: run only while connected to JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true))
     {
      PrintFormat("KingEA reduced-spread build failed: origin symbol %s unavailable.",InpOriginSymbol);
      return;
     }
   g_digits=(int)SymbolInfoInteger(InpOriginSymbol,SYMBOL_DIGITS);
   g_point=SymbolInfoDouble(InpOriginSymbol,SYMBOL_POINT);
   if(g_point<=0.0)
     {
      Print("KingEA reduced-spread build failed: invalid symbol point.");
      return;
     }

   double live_sorted[];
   double demo_sorted[];
   if(!LoadEvidenceDistribution(InpLiveEvidenceFile,"JustMarkets-Live2","LIVE2_REFERENCE",
                                "live_reference_rank_",EXPECTED_LIVE_COUNT,EXPECTED_LIVE_MEDIAN,live_sorted) ||
      !LoadEvidenceDistribution(InpDemoEvidenceFile,"JustMarkets-Demo2","DEMO2_BOUNDARY",
                                "demo_old_reference_rank_",EXPECTED_DEMO_COUNT,EXPECTED_DEMO_MEDIAN,demo_sorted))
      return;
   long preflight_ticks=0;
   long preflight_zero_spreads=0;
   long preflight_registered_crossed=0;
   long preflight_unexpected_reversed=0;
   if(!PreflightSource(preflight_ticks,preflight_zero_spreads,preflight_registered_crossed,preflight_unexpected_reversed))
      return;
   if(!PrepareTarget())
      return;

   g_utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   g_server_time=TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS);
   string stamp=SafeName(g_utc);
   string filename="KingEA\\native_reduced_build_"+SafeName(InpCustomSymbol)+"_"+stamp+".csv";
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report==INVALID_HANDLE)
     {
      PrintFormat("KingEA reduced-spread build failed: report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(report,"snapshot_utc","snapshot_server","section","key","value","unit","notes");
   WriteRow(report,"build","scope","NON_PERFORMANCE_NATIVE_REDUCED_SPREAD_DATASET");
   WriteRow(report,"build","origin_server",server);
   WriteRow(report,"build","origin_symbol",InpOriginSymbol);
   WriteRow(report,"build","target_symbol",InpCustomSymbol);
   WriteRow(report,"build","dataset_start_msc",StringFormat("%I64d",DATASET_START_MSC));
   WriteRow(report,"build","dataset_end_msc_exclusive",StringFormat("%I64d",DATASET_END_MSC));
   WriteRow(report,"build","boundary_msc",StringFormat("%I64d",BOUNDARY_MSC));
   WriteRow(report,"build","live_reference_count",IntegerToString(ArraySize(live_sorted)));
   WriteRow(report,"build","demo_reference_count",IntegerToString(ArraySize(demo_sorted)));
   WriteRow(report,"preflight","source_ticks",StringFormat("%I64d",preflight_ticks),"ticks");
   WriteRow(report,"preflight","zero_spread_ticks",StringFormat("%I64d",preflight_zero_spreads),"ticks","Accepted source events; mapped to the Live2 minimum before the boundary and preserved at/after it.");
   WriteRow(report,"preflight","registered_crossed_ticks",StringFormat("%I64d",preflight_registered_crossed),"ticks","Exact registered timestamps and prices; MT5 normalizes flags only.");
   WriteRow(report,"preflight","unexpected_reversed_ticks",StringFormat("%I64d",preflight_unexpected_reversed),"ticks");
   WriteRow(report,"preflight","status","PASS");

   long total=0;
   long transformed=0;
   long unchanged=0;
   long invalid=0;
   long readback_nonflag_mismatches=0;
   long last_time_msc=0;
   bool ok=true;
   const long DAY_MSC=86400000;
   for(long chunk_from=DATASET_START_MSC;chunk_from<DATASET_END_MSC;chunk_from+=DAY_MSC)
     {
      long chunk_to=MathMin(chunk_from+DAY_MSC,DATASET_END_MSC);
      MqlTick ticks[];
      ResetLastError();
      int copied=CopyTicksRange(InpOriginSymbol,ticks,COPY_TICKS_ALL,(ulong)chunk_from,(ulong)(chunk_to-1));
      int copy_error=GetLastError();
      if(copied<0)
        {
         WriteRow(report,"day",StringFormat("%I64d",chunk_from),"COPY_FAILED","",StringFormat("error=%d",copy_error));
         ok=false;
         break;
        }

      long day_transformed=0;
      long day_unchanged=0;
      for(int i=0;i<copied;i++)
        {
         string invalid_reason="";
         if(!MathIsValidNumber(ticks[i].bid) || !MathIsValidNumber(ticks[i].ask))
            invalid_reason="INVALID_NUMBER";
         else if(ticks[i].time_msc<chunk_from || ticks[i].time_msc>=chunk_to)
            invalid_reason="OUT_OF_RANGE";
         else if(ticks[i].time_msc<last_time_msc)
            invalid_reason="BACKWARD_TIMESTAMP";
         else if(ticks[i].bid<=0.0)
            invalid_reason="NONPOSITIVE_BID";
         else if(ticks[i].ask<=0.0)
            invalid_reason="NONPOSITIVE_ASK";
         else if(ticks[i].ask<ticks[i].bid && !IsRegisteredCrossedTick(ticks[i]))
            invalid_reason="UNREGISTERED_REVERSED_SPREAD";
         if(StringLen(invalid_reason)>0)
           {
            invalid++;
            WriteRow(report,"day",StringFormat("%I64d",chunk_from),"INVALID_SOURCE_TICK","",
                     StringFormat("reason=%s|index=%d|time_msc=%I64d|bid=%s|ask=%s",invalid_reason,i,ticks[i].time_msc,
                                  DoubleToString(ticks[i].bid,g_digits),DoubleToString(ticks[i].ask,g_digits)));
            ok=false;
            break;
           }
         if(ticks[i].time_msc<BOUNDARY_MSC)
           {
            double recorded=ticks[i].ask-ticks[i].bid;
            double mapped=MapSpread(recorded,demo_sorted,live_sorted);
            ticks[i].ask=NormalizeDouble(ticks[i].bid+mapped,g_digits);
            day_transformed++;
           }
         else
            day_unchanged++;
         last_time_msc=ticks[i].time_msc;
        }
      if(!ok)
        {
         ArrayFree(ticks);
         break;
        }
      if(copied>0)
        {
         ResetLastError();
         int replaced=CustomTicksReplace(InpCustomSymbol,(ulong)chunk_from,(ulong)(chunk_to-1),ticks);
         if(replaced!=copied)
           {
            WriteRow(report,"day",StringFormat("%I64d",chunk_from),"REPLACE_FAILED","",StringFormat("replaced=%d|copied=%d|error=%d",replaced,copied,GetLastError()));
            ok=false;
            ArrayFree(ticks);
            break;
           }

         MqlTick stored[];
         ResetLastError();
         int stored_count=CopyTicksRange(InpCustomSymbol,stored,COPY_TICKS_ALL,(ulong)chunk_from,(ulong)(chunk_to-1));
         int read_error=GetLastError();
         if(stored_count!=copied)
           {
            WriteRow(report,"day",StringFormat("%I64d",chunk_from),"READBACK_COUNT_FAILED","",
                     StringFormat("stored=%d|expected=%d|error=%d",stored_count,copied,read_error));
            ok=false;
            ArrayFree(stored);
            ArrayFree(ticks);
            break;
           }
         long day_readback_mismatches=0;
         for(int i=0;i<copied;i++)
           {
            bool same=(ticks[i].time_msc==stored[i].time_msc && ticks[i].time==stored[i].time &&
                       ticks[i].bid==stored[i].bid && ticks[i].ask==stored[i].ask &&
                       ticks[i].last==stored[i].last && ticks[i].volume==stored[i].volume &&
                       ticks[i].volume_real==stored[i].volume_real);
            if(!same)
              {
               day_readback_mismatches++;
               readback_nonflag_mismatches++;
               if(readback_nonflag_mismatches<=20)
                  WriteRow(report,"readback_mismatch",StringFormat("%I64d",stored[i].time_msc),"NONFLAG_MISMATCH","",
                           StringFormat("day=%I64d|index=%d",chunk_from,i));
              }
           }
         ArrayFree(stored);
         if(day_readback_mismatches>0)
           {
            WriteRow(report,"day",StringFormat("%I64d",chunk_from),"READBACK_FIELDS_FAILED","",
                     StringFormat("nonflag_mismatches=%I64d",day_readback_mismatches));
            ok=false;
            ArrayFree(ticks);
            break;
           }
        }
      total+=copied;
      transformed+=day_transformed;
      unchanged+=day_unchanged;
      WriteRow(report,"day",StringFormat("%I64d",chunk_from),
               StringFormat("ticks=%d|transformed=%I64d",copied,day_transformed));
      ArrayFree(ticks);
      if((total%1000000)<copied)
         PrintFormat("KingEA reduced-spread build progress: ticks=%I64d",total);
     }

   WriteRow(report,"result","total_ticks",StringFormat("%I64d",total),"ticks");
   WriteRow(report,"result","transformed_ticks",StringFormat("%I64d",transformed),"ticks");
   WriteRow(report,"result","unchanged_ticks",StringFormat("%I64d",unchanged),"ticks");
   WriteRow(report,"result","invalid_ticks",StringFormat("%I64d",invalid),"ticks");
   WriteRow(report,"result","readback_nonflag_mismatches",StringFormat("%I64d",readback_nonflag_mismatches),"ticks");
   WriteRow(report,"result","last_time_msc",StringFormat("%I64d",last_time_msc));
   WriteRow(report,"result","status",ok && total>0 ? "PASS" : "FAIL");
   FileFlush(report);
   FileClose(report);
   PrintFormat("KingEA native reduced-spread build report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; target=%s; ticks=%I64d; transformed=%I64d; readback_nonflag_mismatches=%I64d. This does not authorize performance testing.",
               ok && total>0 ? "PASS" : "FAIL",InpCustomSymbol,total,transformed,readback_nonflag_mismatches);
  }
