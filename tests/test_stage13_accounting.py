import unittest
import tempfile
from pathlib import Path

from accounting_pipeline.stage13 import Stage13Accounting
from accounting_pipeline.cli import write_new_bundle


class Stage13AccountingTests(unittest.TestCase):
    def test_events_form_a_deterministic_chain_and_replay_is_rejected(self):
        accounting = Stage13Accounting()
        events = [
            {
                "event_id": "EVT-001",
                "event_type": "DEAL",
                "server_time_msc": 1_722_162_000_000,
                "utc_time_msc": 1_722_133_200_000,
                "account_fingerprint": "A" * 64,
                "deployment_id": "KINGEA-DEMO2-001",
                "sleeve_id": "SLEEVE-1",
                "trade_group_id": "GROUP-1",
                "net_amount": "10.00",
            }
        ]

        first = accounting.process_batch(events, checkpoint=None)
        self.assertEqual(first["status"], "ACCEPTED")
        self.assertEqual(first["event_count"], 1)
        self.assertEqual(len(first["ledger_root_sha256"]), 64)

        replay = accounting.process_batch(events, checkpoint=first["checkpoint"])
        self.assertEqual(replay["status"], "QUARANTINED")
        self.assertEqual(replay["reason"], "DUPLICATE_EVENT")

    def test_realized_costs_are_net_once_and_external_cash_flow_is_separate(self):
        accounting = Stage13Accounting()
        common = {
            "server_time_msc": 1_722_162_000_000,
            "utc_time_msc": 1_722_133_200_000,
            "account_fingerprint": "A" * 64,
            "deployment_id": "KINGEA-DEMO2-001",
            "sleeve_id": "SLEEVE-1",
            "trade_group_id": "GROUP-1",
        }
        events = [
            dict(
                common,
                event_id="DEAL-1",
                event_type="DEAL",
                gross_profit="12.00",
                commission="-1.00",
                swap="-0.50",
                fee="-0.25",
                spread_estimate="2.00",
                slippage_estimate="1.00",
            ),
            dict(
                common,
                event_id="FLOW-1",
                event_type="EXTERNAL_CASH_FLOW",
                cash_flow_type="DEPOSIT",
                amount="500.00",
            ),
        ]

        result = accounting.process_batch(events, checkpoint=None)

        self.assertEqual(result["account_summary"]["strategy_net_pnl"], "10.25")
        self.assertEqual(result["account_summary"]["external_cash_flow"], "500.00")
        self.assertEqual(result["account_summary"]["spread_attribution"], "2.00")
        self.assertEqual(result["account_summary"]["slippage_attribution"], "1.00")
        self.assertEqual(result["sleeve_summaries"]["SLEEVE-1"]["strategy_net_pnl"], "10.25")

    def test_statement_reconciliation_matches_each_deal_without_offsetting_errors(self):
        accounting = Stage13Accounting()
        ledger = [
            {
                "event_type": "DEAL",
                "deal_ticket": "101",
                "server_time_msc": 1_000_000,
                "volume": "0.01",
                "price": "1876.28",
                "gross_profit": "5.00",
                "commission": "-0.25",
                "swap": "0.00",
                "fee": "0.00",
            },
            {
                "event_type": "DEAL",
                "deal_ticket": "102",
                "server_time_msc": 2_000_000,
                "volume": "0.01",
                "price": "1880.00",
                "gross_profit": "-2.00",
                "commission": "-0.25",
                "swap": "0.00",
                "fee": "0.00",
            },
        ]
        matching = [dict(row) for row in ledger]
        self.assertEqual(
            accounting.reconcile_statement(
                ledger,
                matching,
                tick_size="0.01",
                volume_step="0.01",
                currency_unit="0.01",
            )["status"],
            "RECONCILED",
        )

        offsetting = [dict(row) for row in matching]
        offsetting[0]["gross_profit"] = "5.01"
        offsetting[1]["gross_profit"] = "-2.01"
        result = accounting.reconcile_statement(
            ledger,
            offsetting,
            tick_size="0.01",
            volume_step="0.01",
            currency_unit="0.01",
        )
        self.assertEqual(result["status"], "RECONCILIATION_QUARANTINE")
        self.assertEqual(result["mismatch_count"], 2)

    def test_repeated_month_and_integrity_failures_latch_cumulative_review(self):
        accounting = Stage13Accounting()
        months = [
            {"month": "2026-01", "status": "ACCEPTED"},
            {"month": "2026-02", "status": "FAILED"},
            {"month": "2026-03", "status": "ACCEPTED"},
            {"month": "2026-04", "status": "FAILED"},
            {"month": "2026-05", "status": "ACCEPTED"},
            {"month": "2026-06", "status": "FAILED"},
        ]
        coverage = accounting.evaluate_controls(
            as_of_broker_day="2026-07-01",
            month_closes=months,
            quarantine_dates=[],
        )
        self.assertEqual(coverage["status"], "CUMULATIVE_ACCOUNTING_REVIEW")
        self.assertEqual(coverage["coverage_failures"], 3)

        integrity = accounting.evaluate_controls(
            as_of_broker_day="2026-07-01",
            month_closes=[dict(row, status="ACCEPTED") for row in months],
            quarantine_dates=["2026-04-15", "2026-06-30"],
        )
        self.assertEqual(integrity["status"], "CUMULATIVE_ACCOUNTING_REVIEW")
        self.assertEqual(integrity["integrity_failures"], 2)
        self.assertEqual(integrity["governing_latch"], "CUMULATIVE")

    def test_review_requires_complete_evidence_and_uses_reduced_resume_rules(self):
        accounting = Stage13Accounting()
        complete = {
            "originals_preserved": True,
            "append_only_corrections": True,
            "root_cause_documented": True,
            "fresh_broker_capture": True,
            "replay_exact": True,
            "integrity_tests_passed": True,
            "owner_approved": True,
            "outstanding_months_reconciled": True,
        }
        denied = accounting.review_recovery(
            latch="RECONCILIATION_QUARANTINE",
            previously_earned_tier=1.10,
            evidence=dict(complete, owner_approved=False),
            clean_days=5,
            current_epoch=3,
        )
        self.assertEqual(denied["status"], "REVIEW_LATCHED")

        recovering = accounting.review_recovery(
            latch="RECONCILIATION_QUARANTINE",
            previously_earned_tier=1.10,
            evidence=complete,
            clean_days=4,
            current_epoch=3,
        )
        self.assertEqual(recovering["status"], "RECOVERY_ACTIVE")
        self.assertEqual(recovering["effective_tier_percent"], 0.55)

        cumulative = accounting.review_recovery(
            latch="CUMULATIVE_ACCOUNTING_REVIEW",
            previously_earned_tier=1.10,
            evidence=complete,
            clean_days=5,
            current_epoch=3,
        )
        self.assertEqual(cumulative["status"], "BOTTOM_TIER_RAMP")
        self.assertEqual(cumulative["effective_tier_percent"], 0.25)
        self.assertEqual(cumulative["next_epoch"], 4)
        self.assertTrue(cumulative["archive_active_events"])

    def test_health_review_never_invents_oos_ranges_and_pauses_on_drift(self):
        accounting = Stage13Accounting()
        observed = {
            "profit_factor": 1.25,
            "expectancy_r": 0.10,
            "drawdown_percent": 8.0,
            "trade_count": 30,
        }
        unavailable = accounting.build_health_review(
            period="2026-07",
            observed=observed,
            expected_range_manifest=None,
            reconciliation_status="RECONCILED",
        )
        self.assertEqual(unavailable["classification"], "NOT_EVALUABLE")
        self.assertTrue(unavailable["pause_tier_advancement"])

        manifest = {
            "status": "AUTHORIZED",
            "manifest_sha256": "B" * 64,
            "ranges": {
                "profit_factor": {"minimum": 1.30},
                "expectancy_r": {"minimum": 0.05},
                "drawdown_percent": {"maximum": 12.0},
                "trade_count": {"minimum": 20, "maximum": 60},
            },
        }
        drift = accounting.build_health_review(
            period="2026-07",
            observed=observed,
            expected_range_manifest=manifest,
            reconciliation_status="RECONCILED",
        )
        self.assertEqual(drift["classification"], "OUTSIDE_RANGE")
        self.assertEqual(drift["outside_metrics"], ["profit_factor"])
        self.assertTrue(drift["pause_tier_advancement"])
        self.assertFalse(drift["flatten_required"])

    def test_mt5_html_adapter_redacts_account_identity_and_rejects_unknown_templates(self):
        accounting = Stage13Accounting()
        html = """
        <html><body><p>Account: 9876543210</p>
        <table><tr><th>Deal</th><th>Time</th><th>Type</th><th>Symbol</th>
        <th>Volume</th><th>Price</th><th>Commission</th><th>Swap</th><th>Profit</th></tr>
        <tr><td>101</td><td>2026.07.28 20:12:29</td><td>buy</td><td>ETHUSD.s</td>
        <td>0.01</td><td>1876.28</td><td>-0.25</td><td>0.00</td><td>5.00</td></tr></table>
        </body></html>
        """
        result = accounting.parse_mt5_html_statement(
            html,
            account_fingerprint="A" * 64,
            server_utc_offset_seconds=8 * 3600,
        )
        self.assertEqual(result["status"], "PARSED")
        self.assertEqual(result["records"][0]["deal_ticket"], "101")
        self.assertNotIn("9876543210", str(result))

        rejected = accounting.parse_mt5_html_statement(
            "<html><table><tr><th>Ticket inconnu</th></tr></table></html>",
            account_fingerprint="A" * 64,
            server_utc_offset_seconds=8 * 3600,
        )
        self.assertEqual(rejected["status"], "UNSUPPORTED_TEMPLATE")

    def test_export_bundle_is_hashable_human_readable_and_contains_no_raw_login(self):
        accounting = Stage13Accounting()
        batch = accounting.process_batch(
            [
                {
                    "event_id": "EVT-EXPORT-1",
                    "event_type": "VALUATION",
                    "server_time_msc": 1_722_162_000_000,
                    "utc_time_msc": 1_722_133_200_000,
                    "account_fingerprint": "A" * 64,
                    "deployment_id": "KINGEA-DEMO2-001",
                    "sleeve_id": "SLEEVE-1",
                    "trade_group_id": "",
                    "equity": "1000.00",
                    "sleeve_equity": "1000.00",
                }
            ],
            checkpoint=None,
        )
        health = {
            "period": "2026-07",
            "classification": "NOT_EVALUABLE",
            "pause_tier_advancement": True,
        }
        bundle = accounting.render_export_bundle(batch=batch, health_review=health)

        self.assertIn('"event_id":"EVT-EXPORT-1"', bundle["events_jsonl"])
        self.assertIn("event_id,event_type", bundle["events_csv"])
        self.assertIn("# KingEA Accounting Health Review", bundle["health_markdown"])
        self.assertEqual(len(bundle["manifest"]["bundle_sha256"]), 64)
        self.assertNotIn("account_login", str(bundle).lower())

        with tempfile.TemporaryDirectory() as directory:
            paths = write_new_bundle(Path(directory), "2026-07-28", bundle)
            self.assertEqual(set(paths), {"events_jsonl", "events_csv", "health_markdown", "manifest"})
            with self.assertRaises(FileExistsError):
                write_new_bundle(Path(directory), "2026-07-28", bundle)

    def test_tester_accounting_frames_must_agree_with_legacy_completion(self):
        accounting = Stage13Accounting()
        frames = [
            "schema=1|sequence=1|event_id=ENTRY-1|event_type=2|net=0.000000000000|net_return=0.000000000000|net_r=0.000000000000|root=" + "A" * 64,
            "schema=1|sequence=2|event_id=CLOSE-1|event_type=9|net=10.250000000000|net_return=0.010250000000|net_r=1.025000000000|root=" + "B" * 64,
        ]
        complete = (
            "schema=1|event_count=2|close_count=1|trade_return_count=1|"
            "legacy_net=10.250000000000|ledger_net=10.250000000000|root="
            + "B" * 64
            + "|complete=1"
        )
        accepted = accounting.validate_tester_frames(
            event_frames=frames,
            completion_frame=complete,
            legacy_trade_returns=[0.01025],
            legacy_trade_r=[1.025],
            legacy_trade_net=[10.25],
        )
        self.assertTrue(accepted["passed"])

        altered = list(frames)
        altered[1] = altered[1].replace("10.250000000000", "10.240000000000")
        self.assertFalse(
            accounting.validate_tester_frames(
                event_frames=altered,
                completion_frame=complete,
                legacy_trade_returns=[0.01025],
                legacy_trade_r=[1.025],
                legacy_trade_net=[10.25],
            )["passed"]
        )

    def test_valuations_keep_external_cash_flows_out_of_equity_performance(self):
        accounting = Stage13Accounting()
        common = {
            "utc_time_msc": 1_722_133_200_000,
            "account_fingerprint": "A" * 64,
            "deployment_id": "KINGEA-DEMO2-001",
            "sleeve_id": "SLEEVE-1",
            "trade_group_id": "",
        }
        result = accounting.process_batch(
            [
                dict(common, event_id="V1", event_type="VALUATION", server_time_msc=1000, equity="1000.00", sleeve_equity="1000.00"),
                dict(common, event_id="F1", event_type="EXTERNAL_CASH_FLOW", server_time_msc=2000, cash_flow_type="DEPOSIT", amount="500.00"),
                dict(common, event_id="V2", event_type="VALUATION", server_time_msc=3000, equity="1510.00", sleeve_equity="1010.00"),
            ],
            checkpoint=None,
        )
        self.assertEqual(result["account_summary"]["broker_equity"], "1510.00")
        self.assertEqual(result["account_summary"]["cash_flow_adjusted_equity"], "1010.00")
        self.assertEqual(result["account_summary"]["cash_flow_adjusted_equity_high"], "1010.00")
        self.assertEqual(result["sleeve_summaries"]["SLEEVE-1"]["equity"], "1010.00")


if __name__ == "__main__":
    unittest.main()
