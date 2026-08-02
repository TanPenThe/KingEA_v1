#property copyright "KingEA"
#property version   "1.00"
#property script_show_inputs
#property description "Local custom-symbol round-trip probe for two native crossed ticks."
#property description "No orders; signals; indicators; returns; optimizer logic; deletion; or RSB mutation."

input bool   InpAuthorizeLocalProbe = false;
input string InpOriginSymbol = "ETHUSD.s";
input string InpProbeSymbol = "KINGEA_DIAG_CROSSED_V1";
input string InpProbePath = "KingEA\\Diagnostics";

const long FIRST_MSC = 1709374488223;
const long SECOND_MSC = 1709375322820;

bool SameDouble(const double left,const double right)
  {
   return left==right;
  }

bool CopyExactOriginTick(const long time_msc,MqlTick &result)
  {
   MqlTick ticks[];
   ResetLastError();
   int copied=CopyTicksRange(InpOriginSymbol,ticks,COPY_TICKS_ALL,(ulong)time_msc,(ulong)time_msc);
   if(copied!=1)
     {
      PrintFormat("KingEA crossed-tick probe failed: expected one origin tick at %I64d; copied=%d error=%d",time_msc,copied,GetLastError());
      return false;
     }
   result=ticks[0];
   return true;
  }

bool SameTick(const MqlTick &left,const MqlTick &right)
  {
   return left.time_msc==right.time_msc && left.time==right.time &&
          SameDouble(left.bid,right.bid) && SameDouble(left.ask,right.ask) &&
          SameDouble(left.last,right.last) && left.volume==right.volume &&
          SameDouble(left.volume_real,right.volume_real) && left.flags==right.flags;
  }

void OnStart()
  {
   if(!InpAuthorizeLocalProbe)
     {
      Print("KingEA crossed-tick probe refused: set InpAuthorizeLocalProbe=true for this registered local diagnostic only.");
      return;
     }
   string server=AccountInfoString(ACCOUNT_SERVER);
   if(StringFind(server,"Demo2")<0)
     {
      PrintFormat("KingEA crossed-tick probe refused: run on JustMarkets-Demo2; current server=%s",server);
      return;
     }
   if(!SymbolSelect(InpOriginSymbol,true))
     {
      PrintFormat("KingEA crossed-tick probe failed: origin unavailable; error=%d",GetLastError());
      return;
     }

   bool is_custom=false;
   bool exists=SymbolExist(InpProbeSymbol,is_custom);
   if(exists && !is_custom)
     {
      Print("KingEA crossed-tick probe refused: probe name belongs to a broker symbol.");
      return;
     }
   if(!exists && !CustomSymbolCreate(InpProbeSymbol,InpProbePath,InpOriginSymbol))
     {
      PrintFormat("KingEA crossed-tick probe failed: CustomSymbolCreate error=%d",GetLastError());
      return;
     }
   if(!SymbolSelect(InpProbeSymbol,true))
     {
      PrintFormat("KingEA crossed-tick probe failed: cannot select probe symbol; error=%d",GetLastError());
      return;
     }
   MqlTick existing[];
   if(CopyTicks(InpProbeSymbol,existing,COPY_TICKS_ALL,0,1)>0)
     {
      Print("KingEA crossed-tick probe refused: probe symbol already contains ticks. Do not delete it; use a reviewed new version.");
      return;
     }

   MqlTick source[];
   ArrayResize(source,2);
   if(!CopyExactOriginTick(FIRST_MSC,source[0]) || !CopyExactOriginTick(SECOND_MSC,source[1]))
      return;
   if(source[0].ask>=source[0].bid || source[1].ask>=source[1].bid)
     {
      Print("KingEA crossed-tick probe failed: captured origin ticks are no longer reversed; source history changed.");
      return;
     }

   ResetLastError();
   int added=CustomTicksAdd(InpProbeSymbol,source,2);
   int add_error=GetLastError();
   MqlTick roundtrip[];
   ResetLastError();
   int copied=CopyTicksRange(InpProbeSymbol,roundtrip,COPY_TICKS_ALL,(ulong)FIRST_MSC,(ulong)SECOND_MSC);
   int copy_error=GetLastError();

   bool exact=(added==2 && copied==2 && SameTick(source[0],roundtrip[0]) && SameTick(source[1],roundtrip[1]));
   string utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   string filename="KingEA\\crossed_tick_roundtrip_"+InpProbeSymbol+"_"+utc+".csv";
   StringReplace(filename,":","-");
   StringReplace(filename," ","_");
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,',',CP_UTF8);
   if(report!=INVALID_HANDLE)
     {
      FileWrite(report,"key","value","notes");
      FileWrite(report,"origin_server",server,"");
      FileWrite(report,"origin_symbol",InpOriginSymbol,"");
      FileWrite(report,"probe_symbol",InpProbeSymbol,"");
      FileWrite(report,"requested_ticks",2,"");
      FileWrite(report,"added_ticks",added,StringFormat("error=%d",add_error));
      FileWrite(report,"roundtrip_ticks",copied,StringFormat("error=%d",copy_error));
      FileWrite(report,"first_origin",StringFormat("%I64d|%.8f|%.8f|%d",source[0].time_msc,source[0].bid,source[0].ask,source[0].flags),"");
      if(copied>0)
         FileWrite(report,"first_roundtrip",StringFormat("%I64d|%.8f|%.8f|%d",roundtrip[0].time_msc,roundtrip[0].bid,roundtrip[0].ask,roundtrip[0].flags),"");
      FileWrite(report,"second_origin",StringFormat("%I64d|%.8f|%.8f|%d",source[1].time_msc,source[1].bid,source[1].ask,source[1].flags),"");
      if(copied>1)
         FileWrite(report,"second_roundtrip",StringFormat("%I64d|%.8f|%.8f|%d",roundtrip[1].time_msc,roundtrip[1].bid,roundtrip[1].ask,roundtrip[1].flags),"");
      FileWrite(report,"exact_roundtrip",exact ? "PASS" : "FAIL","Bid Ask timestamp flags last and volume fields compared exactly");
      FileWrite(report,"result",exact ? "PASS" : "FAIL","No strategy or performance authorization");
      FileFlush(report);
      FileClose(report);
     }
   PrintFormat("KingEA crossed-tick round-trip report: %s",TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
   PrintFormat("Result: %s; added=%d; copied=%d. Local diagnostic symbol only; RSB1 and RSB2 untouched.",exact ? "PASS" : "FAIL",added,copied);
  }
