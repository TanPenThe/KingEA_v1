#ifndef KINGEA_ZERO_ENTRY_DIAGNOSTIC_MQH
#define KINGEA_ZERO_ENTRY_DIAGNOSTIC_MQH

// Pure, non-order funnel accounting for the governed Gate 1 zero-entry diagnostic.
#define KINGEA_ZERO_ENTRY_REASON_CAPACITY 64

enum KingEAZeroEntryStage
  {
   KINGEA_ZERO_ENTRY_STAGE_NONE=0,
   KINGEA_ZERO_ENTRY_STAGE_CLOSED_BARS=1,
   KINGEA_ZERO_ENTRY_STAGE_REGIME_HEALTH=2,
   KINGEA_ZERO_ENTRY_STAGE_REGIME_ELIGIBLE=3,
   KINGEA_ZERO_ENTRY_STAGE_SLEEVE_HEALTH=4,
   KINGEA_ZERO_ENTRY_STAGE_BREAKOUT_INTENT=5,
   KINGEA_ZERO_ENTRY_STAGE_SAFETY_APPROVAL=6,
   KINGEA_ZERO_ENTRY_STAGE_VIRTUAL_FILL=7,
   KINGEA_ZERO_ENTRY_STAGE_ACCOUNTING=8
  };

struct KingEAZeroEntryFunnel
  {
   long closed_bars;
   long regime_healthy;
   long regime_entry_eligible;
   long sleeve_healthy;
   long breakout_intents;
   long safety_approvals;
   long safety_rejections;
   long virtual_order_attempts;
   long virtual_fills;
   long virtual_execution_failures;
   long accounting_completions;
   long native_order_calls;
   long regime_reason_counts[KINGEA_ZERO_ENTRY_REASON_CAPACITY];
   long sleeve_reason_counts[KINGEA_ZERO_ENTRY_REASON_CAPACITY];
   long safety_reason_counts[KINGEA_ZERO_ENTRY_REASON_CAPACITY];
  };

void KingEAZeroEntryReset(KingEAZeroEntryFunnel &funnel)
  {
   ZeroMemory(funnel);
  }

void KingEAZeroEntryCountReason(long &counts[],const int reason)
  {
   if(reason>=0 && reason<ArraySize(counts))
      counts[reason]++;
  }

void KingEAZeroEntryCountClosedBar(KingEAZeroEntryFunnel &funnel)
  {
   funnel.closed_bars++;
  }

void KingEAZeroEntryCountRegime(KingEAZeroEntryFunnel &funnel,
                                const bool healthy,
                                const bool entry_eligible,
                                const int reason)
  {
   KingEAZeroEntryCountReason(funnel.regime_reason_counts,reason);
   if(healthy)
      funnel.regime_healthy++;
   if(healthy && entry_eligible)
      funnel.regime_entry_eligible++;
  }

void KingEAZeroEntryCountSleeve(KingEAZeroEntryFunnel &funnel,
                                const bool healthy,
                                const bool entry_intent,
                                const int reason)
  {
   KingEAZeroEntryCountReason(funnel.sleeve_reason_counts,reason);
   if(healthy)
      funnel.sleeve_healthy++;
   if(entry_intent)
      funnel.breakout_intents++;
  }

void KingEAZeroEntryCountSafety(KingEAZeroEntryFunnel &funnel,
                                const bool approved,
                                const int reason)
  {
   KingEAZeroEntryCountReason(funnel.safety_reason_counts,reason);
   if(approved)
      funnel.safety_approvals++;
   else
      funnel.safety_rejections++;
  }

void KingEAZeroEntryCountVirtualAttempt(KingEAZeroEntryFunnel &funnel,
                                        const bool filled)
  {
   funnel.virtual_order_attempts++;
   if(filled)
      funnel.virtual_fills++;
   else
      funnel.virtual_execution_failures++;
  }

void KingEAZeroEntryCountAccounting(KingEAZeroEntryFunnel &funnel,
                                    const bool completed)
  {
   if(completed)
      funnel.accounting_completions++;
  }

int KingEAZeroEntryFirstZeroStage(const KingEAZeroEntryFunnel &funnel)
  {
   if(funnel.closed_bars<=0)
      return KINGEA_ZERO_ENTRY_STAGE_CLOSED_BARS;
   if(funnel.regime_healthy<=0)
      return KINGEA_ZERO_ENTRY_STAGE_REGIME_HEALTH;
   if(funnel.regime_entry_eligible<=0)
      return KINGEA_ZERO_ENTRY_STAGE_REGIME_ELIGIBLE;
   if(funnel.sleeve_healthy<=0)
      return KINGEA_ZERO_ENTRY_STAGE_SLEEVE_HEALTH;
   if(funnel.breakout_intents<=0)
      return KINGEA_ZERO_ENTRY_STAGE_BREAKOUT_INTENT;
   if(funnel.safety_approvals<=0)
      return KINGEA_ZERO_ENTRY_STAGE_SAFETY_APPROVAL;
   if(funnel.virtual_fills<=0)
      return KINGEA_ZERO_ENTRY_STAGE_VIRTUAL_FILL;
   if(funnel.accounting_completions<=0)
      return KINGEA_ZERO_ENTRY_STAGE_ACCOUNTING;
   return KINGEA_ZERO_ENTRY_STAGE_NONE;
  }

bool KingEAZeroEntryFunnelComplete(const KingEAZeroEntryFunnel &funnel)
  {
   return KingEAZeroEntryFirstZeroStage(funnel)==KINGEA_ZERO_ENTRY_STAGE_NONE &&
          funnel.native_order_calls==0;
  }

string KingEAZeroEntryReasonSummary(const long &counts[])
  {
   string result="";
   for(int i=0;i<ArraySize(counts);i++)
     {
      if(counts[i]<=0)
         continue;
      result+=(result=="" ? "" : ";")+IntegerToString(i)+":"+(string)counts[i];
     }
   return (result=="" ? "NONE" : result);
  }

string KingEAZeroEntryPayload(const KingEAZeroEntryFunnel &funnel,
                              const string source,
                              const int configuration_id)
  {
   return StringFormat(
      "schema=1|kind=GATE1_ZERO_ENTRY_DIAGNOSTIC|source=%s|config=%d|closed_bars=%I64d|regime_healthy=%I64d|regime_entry_eligible=%I64d|sleeve_healthy=%I64d|breakout_intents=%I64d|safety_approvals=%I64d|safety_rejections=%I64d|virtual_order_attempts=%I64d|virtual_fills=%I64d|virtual_execution_failures=%I64d|accounting_completions=%I64d|native_order_calls=%I64d|first_zero_stage=%d|regime_reasons=%s|sleeve_reasons=%s|safety_reasons=%s|returns=ABSENT|complete=1",
      source,configuration_id,funnel.closed_bars,funnel.regime_healthy,
      funnel.regime_entry_eligible,funnel.sleeve_healthy,
      funnel.breakout_intents,funnel.safety_approvals,funnel.safety_rejections,
      funnel.virtual_order_attempts,funnel.virtual_fills,
      funnel.virtual_execution_failures,funnel.accounting_completions,
      funnel.native_order_calls,KingEAZeroEntryFirstZeroStage(funnel),
      KingEAZeroEntryReasonSummary(funnel.regime_reason_counts),
      KingEAZeroEntryReasonSummary(funnel.sleeve_reason_counts),
      KingEAZeroEntryReasonSummary(funnel.safety_reason_counts));
  }

#endif
