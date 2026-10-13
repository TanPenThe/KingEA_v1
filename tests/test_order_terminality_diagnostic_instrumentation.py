"""Static and synthetic non-runtime checks for capture-only terminality diagnostics."""
import hashlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "MQL5/Include/KingEA/DecisionADealAdapter.mqh"
INTEGRATION = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
LIFECYCLE = ROOT / "MQL5/Include/KingEA/DecisionALifecycle.mqh"
EA = ROOT / "MQL5/Experts/KingEA/GuardedResearchTester.mq5"
BEFORE = ROOT / "governance/review/order_terminality_diagnostic_instrumentation_20260923/before"


def body(source, name):
    match = re.search(r"\b(?:bool|void|string|double|int)\s+" + re.escape(name) + r"\s*\([^;{}]*\)\s*\{", source)
    if not match:
        raise AssertionError(name)
    start = match.end()
    depth = 1
    end = start
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end-1]


class TerminalityDiagnosticInstrumentation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.adapter = ADAPTER.read_text()
        cls.integration = INTEGRATION.read_text()
        cls.old_integration = (BEFORE / "GuardedNativeCostIntegration.mqh").read_text()
        cls.old_adapter = (BEFORE / "DecisionADealAdapter.mqh").read_text()
        cls.lifecycle = LIFECYCLE.read_bytes()
        cls.ea = EA.read_text()

    def test_01_transaction_type_captured_exactly(self):
        capture = body(self.adapter, "Capture")
        self.assertIn("rows[tail].type=t.type", capture)
        self.assertIn("row.type", body(self.integration, "ResearchTerminalityCaptureDiagnostic"))

    def test_02_monotonic_sequence_at_capture(self):
        capture = body(self.adapter, "Capture")
        self.assertIn("rows[tail].capture_sequence=++next_capture_sequence", capture)
        self.assertLess(capture.index("capture_sequence=++next_capture_sequence"), capture.index("tail=(tail+1)%256"))
        self.assertIn("next_capture_sequence=0", body(self.adapter, "Reset"))

    def test_03_sequence_not_assigned_during_poll(self):
        self.assertNotIn("++next_capture_sequence", body(self.integration, "ResearchNativePoll"))
        self.assertNotIn("capture_sequence=++", body(self.integration, "ResearchNativePoll"))

    def test_04_stored_row_preserves_sequence(self):
        poll = body(self.integration, "ResearchNativePoll")
        self.assertIn("g_da_terminals[g_da_terminal_count++]=row", poll)
        self.assertIn("DANativeCapture t=g_da_terminals[i]", poll)
        self.assertIn("t,g_da_terminal_diagnostic_evaluations[i]", poll)

    def test_05_terminal_observation_exposes_type_and_sequence(self):
        poll = body(self.integration, "ResearchNativePoll")
        self.assertIn('\\\"transaction_type\\\"', poll)
        self.assertIn('\\\"capture_sequence\\\"', poll)
        self.assertIn('(string)row.type', poll)
        self.assertIn('(string)row.capture_sequence', poll)

    def test_06_raw_volume_and_unfilled_provenance(self):
        capture = body(self.adapter, "Capture")
        self.assertIn("rows[tail].unfilled=t.volume", capture)
        self.assertIn("rows[tail].raw_transaction_volume=t.volume", capture)
        poll = body(self.integration, "ResearchNativePoll")
        self.assertIn("DANumber(row.raw_transaction_volume)", poll)

    def test_07_order_type_distinct_from_transaction_type(self):
        capture = body(self.adapter, "Capture")
        self.assertIn("rows[tail].order_type=t.order_type", capture)
        poll = body(self.integration, "ResearchNativePoll")
        self.assertIn('\\\"type\\\"', poll)
        self.assertIn('(string)row.order_type', poll)
        self.assertIn('\\\"transaction_type\\\"', poll)

    def test_08_two_callback_types_can_be_distinguished(self):
        self.assertIn("TRADE_TRANSACTION_ORDER_DELETE", self.adapter)
        self.assertIn("TRADE_TRANSACTION_HISTORY_ADD", self.adapter)
        callbacks = [(1, "ORDER_DELETE", .1), (2, "HISTORY_ADD", 0.)]
        self.assertNotEqual(callbacks[0][:2], callbacks[1][:2])
        self.assertIn("row.type", body(self.integration, "ResearchTerminalityCaptureDiagnostic"))

    def test_09_reevaluation_reuses_sequence(self):
        poll = body(self.integration, "ResearchNativePoll")
        self.assertIn("g_da_terminal_diagnostic_evaluations[i]++", poll)
        self.assertIn("g_da_terminal_diagnostic_evaluations[i]<2", poll)
        self.assertIn("ResearchTerminalityEvaluationDiagnostic(t,g_da_terminal_diagnostic_evaluations[i])", poll)
        self.assertIn("row.capture_sequence", body(self.integration, "ResearchTerminalityEvaluationDiagnostic"))

    def test_10_deal_and_terminal_capture_order_visible(self):
        poll = body(self.integration, "ResearchNativePoll")
        self.assertLess(poll.index("ResearchTerminalityCaptureDiagnostic(row)"), poll.index("if(row.type==TRADE_TRANSACTION_DEAL_ADD)"))
        capture = body(self.adapter, "Capture")
        self.assertIn("TRADE_TRANSACTION_DEAL_ADD", capture)
        self.assertIn("rows[tail].deal_ticket=t.deal", capture)
        for field in ("capture_sequence", "transaction_type", "deal", "order", "position"):
            self.assertIn(field, body(self.integration, "ResearchTerminalityCaptureDiagnostic"))

    def test_11_known_conflict_still_follows_old_state_machine(self):
        old = body(self.old_integration, "ResearchNativePoll")
        new = body(self.integration, "ResearchNativePoll")
        self.assertIn('g_da.Invalidate("CONFLICTING_ORDER_TERMINALITY")', old)
        self.assertIn('g_da.Receipt(t.order,true,actual,valid', old)
        authority = body(self.integration, "ResearchNativeAuthoritativeTerminal")
        self.assertIn("if(t.type!=TRADE_TRANSACTION_HISTORY_ADD)return false", authority)
        self.assertLess(new.index("ResearchNativeAuthoritativeTerminal(t,actual)"), new.index("g_da.Receipt(t.order,true,actual,true,no_fill)"))
        self.assertIn("g_da.Receipt(t.order,true,actual,true,no_fill)", new)
        self.assertIn("order=ticket;terminal=completed", LIFECYCLE.read_text())

    def test_12_diagnostic_is_not_a_conformance_marker(self):
        added = body(self.integration, "ResearchTerminalityCaptureDiagnostic") + body(self.integration, "ResearchTerminalityEvaluationDiagnostic")
        self.assertNotIn("ResearchConformanceObserve", added)
        self.assertNotIn("OBS_", added)
        markers = set(re.findall(r'"(OBS_[A-Z0-9_]+)"', self.ea + self.integration))
        self.assertEqual(32, len(markers))

    def test_13_governed_tester_guard_and_no_authority(self):
        guard = body(self.integration, "ResearchTerminalityDiagnosticEnabled")
        for token in ("InpNativeConformance", 'InpPurpose=="NON_CANDIDATE_NATIVE_CONFORMANCE_V1"', "MQLInfoInteger(MQL_TESTER)", "g_initialized"):
            self.assertIn(token, guard)
        for name in ("ResearchTerminalityCaptureDiagnostic", "ResearchTerminalityEvaluationDiagnostic"):
            code = body(self.integration, name)
            self.assertIn("if(!ResearchTerminalityDiagnosticEnabled())return;", code)
            for forbidden in ("OrderSend", "OrderCheck", "g_da.Receipt", "g_da.Reconcile", "ResearchNativeRecord", "ResearchConformanceObserve"):
                self.assertNotIn(forbidden, code)

    def test_14_persistence_and_ordercheck_bytes_unchanged(self):
        for name in ("ResearchNativePersist", "ResearchNativeRecord"):
            self.assertEqual(body(self.old_integration, name), body(self.integration, name))
        old_check = body(self.old_integration, "ResearchNativeOrderCheck")
        new_check = body(self.integration, "ResearchNativeOrderCheck")
        # Preserve the frozen check/send behavior; only expiration JSON quoting is authorized.
        self.assertEqual(old_check.replace("(string)r.expiration", "DAQuote((string)r.expiration)"), new_check)
        self.assertIn("string evidence_key=ResearchSha256String(name)", self.integration)
        self.assertIn("ResetLastError();\n   int h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);\n   int write_open_error=GetLastError();", self.integration)

    def test_15_lifecycle_and_candidate_source_unchanged(self):
        self.assertEqual("C01EA494B37E2C7F4CD5C9AA7A7F6B4E81A331BA745591CAFAE616CFD51BEE03", hashlib.sha256(self.lifecycle).hexdigest().upper())
        self.assertNotIn("KINGEA_NATIVE_TRANSACTION_CAPTURE", self.ea)

    def test_16_last_error_interposition_zero(self):
        all_source = self.ea + "\n" + self.integration
        pairs = re.findall(r"ResetLastError\(\)(.*?)GetLastError\(\)", all_source, re.S)
        self.assertEqual(2, len(pairs))
        for between in pairs:
            self.assertNotIn("ResearchTerminality", between)
            self.assertNotIn("Print", between)


if __name__ == "__main__":
    unittest.main()
