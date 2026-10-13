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
  }
#endif
