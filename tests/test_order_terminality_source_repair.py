"""Non-runtime source and retained-trace checks for terminal authority repair."""
import hashlib
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / 'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh'
ADAPTER = ROOT / 'MQL5/Include/KingEA/DecisionADealAdapter.mqh'
LIFECYCLE = ROOT / 'MQL5/Include/KingEA/DecisionALifecycle.mqh'
EA = ROOT / 'MQL5/Experts/KingEA/GuardedResearchTester.mq5'
BEFORE = ROOT / 'governance/review/order_terminality_source_repair_20260924/before'
TRACE = ROOT / 'governance/review/order_terminality_callback_origin_runtime_20260923/evidence_attempt3/FINAL_RESULT.json'


def body(source, name):
    match = re.search(r'\b(?:bool|void|string|double|int)\s+' + re.escape(name) + r'\s*\([^;{}]*\)\s*\{', source)
    if not match:
        raise AssertionError(name)
    start = match.end();depth = 1;end = start
    while depth:
        depth += (source[end] == '{') - (source[end] == '}');end += 1
    return source[start:end-1]


class OrderTerminalitySourceRepair(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.integration = INTEGRATION.read_text(encoding='utf-8')
        cls.adapter = ADAPTER.read_text(encoding='utf-8')
        cls.lifecycle = LIFECYCLE.read_bytes()
        cls.ea = EA.read_text(encoding='utf-8')
        cls.old_integration = (BEFORE / 'MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh').read_text(encoding='utf-8')
        cls.old_adapter = (BEFORE / 'MQL5/Include/KingEA/DecisionADealAdapter.mqh').read_text(encoding='utf-8')
        cls.old_lifecycle = (BEFORE / 'MQL5/Include/KingEA/DecisionALifecycle.mqh').read_bytes()

    def test_authority_gate_is_explicit_history_add_only(self):
        authority = body(self.integration, 'ResearchNativeAuthoritativeTerminal')
        self.assertIn('if(t.type!=TRADE_TRANSACTION_HISTORY_ADD)return false', authority)
        self.assertNotIn('TRADE_TRANSACTION_ORDER_DELETE', authority)
        for state in ('ORDER_STATE_FILLED', 'ORDER_STATE_CANCELED', 'ORDER_STATE_REJECTED', 'ORDER_STATE_EXPIRED'):
            self.assertIn(state, authority)
        self.assertIn('t.order_type==expected_type', authority)
        self.assertIn('(t.order_state!=ORDER_STATE_FILLED||t.unfilled==0)', authority)
        self.assertIn('actual=g_da.requested-t.unfilled', authority)

    def test_only_authorized_valid_receipt_reaches_lifecycle_mutation(self):
        poll = body(self.integration, 'ResearchNativePoll')
        gate = poll.index('if(!ResearchNativeAuthoritativeTerminal(t,actual))continue;')
        receipt = poll.index('g_da.Receipt(t.order,true,actual,true,no_fill)')
        self.assertLess(gate, receipt)
        self.assertEqual(poll.count('g_da.Receipt('), 1)
        self.assertIn('if(t.order!=g_da.order)continue', poll)
        self.assertIn('if(prior.order==t.order&&ResearchNativeAuthoritativeTerminal(prior,prior_actual)', poll)

    def test_accepted_runtime_trace_routes_delete_as_transitional_and_history_as_authority(self):
        trace = json.loads(TRACE.read_text(encoding='utf-8'))
        captures = {x['capture_sequence']: x for x in trace['captures']}
        delete = captures[2];history = captures[3]
        self.assertEqual((delete['transaction_type'], delete['order_state'], delete['raw_transaction_volume']), (2, 4, '0.1000000000000000'))
        self.assertEqual((history['transaction_type'], history['order_state'], history['raw_transaction_volume']), (3, 4, '0.0000000000000000'))
        authority = body(self.integration, 'ResearchNativeAuthoritativeTerminal')
        self.assertIn('t.type!=TRADE_TRANSACTION_HISTORY_ADD', authority)
        poll = body(self.integration, 'ResearchNativePoll')
        self.assertLess(poll.index('if(!ResearchNativeAuthoritativeTerminal(t,actual))continue;'),
                        poll.index('g_da.Receipt(t.order,true,actual,true,no_fill)'))

    def test_authoritative_conflicts_fail_but_transitional_rows_do_not_compare(self):
        poll = body(self.integration, 'ResearchNativePoll')
        gate = poll.index('if(!ResearchNativeAuthoritativeTerminal(t,actual))continue;')
        conflict = poll.index('g_da.Invalidate("CONFLICTING_ORDER_TERMINALITY")')
        self.assertLess(gate, conflict)
        self.assertIn('prior.position!=t.position', poll)
        self.assertIn('!DAVolumeEqual(prior_actual,actual)', poll)
        self.assertIn('prior_no_fill!=no_fill', poll)
        self.assertIn('!DAVolumeEqual(actual,g_da.executed_target)', poll)

    def test_no_fill_cancel_reject_and_expiry_semantics_are_preserved(self):
        authority = body(self.integration, 'ResearchNativeAuthoritativeTerminal')
        poll = body(self.integration, 'ResearchNativePoll')
        lifecycle = self.lifecycle.decode('utf-8')
        self.assertIn('ORDER_STATE_CANCELED', authority)
        self.assertIn('ORDER_STATE_REJECTED', authority)
        self.assertIn('ORDER_STATE_EXPIRED', authority)
        self.assertIn('actual==0&&t.order_state!=ORDER_STATE_FILLED', poll)
        self.assertIn('Receipt(t.order,true,actual,true,no_fill)', poll)
        self.assertIn('no_fill=completed&&execution_volume_authenticated&&actual_executed==0&&rejected_without_fill', lifecycle)
        self.assertIn('if(no_fill && intent==DA_ENTRY && position==0)', lifecycle)
        self.assertEqual(self.lifecycle, self.old_lifecycle)

    def test_raw_terminal_fields_and_transaction_order_type_separation_remain(self):
        poll = body(self.integration, 'ResearchNativePoll')
        capture = body(self.adapter, 'Capture')
        for field in ('transaction_type', 'capture_sequence', 'raw_transaction_volume'):
            self.assertIn(field, poll)
        self.assertIn('row.order_type', poll)
        self.assertIn('(string)row.type', poll)
        self.assertIn('rows[tail].type=t.type', capture)
        self.assertIn('rows[tail].order_type=t.order_type', capture)
        self.assertEqual(self.adapter, self.old_adapter)

    def test_diagnostic_messages_remain_outside_the_32_marker_chain(self):
        diagnostics = body(self.integration, 'ResearchTerminalityCaptureDiagnostic') + body(self.integration, 'ResearchTerminalityEvaluationDiagnostic')
        self.assertIn('KINGEA_NATIVE_TRANSACTION_CAPTURE', diagnostics)
        self.assertIn('KINGEA_NATIVE_TERMINAL_EVALUATION', diagnostics)
        self.assertNotIn('ResearchConformanceObserve', diagnostics)
        markers = set(re.findall(r'"(OBS_[A-Z0-9_]+)"', self.ea + self.integration))
        self.assertEqual(32, len(markers))

    def test_path_repair_ordercheck_and_ordersend_are_byte_identical(self):
        for name in ('ResearchNativePersist', 'ResearchNativeRecord'):
            self.assertEqual(body(self.old_integration, name), body(self.integration, name))
        old_check = body(self.old_integration, 'ResearchNativeOrderCheck')
        new_check = body(self.integration, 'ResearchNativeOrderCheck')
        # The only permitted OrderCheck-body delta is quoting expiration as JSON text.
        self.assertEqual(old_check.replace('(string)r.expiration', 'DAQuote((string)r.expiration)'), new_check)
        self.assertEqual(self.old_integration.count('ResearchOrderSend('), self.integration.count('ResearchOrderSend('))
        source = self.integration
        self.assertIn('string evidence_key=ResearchSha256String(name)', source)
        self.assertIn('NATIVE_COST_', source)
        self.assertIn('ResetLastError();\n   int h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);\n   int write_open_error=GetLastError();', source)
        self.assertEqual(hashlib.sha256(self.lifecycle).hexdigest().upper(),
                         hashlib.sha256(self.old_lifecycle).hexdigest().upper())

    def test_no_last_error_observer_interpositions(self):
        all_source = self.ea + '\n' + self.integration
        pairs = re.findall(r'ResetLastError\(\)(.*?)GetLastError\(\)', all_source, re.S)
        self.assertEqual(len(pairs), 2)
        for between in pairs:
            self.assertNotIn('ResearchConformanceObserve', between)
            self.assertNotIn('ResearchTerminality', between)
            self.assertNotIn('Print', between)


if __name__ == '__main__':
    unittest.main()
