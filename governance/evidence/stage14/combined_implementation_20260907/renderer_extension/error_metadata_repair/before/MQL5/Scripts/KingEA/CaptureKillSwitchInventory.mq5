#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Read-only Stage 9 broker-inventory evidence capture."
#property description "Contains no order submission, modification, or closure capability."

input string InpRequiredServer="JustMarkets-Demo2";
input string InpDrillId="DRILL-DEMO-001";
input int    InpReadinessTimeoutSeconds=30;

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

string SafeName(string value)
  {
   StringReplace(value," ","_");
   StringReplace(value,":","-");
   StringReplace(value,".","-");
   return value;
  }

void Row(const int handle,const string key,const string value)
  {
   FileWrite(handle,key,value);
  }

void OnStart()
  {
   string server="";
   ulong deadline=GetTickCount64()+(ulong)MathMax(1,InpReadinessTimeoutSeconds)*1000;
   while(GetTickCount64()<=deadline)
     {
      server=AccountInfoString(ACCOUNT_SERVER);
      if(server!="" && server!=InpRequiredServer)
        {
         PrintFormat("KingEA Stage 9 inventory refused: server='%s' required='%s'",
                     server,InpRequiredServer);
         return;
        }
      if(server==InpRequiredServer && (bool)TerminalInfoInteger(TERMINAL_CONNECTED))
         break;
      Sleep(250);
     }
   if(server!=InpRequiredServer || !(bool)TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      Print("KingEA Stage 9 inventory failed: Demo2 connection readiness timeout");
      return;
     }

   long login=(long)AccountInfoInteger(ACCOUNT_LOGIN);
   string login_text=(string)login;
   string suffix=(StringLen(login_text)>=4
                  ? StringSubstr(login_text,StringLen(login_text)-4)
                  : "REDACTED");
   string fingerprint=Sha256(server+"|"+login_text);
   int positions=PositionsTotal();
   int orders=OrdersTotal();
   if(login<=0 || fingerprint=="" || positions<0 || orders<0)
     {
      Print("KingEA Stage 9 inventory failed: identity or inventory unavailable");
      return;
     }

   string stamp=SafeName(TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   string relative="KingEA\\stage9_inventory_"+InpDrillId+"_"+stamp+".csv";
   int handle=FileOpen(relative,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,
                       ',',CP_UTF8);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("KingEA Stage 9 inventory failed: FileOpen error=%d",GetLastError());
      return;
     }
   FileWrite(handle,"key","value");
   Row(handle,"scope","READ_ONLY_KILL_SWITCH_EVIDENCE");
   Row(handle,"drill_id",InpDrillId);
   Row(handle,"server",server);
   Row(handle,"account_suffix",suffix);
   Row(handle,"account_fingerprint",fingerprint);
   Row(handle,"captured_server_time",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS));
   Row(handle,"captured_utc",TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   Row(handle,"position_count",IntegerToString(positions));
   for(int i=0;i<positions;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
        {
         FileClose(handle);
         Print("KingEA Stage 9 inventory failed: position selection");
         return;
        }
      string prefix="position_"+IntegerToString(i)+"_";
      Row(handle,prefix+"ticket",(string)ticket);
      Row(handle,prefix+"symbol",PositionGetString(POSITION_SYMBOL));
      Row(handle,prefix+"type",(string)PositionGetInteger(POSITION_TYPE));
      Row(handle,prefix+"volume",DoubleToString(PositionGetDouble(POSITION_VOLUME),8));
      Row(handle,prefix+"open_price",DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),8));
      Row(handle,prefix+"stop_loss",DoubleToString(PositionGetDouble(POSITION_SL),8));
      Row(handle,prefix+"take_profit",DoubleToString(PositionGetDouble(POSITION_TP),8));
     }
   Row(handle,"order_count",IntegerToString(orders));
   for(int i=0;i<orders;i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
        {
         FileClose(handle);
         Print("KingEA Stage 9 inventory failed: order selection");
         return;
        }
      string prefix="order_"+IntegerToString(i)+"_";
      Row(handle,prefix+"ticket",(string)ticket);
      Row(handle,prefix+"symbol",OrderGetString(ORDER_SYMBOL));
      Row(handle,prefix+"type",(string)OrderGetInteger(ORDER_TYPE));
      Row(handle,prefix+"volume_initial",DoubleToString(OrderGetDouble(ORDER_VOLUME_INITIAL),8));
      Row(handle,prefix+"entry_price",DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN),8));
      Row(handle,prefix+"stop_loss",DoubleToString(OrderGetDouble(ORDER_SL),8));
      Row(handle,prefix+"take_profit",DoubleToString(OrderGetDouble(ORDER_TP),8));
      Row(handle,prefix+"expiration",(string)OrderGetInteger(ORDER_TIME_EXPIRATION));
     }
   Row(handle,"order_capability","PROHIBITED_AND_ABSENT");
   Row(handle,"performance_authorization","DENIED");
   FileFlush(handle);
   FileClose(handle);

   string full=TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+relative;
   PrintFormat("KingEA Stage 9 inventory capture complete: %s",full);
   PrintFormat("Result: PASS; server=%s; suffix=%s; positions=%d; orders=%d; no order capability.",
               server,suffix,positions,orders);
  }
