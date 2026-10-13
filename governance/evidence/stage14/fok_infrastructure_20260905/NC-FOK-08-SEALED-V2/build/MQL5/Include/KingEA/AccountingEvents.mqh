#ifndef KINGEA_ACCOUNTING_EVENTS_MQH
#define KINGEA_ACCOUNTING_EVENTS_MQH

// Stage 13 pure accounting-event contract.  No terminal I/O or trading APIs.

enum KingEAAccountingEventType
  {
   KINGEA_ACCOUNTING_EVENT_INVALID=0,
   KINGEA_ACCOUNTING_EVENT_ORDER=1,
   KINGEA_ACCOUNTING_EVENT_DEAL=2,
   KINGEA_ACCOUNTING_EVENT_POSITION=3,
   KINGEA_ACCOUNTING_EVENT_STOP_CHANGE=4,
   KINGEA_ACCOUNTING_EVENT_EXTERNAL_CASH_FLOW=5,
   KINGEA_ACCOUNTING_EVENT_VALUATION=6,
   KINGEA_ACCOUNTING_EVENT_SAFETY=7,
   KINGEA_ACCOUNTING_EVENT_MISSED_SIGNAL=8,
   KINGEA_ACCOUNTING_EVENT_TRADE_GROUP_CLOSE=9
  };

struct KingEAAccountingEvent
  {
   int      schema_version;
   string   event_id;
   int      event_type;
   long     server_time_msc;
   long     utc_time_msc;
   string   account_fingerprint;
   string   deployment_id;
   string   candidate_id;
   string   configuration_hash;
   string   sleeve_id;
   string   trade_group_id;
   string   signal_id;
   ulong    order_ticket;
   ulong    deal_ticket;
   ulong    position_ticket;
   string   symbol;
   int      direction;
   double   volume;
   double   requested_price;
   double   executed_price;
   double   protective_stop;
   double   gross_profit;
   double   commission;
   double   swap;
   double   fee;
   double   spread_attribution;
   double   slippage_attribution;
   double   external_cash_flow;
   double   account_equity;
   double   sleeve_equity;
   double   net_return;
   double   net_r;
   double   mae_r;
   double   mfe_r;
   int      bars_held;
   string   reason_code;
   string   source_quality;
  };

struct KingEAAccountingCheckpoint
  {
   long     last_sequence;
   long     last_server_time_msc;
   string   ledger_root_sha256;
   double   strategy_net_pnl;
   double   external_cash_flow;
   double   spread_attribution;
   double   slippage_attribution;
  };

struct KingEAAccountingDecision
  {
   bool                       accepted;
   string                     reason;
   long                       sequence;
   string                     event_sha256;
   double                     event_net_pnl;
   KingEAAccountingCheckpoint next_checkpoint;
  };

bool KingEAAccountingHash(const string value)
  {
   if(StringLen(value)!=64)
      return false;
   for(int i=0;i<64;i++)
     {
      ushort c=StringGetCharacter(value,i);
      if(!((c>='0' && c<='9') || (c>='A' && c<='F')))
         return false;
     }
   return true;
  }

string KingEAAccountingHex(const uchar &bytes[])
  {
   string result="";
   for(int i=0;i<ArraySize(bytes);i++)
      result+=StringFormat("%02X",(int)bytes[i]);
   return result;
  }

string KingEAAccountingSha256(const string value)
  {
   uchar source[],key[],digest[];
   int count=StringToCharArray(value,source,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=0)
      return "";
   ArrayResize(source,count-1);
   if(CryptEncode(CRYPT_HASH_SHA256,source,key,digest)!=32)
      return "";
   return KingEAAccountingHex(digest);
  }

string KingEAAccountingCanonical(const KingEAAccountingEvent &event,
                                 const long sequence,
                                 const string previous_hash)
  {
   return IntegerToString(event.schema_version)+"|"+
          event.event_id+"|"+IntegerToString(event.event_type)+"|"+
          (string)event.server_time_msc+"|"+(string)event.utc_time_msc+"|"+
          event.account_fingerprint+"|"+event.deployment_id+"|"+
          event.candidate_id+"|"+event.configuration_hash+"|"+
          event.sleeve_id+"|"+event.trade_group_id+"|"+event.signal_id+"|"+
          (string)event.order_ticket+"|"+(string)event.deal_ticket+"|"+
          (string)event.position_ticket+"|"+event.symbol+"|"+
          IntegerToString(event.direction)+"|"+
          DoubleToString(event.volume,8)+"|"+
          DoubleToString(event.requested_price,8)+"|"+
          DoubleToString(event.executed_price,8)+"|"+
          DoubleToString(event.protective_stop,8)+"|"+
          DoubleToString(event.gross_profit,8)+"|"+
          DoubleToString(event.commission,8)+"|"+
          DoubleToString(event.swap,8)+"|"+
          DoubleToString(event.fee,8)+"|"+
          DoubleToString(event.spread_attribution,8)+"|"+
          DoubleToString(event.slippage_attribution,8)+"|"+
          DoubleToString(event.external_cash_flow,8)+"|"+
          DoubleToString(event.account_equity,8)+"|"+
          DoubleToString(event.sleeve_equity,8)+"|"+
          DoubleToString(event.net_return,12)+"|"+
          DoubleToString(event.net_r,12)+"|"+
          DoubleToString(event.mae_r,12)+"|"+
          DoubleToString(event.mfe_r,12)+"|"+
          IntegerToString(event.bars_held)+"|"+
          event.reason_code+"|"+event.source_quality+"|"+
          (string)sequence+"|"+previous_hash;
  }

bool KingEAAccountingFinite(const KingEAAccountingEvent &event)
  {
   double values[]={event.volume,event.requested_price,event.executed_price,
                    event.protective_stop,event.gross_profit,event.commission,
                    event.swap,event.fee,event.spread_attribution,
                    event.slippage_attribution,event.external_cash_flow,
                    event.account_equity,event.sleeve_equity,event.net_return,
                    event.net_r,event.mae_r,event.mfe_r};
   for(int i=0;i<ArraySize(values);i++)
      if(!MathIsValidNumber(values[i]))
         return false;
   return true;
  }

void KingEAProcessAccountingEvent(const KingEAAccountingEvent &event,
                                  const KingEAAccountingCheckpoint &prior,
                                  KingEAAccountingDecision &decision)
  {
   ZeroMemory(decision);
   decision.next_checkpoint=prior;
   string prior_hash=prior.ledger_root_sha256;
   if(prior.last_sequence==0 && StringLen(prior_hash)==0)
      StringInit(prior_hash,64,'0');
   if(event.schema_version!=1 || event.event_id=="" ||
      event.event_type<=KINGEA_ACCOUNTING_EVENT_INVALID ||
      event.server_time_msc<=0 || event.utc_time_msc<=0 ||
      event.account_fingerprint=="" || event.deployment_id=="" ||
      !KingEAAccountingFinite(event) ||
      !KingEAAccountingHash(prior_hash) || prior.last_sequence<0 ||
      (prior.last_server_time_msc>0 &&
       event.server_time_msc<prior.last_server_time_msc))
     {
      decision.reason="ACCOUNTING_EVENT_INVALID";
      return;
     }
   long sequence=prior.last_sequence+1;
   string canonical=KingEAAccountingCanonical(event,sequence,prior_hash);
   string digest=KingEAAccountingSha256(canonical);
   if(!KingEAAccountingHash(digest))
     {
      decision.reason="ACCOUNTING_HASH_FAILED";
      return;
     }
   decision.accepted=true;
   decision.reason="ACCOUNTING_EVENT_ACCEPTED";
   decision.sequence=sequence;
   decision.event_sha256=digest;
   decision.event_net_pnl=(event.event_type==KINGEA_ACCOUNTING_EVENT_DEAL ||
                           event.event_type==KINGEA_ACCOUNTING_EVENT_TRADE_GROUP_CLOSE ?
                           event.gross_profit+event.commission+event.swap+event.fee : 0.0);
   decision.next_checkpoint.last_sequence=sequence;
   decision.next_checkpoint.last_server_time_msc=event.server_time_msc;
   decision.next_checkpoint.ledger_root_sha256=digest;
   decision.next_checkpoint.strategy_net_pnl+=decision.event_net_pnl;
   decision.next_checkpoint.external_cash_flow+=event.external_cash_flow;
   decision.next_checkpoint.spread_attribution+=event.spread_attribution;
   decision.next_checkpoint.slippage_attribution+=event.slippage_attribution;
  }

string KingEAAccountingFramePayload(const KingEAAccountingEvent &event,
                                    const KingEAAccountingDecision &decision)
  {
   if(!decision.accepted)
      return "";
   return "schema=1|sequence="+(string)decision.sequence+
          "|event_id="+event.event_id+
          "|event_type="+IntegerToString(event.event_type)+
          "|server_time_msc="+(string)event.server_time_msc+
          "|sleeve="+event.sleeve_id+
          "|group="+event.trade_group_id+
          "|order="+(string)event.order_ticket+
          "|deal="+(string)event.deal_ticket+
          "|position="+(string)event.position_ticket+
          "|gross="+DoubleToString(event.gross_profit,12)+
          "|commission="+DoubleToString(event.commission,12)+
          "|swap="+DoubleToString(event.swap,12)+
          "|fee="+DoubleToString(event.fee,12)+
          "|net="+DoubleToString(decision.event_net_pnl,12)+
          "|net_return="+DoubleToString(event.net_return,12)+
          "|net_r="+DoubleToString(event.net_r,12)+
          "|mae_r="+DoubleToString(event.mae_r,12)+
          "|mfe_r="+DoubleToString(event.mfe_r,12)+
          "|bars_held="+IntegerToString(event.bars_held)+
          "|root="+decision.event_sha256;
  }

#endif
