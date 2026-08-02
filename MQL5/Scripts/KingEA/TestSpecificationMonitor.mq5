#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Deterministic non-trading Stage 8 specification-monitor contract tests."

#include <KingEA/SpecificationMonitor.mqh>

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

string SafeStamp(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,".","-");
   return value;
  }

void WriteContractReport()
  {
   string relative="KingEA\\specification_monitor_contract_"+
                   SafeStamp(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS))+".csv";
   int handle=FileOpen(relative,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,
                       ',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      g_failures++;
      PrintFormat("FAIL: contract report FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"key","value");
   FileWrite(handle,"stage","8");
   FileWrite(handle,"scope","DETERMINISTIC_NON_PERFORMANCE_CONTRACT");
   FileWrite(handle,"result",(g_failures==0 ? "PASS" : "FAIL"));
   FileWrite(handle,"checks",IntegerToString(g_checks));
   FileWrite(handle,"failures",IntegerToString(g_failures));
   FileWrite(handle,"order_capability","PROHIBITED_AND_ABSENT");
   FileWrite(handle,"performance_authorization","DENIED");
   FileFlush(handle);
   FileClose(handle);
   PrintFormat("KingEA Stage 8 contract report: %s\\Files\\%s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH),relative);
  }

KingEASymbolSpecification Baseline()
  {
   KingEASymbolSpecification spec={};
   spec.valid=true;
   spec.symbol_id="ETHUSD.s";
   spec.description="Ethereum vs US Dollar";
   spec.path="Crypto\\ETHUSD.s";
   spec.currency_base="ETH";
   spec.currency_profit="USD";
   spec.currency_margin="USD";
   spec.digits=2;
   spec.point=0.01;
   spec.tick_size=0.01;
   spec.tick_value=0.01;
   spec.tick_value_profit=0.01;
   spec.tick_value_loss=0.01;
   spec.contract_size=1.0;
   spec.calc_mode=2;
   spec.execution_mode=2;
   spec.filling_mode=1;
   spec.order_mode=127;
   spec.expiration_mode=15;
   spec.trade_mode=4;
   spec.volume_min=0.01;
   spec.volume_max=100.0;
   spec.volume_step=0.01;
   spec.volume_limit=0.0;
   spec.stops_level=0;
   spec.freeze_level=0;
   spec.margin_initial=0.0;
   spec.margin_maintenance=0.0;
   spec.margin_hedged=0.0;
   spec.margin_rate_buy=0.002;
   spec.margin_rate_sell=0.002;
   spec.session_count=2;
   spec.sessions[0].from_second=300;
   spec.sessions[0].to_second=86400;
   spec.sessions[1].from_second=86700;
   spec.sessions[1].to_second=172800;
   return spec;
  }

KingEASpecificationRequest HealthyRequest()
  {
   KingEASpecificationRequest request={};
   request.event=KINGEA_SPEC_EVENT_PERIODIC;
   request.observed_at=(datetime)1785196800;
   request.expected_symbol="ETHUSD.s";
   request.expected_server_class="JustMarkets-Demo2";
   request.observed_server_class="JustMarkets-Demo2";
   request.connected=true;
   request.facts_fresh=true;
   request.tick_probe_available=true;
   request.tick_probe_reported=0.01;
   request.tick_probe_calculated=0.01;
   request.equity=1000.0;
   request.stressed_margin_level_percent=1000.0;
   request.stressed_free_margin_ratio=0.90;
   request.hmr_proxy_margin_per_lot=17.50;
   request.live_margin_per_lot=3.50;
   request.administrative_proof_complete=true;
   request.sessions_strategy_equivalent=true;
   request.exposure.known=true;
   request.exposure.has_position=false;
   request.exposure.protective_stop_confirmed=true;
   request.exposure.stop_valid=true;
   request.exposure.volume_valid=true;
   request.exposure.closure_available=true;
   request.exposure.reduction_feasible=true;
   return request;
  }

void OnStart()
  {
   KingEASymbolSpecification approved=Baseline();
   KingEASymbolSpecification observed=Baseline();
   KingEASpecificationRequest request=HealthyRequest();
   KingEASpecificationState prior={};
   KingEASpecificationState empty_state={};
   KingEASpecificationDecision decision={};

   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_UNCHANGED,
         "unchanged healthy specification is classified unchanged");
   Check(decision.entry_allowed,
         "unchanged healthy specification permits entry");

   // Harmless canonicalization and serialization noise.
   observed=Baseline();
   KingEASessionInterval temporary=observed.sessions[0];
   observed.sessions[0]=observed.sessions[1];
   observed.sessions[1]=temporary;
   observed.point+=1e-11;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_UNCHANGED,
         "session reordering and float serialization noise are unchanged");
   Check(decision.approved_hash==decision.observed_hash,
         "canonical hash ignores equivalent session ordering");
   approved=Baseline();
   approved.sessions[1]=approved.sessions[0];
   observed=approved;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_INVALID_OR_STALE,
         "duplicate approved session interval fails closed");
   approved=Baseline();

   // Expected tick-value movement requires the deterministic profit probe.
   observed=Baseline();
   observed.tick_value=0.02;
   observed.tick_value_profit=0.02;
   observed.tick_value_loss=0.02;
   request=HealthyRequest();
   request.tick_probe_reported=0.02;
   request.tick_probe_calculated=0.02;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_EXPECTED_DYNAMIC && decision.entry_allowed,
         "validated tick-value movement is expected dynamic");
   request.tick_probe_calculated=0.50;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED &&
         !decision.entry_allowed,
         "failed tick-value probe becomes risk-critical confirmation");

   // Confirmed HMR requires all calendar, envelope, and floor evidence.
   observed=Baseline();
   observed.margin_rate_buy=0.005;
   observed.margin_rate_sell=0.005;
   request=HealthyRequest();
   request.hmr_calendar_authoritative=true;
   request.hmr_active=true;
   request.live_margin_per_lot=17.50;
   request.hmr_proxy_margin_per_lot=17.50;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMED_HMR && decision.entry_allowed,
         "authoritative in-envelope HMR is accepted");
   request.hmr_calendar_authoritative=false;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED,
         "HMR label without authoritative calendar is not accepted");
   request=HealthyRequest();
   request.hmr_calendar_authoritative=true;
   request.hmr_active=true;
   request.live_margin_per_lot=18.0;
   request.hmr_proxy_margin_per_lot=17.5;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED,
         "out-of-envelope HMR is risk critical");
   observed=Baseline();
   observed.margin_rate_buy=0.001;
   observed.margin_rate_sell=0.001;
   request=HealthyRequest();
   request.hmr_calendar_authoritative=true;
   request.hmr_active=true;
   request.live_margin_per_lot=2.0;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED,
         "loosened margin terms cannot be classified as HMR");

   // Administrative changes preserve tier only with complete proof.
   observed=Baseline();
   observed.path="Crypto\\Pro\\ETHUSD.s";
   request=HealthyRequest();
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_ADMINISTRATIVE_CHANGE &&
         decision.preserve_earned_tier && !decision.reset_to_bottom_tier,
         "proved administrative change preserves earned tier");
   request.administrative_proof_complete=false;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED,
         "unproved administrative change promotes to risk critical");

   observed=Baseline();
   observed.sessions[1].from_second+=3600;
   observed.sessions[1].to_second+=3600;
   request=HealthyRequest();
   request.sessions_strategy_equivalent=true;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_ADMINISTRATIVE_CHANGE,
         "proved strategy-equivalent session change is administrative");
   request.sessions_strategy_equivalent=false;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED,
         "effective session change is risk critical");

   observed=Baseline();
   observed.trade_mode=2;
   request=HealthyRequest();
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_TEMPORARY_RESTRICTION &&
         !decision.entry_allowed && !decision.reset_to_bottom_tier,
         "temporary trade restriction blocks without baseline reset");

   // Risk-critical changes require a matching independent second capture.
   observed=Baseline();
   observed.contract_size=2.0;
   request=HealthyRequest();
   prior=empty_state;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_CONFIRMATION_REQUIRED &&
         decision.next_state.awaiting_second_capture,
         "first risk change waits for second capture");
   prior=decision.next_state;
   request.event=KINGEA_SPEC_EVENT_SECOND_CAPTURE;
   request.observed_at+=2;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_RISK_CRITICAL_CHANGE &&
         decision.reset_to_bottom_tier && decision.revalidation_required,
         "matching second capture confirms risk change and bottom-tier reset");

   // Different changed states are unstable and never selected arbitrarily.
   observed=Baseline();
   observed.point=0.02;
   request=HealthyRequest();
   prior=empty_state;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   prior=decision.next_state;
   observed=Baseline();
   observed.contract_size=2.0;
   request.event=KINGEA_SPEC_EVENT_SECOND_CAPTURE;
   request.observed_at+=2;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_UNSTABLE_CAPTURE &&
         decision.action==KINGEA_SPEC_ACTION_QUARANTINE,
         "disagreeing changed captures quarantine as unstable");

   // A transient needs a genuinely scheduled, time-separated third capture.
   observed=Baseline();
   observed.point=0.02;
   request=HealthyRequest();
   prior=empty_state;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   prior=decision.next_state;
   observed=Baseline();
   request.event=KINGEA_SPEC_EVENT_SECOND_CAPTURE;
   request.observed_at+=2;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_TRANSIENT_CONFIRMATION &&
         decision.next_state.transient_confirmation_pending,
         "baseline second capture starts scheduled transient confirmation");
   prior=decision.next_state;
   request.event=KINGEA_SPEC_EVENT_SECOND_CAPTURE;
   request.observed_at+=2;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(!decision.entry_allowed &&
         decision.reason=="SCHEDULED_CONFIRMATION_REQUIRED",
         "immediate third read cannot clear transient");
   prior=decision.next_state;
   request.event=KINGEA_SPEC_EVENT_PERIODIC;
   request.observed_at=prior.scheduled_confirmation_not_before;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.entry_allowed && !decision.next_state.transient_confirmation_pending,
         "on-time scheduled sixty-second baseline poll clears transient");

   prior.transient_confirmation_pending=true;
   prior.scheduled_confirmation_not_before=request.observed_at+60;
   observed.valid=false;
   request.observed_at=prior.scheduled_confirmation_not_before;
   KingEAEvaluateSpecification(approved,observed,request,prior,decision);
   Check(decision.classification==KINGEA_SPEC_INVALID_OR_STALE &&
         decision.next_state.scheduled_confirmation_not_before==request.observed_at+60,
         "invalid scheduled poll restarts sixty-second requirement");

   // Immediate proven exposure risk overrides the two-capture delay.
   observed=Baseline();
   observed.volume_step=0.10;
   request=HealthyRequest();
   request.immediate_risk_breach=true;
   request.exposure.has_position=true;
   request.exposure.stop_valid=false;
   KingEAEvaluateSpecification(approved,observed,request,
                               empty_state,decision);
   Check(decision.classification==KINGEA_SPEC_RISK_CRITICAL_CHANGE &&
         decision.action==KINGEA_SPEC_ACTION_REDUCE,
         "immediate invalid exposure emits feasible reduction");
   request.exposure.reduction_feasible=false;
   KingEAEvaluateSpecification(approved,observed,request,
                               empty_state,decision);
   Check(decision.action==KINGEA_SPEC_ACTION_FLATTEN,
         "infeasible reduction emits flatten");
   request.exposure.closure_available=false;
   KingEAEvaluateSpecification(approved,observed,request,
                               empty_state,decision);
   Check(decision.action==KINGEA_SPEC_ACTION_QUARANTINE,
         "unknown closure capability overrides flatten");

   request=HealthyRequest();
   request.connected=false;
   observed=Baseline();
   KingEAEvaluateSpecification(approved,observed,request,
                               empty_state,decision);
   Check(decision.classification==KINGEA_SPEC_INVALID_OR_STALE &&
         !decision.entry_allowed,
         "disconnected facts fail closed");

   WriteContractReport();
   PrintFormat("KINGEA_STAGE8_TEST_RESULT=%s; checks=%d; failures=%d; order_capability=PROHIBITED_AND_ABSENT",
               (g_failures==0 ? "PASS" : "FAIL"),g_checks,g_failures);
  }
