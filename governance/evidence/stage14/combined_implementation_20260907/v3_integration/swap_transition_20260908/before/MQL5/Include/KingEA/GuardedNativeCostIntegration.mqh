// Included only by GuardedResearchTester after its existing implementation.
// No extra order seam, no new Candidate rule, and no history enumeration.
#include "NativeCostIntegration.mqh"
bool ResearchNativePersist(const string name,const string value)
  {
   string file="KingEA\\stage14_spool\\"+InpManifestSha256+"\\NATIVE_COST_"+
      (string)InpConfigurationId+"_"+name+".evidence";
   if(FileIsExist(file,FILE_COMMON))
     {
      int r=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(r==INVALID_HANDLE) return false;
      string old=FileReadString(r); FileClose(r); return old==value;
     }
   int h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return false;
   bool ok=FileWriteString(h,value)==StringLen(value); FileClose(h); return ok;
  }
bool ResearchNativePersistLedger()
  {
   if(g_native_cost==NULL) return false;
   string prefix=StringSubstr(g_native_cost.BindingHash(),0,24);
   for(int i=0;i<g_native_cost.RecordCount();i++)
      if(!ResearchNativePersist(prefix+"_"+(string)i,g_native_cost.Record(i))) return false;
   return true;
  }
bool ResearchNativeBegin(const string group,const int side,const double volume,const long now)
  {
   if(g_native_cost!=NULL)
     {
      if(!g_native_cost.NormalClosed() || !ResearchNativePersistLedger()) { g_hard_failures++; return false; }
      delete g_native_cost; g_native_cost=NULL;
     }
   g_native_cost=new KingEANativeCostEvidence;
   KingEANativeCostBinding b={}; b.run=InpManifestSha256; b.configuration=InpConfigurationId;
   b.branch=InpBranch; b.partition=InpPartition; b.group=group; b.symbol=_Symbol;
   b.magic=12001; b.side=side; b.volume=volume;
   b.start_msc=(long)g_evaluation_start*1000; b.end_msc=(long)g_evaluation_end_exclusive*1000;
   g_native_start_msc=now; g_native_entry_captured=false; g_native_receipt_known=false;
   g_native_exit_pending=false; ZeroMemory(g_native_close_fact);
   if(!g_native_cost.Begin(b)) { g_hard_failures++; return false; }
   return true;
  }
void ResearchNativeReceipt(const MqlTradeResult &receipt)
  {
   g_native_receipt=receipt; g_native_receipt_known=true;
   if(receipt.retcode!=TRADE_RETCODE_DONE || receipt.deal==0 || receipt.order==0 || receipt.price<=0)
      g_hard_failures++;
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(ResearchUsesVirtual() || !g_initialized || !g_manifest_valid || trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(g_native_cost==NULL) { g_hard_failures++; return; }
   KingEANativeDealFact d={};
   if(!KingEAReadCurrentRunDeal(trans,true,g_native_cost.BindingHash(),d) || d.time_msc<g_native_start_msc)
     { g_hard_failures++; return; }
   KingEANativeLifecycleFacts lifecycle={}; lifecycle.observation_origin="NATIVE_TRANSACTION";
   // No native lifecycle proof is invented here. Ambiguous OUT remains fail-closed.
   string outcome; KingEANativeCostBinding context=g_native_cost.Binding();
   if(!KingEAHandleNativeCostDeal(g_native_cost,context,d,lifecycle,outcome))
     {
      g_hard_failures++;
      ResearchNativePersist("REJECTED_NATIVE_EVENT_"+(string)d.deal,"FAIL_CLOSED|"+g_native_cost.BindingHash());
      return;
     }
   if(outcome=="ENTRY_METADATA_CAPTURED")
     {
      g_native_entry_captured=true;
      return;
     }
   if(outcome=="STRATEGY_TESTER_END_OF_TEST_HOUSEKEEPING")
     {
      ResearchNativePersist("HOUSEKEEPING_"+(string)d.deal,g_native_cost.HousekeepingEvidence());
      return;
     }
   if(outcome!="NORMAL_PRE_END_EXIT_PENDING_PROJECTION" || !g_native_entry_captured || g_native_exit_pending)
     { g_hard_failures++; return; }
   // Normal native close facts are kept outside the entry-cost ledger.
   g_native_close_fact=d; g_native_exit_pending=true;
  }
void ResearchNativeSeal(const MqlTick &tick)
  {
   if(ResearchUsesVirtual() || InpZeroEntryDiagnostic || !ResearchEvaluationEligible(tick.time)) return;
   g_native_last_eligible_tick=tick.time_msc;
   if(!g_position.has_position || g_native_cost==NULL || g_native_exit_pending) return;
   if(!g_native_entry_captured || !g_native_receipt_known) return; // Cannot backfill this tick later.
   if(!g_native_cost.ReconcileReceipt(g_native_receipt.deal,g_native_receipt.order,
                                      g_native_receipt.volume,g_native_receipt.price) ||
      !KingEASealNativeEligibleQuote(g_native_cost,tick,_Symbol,(long)g_evaluation_start*1000,
         (long)g_evaluation_end_exclusive*1000,InpResearchSpecificationSha256))
      g_hard_failures++;
  }
bool ResearchNativeNormalCloseReady()
  {
   if(g_native_boundary_projected || g_native_cost==NULL || !g_native_cost.Healthy()) { g_hard_failures++; return false; }
   if(!g_native_exit_pending) return false; // Await exact deal event; never infer close from equity.
   if(!ResearchEvaluationEligible(TimeCurrent())) { g_hard_failures++; return false; }
   g_close_deal_ticket=g_native_close_fact.deal; g_close_order_ticket=g_native_close_fact.order;
   return true;
  }
void ResearchNativeNormalCloseCommitted()
  {
   if(g_native_cost==NULL || !g_native_cost.MarkNormalClose(g_native_close_fact.position_id,
         g_native_close_fact.time_msc,true) || !ResearchNativePersistLedger()) g_hard_failures++;
  }
bool ResearchNativeBoundaryFinalize()
  {
   if(ResearchUsesVirtual() || InpZeroEntryDiagnostic || InpWorkloadDryRun) return false;
   if(g_native_boundary_projected) return g_hard_failures==0;
   if(!g_position.has_position && g_trade_group_id=="") return false;
   if(g_hard_failures!=0 || g_native_cost==NULL || !g_native_cost.Healthy() ||
      g_native_exit_pending || g_virtual_pending || OrdersTotal()!=0 ||
      g_native_cost.SealedTime()!=g_native_last_eligible_tick)
      return false;
   // At a post-end tick, still-open identity must reconcile. At OnTester, a no-callback
   // terminal close can only use the full snapshot from the last processed eligible tick.
   if(!g_native_in_tester_end && (!PositionSelect(_Symbol) ||
       (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=g_native_cost.PositionId())) return false;
   KingEAAccountingEvent base={}; base.schema_version=1;
   base.event_id="BOUNDARY-"+KingEAAccountingSha256(g_trade_group_id); base.trade_group_id=g_trade_group_id; base.symbol=_Symbol;
   base.server_time_msc=g_native_cost.SealedTime(); base.utc_time_msc=base.server_time_msc;
   base.account_fingerprint=g_account_fingerprint; base.deployment_id="KINGEA-TESTER-STAGE13";
   base.candidate_id="CAND-ETH-ST-001"; base.sleeve_id="SLEEVE-1";
   base.configuration_hash="A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE";
   base.mae_r=g_trade_mae_r; base.mfe_r=g_trade_mfe_r; base.bars_held=g_trade_bars_held;
   base.protective_stop=g_position.original_confirmed_stop;
   KingEAAccountingEvent event={}; KingEAAccountingDecision decision={};
   if(!g_native_cost.Finalize(base,g_accounting_checkpoint,g_entry_equity,g_entry_risk_money,false,
                             event,decision,g_native_sidecar)) { g_hard_failures++; return false; }
   if(!ResearchNativePersistLedger() || !ResearchNativePersist("BOUNDARY_"+StringSubstr(g_native_cost.BindingHash(),0,24),g_native_sidecar))
      { g_hard_failures++; return false; }
   string package=KingEANativeBoundaryPackage(g_native_cost,event,decision,
                                             g_accounting_checkpoint.ledger_root_sha256,g_native_sidecar);
   if(package=="" || !ResearchNativePersist("PACKAGE_"+StringSubstr(g_native_cost.BindingHash(),0,24),package))
      { g_hard_failures++; return false; }
   uchar package_frame[]; int package_bytes=StringToCharArray(package,package_frame,0,WHOLE_ARRAY,CP_UTF8);
   if(package_bytes>0) ArrayResize(package_frame,package_bytes-1);
   if(package_bytes<=0 || !FrameAdd("KINGEA_NATIVE_COST_PACKAGE",InpConfigurationId,0.0,package_frame))
      { g_hard_failures++; return false; }
   int n=ArraySize(g_accounting_payloads); ArrayResize(g_accounting_payloads,n+1);
   g_accounting_payloads[n]=KingEAAccountingFramePayload(event,decision);
   g_accounting_checkpoint=decision.next_checkpoint; g_accounting_close_count++;
   int count=ArraySize(g_trade_net); ArrayResize(g_trade_net,count+1);
   ArrayResize(g_trade_returns,count+1); ArrayResize(g_trade_r,count+1);
   g_trade_net[count]=decision.event_net_pnl; g_trade_returns[count]=event.net_return; g_trade_r[count]=event.net_r;
   g_native_boundary_equity=event.account_equity; g_native_boundary_projected=true; g_boundary_finalization_count++;
   // Candidate exit count is intentionally untouched.
   ZeroMemory(g_position); g_trade_group_id="";
   return true;
  }
