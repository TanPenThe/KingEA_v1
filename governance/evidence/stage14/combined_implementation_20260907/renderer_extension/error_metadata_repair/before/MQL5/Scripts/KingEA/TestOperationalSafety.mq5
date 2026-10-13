#property copyright "KingEA"
#property version   "1.00"
#property description "Deterministic non-performance tests for KingEA Stage 7 operational safety."
#property description "No orders, strategy history, indicators, performance, OOS, or holdout access."

#include <KingEA/OperationalSafety.mqh>
#include <KingEA/BrokerInventoryAdapter.mqh>

int g_failures=0;
int g_checks=0;

void Check(const bool condition,const string label)
  {
   g_checks++;
   if(condition)
      return;
   g_failures++;
   PrintFormat("OPERATIONAL_SAFETY_TEST_FAIL: %s",label);
  }

KingEAPersistenceContext TestContext(const string suffix)
  {
   KingEAPersistenceContext context={};
   context.schema_version=1;
   context.deployment_id="STAGE7_TEST_"+suffix;
   context.candidate_hash="A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE";
   context.configuration_hash="CFG_TEST_V1";
   context.safety_contract_hash="E59C45C8CA54429390A95D96FDFDD381475555C8D0891FA92DBC31A88747258B";
   context.genesis_authorized=true;
   context.broker_flat=true;
   context.exposure_reconciled=true;
   return context;
  }

KingEAInventory TestInventory()
  {
   KingEAInventory inventory={};
   inventory.account_login=100001;
   inventory.server="JustMarkets-Demo2";
   inventory.trade_mode=0;
   inventory.margin_mode=2;
   inventory.position_count=1;
   inventory.positions[0].ticket=7001;
   inventory.positions[0].identifier=9001;
   inventory.positions[0].symbol="ETHUSD.s";
   inventory.positions[0].direction=1;
   inventory.positions[0].volume=0.01;
   inventory.positions[0].open_price=2200.0;
   inventory.positions[0].stop_loss=2150.0;
   inventory.positions[0].take_profit=0.0;
   inventory.positions[0].magic=260727;
   inventory.positions[0].trade_group="TG-001";
   inventory.positions[0].sleeve_id="CAND-ETH-ST-001";
   inventory.order_count=1;
   inventory.orders[0].ticket=8001;
   inventory.orders[0].type=2;
   inventory.orders[0].symbol="ETHUSD.s";
   inventory.orders[0].volume_initial=0.01;
   inventory.orders[0].volume_current=0.01;
   inventory.orders[0].entry_price=2250.0;
   inventory.orders[0].stop_loss=2200.0;
   inventory.orders[0].take_profit=0.0;
   inventory.orders[0].magic=260727;
   inventory.orders[0].trade_group="TG-002";
   inventory.orders[0].sleeve_id="CAND-ETH-ST-001";
   return inventory;
  }

KingEAConfigurationBinding TestBinding(const string configuration)
  {
   KingEAConfigurationBinding binding={};
   binding.deployment_id="KINGEA-DEMO2-001";
   binding.candidate_hash="A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE";
   binding.configuration_hash=configuration;
   binding.safety_contract_hash="E59C45C8CA54429390A95D96FDFDD381475555C8D0891FA92DBC31A88747258B";
   binding.build_id="KINGEA-STAGE7-20260727-A";
   binding.symbol="ETHUSD.s";
   binding.server_class="JustMarkets-Demo2";
   return binding;
  }

void TestPersistenceFailures()
  {
   KingEAPersistenceContext context=TestContext("INTERRUPT");
   KingEAPersistentEnvelope envelope={};
   envelope.committed_utc=D'2026.07.27 00:00:00';
   KingEAPersistenceResult result={};
   KingEACommitPersistentState(context,envelope,result);
   string temp=KingEAStateDirectory(context)+"\\snapshot_A.tmp";
   int handle=FileOpen(temp,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle!=INVALID_HANDLE)
     {
      FileWriteString(handle,"INTERRUPTED");
      FileFlush(handle);
      FileClose(handle);
     }
   KingEALoadPersistentState(context,result);
   Check(result.status==KINGEA_PERSIST_OK,
         "interrupted temporary write preserves committed pair");

   context=TestContext("CORRUPT");
   ZeroMemory(envelope);
   envelope.committed_utc=D'2026.07.27 00:00:00';
   KingEACommitPersistentState(context,envelope,result);
   handle=FileOpen(KingEAStateDirectory(context)+"\\snapshot_B.dat",
                   FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle!=INVALID_HANDLE)
     {
      FileWriteString(handle,"CORRUPTED\r\nBAD_HASH\r\n");
      FileClose(handle);
     }
   KingEALoadPersistentState(context,result);
   Check(result.status==KINGEA_PERSIST_QUARANTINE && result.quarantine,
         "one corrupted redundant slot quarantines instead of auto-resume");

   context=TestContext("MISSING");
   KingEALoadPersistentState(context,result);
   Check(result.status==KINGEA_PERSIST_QUARANTINE,
         "missing persistent pair quarantines");

   context=TestContext("ROLLBACK");
   ZeroMemory(envelope);
   envelope.committed_utc=D'2026.07.27 00:00:00';
   KingEACommitPersistentState(context,envelope,result);
   context.minimum_sequence=2;
   KingEALoadPersistentState(context,result);
   Check(result.status==KINGEA_PERSIST_SEQUENCE_FAILURE,
         "minimum sequence detects rollback");

   context=TestContext("GENESIS_REFUSED");
   context.genesis_authorized=false;
   KingEACommitPersistentState(context,envelope,result);
   Check(result.status==KINGEA_PERSIST_GENESIS_REFUSED,
         "genesis requires explicit authorization");
  }

void TestBrokerReconciliation()
  {
   KingEAInventory expected=TestInventory();
   KingEAInventory actual=expected;
   KingEAReconciliationResult result={};
   KingEAReconcileBrokerInventory(expected,actual,result);
   Check(result.status==KINGEA_RECONCILED && !result.quarantine,
         "exact ticket-level broker truth reconciles");

   actual.positions[0].volume=0.02;
   KingEAReconcileBrokerInventory(expected,actual,result);
   Check(result.status==KINGEA_RECONCILIATION_QUARANTINE,
         "altered broker position quarantines");

   actual=expected;
   actual.positions[0].stop_loss=0.0;
   expected.positions[0].stop_loss=0.0;
   KingEAReconcileBrokerInventory(expected,actual,result);
   Check(result.status==KINGEA_RECONCILIATION_QUARANTINE &&
         result.reason=="POSITION_UNPROTECTED",
         "matching but unprotected broker position quarantines");

   expected=TestInventory();
   actual=expected;
   actual.order_count=0;
   KingEAReconcileBrokerInventory(expected,actual,result);
   Check(result.status==KINGEA_RECONCILIATION_QUARANTINE,
         "missing pending order quarantines");

   actual=expected;
   actual.server="Other-Server";
   KingEAReconcileBrokerInventory(expected,actual,result);
   Check(result.reason=="ACCOUNT_IDENTITY_MISMATCH",
         "account or server mismatch quarantines");

   string sleeve="",group="";
   Check(KingEAParseOwnershipComment("KINGEA|CAND-ETH-ST-001|TG-001",sleeve,group) &&
         sleeve=="CAND-ETH-ST-001" && group=="TG-001",
         "broker ownership comment maps sleeve and trade group exactly");
   Check(!KingEAParseOwnershipComment("manual trade",sleeve,group),
         "unowned broker comment fails closed");
  }

void TestConfigurationVersioning()
  {
   KingEAConfigurationBinding approved=TestBinding("CFG_V1");
   KingEAConfigurationBinding runtime=approved;
   KingEAConfigurationFacts facts={};
   KingEAConfigurationResult result={};
   KingEAVerifyConfiguration(approved,runtime,facts,4,result);
   Check(result.status==KINGEA_CONFIG_OK &&
         !result.reset_validation_clock &&
         result.next_validation_epoch==4,
         "approved configuration preserves validation epoch");

   runtime.configuration_hash="CFG_V2";
   KingEAVerifyConfiguration(approved,runtime,facts,4,result);
   Check(result.status==KINGEA_CONFIG_QUARANTINE && result.quarantine,
         "unauthorized configuration quarantines");

   facts.change_authorized=true;
   facts.affected_positions_open=true;
   KingEAVerifyConfiguration(approved,runtime,facts,4,result);
   Check(result.status==KINGEA_CONFIG_CHANGE_REJECTED_OPEN_EXPOSURE,
         "configuration cannot change with open exposure");

   facts.affected_positions_open=false;
   KingEAVerifyConfiguration(approved,runtime,facts,4,result);
   Check(result.status==KINGEA_CONFIG_NEW_VALIDATION_EPOCH &&
         result.reset_validation_clock &&
         result.next_validation_epoch==5,
         "approved flat-state change starts a fresh validation epoch");
  }

void TestHeartbeat()
  {
   KingEAHeartbeatContext context={};
   context.deployment_id="STAGE7_TEST_HEARTBEAT";
   context.configuration_hash="CFG_V1";
   context.server_class="JustMarkets-Demo2";
   context.executable_path="C:\\Program Files\\MetaTrader 5\\terminal64.exe";
   context.data_root="D0E8209F77C8CF37AD8BF550E51FF075";
   context.process_id=12345;
   KingEAHeartbeatResult result={};
   Check(KingEAWriteHeartbeat(context,1,D'2026.07.27 00:00:00',result) &&
         result.ok && FileIsExist(result.path,FILE_COMMON),
         "fresh canonical heartbeat is atomically published");
   Check(!KingEAWriteHeartbeat(context,0,D'2026.07.27 00:00:00',result),
         "invalid heartbeat sequence fails closed");
  }

void OnStart()
  {
   KingEAPersistenceContext context=TestContext("ROUNDTRIP");
   KingEAPersistentEnvelope envelope={};
   envelope.sequence=0;
   envelope.committed_utc=D'2026.07.27 00:00:00';
   envelope.validation_epoch=7;
   envelope.risk_tier_percent=0.25;
   envelope.safety_state.daily_paused=true;
   envelope.safety_state.sleeve_recovery.force_bottom_tier=true;

   KingEAPersistenceResult committed={};
   KingEACommitPersistentState(context,envelope,committed);
   Check(committed.status==KINGEA_PERSIST_OK,"valid genesis commits");

   KingEAPersistenceResult loaded={};
   KingEALoadPersistentState(context,loaded);
   Check(loaded.status==KINGEA_PERSIST_OK &&
         loaded.envelope.validation_epoch==7 &&
         loaded.envelope.safety_state.daily_paused &&
         loaded.envelope.safety_state.sleeve_recovery.force_bottom_tier,
         "committed state reloads exactly");

   TestPersistenceFailures();
   TestBrokerReconciliation();
   TestConfigurationVersioning();
   TestHeartbeat();

   string status=(g_failures==0 ? "PASS" : "FAIL");
   string safe_utc=TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   StringReplace(safe_utc,":","-");
   StringReplace(safe_utc," ","_");
   string filename="KingEA\\operational_safety_contract_"+safe_utc+".csv";
   int report=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(report!=INVALID_HANDLE)
     {
      FileWrite(report,"section","key","value","notes");
      FileWrite(report,"audit","scope","NON_PERFORMANCE_STAGE7_OPERATIONAL_SAFETY","");
      FileWrite(report,"audit","build_id","KINGEA-STAGE7-20260727-A","");
      FileWrite(report,"result","status",status,"");
      FileWrite(report,"result","checks",IntegerToString(g_checks),"");
      FileWrite(report,"result","failures",IntegerToString(g_failures),"");
      FileWrite(report,"result","order_capability","PROHIBITED_AND_ABSENT","");
      FileClose(report);
      PrintFormat("KingEA operational safety contract report: %s",
                  TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+filename);
     }
   else
     {
      g_failures++;
      status="FAIL";
      PrintFormat("OPERATIONAL_SAFETY_TEST_FAIL: report open error=%d",GetLastError());
     }

   PrintFormat("OPERATIONAL_SAFETY_TEST_%s: checks=%d; failures=%d; non-performance; no order capability.",
               status,g_checks,g_failures);
  }
