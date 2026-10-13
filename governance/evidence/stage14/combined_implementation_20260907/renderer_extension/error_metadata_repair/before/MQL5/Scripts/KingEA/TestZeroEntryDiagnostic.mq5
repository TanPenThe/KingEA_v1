#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Deterministic, non-order Gate 1 zero-entry diagnostic contract tests."

#include <KingEA/ZeroEntryDiagnostic.mqh>

int g_checks=0;
int g_failures=0;

void Check(const bool condition,const string name)
  {
   g_checks++;
   if(condition)
      Print("PASS: ",name);
   else
     {
      g_failures++;
      Print("FAIL: ",name);
     }
  }

void OnStart()
  {
   KingEAZeroEntryFunnel funnel={};
   KingEAZeroEntryReset(funnel);
   KingEAZeroEntryCountClosedBar(funnel);
   KingEAZeroEntryCountRegime(funnel,true,true,0);
   KingEAZeroEntryCountSleeve(funnel,true,true,0);
   KingEAZeroEntryCountSafety(funnel,true,0);
   KingEAZeroEntryCountVirtualAttempt(funnel,true);
   KingEAZeroEntryCountAccounting(funnel,true);

   Check(KingEAZeroEntryFunnelComplete(funnel),
         "complete synthetic funnel reaches accounting without an order");
   Check(KingEAZeroEntryFirstZeroStage(funnel)==KINGEA_ZERO_ENTRY_STAGE_NONE,
         "complete synthetic funnel has no zero stage");

   KingEAZeroEntryFunnel gap={};
   KingEAZeroEntryReset(gap);
   KingEAZeroEntryCountClosedBar(gap);
   KingEAZeroEntryCountRegime(gap,false,false,4);
   Check(KingEAZeroEntryFirstZeroStage(gap)==KINGEA_ZERO_ENTRY_STAGE_REGIME_HEALTH,
         "unhealthy regime is identified before sleeve processing");
   Check(gap.regime_reason_counts[4]==1,
         "regime reason count is preserved independently");

   KingEAZeroEntryFunnel rejected={};
   KingEAZeroEntryReset(rejected);
   KingEAZeroEntryCountClosedBar(rejected);
   KingEAZeroEntryCountRegime(rejected,true,true,0);
   KingEAZeroEntryCountSleeve(rejected,true,true,0);
   KingEAZeroEntryCountSafety(rejected,false,7);
   Check(KingEAZeroEntryFirstZeroStage(rejected)==KINGEA_ZERO_ENTRY_STAGE_SAFETY_APPROVAL,
         "safety rejection is identified after a valid sleeve intent");
   Check(rejected.safety_reason_counts[7]==1,
         "safety reason count is preserved independently");

   string payload=KingEAZeroEntryPayload(funnel,"SYNTHETIC",7168);
   Check(StringFind(payload,"returns=ABSENT")>=0 &&
         StringFind(payload,"native_order_calls=0")>=0 &&
         StringFind(payload,"accounting_completions=1")>=0,
         "payload exposes funnel counts only and proves zero native orders");
   PrintFormat("GATE1_ZERO_ENTRY_DIAGNOSTIC_CONTRACT_%s: checks=%d; failures=%d",
               g_failures==0 ? "PASS" : "FAIL",g_checks,g_failures);
  }
