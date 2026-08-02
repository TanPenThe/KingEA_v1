#property copyright "KingEA"
#property version   "1.00"
#property description "Deterministic non-performance contract tests for the pure KingEA safety kernel."
#property description "No history, indicators, orders, returns, optimization, OOS, or holdout access."
#property description "Build ID: KINGEA-SAFETY-KERNEL-TEST-20260726-A."

#include <KingEA/SafetyKernel.mqh>

int g_failures=0;
int g_checks=0;

void Check(const bool condition,const string label)
  {
   g_checks++;
   if(condition) return;
   g_failures++;
   PrintFormat("SAFETY_KERNEL_TEST_FAIL: %s",label);
  }

KingEASafetyRequest ValidEntryRequest()
  {
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_ENTRY;
   request.direction=KINGEA_SAFETY_LONG;
   request.entry_price=2000.0;
   request.technical_stop=1950.0;
   request.signal_present=true;
   return request;
  }

KingEASafetyFacts HealthyFacts()
  {
   KingEASafetyFacts facts={};
   facts.now_server=D'2026.07.27 12:00:00';
   facts.account_equity=1000.0;
   facts.account_day_open_equity=1000.0;
   facts.account_week_open_equity=1000.0;
   facts.account_month_open_equity=1000.0;
   facts.account_equity_high=1000.0;
   facts.sleeve_equity=1000.0;
   facts.sleeve_week_open_equity=1000.0;
   facts.sleeve_month_open_equity=1000.0;
   facts.sleeve_equity_high=1000.0;
   facts.sleeve_tier_percent=0.25;
   facts.cluster_existing_risk=0.0;
   facts.portfolio_existing_risk=0.0;
   facts.cluster_known=true;
   facts.volume_min=0.01;
   facts.volume_max=100.0;
   facts.volume_step=0.01;
   facts.stressed_loss_per_lot=50.0;
   facts.live_margin_per_lot=4.0;
   facts.notional_per_lot=2000.0;
   facts.current_used_margin=0.0;
   facts.spread_ratio=1.0;
   facts.stop_valid=true;
   facts.state_valid=true;
   facts.configuration_valid=true;
   facts.exposure_reconciled=true;
   facts.stops_confirmed=true;
   facts.connection_healthy=true;
   facts.specification_healthy=true;
   facts.calendar_fresh=true;
   facts.market_open=true;
   facts.external_cash_flow_reconciled=true;
   return facts;
  }

void TestBreakerPrecedence()
  {
   KingEASafetyRequest request=ValidEntryRequest();
   KingEASafetyFacts facts=HealthyFacts();
   KingEASafetyState prior={};
   KingEASafetyDecision decision={};

   facts.account_equity=970.0;
   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.action==KINGEA_ACTION_FLATTEN &&
         decision.reason==KINGEA_REASON_DAILY_BREAKER,
         "three-percent daily breaker flattens and cancels");
   Check(decision.next_state.daily_paused && decision.cancel_pending,
         "daily breaker persists its pause");

   facts=HealthyFacts();
   facts.account_equity=940.0;
   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.reason==KINGEA_REASON_WEEKLY_BREAKER &&
         decision.next_state.account_weekly_paused,
         "six-percent account weekly breaker is independent");

   facts=HealthyFacts();
   facts.account_equity=790.0;
   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.reason==KINGEA_REASON_PERMANENT_BREAKER &&
         decision.next_state.account_permanent_halt,
         "all-time breaker outranks monthly and weekly breakers");

   facts=HealthyFacts();
   facts.account_equity=940.0;
   prior.account_recovery.weekly_breaker_1=D'2026.05.20 12:00:00';
   prior.account_recovery.weekly_breaker_2=D'2026.06.20 12:00:00';
   prior.account_recovery.weekly_breaker_count=2;
   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.reason==KINGEA_REASON_CUMULATIVE_REVIEW &&
         decision.next_state.account_recovery.weekly_breaker_count==3 &&
         decision.next_state.account_recovery.manual_review_latched,
         "third weekly breaker in ninety days latches cumulative review");
  }

void TestRecoveryStateMachine()
  {
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_PERIOD_TRANSITION;
   request.new_broker_day=true;
   request.new_broker_week=true;
   KingEASafetyFacts facts=HealthyFacts();
   KingEASafetyState state={};
   state.account_weekly_paused=true;
   KingEASafetyDecision decision={};

   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.account_recovery.active &&
         state.account_recovery.clean_days==0,
         "weekly boundary starts half-risk recovery without free clean-day credit");

   request.new_broker_week=false;
   for(int day=0;day<4;day++)
     {
      KingEAEvaluateSafety(request,facts,state,decision);
      state=decision.next_state;
     }
   Check(state.account_recovery.active &&
         state.account_recovery.clean_days==4,
         "four clean broker days do not restore risk");
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(!state.account_recovery.active &&
         state.account_recovery.clean_days==0,
         "fifth consecutive clean broker day completes recovery");

   ZeroMemory(state);
   state.account_recovery.active=true;
   state.account_recovery.clean_days=3;
   state.full_losses_today=1;
   ZeroMemory(request);
   request.event=KINGEA_EVENT_CLOSED_TRADE_GROUP;
   request.closed_group_full_loss=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.account_recovery.clean_days==0 &&
         state.account_recovery.throttle_events==1 &&
         !state.account_recovery.manual_review_latched,
         "first recovery throttle resets the clean-day streak");

   state.full_losses_today=1;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(decision.action==KINGEA_ACTION_FLATTEN &&
         state.account_recovery.manual_review_latched &&
         state.account_recovery.force_bottom_tier,
         "second recovery throttle latches review and bottom-tier restart");

   ZeroMemory(request);
   request.event=KINGEA_EVENT_CUMULATIVE_REVIEW_APPROVED;
   request.scope=KINGEA_SCOPE_ACCOUNT;
   state.account_recovery.weekly_breaker_1=D'2026.05.20 12:00:00';
   state.account_recovery.weekly_breaker_2=D'2026.06.20 12:00:00';
   state.account_recovery.weekly_breaker_3=D'2026.07.20 12:00:00';
   state.account_recovery.weekly_breaker_count=3;
   long old_epoch=state.account_recovery.escalation_epoch;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.account_recovery.weekly_breaker_count==0 &&
         state.account_recovery.escalation_epoch==old_epoch+1 &&
         state.account_recovery.active,
         "successful cumulative review archives events and starts a fresh epoch");

   request=ValidEntryRequest();
   facts=HealthyFacts();
   facts.account_equity=940.0;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.next_state.account_recovery.weekly_breaker_count==1,
         "post-review weekly breaker counting restarts from zero");
  }

void TestCapsGatesAndPositionProtection()
  {
   KingEASafetyRequest request=ValidEntryRequest();
   KingEASafetyFacts facts=HealthyFacts();
   KingEASafetyState state={};
   KingEASafetyDecision decision={};

   facts.cluster_existing_risk=-5.0;
   facts.portfolio_existing_risk=-10.0;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(MathAbs(decision.permitted_volume-0.05)<1e-9,
         "protected profit receives zero risk credit");

   facts=HealthyFacts();
   facts.cluster_known=false;
   facts.portfolio_existing_risk=14.5;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_DOWNSIZE_ENTRY &&
         MathAbs(decision.permitted_volume-0.01)<1e-9,
         "missing cluster data defaults all portfolio exposure to correlated");

   facts=HealthyFacts();
   state.account_recovery.active=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_DOWNSIZE_ENTRY &&
         MathAbs(decision.permitted_volume-0.02)<1e-9,
         "active weekly recovery halves the earned risk tier");

   ZeroMemory(state);
   facts=HealthyFacts();
   facts.stressed_loss_per_lot=1000.0;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_REJECT_SIGNAL &&
         decision.reason==KINGEA_REASON_MINIMUM_VOLUME,
         "minimum volume is rejected when stop risk exceeds capacity");

   facts=HealthyFacts();
   facts.unknown_exposure=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_QUARANTINE &&
         decision.reason==KINGEA_REASON_UNKNOWN_EXPOSURE,
         "unknown account exposure quarantines new entries");

   facts=HealthyFacts();
   facts.spread_ratio=2.01;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_REJECT_SIGNAL,
         "spread above two times median blocks entry");

   ZeroMemory(request);
   request.event=KINGEA_EVENT_POSITION_REVIEW;
   request.position_present=true;
   request.direction=KINGEA_SAFETY_LONG;
   request.position_volume=0.10;
   request.current_stop=1950.0;
   request.proposed_stop=1940.0;
   facts=HealthyFacts();
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_NONE &&
         decision.reason==KINGEA_REASON_STOP_INVARIANT &&
         decision.required_stop==1950.0,
         "long stop widening is rejected against the confirmed stop");

   request.manual_stop_change=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_QUARANTINE &&
         decision.restore_confirmed_stop &&
         decision.required_stop==1950.0,
         "manual stop widening requests restoration and quarantine");

   request.manual_stop_change=false;
   request.protective_stop_failed=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_FLATTEN &&
         decision.quarantine,
         "failed broker-side stop requests flatten and quarantine");

   request.protective_stop_failed=false;
   facts=HealthyFacts();
   facts.spread_ratio=2.6;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_REDUCE_POSITION &&
         decision.reduction_fraction==0.50 &&
         MathAbs(decision.permitted_volume-0.05)<1e-9,
         "spread above two-and-a-half times requests fixed reduction");

   request.position_volume=0.01;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_FLATTEN,
         "infeasible minimum-volume reduction falls back to flatten");
   request.position_volume=0.10;

   facts.spread_above_three_persistent=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_FLATTEN &&
         decision.reason==KINGEA_REASON_SPREAD_FLATTEN,
         "persistent three-times spread outranks reduction");

   facts=HealthyFacts();
   facts.news_block=true;
   facts.existing_news_position_safe=false;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_FLATTEN,
         "unprotected news exposure is flattened");
   facts.existing_news_position_safe=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_NONE,
         "profit-protected news exposure may remain");
  }

void TestFailClosedFactsAndHealthMemory()
  {
   KingEASafetyRequest request=ValidEntryRequest();
   KingEASafetyFacts facts=HealthyFacts();
   KingEASafetyState state={};
   KingEASafetyDecision decision={};

   facts.spread_ratio=MathSqrt(-1.0);
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_QUARANTINE &&
         decision.reason==KINGEA_REASON_INVALID_INPUT,
         "non-finite safety facts fail closed before breaker math");

   facts=HealthyFacts();
   state.account_recovery.active=true;
   state.account_recovery.clean_days=3;
   facts.connection_healthy=false;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.account_recovery.day_health_failed,
         "intraday health failure is remembered through recovery");

   facts=HealthyFacts();
   ZeroMemory(request);
   request.event=KINGEA_EVENT_PERIOD_TRANSITION;
   request.new_broker_day=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.next_state.account_recovery.clean_days==0,
         "remembered intraday failure resets the clean-day streak");

   request=ValidEntryRequest();
   facts=HealthyFacts();
   ZeroMemory(state);
   state.account_recovery.weekly_breaker_count=1;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_QUARANTINE &&
         decision.reason==KINGEA_REASON_INVALID_INPUT,
         "inconsistent recovered state fails closed");
  }

void TestSleeveRecoveryAndReview()
  {
   KingEASafetyRequest request=ValidEntryRequest();
   KingEASafetyFacts facts=HealthyFacts();
   KingEASafetyState state={};
   KingEASafetyDecision decision={};

   facts.sleeve_equity=960.0;
   state.sleeve_recovery.weekly_breaker_1=D'2026.05.20 12:00:00';
   state.sleeve_recovery.weekly_breaker_2=D'2026.06.20 12:00:00';
   state.sleeve_recovery.weekly_breaker_count=2;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.next_state.sleeve_recovery.weekly_breaker_count==3 &&
         decision.next_state.sleeve_recovery.manual_review_latched &&
         !decision.next_state.account_recovery.manual_review_latched,
         "sleeve cumulative review is isolated from account recovery");

   state=decision.next_state;
   ZeroMemory(request);
   request.event=KINGEA_EVENT_CUMULATIVE_REVIEW_APPROVED;
   request.scope=KINGEA_SCOPE_SLEEVE;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.sleeve_recovery.weekly_breaker_count==0 &&
         state.sleeve_recovery.active,
         "successful sleeve review starts a fresh sleeve epoch");

   state.sleeve_recovery.active=true;
   state.sleeve_recovery.throttle_events=1;
   state.full_losses_today=1;
   ZeroMemory(request);
   request.event=KINGEA_EVENT_CLOSED_TRADE_GROUP;
   request.closed_group_full_loss=true;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.sleeve_recovery.manual_review_latched &&
         !state.account_recovery.manual_review_latched,
         "second sleeve recovery throttle halts only that sleeve");

   ZeroMemory(request);
   request.event=KINGEA_EVENT_MANUAL_REVIEW_APPROVED;
   request.scope=KINGEA_SCOPE_SLEEVE;
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.sleeve_recovery.force_bottom_tier &&
         !state.sleeve_recovery.manual_review_latched,
         "approved severe sleeve review restarts at bottom tier");

   ZeroMemory(request);
   request.event=KINGEA_EVENT_PERIOD_TRANSITION;
   request.new_broker_day=true;
   facts=HealthyFacts();
   KingEAEvaluateSafety(request,facts,state,decision);
   state=decision.next_state;
   Check(state.sleeve_recovery.force_bottom_tier,
         "bottom-tier pin survives the broker-day transition");

   request=ValidEntryRequest();
   facts=HealthyFacts();
   facts.sleeve_tier_percent=1.10;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_DOWNSIZE_ENTRY &&
         MathAbs(decision.permitted_volume-0.05)<1e-9,
         "bottom-tier override caps a previously earned full tier");

   ZeroMemory(state);
   state.sleeve_retired=true;
   ZeroMemory(request);
   request.event=KINGEA_EVENT_MANUAL_REVIEW_APPROVED;
   request.scope=KINGEA_SCOPE_SLEEVE;
   KingEAEvaluateSafety(request,facts,state,decision);
   Check(decision.action==KINGEA_ACTION_QUARANTINE &&
         decision.next_state.sleeve_retired,
         "manual review cannot clear a retired sleeve without revalidation");
  }

void OnStart()
  {
   KingEASafetyRequest request=ValidEntryRequest();
   KingEASafetyFacts facts=HealthyFacts();
   KingEASafetyState prior={};
   KingEASafetyDecision decision={};

   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.action==KINGEA_ACTION_APPROVE_ENTRY,
         "valid entry is approved");
   Check(MathAbs(decision.permitted_volume-0.05)<1e-9,
         "stop-derived volume is rounded downward");
   Check(decision.required_stop==1950.0,
         "technical stop is preserved");

   prior.full_losses_today=2;
   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.action==KINGEA_ACTION_DOWNSIZE_ENTRY,
         "two-loss throttle downsizes the final trade");
   Check(MathAbs(decision.permitted_volume-0.02)<1e-9,
         "throttle allowance is the sole binding constraint");
   Check(decision.next_state.final_trade_submitted,
         "throttled final trade closes the broker day to entries");

   ZeroMemory(prior);
   facts=HealthyFacts();
   facts.live_margin_per_lot=4000.0;
   facts.notional_per_lot=1000000.0;
   KingEAEvaluateSafety(request,facts,prior,decision);
   Check(decision.action==KINGEA_ACTION_DOWNSIZE_ENTRY,
         "stressed margin floors downsize instead of weakening");
   Check(MathAbs(decision.permitted_volume-0.04)<1e-9,
         "greater HMR margin proxy binds at five-hundred percent and eighty percent");

   TestBreakerPrecedence();
   TestRecoveryStateMachine();
   TestCapsGatesAndPositionProtection();
   TestFailClosedFactsAndHealthMemory();
   TestSleeveRecoveryAndReview();

   string status=(g_failures==0 ? "PASS" : "FAIL");
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string safe_utc=utc;
   StringReplace(safe_utc,":","-");
   StringReplace(safe_utc," ","_");
   string filename="KingEA\\safety_kernel_contract_"+safe_utc+".csv";
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(report!=INVALID_HANDLE)
     {
      FileWrite(report,"section","key","value","notes");
      FileWrite(report,"audit","scope","NON_PERFORMANCE_SAFETY_KERNEL_CONTRACT","");
      FileWrite(report,"audit","build_id","KINGEA-SAFETY-KERNEL-TEST-20260726-A","");
      FileWrite(report,"result","status",status,"");
      FileWrite(report,"result","checks",IntegerToString(g_checks),"");
      FileWrite(report,"result","failures",IntegerToString(g_failures),"");
      FileWrite(report,"result","order_capability","PROHIBITED_AND_ABSENT","");
      FileClose(report);
      PrintFormat("KingEA safety kernel contract report: %s",
                  TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
     }
   else
     {
      g_failures++;
      status="FAIL";
      PrintFormat("SAFETY_KERNEL_TEST_FAIL: report open error=%d",GetLastError());
     }
   PrintFormat("SAFETY_KERNEL_TEST_%s: checks=%d; failures=%d; non-performance; no order capability.",
               status,g_checks,g_failures);
  }
