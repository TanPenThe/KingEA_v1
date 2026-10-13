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
string KingEANativeEvidenceQuote(string value)
  {
   StringReplace(value,"\\","\\\\"); StringReplace(value,"\"","\\\"");
   StringReplace(value,"\n","\\n"); StringReplace(value,"\r","\\r");
   return "\""+value+"\"";
  }
string KingEANativeBoundaryPackage(KingEANativeCostEvidence &ledger,
                                   const KingEAAccountingEvent &event,
                                   const KingEAAccountingDecision &decision,
                                   const string prior_root,const string sidecar)
  {
   if(!ledger.Healthy() || !ledger.Finalized() || ledger.BoundaryCount()!=1 || !decision.accepted ||
      StringFind(sidecar,"|sha256="+ledger.BoundarySealHash())<0) return "";
   KingEANativeCostBinding b=ledger.Binding(); string previous=prior_root;
   if(previous=="") StringInit(previous,64,'0');
   string payload="{\"schema\":\"NATIVE_COST_BOUNDARY_PACKAGE_V1\",\"run\":"+KingEANativeEvidenceQuote(b.run)+
      ",\"configuration\":"+(string)b.configuration+",\"branch\":"+KingEANativeEvidenceQuote(b.branch)+
      ",\"partition\":"+KingEANativeEvidenceQuote(b.partition)+",\"group\":"+KingEANativeEvidenceQuote(b.group)+
      ",\"boundary_finalization_count\":1,\"candidate_exit_count_delta\":0,\"records\":[";
   for(int i=0;i<ledger.RecordCount();i++)
      payload+=(i==0 ? "" : ",")+KingEANativeEvidenceQuote(ledger.Record(i));
   payload+="],\"sidecar\":"+KingEANativeEvidenceQuote(sidecar)+
      ",\"stage13_frame\":"+KingEANativeEvidenceQuote(KingEAAccountingFramePayload(event,decision))+
      ",\"stage13_canonical\":"+KingEANativeEvidenceQuote(KingEAAccountingCanonical(event,decision.sequence,previous))+"}";
   return payload+"|sha256="+KingEAAccountingSha256(payload);
  }
#endif
