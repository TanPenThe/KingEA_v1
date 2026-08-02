#property copyright "KingEA"
#property version   "1.00"
#property tester_everytick_calculate
#property description "Signal-free Stage 14 real-tick throughput benchmark."
#property description "No indicator, signal, trade, return, or performance capability."

input string InpBenchmarkRootSha256="";
input string InpBranch="";
input string InpExpectedSymbol="";
input int    InpTesterModel=4;
input bool   InpLocalAgentsOnly=true;
input bool   InpRemoteAgentsDisabled=true;
input bool   InpCloudAgentsDisabled=true;
input int    InpBenchmarkPassId=0;

long g_tick_count=0;
long g_first_tick_msc=0;
long g_last_tick_msc=0;
bool g_healthy=false;

bool BenchmarkHash(const string value)
  {
   if(StringLen(value)!=64)
      return false;
   for(int i=0;i<64;i++)
     {
      ushort character=StringGetCharacter(value,i);
      if(!((character>='0' && character<='9') ||
           (character>='A' && character<='F')))
         return false;
     }
   return true;
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || InpTesterModel!=4 ||
      !InpLocalAgentsOnly || !InpRemoteAgentsDisabled ||
      !InpCloudAgentsDisabled || !BenchmarkHash(InpBenchmarkRootSha256) ||
      InpBenchmarkPassId<0 || InpExpectedSymbol=="" ||
      _Symbol!=InpExpectedSymbol ||
      (InpBranch!="RECORDED" && InpBranch!="RSB3") ||
      (InpBranch=="RECORDED" && _Symbol!="ETHUSD.s") ||
      (InpBranch=="RSB3" && _Symbol!="KINGEA_ETHUSD_S_RSB3"))
      return INIT_FAILED;
   g_healthy=true;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!g_healthy)
      return;
   MqlTick tick={};
   if(!SymbolInfoTick(_Symbol,tick) || tick.time_msc<=0 ||
      (g_last_tick_msc>0 && tick.time_msc<g_last_tick_msc))
     {
      g_healthy=false;
      return;
     }
   if(g_tick_count==0)
      g_first_tick_msc=(long)tick.time_msc;
   g_last_tick_msc=(long)tick.time_msc;
   g_tick_count++;
  }

double OnTester()
  {
   string payload=StringFormat(
      "schema=1|kind=SIGNAL_FREE_BENCHMARK|root=%s|branch=%s|pass=%d|ticks=%I64d|first_tick_msc=%I64d|last_tick_msc=%I64d|signals=0|trades=0|returns=ABSENT|candidate_budget=0|complete=1|healthy=%d",
      InpBenchmarkRootSha256,InpBranch,InpBenchmarkPassId,g_tick_count,
      g_first_tick_msc,g_last_tick_msc,g_healthy ? 1 : 0);
   uchar frame[];
   int count=StringToCharArray(payload,frame,0,WHOLE_ARRAY,CP_UTF8);
   if(count>0)
      ArrayResize(frame,count-1);
   if(!g_healthy || g_tick_count<=0 || count<=0 ||
      !FrameAdd("KINGEA_STAGE14_BENCHMARK",InpBenchmarkPassId,0.0,frame))
      return -1.0;
   return 0.0;
  }

void OnTesterPass()
  {
   ulong pass=0;
   string name="";
   long identifier=0;
   double value=0.0;
   uchar data[];
   while(FrameNext(pass,name,identifier,value,data))
      PrintFormat("KINGEA_STAGE14_BENCHMARK_FRAME: pass=%I64u id=%I64d bytes=%d",
                  pass,identifier,ArraySize(data));
  }

void OnTesterDeinit()
  {
   OnTesterPass();
  }
