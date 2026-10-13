#ifndef KINGEA_DECISION_A_STATIC_STOP_MQH
#define KINGEA_DECISION_A_STATIC_STOP_MQH
#include "DecisionALifecycle.mqh"
struct DAObservation { long type;ulong position,order;double sl;uint retcode;long action; };
class DAObservationRing {
public:
 DAObservation rows[256];int head,tail,size;bool overflow;
 void Reset(){head=0;tail=0;size=0;overflow=false;}
 bool Capture(const MqlTradeTransaction &t,const MqlTradeRequest &r,const MqlTradeResult &s){
 if(t.type!=TRADE_TRANSACTION_POSITION&&t.type!=TRADE_TRANSACTION_REQUEST)return true;
 if(size==256){overflow=true;return false;}
 rows[tail].type=t.type;rows[tail].position=t.position;rows[tail].order=t.order;rows[tail].sl=t.price_sl;rows[tail].action=-1;rows[tail].retcode=0;
 if(t.type==TRADE_TRANSACTION_REQUEST){rows[tail].position=r.position;rows[tail].order=s.order;rows[tail].action=r.action;rows[tail].retcode=s.retcode;}
 tail=(tail+1)%256;size++;return true;}
 bool Pop(DAObservation &o){if(size==0)return false;o=rows[head];head=(head+1)%256;size--;return true;}
};
bool DAStaticSendAllowed(const MqlTradeRequest &r,DAIntent intent,const DecisionALifecycle &ledger,bool context_authority){
 if(!context_authority)return false;
 if(r.action!=TRADE_ACTION_DEAL||r.type_filling!=ORDER_FILLING_FOK||r.symbol!=ledger.symbol||r.magic!=12001||r.volume<=0||!MathIsValidNumber(r.volume))return false;
 if(r.type!=(intent==DA_ENTRY?(ledger.side==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL):(ledger.side==1?ORDER_TYPE_SELL:ORDER_TYPE_BUY)))return false;
 if(intent!=ledger.intent||!ledger.pending)return false;
 if(intent==DA_ENTRY)return !ledger.invalid&&r.tp==0&&r.position==0&&NormalizeDouble(r.sl,ledger.digits)==ledger.s0&&DAVolumeEqual(r.volume,ledger.v0);
 if(r.position!=ledger.position_ticket||r.sl!=0||r.tp!=0)return false;
 if(intent==DA_CONTAINMENT)return ledger.invalid&&ledger.contained&&ledger.pending&&ledger.terminal==false&&ledger.residual.valid&&DAVolumeEqual(r.volume,ledger.residual.volume);
 return !ledger.invalid&&ledger.pending&&DAVolumeEqual(r.volume,ledger.requested);
}
// Accepted native profile, exact signed rates and weekday factors. No symbol-name equivalence.
bool DAValidateNativeProfileForBuild(const int expected_terminal_build){
 if(expected_terminal_build<=0||!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_VISUAL_MODE)||MQLInfoInteger(MQL_DLLS_ALLOWED)||TerminalInfoInteger(TERMINAL_BUILD)!=expected_terminal_build||AccountInfoString(ACCOUNT_SERVER)!="JustMarkets-Demo2"||_Symbol!="ETHUSD.s")return false;
 long mode=0,roll=0,digits=0,fill=0;
 if(!SymbolInfoInteger(_Symbol,SYMBOL_SWAP_MODE,mode)||!SymbolInfoInteger(_Symbol,SYMBOL_SWAP_ROLLOVER3DAYS,roll)||!SymbolInfoInteger(_Symbol,SYMBOL_DIGITS,digits)||!SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE,fill))return false;
 if(mode!=1||roll!=3||digits!=2||(fill&SYMBOL_FILLING_FOK)==0)return false;
 ENUM_SYMBOL_INFO_DOUBLE ids[]={SYMBOL_SWAP_LONG,SYMBOL_SWAP_SHORT,SYMBOL_VOLUME_MIN,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_MAX,SYMBOL_POINT,SYMBOL_TRADE_TICK_SIZE,SYMBOL_TRADE_CONTRACT_SIZE,SYMBOL_SWAP_MONDAY,SYMBOL_SWAP_TUESDAY,SYMBOL_SWAP_WEDNESDAY,SYMBOL_SWAP_THURSDAY,SYMBOL_SWAP_FRIDAY,SYMBOL_SWAP_SATURDAY,SYMBOL_SWAP_SUNDAY};
 double expected[]={-280.56,-184.08,0.01,0.01,100,0.01,0.01,1,1,1,3,1,1,0,0};
 for(int i=0;i<ArraySize(ids);i++){double v=0;if(!SymbolInfoDouble(_Symbol,ids[i],v)||!MathIsValidNumber(v)||v!=expected[i])return false;}return true;
}
// Historical Candidate/non-conformance profile remains fixed to build 6140.
bool DABoundNativeProfile(){return DAValidateNativeProfileForBuild(6140);}
// Only the separately authorized conformance path may supply a fixture-bound build.
bool DAConformanceBoundNativeProfile(const int expected_terminal_build){return DAValidateNativeProfileForBuild(expected_terminal_build);}
#endif
