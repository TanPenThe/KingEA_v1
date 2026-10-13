#ifndef KINGEA_SPECIFICATION_MONITOR_MQH
#define KINGEA_SPECIFICATION_MONITOR_MQH

// Stage 8 pure structural specification monitor.
// No broker access, file I/O, order submission, strategy history, indicator,
// performance, optimizer, OOS, holdout, DLL, network, or tick-flag capability.

#define KINGEA_MAX_SPEC_SESSIONS 64

enum KingEASpecificationEvent
  {
   KINGEA_SPEC_EVENT_INITIALIZATION=0,
   KINGEA_SPEC_EVENT_RECONNECT=1,
   KINGEA_SPEC_EVENT_BROKER_DAY=2,
   KINGEA_SPEC_EVENT_PERIODIC=3,
   KINGEA_SPEC_EVENT_PRE_SIZING=4,
   KINGEA_SPEC_EVENT_SECOND_CAPTURE=5
  };

enum KingEASpecificationClassification
  {
   KINGEA_SPEC_UNCHANGED=0,
   KINGEA_SPEC_EXPECTED_DYNAMIC=1,
   KINGEA_SPEC_CONFIRMED_HMR=2,
   KINGEA_SPEC_TEMPORARY_RESTRICTION=3,
   KINGEA_SPEC_ADMINISTRATIVE_CHANGE=4,
   KINGEA_SPEC_RISK_CRITICAL_CHANGE=5,
   KINGEA_SPEC_UNSTABLE_CAPTURE=6,
   KINGEA_SPEC_INVALID_OR_STALE=7,
   KINGEA_SPEC_CONFIRMATION_REQUIRED=8,
   KINGEA_SPEC_TRANSIENT_CONFIRMATION=9
  };

enum KingEASpecificationAction
  {
   KINGEA_SPEC_ACTION_HOLD=0,
   KINGEA_SPEC_ACTION_REDUCE=1,
   KINGEA_SPEC_ACTION_FLATTEN=2,
   KINGEA_SPEC_ACTION_QUARANTINE=3
  };

enum KingEASpecificationAlert
  {
   KINGEA_SPEC_ALERT_NONE=0,
   KINGEA_SPEC_ALERT_TIER2=2,
   KINGEA_SPEC_ALERT_TIER1=1
  };

struct KingEASessionInterval
  {
   int from_second;
   int to_second;
  };

struct KingEASymbolSpecification
  {
   bool   valid;
   string symbol_id;
   string description;
   string path;
   string currency_base;
   string currency_profit;
   string currency_margin;
   int    digits;
   double point;
   double tick_size;
   double tick_value;
   double tick_value_profit;
   double tick_value_loss;
   double contract_size;
   int    calc_mode;
   int    execution_mode;
   long   filling_mode;
   long   order_mode;
   long   expiration_mode;
   int    trade_mode;
   double volume_min;
   double volume_max;
   double volume_step;
   double volume_limit;
   int    stops_level;
   int    freeze_level;
   double margin_initial;
   double margin_maintenance;
   double margin_hedged;
   double margin_rate_buy;
   double margin_rate_sell;
   int    session_count;
   KingEASessionInterval sessions[KINGEA_MAX_SPEC_SESSIONS];
  };

struct KingEASpecificationExposure
  {
   bool known;
   bool has_position;
   bool protective_stop_confirmed;
   bool stop_valid;
   bool volume_valid;
   bool closure_available;
   bool reduction_feasible;
  };

struct KingEASpecificationRequest
  {
   KingEASpecificationEvent event;
   datetime observed_at;
   string expected_symbol;
   string expected_server_class;
   string observed_server_class;
   bool connected;
   bool facts_fresh;
   bool tick_probe_available;
   double tick_probe_reported;
   double tick_probe_calculated;
   bool hmr_calendar_authoritative;
   bool hmr_active;
   double equity;
   double stressed_margin_level_percent;
   double stressed_free_margin_ratio;
   double hmr_proxy_margin_per_lot;
   double live_margin_per_lot;
   bool administrative_proof_complete;
   bool sessions_strategy_equivalent;
   bool immediate_risk_breach;
   KingEASpecificationExposure exposure;
  };

struct KingEASpecificationState
  {
   bool awaiting_second_capture;
   bool transient_confirmation_pending;
   datetime scheduled_confirmation_not_before;
   string first_observed_hash;
  };

struct KingEASpecificationDecision
  {
   KingEASpecificationClassification classification;
   KingEASpecificationAction action;
   KingEASpecificationAlert alert;
   bool entry_allowed;
   bool specification_healthy;
   bool review_required;
   bool revalidation_required;
   bool reset_to_bottom_tier;
   bool preserve_earned_tier;
   string reason;
   string approved_hash;
   string observed_hash;
   KingEASpecificationState next_state;
  };

bool KingEASpecFinite(const double value)
  {
   return MathIsValidNumber(value);
  }

bool KingEASpecNear(const double left,const double right)
  {
   double magnitude=MathMax(MathAbs(left),MathAbs(right));
   return MathAbs(left-right)<=MathMax(1e-8,1e-9*magnitude);
  }

string KingEASpecCanonicalDouble(const double value)
  {
   double tolerance=MathMax(1e-8,1e-9*MathAbs(value));
   double normalized=MathRound(value/tolerance)*tolerance;
   return DoubleToString(normalized,12);
  }

bool KingEASpecSameSessionSet(const KingEASymbolSpecification &left,
                             const KingEASymbolSpecification &right)
  {
   if(left.session_count!=right.session_count)
      return false;
   for(int i=0;i<left.session_count;i++)
     {
      bool found=false;
      for(int j=0;j<right.session_count;j++)
         if(left.sessions[i].from_second==right.sessions[j].from_second &&
            left.sessions[i].to_second==right.sessions[j].to_second)
           {
            found=true;
            break;
           }
      if(!found)
         return false;
     }
   return true;
  }

string KingEASpecCanonical(const KingEASymbolSpecification &spec)
  {
   string value=spec.symbol_id+"|"+spec.description+"|"+spec.path+"|"+
                spec.currency_base+"|"+spec.currency_profit+"|"+spec.currency_margin;
   value+="|"+IntegerToString(spec.digits);
   value+="|"+KingEASpecCanonicalDouble(spec.point);
   value+="|"+KingEASpecCanonicalDouble(spec.tick_size);
   value+="|"+KingEASpecCanonicalDouble(spec.tick_value);
   value+="|"+KingEASpecCanonicalDouble(spec.tick_value_profit);
   value+="|"+KingEASpecCanonicalDouble(spec.tick_value_loss);
   value+="|"+KingEASpecCanonicalDouble(spec.contract_size);
   value+="|"+IntegerToString(spec.calc_mode)+"|"+IntegerToString(spec.execution_mode);
   value+="|"+(string)spec.filling_mode+"|"+(string)spec.order_mode+"|"+(string)spec.expiration_mode;
   value+="|"+IntegerToString(spec.trade_mode);
   value+="|"+KingEASpecCanonicalDouble(spec.volume_min)+"|"+KingEASpecCanonicalDouble(spec.volume_max);
   value+="|"+KingEASpecCanonicalDouble(spec.volume_step)+"|"+KingEASpecCanonicalDouble(spec.volume_limit);
   value+="|"+IntegerToString(spec.stops_level)+"|"+IntegerToString(spec.freeze_level);
   value+="|"+KingEASpecCanonicalDouble(spec.margin_initial)+"|"+KingEASpecCanonicalDouble(spec.margin_maintenance);
   value+="|"+KingEASpecCanonicalDouble(spec.margin_hedged)+"|"+KingEASpecCanonicalDouble(spec.margin_rate_buy);
   value+="|"+KingEASpecCanonicalDouble(spec.margin_rate_sell);
   bool used[KINGEA_MAX_SPEC_SESSIONS];
   ArrayInitialize(used,false);
   for(int rank=0;rank<spec.session_count;rank++)
     {
      int selected=-1;
      for(int i=0;i<spec.session_count;i++)
        {
         if(used[i])
            continue;
         if(selected<0 ||
            spec.sessions[i].from_second<spec.sessions[selected].from_second ||
            (spec.sessions[i].from_second==spec.sessions[selected].from_second &&
             spec.sessions[i].to_second<spec.sessions[selected].to_second))
            selected=i;
        }
      if(selected>=0)
        {
         used[selected]=true;
         value+="|"+IntegerToString(spec.sessions[selected].from_second)+":"+
                IntegerToString(spec.sessions[selected].to_second);
        }
     }
   return value;
  }

string KingEASpecHash(const KingEASymbolSpecification &spec)
  {
   uchar source[],key[],digest[];
   int count=StringToCharArray(KingEASpecCanonical(spec),source,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=0)
      return "";
   ArrayResize(source,count-1);
   if(CryptEncode(CRYPT_HASH_SHA256,source,key,digest)!=32)
      return "";
   string result="";
   for(int i=0;i<ArraySize(digest);i++)
      result+=StringFormat("%02X",(int)digest[i]);
   return result;
  }

bool KingEASpecValid(const KingEASymbolSpecification &spec,
                     const KingEASpecificationRequest &request)
  {
   if(!spec.valid || spec.symbol_id=="" ||
      spec.session_count<0 || spec.session_count>KINGEA_MAX_SPEC_SESSIONS)
      return false;
   if(!KingEASpecFinite(spec.point) || !KingEASpecFinite(spec.tick_size) ||
      !KingEASpecFinite(spec.tick_value) || !KingEASpecFinite(spec.tick_value_profit) ||
      !KingEASpecFinite(spec.tick_value_loss) || !KingEASpecFinite(spec.contract_size) ||
      !KingEASpecFinite(spec.volume_min) || !KingEASpecFinite(spec.volume_max) ||
      !KingEASpecFinite(spec.volume_step) || !KingEASpecFinite(spec.volume_limit) ||
      !KingEASpecFinite(spec.margin_initial) || !KingEASpecFinite(spec.margin_maintenance) ||
      !KingEASpecFinite(spec.margin_hedged) || !KingEASpecFinite(spec.margin_rate_buy) ||
      !KingEASpecFinite(spec.margin_rate_sell))
      return false;
   if(spec.point<=0.0 || spec.tick_size<=0.0 || spec.contract_size<=0.0 ||
      spec.volume_min<=0.0 || spec.volume_max<spec.volume_min || spec.volume_step<=0.0)
      return false;
   for(int i=0;i<spec.session_count;i++)
     {
      if(spec.sessions[i].from_second<0 ||
         spec.sessions[i].to_second<=spec.sessions[i].from_second ||
         spec.sessions[i].to_second>604800)
         return false;
      for(int j=i+1;j<spec.session_count;j++)
         if(spec.sessions[i].from_second==spec.sessions[j].from_second &&
            spec.sessions[i].to_second==spec.sessions[j].to_second)
            return false;
     }
   return request.connected && request.facts_fresh &&
          request.expected_symbol==spec.symbol_id &&
          request.expected_server_class!="" &&
          request.expected_server_class==request.observed_server_class;
  }

bool KingEASpecExactlyEquivalent(const KingEASymbolSpecification &left,
                                 const KingEASymbolSpecification &right)
  {
   return left.symbol_id==right.symbol_id &&
          left.description==right.description &&
          left.path==right.path &&
          left.currency_base==right.currency_base &&
          left.currency_profit==right.currency_profit &&
          left.currency_margin==right.currency_margin &&
          left.digits==right.digits &&
          KingEASpecNear(left.point,right.point) &&
          KingEASpecNear(left.tick_size,right.tick_size) &&
          KingEASpecNear(left.tick_value,right.tick_value) &&
          KingEASpecNear(left.tick_value_profit,right.tick_value_profit) &&
          KingEASpecNear(left.tick_value_loss,right.tick_value_loss) &&
          KingEASpecNear(left.contract_size,right.contract_size) &&
          left.calc_mode==right.calc_mode &&
          left.execution_mode==right.execution_mode &&
          left.filling_mode==right.filling_mode &&
          left.order_mode==right.order_mode &&
          left.expiration_mode==right.expiration_mode &&
          left.trade_mode==right.trade_mode &&
          KingEASpecNear(left.volume_min,right.volume_min) &&
          KingEASpecNear(left.volume_max,right.volume_max) &&
          KingEASpecNear(left.volume_step,right.volume_step) &&
          KingEASpecNear(left.volume_limit,right.volume_limit) &&
          left.stops_level==right.stops_level &&
          left.freeze_level==right.freeze_level &&
          KingEASpecNear(left.margin_initial,right.margin_initial) &&
          KingEASpecNear(left.margin_maintenance,right.margin_maintenance) &&
          KingEASpecNear(left.margin_hedged,right.margin_hedged) &&
          KingEASpecNear(left.margin_rate_buy,right.margin_rate_buy) &&
          KingEASpecNear(left.margin_rate_sell,right.margin_rate_sell) &&
          KingEASpecSameSessionSet(left,right);
  }

bool KingEASpecTickProbePasses(const KingEASpecificationRequest &request)
  {
   if(!request.tick_probe_available ||
      !KingEASpecFinite(request.tick_probe_reported) ||
      !KingEASpecFinite(request.tick_probe_calculated) ||
      request.tick_probe_reported<=0.0 || request.tick_probe_calculated<=0.0)
      return false;
   double tolerance=MathMax(0.01,0.001*MathAbs(request.tick_probe_calculated));
   return MathAbs(request.tick_probe_reported-request.tick_probe_calculated)<=tolerance;
  }

bool KingEASpecCoreRiskEqual(const KingEASymbolSpecification &left,
                            const KingEASymbolSpecification &right)
  {
   return left.symbol_id==right.symbol_id &&
          left.currency_base==right.currency_base &&
          left.currency_profit==right.currency_profit &&
          left.currency_margin==right.currency_margin &&
          left.digits==right.digits &&
          KingEASpecNear(left.point,right.point) &&
          KingEASpecNear(left.tick_size,right.tick_size) &&
          KingEASpecNear(left.contract_size,right.contract_size) &&
          left.calc_mode==right.calc_mode &&
          left.execution_mode==right.execution_mode &&
          left.filling_mode==right.filling_mode &&
          left.order_mode==right.order_mode &&
          left.expiration_mode==right.expiration_mode &&
          KingEASpecNear(left.volume_min,right.volume_min) &&
          KingEASpecNear(left.volume_max,right.volume_max) &&
          KingEASpecNear(left.volume_step,right.volume_step) &&
          KingEASpecNear(left.volume_limit,right.volume_limit) &&
          left.stops_level==right.stops_level &&
          left.freeze_level==right.freeze_level;
  }

bool KingEASpecTickValuesEqual(const KingEASymbolSpecification &left,
                              const KingEASymbolSpecification &right)
  {
   return KingEASpecNear(left.tick_value,right.tick_value) &&
          KingEASpecNear(left.tick_value_profit,right.tick_value_profit) &&
          KingEASpecNear(left.tick_value_loss,right.tick_value_loss);
  }

bool KingEASpecMarginsEqual(const KingEASymbolSpecification &left,
                           const KingEASymbolSpecification &right)
  {
   return KingEASpecNear(left.margin_initial,right.margin_initial) &&
          KingEASpecNear(left.margin_maintenance,right.margin_maintenance) &&
          KingEASpecNear(left.margin_hedged,right.margin_hedged) &&
          KingEASpecNear(left.margin_rate_buy,right.margin_rate_buy) &&
          KingEASpecNear(left.margin_rate_sell,right.margin_rate_sell);
  }

bool KingEASpecAdministrativeFieldsEqual(const KingEASymbolSpecification &left,
                                        const KingEASymbolSpecification &right)
  {
   return left.description==right.description && left.path==right.path;
  }

bool KingEASpecHmrPasses(const KingEASpecificationRequest &request)
  {
   if(!request.hmr_calendar_authoritative || !request.hmr_active ||
      !KingEASpecFinite(request.live_margin_per_lot) ||
      !KingEASpecFinite(request.hmr_proxy_margin_per_lot) ||
      !KingEASpecFinite(request.stressed_margin_level_percent) ||
      !KingEASpecFinite(request.stressed_free_margin_ratio) ||
      request.live_margin_per_lot<=0.0 || request.hmr_proxy_margin_per_lot<=0.0)
      return false;
   return request.live_margin_per_lot<=request.hmr_proxy_margin_per_lot*1.001 &&
          request.stressed_margin_level_percent>=500.0 &&
          request.stressed_free_margin_ratio>=0.80;
  }

bool KingEASpecHmrTightensMargins(const KingEASymbolSpecification &approved,
                                 const KingEASymbolSpecification &observed)
  {
   double old_values[5]={approved.margin_initial,approved.margin_maintenance,
                         approved.margin_hedged,approved.margin_rate_buy,
                         approved.margin_rate_sell};
   double new_values[5]={observed.margin_initial,observed.margin_maintenance,
                         observed.margin_hedged,observed.margin_rate_buy,
                         observed.margin_rate_sell};
   bool tightened=false;
   for(int i=0;i<5;i++)
     {
      double tolerance=MathMax(1e-8,1e-9*MathMax(MathAbs(old_values[i]),
                                                 MathAbs(new_values[i])));
      if(new_values[i]<old_values[i]-tolerance)
         return false;
      if(new_values[i]>old_values[i]+tolerance)
         tightened=true;
     }
   return tightened;
  }

KingEASpecificationClassification KingEASpecRawClassification(
                              const KingEASymbolSpecification &approved,
                              const KingEASymbolSpecification &observed,
                              const KingEASpecificationRequest &request)
  {
   if(KingEASpecExactlyEquivalent(approved,observed))
      return KINGEA_SPEC_UNCHANGED;

   bool core_equal=KingEASpecCoreRiskEqual(approved,observed);
   bool ticks_equal=KingEASpecTickValuesEqual(approved,observed);
   bool margins_equal=KingEASpecMarginsEqual(approved,observed);
   bool admin_equal=KingEASpecAdministrativeFieldsEqual(approved,observed);
   bool sessions_equal=KingEASpecSameSessionSet(approved,observed);
   bool trade_equal=(approved.trade_mode==observed.trade_mode);

   if(core_equal && margins_equal && admin_equal && sessions_equal && trade_equal &&
      !ticks_equal && KingEASpecTickProbePasses(request))
      return KINGEA_SPEC_EXPECTED_DYNAMIC;

   if(core_equal && ticks_equal && admin_equal && sessions_equal && trade_equal &&
      !margins_equal && KingEASpecHmrPasses(request) &&
      KingEASpecHmrTightensMargins(approved,observed))
      return KINGEA_SPEC_CONFIRMED_HMR;

   if(core_equal && ticks_equal && margins_equal && admin_equal && sessions_equal &&
      !trade_equal)
      return KINGEA_SPEC_TEMPORARY_RESTRICTION;

   bool sessions_administrative=(sessions_equal ||
                                 (request.administrative_proof_complete &&
                                  request.sessions_strategy_equivalent));
   if(core_equal && ticks_equal && margins_equal && trade_equal &&
      sessions_administrative &&
      request.administrative_proof_complete &&
      (!admin_equal || !sessions_equal))
      return KINGEA_SPEC_ADMINISTRATIVE_CHANGE;

   return KINGEA_SPEC_RISK_CRITICAL_CHANGE;
  }

void KingEASpecSetExposureAction(const KingEASpecificationRequest &request,
                                 KingEASpecificationDecision &decision)
  {
   if(!request.exposure.known)
     {
      decision.action=KINGEA_SPEC_ACTION_QUARANTINE;
      return;
     }
   if(!request.exposure.has_position)
     {
      decision.action=KINGEA_SPEC_ACTION_HOLD;
      return;
     }
   if(!request.exposure.closure_available)
     {
      decision.action=KINGEA_SPEC_ACTION_QUARANTINE;
      return;
     }
   bool invalid=!request.exposure.protective_stop_confirmed ||
                !request.exposure.stop_valid ||
                !request.exposure.volume_valid ||
                request.stressed_margin_level_percent<500.0 ||
                request.stressed_free_margin_ratio<0.80;
   if(!invalid)
     {
      decision.action=KINGEA_SPEC_ACTION_HOLD;
      return;
     }
   decision.action=(request.exposure.reduction_feasible
                    ? KINGEA_SPEC_ACTION_REDUCE
                    : KINGEA_SPEC_ACTION_FLATTEN);
  }

void KingEASpecDefaultDecision(const KingEASpecificationState &prior,
                               KingEASpecificationDecision &decision)
  {
   decision.classification=KINGEA_SPEC_INVALID_OR_STALE;
   decision.action=KINGEA_SPEC_ACTION_QUARANTINE;
   decision.alert=KINGEA_SPEC_ALERT_TIER1;
   decision.entry_allowed=false;
   decision.specification_healthy=false;
   decision.review_required=false;
   decision.revalidation_required=false;
   decision.reset_to_bottom_tier=false;
   decision.preserve_earned_tier=false;
   decision.reason="INVALID_OR_STALE";
   decision.approved_hash="";
   decision.observed_hash="";
   decision.next_state=prior;
  }

void KingEAEvaluateSpecification(const KingEASymbolSpecification &approved,
                                 const KingEASymbolSpecification &observed,
                                 const KingEASpecificationRequest &request,
                                 const KingEASpecificationState &prior,
                                 KingEASpecificationDecision &decision)
  {
   KingEASpecDefaultDecision(prior,decision);
   decision.approved_hash=KingEASpecHash(approved);
   decision.observed_hash=KingEASpecHash(observed);

   if(!KingEASpecValid(approved,request) || !KingEASpecValid(observed,request) ||
      decision.approved_hash=="" || decision.observed_hash=="" ||
      !request.exposure.known)
     {
      if(prior.transient_confirmation_pending)
         decision.next_state.scheduled_confirmation_not_before=request.observed_at+60;
      return;
     }

   KingEASpecificationClassification raw=
      KingEASpecRawClassification(approved,observed,request);

   if(raw==KINGEA_SPEC_UNCHANGED)
     {
      if(prior.awaiting_second_capture)
        {
         decision.classification=KINGEA_SPEC_TRANSIENT_CONFIRMATION;
         decision.action=KINGEA_SPEC_ACTION_HOLD;
         decision.alert=KINGEA_SPEC_ALERT_TIER1;
         decision.reason="TRANSIENT_WAIT_SCHEDULED_POLL";
         decision.next_state.awaiting_second_capture=false;
         decision.next_state.transient_confirmation_pending=true;
         decision.next_state.scheduled_confirmation_not_before=request.observed_at+60;
         decision.next_state.first_observed_hash="";
         return;
        }
      if(prior.transient_confirmation_pending)
        {
         bool scheduled=(request.event==KINGEA_SPEC_EVENT_PERIODIC &&
                         request.observed_at>=prior.scheduled_confirmation_not_before);
         if(!scheduled)
           {
            decision.classification=KINGEA_SPEC_TRANSIENT_CONFIRMATION;
            decision.action=KINGEA_SPEC_ACTION_HOLD;
            decision.alert=KINGEA_SPEC_ALERT_TIER1;
            decision.reason="SCHEDULED_CONFIRMATION_REQUIRED";
            return;
           }
         decision.next_state.transient_confirmation_pending=false;
         decision.next_state.scheduled_confirmation_not_before=0;
        }
      decision.classification=KINGEA_SPEC_UNCHANGED;
      decision.action=KINGEA_SPEC_ACTION_HOLD;
      decision.alert=KINGEA_SPEC_ALERT_NONE;
      decision.entry_allowed=true;
      decision.specification_healthy=true;
      decision.reason="UNCHANGED";
      return;
     }

   if(raw==KINGEA_SPEC_EXPECTED_DYNAMIC || raw==KINGEA_SPEC_CONFIRMED_HMR)
     {
      decision.classification=raw;
      decision.action=KINGEA_SPEC_ACTION_HOLD;
      decision.alert=KINGEA_SPEC_ALERT_NONE;
      decision.entry_allowed=true;
      decision.specification_healthy=true;
      decision.reason=(raw==KINGEA_SPEC_EXPECTED_DYNAMIC
                       ? "EXPECTED_DYNAMIC_TICK_VALUE"
                       : "CONFIRMED_HMR");
      return;
     }

   if(raw==KINGEA_SPEC_TEMPORARY_RESTRICTION)
     {
      decision.classification=raw;
      decision.action=(request.exposure.has_position && !request.exposure.closure_available
                       ? KINGEA_SPEC_ACTION_QUARANTINE
                       : KINGEA_SPEC_ACTION_HOLD);
      decision.alert=KINGEA_SPEC_ALERT_TIER1;
      decision.reason="TEMPORARY_TRADE_RESTRICTION";
      return;
     }

   if(raw==KINGEA_SPEC_ADMINISTRATIVE_CHANGE)
     {
      decision.classification=raw;
      decision.action=KINGEA_SPEC_ACTION_HOLD;
      decision.alert=KINGEA_SPEC_ALERT_TIER2;
      decision.review_required=true;
      decision.preserve_earned_tier=true;
      decision.reason="ADMINISTRATIVE_REVIEW_REQUIRED";
      return;
     }

   if(request.immediate_risk_breach)
     {
      decision.classification=KINGEA_SPEC_RISK_CRITICAL_CHANGE;
      decision.alert=KINGEA_SPEC_ALERT_TIER1;
      decision.review_required=true;
      decision.revalidation_required=true;
      decision.reset_to_bottom_tier=true;
      decision.reason="IMMEDIATE_RISK_BREACH";
      KingEASpecSetExposureAction(request,decision);
      return;
     }

   if(prior.awaiting_second_capture)
     {
      if(prior.first_observed_hash==decision.observed_hash)
        {
         decision.classification=KINGEA_SPEC_RISK_CRITICAL_CHANGE;
         decision.alert=KINGEA_SPEC_ALERT_TIER1;
         decision.review_required=true;
         decision.revalidation_required=true;
         decision.reset_to_bottom_tier=true;
         decision.reason="RISK_CRITICAL_CONFIRMED";
         decision.next_state.awaiting_second_capture=false;
         decision.next_state.first_observed_hash="";
         KingEASpecSetExposureAction(request,decision);
        }
      else
        {
         decision.classification=KINGEA_SPEC_UNSTABLE_CAPTURE;
         decision.action=KINGEA_SPEC_ACTION_QUARANTINE;
         decision.alert=KINGEA_SPEC_ALERT_TIER1;
         decision.review_required=true;
         decision.reason="CAPTURES_DISAGREE";
         decision.next_state.awaiting_second_capture=false;
         decision.next_state.first_observed_hash="";
        }
      return;
     }

   decision.classification=KINGEA_SPEC_CONFIRMATION_REQUIRED;
   decision.action=KINGEA_SPEC_ACTION_HOLD;
   decision.alert=KINGEA_SPEC_ALERT_TIER1;
   decision.reason="SECOND_CAPTURE_REQUIRED";
   decision.next_state.awaiting_second_capture=true;
   decision.next_state.first_observed_hash=decision.observed_hash;
  }

#endif
