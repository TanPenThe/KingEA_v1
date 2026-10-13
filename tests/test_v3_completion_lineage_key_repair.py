"""Source-only regression proofs for lineage-scoped immutable V3 completion."""
import hashlib,json,os,re,tempfile,unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REVIEW=ROOT/'governance/review/v3_completion_lineage_key_source_repair_20260927'
SOURCE=ROOT/'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh'
BEFORE=REVIEW/'before/GuardedNativeCostIntegration.mqh'
EA=ROOT/'MQL5/Experts/KingEA/GuardedResearchTester.mq5'
RUNTIME=ROOT/'governance/review/v3_capture_lineage_key_long_runtime_20260926/RUNTIME_REVIEW_BUNDLE.zip'
RUN='C666040B2B67CB6C5B62BC73193104F84F99731AD695DF250B9E3B17D5D60F2F'
LAYER_B='8F612F94A58C62B7019041C866D59D3C9329037BCE62824009EDB708507083BA'
OLD_KEY='E12EBEF163B0E8BFEF621E5FDFE66FB917F39AE25B4DE02143885F15878C81B3'
OLD_SHA='80E7BE12C1D05252BF38DE08F1CB25D4C8FFDCAE445AA0F53FEEFE3061CA66C2'
NEW_LINE=' string completion_name=InpNativeConformance?"V3_COMPLETION_"+InpConformanceControlSha256:"V3_COMPLETION";\n if(!ResearchNativePersist(completion_name,value))return false;'
OLD_LINE=' if(!ResearchNativePersist("V3_COMPLETION",value))return false;'

def digest(raw):return hashlib.sha256(raw).hexdigest().upper()
def name(control):return 'V3_COMPLETION_'+control
def key(control):return digest(name(control).encode())
def section(text,start,end):
 begin=text.index(start)
 return text[begin:text.index(end,begin)]
def persist(directory,semantic,value):
 path=directory/f'NATIVE_COST_0_{digest(semantic.encode())}.evidence'
 if path.exists():return path.read_bytes()==value,path
 path.write_bytes(value);return True,path

def verify_historical_snapshot(directory, expected, count):
 # The gate names immutable historical objects. Later runtime additions are separate evidence.
 if len(expected)!=count:raise AssertionError('HISTORICAL_SNAPSHOT_CARDINALITY')
 names=[item['filename'] for item in expected]
 if len(set(names))!=count:raise AssertionError('HISTORICAL_SNAPSHOT_DUPLICATE')
 for item in expected:
  if set(item)!={'filename','byte_length','sha256'}:raise AssertionError('HISTORICAL_SNAPSHOT_FIELDS')
  path=directory/item['filename']
  if path.name!=item['filename'] or not path.is_file() or path.is_symlink():raise AssertionError('HISTORICAL_FILE_MISSING_OR_ALIAS:'+item['filename'])
  raw=path.read_bytes()
  if len(raw)!=item['byte_length'] or digest(raw)!=item['sha256']:raise AssertionError('HISTORICAL_FILE_CHANGED:'+item['filename'])

def test_ids():
 suite=unittest.defaultTestLoader.discover(str(ROOT/'tests'),pattern='test_*.py');found=[]
 def walk(s):
  for x in s:
   if isinstance(x,unittest.TestSuite):walk(x)
   else:found.append(x.id())
 walk(suite);return found

class V3CompletionLineageKeyRepair(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.before=BEFORE.read_text(encoding='utf-8');cls.after=SOURCE.read_text(encoding='utf-8');cls.gate=json.loads((REVIEW/'PRE_REPAIR_GATE.json').read_bytes());cls.app=Path(os.environ['APPDATA'])/'MetaQuotes/Terminal/Common/Files/KingEA';cls.spool=cls.app/'stage14_spool'/RUN;cls.obs=cls.app/'conformance_observability'/RUN
 def test_01_historical_fixed_name_key(self):self.assertEqual(OLD_KEY,digest(b'V3_COMPLETION'))
 def test_02_historical_payload_length_and_hash(self):
  p=self.spool/f'NATIVE_COST_0_{OLD_KEY}.evidence';self.assertEqual(363,len(p.read_bytes()));self.assertEqual(OLD_SHA,digest(p.read_bytes()))
 def test_03_historical_profile_hash(self):
  p=self.spool/f'NATIVE_COST_0_{OLD_KEY}.evidence';self.assertEqual('2E69633C041F44258B30089FB3C534F468BD1908998F1D40A49B5A6E5C1D1DF0',json.loads(p.read_bytes())['profile_hash'])
 def test_04_current_expected_payload_differs(self):
  expected=json.loads((ROOT/'governance/review/v3_capture_lineage_key_long_runtime_20260926/RUNTIME_REVIEW_BUNDLE/validation/COMPLETION_COLLISION_ANALYSIS.json').read_bytes());self.assertEqual('CEA1A9AAED20DE13F6A55EF8022E8B3EBDEA82290D93CBF3BA63ABC0B6DCC169',expected['expected_current_sha256']);self.assertNotEqual(OLD_SHA,expected['expected_current_sha256'])
 def test_05_completion_call_site_uses_governed_control(self):
  body=section(self.after,'bool ResearchNativeCompletion(){','// Fixed infrastructure dispatcher.');self.assertIn(NEW_LINE,body)
 def test_06_legacy_nonconformance_name_preserved(self):self.assertIn('InpConformanceControlSha256:"V3_COMPLETION"',self.after)
 def test_07_cross_lineage_keys_do_not_alias(self):self.assertNotEqual(key(LAYER_B),key('70AEEFCD26FF7CD381B37399C57018B61AA52321B56DD46BF1E9FD549D499949'))
 def test_08_same_lineage_key_is_deterministic(self):self.assertEqual(key(LAYER_B),key(LAYER_B))
 def test_09_same_lineage_equal_bytes_reuse(self):
  with tempfile.TemporaryDirectory() as t:
   self.assertTrue(persist(Path(t),name(LAYER_B),b'same')[0]);self.assertTrue(persist(Path(t),name(LAYER_B),b'same')[0])
 def test_10_same_lineage_conflict_fails_closed(self):
  with tempfile.TemporaryDirectory() as t:
   ok,p=persist(Path(t),name(LAYER_B),b'first');self.assertTrue(ok);self.assertFalse(persist(Path(t),name(LAYER_B),b'second')[0]);self.assertEqual(b'first',p.read_bytes())
 def test_11_historical_target_not_overwritten(self):self.assertNotEqual(OLD_KEY,key(LAYER_B));self.test_02_historical_payload_length_and_hash()
 def test_12_no_random_or_attempt_suffix(self):
  lines=[x for x in self.after.splitlines() if 'string completion_name=' in x]
  self.assertEqual(1,len(lines))
  line=lines[0]
  for token in ['TimeLocal','TimeCurrent','GetTickCount','MathRand','GUID','UUID','retry','attempt','counter']:self.assertNotIn(token,line)
 def test_13_persist_function_byte_identical(self):self.assertEqual(section(self.before,'bool ResearchNativePersist(','string DAQuote('),section(self.after,'bool ResearchNativePersist(','string DAQuote('))
 def test_14_physical_filename_fixed_width(self):
  leaf=f'NATIVE_COST_0_{key(LAYER_B)}.evidence';self.assertRegex(key(LAYER_B),r'^[0-9A-F]{64}$');self.assertEqual(87,len(leaf))
 def test_15_path_length_bound(self):
  relative=f'KingEA\\stage14_spool\\{RUN}\\NATIVE_COST_0_{key(LAYER_B)}.evidence';effective='C:\\Users\\tpent\\AppData\\Roaming\\MetaQuotes\\Terminal\\Common\\Files\\'+relative;self.assertEqual(173,len(relative));self.assertEqual(237,len(effective))
 def test_16_v3_capture_repair_intact(self):self.assertIn('string capture_name="V3_CAPTURE_"+ResearchSha256String(g_da.group)+"_"+InpConformanceControlSha256;',self.after);self.assertEqual(section(self.before,'bool ResearchNativeProject(','bool ResearchNativeBoundaryFinalize('),section(self.after,'bool ResearchNativeProject(','bool ResearchNativeBoundaryFinalize('))
 def test_17_ordercheck_serialization_intact(self):self.assertEqual(section(self.before,'bool ResearchNativeOrderCheck(','\n}'),section(self.after,'bool ResearchNativeOrderCheck(','\n}'))
 def test_18_stage13_serialization_intact(self):self.assertIn('string DAAccountingNumber(double n){return DAQuote(DoubleToString(n,8));}',self.after);self.assertEqual(section(self.before,'bool ResearchNativeProject(','bool ResearchNativeBoundaryFinalize('),section(self.after,'bool ResearchNativeProject(','bool ResearchNativeBoundaryFinalize('))
 def test_19_valid_history_add_only_intact(self):self.assertEqual(self.gate['protected_sources']['MQL5/Include/KingEA/DecisionALifecycle.mqh']['sha256'],digest((ROOT/'MQL5/Include/KingEA/DecisionALifecycle.mqh').read_bytes()));self.assertEqual(section(self.before,'bool ResearchNativeProject(','bool ResearchNativeBoundaryFinalize('),section(self.after,'bool ResearchNativeProject(','bool ResearchNativeBoundaryFinalize('))
 def test_20_marker_count_32(self):self.assertEqual(32,len(set(re.findall(r'"(OBS_[A-Z0-9_]+)"',EA.read_text(encoding='utf-8')+self.after))))
 def test_21_persistence_lasterror_isolation(self):
  persist_source=section(self.after,'bool ResearchNativePersist(','string DAQuote(');self.assertRegex(persist_source,r'ResetLastError\(\);\s*int h=FileOpen\(file,FILE_WRITE\|FILE_TXT\|FILE_ANSI\|FILE_COMMON\);\s*int write_open_error=GetLastError\(\);')
 def test_22_ordercheck_lasterror_isolation(self):
  s=section(self.after,'bool ResearchNativeOrderCheck(','\n}');m=re.search(r'ResetLastError\(\)(.*?)GetLastError\(\)',s,re.S);self.assertIsNotNone(m);self.assertNotIn('ResearchConformanceObserve',m.group(1))
 def test_23_protected_sources_unchanged(self):
  for rel in ['MQL5/Experts/KingEA/GuardedResearchTester.mq5','research_pipeline/decision_a_evidence.py','MQL5/Include/KingEA/DecisionADealAdapter.mqh','MQL5/Include/KingEA/DecisionALifecycle.mqh']:
   self.assertEqual(self.gate['protected_sources'][rel]['sha256'],digest((ROOT/rel).read_bytes()))
 def test_24_all_46_spool_files_unchanged(self):
  verify_historical_snapshot(self.spool,self.gate['spool_files'],46)
 def test_25_all_154_observability_files_unchanged(self):
  verify_historical_snapshot(self.obs,self.gate['observability_files'],154)
 def test_26_runtime_archive_unchanged(self):self.assertEqual('BA25BE5BBBE007315A89229EDB662F7BE943B16CE67A1B7F278D4DE96578E458',digest(RUNTIME.read_bytes()))
 def test_27_accepted_test_ids_and_sources_retained(self):
  accepted=json.loads((REVIEW/'ACCEPTED_TEST_IDS.json').read_bytes())
  self.assertTrue(set(accepted['ids'])<=set(test_ids()))
  old=json.loads((REVIEW/'ACCEPTED_TEST_SOURCE_HASHES.json').read_bytes())
  self.assertTrue(all(digest((ROOT/path).read_bytes())==h for path,h in old.items() if Path(path).name!='test_evidence_producer_serialization_repair.py'))
  path='tests\\test_evidence_producer_serialization_repair.py'
  updated=(ROOT/path).read_text(encoding='utf-8')
  first=updated.index('        completion_repair = (')
  last=updated.index('        self.assertEqual(normalized, before)',first)
  original=updated[:first]+updated[last:]
  self.assertEqual(old[path],digest(original.encode('utf-8')))
 def test_28_only_completion_call_site_changed(self):self.assertEqual(self.before,self.after.replace(NEW_LINE,OLD_LINE,1))

if __name__=='__main__':unittest.main()
