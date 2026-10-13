// Prospective controlled-tester lifecycle. Included after the guarded adapter.
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

string DAQuote(string s){StringReplace(s,"\\","\\\\");StringReplace(s,"\"","\\\"");StringReplace(s,"\r","\\r");StringReplace(s,"\n","\\n");return "\""+s+"\"";}
string DANumber(double n){return DAQuote(DoubleToString(n,16));}
string DAFlag(bool v){return v?"true":"false";}
// Only top-level scalar bindings are consumed from the already captured buffer.
// The independently pinned renderer/launcher supplies input authority; these
// copies cannot authorize a root, freeze or execution by themselves.
string DAManifestString(string key){
 string raw=CharArrayToString(g_manifest_input_bytes,0,ArraySize(g_manifest_input_bytes),CP_UTF8);
 int depth=0;string found="";bool seen=false;
 for(int i=0;i<StringLen(raw);i++){
  ushort c=StringGetCharacter(raw,i);if(c=='{')depth++;else if(c=='}')depth--;
  else if(c=='"'){
   int start=++i;bool escaped=false;
   while(i<StringLen(raw)){
    ushort ch=StringGetCharacter(raw,i);if(ch=='\\'){escaped=true;i+=2;continue;}if(ch=='"')break;i++;
   }
   string token=StringSubstr(raw,start,i-start);
   if(depth==1&&!escaped&&token==key){
    if(seen)return "";seen=true;int j=i+1;
    while(j<StringLen(raw)&&StringGetCharacter(raw,j)<=32)j++;
    if(StringGetCharacter(raw,j++)!=':')return "";
    while(j<StringLen(raw)&&StringGetCharacter(raw,j)<=32)j++;
    if(StringGetCharacter(raw,j++)!='"')return "";int end=j;
    while(end<StringLen(raw)&&StringGetCharacter(raw,end)!='"'){if(StringGetCharacter(raw,end)=='\\')return "";end++;}
    found=StringSubstr(raw,j,end-j);i=end;
   }
  }
 }
 return found;
}
bool ResearchNativeContext(){
 if(!DABoundNativeProfile()||!ResearchHash(g_manifest_input_hash)||g_manifest_input_hash!=InpManifestFileSha256)return false;
 if(DAManifestString("candidate_id")!="CAND-ETH-ST-002"||
    DAManifestString("native_cost_contract")!="NATIVE_GROUP_LIFECYCLE_CONTRACT_V3"||
    DAManifestString("package_schema")!="NATIVE_GROUP_LIFECYCLE_PACKAGE_V3"||
    DAManifestString("evidence_semantics")!="PARTIAL_POSITION_COMPONENTS_V1"||
    DAManifestString("filling")!="ORDER_FILLING_FOK"||
    DAManifestString("swap_transition_rule")!="SWAP_TRANSITION_CONSERVATION_V1"||
    DAManifestString("swap_transition_rule_sha256")!="BEE9D303C1FBC804C9F0993685B8CBD2B9FCF43F226CD7BFBA5D73C972C9E772"||
    DAManifestString("inventory_protocol_sha256")!="42E9BAA5FE03DBE0416BBFFA22B0FDA8820AF51E9E16A4F3C67240D01536A7F6")return false;
 g_da_candidate=DAManifestString("candidate_id");g_da_configuration=DAManifestString("configuration_sha256");
 g_da_profile=DAManifestString("tester_profile_sha256");
 return ResearchHash(g_da_configuration)&&ResearchHash(g_da_profile)&&ResearchHash(DAManifestString("source_sha256"));
}
bool ResearchNativeRecord(string role,string payload){
 int n=ArraySize(g_da_records);if(n>=256){g_da.Invalidate("NATIVE_EVIDENCE_OVERFLOW");return false;}
 string hash=ResearchSha256String(payload);
 if(!ResearchNativePersist(StringSubstr(ResearchSha256String(g_da.group),0,24)+"_"+(string)n+"_"+hash,payload)){
  g_da.Invalidate("NATIVE_EVIDENCE_PERSIST_FAILED");return false;
 }
 ArrayResize(g_da_records,n+1);ArrayResize(g_da_record_roles,n+1);g_da_records[n]=payload;g_da_record_roles[n]=role;return true;
}
string DAPositionEvidence(const DAPosition &p){
 return "{\"position_id\":"+(string)p.id+",\"position_ticket\":"+(string)p.ticket+",\"side\":"+(string)p.side+
 ",\"magic\":"+(string)p.magic+",\"symbol\":"+DAQuote(p.symbol)+",\"volume\":"+DANumber(p.volume)+
 ",\"basis\":"+DANumber(p.basis)+",\"sl\":"+DANumber(p.sl)+",\"swap\":"+DANumber(p.swap)+
 ",\"bid\":"+DANumber(p.bid)+",\"ask\":"+DANumber(p.ask)+",\"mark\":"+DANumber(p.mark)+",\"time_msc\":"+(string)p.time_msc+",\"reads\":"+(string)p.reads+",\"valid\":"+DAFlag(p.valid)+"}";
}
bool ResearchNativeBegin(const string group,const int side,const double volume,const long now,const double stop,const double equity,const double risk){
 if(!ResearchNativeContext()||side!=1){g_da.Invalidate("SWAP_PROFILE_NOT_AUTHORIZED");return false;}
 if(!g_da.Begin(group,_Symbol,side,volume,stop,g_da_base,risk,_Digits,(long)g_evaluation_end_exclusive*1000))return false;
 ArrayResize(g_da_records,0);ArrayResize(g_da_record_roles,0);g_da_terminal_count=0;g_da_loss_reported=false;g_da_close_attempted=false;g_da_reduction_attempted=false;
 g_native_start_msc=now;g_native_exit_pending=false;g_native_boundary_projected=false;ZeroMemory(g_da_sealed);
 if(!ResearchNativeRecord("ORIGINAL","{\"run_id\":"+DAQuote(InpManifestSha256)+",\"group_id\":"+DAQuote(group)+
  ",\"configuration_id\":"+(string)InpConfigurationId+",\"V0\":"+DANumber(volume)+",\"S0\":"+DANumber(stop)+",\"E0\":"+DANumber(g_da_base)+",\"R0\":"+DANumber(risk)+
  ",\"profile_hash\":"+DAQuote(g_da_profile)+"}"))return false;
 return g_da.Prepare(DA_ENTRY,volume);
}
bool ResearchNativeRequest(MqlTradeRequest &request,DAIntent intent){
 if(!ResearchNativeContext()) {g_da.Invalidate("TESTER_PROFILE_INVALID");return false;}
 MqlTick tick={};DAPosition now={};
 if(!SymbolInfoTick(_Symbol,tick)||!DAReadPosition(g_da.position_ticket,g_da.position,_Symbol,tick,now))return false;
 if(now.side!=(g_da.side==1?POSITION_TYPE_BUY:POSITION_TYPE_SELL)||now.basis!=g_da.p0||NormalizeDouble(now.sl,_Digits)!=g_da.s0||!DAVolumeEqual(now.volume,g_da.residual.volume)){
  g_da.Invalidate("UNEXPLAINED_POSITION_MODIFICATION");return false;
 }
 g_da.residual=now;
 string role=intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"BEFORE_REQUEST";
 if(!ResearchNativeRecord(role,DAPositionEvidence(now)))return false;
 if(intent==DA_CLOSE&&g_da_close_attempted)return false;
 if(intent==DA_REDUCTION&&g_da_reduction_attempted)return false;
 if(!g_da.Prepare(intent,request.volume))return false;
 if(intent==DA_CLOSE)g_da_close_attempted=true;
 if(intent==DA_REDUCTION)g_da_reduction_attempted=true;
 return ResearchNativeRecord(role+"_INTENT","{\"intent\":"+(string)intent+",\"volume\":"+DANumber(request.volume)+
  ",\"reason\":"+DAQuote(intent==DA_REDUCTION?"SPREAD_ABOVE_2_5X_REDUCE_50_PERCENT":g_da_close_reason)+",\"position\":"+(string)request.position+",\"FOK\":true,\"attempt_consumed\":"+DAFlag(g_da.contained)+"}");
}
void ResearchNativeReceipt(const MqlTradeResult &receipt){
 g_native_receipt=receipt;g_native_receipt_known=true;g_da.order=receipt.order;
 // A broker result.deal volume is not an aggregate-order terminality oracle.
 ResearchNativeRecord(g_da.intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"REQUEST_RESULT",
  "{\"order\":"+(string)receipt.order+",\"deal\":"+(string)receipt.deal+",\"retcode\":"+(string)receipt.retcode+
  ",\"volume\":"+DANumber(receipt.volume)+",\"price\":"+DANumber(receipt.price)+"}");
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result){
 if(ResearchUsesVirtual()||InpZeroEntryDiagnostic||!g_initialized)return;
 // Capture remains active after invalidity. All processing/persistence is deferred.
 g_da_observations.Capture(trans,request,result);g_da_capture.Capture(trans);
}
void ResearchNativePoll(const MqlTick &tick){
 if(ResearchUsesVirtual()||InpZeroEntryDiagnostic||!g_initialized)return;
 if(!ResearchNativeContext())g_da.Invalidate("TESTER_PROFILE_INVALID");
 if(g_da_capture.overflow||g_da_observations.overflow)g_da.Invalidate("TRANSACTION_CAPTURE_OVERFLOW");
 DANativeCapture row={};
 while(g_da_capture.Pop(row)){
  if(row.type==TRADE_TRANSACTION_DEAL_ADD){
   DADeal d=row.deal;
   if(d.type==DEAL_TYPE_BALANCE){ResearchNativeRecord("EXTERNAL_CASH_EVIDENCE",DADealCanonical(d));continue;}
   if(d.type!=DEAL_TYPE_BUY&&d.type!=DEAL_TYPE_SELL){
    g_da.Invalidate("SWAP_PROFILE_OUTSIDE_SUPPORTED_SEMANTICS");
    ResearchNativeRecord("INVALID_NATIVE_FINANCIAL_EVENT",DADealCanonical(d));continue;
   }
   if(!g_da.started){g_da.Invalidate("FOREIGN_DEAL_WITHOUT_GROUP");continue;}
   if(!g_da.pending&&d.position==g_da.position&&d.entry==DEAL_ENTRY_OUT){
    if(d.reason==DEAL_REASON_SL&&NormalizeDouble(d.sl,_Digits)==g_da.s0&&!g_da.projected){
     if(!g_da.Prepare(DA_CLOSE,g_da.residual.volume))g_da.Invalidate("STOP_EXIT_RECONCILIATION_FAILED");
     g_da.order=d.order;
     ResearchNativeRecord("STATIC_PROTECTIVE_STOP_INTENT",DAQuote(g_da.group));
    }else g_da.Invalidate("MANUAL_INTERVENTION_RESEARCH_INVALID");
   }
   g_da.Capture(d);
   if(d.position==g_da.position||g_da.position==0){if(row.position>0)g_da.position_ticket=row.position;}
   ResearchNativeRecord(g_da.intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"DEAL_ADD",DADealCanonical(d));
  }else{
   if(row.symbol!=_Symbol)continue;
   if(g_da_terminal_count==64){g_da.Invalidate("ORDER_CAPTURE_OVERFLOW");continue;}
   g_da_terminals[g_da_terminal_count++]=row;
   ResearchNativeRecord(g_da.intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"ORDER_TERMINAL_OBSERVATION",
    "{\"order\":"+(string)row.order+",\"position\":"+(string)row.position+",\"state\":"+(string)row.order_state+
    ",\"type\":"+(string)row.order_type+",\"unfilled\":"+DANumber(row.unfilled)+",\"symbol\":"+DAQuote(row.symbol)+"}");
  }
 }
 DAObservation observation={};
 while(g_da_observations.Pop(observation)){
  if(observation.type==TRADE_TRANSACTION_POSITION&&g_da.started&&observation.position==g_da.position_ticket)
   g_da.Invalidate("UNEXPLAINED_POSITION_MODIFICATION");
  if(observation.type==TRADE_TRANSACTION_REQUEST&&observation.position==g_da.position_ticket&&observation.action==TRADE_ACTION_SLTP)
   g_da.Invalidate("MANUAL_INTERVENTION_RESEARCH_INVALID");
 }
 if(g_da.pending&&g_da.order>0){
  for(int i=0;i<g_da_terminal_count;i++){
   DANativeCapture t=g_da_terminals[i];if(t.order!=g_da.order)continue;
   bool ended=t.order_state==ORDER_STATE_FILLED||t.order_state==ORDER_STATE_CANCELED||t.order_state==ORDER_STATE_REJECTED||t.order_state==ORDER_STATE_EXPIRED;
   if(!ended)continue;
   long expected_type=g_da.intent==DA_ENTRY?(g_da.side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL):(g_da.side==1?ORDER_TYPE_SELL:ORDER_TYPE_BUY);
   bool valid=MathIsValidNumber(t.unfilled)&&t.unfilled>=0&&t.unfilled<=g_da.requested&&t.order_type==expected_type&&(t.order_state!=ORDER_STATE_FILLED||t.unfilled==0);
   double actual=valid?g_da.requested-t.unfilled:0;
   if(g_da.terminal&&(!valid||!DAVolumeEqual(actual,g_da.executed_target)))g_da.Invalidate("CONFLICTING_ORDER_TERMINALITY");
   else g_da.Receipt(t.order,true,actual,valid,actual==0&&t.order_state!=ORDER_STATE_FILLED);
  }
 }
 DAPosition now={};bool observed=DAReadPosition(g_da.position_ticket,g_da.position,_Symbol,tick,now);
 if(g_da.pending){
  double out=0;bool complete=g_da.terminal&&g_da.execution_volume_authenticated;
  for(int i=0;i<g_da.count;i++){DADeal d=g_da.facts[i];if(d.order!=g_da.order)continue;
   if(!d.valid||d.entry!=DEAL_ENTRY_OUT||d.position!=g_da.position)complete=false;out+=d.volume;
  }
  // Exact terminal OUT set exhausting the prior authenticated volume is flat
  // authority. Failed position selection alone is never used as that authority.
  bool flat=complete&&!observed&&DAVolumeEqual(out,g_da.executed_target)&&DAVolumeEqual(out,g_da.before_volume)&&out>0;
  DAIntent prior=g_da.intent;bool accepted=g_da.Reconcile(now,flat);
  if(accepted){
   ResearchNativeRecord("RECONCILED_POSITION",DAPositionEvidence(g_da.residual));
   if(prior==DA_ENTRY){g_native_entry_captured=true;g_position_ticket=g_da.position_ticket;g_position.entry_price=g_da.p0;g_position.original_confirmed_stop=g_da.s0;}
   if(prior==DA_REDUCTION)g_spread_reduced=true;
   if(prior==DA_CLOSE){g_exits++;g_native_exit_pending=true;g_close_order_ticket=g_da.order;
    for(int i=0;i<g_da.count;i++)if(g_da.facts[i].order==g_da.order)g_close_deal_ticket=g_da.facts[i].ticket;}
  }
  if(!g_da.pending&&g_da.no_fill&&prior==DA_REDUCTION)g_da_fallback_due=true;
 }else if(observed&&g_da.started&&!g_da.projected){
  if(now.id!=g_da.position||now.basis!=g_da.p0||NormalizeDouble(now.sl,_Digits)!=g_da.s0||!DAVolumeEqual(now.volume,g_da.residual.volume))
   g_da.Invalidate("UNEXPLAINED_POSITION_MODIFICATION");
  else g_da.residual=now; // Replace current residual mark/swap; never accumulate snapshots.
 }
 if(g_da.invalid&&!g_da_loss_reported){g_hard_failures++;g_da_loss_reported=true;ResearchNativeRecord("INVALID_LATCHED",DAQuote(g_da.failure));}
 if(g_da.invalid&&!g_da.pending&&!g_da.contained&&g_da.terminal&&g_da.residual.valid&&g_da.residual.volume>0&&ResearchNativeContext()&&
    (g_da.failure=="PARTIAL_ORDER_EXECUTION"||g_da.failure=="FOK_FULL_MULTI_DEAL_UNSUPPORTED_LEDGER_CARDINALITY")){
  MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.magic=12001;r.position=g_da.position_ticket;
  r.volume=g_da.residual.volume;r.type=g_da.side==1?ORDER_TYPE_SELL:ORDER_TYPE_BUY;r.price=g_da.side==1?tick.bid:tick.ask;r.type_filling=ORDER_FILLING_FOK;
  if(ResearchNativeRequest(r,DA_CONTAINMENT)){ResearchOrderSend(r,result);ResearchNativeReceipt(result);}
 }
}
void ResearchNativeSeal(const MqlTick &tick){
 if(ResearchUsesVirtual()||InpZeroEntryDiagnostic||!g_da.started||g_da.invalid||g_da.pending||g_da.projected||!ResearchEvaluationEligible(tick.time))return;
 if(g_da.residual.valid&&g_da.residual.volume>0){g_da_sealed=g_da.residual;g_native_last_eligible_tick=tick.time_msc;}
}
bool ResearchNativeNormalCloseReady(){return g_da.started&&!g_da.invalid&&!g_da.pending&&!g_da.projected&&g_da.exposure==DA_FLAT&&g_native_exit_pending;}
void ResearchNativeNormalCloseCommitted(){if(!g_da.Commit())g_hard_failures++;}
bool ResearchNativeProject(bool boundary){
 if(g_da.invalid||g_hard_failures!=0||g_da.pending||g_da.projected)return false;
 if(boundary){if(g_native_exit_pending||!g_da_sealed.valid||g_da_sealed.time_msc!=g_native_last_eligible_tick)return false;g_da.residual=g_da_sealed;}
 long time=g_da.residual.time_msc;
 if(!boundary){time=0;for(int i=0;i<g_da.count;i++)if(g_da.facts[i].order==g_da.order)time=g_da.facts[i].time_msc;}
 KingEAAccountingEvent event=ResearchAccountingBase(KINGEA_ACCOUNTING_EVENT_TRADE_GROUP_CLOSE,"V3-CLOSE-"+ResearchSha256String(g_da.group),time);
 event.trade_group_id=g_da.group;event.direction=g_da.side;event.volume=g_da.v0;event.protective_stop=g_da.s0;
 event.order_ticket=boundary?0:g_close_order_ticket;event.deal_ticket=boundary?0:g_close_deal_ticket;event.position_ticket=g_da.position_ticket;
 event.reason_code=boundary?"EVALUATOR_BOUNDARY":"TRADE_GROUP_CLOSE";event.source_quality="NATIVE_GROUP_LIFECYCLE_V3";
 if(!g_da.Projection(boundary,event))return false;
 double net=event.gross_profit+event.commission+event.fee+event.swap;event.account_equity=g_da_base+net;event.sleeve_equity=event.account_equity;
 KingEAAccountingDecision decision={};KingEAProcessAccountingEvent(event,g_accounting_checkpoint,decision);
 if(!decision.accepted)return false;
 string prior=g_accounting_checkpoint.ledger_root_sha256;if(prior=="")StringInit(prior,64,'0');
 string canonical=KingEAAccountingCanonical(event,decision.sequence,prior);
 if(!ResearchNativeRecord("TERMINAL_POSITION",DAPositionEvidence(g_da.residual)))return false;
 if(!ResearchNativeRecord("STAGE13_PREPARED",canonical))return false;
 // Prepared evidence is durable before the atomic financial handoff. A later
 // persistence failure invalidates the run and cannot authorize another projection.
 double base_before=g_da_base;
 if(!g_da.Commit())return false;
 g_accounting_checkpoint=decision.next_checkpoint;g_da_base+=net;
 if(!ResearchNativeRecord("STAGE13_COMMITTED","{\"event_hash\":"+DAQuote(decision.event_sha256)+
  ",\"prior_root\":"+DAQuote(prior)+",\"base_before\":"+DANumber(base_before)+",\"base_after\":"+DANumber(g_da_base)+
  ",\"contribution_after\":\"0\",\"financial_projection_count\":1,\"atomic_handoff\":true}"))return false;
 string records="[";for(int i=0;i<ArraySize(g_da_records);i++){if(i>0)records+=",";records+="{\"role\":"+DAQuote(g_da_record_roles[i])+",\"payload\":"+DAQuote(g_da_records[i])+"}";}records+="]";
 string capture="{\"kind\":\"NATIVE_LIFECYCLE_CAPTURE_V3\",\"run_id\":"+DAQuote(InpManifestSha256)+",\"group_id\":"+DAQuote(g_da.group)+
  ",\"outcome\":"+DAQuote(boundary?"EVALUATOR_BOUNDARY":"NORMAL_CLOSE")+",\"records\":"+records+"}";
 if(!ResearchNativePersist("V3_CAPTURE_"+ResearchSha256String(g_da.group),capture)){g_da.Invalidate("COMMITTED_CAPTURE_PERSIST_FAILED");g_hard_failures++;return false;}
 int n=ArraySize(g_accounting_payloads);ArrayResize(g_accounting_payloads,n+1);g_accounting_payloads[n]=KingEAAccountingFramePayload(event,decision);
 int count=ArraySize(g_trade_net);ArrayResize(g_trade_net,count+1);ArrayResize(g_trade_returns,count+1);ArrayResize(g_trade_r,count+1);
 g_trade_net[count]=net;g_trade_returns[count]=event.net_return;g_trade_r[count]=event.net_r;g_accounting_close_count++;
 uchar frame[];int bytes=StringToCharArray(capture,frame,0,WHOLE_ARRAY,CP_UTF8);if(bytes>0)ArrayResize(frame,bytes-1);
 if(bytes<=0||!FrameAdd("KINGEA_V3_NATIVE_CAPTURE",InpConfigurationId,0.0,frame)){g_da.Invalidate("CAPTURE_FRAME_FAILED");g_hard_failures++;return false;}
 if(boundary){g_native_boundary_projected=true;g_native_boundary_equity=g_da_base;g_boundary_finalization_count++;}
 KingEASafetyFacts facts={};ResearchHealthyFacts(TimeCurrent(),g_da.p0,g_da.s0,g_da.side,facts);
 KingEASafetyRequest closed={};closed.event=KINGEA_EVENT_CLOSED_TRADE_GROUP;closed.scope=KINGEA_SCOPE_SLEEVE;
 closed.closed_group_full_loss=event.net_r<=-0.80;KingEASafetyDecision safety={};KingEAEvaluateSafety(closed,facts,g_safety_state,safety);
 g_safety_state=safety.next_state;if(safety.action==KINGEA_ACTION_QUARANTINE){g_hard_failures++;g_da.Invalidate("SAFETY_QUARANTINE");}
 ZeroMemory(g_position);g_trade_group_id="";g_native_exit_pending=false;return !g_da.invalid;
}
bool ResearchNativeBoundaryFinalize(){
 if(ResearchUsesVirtual()||InpZeroEntryDiagnostic||InpWorkloadDryRun||g_da.invalid)return false;
 if(g_da.projected)return g_native_boundary_projected;
 if(ResearchNativeNormalCloseReady())return ResearchNativeProject(false);
 return ResearchNativeProject(true);
}

void ResearchNativeSafetyObserve(const MqlTick &tick){
 // Observations continue after invalidity. Decisions do not create any new
 // order authority or retry; only the adopted containment seam may submit.
 if(!g_da.residual.valid||g_da.pending||g_da.position==0)return;
 double contribution=0;if(!g_da.OperationalContribution(contribution))return;
 KingEASafetyFacts facts={};ResearchHealthyFacts(tick.time,g_da.p0,g_da.s0,g_da.side,facts);
 facts.exposure_reconciled=true;facts.unknown_exposure=false;
 KingEASafetyRequest request={};request.event=KINGEA_EVENT_POSITION_REVIEW;request.scope=KINGEA_SCOPE_SLEEVE;
 request.position_present=g_da.residual.volume>0;request.position_volume=g_da.residual.volume;
 KingEASafetyDecision decision={};KingEAEvaluateSafety(request,facts,g_safety_state,decision);g_safety_state=decision.next_state;
}

bool ResearchNativeCompletion(){
 if(g_da.invalid||g_da.pending||g_hard_failures!=0||!ResearchNativeContext())return false;
 string value="{\"kind\":\"NATIVE_V3_COMPLETION\",\"run_id\":"+DAQuote(InpManifestSha256)+
  ",\"configuration_id\":"+(string)InpConfigurationId+",\"profile_hash\":"+DAQuote(g_da_profile)+
  ",\"group_count\":"+(string)g_accounting_close_count+",\"boundary_count\":"+(string)g_boundary_finalization_count+
  ",\"research_invalid\":false,\"containment_attempted\":false,\"unsupported_financial_events\":[],\"complete\":1}";
 if(!ResearchNativePersist("V3_COMPLETION",value))return false;
 uchar frame[];int n=StringToCharArray(value,frame,0,WHOLE_ARRAY,CP_UTF8);if(n>0)ArrayResize(frame,n-1);
 return n>0&&FrameAdd("KINGEA_V3_NATIVE_COMPLETE",InpConfigurationId,0.0,frame);
}
