// Prospective controlled-tester lifecycle. Included after the guarded adapter.
bool ResearchNativePersist(const string name,const string value)
  {
   string folder="KingEA\\stage14_spool\\"+InpManifestSha256;
   FolderCreate(folder,FILE_COMMON);
   string evidence_key=ResearchSha256String(name);
   string file=folder+"\\NATIVE_COST_"+
      (string)InpConfigurationId+"_"+evidence_key+".evidence";
   if(FileIsExist(file,FILE_COMMON))
     {
      int r=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
      if(r==INVALID_HANDLE) return false;
      string old=FileReadString(r); FileClose(r); return old==value;
     }
   ResetLastError();
   int h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   int write_open_error=GetLastError();
   if(h==INVALID_HANDLE)
     {
      string common_root=TerminalInfoString(TERMINAL_COMMONDATA_PATH);
      PrintFormat("KINGEA_NATIVE_PERSIST_WRITE_OPEN_FAIL|error_code=%d|handle=%d|relative_path=%s|relative_path_length=%d|manifest_sha256=%s|configuration_id=%d|terminal_common_data_root=%s",
                  write_open_error,h,file,StringLen(file),InpManifestSha256,InpConfigurationId,common_root);
      return false;
     }
   bool ok=FileWriteString(h,value)==StringLen(value); FileClose(h); return ok;
  }

string DAQuote(string s){StringReplace(s,"\\","\\\\");StringReplace(s,"\"","\\\"");StringReplace(s,"\r","\\r");StringReplace(s,"\n","\\n");return "\""+s+"\"";}
string DANumber(double n){return DAQuote(DoubleToString(n,16));}
string DAAccountingNumber(double n){return DAQuote(DoubleToString(n,8));}
string DAFlag(bool v){return v?"true":"false";}
// Diagnostic journal only: capture identity never enters conformance markers or trading predicates.
int g_da_terminal_diagnostic_evaluations[64];
bool ResearchTerminalityDiagnosticEnabled(){
 return InpNativeConformance&&InpPurpose=="NON_CANDIDATE_NATIVE_CONFORMANCE_V1"&&
        MQLInfoInteger(MQL_TESTER)&&g_initialized;
}
void ResearchTerminalityCaptureDiagnostic(const DANativeCapture &row){
 if(!ResearchTerminalityDiagnosticEnabled())return;
 PrintFormat("KINGEA_NATIVE_TRANSACTION_CAPTURE|capture_sequence=%I64u|transaction_type=%d|order=%I64u|deal=%I64u|position=%I64u|order_state=%d|order_type=%d|raw_transaction_volume=%s|symbol=%s",
             row.capture_sequence,row.type,row.order,row.deal_ticket,row.position,
             row.order_state,row.order_type,DoubleToString(row.raw_transaction_volume,16),row.symbol);
}
void ResearchTerminalityEvaluationDiagnostic(const DANativeCapture &row,const int evaluation_count){
 if(!ResearchTerminalityDiagnosticEnabled())return;
 PrintFormat("KINGEA_NATIVE_TERMINAL_EVALUATION|capture_sequence=%I64u|evaluation_count=%d|transaction_type=%d|order=%I64u|raw_transaction_volume=%s",
             row.capture_sequence,evaluation_count,row.type,row.order,DoubleToString(row.raw_transaction_volume,16));
}
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
bool DAConformanceLayerAClosed(){
 string raw=CharArrayToString(g_manifest_input_bytes,0,ArraySize(g_manifest_input_bytes),CP_UTF8);
 string keys[]={"S0","close_msc","configuration_sha256","data_scope","domain","end_msc","entry_msc","execution_mode","fixture_id","group_id","inventory_protocol_sha256","optimization","outcome","reduction_msc","run_id","side","source_sha256","start_msc","swap_transition_rule_sha256","symbol","volume"};
 int depth=0,count=0;
 for(int i=0;i<StringLen(raw);i++){
  ushort c=StringGetCharacter(raw,i);if(c=='{')depth++;else if(c=='}')depth--;
  else if(c=='"'){
   int start=++i;bool escaped=false;
   while(i<StringLen(raw)){ushort ch=StringGetCharacter(raw,i);if(ch=='\\'){escaped=true;i+=2;continue;}if(ch=='"')break;i++;}
   if(depth==1&&!escaped){int j=i+1;while(j<StringLen(raw)&&StringGetCharacter(raw,j)<=32)j++;
    if(j<StringLen(raw)&&StringGetCharacter(raw,j)==':'){
     string key=StringSubstr(raw,start,i-start);bool known=false;
     for(int k=0;k<ArraySize(keys);k++)if(key==keys[k]){known=true;break;}
     if(!known)return false;count++;
    }
   }
  }
  if(depth<0||depth>1)return false;
 }
 if(depth!=0||count!=ArraySize(keys)||DAManifestString("control_sha256")!=""||DAManifestString("tester_profile_sha256")!="")return false;
 for(int k=0;k<ArraySize(keys);k++)if(DAManifestString(keys[k])=="")return false;
 return true;
}
bool ResearchConformanceContext(){
 if(!ResearchConformanceValid())return false;
 g_da_candidate="NON_CANDIDATE_NATIVE_CONFORMANCE_V1";
 g_da_configuration=DAManifestString("configuration_sha256");g_da_profile=InpConformanceRuntimeProfileSha256;
 return ResearchHash(g_da_configuration)&&ResearchHash(g_da_profile);
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
bool ResearchActiveNativeContext(){
 return InpNativeConformance?ResearchConformanceContext():ResearchNativeContext();
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
 if(!ResearchActiveNativeContext()||(!InpNativeConformance&&side!=1)||(InpNativeConformance&&side!=(DAManifestString("side")=="LONG"?1:-1))){g_da.Invalidate("SWAP_PROFILE_NOT_AUTHORIZED");return false;}
 if(!g_da.Begin(group,_Symbol,side,volume,stop,g_da_base,risk,_Digits,(long)g_evaluation_end_exclusive*1000))return false;
 ArrayResize(g_da_records,0);ArrayResize(g_da_record_roles,0);g_da_terminal_count=0;g_da_loss_reported=false;g_da_close_attempted=false;g_da_reduction_attempted=false;
 g_native_start_msc=now;g_native_exit_pending=false;g_native_boundary_projected=false;ZeroMemory(g_da_sealed);
 if(!ResearchNativeRecord("ORIGINAL","{\"run_id\":"+DAQuote(InpManifestSha256)+",\"group_id\":"+DAQuote(group)+
  ",\"configuration_id\":"+(string)InpConfigurationId+",\"V0\":"+DANumber(volume)+",\"S0\":"+DANumber(stop)+",\"E0\":"+DANumber(g_da_base)+",\"R0\":"+DANumber(risk)+
  ",\"profile_hash\":"+DAQuote(g_da_profile)+(InpNativeConformance?",\"evidence_scope\":\"NON_CANDIDATE_NATIVE_CONFORMANCE\",\"fixture_id\":"+DAQuote(DAManifestString("fixture_id")):"")+"}"))return false;
 return g_da.Prepare(DA_ENTRY,volume);
}
bool ResearchNativeRequest(MqlTradeRequest &request,DAIntent intent){
 if(!ResearchActiveNativeContext()) {g_da.Invalidate("TESTER_PROFILE_INVALID");return false;}
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
 if(!g_da_last_send_attempted){g_native_receipt_known=false;ResearchNativeRecord("ORDER_SEND_NOT_ATTEMPTED",DAQuote(g_da.failure));return;}
 g_native_receipt=receipt;g_native_receipt_known=true;g_da.order=receipt.order;
 // A broker result.deal volume is not an aggregate-order terminality oracle.
 ResearchNativeRecord(g_da.intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"REQUEST_RESULT",
  "{\"order\":"+(string)receipt.order+",\"deal\":"+(string)receipt.deal+",\"retcode\":"+(string)receipt.retcode+
   ",\"volume\":"+DANumber(receipt.volume)+",\"price\":"+DANumber(receipt.price)+"}");
}
// ORDER_DELETE is retained as transitional evidence only. For this tester
// path, only a valid completed HISTORY_ADD snapshot can authorize lifecycle
// terminality; transaction arrival order is not used as causal authority.
bool ResearchNativeAuthoritativeTerminal(const DANativeCapture &t,double &actual){
 if(t.type!=TRADE_TRANSACTION_HISTORY_ADD)return false;
 bool ended=t.order_state==ORDER_STATE_FILLED||t.order_state==ORDER_STATE_CANCELED||
            t.order_state==ORDER_STATE_REJECTED||t.order_state==ORDER_STATE_EXPIRED;
 if(!ended)return false;
 long expected_type=g_da.intent==DA_ENTRY?(g_da.side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL):
                     (g_da.side==1?ORDER_TYPE_SELL:ORDER_TYPE_BUY);
 bool valid=MathIsValidNumber(t.unfilled)&&t.unfilled>=0&&t.unfilled<=g_da.requested&&
            t.order_type==expected_type&&
            (t.order_state!=ORDER_STATE_FILLED||t.unfilled==0);
 if(!valid)return false;
 actual=g_da.requested-t.unfilled;
 return MathIsValidNumber(actual)&&actual>=0;
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result){
 if(ResearchUsesVirtual()||InpZeroEntryDiagnostic||!g_initialized)return;
 // Capture remains active after invalidity. All processing/persistence is deferred.
 g_da_observations.Capture(trans,request,result);g_da_capture.Capture(trans);
}
void ResearchNativePoll(const MqlTick &tick){
 if(ResearchUsesVirtual()||InpZeroEntryDiagnostic||!g_initialized)return;
 if(!ResearchActiveNativeContext())g_da.Invalidate("TESTER_PROFILE_INVALID");
 if(g_da_capture.overflow||g_da_observations.overflow)g_da.Invalidate("TRANSACTION_CAPTURE_OVERFLOW");
  DANativeCapture row={};
  while(g_da_capture.Pop(row)){
   ResearchTerminalityCaptureDiagnostic(row);
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
    g_da_terminal_diagnostic_evaluations[g_da_terminal_count]=0;
    g_da_terminals[g_da_terminal_count++]=row;
    ResearchNativeRecord(g_da.intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"ORDER_TERMINAL_OBSERVATION",
     "{\"order\":"+(string)row.order+",\"position\":"+(string)row.position+",\"state\":"+(string)row.order_state+
     ",\"type\":"+(string)row.order_type+",\"unfilled\":"+DANumber(row.unfilled)+",\"symbol\":"+DAQuote(row.symbol)+
     ",\"transaction_type\":"+(string)row.type+",\"capture_sequence\":"+(string)row.capture_sequence+
     ",\"raw_transaction_volume\":"+DANumber(row.raw_transaction_volume)+"}");
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
    if(ResearchTerminalityDiagnosticEnabled()&&g_da_terminal_diagnostic_evaluations[i]<2){
     g_da_terminal_diagnostic_evaluations[i]++;
     ResearchTerminalityEvaluationDiagnostic(t,g_da_terminal_diagnostic_evaluations[i]);
    }
     double actual=0;
     if(!ResearchNativeAuthoritativeTerminal(t,actual))continue;
    bool no_fill=actual==0&&t.order_state!=ORDER_STATE_FILLED;
    bool conflicting_authority=false;
    for(int j=0;j<i;j++){
     DANativeCapture prior=g_da_terminals[j];double prior_actual=0;
     if(prior.order==t.order&&ResearchNativeAuthoritativeTerminal(prior,prior_actual)){
      bool prior_no_fill=prior_actual==0&&prior.order_state!=ORDER_STATE_FILLED;
      if(prior.position!=t.position||prior.order_type!=t.order_type||prior.symbol!=t.symbol||
         !DAVolumeEqual(prior_actual,actual)||prior_no_fill!=no_fill)conflicting_authority=true;
     }
    }
    if(conflicting_authority||(g_da.terminal&&
       (!DAVolumeEqual(actual,g_da.executed_target)||no_fill!=g_da.no_fill)))
     g_da.Invalidate("CONFLICTING_ORDER_TERMINALITY");
    else g_da.Receipt(t.order,true,actual,true,no_fill);
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
 if(g_da.invalid&&!g_da.pending&&!g_da.contained&&g_da.terminal&&g_da.residual.valid&&g_da.residual.volume>0&&ResearchActiveNativeContext()&&
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
  ",\"prior_root\":"+DAQuote(prior)+",\"base_before\":"+DAAccountingNumber(base_before)+",\"base_after\":"+DAAccountingNumber(g_da_base)+
  ",\"contribution_after\":\"0\",\"financial_projection_count\":1,\"atomic_handoff\":true}"))return false;
 string records="[";for(int i=0;i<ArraySize(g_da_records);i++){if(i>0)records+=",";records+="{\"role\":"+DAQuote(g_da_record_roles[i])+",\"payload\":"+DAQuote(g_da_records[i])+"}";}records+="]";
 string capture="{\"kind\":\"NATIVE_LIFECYCLE_CAPTURE_V3\",\"run_id\":"+DAQuote(InpManifestSha256)+",\"group_id\":"+DAQuote(g_da.group)+
  ",\"outcome\":"+DAQuote(boundary?"EVALUATOR_BOUNDARY":"NORMAL_CLOSE")+",\"records\":"+records+"}";
 string capture_name="V3_CAPTURE_"+ResearchSha256String(g_da.group)+"_"+InpConformanceControlSha256;
 if(!ResearchNativePersist(capture_name,capture)){g_da.Invalidate("COMMITTED_CAPTURE_PERSIST_FAILED");g_hard_failures++;return false;}
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
 if(g_da.invalid||g_da.pending||g_hard_failures!=0||!ResearchActiveNativeContext())return false;
 string value="{\"kind\":"+DAQuote(InpNativeConformance?"NON_CANDIDATE_CONFORMANCE_COMPLETION":"NATIVE_V3_COMPLETION")+",\"run_id\":"+DAQuote(InpManifestSha256)+
  ",\"configuration_id\":"+(string)InpConfigurationId+",\"profile_hash\":"+DAQuote(g_da_profile)+
  ",\"group_count\":"+(string)g_accounting_close_count+",\"boundary_count\":"+(string)g_boundary_finalization_count+
  ",\"research_invalid\":false,\"containment_attempted\":false,\"unsupported_financial_events\":[],\"complete\":1}";
 string completion_name=InpNativeConformance?"V3_COMPLETION_"+InpConformanceControlSha256:"V3_COMPLETION";
 if(!ResearchNativePersist(completion_name,value))return false;
 uchar frame[];int n=StringToCharArray(value,frame,0,WHOLE_ARRAY,CP_UTF8);if(n>0)ArrayResize(frame,n-1);
 return n>0&&FrameAdd("KINGEA_V3_NATIVE_COMPLETE",InpConfigurationId,0.0,frame);
}

// Fixed infrastructure dispatcher. No Candidate signal evaluation or adaptive schedule.
string g_conformance_validation_reason="";
bool ResearchConformanceReject(const string reason){g_conformance_validation_reason=reason;return false;}
bool ResearchConformanceValid(){
 g_conformance_validation_reason="";
 if(!InpNativeConformance)return ResearchConformanceReject("NATIVE_CONFORMANCE_DISABLED");
 if(!MQLInfoInteger(MQL_TESTER))return ResearchConformanceReject("MQL_TESTER_FALSE");
 if(MQLInfoInteger(MQL_OPTIMIZATION))return ResearchConformanceReject("MQL_OPTIMIZATION_TRUE");
 if(!DAConformanceBoundNativeProfile(InpConformanceExpectedTerminalBuild))return ResearchConformanceReject("BOUND_NATIVE_PROFILE_INVALID");
 if(InpPurpose!="NON_CANDIDATE_NATIVE_CONFORMANCE_V1")return ResearchConformanceReject("PURPOSE_MISMATCH");
 if(InpGate!="0")return ResearchConformanceReject("GATE_NOT_ZERO");
 if(InpRootSha256!="")return ResearchConformanceReject("ROOT_NOT_EMPTY");
 if(InpDetachedAuthorizationToken!="")return ResearchConformanceReject("DETACHED_AUTHORIZATION_NOT_EMPTY");
 if(InpConfigurationId!=0)return ResearchConformanceReject("CONFIGURATION_ID_NOT_ZERO");
 if(InpZeroEntryDiagnostic)return ResearchConformanceReject("ZERO_ENTRY_DIAGNOSTIC_ENABLED");
 if(InpWorkloadDryRun)return ResearchConformanceReject("WORKLOAD_DRY_RUN_ENABLED");
 if(InpBranch!="RECORDED")return ResearchConformanceReject("BRANCH_MISMATCH");
 if(InpScenario!="BASELINE_20MS")return ResearchConformanceReject("SCENARIO_MISMATCH");
 if(InpSpreadMultiplier!=1.0)return ResearchConformanceReject("SPREAD_MULTIPLIER_MISMATCH");
 if(InpCostMultiplier!=1.0)return ResearchConformanceReject("COST_MULTIPLIER_MISMATCH");
 if(InpSlippageSpreadFraction!=0)return ResearchConformanceReject("SLIPPAGE_FRACTION_NONZERO");
 if(InpVolatilityDependentSlippage)return ResearchConformanceReject("VOLATILITY_SLIPPAGE_ENABLED");
 if(InpMissedEntryFraction!=0)return ResearchConformanceReject("MISSED_ENTRY_FRACTION_NONZERO");
 if(InpExecutionAdapter!="NATIVE")return ResearchConformanceReject("EXECUTION_ADAPTER_MISMATCH");
 if(InpDelayMs!=20)return ResearchConformanceReject("DELAY_MISMATCH");
 if(InpTesterModel!=4)return ResearchConformanceReject("TESTER_MODEL_MISMATCH");
 if(!InpLocalAgentsOnly)return ResearchConformanceReject("LOCAL_AGENTS_ONLY_FALSE");
 if(!InpRemoteAgentsDisabled)return ResearchConformanceReject("REMOTE_AGENTS_ENABLED");
 if(!InpCloudAgentsDisabled)return ResearchConformanceReject("CLOUD_AGENTS_ENABLED");
 if(!ResearchEvaluationWindowValid())return ResearchConformanceReject("EVALUATION_WINDOW_INVALID");
 if(!ResearchHash(InpConformanceControlSha256))return ResearchConformanceReject("CONTROL_HASH_INVALID");
 if(!ResearchHash(InpConformanceRuntimeProfileSha256))return ResearchConformanceReject("RUNTIME_PROFILE_HASH_INVALID");
 if(ResearchFileSha256(InpRunManifest)!=InpManifestFileSha256)return ResearchConformanceReject("MANIFEST_FILE_HASH_MISMATCH");
 if(!ResearchHash(InpManifestFileSha256))return ResearchConformanceReject("MANIFEST_FILE_HASH_INVALID");
 if(ResearchFileSha256(InpCalendarIntervalsFile)!=InpCalendarFileSha256)return ResearchConformanceReject("CALENDAR_FILE_HASH_MISMATCH");
 if(!ResearchHash(InpCalendarFileSha256))return ResearchConformanceReject("CALENDAR_FILE_HASH_INVALID");
 if(!DAConformanceLayerAClosed())return ResearchConformanceReject("LAYER_A_SCHEMA_INVALID");
 if(DAManifestString("domain")!="NON_CANDIDATE_NATIVE_CONFORMANCE_V1")return ResearchConformanceReject("DOMAIN_MISMATCH");
 if(DAManifestString("run_id")!=InpManifestSha256)return ResearchConformanceReject("RUN_ID_MISMATCH");
 if(DAManifestString("data_scope")!="DEVELOPMENT_ONLY")return ResearchConformanceReject("DATA_SCOPE_MISMATCH");
 if(DAManifestString("swap_transition_rule_sha256")!="BEE9D303C1FBC804C9F0993685B8CBD2B9FCF43F226CD7BFBA5D73C972C9E772")return ResearchConformanceReject("SWAP_TRANSITION_HASH_MISMATCH");
 if(DAManifestString("inventory_protocol_sha256")!="42E9BAA5FE03DBE0416BBFFA22B0FDA8820AF51E9E16A4F3C67240D01536A7F6")return ResearchConformanceReject("INVENTORY_PROTOCOL_HASH_MISMATCH");
 string side=DAManifestString("side");
 long start=(long)StringToInteger(DAManifestString("start_msc")),end=(long)StringToInteger(DAManifestString("end_msc"));
 long entry=(long)StringToInteger(DAManifestString("entry_msc")),reduce=(long)StringToInteger(DAManifestString("reduction_msc")),close=(long)StringToInteger(DAManifestString("close_msc"));
 if(start!=(long)g_evaluation_start*1000)return ResearchConformanceReject("START_TIME_MISMATCH");
 if(end!=(long)g_evaluation_end_exclusive*1000)return ResearchConformanceReject("END_TIME_MISMATCH");
 if(start>entry)return ResearchConformanceReject("ENTRY_BEFORE_START");
 if(entry>=reduce)return ResearchConformanceReject("ENTRY_REDUCTION_ORDER_INVALID");
 if(reduce>=end)return ResearchConformanceReject("REDUCTION_AFTER_END");
 bool boundary=DAManifestString("outcome")=="EVALUATOR_BOUNDARY";
 if(boundary&&close!=0)return ResearchConformanceReject("BOUNDARY_CLOSE_NONZERO");
 if(!boundary&&DAManifestString("outcome")!="NORMAL_CLOSE")return ResearchConformanceReject("OUTCOME_INVALID");
 if(!boundary&&close<=reduce)return ResearchConformanceReject("CLOSE_NOT_AFTER_REDUCTION");
 if(!boundary&&close>=end)return ResearchConformanceReject("CLOSE_AFTER_END");
 if(side!="LONG"&&side!="SHORT")return ResearchConformanceReject("SIDE_INVALID");
 if(StringToDouble(DAManifestString("volume"))<=0)return ResearchConformanceReject("VOLUME_NONPOSITIVE");
 if(StringToDouble(DAManifestString("S0"))<=0)return ResearchConformanceReject("S0_NONPOSITIVE");
 return true;
}
void ResearchConformanceTick(const MqlTick &tick){
 bool valid=ResearchConformanceValid();
 if(valid&&!g_obs_revalidation_pass){g_obs_revalidation_pass=true;ResearchConformanceObserve("OBS_CONFORMANCE_REVALIDATION_PASS",tick.time_msc,0,"CONFORMANCE_REVALIDATION_PASS","{}");}
 if(!valid&&!g_obs_revalidation_fail){g_obs_revalidation_fail=true;ResearchConformanceObserve("OBS_CONFORMANCE_REVALIDATION_FAIL",tick.time_msc,0,g_conformance_validation_reason,"{}");}
 if(!valid){g_da.Invalidate("CONFORMANCE_CONTEXT_LOST");g_hard_failures++;}
 ResearchNativePoll(tick);
 if(g_da.invalid){ResearchNativeSafetyObserve(tick);return;}
 ResearchFinalizeClosedTrade();
 if(g_da_fallback_due&&!g_da.pending){g_da_fallback_due=false;g_cf_close_attempted=true;g_da_close_reason="BROKER_VOLUME_FALLBACK";ResearchClose(g_position.direction,tick);g_da_close_reason="STRATEGY_CLOSE";}
 ResearchUpdateSpreadState(tick);ResearchUpdatePeriodsFast(tick.time);ResearchNativeSafetyObserve(tick);
 if(tick.time_msc>=(long)g_evaluation_end_exclusive*1000){ResearchNativeBoundaryFinalize();return;}
 if(!ResearchEvaluationEligible(tick.time)||g_da.projected)return;
 long entry=(long)StringToInteger(DAManifestString("entry_msc")),reduce=(long)StringToInteger(DAManifestString("reduction_msc")),close=(long)StringToInteger(DAManifestString("close_msc"));
 int side=DAManifestString("side")=="LONG"?1:-1;
 if(!g_cf_entry_attempted&&tick.time_msc<entry&&!g_obs_pre_entry_tick){g_obs_pre_entry_tick=true;ResearchConformanceObserve("OBS_PRE_ENTRY_TICK",tick.time_msc,entry,"PRE_ENTRY_TICK","{\"reduction_msc\":"+(string)reduce+"}");}
 if(!g_cf_entry_attempted&&tick.time_msc>=entry&&!g_obs_entry_time_reached){g_obs_entry_time_reached=true;ResearchConformanceObserve("OBS_ENTRY_TIME_REACHED",tick.time_msc,entry,"ENTRY_TIME_REACHED","{\"reduction_msc\":"+(string)reduce+"}");}
 if(!g_cf_entry_attempted&&tick.time_msc>=entry){
  g_cf_entry_attempted=true;
  ResearchConformanceObserve("OBS_ENTRY_LATCHED",tick.time_msc,entry,"ENTRY_LATCHED","{\"reduction_msc\":"+(string)reduce+"}");
  if(tick.time_msc>=reduce){ResearchConformanceObserve("OBS_ENTRY_WINDOW_REJECT",tick.time_msc,entry,"FIXTURE_ENTRY_WINDOW_MISSED","{\"reduction_msc\":"+(string)reduce+"}");g_da.Invalidate("FIXTURE_ENTRY_WINDOW_MISSED");return;}
  ResearchConformanceObserve("OBS_ENTRY_WINDOW_PASS",tick.time_msc,entry,"ENTRY_WINDOW_PASS","{\"reduction_msc\":"+(string)reduce+"}");
  double volume=StringToDouble(DAManifestString("volume")),stop=StringToDouble(DAManifestString("S0")),price=side==1?tick.ask:tick.bid,risk=0;
  if((side==1&&stop>=price)||(side==-1&&stop<=price)){ResearchConformanceObserve("OBS_STOP_GEOMETRY_FAIL",tick.time_msc,entry,"STOP_GEOMETRY_INVALID","{\"side\":"+(string)side+",\"price\":"+DAQuote(DoubleToString(price,16))+",\"stop\":"+DAQuote(DoubleToString(stop,16))+"}");g_da.Invalidate("FIXTURE_STOP_OR_RISK_INVALID");return;}
  if(!OrderCalcProfit(side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,price,stop,risk)){ResearchConformanceObserve("OBS_ORDER_CALC_PROFIT_FAIL",tick.time_msc,entry,"ORDER_CALC_PROFIT_FALSE","{\"side\":"+(string)side+",\"volume\":"+DAQuote(DoubleToString(volume,16))+",\"price\":"+DAQuote(DoubleToString(price,16))+",\"stop\":"+DAQuote(DoubleToString(stop,16))+"}");g_da.Invalidate("FIXTURE_STOP_OR_RISK_INVALID");return;}
  if(risk>=0){ResearchConformanceObserve("OBS_RISK_NONPOSITIVE",tick.time_msc,entry,"CALCULATED_LOSS_NOT_NEGATIVE","{\"raw_profit\":"+DAQuote(DoubleToString(risk,16))+"}");g_da.Invalidate("FIXTURE_STOP_OR_RISK_INVALID");return;}
  ResearchConformanceObserve("OBS_RISK_VALID",tick.time_msc,entry,"RISK_VALID","{\"raw_profit\":"+DAQuote(DoubleToString(risk,16))+",\"risk_money\":"+DAQuote(DoubleToString(-risk,16))+"}");
  string group=DAManifestString("group_id");
  ResearchConformanceObserve("OBS_NATIVE_BEGIN_ENTER",tick.time_msc,entry,"NATIVE_BEGIN_ENTER","{}");
  bool begun=ResearchNativeBegin(group,side,volume,tick.time_msc,stop,g_da_base,-risk);
  ResearchConformanceObserve(begun?"OBS_NATIVE_BEGIN_PASS":"OBS_NATIVE_BEGIN_FAIL",tick.time_msc,entry,begun?"NATIVE_BEGIN_PASS":"NATIVE_BEGIN_FAIL","{}");
  if(!begun)return;
  g_trade_group_id=group;g_position.direction=side;g_position.has_position=true;g_position.entry_price=price;
  g_position.original_confirmed_stop=stop;g_position.original_stop_confirmed=true;g_trade_volume=volume;g_spread_reduced=false;
  MqlTradeRequest r={};MqlTradeResult result={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.magic=12001;
  r.type=side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL;r.volume=volume;r.price=price;r.sl=stop;r.type_filling=ORDER_FILLING_FOK;r.comment="NON_CANDIDATE_CONFORMANCE";
  ResearchOrderSend(r,result);ResearchNativeReceipt(result);
 }
 if(!g_da.pending&&g_da.position>0&&!g_cf_reduction_attempted&&tick.time_msc>=reduce){
  g_cf_reduction_attempted=true;
  if(close>0&&tick.time_msc>=close){g_da.Invalidate("FIXTURE_REDUCTION_WINDOW_MISSED");return;}
  ResearchReduceHalf(tick);
 }
 if(close>0&&!g_da.pending&&!g_cf_close_attempted&&tick.time_msc>=close){g_cf_close_attempted=true;ResearchClose(side,tick);}
 ResearchNativeSeal(tick);
}
bool ResearchNativeOrderCheck(MqlTradeRequest &r){
 MqlTradeCheckResult c={};
 ResearchConformanceObserve("OBS_ORDERCHECK_ENTER",(long)TimeCurrent()*1000,0,"ORDERCHECK_ENTER","{\"action\":"+(string)r.action+",\"type\":"+(string)r.type+",\"volume\":"+DAQuote(DoubleToString(r.volume,16))+",\"price\":"+DAQuote(DoubleToString(r.price,16))+",\"sl\":"+DAQuote(DoubleToString(r.sl,16))+",\"position\":"+(string)r.position+"}");
 ResetLastError();
 bool ok=OrderCheck(r,c);int error=GetLastError();
 ResearchConformanceObserve("OBS_ORDERCHECK_RESULT",(long)TimeCurrent()*1000,0,ok?"ORDERCHECK_BOOL_TRUE":"ORDERCHECK_BOOL_FALSE","{\"bool_return\":"+DAFlag(ok)+",\"retcode\":"+(string)c.retcode+",\"error\":"+(string)error+"}");
 string request="{\"action\":"+(string)r.action+",\"magic\":"+(string)r.magic+",\"order\":"+(string)r.order+",\"symbol\":"+DAQuote(r.symbol)+",\"volume\":"+DANumber(r.volume)+",\"price\":"+DANumber(r.price)+",\"stoplimit\":"+DANumber(r.stoplimit)+",\"sl\":"+DANumber(r.sl)+",\"tp\":"+DANumber(r.tp)+",\"deviation\":"+(string)r.deviation+",\"type\":"+(string)r.type+",\"type_filling\":"+(string)r.type_filling+",\"type_time\":"+(string)r.type_time+",\"expiration\":"+DAQuote((string)r.expiration)+",\"comment\":"+DAQuote(r.comment)+",\"position\":"+(string)r.position+",\"position_by\":"+(string)r.position_by+"}";
 string payload="{\"run_id\":"+DAQuote(InpManifestSha256)+",\"group_id\":"+DAQuote(g_da.group)+",\"request\":"+request+",\"request_hash\":"+DAQuote(ResearchSha256String(request))+",\"bool_return\":"+DAFlag(ok)+",\"retcode\":"+(string)c.retcode+",\"error\":"+(string)error+",\"comment\":"+DAQuote(c.comment)+",\"balance\":"+DANumber(c.balance)+",\"equity\":"+DANumber(c.equity)+",\"profit\":"+DANumber(c.profit)+",\"margin\":"+DANumber(c.margin)+",\"margin_free\":"+DANumber(c.margin_free)+",\"margin_level\":"+DANumber(c.margin_level)+",\"time_msc\":"+(string)((long)TimeCurrent()*1000)+",\"context_hash\":"+DAQuote(InpNativeConformance?InpConformanceControlSha256:InpManifestFileSha256)+"}";
 if(!ResearchNativeRecord(g_da.intent==DA_CONTAINMENT?"INVALID_RUN_CONTAINMENT_EVIDENCE":"ORDER_CHECK",payload))return false;
 if(!ok||c.retcode!=0){g_da.Invalidate("ORDER_CHECK_REJECTED_NO_SEND");return false;}
 return true;
}
