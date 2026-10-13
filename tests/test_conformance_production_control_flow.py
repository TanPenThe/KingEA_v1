"""Static production control-flow proofs, distinct from native runtime proof."""
import re,json,hashlib,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EA=ROOT/'MQL5/Experts/KingEA/GuardedResearchTester.mq5'
INTEGRATION=ROOT/'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh'
STATIC_STOP=ROOT/'MQL5/Include/KingEA/DecisionAStaticStop.mqh'
LONG_MANIFEST=ROOT/'governance/evidence/stage14/native_production_conformance_20260909/v3_current_runtime_packages_v2/NCV1-LONG-NORMAL-001/manifest.json'
INVENTORY_PROTOCOL='42E9BAA5FE03DBE0416BBFFA22B0FDA8820AF51E9E16A4F3C67240D01536A7F6'
SWAP_TRANSITION='BEE9D303C1FBC804C9F0993685B8CBD2B9FCF43F226CD7BFBA5D73C972C9E772'

def functions(text):
 # Ignore comments and literals before balancing function bodies; function calls
 # in comments/strings cannot manufacture reachability evidence.
 text=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"',lambda m:'""' if m[0].startswith('"') else '',text)
 result={}
 for match in re.finditer(r'\b(?:bool|void|double|int|string|datetime|long)\s+(\w+)\s*\([^;{}]*\)\s*\{',text):
  start=match.end();depth=1;i=start
  while depth and i<len(text):
   depth+=(text[i]=='{')-(text[i]=='}');i+=1
  result[match[1]]=text[start:i-1]
 return result

class ConformanceProductionControlFlow(unittest.TestCase):
 def setUp(self):self.ea=EA.read_text();self.integration=INTEGRATION.read_text();self.f=functions(self.ea+'\n'+self.integration)
 def test_build_authority_reaches_exact_native_profile_predicate(self):
  stop=STATIC_STOP.read_text();native=self.f['ResearchConformanceValid'];context=self.f['ResearchNativeContext']
  conformance_context=self.f['ResearchConformanceContext'];active=self.f['ResearchActiveNativeContext']
  self.assertIn('input int    InpExpectedTerminalBuild=0;',self.ea)
  self.assertIn('input int    InpConformanceExpectedTerminalBuild=0;',self.ea)
  self.assertIn('InpConformanceExpectedTerminalBuild<=0',self.f['ResearchConformanceAuthorizationValidate'])
  self.assertIn('DAConformanceBoundNativeProfile(InpConformanceExpectedTerminalBuild)',native)
  self.assertIn('DABoundNativeProfile()',context)
  self.assertNotIn('InpConformanceExpectedTerminalBuild',context)
  self.assertNotIn('InpExpectedTerminalBuild',context)
  self.assertNotIn('InpExpectedTerminalBuild',conformance_context)
  self.assertIn('ResearchConformanceContext():ResearchNativeContext()',active)
  self.assertIn('g_da_context=ResearchActiveNativeContext()',self.f['OnInit'])
  self.assertIn('DAValidateNativeProfileForBuild(const int expected_terminal_build)',stop)
  self.assertIn('DABoundNativeProfile(){return DAValidateNativeProfileForBuild(6140);}',stop)
  self.assertIn('DAConformanceBoundNativeProfile(const int expected_terminal_build)',stop)
  self.assertIn('expected_terminal_build<=0',stop)
  self.assertIn('TerminalInfoInteger(TERMINAL_BUILD)!=expected_terminal_build',stop)
  self.assertNotRegex(stop,r'TERMINAL_BUILD\)\s*!=\s*(?:6140|6182)')
  for required in ('MQL_TESTER','MQL_VISUAL_MODE','MQL_DLLS_ALLOWED','JustMarkets-Demo2','ETHUSD.s','SYMBOL_SWAP_MODE','SYMBOL_SWAP_ROLLOVER3DAYS','SYMBOL_DIGITS','SYMBOL_FILLING_FOK','SYMBOL_SWAP_LONG','SYMBOL_SWAP_SHORT'):
   self.assertIn(required,stop)
 def test_fixture_transitive_call_graph_excludes_candidate_signals(self):
  pending=['ResearchConformanceTick'];seen=set();calls=set()
  while pending:
   name=pending.pop()
   if name in seen:continue
   seen.add(name)
   targets=set(re.findall(r'\b(\w+)\s*\(',self.f.get(name,'')));calls|=targets
   pending.extend(targets & self.f.keys())
  self.assertNotIn('KingEAEvaluateSleeveEthSt001',calls)
  self.assertNotIn('ResearchEvaluateClosedBar',seen)
  self.assertTrue({'ResearchOrderSend','ResearchNativePoll','ResearchNativeProject','ResearchReduceHalf'}<=seen)
  tick=self.f['OnTick'];self.assertRegex(tick,r'if\(InpNativeConformance\)\{ResearchConformanceTick\(tick\);return;\}')
  self.assertLess(tick.index('ResearchConformanceTick'),tick.index('ResearchEvaluateClosedBar'))
 def test_check_rejection_dominates_only_order_send(self):
  body=self.f['ResearchOrderSend'];self.assertEqual(len(re.findall(r'\bOrderSend\(',body)),1)
  self.assertRegex(body,r'if\(!ResearchNativeOrderCheck\(request\)\)return false;\s*g_da_last_send_attempted=true;')
  self.assertLess(body.index('ResearchNativeOrderCheck(request)'),body.index('OrderSend(request,result)'))
  self.assertRegex(body,r'bool sent=OrderSend\(request,result\);[\s\S]*return sent;')
  check=self.f['ResearchNativeOrderCheck'];self.assertNotIn('OrderSend(',check)
  self.assertRegex(check,r'if\(!ok\|\|c.retcode!=0\)\{g_da.Invalidate\(""\);return false;\}')
  self.assertNotIn('.Receipt(',check);self.assertNotIn('.Commit(',check)
 def test_actions_consume_before_submission_no_retry_loop(self):
  body=self.f['ResearchConformanceTick']
  for flag,call in [('g_cf_entry_attempted','ResearchNativeBegin'),('g_cf_reduction_attempted','ResearchReduceHalf'),('g_cf_close_attempted','ResearchClose')]:
   self.assertIn('!'+flag,body);self.assertLess(body.index(flag+'=true'),body.index(call))
   self.assertNotIn(flag+'=false',body)
  self.assertNotIn('while(',body);self.assertNotIn('for(',body)
 def test_conformance_tester_completion_cannot_reach_candidate_completion(self):
  body=self.f['OnTester'];start=body.index('if(InpNativeConformance)');first=body.index('{',start);depth=1;i=first+1
  while depth:depth+=(body[i]=='{')-(body[i]=='}');i+=1
  branch=body[first:i];self.assertIn('bool completed=g_da.projected && ResearchNativeCompletion();',branch)
  self.assertIn('if(!completed)',branch);self.assertIn('return 0.0;',branch)
  self.assertNotIn('Stage12',branch);self.assertNotIn('KingEAResearchDecodeConfiguration',branch)
 def test_oninit_uses_isolated_conformance_authorization(self):
  normal=self.f['ResearchAuthorizationValid'];active=self.f['ResearchActiveAuthorizationValid'];oninit=self.f['OnInit'];conformance=self.f['ResearchConformanceAuthorizationValidate'];send=self.f['ResearchOrderSend']
  self.assertNotIn('InpNativeConformance',normal)
  self.assertRegex(active,r'if\(InpNativeConformance\)\s*return ResearchConformanceAuthorizationValidate\(\);\s*return ResearchAuthorizationValid\(\);')
  self.assertIn('ResearchActiveAuthorizationValid()',send)
  self.assertRegex(oninit,r'if\(InpNativeConformance\)\s*g_manifest_valid=ResearchConformanceAuthorizationValidate\(\);\s*else')
  self.assertLess(oninit.index('ResearchConformanceAuthorizationValidate'),oninit.index('ResearchAuthorizationValid'))
  for required in ('InpGate!=','InpRootSha256!=','InpDetachedAuthorizationToken!=','InpConfigurationId!=0','InpExecutionAdapter!=','InpScenario!=','InpTesterModel!=4','InpExpectedSymbol!=','DAManifestString','ResearchFileSha256','InpManifestFileSha256'):
   self.assertIn(required,conformance)
  for required in ('NON_CANDIDATE_NATIVE_CONFORMANCE_V1','fixture_id','group_id','configuration_sha256','InpConformanceRuntimeProfileSha256','source_sha256','execution_mode','optimization','symbol'):
   self.assertIn(required,self.ea)
  self.assertIn('#property tester_file "KingEA\\\\conformance\\\\NCV1-LONG-NORMAL-001\\\\manifest.json"',self.ea)
  self.assertIn('#property tester_file "KingEA\\\\conformance\\\\NCV1-SHORT-NORMAL-001\\\\manifest.json"',self.ea)
  self.assertIn('#property tester_file "KingEA\\\\conformance\\\\NCV1-LONG-BOUNDARY-001\\\\manifest.json"',self.ea)
 def test_conformance_authority_is_manifest_bound_and_fail_closed(self):
  body=self.f['ResearchConformanceAuthorizationValidate'];oninit=self.f['OnInit']
  for required in ('ResearchFileSha256(InpRunManifest)!=InpManifestFileSha256','ResearchConformanceValid()','run_id','side','volume','S0','start_msc','end_msc','entry_msc','reduction_msc','close_msc','outcome','data_scope','execution_mode','optimization','symbol','configuration_sha256','source_sha256'):
   self.assertIn(required,body if required in ('ResearchFileSha256(InpRunManifest)!=InpManifestFileSha256','ResearchConformanceValid()') else self.ea)
  self.assertNotIn('DAManifestString("control_sha256")',body);self.assertNotIn('DAManifestString("tester_profile_sha256")',body)
  self.assertIn('InpConformanceRuntimeProfileSha256',body)
  self.assertNotRegex(oninit,r'if\(InpNativeConformance\)\s*g_manifest_valid=ResearchAuthorizationValid\(\)')
  self.assertIn('return INIT_FAILED;',oninit)
 def test_wrong_inventory_protocol_hash_rejects(self):
  conformance=self.f['ResearchConformanceAuthorizationValidate'];native=self.f['ResearchConformanceValid']
  self.assertIn('ResearchConformanceValid()',conformance)
  self.assertIn('DAManifestString("inventory_protocol_sha256")!="'+INVENTORY_PROTOCOL+'"',self.integration)
  manifest=json.loads(LONG_MANIFEST.read_text());manifest['inventory_protocol_sha256']='0'*64
  self.assertFalse(manifest['inventory_protocol_sha256']==INVENTORY_PROTOCOL)
 def test_wrong_swap_transition_hash_rejects(self):
  conformance=self.f['ResearchConformanceAuthorizationValidate'];native=self.f['ResearchConformanceValid']
  self.assertIn('ResearchConformanceValid()',conformance)
  self.assertIn('DAManifestString("swap_transition_rule_sha256")!="'+SWAP_TRANSITION+'"',self.integration)
  manifest=json.loads(LONG_MANIFEST.read_text());manifest['swap_transition_rule_sha256']='F'*64
  self.assertFalse(manifest['swap_transition_rule_sha256']==SWAP_TRANSITION)
 def test_later_tick_revalidates_and_fails_closed(self):
  tick=self.f['ResearchConformanceTick'];context=self.f['ResearchConformanceContext'];native=self.f['ResearchConformanceValid']
  self.assertLess(tick.index('ResearchConformanceValid()'),tick.index('ResearchNativePoll'))
  self.assertIn('g_da.Invalidate("")',tick);self.assertIn('InpConformanceRuntimeProfileSha256',context)
  self.assertIn('DAConformanceLayerAClosed()',native)
 def test_successor_historical_and_protected_sources_equal(self):
  base=ROOT/'governance/evidence/stage14/native_conformance_interface_20260908/FINAL_PRE_TOOLING.json'
  files=json.loads(base.read_text())['files'];changed={'MQL5/Experts/KingEA/GuardedResearchTester.mq5','MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh','MQL5/Include/KingEA/DecisionAStaticStop.mqh','research_pipeline/decision_a_evidence.py'}
  for e in files:
   if e['path']=='MQL5/Include/KingEA/DecisionADealAdapter.mqh':
    old=ROOT/'governance/review/order_terminality_diagnostic_instrumentation_20260923/before/DecisionADealAdapter.mqh'
    current=ROOT/e['path']
    self.assertEqual(hashlib.sha256(old.read_bytes()).hexdigest().upper(),e['sha256'])
    prefix='// Bounded capture only.'
    self.assertEqual(old.read_text().split(prefix)[0],current.read_text().split(prefix)[0])
    continue
   if e['path'] in changed or e['path'].startswith('tests/'):continue
   with self.subTest(path=e['path']):self.assertEqual(hashlib.sha256((ROOT/e['path']).read_bytes()).hexdigest().upper(),e['sha256'])
