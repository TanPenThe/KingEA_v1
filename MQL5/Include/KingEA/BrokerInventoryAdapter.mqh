#ifndef KINGEA_BROKER_INVENTORY_ADAPTER_MQH
#define KINGEA_BROKER_INVENTORY_ADAPTER_MQH

// Read-only MT5 adapter for restart reconciliation.
// It never submits, changes, closes, or cancels an order or position.

#include <KingEA/OperationalSafety.mqh>

bool KingEAParseOwnershipComment(const string comment,
                                 string &sleeve_id,
                                 string &trade_group)
  {
   string tokens[];
   int count=StringSplit(comment,'|',tokens);
   if(count!=3 || tokens[0]!="KINGEA" || tokens[1]=="" || tokens[2]=="")
      return false;
   sleeve_id=tokens[1];
   trade_group=tokens[2];
   return true;
  }

bool KingEACollectBrokerInventory(KingEAInventory &inventory,string &reason)
  {
   ZeroMemory(inventory);
   inventory.account_login=(long)AccountInfoInteger(ACCOUNT_LOGIN);
   inventory.server=AccountInfoString(ACCOUNT_SERVER);
   inventory.trade_mode=(int)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   inventory.margin_mode=(int)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

   int positions=PositionsTotal();
   int orders=OrdersTotal();
   if(positions<0 || positions>KINGEA_MAX_INVENTORY ||
      orders<0 || orders>KINGEA_MAX_INVENTORY)
     {
      reason="BROKER_INVENTORY_CAPACITY_EXCEEDED";
      return false;
     }

   inventory.position_count=positions;
   for(int i=0;i<positions;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
        {
         reason="POSITION_SELECTION_FAILED";
         return false;
        }
      KingEAPositionRecord record={};
      record.ticket=ticket;
      record.identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      record.symbol=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      record.direction=(type==POSITION_TYPE_BUY ? 1 : -1);
      record.volume=PositionGetDouble(POSITION_VOLUME);
      record.open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      record.stop_loss=PositionGetDouble(POSITION_SL);
      record.take_profit=PositionGetDouble(POSITION_TP);
      record.magic=PositionGetInteger(POSITION_MAGIC);
      string comment=PositionGetString(POSITION_COMMENT);
      if(!KingEAParseOwnershipComment(comment,record.sleeve_id,record.trade_group))
        {
         reason="UNOWNED_POSITION_COMMENT";
         return false;
        }
      inventory.positions[i]=record;
     }

   inventory.order_count=orders;
   for(int i=0;i<orders;i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
        {
         reason="ORDER_SELECTION_FAILED";
         return false;
        }
      KingEAOrderRecord record={};
      record.ticket=ticket;
      record.type=(int)OrderGetInteger(ORDER_TYPE);
      record.symbol=OrderGetString(ORDER_SYMBOL);
      record.volume_initial=OrderGetDouble(ORDER_VOLUME_INITIAL);
      record.volume_current=OrderGetDouble(ORDER_VOLUME_CURRENT);
      record.entry_price=OrderGetDouble(ORDER_PRICE_OPEN);
      record.stop_loss=OrderGetDouble(ORDER_SL);
      record.take_profit=OrderGetDouble(ORDER_TP);
      record.magic=OrderGetInteger(ORDER_MAGIC);
      string comment=OrderGetString(ORDER_COMMENT);
      if(!KingEAParseOwnershipComment(comment,record.sleeve_id,record.trade_group))
        {
         reason="UNOWNED_ORDER_COMMENT";
         return false;
        }
      inventory.orders[i]=record;
     }

   reason="OK";
   return true;
  }

#endif
