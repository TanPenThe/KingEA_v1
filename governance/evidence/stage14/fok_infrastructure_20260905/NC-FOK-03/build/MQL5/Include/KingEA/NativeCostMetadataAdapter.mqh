#ifndef KINGEA_NATIVE_COST_METADATA_ADAPTER_MQH
#define KINGEA_NATIVE_COST_METADATA_ADAPTER_MQH
#include "NativeCostEvidence.mqh"

// Call only from the active run's OnTradeTransaction DEAL_ADD callback.
// HistoryDealSelect clears the selected deal list. No caller may rely on that list.
bool KingEAReadCurrentRunDeal(const MqlTradeTransaction &trans,
                            const bool active_authorized_run,const string binding,
                            KingEANativeDealFact &fact)
  {
   ZeroMemory(fact);
   if(!MQLInfoInteger(MQL_TESTER) || !active_authorized_run ||
      !KingEAAccountingHash(binding) || trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0)
      return false;
   if(!HistoryDealSelect(trans.deal)) return false;
   fact.deal=trans.deal; fact.binding=binding;
   long order=0,position=0,magic=0;
   bool ok=HistoryDealGetInteger(trans.deal,DEAL_ORDER,order);
   ok=HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID,position) && ok;
   ok=HistoryDealGetInteger(trans.deal,DEAL_MAGIC,magic) && ok;
   ok=HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC,fact.time_msc) && ok;
   ok=HistoryDealGetInteger(trans.deal,DEAL_ENTRY,fact.entry) && ok;
   ok=HistoryDealGetInteger(trans.deal,DEAL_TYPE,fact.type) && ok;
   ok=HistoryDealGetString(trans.deal,DEAL_SYMBOL,fact.symbol) && ok;
   ok=HistoryDealGetDouble(trans.deal,DEAL_VOLUME,fact.volume) && ok;
   ok=HistoryDealGetDouble(trans.deal,DEAL_PRICE,fact.price) && ok;
   ok=HistoryDealGetDouble(trans.deal,DEAL_COMMISSION,fact.commission) && ok;
   ok=HistoryDealGetDouble(trans.deal,DEAL_FEE,fact.fee) && ok;
   ok=HistoryDealGetDouble(trans.deal,DEAL_SWAP,fact.swap) && ok;
   fact.order=(ulong)order; fact.position_id=(ulong)position; fact.magic=(ulong)magic;
   fact.read_ok=ok && order>0 && position>0 && magic>=0 &&
      trans.order==fact.order && trans.symbol==fact.symbol &&
      trans.volume==fact.volume && trans.price==fact.price && trans.deal_type==fact.type;
   return fact.read_ok;
  }

// The caller supplies the current tick; this adapter never looks up a post-end tick.
bool KingEASealNativeEligibleQuote(KingEANativeCostEvidence &ledger,
                                  const MqlTick &tick,const string symbol,
                                  const long start_msc,const long end_msc,
                                  const string specification_hash)
  {
   if(!MQLInfoInteger(MQL_TESTER) || tick.time_msc<start_msc || tick.time_msc>=end_msc ||
      !PositionSelect(symbol)) return false;
   KingEANativeCostSnapshot s={};
   s.binding=ledger.BindingHash(); s.time_msc=tick.time_msc;
   s.bid=tick.bid; s.ask=tick.ask; s.specification_hash=specification_hash;
   s.currency=AccountInfoString(ACCOUNT_CURRENCY); // Identity only; never terminal equity.
   long id=0,ticket=0,type=0;
   bool ok=PositionGetInteger(POSITION_IDENTIFIER,id);
   ok=PositionGetInteger(POSITION_TICKET,ticket) && ok;
   ok=PositionGetInteger(POSITION_TYPE,type) && ok;
   ok=PositionGetDouble(POSITION_VOLUME,s.volume) && ok;
   ok=PositionGetDouble(POSITION_PRICE_OPEN,s.entry) && ok;
   ok=PositionGetDouble(POSITION_SWAP,s.swap) && ok;
   s.position_id=(ulong)id; s.position_ticket=(ulong)ticket;
   if(type!=POSITION_TYPE_BUY && type!=POSITION_TYPE_SELL) return false;
   s.side=(type==POSITION_TYPE_BUY ? 1 : -1);
   s.position_read_ok=ok && id>0 && ticket>0;
   s.profit_read_ok=OrderCalcProfit(s.side==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                  symbol,s.volume,s.entry,s.side==1 ? s.bid : s.ask,s.mark);
   return ledger.Seal(s);
  }
#endif
