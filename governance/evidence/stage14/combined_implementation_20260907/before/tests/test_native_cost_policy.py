import hashlib
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

class NativeCostPolicyTests(unittest.TestCase):
    def test_adopted_bytes_and_stage13_v1_are_unchanged(self):
        expected={
            'governance/review/DRAFT_CURRENT_RUN_NATIVE_EXECUTION_ACCOUNTING_METADATA_ONLY_AMENDMENT_V2_20260905.md':'CDFE801225C54C622A566CB125FE37B0759A3E47320D988571B796629CF984D9',
            'governance/review/DRAFT_EVALUATION_BOUNDARY_MARK_TO_MARKET_FINALIZATION_AMENDMENT_V4_20260905.md':'909C23E3B14BB64A62BC371890B2FFFB1964D24FC24879971DB614FB078E92C6',
            'MQL5/Include/KingEA/AccountingEvents.mqh':'2B88475645AC23207D9A4227A676E89E8D6D58C9753FAE12BF1C8496CA839D9D',
            'MQL5/Include/KingEA/CandidateEthSt001.mqh':'4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83'}
        for path,value in expected.items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest().upper(),value,path)

    def test_history_access_is_single_transaction_ticket_only(self):
        adapter=(ROOT/'MQL5/Include/KingEA/NativeCostMetadataAdapter.mqh').read_text()
        code=re.sub(r'//[^\n]*','',adapter)
        self.assertEqual(re.findall(r'HistoryDealSelect\((.*?)\)',code),['trans.deal'])
        self.assertNotRegex(code,r'\b(HistorySelect|HistorySelectByPosition|HistoryDealsTotal|HistoryDealGetTicket|HistoryOrder\w*)\s*\(')
        for args in re.findall(r'HistoryDealGet(?:Double|Integer|String)\((.*?)\)',code):
            self.assertTrue(args.startswith('trans.deal,'))
        self.assertIn('trans.type!=TRADE_TRANSACTION_DEAL_ADD',code)

    def test_core_has_no_terminal_equity_history_or_order_capability(self):
        core=(ROOT/'MQL5/Include/KingEA/NativeCostEvidence.mqh').read_text()
        self.assertNotRegex(core,r'\b(AccountInfoDouble|History\w+|OrderSend|OrderSendAsync|SymbolInfoTick)\s*\(')
        entry=core.split('bool CaptureEntry',1)[1].split('bool ReconcileReceipt',1)[0]
        self.assertNotIn('KingEAProcessAccountingEvent',entry)
        self.assertNotIn('strategy_net_pnl',entry)
        self.assertEqual(core.count('KingEAProcessAccountingEvent('),1)

    def test_non_candidate_harness_is_tester_guarded(self):
        source=(ROOT/'MQL5/Experts/KingEA/NativeCostConformance.mq5').read_text()
        self.assertNotIn('CandidateEthSt001',source)
        self.assertNotIn('SleeveEthSt001',source)
        self.assertIn('!MQLInfoInteger(MQL_TESTER) || !OrderSend',source)
        self.assertEqual(len(re.findall(r'\bOrderSend\(',source)),1)

if __name__=='__main__': unittest.main()
