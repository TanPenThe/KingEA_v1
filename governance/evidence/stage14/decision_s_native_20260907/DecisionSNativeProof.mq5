#property strict
#property version "1.00"
// Standalone infrastructure only. No includes, Candidate rules, file inputs or statistics.
input string RunId="";
input string Output="";
input int ExpectedBuild=6140;
input bool ShortSide=false;
input double FixedVolume=0.10;
input datetime EntryAfter=D'2022.12.05 12:00';
input datetime ReductionAfter=D'2022.12.07 12:00';
input datetime Deadline=D'2022.12.09 00:00';
int fh=INVALID_HANDLE,phase=0,n=0,events=0;
bool done=false,overflow=false;
string result="SWAP_EVIDENCE_INCOMPLETE";
ulong entryOrder=0,reduceOrder=0,closeOrder=0,pid=0,pticket=0;
double v0=0,p0=0,s0=0,q=0,ub=0,ua=0,uf=0,ds=0,df=0;
long actionTime=0,residualTime=0;
struct Fact {ulong deal,order,id; long when,entry,type,reason; double volume,price,profit,commission,fee,swap,sl; bool ok;};
Fact facts[32];
string Num(double x){return DoubleToString(x,12);}
void Emit(string s){if(fh!=INVALID_HANDLE){FileWriteString(fh,s+"\r\n");FileFlush(fh);} Print("DS_NATIVE|",s);}
void Stop(string why){if(done)return;result=why;done=true;Emit("RESULT|"+why+"|phase="+(string)phase);TesterStop();}
bool PD(ENUM_POSITION_PROPERTY_DOUBLE prop,double &x,string label){bool ok=PositionGetDouble(prop,x);Emit("P_READ|"+label+"|ok="+(string)ok+"|value="+Num(x));return ok && MathIsValidNumber(x);}
bool PI(ENUM_POSITION_PROPERTY_INTEGER prop,long &x,string label){bool ok=PositionGetInteger(prop,x);Emit("P_READ|"+label+"|ok="+(string)ok+"|value="+(string)x);return ok;}
bool DD(ulong t,ENUM_DEAL_PROPERTY_DOUBLE prop,double &x,string label){bool ok=HistoryDealGetDouble(t,prop,x);Emit("D_READ|ticket="+(string)t+"|"+label+"|ok="+(string)ok+"|value="+Num(x));return ok && MathIsValidNumber(x);}
bool DI(ulong t,ENUM_DEAL_PROPERTY_INTEGER prop,long &x,string label){bool ok=HistoryDealGetInteger(t,prop,x);Emit("D_READ|ticket="+(string)t+"|"+label+"|ok="+(string)ok+"|value="+(string)x);return ok;}
bool Snap(string label,double expected,double &sw,bool initial=false){
 Emit("SNAP_BEGIN|"+label+"|tester_time="+(string)TimeCurrent());
 if(!PositionSelect(_Symbol)){Emit("SNAP_SELECT_FAILED");return false;}
 double v=0,p=0,s=0;long id=0,t=0,type=0;
 bool ok=PI(POSITION_IDENTIFIER,id,"POSITION_IDENTIFIER");
 ok=PI(POSITION_TICKET,t,"POSITION_TICKET") && ok;ok=PI(POSITION_TYPE,type,"POSITION_TYPE") && ok;
 ok=PD(POSITION_VOLUME,v,"POSITION_VOLUME") && ok;ok=PD(POSITION_PRICE_OPEN,p,"POSITION_PRICE_OPEN") && ok;
 ok=PD(POSITION_SL,s,"POSITION_SL") && ok;ok=PD(POSITION_SWAP,sw,"POSITION_SWAP") && ok;
 if(initial){pid=(ulong)id;pticket=(ulong)t;p0=p;v0=v;}
 Emit("SNAP_END|"+label+"|id="+(string)id+"|ticket="+(string)t+"|volume="+Num(v)+"|basis="+Num(p)+"|sl="+Num(s)+"|swap="+Num(sw));
 int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
 return ok && id>0 && (ulong)id==pid && t>0 && type==(ShortSide?POSITION_TYPE_SELL:POSITION_TYPE_BUY) &&
 NormalizeDouble(v-expected,8)==0 && p==p0 && NormalizeDouble(s,digits)==s0;
}
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &req,const MqlTradeResult &res){
 if(done)return;
 events++;if(events>128){overflow=true;Stop("SWAP_EVIDENCE_INCOMPLETE_EVENT_BOUND");return;}
 Emit("TX|type="+(string)tr.type+"|deal="+(string)tr.deal+"|order="+(string)tr.order+"|position_ticket="+(string)tr.position+"|price_sl="+Num(tr.price_sl)+"|capture_time="+(string)TimeCurrent());
 if(tr.type==TRADE_TRANSACTION_REQUEST)Emit("REQUEST_EVENT|action="+(string)req.action+"|position="+(string)req.position+"|retcode="+(string)res.retcode+"|request_id="+(string)res.request_id);
 if(tr.type!=TRADE_TRANSACTION_DEAL_ADD)return;
 if(n>=32){Stop("SWAP_EVIDENCE_INCOMPLETE_DEAL_BOUND");return;}
 if(!HistoryDealSelect(tr.deal)){Stop("SWAP_EVIDENCE_INCOMPLETE_SELECT");return;}
 Fact f={}; f.deal=tr.deal;long o=0,id=0;
 bool ok=DI(tr.deal,DEAL_ORDER,o,"DEAL_ORDER");ok=DI(tr.deal,DEAL_POSITION_ID,id,"DEAL_POSITION_ID") && ok;
 ok=DI(tr.deal,DEAL_TIME_MSC,f.when,"DEAL_TIME_MSC") && ok;ok=DI(tr.deal,DEAL_ENTRY,f.entry,"DEAL_ENTRY") && ok;
 ok=DI(tr.deal,DEAL_TYPE,f.type,"DEAL_TYPE") && ok;ok=DI(tr.deal,DEAL_REASON,f.reason,"DEAL_REASON") && ok;
 ok=DD(tr.deal,DEAL_VOLUME,f.volume,"DEAL_VOLUME") && ok;ok=DD(tr.deal,DEAL_PRICE,f.price,"DEAL_PRICE") && ok;
 ok=DD(tr.deal,DEAL_PROFIT,f.profit,"DEAL_PROFIT") && ok;ok=DD(tr.deal,DEAL_COMMISSION,f.commission,"DEAL_COMMISSION") && ok;
 ok=DD(tr.deal,DEAL_FEE,f.fee,"DEAL_FEE") && ok;ok=DD(tr.deal,DEAL_SWAP,f.swap,"DEAL_SWAP") && ok;ok=DD(tr.deal,DEAL_SL,f.sl,"DEAL_SL") && ok;
 string symbol="";bool symok=HistoryDealGetString(tr.deal,DEAL_SYMBOL,symbol);Emit("D_READ|ticket="+(string)tr.deal+"|DEAL_SYMBOL|ok="+(string)symok+"|value="+symbol);
 f.order=(ulong)o;f.id=(ulong)id;f.ok=ok && symok && symbol==_Symbol && tr.order==f.order;
 facts[n++]=f;if(!f.ok)Stop("SWAP_EVIDENCE_INCOMPLETE_PROPERTY");
}
bool Send(int stage,double vol,ulong &order){
 MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick)){Stop("SWAP_EVIDENCE_INCOMPLETE_TICK");return false;}
 MqlTradeRequest r={};MqlTradeResult s={};r.action=TRADE_ACTION_DEAL;r.symbol=_Symbol;r.volume=vol;r.type_filling=ORDER_FILLING_FOK;
 r.magic=7090701;r.type=(stage==0?(ShortSide?ORDER_TYPE_SELL:ORDER_TYPE_BUY):(ShortSide?ORDER_TYPE_BUY:ORDER_TYPE_SELL));
 r.price=(r.type==ORDER_TYPE_BUY?tick.ask:tick.bid);if(stage==0)r.sl=s0;else r.position=pticket;
 Emit("SEND|stage="+(string)stage+"|requested_q="+Num(vol)+"|FOK=1|sl="+Num(r.sl)+"|time_msc="+(string)tick.time_msc);
 bool ok=OrderSend(r,s);order=s.order;actionTime=(long)TimeCurrent();
 Emit("RECEIPT|stage="+(string)stage+"|ok="+(string)ok+"|retcode="+(string)s.retcode+"|order="+(string)s.order+"|deal="+(string)s.deal+"|volume="+Num(s.volume)+"|request_id="+(string)s.request_id);
 if(!ok || s.retcode!=TRADE_RETCODE_DONE){Stop("FOK_REJECTED_OR_UNRESOLVED_RECEIPT");return false;}return true;
}
int Reconcile(ulong order,double requested,long role,double &swap){
 int count=0;double sum=0;swap=0;
 for(int i=0;i<n;i++)if(facts[i].order==order){count++;sum+=facts[i].volume;swap+=facts[i].swap;
  if(!facts[i].ok || facts[i].entry!=role || (pid!=0 && facts[i].id!=pid)){Stop("SWAP_EVIDENCE_INCOMPLETE_IDENTITY");return -1;}}
 if(count==0){if((long)TimeCurrent()-actionTime>60)Stop("SWAP_EVIDENCE_INCOMPLETE_CALLBACK_TIMEOUT");return 0;}
 Emit("RECONCILE|order="+(string)order+"|requested_q="+Num(requested)+"|executed_volume="+Num(sum)+"|deal_count="+(string)count+"|swap="+Num(swap));
 if(NormalizeDouble(sum-requested,8)!=0){Stop("PARTIAL_ORDER_EXECUTION");return -1;}
 if(count>1){Stop("FOK_FULL_MULTI_DEAL_UNSUPPORTED_LEDGER_CARDINALITY");return -1;}
 Emit("FOK_FULL_SINGLE_DEAL|order="+(string)order);return 1;
}
int OnInit(){
 if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION)||MQLInfoInteger(MQL_VISUAL_MODE)||MQLInfoInteger(MQL_DLLS_ALLOWED)||_Symbol!="ETHUSD.s"||RunId==""||Output==""||TerminalInfoInteger(TERMINAL_BUILD)!=ExpectedBuild)return INIT_FAILED;
 if(AccountInfoString(ACCOUNT_SERVER)!="JustMarkets-Demo2" || PositionsTotal()!=0 || OrdersTotal()!=0)return INIT_FAILED;
 if(FileIsExist(Output,FILE_COMMON))return INIT_FAILED;
 fh=FileOpen(Output,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);if(fh==INVALID_HANDLE)return INIT_FAILED;
 Emit("INIT|"+RunId+"|MQL_TESTER=1|build="+(string)TerminalInfoInteger(TERMINAL_BUILD)+"|compiler="+(string)__MQLBUILD__+"|symbol="+_Symbol+"|side="+(ShortSide?"SHORT":"LONG"));
 ENUM_SYMBOL_INFO_DOUBLE dp[]={SYMBOL_VOLUME_MIN,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_MAX,SYMBOL_POINT,SYMBOL_TRADE_TICK_SIZE,SYMBOL_TRADE_CONTRACT_SIZE,SYMBOL_SWAP_LONG,SYMBOL_SWAP_SHORT,SYMBOL_SWAP_MONDAY,SYMBOL_SWAP_TUESDAY,SYMBOL_SWAP_WEDNESDAY,SYMBOL_SWAP_THURSDAY,SYMBOL_SWAP_FRIDAY,SYMBOL_SWAP_SATURDAY,SYMBOL_SWAP_SUNDAY};
 for(int i=0;i<ArraySize(dp);i++){double x=0;bool ok=SymbolInfoDouble(_Symbol,dp[i],x);Emit("SPEC|"+EnumToString(dp[i])+"|ok="+(string)ok+"|value="+Num(x));if(!ok)return INIT_FAILED;}
 ENUM_SYMBOL_INFO_INTEGER ip[]={SYMBOL_DIGITS,SYMBOL_FILLING_MODE,SYMBOL_TRADE_MODE,SYMBOL_TRADE_EXEMODE,SYMBOL_SWAP_MODE,SYMBOL_SWAP_ROLLOVER3DAYS,SYMBOL_TRADE_STOPS_LEVEL,SYMBOL_TRADE_FREEZE_LEVEL};
 for(int i=0;i<ArraySize(ip);i++){long x=0;bool ok=SymbolInfoInteger(_Symbol,ip[i],x);Emit("SPEC|"+EnumToString(ip[i])+"|ok="+(string)ok+"|value="+(string)x);if(!ok)return INIT_FAILED;}
 if((SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE)&SYMBOL_FILLING_FOK)==0){Stop("FOK_UNSUPPORTED");return INIT_SUCCEEDED;}
 double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
 if(st<=0||FixedVolume/2<mn||NormalizeDouble(MathRound(FixedVolume/st)*st-FixedVolume,8)!=0||NormalizeDouble(MathRound(FixedVolume/2/st)*st-FixedVolume/2,8)!=0){Stop("VOLUME_STEP_MINIMUM_INFEASIBLE");return INIT_SUCCEEDED;}
 return INIT_SUCCEEDED;
}
void OnTick(){
 if(done)return;datetime now=TimeCurrent();
 if(now>=Deadline){Stop(phase==2?"NONZERO_SWAP_NOT_OBTAINED":"SWAP_EVIDENCE_INCOMPLETE_DEADLINE");return;}
 if(phase==0){if(now<EntryAfter)return;MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick))return;
  s0=NormalizeDouble(ShortSide?tick.ask*1.5:tick.bid*0.5,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
  phase=1;Send(0,FixedVolume,entryOrder);return;}
 if(phase==1){double es=0;if(Reconcile(entryOrder,FixedVolume,DEAL_ENTRY_IN,es)!=1)return;
  if(!Snap("ENTRY",FixedVolume,ub,true)){Stop("ENTRY_POSITION_OR_S0_MISMATCH");return;}
  if(es!=0){Stop("SWAP_PROFILE_OTHER_ENTRY_SWAP");return;}phase=2;return;}
 if(phase==2){if(now<ReductionAfter)return;double sw=0;if(!PositionSelect(_Symbol)||!PositionGetDouble(POSITION_SWAP,sw)){Stop("SWAP_EVIDENCE_INCOMPLETE_POSITION");return;}if(sw==0)return;
  if(!Snap("PRE_REDUCTION",v0,ub)){Stop("PRE_REDUCTION_POSITION_MISMATCH");return;}q=NormalizeDouble(v0/2,8);phase=3;Send(1,q,reduceOrder);return;}
 if(phase==3){if(Reconcile(reduceOrder,q,DEAL_ENTRY_OUT,ds)!=1)return;
  if(!Snap("POST_REDUCTION",v0-q,ua)){Stop("RESIDUAL_IDENTITY_VOLUME_BASIS_OR_S0_MISMATCH");return;}
  Emit("SWAP_RAW|Ub="+Num(ub)+"|reduction_DEAL_SWAP="+Num(ds)+"|Ua="+Num(ua));
  if(MathAbs(ub-ds-ua)>0.00000001){Stop(ua==ub&&ds!=0?"DEAL_SWAP_POSITION_SWAP_OVERLAP_OBSERVED":ua==0?"POSITION_SWAP_RESET_OR_REBASED":"SWAP_PROFILE_OTHER");return;}
  residualTime=(long)now;phase=4;return;}
 if(phase==4){if((long)now-residualTime<60)return;if(!Snap("PRE_FINAL_CLOSE",v0-q,uf)){Stop("FINAL_POSITION_MISMATCH");return;}phase=5;Send(2,v0-q,closeOrder);return;}
 if(phase==5){if(Reconcile(closeOrder,v0-q,DEAL_ENTRY_OUT,df)!=1)return;
  if(PositionSelect(_Symbol)){Stop("FINAL_RESIDUAL_NOT_FLAT");return;}
  Emit("FINAL_SWAP_RAW|pre_final_POSITION_SWAP="+Num(uf)+"|final_DEAL_SWAP="+Num(df)+"|deal_swap_sum="+Num(ds+df));
  if(MathAbs(uf-df)>0.00000001){Stop("SWAP_PROFILE_OTHER_FINAL_CLOSE");return;}
  Stop("DISJOINT_EQUATIONS_OBSERVED_REQUIRES_INDEPENDENT_REVIEW");return;}
}
void OnDeinit(const int reason){Emit("DEINIT|reason="+(string)reason+"|result="+result+"|phase="+(string)phase+"|deal_count="+(string)n+"|events="+(string)events+"|overflow="+(string)overflow);if(fh!=INVALID_HANDLE){FileClose(fh);fh=INVALID_HANDLE;}}
