"""Static proof for output-only conformance observability instrumentation."""
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/'MQL5/Experts/KingEA/GuardedResearchTester.mq5'
INTEGRATION=ROOT/'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh'
BEFORE=ROOT/'governance/review/repaired_conformance_observability_instrumentation_20260918/before'

REQUIRED={
 'OBS_ONINIT_SUCCESS','OBS_FIRST_ONTICK','OBS_SYMBOL_INFO_TICK_FAIL',
 'OBS_CONFORMANCE_REVALIDATION_FAIL','OBS_CONFORMANCE_REVALIDATION_PASS',
 'OBS_PRE_ENTRY_TICK','OBS_ENTRY_TIME_REACHED','OBS_ENTRY_LATCHED',
 'OBS_ENTRY_WINDOW_REJECT','OBS_ENTRY_WINDOW_PASS','OBS_STOP_GEOMETRY_FAIL',
 'OBS_ORDER_CALC_PROFIT_FAIL','OBS_RISK_NONPOSITIVE','OBS_RISK_VALID',
 'OBS_NATIVE_BEGIN_ENTER','OBS_NATIVE_BEGIN_PASS','OBS_NATIVE_BEGIN_FAIL',
 'OBS_SEND_SEAM_ENTER','OBS_SEND_NOT_INITIALIZED','OBS_SEND_AUTHORIZATION_FAIL',
 'OBS_SEND_STATIC_AUTHORITY_FAIL','OBS_SEND_EVALUATION_FAIL','OBS_SEND_GATES_PASS',
 'OBS_ORDERCHECK_ENTER','OBS_ORDERCHECK_RESULT','OBS_ORDERSEND_ENTER',
 'OBS_ORDERSEND_RESULT','OBS_ONTESTER_INVALID_OR_HARDFAIL_OR_PENDING',
 'OBS_ONTESTER_NORMAL_CLOSE_NOT_READY','OBS_ONTESTER_BOUNDARY_FINALIZE_FAIL',
 'OBS_ONTESTER_COMPLETION_FAIL','OBS_ONTESTER_COMPLETION_PASS'
}

def functions(text):
 text=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"',lambda m:'""' if m[0].startswith('"') else '',text)
 result={}
 for match in re.finditer(r'\b(?:bool|void|double|int|string|datetime|long)\s+(\w+)\s*\([^;{}]*\)\s*\{',text):
  start=match.end();depth=1;i=start
  while depth and i<len(text):depth+=(text[i]=='{')-(text[i]=='}');i+=1
  result[match[1]]=text[start:i-1]
 return result

def raw_between(text,start,end):
 return text[text.index(start):text.index(end,text.index(start))]

class ConformanceObservability(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.ea=EA.read_text();cls.integration=INTEGRATION.read_text();cls.all=cls.ea+'\n'+cls.integration
  cls.f=functions(cls.all)
  cls.old_ea=(BEFORE/'GuardedResearchTester.mq5').read_text()
  cls.old_integration=(BEFORE/'GuardedNativeCostIntegration.mqh').read_text()
  cls.old_f=functions(cls.old_ea+'\n'+cls.old_integration)

 def test_required_marker_inventory_is_closed_and_unique(self):
  emitted=set(re.findall(r'ResearchConformanceObserve\((?:begun\?"(OBS_[A-Z0-9_]+)":"(OBS_[A-Z0-9_]+)"|"(OBS_[A-Z0-9_]+)")',self.all))
  emitted={v for group in emitted for v in group if v}
  self.assertEqual(REQUIRED,emitted)
  for marker in REQUIRED:self.assertEqual(1,self.all.count('"'+marker+'"'),marker)

 def test_schema_has_authority_bindings_and_separate_output_path(self):
  body=raw_between(self.ea,'void ResearchConformanceObserve','// Captured once per tester initialization')
  for value in ('CONFORMANCE_OBSERVABILITY_V1','NON_CANDIDATE_NATIVE_CONFORMANCE_V1','fixture_id','InpManifestSha256','source_sha256','InpManifestFileSha256','InpConformanceControlSha256','InpConformanceRuntimeProfileSha256','milestone','sequence','prior_record_sha256'):
   self.assertIn(value,body)
  self.assertIn('KingEA\\\\conformance_observability',body)
  for forbidden in ('stage14_spool','NATIVE_COST_','FrameAdd','KingEAProcessAccountingEvent'):
   self.assertNotIn(forbidden,body)

 def test_sequence_is_monotonic_and_persistence_is_output_only(self):
  body=self.f['ResearchConformanceObserve']
  self.assertLess(body.index('g_conformance_observation_sequence++'),body.index('StringFormat'))
  self.assertIn('OBS_%06d_%s.json',self.ea)
  self.assertIn('void ResearchConformanceObserve',self.ea)
  self.assertNotIn('return false',body);self.assertNotIn('return true',body)
  self.assertEqual(2,self.all.count('g_conformance_observation_persist_failed'))
  self.assertNotRegex(self.all,r'if\s*\(\s*g_conformance_observation_persist_failed')

 def test_candidate_path_cannot_emit(self):
  body=self.f['ResearchConformanceObserve']
  self.assertRegex(body,r'if\(!InpNativeConformance\)\s*return;')
  self.assertLess(body.index('if(!InpNativeConformance)'),body.index('g_conformance_observation_sequence++'))

 def test_transition_only_no_unrestricted_tick_logging(self):
  tick=self.f['ResearchConformanceTick'];on_tick=self.f['OnTick']
  self.assertNotIn('for(',tick);self.assertNotIn('while(',tick)
  self.assertIn('!g_obs_revalidation_pass',tick);self.assertIn('!g_obs_revalidation_fail',tick)
  self.assertIn('!g_obs_pre_entry_tick',tick);self.assertIn('!g_obs_entry_time_reached',tick)
  self.assertIn('!g_obs_first_ontick',on_tick)

 def test_validator_predicate_order_preserved(self):
  current=raw_between(self.integration,'bool ResearchConformanceValid()','void ResearchConformanceTick')
  ordered=('InpNativeConformance','MQL_TESTER','MQL_OPTIMIZATION','DAConformanceBoundNativeProfile','InpPurpose','InpGate','InpRootSha256','InpDetachedAuthorizationToken','InpConfigurationId','InpZeroEntryDiagnostic','InpWorkloadDryRun','InpBranch','InpScenario','InpSpreadMultiplier','InpCostMultiplier','InpSlippageSpreadFraction','InpVolatilityDependentSlippage','InpMissedEntryFraction','InpExecutionAdapter','InpDelayMs','InpTesterModel','InpLocalAgentsOnly','InpRemoteAgentsDisabled','InpCloudAgentsDisabled','ResearchEvaluationWindowValid','InpConformanceControlSha256','InpConformanceRuntimeProfileSha256','ResearchFileSha256(InpRunManifest)','InpManifestFileSha256','ResearchFileSha256(InpCalendarIntervalsFile)','InpCalendarFileSha256','DAConformanceLayerAClosed','DAManifestString("domain")','DAManifestString("run_id")','DAManifestString("data_scope")','swap_transition_rule_sha256','inventory_protocol_sha256')
  positions=[current.index(token) for token in ordered]
  self.assertEqual(positions,sorted(positions))
  old=raw_between(self.old_integration,'bool ResearchConformanceValid()','void ResearchConformanceTick')
  for token in ordered:self.assertIn(token,old)

 def test_entry_and_native_begin_order_unchanged(self):
  body=self.f['ResearchConformanceTick']
  sequence=('tick.time_msc>=entry','g_cf_entry_attempted=true','tick.time_msc>=reduce','stop>=price','OrderCalcProfit','risk>=0','ResearchNativeBegin','ResearchOrderSend')
  positions=[body.index(token) for token in sequence]
  self.assertEqual(positions,sorted(positions))
  old=self.old_f['ResearchConformanceTick']
  old_sequence=('tick.time_msc>=entry','g_cf_entry_attempted=true','tick.time_msc>=reduce','stop>=price','OrderCalcProfit','risk>=0','ResearchNativeBegin','ResearchOrderSend')
  self.assertEqual([old.index(x) for x in old_sequence],sorted(old.index(x) for x in old_sequence))

 def test_send_gate_and_native_call_order_unchanged(self):
  body=self.f['ResearchOrderSend']
  order=('!g_initialized','ResearchActiveAuthorizationValid()','DAStaticSendAllowed','ResearchEvaluationEligible(TimeCurrent())','ResearchNativeOrderCheck(request)','OrderSend(request,result)')
  self.assertEqual([body.index(x) for x in order],sorted(body.index(x) for x in order))
  checked=body.index('if(!ResearchNativeOrderCheck(request))return false;')+len('if(!ResearchNativeOrderCheck(request))return false;')
  between=body[checked:body.index('OrderSend(request,result)')]
  self.assertNotIn('if(',between);self.assertNotIn('return false',between)

 def test_ordercheck_markers_bracket_native_call(self):
  body=self.integration[self.integration.index('bool ResearchNativeOrderCheck'):]
  self.assertLess(body.index('OBS_ORDERCHECK_ENTER'),body.index('OrderCheck(r,c)'))
  self.assertLess(body.index('OrderCheck(r,c)'),body.index('OBS_ORDERCHECK_RESULT'))
  self.assertLess(body.index('OBS_ORDERCHECK_RESULT'),body.index('ResearchNativeRecord'))

 def test_ordercheck_lasterror_capture_excludes_observer_io(self):
  body=self.integration[self.integration.index('bool ResearchNativeOrderCheck'):]
  ordered=('OBS_ORDERCHECK_ENTER','ResetLastError()','OrderCheck(r,c)','GetLastError()','OBS_ORDERCHECK_RESULT')
  positions=[body.index(token) for token in ordered]
  self.assertEqual(positions,sorted(positions))
  native_error_region=body[body.index('ResetLastError()'):body.index('GetLastError()')+len('GetLastError()')]
  self.assertEqual(1,native_error_region.count('OrderCheck(r,c)'))
  self.assertNotIn('ResearchConformanceObserve',native_error_region)

 def test_observer_does_not_interpose_any_lasterror_pair(self):
  self.assertEqual(2,self.all.count('ResetLastError()'))
  self.assertEqual(2,self.all.count('GetLastError()'))
  for match in re.finditer(r'ResetLastError\(\)(.*?)GetLastError\(\)',self.all,re.S):
   self.assertNotIn('ResearchConformanceObserve',match.group(1))

 def test_on_tester_markers_precede_unchanged_returns(self):
  body=raw_between(self.ea,'double OnTester()','void OnTesterPass()')
  for marker in ('OBS_ONTESTER_INVALID_OR_HARDFAIL_OR_PENDING','OBS_ONTESTER_NORMAL_CLOSE_NOT_READY','OBS_ONTESTER_BOUNDARY_FINALIZE_FAIL','OBS_ONTESTER_COMPLETION_FAIL'):
   pos=body.index(marker);self.assertIn('return -1.0;',body[pos:pos+260])
  pos=body.index('OBS_ONTESTER_COMPLETION_PASS');self.assertIn('return 0.0;',body[pos:pos+220])
  for predicate in ('g_da.invalid||g_hard_failures||g_da.pending','!g_da.projected && DAManifestString','!g_da.projected && !ResearchNativeBoundaryFinalize()','g_da.projected && ResearchNativeCompletion()'):
   self.assertIn(predicate,body);self.assertIn(predicate,self.old_f['OnTester'])

 def test_observation_state_never_enters_trading_predicates(self):
  without_observer=self.all
  for state in ('g_conformance_observation_sequence','g_conformance_observation_prior_hash','g_conformance_observation_persist_failed'):
   self.assertNotRegex(without_observer,r'if\s*\([^)]*'+state)
  self.assertEqual(2,without_observer.count('g_conformance_observation_persist_failed'))

if __name__=='__main__':unittest.main()
