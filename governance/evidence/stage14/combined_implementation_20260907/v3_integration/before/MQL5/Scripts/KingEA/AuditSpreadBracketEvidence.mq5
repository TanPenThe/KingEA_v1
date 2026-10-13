#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only native spread-bracket evidence export."
#property description "No orders; signals; indicators; returns; or optimizer logic."

input string InpSymbol = "ETHUSD.s";
input bool   InpExportRawReferenceSpreads = true;

const int    ROLLING_WINDOW = 1001;
const int    CONFIRM_WINDOWS = 1001;
const double AUDITED_LIVE_MEDIAN = 1.26;

enum EvidenceRole
  {
   ROLE_UNSUPPORTED=0,
   ROLE_DEMO2_BOUNDARY=1,
   ROLE_LIVE2_REFERENCE=2
  };

string g_symbol;
string g_server;
string g_snapshot_utc;
string g_snapshot_server;
int    g_digits;
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
   FileWrite(handle,g_snapshot_utc,g_snapshot_server,section,key,value,unit,notes);
  }

datetime FixedMonthlyStart(const int year,const int month)
  {
   MqlDateTime value={};
   value.year=year;
   value.mon=month;
   value.day=15;
   value.hour=12;
   datetime result=StructToTime(value);
   MqlDateTime normalized={};
   if(!TimeToStruct(result,normalized))
      return 0;
   if(normalized.day_of_week==0)
      result+=24*60*60;
   else if(normalized.day_of_week==6)
      result+=2*24*60*60;
   return result;
  }

datetime MakeTime(const int year,const int month,const int day)
  {
   MqlDateTime value={};
   value.year=year;
   value.mon=month;
   value.day=day;
   return StructToTime(value);
  }

int CopyWindow(const datetime from,const datetime to,MqlTick &ticks[],int &copy_error)
  {
   copy_error=0;
   int copied=-1;
   for(int attempt=0;attempt<2;attempt++)
     {
      ResetLastError();
      ulong from_msc=((ulong)from)*1000;
      ulong to_msc=((ulong)to)*1000-1;
      copied=CopyTicksRange(g_symbol,ticks,COPY_TICKS_ALL,from_msc,to_msc);
      copy_error=GetLastError();
      if(copied>=0)
         break;
      Sleep(250);
     }
   return copied;
  }

bool ValidSpread(const MqlTick &tick,double &spread)
  {
   if(!MathIsValidNumber(tick.bid) || !MathIsValidNumber(tick.ask) ||
      tick.bid<=0.0 || tick.ask<=0.0)
      return false;
   spread=tick.ask-tick.bid;
   return MathIsValidNumber(spread) && spread>0.0;
  }

void AppendValue(double &values[],int &count,const double value)
  {
   if(count>=ArraySize(values))
      ArrayResize(values,count+1,250000);
   values[count++]=value;
  }

double Percentile(const double &sorted[],const int count,const double fraction)
  {
   if(count<=0)
      return 0.0;
   int index=(int)MathFloor(fraction*(count-1));
   index=MathMax(0,MathMin(index,count-1));
   return sorted[index];
  }

string TickTimeText(const long time_msc)
  {
   datetime seconds=(datetime)(time_msc/1000);
   int millis=(int)(time_msc%1000);
   return TimeToString(seconds,TIME_DATE|TIME_SECONDS)+StringFormat(".%03d",millis);
  }

EvidenceRole DetectRole()
  {
   if(StringFind(g_server,"Demo2")>=0)
      return ROLE_DEMO2_BOUNDARY;
   if(StringFind(g_server,"Live2")>=0)
      return ROLE_LIVE2_REFERENCE;
   return ROLE_UNSUPPORTED;
  }

bool CollectReference(const int handle,const string label,
                      const int start_year,const int start_month,
                      const int end_year,const int end_month,
                      double &values[],int &value_count)
  {
   value_count=0;
   ArrayResize(values,0);
   int current=start_year*12+(start_month-1);
   int final_month=end_year*12+(end_month-1);
   bool complete=true;

   for(;current<=final_month;current++)
     {
      int year=current/12;
      int month=current%12+1;
      datetime from=FixedMonthlyStart(year,month);
      datetime to=from+60*60;
      MqlTick ticks[];
      int copy_error=0;
      int copied=CopyWindow(from,to,ticks,copy_error);
      long valid=0;
      long invalid=0;
      double monthly[];
      int monthly_count=0;

      if(copied<0)
        {
         complete=false;
         WriteRow(handle,"monthly_sample",label+"_"+IntegerToString(year)+StringFormat("_%02d",month),
                  "COPY_FAILED","",StringFormat("error=%d",copy_error));
         continue;
        }

      ArrayResize(monthly,MathMax(0,copied));
      for(int i=0;i<copied;i++)
        {
         double spread=0.0;
         if(!ValidSpread(ticks[i],spread))
           {
            invalid++;
            continue;
           }
         monthly[monthly_count++]=spread;
         AppendValue(values,value_count,spread);
         valid++;
        }
      ArrayResize(monthly,monthly_count);
      if(monthly_count>0)
         ArraySort(monthly);
      else
         complete=false;

      string key=label+"_"+IntegerToString(year)+StringFormat("_%02d",month);
      string summary=StringFormat("from=%s|ticks=%d|valid=%I64d|invalid=%I64d|median=%s|p99=%s|max=%s",
                                  TimeToString(from,TIME_DATE|TIME_SECONDS),copied,valid,invalid,
                                  DoubleToString(Percentile(monthly,monthly_count,0.50),g_digits),
                                  DoubleToString(Percentile(monthly,monthly_count,0.99),g_digits),
                                  DoubleToString(Percentile(monthly,monthly_count,1.00),g_digits));
      WriteRow(handle,"monthly_sample",key,summary);
      ArrayFree(monthly);
      ArrayFree(ticks);
     }

   ArrayResize(values,value_count);
   if(value_count>0)
      ArraySort(values);
   return complete && value_count>0;
  }

void ExportDistribution(const int handle,const string label,const double &sorted[],const int count)
  {
   WriteRow(handle,"reference",label+"_count",IntegerToString(count),"valid_ticks");
   WriteRow(handle,"reference",label+"_min",DoubleToString(Percentile(sorted,count,0.00),g_digits),"price");
   WriteRow(handle,"reference",label+"_median",DoubleToString(Percentile(sorted,count,0.50),g_digits),"price");
   WriteRow(handle,"reference",label+"_p95",DoubleToString(Percentile(sorted,count,0.95),g_digits),"price");
   WriteRow(handle,"reference",label+"_p99",DoubleToString(Percentile(sorted,count,0.99),g_digits),"price");
   WriteRow(handle,"reference",label+"_max",DoubleToString(Percentile(sorted,count,1.00),g_digits),"price");

   for(int q=0;q<=100;q++)
     {
      double fraction=(double)q/100.0;
      WriteRow(handle,"quantile",label+StringFormat("_q%03d",q),
               DoubleToString(Percentile(sorted,count,fraction),g_digits),"price");
     }

   if(!InpExportRawReferenceSpreads)
      return;
   for(int i=0;i<count;i++)
      WriteRow(handle,"raw_sorted_spread",label+"_rank_"+IntegerToString(i),
               DoubleToString(sorted[i],g_digits),"price");
  }

int LowerBound(const double &sorted[],const int count,const double value)
  {
   int low=0;
   int high=count;
   while(low<high)
     {
      int mid=(low+high)/2;
      if(sorted[mid]<value)
         low=mid+1;
      else
         high=mid;
     }
   return low;
  }

bool RemoveSorted(double &sorted[],const int count,const double value)
  {
   int position=LowerBound(sorted,count,value);
   if(position>=count || sorted[position]!=value)
     {
      position=-1;
      for(int i=0;i<count;i++)
         if(sorted[i]==value)
           {
            position=i;
            break;
           }
      if(position<0)
         return false;
     }
   for(int i=position;i<count-1;i++)
      sorted[i]=sorted[i+1];
   return true;
  }

void InsertSorted(double &sorted[],const int count,const double value)
  {
   int position=LowerBound(sorted,count,value);
   for(int i=count;i>position;i--)
      sorted[i]=sorted[i-1];
   sorted[position]=value;
  }

bool DetectBoundary(const int handle,const double threshold,long &boundary_msc)
  {
   datetime search_from=MakeTime(2023,5,1);
   datetime search_to=MakeTime(2023,7,1);
   double ring[];
   double sorted[];
   ArrayResize(ring,ROLLING_WINDOW);
   ArrayResize(sorted,ROLLING_WINDOW);
   int count=0;
   int ring_position=0;
   int below_streak=0;
   long candidate_msc=0;
   long valid_ticks=0;
   long invalid_ticks=0;
   bool internal_error=false;
   boundary_msc=0;

   for(datetime day=search_from;day<search_to && boundary_msc==0;day+=24*60*60)
     {
      datetime day_to=(datetime)MathMin((long)(day+24*60*60),(long)search_to);
      MqlTick ticks[];
      int copy_error=0;
      int copied=CopyWindow(day,day_to,ticks,copy_error);
      if(copied<0)
        {
         WriteRow(handle,"boundary","copy_failure",TimeToString(day,TIME_DATE),"",StringFormat("error=%d",copy_error));
         internal_error=true;
         break;
        }

      for(int i=0;i<copied;i++)
        {
         double spread=0.0;
         if(!ValidSpread(ticks[i],spread))
           {
            invalid_ticks++;
            continue;
           }
         valid_ticks++;

         if(count<ROLLING_WINDOW)
           {
            InsertSorted(sorted,count,spread);
            ring[ring_position]=spread;
            ring_position=(ring_position+1)%ROLLING_WINDOW;
            count++;
            if(count<ROLLING_WINDOW)
               continue;
           }
         else
           {
            double outgoing=ring[ring_position];
            if(!RemoveSorted(sorted,count,outgoing))
              {
               internal_error=true;
               break;
              }
            InsertSorted(sorted,count-1,spread);
            ring[ring_position]=spread;
            ring_position=(ring_position+1)%ROLLING_WINDOW;
           }

         double rolling_median=sorted[ROLLING_WINDOW/2];
         if(rolling_median<=threshold)
           {
            if(below_streak==0)
               candidate_msc=ticks[i].time_msc;
            below_streak++;
            if(below_streak>=CONFIRM_WINDOWS)
              {
               boundary_msc=candidate_msc;
               break;
              }
           }
         else
           {
            below_streak=0;
            candidate_msc=0;
           }
        }
      ArrayFree(ticks);
      if(internal_error)
         break;
     }

   WriteRow(handle,"boundary","search_from",TimeToString(search_from,TIME_DATE|TIME_SECONDS),"broker_server_time");
   WriteRow(handle,"boundary","search_to_exclusive",TimeToString(search_to,TIME_DATE|TIME_SECONDS),"broker_server_time");
   WriteRow(handle,"boundary","rolling_window",IntegerToString(ROLLING_WINDOW),"valid_ticks");
   WriteRow(handle,"boundary","confirmation_windows",IntegerToString(CONFIRM_WINDOWS),"rolling_medians");
   WriteRow(handle,"boundary","valid_search_ticks",StringFormat("%I64d",valid_ticks),"ticks");
   WriteRow(handle,"boundary","invalid_search_ticks",StringFormat("%I64d",invalid_ticks),"ticks");
   WriteRow(handle,"boundary","result",boundary_msc>0 ? "PASS" : "FAIL");
   WriteRow(handle,"boundary","boundary_time_msc",StringFormat("%I64d",boundary_msc),"milliseconds_since_epoch");
   WriteRow(handle,"boundary","boundary_server_time",boundary_msc>0 ? TickTimeText(boundary_msc) : "UNAVAILABLE","broker_server_time");
   return boundary_msc>0 && !internal_error;
  }

void OnStart()
  {
   g_symbol=(StringLen(InpSymbol)>0 ? InpSymbol : _Symbol);
   g_server=AccountInfoString(ACCOUNT_SERVER);
   g_snapshot_utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   g_snapshot_server=TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS);
   if(!SymbolSelect(g_symbol,true))
     {
      PrintFormat("KingEA spread-bracket audit failed: cannot select %s; error=%d",g_symbol,GetLastError());
      return;
     }
   g_digits=(int)SymbolInfoInteger(g_symbol,SYMBOL_DIGITS);
   g_point=SymbolInfoDouble(g_symbol,SYMBOL_POINT);
   EvidenceRole role=DetectRole();
   if(role==ROLE_UNSUPPORTED)
     {
      PrintFormat("KingEA spread-bracket audit refused: server '%s' is neither JustMarkets-Demo2 nor JustMarkets-Live2.",g_server);
      return;
     }

   string role_text=(role==ROLE_DEMO2_BOUNDARY ? "DEMO2_BOUNDARY" : "LIVE2_REFERENCE");
   string stamp=SafeName(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   string filename="KingEA\\spread_bracket_evidence_"+SafeName(g_symbol)+"_"+role_text+"_"+stamp+".csv";
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA spread-bracket audit failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"snapshot_utc","snapshot_server","section","key","value","unit","notes");
   WriteRow(handle,"audit","scope","NON_PERFORMANCE_NATIVE_SPREAD_BRACKET_EVIDENCE");
   WriteRow(handle,"audit","prohibited","No orders; signals; indicators; OHLC analysis; returns; trades; ranking; or optimization.");
   WriteRow(handle,"audit","server",g_server);
   WriteRow(handle,"audit","symbol",g_symbol);
   WriteRow(handle,"audit","role",role_text);
   WriteRow(handle,"audit","method_version","1.00");
   WriteRow(handle,"audit","raw_reference_spreads_exported",InpExportRawReferenceSpreads ? "1" : "0");

   bool passed=false;
   if(role==ROLE_LIVE2_REFERENCE)
     {
      double live_values[];
      int live_count=0;
      bool complete=CollectReference(handle,"live_reference",2024,12,2026,6,live_values,live_count);
      ExportDistribution(handle,"live_reference",live_values,live_count);
      double live_median=Percentile(live_values,live_count,0.50);
      bool median_match=(MathAbs(live_median-AUDITED_LIVE_MEDIAN)<=g_point/2.0);
      WriteRow(handle,"verification","audited_live_median",DoubleToString(AUDITED_LIVE_MEDIAN,g_digits),"price");
      WriteRow(handle,"verification","live_median_match",median_match ? "PASS" : "FAIL","", "Mismatch blocks manifest; do not change the frozen audited value.");
      passed=complete && median_match;
      ArrayFree(live_values);
     }
   else
     {
      double high_values[];
      int high_count=0;
      bool complete=CollectReference(handle,"demo_old_reference",2021,7,2023,5,high_values,high_count);
      ExportDistribution(handle,"demo_old_reference",high_values,high_count);
      double high_median=Percentile(high_values,high_count,0.50);
      double threshold=(high_median>0.0 ? MathSqrt(high_median*AUDITED_LIVE_MEDIAN) : 0.0);
      WriteRow(handle,"boundary","high_median",DoubleToString(high_median,g_digits),"price");
      WriteRow(handle,"boundary","fixed_live_median",DoubleToString(AUDITED_LIVE_MEDIAN,g_digits),"price");
      WriteRow(handle,"boundary","geometric_threshold",DoubleToString(threshold,g_digits),"price");
      long boundary_msc=0;
      bool boundary_ok=(complete && threshold>0.0 && DetectBoundary(handle,threshold,boundary_msc));
      passed=complete && boundary_ok;
      ArrayFree(high_values);
     }

   WriteRow(handle,"audit","result",passed ? "PASS" : "FAIL");
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA spread-bracket evidence export complete: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s. This is non-performance evidence and does not authorize candidate testing.",passed ? "PASS" : "FAIL");
  }
