"""Non-result-bearing B2 evaluation-window conformance tests."""

from datetime import datetime, timedelta
from pathlib import Path
import unittest

from research_pipeline.b2_date_gate import (
    B2DateGateError,
    EvaluationWindow,
    normal_b2_execution_locks,
    realize_partition_dates,
)
from research_pipeline.stage14 import ResearchRunCoordinator, Stage14Error


class B2DateGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.start = datetime(2023, 1, 1)
        self.end = datetime(2023, 4, 1)
        self.window = EvaluationWindow(self.start, self.end)

    def test_half_open_entry_window_and_pending_boundary(self) -> None:
        self.assertEqual(self.window.classify(self.start - timedelta(minutes=30)), "WARMUP_ONLY")
        self.assertEqual(self.window.classify(self.start), "ELIGIBLE")
        self.assertEqual(self.window.classify(self.end - timedelta(minutes=30)), "ELIGIBLE")
        self.assertEqual(self.window.classify(self.end), "POST_END_BLOCKED")
        self.assertEqual(
            self.window.pending_outcome(self.end - timedelta(milliseconds=500), self.end),
            "DELAY_EXPIRY_AT_EVALUATION_END",
        )

    def test_open_exposure_at_end_is_a_governance_blocker_not_an_invented_exit(self) -> None:
        self.assertEqual(
            self.window.classify(self.end, has_open_exposure=True),
            "UNRESOLVED_END_EXPOSURE_POLICY",
        )
        self.assertTrue(self.window.requires_quarantine_at_end(has_open_exposure=True))
        self.assertFalse(self.window.requires_quarantine_at_end(has_open_exposure=False))

    def test_terminal_end_check_does_not_require_a_post_end_tick(self) -> None:
        self.assertEqual(
            self.window.terminal_outcome(has_open_position=False, has_pending_execution=False,
                                         has_trade_group=False),
            "TERMINAL_END_FLAT_ALLOWED",
        )
        self.assertEqual(
            self.window.terminal_outcome(has_open_position=True, has_pending_execution=False,
                                         has_trade_group=True),
            "TERMINAL_END_UNRESOLVED_EXPOSURE_FAIL_CLOSED",
        )
        self.assertEqual(
            self.window.terminal_outcome(has_open_position=False, has_pending_execution=True,
                                         has_trade_group=False),
            "TERMINAL_END_UNRESOLVED_EXPOSURE_FAIL_CLOSED",
        )

    def test_date_realization_is_explicit_and_to_date_is_inclusive(self) -> None:
        dates = realize_partition_dates("FOLD_1_TRAIN")
        self.assertEqual(dates["from_date"], "2021.04.01")
        self.assertEqual(dates["evaluation_start"], "2021-07-01T00:00:00")
        self.assertEqual(dates["evaluation_end_exclusive"], "2023-01-01T00:00:00")
        self.assertEqual(dates["to_date_inclusive"], "2022.12.31")
        with self.assertRaises(B2DateGateError):
            EvaluationWindow(self.end, self.start)

    def test_all_partition_dates_match_the_governed_v2_realization(self) -> None:
        expected = {
            "FOLD_1_TRAIN": ("2021.04.01", "2021-07-01T00:00:00", "2023-01-01T00:00:00", "2022.12.31"),
            "FOLD_1_FORWARD": ("2022.10.03", "2023-01-01T00:00:00", "2023-04-01T00:00:00", "2023.03.31"),
            "FOLD_2_TRAIN": ("2021.07.03", "2021-10-01T00:00:00", "2023-04-01T00:00:00", "2023.03.31"),
            "FOLD_2_FORWARD": ("2023.01.01", "2023-04-01T00:00:00", "2023-07-01T00:00:00", "2023.06.30"),
            "FOLD_3_TRAIN": ("2021.10.03", "2022-01-01T00:00:00", "2023-07-01T00:00:00", "2023.06.30"),
            "FOLD_3_FORWARD": ("2023.04.02", "2023-07-01T00:00:00", "2023-10-01T00:00:00", "2023.09.30"),
            "FOLD_4_TRAIN": ("2022.01.01", "2022-04-01T00:00:00", "2023-10-01T00:00:00", "2023.09.30"),
            "FOLD_4_FORWARD": ("2023.07.03", "2023-10-01T00:00:00", "2024-01-01T00:00:00", "2023.12.31"),
            "FINAL_SELECTION": ("2022.04.02", "2022-07-01T00:00:00", "2024-01-01T00:00:00", "2023.12.31"),
            "FORMAL_OOS": ("2023.10.03", "2024-01-01T00:00:00", "2025-01-01T00:00:00", "2024.12.31"),
            "HOLDOUT": ("2024.10.03", "2025-01-01T00:00:00", "2026-07-01T00:00:00", "2026.06.30"),
        }
        for partition, values in expected.items():
            dates = realize_partition_dates(partition)
            self.assertEqual(
                (dates["from_date"], dates["evaluation_start"],
                 dates["evaluation_end_exclusive"], dates["to_date_inclusive"]),
                values,
                partition,
            )

    def test_normal_b2_locks_forbid_all_diagnostic_or_virtual_routes(self) -> None:
        locks = normal_b2_execution_locks()
        self.assertEqual(locks["execution_adapter"], "NATIVE")
        self.assertEqual(locks["execution_mode"], 20)
        self.assertFalse(locks["diagnostic_mode"])
        self.assertFalse(locks["workload_dry_run"])
        self.assertFalse(locks["virtual_adapter_allowed"])
        self.assertTrue(locks["normal_stage13_accounting_only"])

    def test_stage14_prepares_explicit_dates_and_rejects_legacy_render_authority(self) -> None:
        hashes = {name: character * 64 for name, character in {
            "candidate": "A", "configuration": "B", "source": "C", "dataset": "D",
            "tester_ea": "E", "pipeline": "F", "accounting": "1", "calendar": "2",
            "cost": "3", "research_specification": "4", "pre_tooling": "5",
        }.items()}
        facts = {
            "run_id": "DATE-GATE-TEST", "gate": 1, "purpose": "DEVELOPMENT",
            "partition": "FOLD_1_TRAIN", "branch": "RECORDED",
            "configuration_start": 0, "configuration_end": 0,
            "scenario": "BASELINE_20MS", "seed": 0, "execution_adapter": "NATIVE",
            "execution_mode": 20, "artifact_hashes": hashes, "mt5_build": 6140,
            "account_fingerprint": "6" * 64,
            "operational_facts": {
                "calendar_intervals_file": "KingEA\\research_inputs\\calendar.csv",
                "calendar_file_sha256": "2" * 64,
                "commission_per_lot_round_turn": 1.0, "swap_per_lot_stress": 0.5,
                "weekend_risk_multiplier": 0.5, "maintenance_entry_block_minutes": 30,
                "maintenance_force_flat_minutes": 5, "maintenance_clean_minutes": 15,
            },
        }
        coordinator = ResearchRunCoordinator()
        manifest = coordinator.prepare_child(facts)
        authorization = {"owner_approved": True, "gate": 1,
                         "root_sha256": manifest["root_sha256"],
                         "child_sha256": manifest["manifest_sha256"]}
        self.assertEqual("2021-07-01T00:00:00", manifest["evaluation_start"])
        self.assertEqual("2023-01-01T00:00:00", manifest["evaluation_end_exclusive"])
        self.assertEqual("2021.04.01", manifest["from_date"])
        self.assertEqual("2022.12.31", manifest["to_date_inclusive"])
        with self.assertRaisesRegex(
            ValueError, "SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED"
        ):
            coordinator.render_bundle(manifest, authorization)
        with self.assertRaises(Stage14Error):
            coordinator.prepare_child(dict(facts, scenario="SPREAD_2X",
                                           execution_adapter="VIRTUAL", execution_mode=0))

    def test_tester_has_a_route_gate_before_order_or_completion_paths(self) -> None:
        source = (Path(__file__).parents[1] / "MQL5" / "Experts" / "KingEA" /
                  "GuardedResearchTester.mq5").read_text(encoding="utf-8")
        self.assertIn('input string InpEvaluationStart="";', source)
        self.assertIn('input string InpEvaluationEndExclusive="";', source)
        self.assertIn("if(!ResearchEvaluationEligible(evaluation_time))", source)
        self.assertLess(source.index("if(!ResearchEvaluationEligible(evaluation_time))"),
                        source.index("ResearchOpen(intent,tick);"))
        self.assertIn("if(g_evaluation_end_unresolved)\n      return -1.0;", source)
        self.assertIn("ResearchTerminalEndHasUnresolvedExposure", source)
        on_tester = source[source.index("double OnTester()") :]
        # Adopted normal-pre-end precedence: reconcile authenticated normal close
        # before considering a boundary. The unresolved gate still precedes any
        # Candidate completion, and the normal-ready predicate must fail closed.
        self.assertLess(on_tester.index("ResearchFinalizeClosedTrade();"),
                        on_tester.index("ResearchNativeBoundaryFinalize();"))
        native = (Path(__file__).parents[1] / "MQL5" / "Include" / "KingEA" /
                  "GuardedNativeCostIntegration.mqh").read_text(encoding="utf-8")
        self.assertIn("!g_da.invalid&&!g_da.pending&&!g_da.projected", native)
        self.assertIn("g_da.exposure==DA_FLAT&&g_native_exit_pending", native)
        self.assertLess(on_tester.index("ResearchTerminalEndHasUnresolvedExposure()"),
                        on_tester.index("KINGEA_STAGE13_ACCOUNTING_COMPLETE"))

    def test_native_20ms_route_cannot_enter_virtual_delay_queue(self) -> None:
        root = Path(__file__).parents[1]
        execution = (root / "MQL5" / "Include" / "KingEA" /
                     "ResearchExecution.mqh").read_text(encoding="utf-8")
        tester = (root / "MQL5" / "Experts" / "KingEA" /
                  "GuardedResearchTester.mq5").read_text(encoding="utf-8")
        native_branch = execution.index("if(adapter==KINGEA_RESEARCH_ADAPTER_NATIVE)")
        delay_branch = execution.index("if(stress.delay_ms>0)")
        self.assertLess(native_branch, delay_branch)
        self.assertIn("route.outcome=KINGEA_RESEARCH_NATIVE_ORDER_REQUIRED", execution[native_branch:delay_branch])
        pending_function = tester[tester.index("void ResearchProcessVirtualPending"):
                                  tester.index("void ResearchEvaluateClosedBar")]
        self.assertIn("if(!ResearchUsesVirtual() || !g_virtual_pending)", pending_function)


if __name__ == "__main__":
    unittest.main()
