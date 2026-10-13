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
 long id=0,t=0;bool ok=PositionGetInteger(POSITION_IDENTIFIER,id);
 ok=PositionGetInteger(POSITION_TICKET,t)&&ok;ok=PositionGetInteger(POSITION_TYPE,p.side)&&ok;
 ok=PositionGetInteger(POSITION_MAGIC,p.magic)&&ok;ok=PositionGetString(POSITION_SYMBOL,p.symbol)&&ok;
 ok=PositionGetDouble(POSITION_VOLUME,p.volume)&&ok;ok=PositionGetDouble(POSITION_PRICE_OPEN,p.basis)&&ok;
 ok=PositionGetDouble(POSITION_SL,p.sl)&&ok;ok=PositionGetDouble(POSITION_SWAP,p.swap)&&ok;
 p.id=(ulong)id;p.ticket=(ulong)t;p.time_msc=tick.time_msc;
 ok=ok&&id>0&&t>0&&(stable==0||p.id==stable)&&p.symbol==symbol&&p.magic==12001&&p.volume>0&&p.basis>0&&p.sl>0;
 ok=ok&&(p.side==POSITION_TYPE_BUY||p.side==POSITION_TYPE_SELL)&&tick.bid>0&&tick.ask>=tick.bid;
 if(ok)ok=OrderCalcProfit(p.side==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,symbol,p.volume,p.basis,p.side==POSITION_TYPE_BUY?tick.bid:tick.ask,p.mark);
 p.valid=ok&&MathIsValidNumber(p.mark)&&MathIsValidNumber(p.swap);return p.valid;
}
#endif
