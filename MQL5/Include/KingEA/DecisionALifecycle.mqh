#ifndef KINGEA_DECISION_A_LIFECYCLE_MQH
#define KINGEA_DECISION_A_LIFECYCLE_MQH
#include "AccountingEvents.mqh"
enum DAExposure { DA_FULL=0,DA_REQUEST_PENDING=1,DA_REDUCED=2,DA_QUARANTINED=3,DA_AMBIGUOUS=4,DA_CLOSE_PENDING=5,DA_FLAT=6 };
enum DAIntent { DA_ENTRY=0,DA_REDUCTION=1,DA_CLOSE=2,DA_CONTAINMENT=3 };
struct DADeal {
 ulong ticket,order,position; long time_msc,entry,type,reason,magic;
 string symbol; double volume,price,profit,commission,fee,swap,sl;
 uint reads; bool valid;
};
struct DAPosition {
 ulong id,ticket; long side,magic; string symbol;
 double volume,basis,sl,swap,mark,bid,ask; long time_msc; uint reads; bool valid;
};
string DADealCanonical(const DADeal &d) {
 return (string)d.ticket+"|"+(string)d.order+"|"+(string)d.position+"|"+(string)d.time_msc+"|"+
 (string)d.entry+"|"+(string)d.type+"|"+(string)d.reason+"|"+(string)d.magic+"|"+d.symbol+"|"+
 DoubleToString(d.volume,16)+"|"+DoubleToString(d.price,16)+"|"+DoubleToString(d.profit,16)+"|"+
 DoubleToString(d.commission,16)+"|"+DoubleToString(d.fee,16)+"|"+DoubleToString(d.swap,16)+"|"+
 DoubleToString(d.sl,16)+"|"+(string)d.reads+"|"+(string)d.valid;
}
bool DAVolumeEqual(double a,double b){return MathIsValidNumber(a)&&MathIsValidNumber(b)&&NormalizeDouble(a,8)==NormalizeDouble(b,8);}
class DecisionALifecycle {
public:
 bool invalid,projected,pending,terminal,contained,reduced,started,projection_prepared,no_fill,execution_volume_authenticated;
 string failure,group,symbol; DAExposure exposure; DAIntent intent;
 double v0,p0,e0,r0,s0,gross,commission,fee,swap,requested,before_swap,executed_target,before_volume;
 ulong position,position_ticket,order; int digits,side,count; long end_msc;
 DAPosition residual; DADeal facts[64]; bool applied[64];
 void Reset(){executed_target=0;execution_volume_authenticated=false;projection_prepared=false;no_fill=false;invalid=false;projected=false;pending=false;terminal=false;contained=false;reduced=false;started=false;
 failure="";group="";symbol="";v0=0;p0=0;e0=0;r0=0;s0=0;gross=0;commission=0;fee=0;swap=0;requested=0;before_swap=0;
 before_volume=0;position=0;position_ticket=0;order=0;digits=0;side=0;count=0;end_msc=0;exposure=DA_FULL;intent=DA_ENTRY;ZeroMemory(residual);
 for(int i=0;i<64;i++)applied[i]=false;}
 void Invalidate(string why){if(!invalid)failure=why;invalid=true;if(exposure!=DA_FLAT)exposure=DA_QUARANTINED;}
 bool Begin(string g,string sym,int direction,double volume,double stop,double equity,double risk,int precision,long end){
 if(invalid || (started && !projected))return false;
 Reset();if(g==""||sym==""||volume<=0||stop<=0||equity<=0||risk<=0||precision<0||precision>8||(direction!=1&&direction!=-1)||!MathIsValidNumber(volume)||!MathIsValidNumber(stop)||!MathIsValidNumber(equity)||!MathIsValidNumber(risk))return false;
 group=g;symbol=sym;side=direction;v0=volume;s0=NormalizeDouble(stop,precision);e0=equity;r0=risk;digits=precision;end_msc=end;started=true;return true;}
 bool Prepare(DAIntent what,double volume){
 if(!started||pending||projected||!MathIsValidNumber(volume)||volume<=0)return false;
 if(what==DA_CONTAINMENT){if((failure!="PARTIAL_ORDER_EXECUTION"&&failure!="FOK_FULL_MULTI_DEAL_UNSUPPORTED_LEDGER_CARDINALITY")||!invalid||contained||!terminal||!residual.valid||residual.volume<=0||!DAVolumeEqual(volume,residual.volume))return false;contained=true;}
 else if(invalid)return false;
 if(what==DA_ENTRY && (position!=0||count!=0))return false;
 if(what==DA_CLOSE && (!residual.valid||!DAVolumeEqual(volume,residual.volume)))return false;
 if(what==DA_REDUCTION && (reduced||!residual.valid||volume>=residual.volume||
 !DAVolumeEqual(volume,v0-NormalizeDouble(MathFloor((v0*0.5+1e-12)/0.01)*0.01,8))))return false;
 no_fill=false;executed_target=0;execution_volume_authenticated=false;projection_prepared=false;intent=what;requested=volume;order=0;terminal=false;pending=true;before_swap=residual.swap;before_volume=residual.volume;exposure=(what==DA_CLOSE||what==DA_CONTAINMENT)?DA_CLOSE_PENDING:DA_REQUEST_PENDING;return true;}
 // Terminality and actual executed volume must come from native receipt/order authority.
 // Neither position disappearance nor a temporarily incomplete callback list supplies them.
 void Receipt(ulong ticket,bool completed,double actual_executed,bool volume_read_ok,bool rejected_without_fill=false){
 order=ticket;terminal=completed;
 execution_volume_authenticated=volume_read_ok&&MathIsValidNumber(actual_executed)&&actual_executed>=0;
 executed_target=execution_volume_authenticated?actual_executed:0;
 no_fill=completed&&execution_volume_authenticated&&actual_executed==0&&rejected_without_fill;
 if(!completed||!execution_volume_authenticated)exposure=DA_AMBIGUOUS;
 }
 bool Capture(const DADeal &d){
 for(int i=0;i<count;i++)if(facts[i].ticket==d.ticket){if(DADealCanonical(facts[i])!=DADealCanonical(d)){Invalidate("CONFLICTING_DUPLICATE_DEAL");return false;}return true;}
 if(count>=64){Invalidate("DEAL_CAPTURE_OVERFLOW");return false;}
 facts[count]=d;applied[count]=false;count++;
 if(!d.valid||d.reads!=65535||d.ticket==0||d.order==0||d.position==0||d.symbol!=symbol||d.magic!=12001){Invalidate("MISSING_OR_FAILED_READ_OR_FOREIGN_DEAL");return false;}
 if(projected){Invalidate("NORMAL_BOUNDARY_IMMUTABLE_CONFLICT");return false;}
 return true;}
 bool Reconcile(const DAPosition &now,bool flat_authenticated){
 if(!pending||!terminal||!execution_volume_authenticated)return false;
 int n=0,index=-1;double filled=0;
 for(int i=0;i<count;i++)if(facts[i].order==order){n++;index=i;filled+=facts[i].volume;}
 // Wait for the complete authenticated executed volume; callback ordering is not causal order.
 if(filled<executed_target && !DAVolumeEqual(filled,executed_target))return false;
 if(filled>executed_target && !DAVolumeEqual(filled,executed_target)){
 Invalidate("EXECUTION_RECEIPT_CALLBACK_CONFLICT");residual.valid=false;exposure=DA_AMBIGUOUS;return false;}
 // A terminal rejection plus an authenticated unchanged position is the only no-fill outcome.
 if(n==0){if(no_fill && intent==DA_ENTRY && position==0){pending=false;started=false;exposure=DA_FLAT;return false;}if(no_fill&&now.valid&&now.id==position&&DAVolumeEqual(now.volume,residual.volume)){pending=false;residual=now;exposure=invalid?DA_QUARANTINED:(reduced?DA_REDUCED:DA_FULL);}return false;}
 ulong bound=position;
 for(int i=0;i<count;i++)if(facts[i].order==order){
 if(bound==0)bound=facts[i].position;
 if(bound==0||facts[i].position!=bound){Invalidate("EXECUTION_POSITION_CONFLICT");residual.valid=false;exposure=DA_AMBIGUOUS;return false;}}
 if(filled>requested&&!DAVolumeEqual(filled,requested)){Invalidate("EXECUTED_VOLUME_EXCEEDS_REQUEST");residual.valid=false;exposure=DA_AMBIGUOUS;return false;}
 if(!DAVolumeEqual(filled,requested)||n>1){
 Invalidate(DAVolumeEqual(filled,requested)?"FOK_FULL_MULTI_DEAL_UNSUPPORTED_LEDGER_CARDINALITY":"PARTIAL_ORDER_EXECUTION");
 pending=false;if(flat_authenticated && intent!=DA_ENTRY && DAVolumeEqual(filled,before_volume)){position=bound;ZeroMemory(residual);residual.valid=true;exposure=DA_FLAT;}else if(now.valid && now.id==bound && now.symbol==symbol && now.magic==12001){position=bound;position_ticket=now.ticket;if(intent==DA_ENTRY)p0=now.basis;residual=now;exposure=DA_QUARANTINED;}else{residual.valid=false;exposure=DA_AMBIGUOUS;}return false;}
 DADeal d=facts[index];
 if(!d.valid||(position!=0&&d.position!=position)||(intent!=DA_CONTAINMENT&&d.time_msc>=end_msc)){Invalidate("DEAL_BINDING_OR_TIME_INVALID");return false;}
 if(intent==DA_CONTAINMENT){pending=false;residual=now;if(flat_authenticated){ZeroMemory(residual);residual.valid=true;exposure=DA_FLAT;}else exposure=now.valid?DA_QUARANTINED:DA_AMBIGUOUS;return false;}
 if(invalid)return false;
 if(intent==DA_ENTRY){
 if(d.entry!=DEAL_ENTRY_IN||d.type!=(side==1?DEAL_TYPE_BUY:DEAL_TYPE_SELL)||d.profit!=0||d.swap!=0||!now.valid||now.reads!=2047||now.id!=d.position||!DAVolumeEqual(now.volume,v0)||NormalizeDouble(now.sl,digits)!=s0){Invalidate("ENTRY_RECONCILIATION_FAILED");return false;}
 position=d.position;position_ticket=now.ticket;p0=now.basis;commission=d.commission;fee=d.fee;residual=now;pending=false;exposure=DA_FULL;applied[index]=true;return true;}
 if(d.entry!=DEAL_ENTRY_OUT||d.type!=(side==1?DEAL_TYPE_SELL:DEAL_TYPE_BUY)){Invalidate("UNSUPPORTED_EXIT_TYPE");return false;}
 if(d.reason!=DEAL_REASON_EXPERT && d.reason!=DEAL_REASON_SL){Invalidate("MANUAL_OR_UNSUPPORTED_EXIT");return false;}
 if(d.reason==DEAL_REASON_SL && NormalizeDouble(d.sl,digits)!=s0){Invalidate("EXIT_STOP_MISMATCH");return false;}
 if(intent==DA_REDUCTION){
 if(!now.valid||now.reads!=2047||now.id!=position||now.basis!=p0||NormalizeDouble(now.sl,digits)!=s0||!DAVolumeEqual(now.volume,v0-requested)){Invalidate("RESIDUAL_RECONCILIATION_FAILED");return false;}
 if(DoubleToString(before_swap,8)!=DoubleToString(d.swap+now.swap,8)){Invalidate("SWAP_TRANSITION_CONSERVATION_FAIL");return false;}
 reduced=true;residual=now;exposure=DA_REDUCED;
 }else{
 if(!flat_authenticated){Invalidate("FINAL_FLAT_UNAUTHENTICATED");return false;}
 ZeroMemory(residual);residual.valid=true;exposure=DA_FLAT;
 }
 if(applied[index]){Invalidate("DUPLICATE_COMPONENT_APPLICATION");return false;}
 gross+=d.profit;commission+=d.commission;fee+=d.fee;swap+=d.swap;applied[index]=true;pending=false;return true;
 }
 // Non-booking operational truth includes authenticated unsupported/containment deals.
 // Research acceptance remains independently invalid; no accepted aggregate is manufactured.
 bool OperationalContribution(double &value){
 value=0;
 if(projected)return true;
 if(!started||position==0||!residual.valid||pending)return false;
 for(int i=0;i<count;i++){
 DADeal d=facts[i];
 if(!d.valid||d.reads!=65535||d.position!=position||d.symbol!=symbol||d.magic!=12001)return false;
 if(d.entry==DEAL_ENTRY_IN){if(d.profit!=0||d.swap!=0)return false;value+=d.commission+d.fee;}
 else if(d.entry==DEAL_ENTRY_OUT)value+=d.profit+d.commission+d.fee+d.swap;
 else return false;
 }
 value+=residual.mark+residual.swap;
 return MathIsValidNumber(value);
 }
 double Contribution(){return gross+commission+fee+swap+(residual.valid?residual.mark+residual.swap:0);}
 bool Projection(bool boundary,KingEAAccountingEvent &event){
 if(projected){Invalidate("SECOND_FINANCIAL_PROJECTION_ATTEMPT");return false;}
 if(invalid||pending||!started||e0<=0||r0<=0)return false;
 if(boundary){if(!residual.valid||residual.time_msc>=end_msc||residual.volume<=0)return false;}
 else if(exposure!=DA_FLAT)return false;
 event.gross_profit=gross+(boundary?residual.mark:0);event.commission=commission;event.fee=fee;event.swap=swap+(boundary?residual.swap:0);
 double net=event.gross_profit+event.commission+event.fee+event.swap;event.net_return=net/e0;event.net_r=net/r0;
 projection_prepared=true;return true;
 }
 bool Commit(){if(projected||invalid||!projection_prepared)return false;projected=true;projection_prepared=false;return true;}
};
#endif
