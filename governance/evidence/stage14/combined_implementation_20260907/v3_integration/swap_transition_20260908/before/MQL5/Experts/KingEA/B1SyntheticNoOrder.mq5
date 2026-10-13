// B1 synthetic infrastructure harness. It is not Candidate 001 and cannot trade.
#property strict
#property version   "1.00"

input string InpRunId="";
input string InpEvidenceFolder="";

ulong g_valid_ticks=0;
bool g_funnel_published=false;

string TelemetryJson()
  {
   return StringFormat("{\"kind\":\"B1_NON_CANDIDATE_FUNNEL_TELEMETRY_V2\",\"run_id\":\"%s\",\"tick\":{\"valid\":%I64u,\"invalid\":0,\"bucket_transitions\":1},\"bars\":{\"appended\":1,\"faults\":0},\"regime\":{\"evaluations\":1,\"healthy\":1,\"blocked\":0,\"reason_counts\":{}},\"breakout\":{\"evaluated\":1,\"intents\":1,\"blocked\":0},\"sleeve\":{\"evaluations\":1,\"entry_intents\":1,\"exit_intents\":1,\"blocked\":0},\"safety\":{\"evaluations\":2,\"approved\":1,\"rejected\":1},\"routing\":{\"attempts\":1,\"accepted\":1,\"no_order_proof\":1},\"accounting\":{\"submissions\":1,\"completed\":1,\"faults\":0}}",InpRunId,g_valid_ticks);
  }

void WriteCommon(const string filename,const string text)
  {
   int handle=FileOpen(InpEvidenceFolder+"\\"+filename,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(handle==INVALID_HANDLE) return;
   FileWriteString(handle,text);
   FileClose(handle);
  }

int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER)==0 || StringLen(InpRunId)==0 || StringLen(InpEvidenceFolder)==0)
      return INIT_FAILED;
   FolderCreate(InpEvidenceFolder,FILE_COMMON);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   g_valid_ticks++;
   if(!g_funnel_published)
     {
      WriteCommon("telemetry.json",TelemetryJson());
      g_funnel_published=true;
     }
  }

void OnDeinit(const int reason)
  {
   WriteCommon("telemetry.json",TelemetryJson());
   WriteCommon("result.json",StringFormat("{\"kind\":\"B1_NON_CANDIDATE_RESULT_V2\",\"run_id\":\"%s\",\"status\":\"COMPLETE\",\"native_orders\":0}",InpRunId));
  }
