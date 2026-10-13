#property copyright "KingEA"
#property version   "1.01"
#property tester_everytick_calculate
#property tester_file "KingEA\\research_inputs\\PROTECTION_INTERVALS_STAGE14_20260802.csv"
#property description "Guarded Candidate 001 research adapter; Strategy Tester only."
#property description "Requires a separately authorized content-addressed manifest."

#include <KingEA/ResearchExecution.mqh>
#include <KingEA/RegimeClassifier.mqh>
#include <KingEA/SleeveEthSt001.mqh>
#include <KingEA/SafetyKernel.mqh>
#include <KingEA/AccountingEvents.mqh>
#include <KingEA/NativeCostMetadataAdapter.mqh>
#include <KingEA/ZeroEntryDiagnostic.mqh>
#include <KingEA/DecisionADealAdapter.mqh>
#include <KingEA/DecisionAStaticStop.mqh>

input string InpRunManifest="";
input string InpManifestSha256="";
input string InpManifestFileSha256="";
input string InpDetachedAuthorizationToken="";
input string InpRootSha256="";
input string InpGate="0";
input string InpPurpose="DEVELOPMENT";
input string InpPartition="";
input string InpBranch="RECORDED";
input string InpExpectedSymbol="";
input int    InpConfigurationId=-1;
input string InpEvaluationStart="";
input string InpEvaluationEndExclusive="";
input int    InpTesterModel=4;
input bool   InpLocalAgentsOnly=true;
input bool   InpRemoteAgentsDisabled=true;
input bool   InpCloudAgentsDisabled=true;
input string InpSelectionSha256="";
input string InpSurfaceSha256="";
input string InpStage15AuthorizationSha256="";
input string InpScenario="BASELINE_20MS";
input string InpExecutionAdapter="NATIVE";
input string InpCalendarSha256="";
input string InpCostManifestSha256="";
input string InpResearchSpecificationSha256="";
input string InpCalendarIntervalsFile="";
input string InpCalendarFileSha256="";
input int    InpDelayMs=20;
input double InpSpreadMultiplier=1.0;
input double InpCostMultiplier=1.0;
input double InpSlippageSpreadFraction=0.0;
input bool   InpVolatilityDependentSlippage=false;
input double InpMissedEntryFraction=0.0;
input uint   InpStressSeed=0;
input double InpCommissionPerLotRoundTurn=0.0;
input double InpSwapPerLotStress=0.0;
input double InpWeekendRiskMultiplier=0.50;
input int    InpMaintenanceEntryBlockMinutes=30;
input int    InpMaintenanceForceFlatMinutes=5;
input int    InpMaintenanceCleanMinutes=15;
input bool   InpWorkloadDryRun=false;
input string InpDryBenchmarkRootSha256="";
input string InpDryAuthorizationToken="";
input int    InpDryBenchmarkPassId=0;
input string InpExpectedServerFragment="";
input int    InpExpectedTerminalBuild=0;
input bool   InpNativeConformance=false;
input string InpConformanceControlSha256="";
input bool   InpZeroEntryDiagnostic=false;
input string InpDiagnosticRootSha256="";
input string InpDiagnosticAuthorizationToken="";

KingEASleeveBar g_bars[];
KingEARegimeHysteresis g_regime_state={};
KingEASleeveState g_sleeve_state={};
KingEASafetyState g_safety_state={};
KingEACandidateParameters g_parameters={};
KingEASleevePositionContext g_position={};
KingEASleeveBar g_current_bar={};
bool g_has_current=false;
bool g_initialized=false;
bool g_manifest_valid=false;
datetime g_evaluation_start=0;
datetime g_evaluation_end_exclusive=0;
bool g_evaluation_end_reached=false;
bool g_evaluation_end_unresolved=false;
DecisionALifecycle g_da;
DANativeCaptureRing g_da_capture;
DAObservationRing g_da_observations;
DAPosition g_da_sealed={};
DANativeCapture g_da_terminals[64];int g_da_terminal_count=0;
string g_da_records[],g_da_record_roles[];
string g_da_candidate="",g_da_configuration="",g_da_profile="";
string g_da_close_reason="STRATEGY_CLOSE";
bool g_da_close_attempted=false,g_da_reduction_attempted=false;
bool g_da_context=false,g_da_loss_reported=false,g_da_fallback_due=false;
double g_da_base=0;
KingEANativeCostEvidence *g_native_cost=NULL;
MqlTradeResult g_native_receipt={};
KingEANativeDealFact g_native_close_fact={};
bool g_native_entry_captured=false,g_native_receipt_known=false,g_native_exit_pending=false;
bool g_native_boundary_projected=false,g_native_in_tester_end=false;
double g_native_boundary_equity=0;
long g_native_start_msc=0,g_native_last_eligible_tick=0;
int g_boundary_finalization_count=0;
string g_native_sidecar="";
double g_initial_equity=0.0;
double g_equity_high=0.0;
double g_day_open=0.0;
double g_week_open=0.0;
double g_month_open=0.0;
datetime g_day_start=0;
datetime g_week_start=0;
datetime g_month_start=0;
int g_entries=0;
int g_exits=0;
int g_missed=0;
int g_delay_expired=0;
int g_gate_rejected_after_delay=0;
int g_virtual_execution_failed=0;
int g_hard_failures=0;
double g_trade_returns[];
double g_trade_r[];
double g_daily_returns[];
double g_entry_equity=0.0;
double g_entry_risk_money=0.0;
KingEAAccountingCheckpoint g_accounting_checkpoint={};
string g_accounting_payloads[];
string g_account_fingerprint="";
string g_trade_group_id="";
double g_trade_net[];
double g_trade_mfe_r=0.0;
double g_trade_mae_r=0.0;
int g_trade_bars_held=0;
int g_accounting_close_count=0;
ulong g_open_order_ticket=0;
ulong g_open_deal_ticket=0;
ulong g_position_ticket=0;
ulong g_close_order_ticket=0;
ulong g_close_deal_ticket=0;
double g_trade_volume=0.0;
int g_current_volatility=KINGEA_STAGE10_VOLATILITY_INVALID;
KingEAResearchVirtualPosition g_virtual_position={};
bool g_virtual_pending=false;
string g_pending_signal_identity="";
int g_pending_direction=KINGEA_DIRECTION_NONE;
double g_pending_stop=0.0;
double g_pending_volume=0.0;
double g_pending_risk_money=0.0;
datetime g_pending_signal_bar=0;
long g_pending_due_msc=0;
long g_pending_expiry_msc=0;
double g_pending_requested_price=0.0;
long g_market_interval_start[];
long g_market_interval_end[];
long g_market_interval_prefix_max_end[];
string g_market_interval_type[];
bool g_market_intervals_loaded=false;
KingEAResearchMarketIntervalSnapshot g_market_interval_snapshot={};
double g_current_bar_spreads[];
datetime g_spread_slot_time[];
double g_spread_slot_median[];
KingEAResearchSpreadBaselineCache g_spread_baseline_cache={};
double g_latest_spread_ratio=0.0;
int g_above_three_count=0;
long g_above_three_start_msc=0;
bool g_spread_reduced=false;
long g_dry_tick_count=0;
long g_dry_first_tick_msc=0;
long g_dry_last_tick_msc=0;
KingEAZeroEntryFunnel g_zero_entry_funnel={};

#define KINGEA_ZERO_ENTRY_DIAGNOSTIC_ROOT "B17EA4E5AA3A6D823B522252D5997F63BC8C0A6CD620C0DDDBA26851E194185D"

void ResearchProcessPeriodTransition(const datetime now,const bool new_day,
                                     const bool new_week,const bool new_month);
void ResearchHealthyFacts(const datetime now,const double entry,
                          const double stop,const int direction,
                          KingEASafetyFacts &facts);
bool ResearchUsesVirtual();
bool ResearchNativeContext();
string DAManifestString(string key);
bool ResearchNativeCompletion();
bool ResearchConformanceValid();
void ResearchConformanceTick(const MqlTick &tick);
bool ResearchNativeOrderCheck(MqlTradeRequest &request);
bool g_cf_entry_attempted=false,g_cf_reduction_attempted=false,g_cf_close_attempted=false;
void ResearchNativePoll(const MqlTick &tick);
void ResearchNativeSafetyObserve(const MqlTick &tick);
bool ResearchNativeRequest(MqlTradeRequest &request,DAIntent intent);
bool ResearchNativeProject(bool boundary);
bool ResearchNativeBegin(const string group,const int side,const double volume,const long now,const double stop,const double equity,const double risk);
void ResearchNativeReceipt(const MqlTradeResult &receipt);
void ResearchNativeSeal(const MqlTick &tick);
bool ResearchNativeBoundaryFinalize();
bool ResearchNativeNormalCloseReady();
void ResearchNativeNormalCloseCommitted();
datetime ResearchParseEvaluationTime(const string value);
bool ResearchEvaluationWindowValid();
bool ResearchEvaluationEligible(const datetime evaluation_time);
bool ResearchEvaluationEndReached(const datetime evaluation_time);
void ResearchMarkEvaluationEnd();
bool ResearchTerminalEndHasUnresolvedExposure();
double ResearchEquity();
bool ResearchHasPosition();
bool ResearchMarketBlocked(const long now_msc,string &kind);
bool ResearchProtectedForNews();
bool ResearchReduceHalf(const MqlTick &tick);
void ResearchTrackSpread(const MqlTick &tick);
void ResearchUpdateSpreadState(const MqlTick &tick);
double ResearchCurrentSpreadRatio(const MqlTick &tick);
void ResearchDryExerciseIntent(const KingEASleeveDecision &intent,
                               const MqlTick &tick);
void ResearchDiagnosticExerciseIntent(const KingEASleeveDecision &intent,
                                     const MqlTick &tick);

string ResearchHex(const uchar &bytes[])
  {
   string result="";
   for(int i=0;i<ArraySize(bytes);i++)
      result+=StringFormat("%02X",(int)bytes[i]);
   return result;
  }

string ResearchSha256Bytes(const uchar &source[])
  {
   uchar key[],digest[];
   if(CryptEncode(CRYPT_HASH_SHA256,source,key,digest)!=32)
      return "";
   return ResearchHex(digest);
  }

string ResearchSha256String(const string value)
  {
   uchar bytes[];
   int count=StringToCharArray(value,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=0)
      return "";
   ArrayResize(bytes,count-1);
   return ResearchSha256Bytes(bytes);
  }

// Captured once per tester initialization. Hashing and parsing share these bytes.
uchar g_manifest_input_bytes[],g_calendar_input_bytes[];
string g_manifest_input_hash="",g_calendar_input_hash="";
bool g_manifest_capture_attempted=false,g_calendar_capture_attempted=false;

bool ResearchCaptureLocalInput(const string filename,uchar &bytes[],string &hash)
  {
   // No shared fallback. A missing staged local artifact fails closed.
   int handle=FileOpen(filename,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE)
      return false;
   ulong size=FileSize(handle);
   if(size==0 || size>10000000)
     { FileClose(handle); return false; }
   ArrayResize(bytes,(int)size);
   uint read=FileReadArray(handle,bytes,0,(int)size);
   FileClose(handle);
   if(read!=(uint)size)
      return false;
   hash=ResearchSha256Bytes(bytes);
   return ResearchHash(hash);
  }

string ResearchFileSha256(const string filename)
  {
   if(filename==InpRunManifest && filename!="")
     {
      if(!g_manifest_capture_attempted)
        {
         g_manifest_capture_attempted=true;
         ResearchCaptureLocalInput(filename,g_manifest_input_bytes,g_manifest_input_hash);
        }
      return g_manifest_input_hash;
     }
   if(filename==InpCalendarIntervalsFile && filename!="")
     {
      if(!g_calendar_capture_attempted)
        {
         g_calendar_capture_attempted=true;
         ResearchCaptureLocalInput(filename,g_calendar_input_bytes,g_calendar_input_hash);
        }
      return g_calendar_input_hash;
     }
   return "";
  }

bool PersistDryBenchmarkPayload(const string payload)
  {
   string filename=StringFormat(
      "KingEA\\stage14_workload_%s_%s_%06d.txt",
      InpDryBenchmarkRootSha256,InpBranch,InpDryBenchmarkPassId);
   if(FileIsExist(filename,FILE_COMMON))
      return false;
   int handle=FileOpen(filename,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(handle==INVALID_HANDLE)
      return false;
   uint written=FileWriteString(handle,payload);
   FileFlush(handle);
   FileClose(handle);
   return written==(uint)StringLen(payload);
  }

// A zero-entry diagnostic is deliberately a single non-optimised tester pass.
// Unlike normal research frames it therefore persists its immutable payload
// directly to Common\\Files rather than relying on OnTesterPass delivery.
bool PersistZeroEntryDiagnosticPayload(const string payload)
  {
   string filename=StringFormat(
      "KingEA\\stage14_spool\\%s\\ZERO_ENTRY_DIAGNOSTIC_%06d.frame",
      InpManifestSha256,InpConfigurationId);
   uchar expected[];
   int bytes=StringToCharArray(payload,expected,0,WHOLE_ARRAY,CP_UTF8);
   if(bytes<=1)
      return false;
   ArrayResize(expected,bytes-1);

   if(FileIsExist(filename,FILE_COMMON))
     {
      int existing=FileOpen(filename,FILE_READ|FILE_BIN|FILE_COMMON);
      if(existing==INVALID_HANDLE)
         return false;
      ulong size=FileSize(existing);
      if(size!=(ulong)ArraySize(expected))
        {
         FileClose(existing);
         return false;
        }
      uchar actual[];
      ArrayResize(actual,(int)size);
      uint read=FileReadArray(existing,actual,0,(int)size);
      FileClose(existing);
      if(read!=(uint)size)
         return false;
      for(int i=0;i<(int)size;i++)
         if(actual[i]!=expected[i])
            return false;
      return true;
     }

   int handle=FileOpen(filename,FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(handle==INVALID_HANDLE)
      return false;
   uint written=FileWriteArray(handle,expected,0,ArraySize(expected));
   FileFlush(handle);
   FileClose(handle);
   return written==(uint)ArraySize(expected);
  }

KingEAAccountingEvent ResearchAccountingBase(const int type,
                                              const string event_id,
                                              const long server_time_msc)
  {
   KingEAAccountingEvent event={};
   event.schema_version=1;
   event.event_id=event_id;
   event.event_type=type;
   event.server_time_msc=server_time_msc;
   event.utc_time_msc=server_time_msc;
   event.account_fingerprint=g_account_fingerprint;
   event.deployment_id="KINGEA-TESTER-STAGE13";
   event.candidate_id=ResearchUsesVirtual()?"CAND-ETH-ST-001":g_da_candidate;
   event.configuration_hash=ResearchUsesVirtual()?"A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE":g_da_configuration;
   event.sleeve_id="SLEEVE-1";
   event.trade_group_id=g_trade_group_id;
   event.symbol=_Symbol;
   event.account_equity=ResearchEquity();
   event.sleeve_equity=event.account_equity;
   event.source_quality="TESTER_ACCOUNTING_V1";
   return event;
  }

bool ResearchBufferAccounting(KingEAAccountingEvent &event)
  {
   KingEAAccountingDecision decision={};
   KingEAProcessAccountingEvent(event,g_accounting_checkpoint,decision);
   if(!decision.accepted)
     {
      g_hard_failures++;
      return false;
     }
   string payload=KingEAAccountingFramePayload(event,decision);
   if(payload=="")
     {
      g_hard_failures++;
      return false;
     }
   int count=ArraySize(g_accounting_payloads);
   ArrayResize(g_accounting_payloads,count+1);
   g_accounting_payloads[count]=payload;
   g_accounting_checkpoint=decision.next_checkpoint;
   return true;
  }

void ResearchUpdateTradeExcursion()
  {
   if(!g_position.has_position || ArraySize(g_bars)<1)
      return;
   double original_r=MathAbs(g_position.entry_price-
                             g_position.original_confirmed_stop);
   if(original_r<=0.0)
     {
      g_hard_failures++;
      return;
     }
   KingEASleeveBar bar=g_bars[ArraySize(g_bars)-1];
   double favorable=0.0,adverse=0.0;
   if(g_position.direction==KINGEA_DIRECTION_LONG)
     {
      favorable=(bar.high-g_position.entry_price)/original_r;
      adverse=(g_position.entry_price-bar.low)/original_r;
     }
   else
     {
      favorable=(g_position.entry_price-bar.low)/original_r;
      adverse=(bar.high-g_position.entry_price)/original_r;
     }
   g_trade_mfe_r=MathMax(g_trade_mfe_r,favorable);
   g_trade_mae_r=MathMax(g_trade_mae_r,adverse);
   g_trade_bars_held++;
  }

bool ResearchHash(const string value)
  {
   if(StringLen(value)!=64)
      return false;
   for(int i=0;i<64;i++)
     {
      ushort character=StringGetCharacter(value,i);
      if(!((character>='0' && character<='9') ||
           (character>='A' && character<='F')))
         return false;
     }
   return true;
  }

int ResearchGateNumber(){if(InpGate=="GATE1"||InpGate=="1")return 1;if(InpGate=="GATE2"||InpGate=="2")return 2;if(InpGate=="3")return 3;return 0;}

bool ResearchPartitionAuthorized()
  {
   if(InpPurpose=="DEVELOPMENT")
      return ResearchGateNumber()==1 &&
             ((StringFind(InpPartition,"FOLD_")==0 &&
               StringFind(InpPartition,"_TRAIN")>0) ||
              InpPartition=="FINAL_SELECTION");
   if(InpPurpose=="FORWARD")
      return ResearchGateNumber()==2 && StringFind(InpPartition,"FOLD_")==0 &&
             StringFind(InpPartition,"_FORWARD")>0;
   if(InpPurpose=="OOS")
      return ResearchGateNumber()==3 && InpPartition=="FORMAL_OOS" &&
             ResearchHash(InpSelectionSha256) && ResearchHash(InpSurfaceSha256);
   if(InpPurpose=="HOLDOUT")
      return InpPartition=="HOLDOUT" &&
             ResearchHash(InpStage15AuthorizationSha256);
   return false;
  }

bool ResearchAuthorizationValid()
  {
   if(InpNativeConformance)return ResearchConformanceValid();
   if(!MQLInfoInteger(MQL_TESTER) || InpTesterModel!=4 ||
      !InpLocalAgentsOnly || !InpRemoteAgentsDisabled ||
      !InpCloudAgentsDisabled || !ResearchPartitionAuthorized())
      return false;
   if(!ResearchHash(InpRootSha256) || !ResearchEvaluationWindowValid() ||
      (InpExecutionAdapter!="NATIVE" && InpExecutionAdapter!="VIRTUAL") ||
      InpScenario=="" || !ResearchHash(InpCalendarSha256) ||
      !ResearchHash(InpCalendarFileSha256) ||
      InpCalendarFileSha256!=InpCalendarSha256 ||
      InpCalendarIntervalsFile=="" ||
      ResearchFileSha256(InpCalendarIntervalsFile)!=InpCalendarFileSha256 ||
      !ResearchHash(InpCostManifestSha256) ||
      !ResearchHash(InpResearchSpecificationSha256) ||
      InpWeekendRiskMultiplier!=0.50 ||
      InpMaintenanceEntryBlockMinutes!=30 ||
      InpMaintenanceForceFlatMinutes!=5 ||
      InpMaintenanceCleanMinutes!=15)
      return false;
   // A normal B2 Gate 1 candidate execution has one permitted seam only.
   if(ResearchGateNumber()==1 && InpPurpose=="DEVELOPMENT" &&
      (InpZeroEntryDiagnostic || InpWorkloadDryRun ||
       InpExecutionAdapter!="NATIVE" || InpScenario!="BASELINE_20MS" ||
       InpDelayMs!=20 || InpSpreadMultiplier!=1.0 ||
       InpCostMultiplier!=1.0 || InpSlippageSpreadFraction!=0.0 ||
       InpVolatilityDependentSlippage || InpMissedEntryFraction!=0.0))
      return false;
   if(InpRunManifest=="" || !ResearchHash(InpManifestSha256) ||
      !ResearchHash(InpManifestFileSha256) ||
      ResearchFileSha256(InpRunManifest)!=InpManifestFileSha256)
      return false;
   string expected=ResearchSha256String(InpManifestSha256+"|"+
                                         InpPurpose+"|RUNNING");
   return expected!="" && InpDetachedAuthorizationToken==expected;
  }

datetime ResearchParseEvaluationTime(const string value)
  {
   // Manifests bind ISO-8601. Normalize deliberately rather than relying on a
   // terminal-specific permissive StringToTime interpretation of '-' or 'T'.
   if(StringLen(value)!=19 || StringGetCharacter(value,4)!='-' ||
      StringGetCharacter(value,7)!='-' || StringGetCharacter(value,10)!='T' ||
      StringGetCharacter(value,13)!=':' || StringGetCharacter(value,16)!=':')
      return 0;
   string normalized=value;
   StringReplace(normalized,"-",".");
   StringReplace(normalized,"T"," ");
   return StringToTime(normalized);
  }

bool ResearchEvaluationWindowValid()
  {
   g_evaluation_start=ResearchParseEvaluationTime(InpEvaluationStart);
   g_evaluation_end_exclusive=ResearchParseEvaluationTime(InpEvaluationEndExclusive);
   return g_evaluation_start>0 && g_evaluation_end_exclusive>g_evaluation_start;
  }

bool ResearchEvaluationEligible(const datetime evaluation_time)
  {
   return evaluation_time>=g_evaluation_start &&
          evaluation_time<g_evaluation_end_exclusive;
  }

bool ResearchEvaluationEndReached(const datetime evaluation_time)
  {
   return evaluation_time>=g_evaluation_end_exclusive;
  }

void ResearchMarkEvaluationEnd()
  {
   g_evaluation_end_reached=true;
   if(ResearchNativeBoundaryFinalize()) return;
   if(ResearchTerminalEndHasUnresolvedExposure())
     {
      // Frozen governance has no approved close/carry policy at a partition end.
      // Do not manufacture one; invalidate the pass before any completion frames.
      g_evaluation_end_unresolved=true;
      g_hard_failures++;
     }
  }

// OnTester can run without a tick at or after EvaluationEndExclusive.  It is
// consequently the independent, final authority for unresolved exposure.
bool ResearchTerminalEndHasUnresolvedExposure()
  {
   if(!ResearchUsesVirtual())return g_da.invalid||g_da.pending||(!g_da.projected&&g_da.started&&g_da.exposure!=DA_FLAT);
   if(g_native_boundary_projected && g_hard_failures==0) return false;
   return ResearchHasPosition() || g_position.has_position ||
          g_virtual_pending || g_trade_group_id!="";
  }

bool ResearchZeroEntryDiagnosticAuthorizationValid()
  {
   if(!InpZeroEntryDiagnostic || InpWorkloadDryRun ||
      !MQLInfoInteger(MQL_TESTER) || InpTesterModel!=4 ||
      !InpLocalAgentsOnly || !InpRemoteAgentsDisabled ||
      !InpCloudAgentsDisabled || InpPurpose!="GATE1_ZERO_ENTRY_DIAGNOSTIC" ||
      ResearchGateNumber()!=1 || InpPartition!="FOLD_1_TRAIN" ||
      (InpBranch!="RECORDED" && InpBranch!="RSB3") ||
      InpExecutionAdapter!="VIRTUAL" || InpConfigurationId!=7168 ||
      InpRootSha256!=KINGEA_ZERO_ENTRY_DIAGNOSTIC_ROOT ||
      InpDiagnosticRootSha256!=KINGEA_ZERO_ENTRY_DIAGNOSTIC_ROOT)
      return false;
   if(!ResearchHash(InpManifestSha256) || !ResearchHash(InpManifestFileSha256) ||
      InpRunManifest=="" || ResearchFileSha256(InpRunManifest)!=InpManifestFileSha256 ||
      !ResearchHash(InpCalendarSha256) || !ResearchHash(InpCalendarFileSha256) ||
      InpCalendarSha256!=InpCalendarFileSha256 || InpCalendarIntervalsFile=="" ||
      ResearchFileSha256(InpCalendarIntervalsFile)!=InpCalendarFileSha256 ||
      !ResearchHash(InpCostManifestSha256) || !ResearchHash(InpResearchSpecificationSha256))
      return false;
   string expected=ResearchSha256String(InpDiagnosticRootSha256+"|"+
                                        InpManifestSha256+
                                        "|GATE1_ZERO_ENTRY_DIAGNOSTIC|AUTHORIZED");
   return expected!="" && InpDiagnosticAuthorizationToken==expected;
  }

bool ResearchDryAuthorizationValid()
  {
   if(!InpWorkloadDryRun || !MQLInfoInteger(MQL_TESTER) ||
      InpTesterModel!=4 || !InpLocalAgentsOnly ||
      !InpRemoteAgentsDisabled || !InpCloudAgentsDisabled ||
      InpPurpose!="WORKLOAD_DRY_BENCHMARK" ||
      InpPartition!="FINAL_SELECTION" || InpScenario!="WORKLOAD_DRY" ||
      InpExecutionAdapter!="VIRTUAL" ||
      !ResearchHash(InpDryBenchmarkRootSha256) ||
      InpDryBenchmarkPassId<0 || InpExpectedServerFragment=="")
     { Print("KINGEA_DRY_AUTH_FAIL: CORE_FACTS"); return false; }
   if(StringFind(AccountInfoString(ACCOUNT_SERVER),InpExpectedServerFragment)<0)
     { Print("KINGEA_DRY_AUTH_FAIL: SERVER_IDENTITY"); return false; }
   if(InpExpectedTerminalBuild<=0 ||
      (int)TerminalInfoInteger(TERMINAL_BUILD)!=InpExpectedTerminalBuild)
     { Print("KINGEA_DRY_AUTH_FAIL: TERMINAL_BUILD"); return false; }
   string expected=ResearchSha256String(
      InpDryBenchmarkRootSha256+"|FULL_WORKLOAD_DRY_BENCHMARK|AUTHORIZED");
   if(expected=="" || InpDryAuthorizationToken!=expected)
     { Print("KINGEA_DRY_AUTH_FAIL: TOKEN"); return false; }
   if(!ResearchHash(InpCalendarSha256) ||
      !ResearchHash(InpCalendarFileSha256) ||
      InpCalendarFileSha256!=InpCalendarSha256 ||
      InpCalendarIntervalsFile=="")
     { Print("KINGEA_DRY_AUTH_FAIL: CALENDAR_FACTS"); return false; }
   if(ResearchFileSha256(InpCalendarIntervalsFile)!=InpCalendarFileSha256)
     { Print("KINGEA_DRY_AUTH_FAIL: CALENDAR_FILE"); return false; }
   if(!ResearchHash(InpCostManifestSha256) ||
      !ResearchHash(InpResearchSpecificationSha256))
     { Print("KINGEA_DRY_AUTH_FAIL: COST_FACTS"); return false; }
   if(InpWeekendRiskMultiplier!=0.50 ||
      InpMaintenanceEntryBlockMinutes!=30 ||
      InpMaintenanceForceFlatMinutes!=5 ||
      InpMaintenanceCleanMinutes!=15)
     { Print("KINGEA_DRY_AUTH_FAIL: POLICY_CONSTANTS"); return false; }
   return true;
  }

bool ResearchUsesVirtual()
  {
   return InpWorkloadDryRun || InpExecutionAdapter=="VIRTUAL";
  }

double ResearchEquity()
  {
   if(g_native_boundary_projected) return g_native_boundary_equity;
   if(ResearchUsesVirtual())return g_virtual_position.equity;
   double live=AccountInfoDouble(ACCOUNT_EQUITY),contribution=0;
   if(g_da_base<=0)return live;
   if(!g_da.started||g_da.projected)return MathMin(live,g_da_base);
   if(!g_da.OperationalContribution(contribution))return live; // Independent conservative account guard only; never group P&L.
   return MathMin(live,g_da_base+contribution);
  }

bool ResearchHasPosition()
  {
   if(ResearchUsesVirtual())return g_virtual_position.has_position;
   if(g_da.started)return !g_da.projected && (g_da.pending||g_da.exposure!=DA_FLAT);
   return PositionSelect(_Symbol); // Only initial foreign-exposure detection, never flat authority.
  }

bool ResearchLoadMarketIntervals()
  {
   ArrayResize(g_market_interval_start,0);
   ArrayResize(g_market_interval_end,0);
   ArrayResize(g_market_interval_prefix_max_end,0);
   ArrayResize(g_market_interval_type,0);
   if(!g_calendar_capture_attempted || !ResearchHash(g_calendar_input_hash) ||
      g_calendar_input_hash!=InpCalendarFileSha256)
      return false;
   string captured=CharArrayToString(g_calendar_input_bytes,0,ArraySize(g_calendar_input_bytes),CP_UTF8);
   if(StringLen(captured)>0 && StringGetCharacter(captured,0)==0xFEFF)
      captured=StringSubstr(captured,1);
   StringReplace(captured,"\r","");
   string lines[];
   int length=StringSplit(captured,'\n',lines);
   if(length<2 || lines[0]!="type,start_msc,end_msc,identity")
      return false;
   long previous_start=0;
   for(int line=1;line<length;line++)
     {
      if(lines[line]=="")continue;
      string fields[];
      if(StringSplit(lines[line],',',fields)!=4)return false;
      string type=fields[0],start_text=fields[1],end_text=fields[2],identity=fields[3];
      for(int k=0;k<StringLen(start_text);k++)
         if(StringGetCharacter(start_text,k)<'0'||StringGetCharacter(start_text,k)>'9')return false;
      for(int k=0;k<StringLen(end_text);k++)
         if(StringGetCharacter(end_text,k)<'0'||StringGetCharacter(end_text,k)>'9')return false;
      long start=(long)StringToInteger(start_text);
      long end=(long)StringToInteger(end_text);
      string normalized_type="";
      bool blocks_entry=false;
      if(!KingEAResearchNormalizeProtectionType(type,normalized_type,
                                                blocks_entry) ||
         start<=0 || end<=start || identity=="" ||
         (previous_start>0 && start<previous_start))
        { return false; }
      previous_start=start;
      if(!blocks_entry)
         continue;
      int count=ArraySize(g_market_interval_start);
      ArrayResize(g_market_interval_start,count+1);
      ArrayResize(g_market_interval_end,count+1);
      ArrayResize(g_market_interval_prefix_max_end,count+1);
      ArrayResize(g_market_interval_type,count+1);
      g_market_interval_start[count]=start;
      g_market_interval_end[count]=end;
      g_market_interval_prefix_max_end[count]=
         (count==0 ? end : MathMax(g_market_interval_prefix_max_end[count-1],end));
      g_market_interval_type[count]=normalized_type;
     }
   return ArraySize(g_market_interval_start)>0;
  }

bool ResearchMarketBlocked(const long now_msc,string &kind)
  {
   if(!g_market_intervals_loaded)
     { kind="MARKET_INTERVALS_INVALID"; return true; }
   if(g_market_interval_snapshot.healthy &&
      now_msc>=g_market_interval_snapshot.observed_at_msc &&
      now_msc<g_market_interval_snapshot.next_change_msc)
     {
      kind=g_market_interval_snapshot.kind;
      return g_market_interval_snapshot.blocked;
     }
   if(g_market_interval_snapshot.healthy &&
      now_msc<g_market_interval_snapshot.observed_at_msc)
     { kind="MARKET_TIME_BACKWARD"; return true; }
   if(!KingEAResearchResolveMarketInterval(
         g_market_interval_start,g_market_interval_end,
         g_market_interval_prefix_max_end,g_market_interval_type,
         now_msc,g_market_interval_snapshot))
     { kind="MARKET_INTERVALS_INVALID"; return true; }
   kind=g_market_interval_snapshot.kind;
   return g_market_interval_snapshot.blocked;
  }

bool ResearchProtectedForNews()
  {
   if(!g_position.has_position || !g_position.original_stop_confirmed ||
      g_trade_volume<=0.0)
      return false;
   double spread=MathAbs(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-
                         SymbolInfoDouble(_Symbol,SYMBOL_BID))*3.0;
   double slippage_fraction=(InpVolatilityDependentSlippage ?
      (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
       g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
      InpSlippageSpreadFraction);
   double worst_stop=(g_position.direction==KINGEA_DIRECTION_LONG ?
                      g_position.original_confirmed_stop-spread*(1.0+slippage_fraction) :
                      g_position.original_confirmed_stop+spread*(1.0+slippage_fraction));
   double profit=0.0;
   ENUM_ORDER_TYPE type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                         ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,_Symbol,g_trade_volume,g_position.entry_price,
                       worst_stop,profit))
      return false;
   double costs=(InpCommissionPerLotRoundTurn+InpSwapPerLotStress)*
                g_trade_volume*InpCostMultiplier;
   return profit-costs>0.0;
  }

double ResearchMedian(double &values[])
  {
   int count=ArraySize(values);
   if(count<=0)
      return 0.0;
   double ordered[];
   ArrayCopy(ordered,values);
   ArraySort(ordered);
   if((count%2)==1)
      return ordered[count/2];
   return (ordered[count/2-1]+ordered[count/2])/2.0;
  }

void ResearchFinalizeSpreadSlot(const datetime open_time)
  {
   double median=ResearchMedian(g_current_bar_spreads);
   if(!KingEAResearchObservedSpreadValid(median))
     { g_hard_failures++; ArrayResize(g_current_bar_spreads,0); return; }
   int count=ArraySize(g_spread_slot_time);
   ArrayResize(g_spread_slot_time,count+1);
   ArrayResize(g_spread_slot_median,count+1);
   g_spread_slot_time[count]=open_time;
   g_spread_slot_median[count]=median;
   datetime cutoff=open_time-90*86400;
   int first=0;
   while(first<ArraySize(g_spread_slot_time) &&
         g_spread_slot_time[first]<cutoff)
      first++;
   if(first>0)
     {
      int remaining=ArraySize(g_spread_slot_time)-first;
      for(int i=0;i<remaining;i++)
        {
         g_spread_slot_time[i]=g_spread_slot_time[i+first];
         g_spread_slot_median[i]=g_spread_slot_median[i+first];
        }
      ArrayResize(g_spread_slot_time,remaining);
      ArrayResize(g_spread_slot_median,remaining);
     }
   ArrayResize(g_current_bar_spreads,0);
  }

double ResearchSpreadBaseline(const datetime now)
  {
   MqlDateTime current={};
   TimeToStruct(now,current);
   double matches[];
   ArrayResize(matches,0);
   datetime cutoff=now-90*86400;
   for(int i=0;i<ArraySize(g_spread_slot_time);i++)
     {
      if(g_spread_slot_time[i]<cutoff || g_spread_slot_time[i]>=now)
         continue;
      MqlDateTime prior={};
      TimeToStruct(g_spread_slot_time[i],prior);
      if(prior.day_of_week==current.day_of_week && prior.hour==current.hour &&
         prior.min==current.min)
        {
         int count=ArraySize(matches);
         ArrayResize(matches,count+1);
         matches[count]=g_spread_slot_median[i];
        }
     }
   if(ArraySize(matches)<8)
      return 0.0;
   return ResearchMedian(matches);
  }

double ResearchCurrentSpreadRatio(const MqlTick &tick)
  {
   datetime bucket=(datetime)((long)tick.time/1800*1800);
   double baseline=0.0;
   if(!KingEAResearchSpreadBaselineCacheHit(g_spread_baseline_cache,
                                             bucket,baseline))
     {
      baseline=ResearchSpreadBaseline(bucket);
      KingEAResearchStoreSpreadBaseline(g_spread_baseline_cache,
                                         bucket,baseline);
     }
   double spread=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
   if(baseline<=0.0 || spread<0.0 || !MathIsValidNumber(spread))
      return 0.0;
   return spread/baseline;
  }

void ResearchTrackSpread(const MqlTick &tick)
  {
   double spread=MathAbs(tick.ask-tick.bid);
   if(!KingEAResearchObservedSpreadValid(spread))
     { g_hard_failures++; return; }
   int count=ArraySize(g_current_bar_spreads);
   ArrayResize(g_current_bar_spreads,count+1,8192);
   g_current_bar_spreads[count]=spread;
  }

void ResearchUpdateSpreadState(const MqlTick &tick)
  {
   g_latest_spread_ratio=ResearchCurrentSpreadRatio(tick);
   if(g_latest_spread_ratio>3.0)
     {
      if(g_above_three_count==0)
         g_above_three_start_msc=(long)tick.time_msc;
      g_above_three_count++;
     }
   else
     {
      g_above_three_count=0;
      g_above_three_start_msc=0;
     }
  }

bool ResearchOrderSend(MqlTradeRequest &request,MqlTradeResult &result)
  {
   if(InpWorkloadDryRun || InpZeroEntryDiagnostic)
    {
      if(InpZeroEntryDiagnostic)
         g_zero_entry_funnel.native_order_calls++;
      Print(InpWorkloadDryRun ? "DRY_EXECUTION_PROHIBITED" :
                                "NON_ORDER_EXECUTION_PROHIBITED");
      g_hard_failures++;
      return false;
     }
   // Every tester order path revalidates the complete immutable guard.
   if(!g_initialized || !ResearchAuthorizationValid() ||
      (!ResearchUsesVirtual() && !DAStaticSendAllowed(request,g_da.intent,g_da,ResearchNativeContext())))
     {
      g_hard_failures++;
      return false;
     }
   if(!ResearchUsesVirtual() && g_da.intent!=DA_CONTAINMENT && !ResearchEvaluationEligible(TimeCurrent()))return false;
   if(!ResearchNativeOrderCheck(request))return false;
   return OrderSend(request,result);
  }

datetime ResearchDayStart(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   parts.hour=0; parts.min=0; parts.sec=0;
   return StructToTime(parts);
  }

datetime ResearchWeekStart(const datetime value)
  {
   datetime day=ResearchDayStart(value);
   MqlDateTime parts={};
   TimeToStruct(day,parts);
   int offset=(parts.day_of_week+6)%7;
   return day-offset*86400;
  }

datetime ResearchMonthStart(const datetime value)
  {
   MqlDateTime parts={};
   TimeToStruct(value,parts);
   parts.day=1; parts.hour=0; parts.min=0; parts.sec=0;
   return StructToTime(parts);
  }

void ResearchUpdatePeriods(const datetime now)
  {
   double equity=ResearchEquity();
   datetime day=ResearchDayStart(now);
   datetime week=ResearchWeekStart(now);
   datetime month=ResearchMonthStart(now);
   bool changed_day=(g_day_start>0 && day!=g_day_start);
   bool changed_week=(g_week_start>0 && week!=g_week_start);
   bool changed_month=(g_month_start>0 && month!=g_month_start);
   if(day!=g_day_start)
     {
      if(g_day_start>0 && g_day_open>0.0)
        {
         int count=ArraySize(g_daily_returns);
         ArrayResize(g_daily_returns,count+1);
         g_daily_returns[count]=(equity-g_day_open)/g_day_open;
        }
      g_day_start=day;
      g_day_open=equity;
     }
   if(week!=g_week_start) { g_week_start=week; g_week_open=equity; }
   if(month!=g_month_start) { g_month_start=month; g_month_open=equity; }
   g_equity_high=MathMax(g_equity_high,equity);
   if(changed_day || changed_week || changed_month)
      ResearchProcessPeriodTransition(now,changed_day,changed_week,changed_month);
  }

void ResearchUpdatePeriodsFast(const datetime now)
  {
   datetime day=(datetime)((long)now/86400*86400);
   if(g_day_start>0 && day==g_day_start)
     {
      g_equity_high=MathMax(g_equity_high,ResearchEquity());
      return;
     }
   ResearchUpdatePeriods(now);
  }

void ResearchFinalizeClosedTrade()
  {
   if(!ResearchUsesVirtual())
     {
      if(ResearchNativeNormalCloseReady())ResearchNativeProject(false);
      return;
     }
   if(!g_position.has_position || ResearchHasPosition())return;
   double equity=ResearchEquity();
   double profit=equity-g_entry_equity;
   int count=ArraySize(g_trade_returns);
   ArrayResize(g_trade_returns,count+1);
   ArrayResize(g_trade_r,count+1);
   ArrayResize(g_trade_net,count+1);
   g_trade_returns[count]=(g_entry_equity>0.0 ? profit/g_entry_equity : 0.0);
   g_trade_r[count]=(g_entry_risk_money>0.0 ? profit/g_entry_risk_money : 0.0);
   g_trade_net[count]=profit;
   KingEAAccountingEvent accounting=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_TRADE_GROUP_CLOSE,
      "CLOSE|"+g_trade_group_id+"|"+(string)(count+1),
      (long)TimeCurrent()*1000);
   accounting.order_ticket=g_close_order_ticket;
   accounting.deal_ticket=g_close_deal_ticket;
   accounting.position_ticket=g_position_ticket;
   accounting.direction=g_position.direction;
   accounting.volume=g_trade_volume;
   accounting.requested_price=0.0;
   accounting.executed_price=0.0;
   accounting.protective_stop=g_position.original_confirmed_stop;
   accounting.gross_profit=profit;
   accounting.net_return=g_trade_returns[count];
   accounting.net_r=g_trade_r[count];
   accounting.mae_r=g_trade_mae_r;
   accounting.mfe_r=g_trade_mfe_r;
   accounting.bars_held=g_trade_bars_held;
   accounting.reason_code="TRADE_GROUP_CLOSE";
   if(ResearchBufferAccounting(accounting))
      g_accounting_close_count++;
   if(!ResearchUsesVirtual()) ResearchNativeNormalCloseCommitted();
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(TimeCurrent(),g_position.entry_price,
                        g_position.original_confirmed_stop,
                        g_position.direction,facts);
   KingEASafetyRequest closed={};
   closed.event=KINGEA_EVENT_CLOSED_TRADE_GROUP;
   closed.scope=KINGEA_SCOPE_SLEEVE;
   closed.closed_group_full_loss=(g_trade_r[count]<=-0.80);
   KingEASafetyDecision safety={};
   KingEAEvaluateSafety(closed,facts,g_safety_state,safety);
   g_safety_state=safety.next_state;
   if(safety.action==KINGEA_ACTION_QUARANTINE)
      g_hard_failures++;
   ZeroMemory(g_position);
   g_entry_equity=0.0;
   g_entry_risk_money=0.0;
   g_trade_group_id="";
   g_trade_mfe_r=0.0;
   g_trade_mae_r=0.0;
   g_trade_bars_held=0;
   g_open_order_ticket=0;
   g_open_deal_ticket=0;
   g_position_ticket=0;
   g_close_order_ticket=0;
   g_close_deal_ticket=0;
   g_trade_volume=0.0;
   g_spread_reduced=false;
  }

void ResearchAppendBar(const KingEASleeveBar &bar)
  {
   int count=ArraySize(g_bars);
   if(count>=5000)
     {
      for(int i=1;i<count;i++)
         g_bars[i-1]=g_bars[i];
      count--;
      ArrayResize(g_bars,count);
     }
   ArrayResize(g_bars,count+1);
   g_bars[count]=bar;
  }

bool ResearchBuildRegime(KingEARegimeDecision &decision,
                         const datetime evaluation_time)
  {
   int count=ArraySize(g_bars);
   KingEARegimeBar bars[];
   ArrayResize(bars,count);
   for(int i=0;i<count;i++)
     {
      bars[i].open_time=g_bars[i].open_time;
      bars[i].open=g_bars[i].open;
      bars[i].high=g_bars[i].high;
      bars[i].low=g_bars[i].low;
      bars[i].close=g_bars[i].close;
      bars[i].complete=g_bars[i].complete;
     }
   KingEARegimeRequest request={};
   request.evaluation_time=evaluation_time;
   request.expected_open_slots=4320;
   request.maximum_staleness_seconds=1800;
   KingEAEvaluateRegime(bars,request,g_regime_state,decision);
   g_regime_state=decision.next_state;
   return decision.healthy;
  }

void ResearchHealthyFacts(const datetime now,const double entry,
                          const double stop,const int direction,
                          KingEASafetyFacts &facts)
  {
   ZeroMemory(facts);
   double equity=ResearchEquity();
   double loss=0.0;
   ENUM_ORDER_TYPE type=(direction==KINGEA_DIRECTION_LONG ?
                         ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,_Symbol,1.0,entry,stop,loss))
      loss=0.0;
   double margin=0.0;
   if(!OrderCalcMargin(type,_Symbol,1.0,entry,margin))
      margin=0.0;
   double spread=MathAbs(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-
                         SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double slippage=spread*InpSpreadMultiplier*
                   InpSlippageSpreadFraction;
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
   double slippage_cost=(tick_size>0.0 ? slippage/tick_size*tick_value : 0.0);
   facts.now_server=now;
   facts.account_equity=equity;
   facts.account_day_open_equity=g_day_open;
   facts.account_week_open_equity=g_week_open;
   facts.account_month_open_equity=g_month_open;
   facts.account_equity_high=g_equity_high;
   facts.sleeve_equity=equity;
   facts.sleeve_week_open_equity=g_week_open;
   facts.sleeve_month_open_equity=g_month_open;
   facts.sleeve_equity_high=g_equity_high;
   MqlDateTime parts={};
   TimeToStruct(now,parts);
   bool weekend=(parts.day_of_week==0 || parts.day_of_week==6);
   facts.sleeve_tier_percent=1.10*(weekend ? InpWeekendRiskMultiplier : 1.0);
   facts.cluster_known=true;
   facts.volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   facts.volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   facts.volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   facts.stressed_loss_per_lot=MathAbs(loss)+
      (InpCommissionPerLotRoundTurn+InpSwapPerLotStress+slippage_cost)*
      InpCostMultiplier;
   facts.live_margin_per_lot=margin;
   facts.notional_per_lot=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)*entry;
   facts.current_used_margin=(ResearchUsesVirtual() ? 0.0 :
                              AccountInfoDouble(ACCOUNT_MARGIN));
   facts.spread_ratio=(g_latest_spread_ratio>0.0 ? g_latest_spread_ratio : 999.0);
   facts.stop_valid=true;
   facts.state_valid=true;
   facts.configuration_valid=true;
   facts.exposure_reconciled=true;
   facts.stops_confirmed=true;
   facts.connection_healthy=(bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   facts.specification_healthy=true;
   string market_kind="";
   bool market_blocked=ResearchMarketBlocked((long)now*1000,market_kind);
   facts.calendar_fresh=g_market_intervals_loaded;
   facts.market_open=!market_blocked;
   facts.external_cash_flow_reconciled=true;
  }

void ResearchProcessPeriodTransition(const datetime now,const bool new_day,
                                     const bool new_week,const bool new_month)
  {
   double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(entry<=0.0)
      entry=1.0;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(now,entry,entry*0.99,KINGEA_DIRECTION_LONG,facts);
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_PERIOD_TRANSITION;
   request.scope=KINGEA_SCOPE_ACCOUNT;
   request.new_broker_day=new_day;
   request.new_broker_week=new_week;
   request.new_broker_month=new_month;
   KingEASafetyDecision decision={};
   KingEAEvaluateSafety(request,facts,g_safety_state,decision);
   g_safety_state=decision.next_state;
   if(decision.action==KINGEA_ACTION_QUARANTINE)
      g_hard_failures++;
   if(new_day)
     {
      KingEAAccountingEvent valuation=ResearchAccountingBase(
         KINGEA_ACCOUNTING_EVENT_VALUATION,
         "DAY|"+(string)ResearchDayStart(now),(long)now*1000);
      valuation.reason_code="BROKER_DAY_TRANSITION";
      ResearchBufferAccounting(valuation);
     }
  }

bool ResearchOpen(const KingEASleeveDecision &intent,const MqlTick &tick)
  {
   if(ResearchHasPosition() || g_virtual_pending)
      return false;
   KingEAResearchStress stress={};
   stress.delay_ms=InpDelayMs;
   stress.spread_multiplier=InpSpreadMultiplier;
   stress.cost_multiplier=InpCostMultiplier;
   stress.slippage_spread_fraction=(InpVolatilityDependentSlippage ?
      (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
       g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
      InpSlippageSpreadFraction);
   stress.missed_entry_fraction=InpMissedEntryFraction;
   stress.seed=InpStressSeed;
   KingEAResearchVirtualFill virtual_fill={};
   KingEAResearchApplyVirtualStress(stress,intent.signal_identity,
                                    tick.bid,tick.ask,intent.direction,
                                    virtual_fill);
   if(!virtual_fill.healthy)
      return false;
   if(virtual_fill.missed)
     {
      g_missed++;
      KingEAAccountingEvent missed=ResearchAccountingBase(
         KINGEA_ACCOUNTING_EVENT_MISSED_SIGNAL,
         "MISSED|"+intent.signal_identity,(long)tick.time_msc);
      missed.signal_id=intent.signal_identity;
      missed.direction=intent.direction;
      missed.reason_code="DETERMINISTIC_STRESS_MISS";
      ResearchBufferAccounting(missed);
      return true;
     }
   double entry=(ResearchUsesVirtual() ? virtual_fill.entry_price :
                 (intent.direction==KINGEA_DIRECTION_LONG ? tick.ask : tick.bid));
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_ENTRY;
   request.scope=KINGEA_SCOPE_SLEEVE;
   request.direction=(intent.direction==KINGEA_DIRECTION_LONG ?
                      KINGEA_SAFETY_LONG : KINGEA_SAFETY_SHORT);
   request.entry_price=entry;
   request.technical_stop=intent.technical_stop;
   request.signal_present=true;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(tick.time,entry,intent.technical_stop,
                        intent.direction,facts);
   KingEASafetyDecision safety={};
   KingEAEvaluateSafety(request,facts,g_safety_state,safety);
   g_safety_state=safety.next_state;
   if(safety.action!=KINGEA_ACTION_APPROVE_ENTRY &&
      safety.action!=KINGEA_ACTION_DOWNSIZE_ENTRY)
     {
      if(safety.reason==KINGEA_REASON_MONTHLY_BREAKER ||
         safety.reason==KINGEA_REASON_PERMANENT_BREAKER ||
         safety.reason==KINGEA_REASON_CUMULATIVE_REVIEW ||
         safety.reason==KINGEA_REASON_THROTTLE_REVIEW ||
         safety.reason==KINGEA_REASON_UNKNOWN_EXPOSURE)
         g_hard_failures++;
      return false;
     }
   double equity_before=ResearchEquity();
   int adapter=(ResearchUsesVirtual() ? KINGEA_RESEARCH_ADAPTER_VIRTUAL :
                                       KINGEA_RESEARCH_ADAPTER_NATIVE);
   KingEAResearchStress routed_stress=stress;
   routed_stress.missed_entry_fraction=0.0; // Already decided before sizing/queueing.
   KingEAResearchEntryRoute route={};
   long expiry=((long)tick.time/1800+1)*1800*1000;
   KingEAResearchRouteEntry(adapter,routed_stress,intent.signal_identity,
                            tick.bid,tick.ask,intent.direction,
                            safety.required_stop,safety.permitted_volume,
                            (long)tick.time_msc,expiry,0.0,false,
                            g_virtual_position,route);
   if(!route.healthy)
      return false;
   if(route.outcome==KINGEA_RESEARCH_DELAY_QUEUED)
     {
      g_virtual_pending=true;
      g_pending_signal_identity=intent.signal_identity;
      g_pending_direction=intent.direction;
      g_pending_stop=safety.required_stop;
      g_pending_volume=safety.permitted_volume;
      g_pending_risk_money=safety.permitted_risk_money;
      g_pending_signal_bar=intent.signal_bar_time;
      g_pending_due_msc=route.due_time_msc;
      g_pending_expiry_msc=route.expiry_time_msc;
      g_pending_requested_price=entry;
      return true;
     }
   MqlTradeResult result={};
   if(route.native_order_required)
     {
      MqlTradeRequest order={};
      order.action=TRADE_ACTION_DEAL;
      order.symbol=_Symbol;
      order.volume=safety.permitted_volume;
      order.type=(intent.direction==KINGEA_DIRECTION_LONG ?
                  ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      order.price=entry;
      order.sl=safety.required_stop;
      order.tp=0.0;
      order.deviation=0;
      order.magic=12001;
      order.comment="KINGEA|CAND-ETH-ST-001|"+intent.signal_identity;
      order.type_filling=ORDER_FILLING_FOK;
      if(!ResearchNativeBegin(intent.signal_identity,intent.direction,safety.permitted_volume,(long)tick.time_msc,safety.required_stop,equity_before,safety.permitted_risk_money))
         return false;
      bool sent=ResearchOrderSend(order,result);
      ResearchNativeReceipt(result);
      // Monitoring must survive rejection, ambiguity, and unsupported execution.
      if(!sent || result.retcode!=TRADE_RETCODE_DONE)return false;
      KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_NATIVE,routed_stress,
                               intent.signal_identity,tick.bid,tick.ask,
                               intent.direction,safety.required_stop,
                               safety.permitted_volume,(long)tick.time_msc,
                               expiry,result.price>0.0 ? result.price : entry,
                               true,g_virtual_position,route);
      if(!route.healthy)
         return false;
     }
   g_position.has_position=true;
   g_position.direction=intent.direction;
   g_position.entry_signal_bar_time=intent.signal_bar_time;
   g_position.entry_price=route.fill_price;
   g_position.original_confirmed_stop=safety.required_stop;
   g_position.original_stop_confirmed=true;
   g_entry_equity=equity_before;
   g_entry_risk_money=safety.permitted_risk_money;
   g_trade_group_id=intent.signal_identity;
   g_open_order_ticket=(ResearchUsesVirtual() ? 0 : result.order);
   g_open_deal_ticket=(ResearchUsesVirtual() ? 0 : result.deal);
   g_position_ticket=ResearchUsesVirtual()?0:g_da.position_ticket; // Native callback supplies exact ticket mapping.
   g_trade_volume=safety.permitted_volume;
   g_spread_reduced=false;
   KingEAAccountingEvent accounting=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_DEAL,
      "ENTRY|"+intent.signal_identity,(long)tick.time_msc);
   accounting.signal_id=intent.signal_identity;
   accounting.order_ticket=g_open_order_ticket;
   accounting.deal_ticket=g_open_deal_ticket;
   accounting.position_ticket=g_position_ticket;
   accounting.direction=intent.direction;
   accounting.volume=safety.permitted_volume;
   accounting.requested_price=entry;
   accounting.executed_price=g_position.entry_price;
   accounting.protective_stop=safety.required_stop;
   accounting.spread_attribution=MathAbs(tick.ask-tick.bid);
   accounting.slippage_attribution=MathAbs(g_position.entry_price-entry);
   accounting.reason_code=(ResearchUsesVirtual() ? "VIRTUAL_FILL" :
                                                    "NATIVE_FILL");
   ResearchBufferAccounting(accounting);
   g_entries++;
   return true;
  }

bool ResearchClose(const int direction,const MqlTick &tick)
  {
   if(!ResearchHasPosition())
      return true;
   if(ResearchUsesVirtual())
     {
      double raw=(direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
      double spread=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
      double slippage_fraction=(InpVolatilityDependentSlippage ?
         (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
          g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
         InpSlippageSpreadFraction);
      double slippage=spread*slippage_fraction;
      double exit_price=(direction==KINGEA_DIRECTION_LONG ? raw-slippage :
                                                           raw+slippage);
      double profit=0.0;
      ENUM_ORDER_TYPE type=(direction==KINGEA_DIRECTION_LONG ?
                            ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      if(!OrderCalcProfit(type,_Symbol,g_virtual_position.volume,
                          g_virtual_position.entry_price,exit_price,profit))
        { g_hard_failures++; return false; }
      double explicit_cost=(InpCommissionPerLotRoundTurn+
                            InpSwapPerLotStress)*g_virtual_position.volume*
                            InpCostMultiplier;
      g_virtual_position.equity+=profit-explicit_cost;
      g_virtual_position.has_position=false;
      g_close_order_ticket=0;
      g_close_deal_ticket=0;
      g_exits++;
      ResearchFinalizeClosedTrade();
      return true;
     }
   ResearchNativePoll(tick);
   if(g_da.invalid||g_da.pending||!g_da.residual.valid)return false;
   ulong ticket=g_da.position_ticket;
   double volume=g_da.residual.volume;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   request.action=TRADE_ACTION_DEAL;
   request.position=ticket;
   request.symbol=_Symbol;
   request.volume=volume;
   request.type=(direction==KINGEA_DIRECTION_LONG ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   request.price=(direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
   request.deviation=0;
   request.magic=12001;
   request.comment="KINGEA|CAND-ETH-ST-001|EXIT";
   request.type_filling=ORDER_FILLING_FOK;
   if(!ResearchNativeRequest(request,DA_CLOSE))return false;
   bool sent=ResearchOrderSend(request,result);ResearchNativeReceipt(result);
   if(!sent || result.retcode!=TRADE_RETCODE_DONE)return false;
   g_close_order_ticket=result.order;
   g_close_deal_ticket=result.deal;
   ResearchFinalizeClosedTrade();
   return true;
  }

bool ResearchReduceHalf(const MqlTick &tick)
  {
   if(!ResearchHasPosition() || g_spread_reduced)
      return true;
   if(!ResearchUsesVirtual()){
      ResearchNativePoll(tick);if(g_da.invalid||g_da.pending||!g_da.residual.valid)return false;
   }
   double current=(ResearchUsesVirtual() ? g_virtual_position.volume :g_da.residual.volume);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(current<=0.0 || step<=0.0 || minimum<=0.0)
      {g_da_close_reason="BROKER_VOLUME_FALLBACK";bool closed=ResearchClose(g_position.direction,tick);g_da_close_reason="STRATEGY_CLOSE";return closed;}
   double remaining=MathFloor((current*0.5+1e-12)/step)*step;
   remaining=NormalizeDouble(remaining,8);
   if(remaining<minimum)
      {g_da_close_reason="BROKER_VOLUME_FALLBACK";bool closed=ResearchClose(g_position.direction,tick);g_da_close_reason="STRATEGY_CLOSE";return closed;}
   double reduction=NormalizeDouble(current-remaining,8);
   if(reduction<minimum)
      {g_da_close_reason="BROKER_VOLUME_FALLBACK";bool closed=ResearchClose(g_position.direction,tick);g_da_close_reason="STRATEGY_CLOSE";return closed;}
   if(ResearchUsesVirtual())
     {
      double raw=(g_position.direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
      double spread=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
      double fraction=(InpVolatilityDependentSlippage ?
         (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
          g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
         InpSlippageSpreadFraction);
      double exit_price=(g_position.direction==KINGEA_DIRECTION_LONG ?
                         raw-spread*fraction : raw+spread*fraction);
      double profit=0.0;
      ENUM_ORDER_TYPE type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                            ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      if(!OrderCalcProfit(type,_Symbol,reduction,g_virtual_position.entry_price,
                          exit_price,profit))
         return false;
      double costs=(InpCommissionPerLotRoundTurn+InpSwapPerLotStress)*reduction*
                   InpCostMultiplier;
      g_virtual_position.equity+=profit-costs;
      g_virtual_position.volume=remaining;
     }
   else
     {
      MqlTradeRequest request={};
      MqlTradeResult result={};
      request.action=TRADE_ACTION_DEAL;
      request.position=g_da.position_ticket;
      request.symbol=_Symbol;
      request.volume=reduction;
      request.type=(g_position.direction==KINGEA_DIRECTION_LONG ?
                    ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      request.price=(g_position.direction==KINGEA_DIRECTION_LONG ? tick.bid : tick.ask);
      request.magic=12001;
      request.comment="KINGEA|EMERGENCY_SPREAD_REDUCTION";
      request.type_filling=ORDER_FILLING_FOK;
      if(!ResearchNativeRequest(request,DA_REDUCTION))return false;
      bool sent=ResearchOrderSend(request,result);ResearchNativeReceipt(result);
      // Only an authenticated terminal no-fill can schedule the existing fallback.
      // A return code or a missing callback alone cannot do so.
      if(!sent || result.retcode!=TRADE_RETCODE_DONE)return false;
     }
   g_trade_volume=remaining;
   g_spread_reduced=true;
   KingEAAccountingEvent safety=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_SAFETY,"SPREAD_REDUCE|"+g_trade_group_id,
      (long)tick.time_msc);
   safety.direction=g_position.direction;
   safety.volume=reduction;
   safety.reason_code="SPREAD_ABOVE_2_5X_REDUCE_50_PERCENT";
   ResearchBufferAccounting(safety);
   return true;
  }

void ResearchClearVirtualPending()
  {
   g_virtual_pending=false;
   g_pending_signal_identity="";
   g_pending_direction=KINGEA_DIRECTION_NONE;
   g_pending_stop=0.0;
   g_pending_volume=0.0;
   g_pending_risk_money=0.0;
   g_pending_signal_bar=0;
   g_pending_due_msc=0;
   g_pending_expiry_msc=0;
   g_pending_requested_price=0.0;
  }

void ResearchProcessVirtualPending(const MqlTick &tick)
  {
   if(!ResearchUsesVirtual() || !g_virtual_pending)
      return;
   if((long)tick.time_msc<g_pending_due_msc)
      return;
   string market_kind="";
   bool market_blocked=ResearchMarketBlocked((long)tick.time_msc,market_kind);
   bool gates_healthy=(InpSpreadMultiplier<=2.0 && !market_blocked &&
                       TerminalInfoInteger(TERMINAL_CONNECTED));
   KingEAResearchStress stress={};
   stress.delay_ms=InpDelayMs;
   stress.spread_multiplier=InpSpreadMultiplier;
   stress.cost_multiplier=InpCostMultiplier;
   stress.slippage_spread_fraction=(InpVolatilityDependentSlippage ?
      (g_current_volatility==KINGEA_STAGE10_VOLATILITY_HIGH ? 0.50 :
       g_current_volatility==KINGEA_STAGE10_VOLATILITY_EXTREME ? 1.00 : 0.25) :
      InpSlippageSpreadFraction);
   stress.missed_entry_fraction=0.0;
   stress.seed=InpStressSeed;
   KingEAResearchEntryRoute route={};
   KingEAResearchCompleteDelayedEntry(stress,g_pending_signal_identity,
                                      tick.bid,tick.ask,g_pending_direction,
                                      g_pending_stop,g_pending_volume,
                                      (long)tick.time_msc,g_pending_due_msc,
                                      g_pending_expiry_msc,gates_healthy,true,
                                      g_virtual_position,route);
   if(route.outcome==KINGEA_RESEARCH_DELAY_QUEUED)
      return;
   if(route.outcome==KINGEA_RESEARCH_DELAY_EXPIRY)
      g_delay_expired++;
   else if(route.outcome==KINGEA_RESEARCH_GATE_REJECT_AFTER_DELAY)
      g_gate_rejected_after_delay++;
   else if(route.outcome==KINGEA_RESEARCH_VIRTUAL_EXECUTION_FAILURE ||
           !route.healthy)
      g_virtual_execution_failed++;
   else if(route.outcome==KINGEA_RESEARCH_VIRTUAL_FILL)
     {
      g_position.has_position=true;
      g_position.direction=g_pending_direction;
      g_position.entry_signal_bar_time=g_pending_signal_bar;
      g_position.entry_price=route.fill_price;
      g_position.original_confirmed_stop=g_pending_stop;
      g_position.original_stop_confirmed=true;
      g_entry_equity=g_virtual_position.entry_equity;
      g_entry_risk_money=g_pending_risk_money;
      g_trade_group_id=g_pending_signal_identity;
      g_trade_volume=g_pending_volume;
      g_spread_reduced=false;
      KingEAAccountingEvent accounting=ResearchAccountingBase(
         KINGEA_ACCOUNTING_EVENT_DEAL,"ENTRY|"+g_pending_signal_identity,
         (long)tick.time_msc);
      accounting.signal_id=g_pending_signal_identity;
      accounting.direction=g_pending_direction;
      accounting.volume=g_pending_volume;
      accounting.requested_price=g_pending_requested_price;
      accounting.executed_price=route.accounting_price;
      accounting.protective_stop=g_pending_stop;
      accounting.spread_attribution=MathAbs(tick.ask-tick.bid)*InpSpreadMultiplier;
      accounting.slippage_attribution=MathAbs(route.accounting_price-
                                               g_pending_requested_price);
      accounting.reason_code="VIRTUAL_FILL_AFTER_DELAY";
      ResearchBufferAccounting(accounting);
      g_entries++;
     }
   ResearchClearVirtualPending();
  }

void ResearchEvaluateClosedBar(const datetime evaluation_time,
                               const MqlTick &tick)
  {
   KingEARegimeDecision regime={};
   ResearchBuildRegime(regime,evaluation_time);
   if(InpZeroEntryDiagnostic)
     {
      KingEAZeroEntryCountClosedBar(g_zero_entry_funnel);
      KingEAZeroEntryCountRegime(g_zero_entry_funnel,regime.healthy,
                                 regime.entry_eligible,(int)regime.reason);
     }
   g_current_volatility=regime.volatility_state;
   KingEASleeveRequest request={};
   request.evaluation_time=evaluation_time;
   request.parameters=g_parameters;
   request.regime=regime;
   request.position=g_position;
   request.has_open_trade_group=ResearchHasPosition();
   KingEASleeveDecision intent={};
   KingEAEvaluateSleeveEthSt001(g_bars,request,g_sleeve_state,intent);
   g_sleeve_state=intent.next_state;
   if(InpZeroEntryDiagnostic)
      KingEAZeroEntryCountSleeve(g_zero_entry_funnel,intent.healthy,
                                 intent.action==KINGEA_SLEEVE_ACTION_ENTRY,
                                 (int)intent.reason);
   ResearchUpdateTradeExcursion();
   // Warm-up bars advance deterministic indicator/sleeve state but cannot route
   // entries, exits, accounting, scoring, or selection before the exact start.
   // The first tick at the exclusive end cannot route a delayed/current signal.
   if(!ResearchEvaluationEligible(evaluation_time))
     {
      if(ResearchEvaluationEndReached(evaluation_time))
         ResearchMarkEvaluationEnd();
      return;
     }
   if(InpZeroEntryDiagnostic)
      ResearchDiagnosticExerciseIntent(intent,tick);
   else if(InpWorkloadDryRun)
      ResearchDryExerciseIntent(intent,tick);
   else if(intent.action==KINGEA_SLEEVE_ACTION_ENTRY)
      ResearchOpen(intent,tick);
   else if(intent.action==KINGEA_SLEEVE_ACTION_EXIT)
      ResearchClose(g_position.direction,tick);
  }

void ResearchDryExerciseIntent(const KingEASleeveDecision &intent,
                               const MqlTick &tick)
  {
   if(intent.action!=KINGEA_SLEEVE_ACTION_ENTRY)
      return;
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_ENTRY;
   request.scope=KINGEA_SCOPE_SLEEVE;
   request.direction=(intent.direction==KINGEA_DIRECTION_LONG ?
                      KINGEA_SAFETY_LONG : KINGEA_SAFETY_SHORT);
   request.entry_price=(intent.direction==KINGEA_DIRECTION_LONG ?
                        tick.ask : tick.bid);
   request.technical_stop=intent.technical_stop;
   request.signal_present=true;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(tick.time,request.entry_price,intent.technical_stop,
                        intent.direction,facts);
   KingEASafetyDecision safety={};
   KingEASafetyState state_copy=g_safety_state;
   KingEAEvaluateSafety(request,facts,state_copy,safety);

   KingEAAccountingEvent event=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_DEAL,"DRY-WORKLOAD",(long)tick.time_msc);
   event.signal_id="WITHHELD";
   event.direction=intent.direction;
   event.requested_price=request.entry_price;
   event.executed_price=request.entry_price;
   event.protective_stop=intent.technical_stop;
   event.reason_code="WORKLOAD_ONLY_NO_EXECUTION";
   KingEAAccountingCheckpoint checkpoint={};
   KingEAAccountingDecision accounting={};
   KingEAProcessAccountingEvent(event,checkpoint,accounting);
    if(accounting.accepted)
      {
       string discarded=KingEAAccountingFramePayload(event,accounting);
       if(discarded=="")
          g_hard_failures++;
      }
   }

void ResearchDiagnosticExerciseIntent(const KingEASleeveDecision &intent,
                                     const MqlTick &tick)
  {
   if(intent.action!=KINGEA_SLEEVE_ACTION_ENTRY)
      return;
   KingEASafetyRequest request={};
   request.event=KINGEA_EVENT_ENTRY;
   request.scope=KINGEA_SCOPE_SLEEVE;
   request.direction=(intent.direction==KINGEA_DIRECTION_LONG ?
                      KINGEA_SAFETY_LONG : KINGEA_SAFETY_SHORT);
   request.entry_price=(intent.direction==KINGEA_DIRECTION_LONG ? tick.ask : tick.bid);
   request.technical_stop=intent.technical_stop;
   request.signal_present=true;
   KingEASafetyFacts facts={};
   ResearchHealthyFacts(tick.time,request.entry_price,intent.technical_stop,
                        intent.direction,facts);
   KingEASafetyDecision safety={};
   KingEASafetyState state_copy=g_safety_state;
   KingEAEvaluateSafety(request,facts,state_copy,safety);
   bool approved=(safety.action==KINGEA_ACTION_APPROVE_ENTRY ||
                  safety.action==KINGEA_ACTION_DOWNSIZE_ENTRY);
   KingEAZeroEntryCountSafety(g_zero_entry_funnel,approved,(int)safety.reason);
   if(!approved)
      return;

   KingEAResearchStress stress={};
   stress.spread_multiplier=1.0;
   stress.cost_multiplier=1.0;
   stress.slippage_spread_fraction=0.0;
   stress.missed_entry_fraction=0.0;
   stress.seed=0;
   KingEAResearchVirtualPosition virtual_position={};
   virtual_position.equity=ResearchEquity();
   KingEAResearchEntryRoute route={};
   KingEAResearchRouteEntry(KINGEA_RESEARCH_ADAPTER_VIRTUAL,stress,
                            intent.signal_identity,tick.bid,tick.ask,
                            intent.direction,safety.required_stop,
                            safety.permitted_volume,(long)tick.time_msc,
                            (long)tick.time_msc+500,0.0,false,
                            virtual_position,route);
   bool filled=(route.healthy && route.outcome==KINGEA_RESEARCH_VIRTUAL_FILL);
   KingEAZeroEntryCountVirtualAttempt(g_zero_entry_funnel,filled);
   if(!filled)
      return;

   KingEAAccountingEvent event=ResearchAccountingBase(
      KINGEA_ACCOUNTING_EVENT_DEAL,"ZERO-ENTRY-DIAGNOSTIC",
      (long)tick.time_msc);
   event.signal_id=intent.signal_identity;
   event.direction=intent.direction;
   event.volume=safety.permitted_volume;
   event.requested_price=request.entry_price;
   event.executed_price=route.accounting_price;
   event.protective_stop=safety.required_stop;
   event.reason_code="DIAGNOSTIC_VIRTUAL_FILL_NO_ORDER";
   KingEAAccountingCheckpoint checkpoint={};
   KingEAAccountingDecision accounting={};
   KingEAProcessAccountingEvent(event,checkpoint,accounting);
   KingEAZeroEntryCountAccounting(g_zero_entry_funnel,accounting.accepted);
   }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("KingEA research adapter refused: Strategy Tester only.");
      return INIT_FAILED;
     }
   if(InpExpectedSymbol=="" || _Symbol!=InpExpectedSymbol ||
      (InpBranch=="RECORDED" && _Symbol!="ETHUSD.s") ||
      (InpBranch=="RSB3" && _Symbol!="KINGEA_ETHUSD_S_RSB3") ||
      (InpBranch!="RECORDED" && InpBranch!="RSB3"))
      return INIT_FAILED;
   if(!InpNativeConformance && !KingEAResearchDecodeConfiguration(InpConfigurationId,g_parameters))
      return INIT_PARAMETERS_INCORRECT;
   if(!InpZeroEntryDiagnostic && !InpWorkloadDryRun &&
      !ResearchEvaluationWindowValid())
      return INIT_PARAMETERS_INCORRECT;
   g_manifest_valid=(InpZeroEntryDiagnostic ?
                     ResearchZeroEntryDiagnosticAuthorizationValid() :
                     (InpWorkloadDryRun ? ResearchDryAuthorizationValid() :
                                          ResearchAuthorizationValid()));
   if(!g_manifest_valid)
     {
      Print("KingEA research adapter refused: manifest/authorization guard failed.");
      return INIT_FAILED;
     }
   g_market_intervals_loaded=ResearchLoadMarketIntervals();
   if(!g_market_intervals_loaded)
      return INIT_FAILED;
   if(ResearchUsesVirtual())
      g_virtual_position.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!ResearchUsesVirtual() && !InpZeroEntryDiagnostic){
      g_da.Reset();g_da_capture.Reset();g_da_observations.Reset();
      g_da_context=ResearchNativeContext();if(!g_da_context)return INIT_FAILED;
      if(PositionSelect(_Symbol))return INIT_FAILED;
      g_da_base=AccountInfoDouble(ACCOUNT_EQUITY);
   }
   g_initial_equity=ResearchEquity();
   if(g_initial_equity<=0.0)
      return INIT_FAILED;
   g_account_fingerprint=ResearchSha256String(
      AccountInfoString(ACCOUNT_SERVER)+"|"+
      (string)AccountInfoInteger(ACCOUNT_LOGIN));
   if(!ResearchHash(g_account_fingerprint))
      return INIT_FAILED;
   g_equity_high=g_initial_equity;
   ResearchUpdatePeriods(TimeCurrent());
   g_initialized=true;
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(!g_initialized)
      return;
   MqlTick tick={};
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0)
      return;
   if(InpNativeConformance){ResearchConformanceTick(tick);return;}
   if(!ResearchUsesVirtual() && !InpZeroEntryDiagnostic){
      ResearchNativePoll(tick);
      if(g_da.invalid){ResearchUpdateSpreadState(tick);ResearchUpdatePeriodsFast(tick.time);ResearchNativeSafetyObserve(tick);return;}
      ResearchFinalizeClosedTrade();
      if(g_da_fallback_due&&!g_da.pending){g_da_fallback_due=false;g_da_close_reason="BROKER_VOLUME_FALLBACK";ResearchClose(g_position.direction,tick);}
   }
   if(!InpZeroEntryDiagnostic && !InpWorkloadDryRun &&
      ResearchEvaluationEndReached(tick.time))
     {
      ResearchMarkEvaluationEnd();
      return;
     }
   if(InpWorkloadDryRun)
     {
      if(g_dry_tick_count==0)
         g_dry_first_tick_msc=(long)tick.time_msc;
      g_dry_last_tick_msc=(long)tick.time_msc;
      g_dry_tick_count++;
     }
   ResearchUpdateSpreadState(tick);
   if(ResearchHasPosition() && g_latest_spread_ratio>2.5 &&
      !g_spread_reduced)
      ResearchReduceHalf(tick);
   if(ResearchHasPosition() && g_above_three_count>=3 &&
      (long)tick.time_msc-g_above_three_start_msc>=10000)
     {g_da_close_reason="SEVERE_SPREAD_FLATTEN";ResearchClose(g_position.direction,tick);g_da_close_reason="STRATEGY_CLOSE";}
   ResearchProcessVirtualPending(tick);
   string market_kind="";
   bool market_blocked=ResearchMarketBlocked((long)tick.time_msc,market_kind);
   if(ResearchHasPosition() && market_blocked &&
      (market_kind=="MAINTENANCE_FORCE_FLAT" ||
       (market_kind=="NEWS_BLOCK" && !ResearchProtectedForNews())))
     {g_da_close_reason=market_kind=="MAINTENANCE_FORCE_FLAT"?"MAINTENANCE_CLOSE":"NEWS_CLOSE";
      ResearchClose(g_position.direction,tick);g_da_close_reason="STRATEGY_CLOSE";}
   if(ResearchUsesVirtual() && g_virtual_position.has_position)
     {
      bool stopped=(g_virtual_position.direction==KINGEA_DIRECTION_LONG ?
                    tick.bid<=g_virtual_position.protective_stop :
                    tick.ask>=g_virtual_position.protective_stop);
      if(stopped)
         ResearchClose(g_virtual_position.direction,tick);
     }
   ResearchFinalizeClosedTrade();
   ResearchNativeSeal(tick);
   ResearchUpdatePeriodsFast(tick.time);
   datetime bucket=(datetime)((long)tick.time/1800*1800);
   if(!g_has_current)
     {
      g_current_bar.open_time=bucket;
      g_current_bar.open=tick.bid;
      g_current_bar.high=tick.bid;
      g_current_bar.low=tick.bid;
      g_current_bar.close=tick.bid;
      g_current_bar.complete=false;
      g_has_current=true;
      ResearchTrackSpread(tick);
      return;
     }
   if(bucket==g_current_bar.open_time)
     {
      g_current_bar.high=MathMax(g_current_bar.high,tick.bid);
      g_current_bar.low=MathMin(g_current_bar.low,tick.bid);
      g_current_bar.close=tick.bid;
      ResearchTrackSpread(tick);
      return;
     }
   if(bucket<g_current_bar.open_time)
     {
      g_hard_failures++;
      return;
     }
   g_current_bar.complete=true;
   ResearchFinalizeSpreadSlot(g_current_bar.open_time);
   ResearchAppendBar(g_current_bar);
   ResearchEvaluateClosedBar(tick.time,tick);
   ResearchNativeSeal(tick);
   g_current_bar.open_time=bucket;
   g_current_bar.open=tick.bid;
   g_current_bar.high=tick.bid;
   g_current_bar.low=tick.bid;
   g_current_bar.close=tick.bid;
   g_current_bar.complete=false;
   ResearchTrackSpread(tick);
  }

double OnTester()
  {
   if(InpNativeConformance){
      MqlTick tick={};if(SymbolInfoTick(_Symbol,tick))ResearchNativePoll(tick);
      if(g_da.invalid||g_hard_failures||g_da.pending)return -1.0;
      if(!g_da.projected && DAManifestString("outcome")=="NORMAL_CLOSE" && !ResearchNativeNormalCloseReady())return -1.0;
      if(!g_da.projected && !ResearchNativeBoundaryFinalize())return -1.0;
      return g_da.projected && ResearchNativeCompletion()?0.0:-1.0;
   }
   if(InpZeroEntryDiagnostic)
     {
      string payload=KingEAZeroEntryPayload(g_zero_entry_funnel,InpBranch,
                                             InpConfigurationId);
      bool complete=(g_initialized && g_manifest_valid &&
                     g_zero_entry_funnel.native_order_calls==0 &&
                     PersistZeroEntryDiagnosticPayload(payload));
      PrintFormat("KINGEA_ZERO_ENTRY_DIAGNOSTIC: %s persisted=%d",payload,
                  complete ? 1 : 0);
      return complete ? 0.0 : -1.0;
     }
   if(InpWorkloadDryRun)
     {
      string payload=StringFormat(
         "schema=1|kind=FULL_WORKLOAD_DRY_BENCHMARK|root=%s|branch=%s|pass=%d|ticks=%I64d|first_tick_msc=%I64d|last_tick_msc=%I64d|results=WITHHELD|signals_exposed=0|trades=0|returns=ABSENT|candidate_budget=0|complete=1|healthy=%d",
         InpDryBenchmarkRootSha256,InpBranch,InpDryBenchmarkPassId,
         g_dry_tick_count,g_dry_first_tick_msc,g_dry_last_tick_msc,
         (g_initialized && g_manifest_valid && g_hard_failures==0) ? 1 : 0);
      uchar dry_frame[];
      int dry_bytes=StringToCharArray(payload,dry_frame,0,WHOLE_ARRAY,CP_UTF8);
      if(dry_bytes>0)
         ArrayResize(dry_frame,dry_bytes-1);
      bool persisted=PersistDryBenchmarkPayload(payload);
      PrintFormat("KINGEA_STAGE14_WORKLOAD_RESULT: %s persisted=%d",
                  payload,persisted ? 1 : 0);
      if(!g_initialized || !g_manifest_valid || g_hard_failures!=0 ||
         g_dry_tick_count<=0 || dry_bytes<=0 || !persisted ||
         !FrameAdd("KINGEA_STAGE14_WORKLOAD_DRY",InpDryBenchmarkPassId,
                   0.0,dry_frame))
         return -1.0;
      return 0.0;
     }
   // Do this before finalization or completion-frame emission: a terminal
   // ending on the last eligible tick must not silently complete an open or
   // pending trade group merely because no later tick called the end gate.
   g_native_in_tester_end=true;
   MqlTick terminal_tick={};if(SymbolInfoTick(_Symbol,terminal_tick))ResearchNativePoll(terminal_tick);
   if(!ResearchUsesVirtual() && g_da.invalid)return -1.0;
   ResearchFinalizeClosedTrade();
   ResearchNativeBoundaryFinalize();
   if(ResearchTerminalEndHasUnresolvedExposure())
     {
      g_evaluation_end_unresolved=true;
      g_hard_failures++;
      return -1.0;
     }
   ResearchFinalizeClosedTrade();
   if(g_evaluation_end_unresolved)
      return -1.0;
   if(g_day_start>0 && g_day_open>0.0)
     {
      int day_count=ArraySize(g_daily_returns);
      ArrayResize(g_daily_returns,day_count+1);
      g_daily_returns[day_count]=(ResearchEquity()-g_day_open)/g_day_open;
     }
   double legacy_net=0.0;
   for(int i=0;i<ArraySize(g_trade_net);i++)
      legacy_net+=g_trade_net[i];
   if(g_accounting_close_count!=ArraySize(g_trade_returns) ||
      MathAbs(legacy_net-g_accounting_checkpoint.strategy_net_pnl)>0.000001)
      g_hard_failures++;
   for(int i=0;i<ArraySize(g_accounting_payloads);i++)
     {
      uchar accounting_frame[];
      int bytes=StringToCharArray(g_accounting_payloads[i],accounting_frame,
                                  0,WHOLE_ARRAY,CP_UTF8);
      if(bytes>0) ArrayResize(accounting_frame,bytes-1);
      if(bytes<=0 || !FrameAdd("KINGEA_STAGE13_ACCOUNTING_EVENT",i+1,0.0,
                               accounting_frame))
         g_hard_failures++;
     }
   if(g_hard_failures!=0 || (!ResearchUsesVirtual()&&g_da.invalid))return -1.0;
   string accounting_complete=StringFormat(
      "schema=1|event_count=%d|close_count=%d|trade_return_count=%d|legacy_net=%.12f|ledger_net=%.12f|root=%s|complete=1",
      ArraySize(g_accounting_payloads),g_accounting_close_count,
      ArraySize(g_trade_returns),legacy_net,
      g_accounting_checkpoint.strategy_net_pnl,
      g_accounting_checkpoint.ledger_root_sha256);
   uchar accounting_summary[];
   int accounting_bytes=StringToCharArray(accounting_complete,
                                           accounting_summary,0,WHOLE_ARRAY,CP_UTF8);
   if(accounting_bytes>0) ArrayResize(accounting_summary,accounting_bytes-1);
   if(accounting_bytes<=0 ||
      !FrameAdd("KINGEA_STAGE13_ACCOUNTING_COMPLETE",InpConfigurationId,
                0.0,accounting_summary))
      g_hard_failures++;
   if(g_hard_failures!=0 || (!ResearchUsesVirtual()&&g_da.invalid))return -1.0;
   if(!ResearchUsesVirtual() && !ResearchNativeCompletion())return -1.0;
   string payload=StringFormat("config=%d|branch=%s|partition=%s|entries=%d|exits=%d|missed=%d|delay_expiry=%d|gate_reject_after_delay=%d|virtual_execution_failure=%d|hard_failures=%d|complete=1",
                               InpConfigurationId,InpBranch,InpPartition,
                               g_entries,g_exits,g_missed,g_delay_expired,
                               g_gate_rejected_after_delay,
                               g_virtual_execution_failed,g_hard_failures);
   payload+="|native_cost_contract="+(ResearchUsesVirtual()?"NATIVE_COST_BOUNDARY_V2":"NATIVE_GROUP_LIFECYCLE_CONTRACT_V3")+"|boundary_finalization_count="+(string)g_boundary_finalization_count;
   payload+="|trade_returns=";
   for(int i=0;i<ArraySize(g_trade_returns);i++)
      payload+=(i>0 ? ";" : "")+DoubleToString(g_trade_returns[i],12);
   payload+="|trade_r=";
   for(int i=0;i<ArraySize(g_trade_r);i++)
      payload+=(i>0 ? ";" : "")+DoubleToString(g_trade_r[i],12);
   payload+="|daily_returns=";
   for(int i=0;i<ArraySize(g_daily_returns);i++)
      payload+=(i>0 ? ";" : "")+DoubleToString(g_daily_returns[i],12);
   uchar frame[];
   int count=StringToCharArray(payload,frame,0,WHOLE_ARRAY,CP_UTF8);
   if(count>0)
      ArrayResize(frame,count-1);
   if(!FrameAdd("KINGEA_STAGE12_COMPLETE",InpConfigurationId,0.0,frame))
      g_hard_failures++;
   return g_hard_failures==0 ? 0.0 : -1.0;
  }

void ResearchDrainFrames()
  {
   ulong pass=0;
   string name="";
   long identifier=0;
   double value=0.0;
   uchar data[];
   while(FrameNext(pass,name,identifier,value,data))
     {
      string safe=name;
      StringReplace(safe,"\\","_");
      StringReplace(safe,"/","_");
      StringReplace(safe,":","_");
      StringReplace(safe,"|","_");
      string filename=StringFormat("KingEA\\stage14_spool\\%s\\%I64u_%s_%I64d.frame",
                                   InpManifestSha256,pass,safe,identifier);
      bool conflict=false;
      if(FileIsExist(filename,FILE_COMMON))
        {
         int existing=FileOpen(filename,FILE_READ|FILE_BIN|FILE_COMMON);
         if(existing==INVALID_HANDLE || FileSize(existing)!=(ulong)ArraySize(data))
            conflict=true;
         else
           {
            uchar prior[];
            ArrayResize(prior,ArraySize(data));
            if(FileReadArray(existing,prior,0,ArraySize(prior))!=(uint)ArraySize(prior))
               conflict=true;
            else
               for(int i=0;i<ArraySize(prior);i++)
                  if(prior[i]!=data[i]) { conflict=true; break; }
           }
         if(existing!=INVALID_HANDLE) FileClose(existing);
        }
      else
        {
         int output=FileOpen(filename,FILE_WRITE|FILE_BIN|FILE_COMMON);
         if(output==INVALID_HANDLE ||
            FileWriteArray(output,data,0,ArraySize(data))!=(uint)ArraySize(data))
            conflict=true;
         if(output!=INVALID_HANDLE) { FileFlush(output); FileClose(output); }
        }
      if(conflict)
         g_hard_failures++;
      PrintFormat("KINGEA_STAGE14_FRAME: pass=%I64u name=%s id=%I64d bytes=%d sha256=%s persisted=%s",
                  pass,name,identifier,ArraySize(data),ResearchSha256Bytes(data),
                  conflict ? "FAIL" : "PASS");
     }
  }

void OnTesterPass()
  {
   ResearchDrainFrames();
  }

void OnTesterDeinit()
  {
   // Drain frames that MT5 delivers after the last OnTesterPass callback.
   ResearchDrainFrames();
  }

#include <KingEA/GuardedNativeCostIntegration.mqh>
