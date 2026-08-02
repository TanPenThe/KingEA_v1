#ifndef KINGEA_SAFETY_KERNEL_MQH
#define KINGEA_SAFETY_KERNEL_MQH

// Pure, deterministic KingEA safety policy.
// This module contains no terminal I/O, history access, or order capability.

const double KINGEA_ACCOUNT_DAILY_BREAKER=0.03;
const double KINGEA_ACCOUNT_WEEKLY_BREAKER=0.06;
const double KINGEA_ACCOUNT_MONTHLY_BREAKER=0.10;
const double KINGEA_ACCOUNT_ALL_TIME_BREAKER=0.20;
const double KINGEA_SLEEVE_WEEKLY_BREAKER=0.04;
const double KINGEA_SLEEVE_MONTHLY_BREAKER=0.07;
const double KINGEA_SLEEVE_ALL_TIME_BREAKER=0.12;
const double KINGEA_CLUSTER_RISK_CAP=0.015;
const double KINGEA_PORTFOLIO_RISK_CAP=0.022;
const double KINGEA_BREAKER_HEADROOM_FRACTION=0.50;
const double KINGEA_HMR_REFERENCE_LEVERAGE=200.0;
const double KINGEA_MIN_MARGIN_LEVEL_PERCENT=500.0;
const double KINGEA_MIN_FREE_MARGIN_EQUITY_RATIO=0.80;
const int    KINGEA_RECOVERY_CLEAN_DAYS=5;
const int    KINGEA_RECOVERY_THROTTLE_LIMIT=2;
const int    KINGEA_WEEKLY_BREAKER_LIMIT=3;
const int    KINGEA_WEEKLY_BREAKER_WINDOW_DAYS=90;
const double KINGEA_THROTTLE_RISK_FRACTION=0.50;
const double KINGEA_WEEKEND_RISK_FRACTION=0.50;
const double KINGEA_BOTTOM_TIER_PERCENT=0.25;
const double KINGEA_ENTRY_SPREAD_BLOCK_RATIO=2.0;
const double KINGEA_REDUCE_SPREAD_RATIO=2.5;
const double KINGEA_FLATTEN_SPREAD_RATIO=3.0;

enum KingEASafetyEvent
  {
   KINGEA_EVENT_ENTRY=0,
   KINGEA_EVENT_POSITION_REVIEW=1,
   KINGEA_EVENT_CLOSED_TRADE_GROUP=2,
   KINGEA_EVENT_PERIOD_TRANSITION=3,
   KINGEA_EVENT_CUMULATIVE_REVIEW_APPROVED=4,
   KINGEA_EVENT_CUMULATIVE_REVIEW_REJECTED=5,
   KINGEA_EVENT_MANUAL_REVIEW_APPROVED=6
  };

enum KingEASafetyScope
  {
   KINGEA_SCOPE_SLEEVE=0,
   KINGEA_SCOPE_ACCOUNT=1
  };

enum KingEASafetyDirection
  {
   KINGEA_SAFETY_NONE=0,
   KINGEA_SAFETY_LONG=1,
   KINGEA_SAFETY_SHORT=-1
  };

enum KingEASafetyAction
  {
   KINGEA_ACTION_NONE=0,
   KINGEA_ACTION_APPROVE_ENTRY=1,
   KINGEA_ACTION_DOWNSIZE_ENTRY=2,
   KINGEA_ACTION_REJECT_SIGNAL=3,
   KINGEA_ACTION_REDUCE_POSITION=4,
   KINGEA_ACTION_FLATTEN=5,
   KINGEA_ACTION_CANCEL_PENDING=6,
   KINGEA_ACTION_QUARANTINE=7
  };

enum KingEASafetyAlert
  {
   KINGEA_ALERT_NONE=0,
   KINGEA_ALERT_TIER3=1,
   KINGEA_ALERT_TIER2=2,
   KINGEA_ALERT_TIER1=3
  };

enum KingEASafetyReason
  {
   KINGEA_REASON_OK=0,
   KINGEA_REASON_INVALID_INPUT=1,
   KINGEA_REASON_RISK_CAP=2,
   KINGEA_REASON_MINIMUM_VOLUME=3,
   KINGEA_REASON_MARGIN_FLOOR=4,
   KINGEA_REASON_GATE_BLOCK=5,
   KINGEA_REASON_BREAKER=6,
   KINGEA_REASON_RECOVERY_REVIEW=7,
   KINGEA_REASON_STOP_INVARIANT=8,
   KINGEA_REASON_UNKNOWN_EXPOSURE=9,
   KINGEA_REASON_SPREAD_REDUCTION=10,
   KINGEA_REASON_SPREAD_FLATTEN=11,
   KINGEA_REASON_DAILY_BREAKER=12,
   KINGEA_REASON_WEEKLY_BREAKER=13,
   KINGEA_REASON_MONTHLY_BREAKER=14,
   KINGEA_REASON_PERMANENT_BREAKER=15,
   KINGEA_REASON_THROTTLE_REVIEW=16,
   KINGEA_REASON_CUMULATIVE_REVIEW=17,
   KINGEA_REASON_RETIRED=18
  };

struct KingEASafetyRequest
  {
   KingEASafetyEvent     event;
   KingEASafetyScope     scope;
   KingEASafetyDirection direction;
   double                entry_price;
   double                technical_stop;
   double                current_stop;
   double                proposed_stop;
   double                position_volume;
   bool                  signal_present;
   bool                  position_present;
   bool                  protective_stop_failed;
   bool                  manual_stop_change;
   bool                  closed_group_full_loss;
   bool                  new_broker_day;
   bool                  new_broker_week;
   bool                  new_broker_month;
  };

struct KingEASafetyFacts
  {
   datetime now_server;
   double   account_equity;
   double   account_day_open_equity;
   double   account_week_open_equity;
   double   account_month_open_equity;
   double   account_equity_high;
   double   sleeve_equity;
   double   sleeve_week_open_equity;
   double   sleeve_month_open_equity;
   double   sleeve_equity_high;
   double   sleeve_tier_percent;
   double   cluster_existing_risk;
   double   portfolio_existing_risk;
   bool     cluster_known;
   double   volume_min;
   double   volume_max;
   double   volume_step;
   double   stressed_loss_per_lot;
   double   live_margin_per_lot;
   double   notional_per_lot;
   double   current_used_margin;
   double   spread_ratio;
   bool     spread_above_three_persistent;
   bool     news_block;
   bool     maintenance_block;
   bool     weekend_crypto;
   bool     existing_news_position_safe;
   bool     stop_valid;
   bool     state_valid;
   bool     configuration_valid;
   bool     exposure_reconciled;
   bool     stops_confirmed;
   bool     connection_healthy;
   bool     specification_healthy;
   bool     calendar_fresh;
   bool     market_open;
   bool     unknown_exposure;
   bool     external_cash_flow_reconciled;
  };

struct KingEARecoveryState
  {
   bool     active;
   int      clean_days;
   int      throttle_events;
   bool     manual_review_latched;
   datetime weekly_breaker_1;
   datetime weekly_breaker_2;
   datetime weekly_breaker_3;
   int      weekly_breaker_count;
   long     escalation_epoch;
   bool     force_bottom_tier;
   bool     day_health_failed;
  };

struct KingEASafetyState
  {
   bool                daily_paused;
   bool                account_weekly_paused;
   bool                account_monthly_latched;
   bool                account_permanent_halt;
   bool                sleeve_weekly_paused;
   bool                sleeve_monthly_latched;
   bool                sleeve_retired;
   bool                account_revalidation_halt;
   bool                account_weekly_breach_recorded;
   bool                sleeve_weekly_breach_recorded;
   int                 full_losses_today;
   bool                final_trade_submitted;
   datetime            broker_day_start;
   datetime            broker_week_start;
   datetime            broker_month_start;
   KingEARecoveryState account_recovery;
   KingEARecoveryState sleeve_recovery;
  };

struct KingEASafetyDecision
  {
   KingEASafetyAction action;
   KingEASafetyReason reason;
   KingEASafetyAlert alert;
   double             permitted_volume;
   double             required_stop;
   double             permitted_risk_money;
   double             reduction_fraction;
   bool               cancel_pending;
   bool               quarantine;
   bool               restore_confirmed_stop;
   KingEASafetyState  next_state;
  };

double KingEAMinimum(const double a,const double b)
  {
   return a<b ? a : b;
  }

double KingEAPositiveHeadroom(const double baseline,const double equity,
                              const double limit_fraction)
  {
   if(baseline<=0.0 || equity<=0.0)
      return 0.0;
   return MathMax(0.0,equity-(baseline*(1.0-limit_fraction)));
  }

double KingEARoundVolumeDown(const double volume,const double step)
  {
   if(step<=0.0 || volume<=0.0)
      return 0.0;
   return MathFloor((volume+1e-12)/step)*step;
  }

bool KingEAEntryFactsValid(const KingEASafetyRequest &request,
                           const KingEASafetyFacts &facts)
  {
   if(!request.signal_present || request.event!=KINGEA_EVENT_ENTRY)
      return false;
   if(request.direction!=KINGEA_SAFETY_LONG &&
      request.direction!=KINGEA_SAFETY_SHORT)
      return false;
   if(!MathIsValidNumber(request.entry_price) ||
      !MathIsValidNumber(request.technical_stop) ||
      request.entry_price<=0.0 || request.technical_stop<=0.0)
      return false;
   if(request.direction==KINGEA_SAFETY_LONG &&
      request.technical_stop>=request.entry_price)
      return false;
   if(request.direction==KINGEA_SAFETY_SHORT &&
      request.technical_stop<=request.entry_price)
      return false;
   if(facts.account_equity<=0.0 || facts.sleeve_equity<=0.0 ||
      facts.sleeve_tier_percent<=0.0 || facts.volume_min<=0.0 ||
      facts.volume_max<facts.volume_min || facts.volume_step<=0.0 ||
      facts.stressed_loss_per_lot<=0.0 || facts.live_margin_per_lot<0.0 ||
      facts.notional_per_lot<0.0 || facts.current_used_margin<0.0)
      return false;
   if(!facts.stop_valid)
      return false;
   return true;
  }

bool KingEANumericFactsValid(const KingEASafetyFacts &facts)
  {
   double values[20];
   values[0]=facts.account_equity;
   values[1]=facts.account_day_open_equity;
   values[2]=facts.account_week_open_equity;
   values[3]=facts.account_month_open_equity;
   values[4]=facts.account_equity_high;
   values[5]=facts.sleeve_equity;
   values[6]=facts.sleeve_week_open_equity;
   values[7]=facts.sleeve_month_open_equity;
   values[8]=facts.sleeve_equity_high;
   values[9]=facts.sleeve_tier_percent;
   values[10]=facts.cluster_existing_risk;
   values[11]=facts.portfolio_existing_risk;
   values[12]=facts.volume_min;
   values[13]=facts.volume_max;
   values[14]=facts.volume_step;
   values[15]=facts.stressed_loss_per_lot;
   values[16]=facts.live_margin_per_lot;
   values[17]=facts.notional_per_lot;
   values[18]=facts.current_used_margin;
   values[19]=facts.spread_ratio;
   for(int i=0;i<ArraySize(values);i++)
      if(!MathIsValidNumber(values[i]))
         return false;
   return facts.now_server>0;
  }

bool KingEARequestValid(const KingEASafetyRequest &request)
  {
   if(!MathIsValidNumber(request.entry_price) ||
      !MathIsValidNumber(request.technical_stop) ||
      !MathIsValidNumber(request.current_stop) ||
      !MathIsValidNumber(request.proposed_stop) ||
      !MathIsValidNumber(request.position_volume))
      return false;
   if(request.event==KINGEA_EVENT_POSITION_REVIEW)
     {
      if(!request.position_present || request.position_volume<=0.0)
         return false;
      if(request.direction!=KINGEA_SAFETY_LONG &&
         request.direction!=KINGEA_SAFETY_SHORT)
         return false;
     }
   return true;
  }

bool KingEARecoveryStateValid(const KingEARecoveryState &recovery)
  {
   if(recovery.clean_days<0 || recovery.clean_days>=KINGEA_RECOVERY_CLEAN_DAYS ||
      recovery.throttle_events<0 ||
      recovery.throttle_events>KINGEA_RECOVERY_THROTTLE_LIMIT ||
      recovery.weekly_breaker_count<0 ||
      recovery.weekly_breaker_count>KINGEA_WEEKLY_BREAKER_LIMIT ||
      recovery.escalation_epoch<0)
      return false;
   if(recovery.active && recovery.manual_review_latched)
      return false;
   int timestamps=0;
   if(recovery.weekly_breaker_1>0) timestamps++;
   if(recovery.weekly_breaker_2>0) timestamps++;
   if(recovery.weekly_breaker_3>0) timestamps++;
   return timestamps==recovery.weekly_breaker_count;
  }

bool KingEASafetyStateValid(const KingEASafetyState &state)
  {
   if(state.full_losses_today<0 || state.full_losses_today>3)
      return false;
   return (KingEARecoveryStateValid(state.account_recovery) &&
           KingEARecoveryStateValid(state.sleeve_recovery));
  }

bool KingEAHealthFactsPass(const KingEASafetyFacts &facts)
  {
   if(facts.account_equity<=0.0)
      return false;
   if(!facts.state_valid || !facts.configuration_valid ||
      !facts.exposure_reconciled || !facts.stops_confirmed ||
      !facts.connection_healthy || !facts.specification_healthy ||
      !facts.calendar_fresh || !facts.external_cash_flow_reconciled ||
      facts.unknown_exposure ||
      facts.spread_ratio>KINGEA_ENTRY_SPREAD_BLOCK_RATIO)
      return false;
   double projected_margin=facts.current_used_margin;
   double margin_level=(projected_margin<=0.0
                        ? 1.0e100
                        : facts.account_equity/projected_margin*100.0);
   double free_ratio=(facts.account_equity-projected_margin)/
                     facts.account_equity;
   return (margin_level+1e-9>=KINGEA_MIN_MARGIN_LEVEL_PERCENT &&
           free_ratio+1e-12>=KINGEA_MIN_FREE_MARGIN_EQUITY_RATIO);
  }

void KingEARecordRecoveryHealth(const KingEASafetyFacts &facts,
                                KingEASafetyState &state)
  {
   if(KingEAHealthFactsPass(facts))
      return;
   if(state.account_recovery.active)
      state.account_recovery.day_health_failed=true;
   if(state.sleeve_recovery.active)
      state.sleeve_recovery.day_health_failed=true;
  }

void KingEAInitializeDecision(const KingEASafetyState &prior,
                              KingEASafetyDecision &decision)
  {
   decision.action=KINGEA_ACTION_REJECT_SIGNAL;
   decision.reason=KINGEA_REASON_INVALID_INPUT;
   decision.alert=KINGEA_ALERT_NONE;
   decision.permitted_volume=0.0;
   decision.required_stop=0.0;
   decision.permitted_risk_money=0.0;
   decision.reduction_fraction=0.0;
   decision.cancel_pending=false;
   decision.quarantine=false;
   decision.restore_confirmed_stop=false;
   decision.next_state=prior;
  }

bool KingEABreakerBreached(const double baseline,const double equity,
                           const double fraction)
  {
   if(baseline<=0.0 || equity<=0.0)
      return true;
   return equity<=baseline*(1.0-fraction)+1e-10;
  }

void KingEARejectWith(const KingEASafetyAction action,
                      const KingEASafetyReason reason,
                      const KingEASafetyAlert alert,
                      const bool cancel_pending,
                      const bool quarantine,
                      KingEASafetyDecision &decision)
  {
   decision.action=action;
   decision.reason=reason;
   decision.alert=alert;
   decision.cancel_pending=cancel_pending;
   decision.quarantine=quarantine;
  }

void KingEAAddWeeklyBreaker(const datetime now_server,
                            KingEARecoveryState &recovery)
  {
   const int WINDOW_SECONDS=KINGEA_WEEKLY_BREAKER_WINDOW_DAYS*24*60*60;
   datetime retained[3];
   int retained_count=0;
   datetime known[3];
   known[0]=recovery.weekly_breaker_1;
   known[1]=recovery.weekly_breaker_2;
   known[2]=recovery.weekly_breaker_3;
   for(int i=0;i<3;i++)
     {
      if(known[i]>0 && now_server-known[i]<WINDOW_SECONDS)
         retained[retained_count++]=known[i];
     }
   if(retained_count<KINGEA_WEEKLY_BREAKER_LIMIT)
      retained[retained_count++]=now_server;
   recovery.weekly_breaker_1=(retained_count>0 ? retained[0] : 0);
   recovery.weekly_breaker_2=(retained_count>1 ? retained[1] : 0);
   recovery.weekly_breaker_3=(retained_count>2 ? retained[2] : 0);
   recovery.weekly_breaker_count=retained_count;
   if(retained_count>=KINGEA_WEEKLY_BREAKER_LIMIT)
      recovery.manual_review_latched=true;
  }

bool KingEACleanRecoveryFacts(const KingEASafetyFacts &facts,
                              const KingEASafetyState &state)
  {
   if(state.daily_paused || state.full_losses_today>=2)
      return false;
   return KingEAHealthFactsPass(facts);
  }

void KingEAAdvanceRecovery(const bool clean,
                           KingEARecoveryState &recovery)
  {
   if(!recovery.active || recovery.manual_review_latched)
      return;
   if(!clean)
     {
      recovery.clean_days=0;
      recovery.day_health_failed=false;
      return;
     }
   recovery.clean_days++;
   if(recovery.clean_days>=KINGEA_RECOVERY_CLEAN_DAYS)
     {
      recovery.active=false;
      recovery.clean_days=0;
      recovery.throttle_events=0;
     }
   recovery.day_health_failed=false;
  }

void KingEAProcessPeriodTransition(const KingEASafetyRequest &request,
                                   const KingEASafetyFacts &facts,
                                   KingEASafetyDecision &decision)
  {
   bool account_started=false;
   bool sleeve_started=false;
   bool common_clean=KingEACleanRecoveryFacts(facts,decision.next_state);
   bool account_clean=(common_clean &&
                       !decision.next_state.account_recovery.day_health_failed);
   bool sleeve_clean=(common_clean &&
                      !decision.next_state.sleeve_recovery.day_health_failed);
   if(request.new_broker_day)
     {
      KingEAAdvanceRecovery(account_clean,decision.next_state.account_recovery);
      KingEAAdvanceRecovery(sleeve_clean,decision.next_state.sleeve_recovery);
      decision.next_state.daily_paused=false;
      decision.next_state.full_losses_today=0;
      decision.next_state.final_trade_submitted=false;
     }
   if(request.new_broker_week)
     {
      if(decision.next_state.account_weekly_paused)
        {
         decision.next_state.account_weekly_paused=false;
         decision.next_state.account_recovery.active=true;
         decision.next_state.account_recovery.clean_days=0;
         decision.next_state.account_recovery.throttle_events=0;
         account_started=true;
        }
      if(decision.next_state.sleeve_weekly_paused)
        {
         decision.next_state.sleeve_weekly_paused=false;
         decision.next_state.sleeve_recovery.active=true;
         decision.next_state.sleeve_recovery.clean_days=0;
         decision.next_state.sleeve_recovery.throttle_events=0;
         sleeve_started=true;
        }
      decision.next_state.account_weekly_breach_recorded=false;
      decision.next_state.sleeve_weekly_breach_recorded=false;
     }
   if(account_started || sleeve_started)
      decision.reason=KINGEA_REASON_WEEKLY_BREAKER;
   else
      decision.reason=KINGEA_REASON_OK;
   decision.action=KINGEA_ACTION_NONE;
  }

bool KingEARegisterRecoveryThrottle(KingEARecoveryState &recovery)
  {
   if(!recovery.active || recovery.manual_review_latched)
      return false;
   recovery.clean_days=0;
   recovery.throttle_events++;
   if(recovery.throttle_events<KINGEA_RECOVERY_THROTTLE_LIMIT)
      return false;
   recovery.manual_review_latched=true;
   recovery.force_bottom_tier=true;
   recovery.active=false;
   return true;
  }

void KingEAProcessClosedGroup(const KingEASafetyRequest &request,
                              KingEASafetyDecision &decision)
  {
   decision.action=KINGEA_ACTION_NONE;
   decision.reason=KINGEA_REASON_OK;
   if(!request.closed_group_full_loss)
      return;
   decision.next_state.full_losses_today++;
   if(decision.next_state.full_losses_today!=2)
      return;
   bool account_halt=KingEARegisterRecoveryThrottle(
      decision.next_state.account_recovery);
   bool sleeve_halt=KingEARegisterRecoveryThrottle(
      decision.next_state.sleeve_recovery);
   if(account_halt || sleeve_halt)
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_THROTTLE_REVIEW,
                       KINGEA_ALERT_TIER1,true,true,decision);
  }

void KingEAProcessReview(const KingEASafetyRequest &request,
                         KingEASafetyDecision &decision)
  {
   KingEARecoveryState recovery=(request.scope==KINGEA_SCOPE_ACCOUNT
                                 ? decision.next_state.account_recovery
                                 : decision.next_state.sleeve_recovery);
   if(request.event==KINGEA_EVENT_CUMULATIVE_REVIEW_APPROVED)
     {
      recovery.weekly_breaker_1=0;
      recovery.weekly_breaker_2=0;
      recovery.weekly_breaker_3=0;
      recovery.weekly_breaker_count=0;
      recovery.manual_review_latched=false;
      recovery.force_bottom_tier=false;
      recovery.throttle_events=0;
      recovery.clean_days=0;
      recovery.active=true;
      recovery.escalation_epoch++;
     }
   else if(request.event==KINGEA_EVENT_CUMULATIVE_REVIEW_REJECTED)
     {
      recovery.manual_review_latched=true;
      recovery.active=false;
      if(request.scope==KINGEA_SCOPE_ACCOUNT)
         decision.next_state.account_revalidation_halt=true;
      else
         decision.next_state.sleeve_retired=true;
     }
   else if(request.event==KINGEA_EVENT_MANUAL_REVIEW_APPROVED)
     {
      bool irreversible=(request.scope==KINGEA_SCOPE_ACCOUNT
                         ? (decision.next_state.account_permanent_halt ||
                            decision.next_state.account_revalidation_halt)
                         : decision.next_state.sleeve_retired);
      if(irreversible)
        {
         KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_RETIRED,
                          KINGEA_ALERT_TIER1,true,true,decision);
         return;
        }
      recovery.manual_review_latched=false;
      recovery.active=false;
      recovery.clean_days=0;
      recovery.throttle_events=0;
     }
   if(request.scope==KINGEA_SCOPE_ACCOUNT)
     {
      decision.next_state.account_recovery=recovery;
      if(request.event!=KINGEA_EVENT_CUMULATIVE_REVIEW_REJECTED)
        {
         decision.next_state.account_weekly_paused=false;
         decision.next_state.account_monthly_latched=false;
        }
     }
   else
     {
      decision.next_state.sleeve_recovery=recovery;
      if(request.event!=KINGEA_EVENT_CUMULATIVE_REVIEW_REJECTED)
        {
         decision.next_state.sleeve_weekly_paused=false;
         decision.next_state.sleeve_monthly_latched=false;
        }
     }
   decision.action=KINGEA_ACTION_NONE;
   decision.reason=KINGEA_REASON_OK;
  }

bool KingEAApplyBreakers(const KingEASafetyFacts &facts,
                         KingEASafetyDecision &decision)
  {
   if(KingEABreakerBreached(facts.account_equity_high,
                            facts.account_equity,KINGEA_ACCOUNT_ALL_TIME_BREAKER))
     {
      decision.next_state.account_permanent_halt=true;
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_PERMANENT_BREAKER,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return true;
     }
   if(KingEABreakerBreached(facts.account_month_open_equity,
                            facts.account_equity,KINGEA_ACCOUNT_MONTHLY_BREAKER))
     {
      decision.next_state.account_monthly_latched=true;
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_MONTHLY_BREAKER,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return true;
     }
   if(KingEABreakerBreached(facts.sleeve_equity_high,
                            facts.sleeve_equity,KINGEA_SLEEVE_ALL_TIME_BREAKER))
     {
      decision.next_state.sleeve_retired=true;
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_PERMANENT_BREAKER,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return true;
     }
   if(KingEABreakerBreached(facts.sleeve_month_open_equity,
                            facts.sleeve_equity,KINGEA_SLEEVE_MONTHLY_BREAKER))
     {
      decision.next_state.sleeve_monthly_latched=true;
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_MONTHLY_BREAKER,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return true;
     }
   bool account_weekly=KingEABreakerBreached(facts.account_week_open_equity,
                                             facts.account_equity,
                                             KINGEA_ACCOUNT_WEEKLY_BREAKER);
   bool sleeve_weekly=KingEABreakerBreached(facts.sleeve_week_open_equity,
                                            facts.sleeve_equity,
                                            KINGEA_SLEEVE_WEEKLY_BREAKER);
   if(account_weekly || sleeve_weekly)
     {
      if(account_weekly)
        {
         decision.next_state.account_weekly_paused=true;
         if(!decision.next_state.account_weekly_breach_recorded)
           {
            KingEAAddWeeklyBreaker(facts.now_server,
                                   decision.next_state.account_recovery);
            decision.next_state.account_weekly_breach_recorded=true;
           }
        }
      if(sleeve_weekly)
        {
         decision.next_state.sleeve_weekly_paused=true;
         if(!decision.next_state.sleeve_weekly_breach_recorded)
           {
            KingEAAddWeeklyBreaker(facts.now_server,
                                   decision.next_state.sleeve_recovery);
            decision.next_state.sleeve_weekly_breach_recorded=true;
           }
        }
      KingEASafetyReason reason=(decision.next_state.account_recovery.manual_review_latched ||
                                 decision.next_state.sleeve_recovery.manual_review_latched
                                 ? KINGEA_REASON_CUMULATIVE_REVIEW
                                 : KINGEA_REASON_WEEKLY_BREAKER);
      KingEARejectWith(KINGEA_ACTION_FLATTEN,reason,KINGEA_ALERT_TIER1,
                       true,reason==KINGEA_REASON_CUMULATIVE_REVIEW,decision);
      return true;
     }
   if(KingEABreakerBreached(facts.account_day_open_equity,
                            facts.account_equity,KINGEA_ACCOUNT_DAILY_BREAKER))
     {
      decision.next_state.daily_paused=true;
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_DAILY_BREAKER,
                       KINGEA_ALERT_TIER1,true,false,decision);
      return true;
     }
   return false;
  }

bool KingEAStateBlocksEntry(const KingEASafetyFacts &facts,
                            const KingEASafetyState &state,
                            KingEASafetyDecision &decision)
  {
   if(state.account_permanent_halt || state.account_revalidation_halt ||
      state.sleeve_retired)
     {
      KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_RETIRED,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return true;
     }
   if(state.account_monthly_latched || state.sleeve_monthly_latched ||
      state.account_recovery.manual_review_latched ||
      state.sleeve_recovery.manual_review_latched)
     {
      KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_RECOVERY_REVIEW,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return true;
     }
   if(state.daily_paused || state.account_weekly_paused ||
      state.sleeve_weekly_paused || state.final_trade_submitted)
     {
      decision.action=KINGEA_ACTION_REJECT_SIGNAL;
      decision.reason=KINGEA_REASON_GATE_BLOCK;
      return true;
     }
   if(facts.unknown_exposure)
     {
      KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_UNKNOWN_EXPOSURE,
                       KINGEA_ALERT_TIER1,false,true,decision);
      return true;
     }
   if(!facts.state_valid || !facts.configuration_valid ||
      !facts.exposure_reconciled || !facts.stops_confirmed ||
      !facts.connection_healthy || !facts.specification_healthy ||
      !facts.external_cash_flow_reconciled)
     {
      KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_GATE_BLOCK,
                       KINGEA_ALERT_TIER1,false,true,decision);
      return true;
     }
   if(!facts.calendar_fresh || !facts.market_open || facts.news_block ||
      facts.maintenance_block ||
      facts.spread_ratio>KINGEA_ENTRY_SPREAD_BLOCK_RATIO)
     {
      decision.action=KINGEA_ACTION_REJECT_SIGNAL;
      decision.reason=KINGEA_REASON_GATE_BLOCK;
      return true;
     }
   return false;
  }

void KingEAProcessPositionReview(const KingEASafetyRequest &request,
                                 const KingEASafetyFacts &facts,
                                 KingEASafetyDecision &decision)
  {
   decision.action=KINGEA_ACTION_NONE;
   decision.reason=KINGEA_REASON_OK;
   if(!request.position_present)
     {
      decision.action=KINGEA_ACTION_REJECT_SIGNAL;
      decision.reason=KINGEA_REASON_INVALID_INPUT;
      return;
     }
   if(request.protective_stop_failed || !facts.stops_confirmed)
     {
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_STOP_INVARIANT,
                       KINGEA_ALERT_TIER1,true,true,decision);
      return;
     }
   if(facts.spread_above_three_persistent)
     {
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_SPREAD_FLATTEN,
                       KINGEA_ALERT_TIER2,false,false,decision);
      return;
     }
   if(facts.maintenance_block ||
      (facts.news_block && !facts.existing_news_position_safe))
     {
      KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_GATE_BLOCK,
                       KINGEA_ALERT_TIER2,false,false,decision);
      return;
     }
   if(!facts.state_valid || !facts.configuration_valid ||
      !facts.exposure_reconciled || !facts.connection_healthy ||
      !facts.specification_healthy || facts.unknown_exposure)
     {
      KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_GATE_BLOCK,
                       KINGEA_ALERT_TIER1,false,true,decision);
      return;
     }
   if(facts.spread_ratio>KINGEA_REDUCE_SPREAD_RATIO)
     {
      double close_volume=KingEARoundVolumeDown(
         request.position_volume*0.50,facts.volume_step);
      double remaining_volume=request.position_volume-close_volume;
      bool partial_valid=(close_volume+1e-12>=facts.volume_min &&
                          remaining_volume+1e-12>=facts.volume_min);
      if(!partial_valid)
         KingEARejectWith(KINGEA_ACTION_FLATTEN,
                          KINGEA_REASON_SPREAD_REDUCTION,
                          KINGEA_ALERT_TIER2,false,false,decision);
      else
        {
         decision.action=KINGEA_ACTION_REDUCE_POSITION;
         decision.reason=KINGEA_REASON_SPREAD_REDUCTION;
         decision.alert=KINGEA_ALERT_TIER2;
         decision.reduction_fraction=0.50;
         decision.permitted_volume=close_volume;
        }
      return;
     }
   if(request.manual_stop_change)
     {
      if(facts.stop_valid && request.current_stop>0.0)
        {
         decision.action=KINGEA_ACTION_QUARANTINE;
         decision.reason=KINGEA_REASON_STOP_INVARIANT;
         decision.alert=KINGEA_ALERT_TIER1;
         decision.quarantine=true;
         decision.restore_confirmed_stop=true;
         decision.required_stop=request.current_stop;
        }
      else
         KingEARejectWith(KINGEA_ACTION_FLATTEN,KINGEA_REASON_STOP_INVARIANT,
                          KINGEA_ALERT_TIER1,true,true,decision);
      return;
     }
   if(request.proposed_stop>0.0 && request.current_stop>0.0)
     {
      bool widens=(request.direction==KINGEA_SAFETY_LONG
                   ? request.proposed_stop<request.current_stop
                   : request.proposed_stop>request.current_stop);
      if(widens)
        {
         decision.reason=KINGEA_REASON_STOP_INVARIANT;
         decision.required_stop=request.current_stop;
         return;
        }
      decision.required_stop=request.proposed_stop;
     }
  }

void KingEAEvaluateSafety(const KingEASafetyRequest &request,
                          const KingEASafetyFacts &facts,
                          const KingEASafetyState &prior,
                          KingEASafetyDecision &decision)
  {
   KingEAInitializeDecision(prior,decision);
   if(!KingEANumericFactsValid(facts) || !KingEARequestValid(request) ||
      !KingEASafetyStateValid(prior))
     {
      KingEARejectWith(KINGEA_ACTION_QUARANTINE,KINGEA_REASON_INVALID_INPUT,
                       KINGEA_ALERT_TIER1,false,true,decision);
      return;
     }
   KingEARecordRecoveryHealth(facts,decision.next_state);
   if(request.event==KINGEA_EVENT_PERIOD_TRANSITION)
     {
      KingEAProcessPeriodTransition(request,facts,decision);
      return;
     }
   if(request.event==KINGEA_EVENT_CLOSED_TRADE_GROUP)
     {
      KingEAProcessClosedGroup(request,decision);
      return;
     }
   if(request.event==KINGEA_EVENT_CUMULATIVE_REVIEW_APPROVED ||
      request.event==KINGEA_EVENT_CUMULATIVE_REVIEW_REJECTED ||
      request.event==KINGEA_EVENT_MANUAL_REVIEW_APPROVED)
     {
      KingEAProcessReview(request,decision);
      return;
     }
   if(KingEAApplyBreakers(facts,decision))
      return;
   if(request.event==KINGEA_EVENT_POSITION_REVIEW)
     {
      KingEAProcessPositionReview(request,facts,decision);
      return;
     }
   if(KingEAStateBlocksEntry(facts,decision.next_state,decision))
      return;
   if(!KingEAEntryFactsValid(request,facts))
      return;

   double normal_tier_risk=facts.account_equity*
                           (facts.sleeve_tier_percent/100.0);
   double effective_tier_percent=facts.sleeve_tier_percent;
   if(decision.next_state.account_recovery.active ||
      decision.next_state.sleeve_recovery.active)
      effective_tier_percent*=KINGEA_THROTTLE_RISK_FRACTION;
   if(decision.next_state.account_recovery.force_bottom_tier ||
      decision.next_state.sleeve_recovery.force_bottom_tier)
      effective_tier_percent=MathMin(effective_tier_percent,
                                     KINGEA_BOTTOM_TIER_PERCENT);
   if(facts.weekend_crypto)
      effective_tier_percent*=KINGEA_WEEKEND_RISK_FRACTION;
   double tier_risk=facts.account_equity*(effective_tier_percent/100.0);
   double throttle_capacity=tier_risk;
   bool throttle_binding=false;
   if(prior.full_losses_today>=2)
     {
      if(prior.final_trade_submitted)
        {
         decision.reason=KINGEA_REASON_GATE_BLOCK;
         return;
        }
      throttle_capacity=tier_risk*KINGEA_THROTTLE_RISK_FRACTION;
      throttle_binding=true;
     }
   double portfolio_existing=MathMax(0.0,facts.portfolio_existing_risk);
   double cluster_existing=MathMax(0.0,facts.cluster_existing_risk);
   if(!facts.cluster_known)
      cluster_existing=MathMax(cluster_existing,portfolio_existing);
   double cluster_capacity=facts.account_equity*KINGEA_CLUSTER_RISK_CAP-
                           cluster_existing;
   double portfolio_capacity=facts.account_equity*KINGEA_PORTFOLIO_RISK_CAP-
                             portfolio_existing;
   double breaker_capacity=KINGEA_BREAKER_HEADROOM_FRACTION*
      KingEAPositiveHeadroom(facts.account_day_open_equity,
                             facts.account_equity,
                             KINGEA_ACCOUNT_DAILY_BREAKER);
   breaker_capacity=KingEAMinimum(breaker_capacity,
      KINGEA_BREAKER_HEADROOM_FRACTION*KingEAPositiveHeadroom(
      facts.account_week_open_equity,facts.account_equity,
      KINGEA_ACCOUNT_WEEKLY_BREAKER));
   breaker_capacity=KingEAMinimum(breaker_capacity,
      KINGEA_BREAKER_HEADROOM_FRACTION*KingEAPositiveHeadroom(
      facts.account_month_open_equity,facts.account_equity,
      KINGEA_ACCOUNT_MONTHLY_BREAKER));
   breaker_capacity=KingEAMinimum(breaker_capacity,
      KINGEA_BREAKER_HEADROOM_FRACTION*KingEAPositiveHeadroom(
      facts.account_equity_high,facts.account_equity,
      KINGEA_ACCOUNT_ALL_TIME_BREAKER));
   breaker_capacity=KingEAMinimum(breaker_capacity,
      KINGEA_BREAKER_HEADROOM_FRACTION*KingEAPositiveHeadroom(
      facts.sleeve_week_open_equity,facts.sleeve_equity,
      KINGEA_SLEEVE_WEEKLY_BREAKER));
   breaker_capacity=KingEAMinimum(breaker_capacity,
      KINGEA_BREAKER_HEADROOM_FRACTION*KingEAPositiveHeadroom(
      facts.sleeve_month_open_equity,facts.sleeve_equity,
      KINGEA_SLEEVE_MONTHLY_BREAKER));
   breaker_capacity=KingEAMinimum(breaker_capacity,
      KINGEA_BREAKER_HEADROOM_FRACTION*KingEAPositiveHeadroom(
      facts.sleeve_equity_high,facts.sleeve_equity,
      KINGEA_SLEEVE_ALL_TIME_BREAKER));

   double permitted=KingEAMinimum(tier_risk,cluster_capacity);
   permitted=KingEAMinimum(permitted,throttle_capacity);
   permitted=KingEAMinimum(permitted,portfolio_capacity);
   permitted=KingEAMinimum(permitted,breaker_capacity);
   double raw_volume=permitted/facts.stressed_loss_per_lot;
   double volume=KingEARoundVolumeDown(raw_volume,facts.volume_step);
   volume=KingEAMinimum(volume,facts.volume_max);
   if(volume+1e-12<facts.volume_min)
     {
      decision.reason=KINGEA_REASON_MINIMUM_VOLUME;
      return;
     }

   double initial_risk_volume=volume;
   double hmr_proxy_margin_per_lot=facts.notional_per_lot/
                                   KINGEA_HMR_REFERENCE_LEVERAGE;
   double margin_per_lot=MathMax(facts.live_margin_per_lot,
                                 hmr_proxy_margin_per_lot);
   bool margin_ok=false;
   while(volume+1e-12>=facts.volume_min)
     {
      double projected_margin=facts.current_used_margin+
                              volume*margin_per_lot;
      double margin_level=(projected_margin<=0.0
                           ? 1.0e100
                           : facts.account_equity/projected_margin*100.0);
      double free_margin_ratio=(facts.account_equity-projected_margin)/
                               facts.account_equity;
      if(margin_level+1e-9>=KINGEA_MIN_MARGIN_LEVEL_PERCENT &&
         free_margin_ratio+1e-12>=KINGEA_MIN_FREE_MARGIN_EQUITY_RATIO)
        {
         margin_ok=true;
         break;
        }
      volume=KingEARoundVolumeDown(volume-facts.volume_step,
                                   facts.volume_step);
     }
   if(!margin_ok || volume+1e-12<facts.volume_min)
     {
      decision.reason=KINGEA_REASON_MARGIN_FLOOR;
      return;
     }

   decision.action=(permitted+1e-12<normal_tier_risk ||
                    volume+1e-12<initial_risk_volume
                    ? KINGEA_ACTION_DOWNSIZE_ENTRY
                    : KINGEA_ACTION_APPROVE_ENTRY);
   decision.reason=KINGEA_REASON_OK;
   decision.permitted_volume=volume;
   decision.required_stop=request.technical_stop;
   decision.permitted_risk_money=volume*facts.stressed_loss_per_lot;
   if(throttle_binding)
      decision.next_state.final_trade_submitted=true;
  }

#endif
