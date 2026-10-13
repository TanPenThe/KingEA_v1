#ifndef KINGEA_DECISION_A_DEAL_ADAPTER_MQH
#define KINGEA_DECISION_A_DEAL_ADAPTER_MQH
#include "DecisionALifecycle.mqh"
// Exact-ticket authority: invoke only within current run DEAL_ADD callback.
bool DAReadDeal(const MqlTradeTransaction &trans,DADeal &d){
 ZeroMemory(d);if(!MQLInfoInteger(MQL_TESTER)||trans.type!=TRADE_TRANSACTION_DEAL_ADD||trans.deal==0)return false;
 if(!HistoryDealSelect(trans.deal))return false;
 d.ticket=trans.deal;long order=0,position=0;
 if(HistoryDealGetInteger(d.ticket,DEAL_ORDER,order))d.reads|=1;
 if(HistoryDealGetInteger(d.ticket,DEAL_POSITION_ID,position))d.reads|=2;
 if(HistoryDealGetInteger(d.ticket,DEAL_TIME_MSC,d.time_msc))d.reads|=4;
 if(HistoryDealGetInteger(d.ticket,DEAL_ENTRY,d.entry))d.reads|=8;
 if(HistoryDealGetInteger(d.ticket,DEAL_TYPE,d.type))d.reads|=16;
 if(HistoryDealGetInteger(d.ticket,DEAL_REASON,d.reason))d.reads|=32;
 if(HistoryDealGetInteger(d.ticket,DEAL_MAGIC,d.magic))d.reads|=64;
 if(HistoryDealGetString(d.ticket,DEAL_SYMBOL,d.symbol))d.reads|=128;
 if(HistoryDealGetDouble(d.ticket,DEAL_VOLUME,d.volume))d.reads|=256;
 if(HistoryDealGetDouble(d.ticket,DEAL_PRICE,d.price))d.reads|=512;
 if(HistoryDealGetDouble(d.ticket,DEAL_PROFIT,d.profit))d.reads|=1024;
 if(HistoryDealGetDouble(d.ticket,DEAL_COMMISSION,d.commission))d.reads|=2048;
 if(HistoryDealGetDouble(d.ticket,DEAL_FEE,d.fee))d.reads|=4096;
 if(HistoryDealGetDouble(d.ticket,DEAL_SWAP,d.swap))d.reads|=8192;
 if(HistoryDealGetDouble(d.ticket,DEAL_SL,d.sl))d.reads|=16384;
 if(trans.order==(ulong)order && trans.symbol==d.symbol)d.reads|=32768;
 d.order=(ulong)order;d.position=(ulong)position;
 d.valid=d.reads==65535&&order>0&&position>0&&d.time_msc>0&&d.volume>0&&d.price>0&&
 MathIsValidNumber(d.volume)&&MathIsValidNumber(d.price)&&MathIsValidNumber(d.profit)&&MathIsValidNumber(d.commission)&&MathIsValidNumber(d.fee)&&MathIsValidNumber(d.swap)&&MathIsValidNumber(d.sl);
 return d.valid;
}
bool DAReadPosition(ulong ticket,ulong stable,string symbol,const MqlTick &tick,DAPosition &p){
 ZeroMemory(p);if(ticket==0||!PositionSelectByTicket(ticket))return false;
 long id=0,t=0;
 if(PositionGetInteger(POSITION_IDENTIFIER,id))p.reads|=1;
 if(PositionGetInteger(POSITION_TICKET,t))p.reads|=2;
 if(PositionGetInteger(POSITION_TYPE,p.side))p.reads|=4;
 if(PositionGetInteger(POSITION_MAGIC,p.magic))p.reads|=8;
 if(PositionGetString(POSITION_SYMBOL,p.symbol))p.reads|=16;
 if(PositionGetDouble(POSITION_VOLUME,p.volume))p.reads|=32;
 if(PositionGetDouble(POSITION_PRICE_OPEN,p.basis))p.reads|=64;
 if(PositionGetDouble(POSITION_SL,p.sl))p.reads|=128;
 if(PositionGetDouble(POSITION_SWAP,p.swap))p.reads|=256;
 p.id=(ulong)id;p.ticket=(ulong)t;p.time_msc=tick.time_msc;p.bid=tick.bid;p.ask=tick.ask;
 bool ok=p.reads==511&&id>0&&t>0&&p.ticket==ticket&&(stable==0||p.id==stable)&&p.symbol==symbol&&p.magic==12001&&p.volume>0&&p.basis>0&&p.sl>0;
 ok=ok&&(p.side==POSITION_TYPE_BUY||p.side==POSITION_TYPE_SELL);
 if(tick.bid>0&&tick.ask>=tick.bid&&MathIsValidNumber(tick.bid)&&MathIsValidNumber(tick.ask))p.reads|=512;
 if(ok&&(p.reads&512)!=0&&OrderCalcProfit(p.side==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,p.volume,p.basis,p.side==POSITION_TYPE_BUY?tick.bid:tick.ask,p.mark))p.reads|=1024;
 p.valid=ok&&p.reads==2047&&MathIsValidNumber(p.mark)&&MathIsValidNumber(p.swap)&&MathIsValidNumber(p.volume)&&MathIsValidNumber(p.basis)&&MathIsValidNumber(p.sl);return p.valid;
}
// Bounded capture only. No history enumeration and no financial projection in
// OnTradeTransaction. ORDER terminal volume is unfilled volume, never residual.
struct DANativeCapture {
  long type; ulong capture_sequence,deal_ticket,position,order; long order_state,order_type;
  double unfilled,raw_transaction_volume; string symbol; DADeal deal;
};
class DANativeCaptureRing {
 public:
  DANativeCapture rows[256]; int head,tail,size; ulong next_capture_sequence; bool overflow;
  void Reset(){head=0;tail=0;size=0;next_capture_sequence=0;overflow=false;}
  bool Capture(const MqlTradeTransaction &t){
   if(t.type!=TRADE_TRANSACTION_DEAL_ADD && t.type!=TRADE_TRANSACTION_ORDER_DELETE && t.type!=TRADE_TRANSACTION_HISTORY_ADD)return true;
   if(size==256){overflow=true;return false;}
   ZeroMemory(rows[tail]);rows[tail].capture_sequence=++next_capture_sequence;
   rows[tail].type=t.type;rows[tail].deal_ticket=t.deal;rows[tail].position=t.position;
   rows[tail].order=t.order;rows[tail].order_state=t.order_state;
   rows[tail].order_type=t.order_type;rows[tail].unfilled=t.volume;
   rows[tail].raw_transaction_volume=t.volume;rows[tail].symbol=t.symbol;
  if(t.type==TRADE_TRANSACTION_DEAL_ADD)DAReadDeal(t,rows[tail].deal);
  tail=(tail+1)%256;size++;return true;
 }
 bool Pop(DANativeCapture &r){if(size==0)return false;r=rows[head];head=(head+1)%256;size--;return true;}
};
#endif
