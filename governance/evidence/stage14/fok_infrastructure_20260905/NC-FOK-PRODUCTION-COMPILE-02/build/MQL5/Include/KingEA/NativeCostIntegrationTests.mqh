#ifndef KINGEA_NATIVE_COST_INTEGRATION_TESTS_MQH
#define KINGEA_NATIVE_COST_INTEGRATION_TESTS_MQH
#include "NativeCostIntegration.mqh"
#include "NativeCostContractTests.mqh"
void NCIntegrationContracts()
  {
   KingEANativeCostBinding b; KingEANativeDealFact f; KingEANativeCostSnapshot s;
   NCFixture(b,f,s); KingEANativeCostEvidence ledger;
   NCCheck(ledger.Begin(b),"integration binding"); f.binding=ledger.BindingHash();
   KingEANativeLifecycleFacts life={}; life.observation_origin="SYNTHETIC_INJECTED"; life.non_candidate=true;
   string outcome;
   NCCheck(KingEAHandleNativeCostDeal(ledger,b,f,life,outcome) && outcome=="ENTRY_METADATA_CAPTURED",
           "shared integration captures entry without financial projection");
   for(int side=-1;side<=1;side+=2)
     {
      KingEANativeCostEvidence a,callback,ambiguous,normal;
      NCFixture(b,f,s,side);
      NCCheck(NCReady(a,b,f,s) && NCReady(callback,b,f,s) && NCReady(ambiguous,b,f,s) &&
              NCReady(normal,b,f,s),"shared lifecycle variants ready");
      KingEAAccountingDecision da={},db={},dc={}; string sa,sb,sc;
      NCCheck(NCProject(a,da,sa) && NCProject(callback,db,sb) && NCProject(ambiguous,dc,sc),
              "same production finalization in callback/no-callback variants");
      f.entry=DEAL_ENTRY_OUT; f.type=(side==1 ? DEAL_TYPE_SELL:DEAL_TYPE_BUY);
      f.deal=99; f.order=98; f.time_msc=10000;
      life.housekeeping_proven=true; life.no_normal_exit_pending=true;
      life.sealed_boundary_hash=callback.BoundarySealHash();
      life.proof_hash=KingEAAccountingSha256("SYNTHETIC_AUTHENTICATED_LIFECYCLE");
      string before=callback.Root();
      NCCheck(KingEAHandleNativeCostDeal(callback,b,f,life,outcome) &&
              outcome=="STRATEGY_TESTER_END_OF_TEST_HOUSEKEEPING","shared authenticated callback handler");
      NCCheck(before==callback.Root() && da.event_sha256==db.event_sha256 && sa==sb &&
              a.BoundaryCount()==1 && callback.BoundaryCount()==1,
              "callback and no-callback exact financial/root/sidecar equivalence");
      life.housekeeping_proven=false;
      NCCheck(!KingEAHandleNativeCostDeal(ambiguous,b,f,life,outcome) && !ambiguous.Healthy(),
              "ambiguous OUT fails closed in production handler");
      f.time_msc=9500;
      NCCheck(KingEAHandleNativeCostDeal(normal,b,f,life,outcome) &&
              outcome=="NORMAL_PRE_END_EXIT_PENDING_PROJECTION","valid normal exit precedence");
      NCCheck(normal.MarkNormalClose(f.position_id,f.time_msc,true) && !NCProject(normal,dc,sc),
              "normal close projection excludes boundary close");
      life.housekeeping_proven=true;
      NCCheck(!KingEAHandleNativeCostDeal(callback,b,f,life,outcome),"duplicate callback fails closed");
     }
   KingEANativeCostEvidence pending;
   NCFixture(b,f,s);
   NCCheck(pending.Begin(b) && pending.ExpirePending(b.end_msc)=="PARTITION_END_PENDING_EXPIRY" &&
           pending.CostFactCount()==0 && pending.BoundaryCount()==0,"pending expiry has no fill or financial close");
   KingEANativeCostEvidence wrong;
   NCCheck(wrong.Begin(b),"wrong-context fixture ready"); f.binding=wrong.BindingHash(); b.configuration++;
   NCCheck(!KingEAHandleNativeCostDeal(wrong,b,f,life,outcome),"foreign configuration rejected before projection");
  }
#endif
