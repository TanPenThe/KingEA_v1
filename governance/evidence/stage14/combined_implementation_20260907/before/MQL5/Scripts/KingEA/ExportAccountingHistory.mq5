#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only Stage 13 order/deal/inventory accounting export."
#property description "No order placement, modification, cancellation, or strategy logic."

input string   InpExpectedServerFragment="Demo2";
input datetime InpFromServer= D'2026.07.28 00:00:00';
input datetime InpToServer= D'2026.07.29 00:00:00';
input string   InpRunLabel="STAGE9_DRILL_READ_ONLY";

string Hex(const uchar &bytes[])
  {
   string result="";
   for(int i=0;i<ArraySize(bytes);i++)
      result+=StringFormat("%02X",(int)bytes[i]);
   return result;
  }

string Sha256(const string value)
  {
   uchar source[],key[],digest[];
   int count=StringToCharArray(value,source,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=0)
      return "";
   ArrayResize(source,count-1);
   if(CryptEncode(CRYPT_HASH_SHA256,source,key,digest)!=32)
      return "";
   return Hex(digest);
  }

string SafeText(string value)
  {
   StringReplace(value,"\r"," ");
   StringReplace(value,"\n"," ");
   StringReplace(value,",",";");
   return value;
  }

void OnStart()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   long login=AccountInfoInteger(ACCOUNT_LOGIN);
   if(StringFind(server,InpExpectedServerFragment)<0 ||
      AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO ||
      InpFromServer<=0 || InpToServer<=InpFromServer)
     {
      Print("KingEA Stage 13 export refused: Demo2 identity/date guard failed.");
      return;
     }
   string fingerprint=Sha256(server+"|"+(string)login);
   if(StringLen(fingerprint)!=64 || !HistorySelect(InpFromServer,InpToServer-1))
     {
      Print("KingEA Stage 13 export refused: fingerprint/history unavailable.");
      return;
     }
   string timestamp=TimeToString(TimeLocal(),TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   StringReplace(timestamp,":","-"); StringReplace(timestamp," ","_");
   string path="KingEA\\accounting_history_"+InpRunLabel+"_"+timestamp+".csv";
   int handle=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_COMMON,',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      Print("KingEA Stage 13 export refused: output unavailable.");
      return;
     }
   FileWrite(handle,"record_type","account_fingerprint","server","time_msc",
             "ticket","related_order","position_id","type","entry","reason",
             "symbol","volume","price","stop_loss","take_profit","profit",
             "commission","swap","fee","magic","comment");
   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0) continue;
      FileWrite(handle,"DEAL",fingerprint,SafeText(server),
                HistoryDealGetInteger(ticket,DEAL_TIME_MSC),ticket,
                HistoryDealGetInteger(ticket,DEAL_ORDER),
                HistoryDealGetInteger(ticket,DEAL_POSITION_ID),
                HistoryDealGetInteger(ticket,DEAL_TYPE),
                HistoryDealGetInteger(ticket,DEAL_ENTRY),
                HistoryDealGetInteger(ticket,DEAL_REASON),
                SafeText(HistoryDealGetString(ticket,DEAL_SYMBOL)),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_VOLUME),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_SL),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_TP),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_PROFIT),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_COMMISSION),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_SWAP),8),
                DoubleToString(HistoryDealGetDouble(ticket,DEAL_FEE),8),
                HistoryDealGetInteger(ticket,DEAL_MAGIC),
                SafeText(HistoryDealGetString(ticket,DEAL_COMMENT)));
     }
   int orders=HistoryOrdersTotal();
   for(int i=0;i<orders;i++)
     {
      ulong ticket=HistoryOrderGetTicket(i);
      if(ticket==0) continue;
      FileWrite(handle,"ORDER",fingerprint,SafeText(server),
                HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP_MSC),ticket,ticket,
                HistoryOrderGetInteger(ticket,ORDER_POSITION_ID),
                HistoryOrderGetInteger(ticket,ORDER_TYPE),"",
                HistoryOrderGetInteger(ticket,ORDER_REASON),
                SafeText(HistoryOrderGetString(ticket,ORDER_SYMBOL)),
                DoubleToString(HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL),8),
                DoubleToString(HistoryOrderGetDouble(ticket,ORDER_PRICE_OPEN),8),
                DoubleToString(HistoryOrderGetDouble(ticket,ORDER_SL),8),
                DoubleToString(HistoryOrderGetDouble(ticket,ORDER_TP),8),"","","","",
                HistoryOrderGetInteger(ticket,ORDER_MAGIC),
                SafeText(HistoryOrderGetString(ticket,ORDER_COMMENT)));
     }
   FileWrite(handle,"INVENTORY_SUMMARY",fingerprint,SafeText(server),
             (long)TimeTradeServer()*1000,"","","","","","","","","","","","","","","","",
             StringFormat("positions=%d;orders=%d",PositionsTotal(),OrdersTotal()));
   FileClose(handle);
   PrintFormat("KingEA Stage 13 read-only accounting export complete: %s deals=%d orders=%d positions=%d pending=%d fingerprint=%s",
               path,deals,orders,PositionsTotal(),OrdersTotal(),fingerprint);
  }

