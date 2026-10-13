#ifndef KINGEA_NATIVE_COST_INTEGRATION_MQH
#define KINGEA_NATIVE_COST_INTEGRATION_MQH
#include "NativeCostEvidence.mqh"
// Explicit lifecycle evidence, not a timestamp-based guess. Native callers without
// independently authenticated lifecycle evidence leave housekeeping_proven=false.
struct KingEANativeLifecycleFacts
  {
   string observation_origin,proof_hash,sealed_boundary_hash;
   bool non_candidate,housekeeping_proven,no_normal_exit_pending;
  };
bool KingEAHandleNativeCostDeal(KingEANativeCostEvidence &ledger,
                               const KingEANativeCostBinding &context,
                               const KingEANativeDealFact &fact,
                               const KingEANativeLifecycleFacts &lifecycle,string &outcome)
  {
   outcome="FAIL_CLOSED";
   KingEANativeCostEvidence identity;
   if(!identity.Begin(context) || identity.BindingHash()!=ledger.BindingHash() ||
      (lifecycle.observation_origin!="NATIVE_TRANSACTION" &&
       !(lifecycle.observation_origin=="SYNTHETIC_INJECTED" && lifecycle.non_candidate)))
      return ledger.Reject("INTEGRATION_CONTEXT_UNPROVEN");
   if(fact.entry==DEAL_ENTRY_IN)
     {
      if(!ledger.CaptureEntry(fact)) return false;
      outcome="ENTRY_METADATA_CAPTURED"; return true;
     }
   if(!ledger.ValidateCloseFact(fact)) return ledger.Reject("NATIVE_CLOSE_IDENTITY_UNPROVEN");
   if(ledger.Finalized())
     {
      if(!lifecycle.housekeeping_proven || !lifecycle.no_normal_exit_pending ||
         lifecycle.sealed_boundary_hash!=ledger.BoundarySealHash() ||
         !ledger.Housekeeping(fact,lifecycle.proof_hash,true))
         return ledger.Reject("HOUSEKEEPING_ATTRIBUTION_AMBIGUOUS");
      outcome="STRATEGY_TESTER_END_OF_TEST_HOUSEKEEPING"; return true;
     }
   if(ledger.NormalClosed() || fact.time_msc>=context.end_msc)
      return ledger.Reject("NORMAL_CLOSE_ATTRIBUTION_UNPROVEN");
   outcome="NORMAL_PRE_END_EXIT_PENDING_PROJECTION";
   return true; // Normal accounting remains the existing financial path.
  }
#endif
