import csv
import io
import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from research_pipeline.stage14 import ResearchRunCoordinator, Stage14Error


class Stage14CoordinatorTests(unittest.TestCase):
    def setUp(self):
        self.coordinator = ResearchRunCoordinator()
        self.hashes = {
            name: character * 64
            for name, character in {
                "candidate": "A",
                "configuration": "B",
                "source": "C",
                "dataset": "D",
                "tester_ea": "E",
                "pipeline": "F",
                "accounting": "1",
                "calendar": "2",
                "cost": "3",
                "research_specification": "4",
                "pre_tooling": "5",
            }.items()
        }
        self.operational = {
            "calendar_intervals_file": "KingEA\\research_inputs\\calendar.csv",
            "calendar_file_sha256": "2" * 64,
            "commission_per_lot_round_turn": 1.25,
            "swap_per_lot_stress": 0.50,
            "weekend_risk_multiplier": 0.50,
            "maintenance_entry_block_minutes": 30,
            "maintenance_force_flat_minutes": 5,
            "maintenance_clean_minutes": 15,
        }

    def child_facts(self):
        return {
            "run_id": "G1-F1-REC-00000-00999",
            "gate": 1,
            "purpose": "DEVELOPMENT",
            "partition": "FOLD_1_TRAIN",
            "branch": "RECORDED",
            "configuration_start": 0,
            "configuration_end": 999,
            "scenario": "BASELINE_20MS",
            "seed": 0,
            "execution_adapter": "NATIVE",
            "execution_mode": 20,
            "artifact_hashes": self.hashes,
            "mt5_build": 5602,
            "account_fingerprint": "6" * 64,
            "operational_facts": self.operational,
        }

    def test_manifest_v2_drives_exact_native_bundle_and_requires_gate_authorization(self):
        manifest = self.coordinator.prepare_child(self.child_facts())
        self.assertEqual(manifest["schema"], 2)
        self.assertEqual(len(manifest["expected_frame_ids"]), 1000)
        self.assertEqual(manifest["status"], "PLANNED")

        denied = self.coordinator.authorize(manifest, None)
        self.assertEqual(denied["reason"], "OWNER_GATE_AUTHORIZATION_REQUIRED")
        authorization = {
            "owner_approved": True,
            "gate": 1,
            "root_sha256": manifest["root_sha256"],
            "child_sha256": manifest["manifest_sha256"],
        }
        self.assertTrue(self.coordinator.authorize(manifest, authorization)["allowed"])

        bundle = self.coordinator.render_bundle(manifest, authorization)
        self.assertIn("ExecutionMode=20", bundle["ini"])
        self.assertIn("Model=4", bundle["ini"])
        self.assertIn("UseRemote=0", bundle["ini"])
        self.assertIn("InpExecutionAdapter=NATIVE", bundle["set"])
        self.assertIn("InpScenario=BASELINE_20MS", bundle["set"])
        self.assertIn("InpCommissionPerLotRoundTurn=1.25", bundle["set"])
        self.assertIn("InpCalendarIntervalsFile=KingEA\\research_inputs\\calendar.csv", bundle["set"])
        self.coordinator.verify_bundle(manifest, authorization, bundle)
        with self.assertRaises(Stage14Error):
            self.coordinator.verify_bundle(
                manifest,
                authorization,
                {"ini": bundle["ini"].replace("ExecutionMode=20", "ExecutionMode=100"), "set": bundle["set"]},
            )

    def test_complete_frames_are_append_only_and_finalize_deterministically(self):
        facts = self.child_facts()
        facts["configuration_end"] = 1
        manifest = self.coordinator.prepare_child(facts)
        with tempfile.TemporaryDirectory() as directory:
            spool = Path(directory)
            second = {"frame_id": manifest["expected_frame_ids"][1], "payload": {"configuration_id": 1, "complete": 1}}
            first = {"frame_id": manifest["expected_frame_ids"][0], "payload": {"configuration_id": 0, "complete": 1}}
            self.coordinator.append_frame(spool, manifest, second)
            self.coordinator.append_frame(spool, manifest, first)
            # Identical replay is idempotent; conflicting replay is forbidden.
            self.coordinator.append_frame(spool, manifest, first)
            with self.assertRaises(Stage14Error):
                self.coordinator.append_frame(
                    spool,
                    manifest,
                    {"frame_id": first["frame_id"], "payload": {"configuration_id": 0, "complete": 0}},
                )
            finalized = self.coordinator.finalize_frames(spool, manifest)
            self.assertEqual(finalized["status"], "COMPLETE")
            self.assertEqual([row["configuration_id"] for row in finalized["frames"]], [0, 1])
            with self.assertRaises(Stage14Error):
                self.coordinator.append_frame(
                    spool,
                    manifest,
                    {"frame_id": "LATE", "payload": {"configuration_id": 9, "complete": 1}},
                )

    def test_pace_control_uses_slower_rate_and_pauses_after_three_bad_checkpoints(self):
        benchmark_root = self.coordinator.prepare_benchmark_root(
            {
                "artifact_hashes": self.hashes,
                "mt5_build": 5602,
                "account_fingerprint": "6" * 64,
                "operational_facts": self.operational,
            },
            sample_passes_per_branch=100,
        )
        self.assertEqual(benchmark_root["pass_count"], 200)
        self.assertEqual(benchmark_root["partition"], "FINAL_SELECTION")
        self.assertEqual(benchmark_root["signals"], 0)
        self.assertEqual(benchmark_root["candidate_budget_consumed"], 0)
        native_bundle = self.coordinator.render_benchmark_bundle(
            benchmark_root, branch="RECORDED"
        )
        self.assertIn("ResearchThroughputBenchmark.ex5", native_bundle["ini"])
        self.assertIn("Model=4", native_bundle["ini"])
        self.assertIn("ExecutionMode=20", native_bundle["ini"])
        self.assertIn("InpExpectedServerFragment=JustMarkets-Demo2", native_bundle["set"])
        self.assertIn("InpBenchmarkPassId=0||0||1||99||Y", native_bundle["set"])

        benchmark = self.coordinator.evaluate_benchmark(
            valid_passes=1000,
            elapsed_seconds=3600,
            local_agents=4,
            projected_passes=194_400,
            available_disk_bytes=100_000_000,
            average_frame_bytes=100,
        )
        self.assertTrue(benchmark["passed"])
        history = []
        for hour in range(1, 4):
            history.append(
                {
                    "at": f"2026-08-02T{hour:02d}:00:00+00:00",
                    "valid_passes": hour * 100,
                    "active_elapsed_seconds": hour * 3600,
                    "trailing_six_hour_rate": 0.02,
                    "available_disk_bytes": 10_000_000,
                    "average_frame_bytes": 100,
                }
            )
        decision = self.coordinator.evaluate_pace(benchmark, history, total_passes=194_400)
        self.assertEqual(decision["action"], "PAUSE")
        self.assertIn("PERSISTENT_THROUGHPUT_DEGRADATION", decision["reasons"])

    def test_combined_signal_has_exactly_one_outcome_without_double_counting(self):
        seeded = self.coordinator.combined_outcome(
            signal_id="SIG-A",
            seed=7,
            missed_fraction=1.0,
            signal_time_msc=1_000,
            next_tick_time_msc=1_700,
            next_m30_boundary_msc=1_800_000,
            gates_healthy=True,
            execution_healthy=True,
        )
        self.assertEqual(seeded["outcome"], "SEEDED_MISS")
        self.assertFalse(seeded["enqueued"])
        expired = self.coordinator.combined_outcome(
            signal_id="SIG-B",
            seed=7,
            missed_fraction=0.0,
            signal_time_msc=1_799_700,
            next_tick_time_msc=1_800_000,
            next_m30_boundary_msc=1_800_000,
            gates_healthy=True,
            execution_healthy=True,
        )
        self.assertEqual(expired["outcome"], "DELAY_EXPIRY")
        self.assertFalse(expired["seeded_miss"])
        rejected = self.coordinator.combined_outcome(
            signal_id="SIG-C",
            seed=7,
            missed_fraction=0.0,
            signal_time_msc=1_000,
            next_tick_time_msc=1_600,
            next_m30_boundary_msc=1_800_000,
            gates_healthy=False,
            execution_healthy=True,
        )
        self.assertEqual(rejected["outcome"], "GATE_REJECT_AFTER_DELAY")

    def test_calendar_snapshot_and_market_boundaries_fail_closed(self):
        header = "schema,event_id,value_id,time,time_msc,importance,event_type,sector,time_mode,country_id,name,source_url\n"
        raw_rows = [
            ("1", "FOMC Interest Rate Decision"),
            ("2", "Consumer Price Index CPI"),
            ("3", "Core PCE Price Index"),
            ("4", "Nonfarm Payroll Report"),
            ("5", "Gross Domestic Product GDP"),
        ]
        raw = header + "".join(
            f"1,{event_id},{event_id},2024.01.10 13:30:00,1704893400000,3,0,0,0,1,{name},https://example.invalid\n"
            for event_id, name in raw_rows
        )
        parsed = self.coordinator.parse_calendar_export(
            raw,
            start="2024-01-01T00:00:00+00:00",
            end="2024-02-01T00:00:00+00:00",
        )
        self.assertTrue(parsed["passed"])

        events = [
            {"event_id": "CPI-1", "currency": "USD", "impact": "HIGH", "category": "CPI", "time": "2024-01-10T13:30:00+00:00"},
            {"event_id": "FOMC-1", "currency": "USD", "impact": "HIGH", "category": "CENTRAL_BANK", "time": "2024-03-20T18:00:00+00:00"},
            {"event_id": "PCE-1", "currency": "USD", "impact": "HIGH", "category": "PCE", "time": "2024-04-26T12:30:00+00:00"},
            {"event_id": "NFP-1", "currency": "USD", "impact": "HIGH", "category": "EMPLOYMENT", "time": "2024-05-03T12:30:00+00:00"},
            {"event_id": "GDP-1", "currency": "USD", "impact": "HIGH", "category": "GDP", "time": "2024-06-27T12:30:00+00:00"},
        ]
        snapshot = self.coordinator.validate_calendar_snapshot(
            events,
            start="2024-01-01T00:00:00+00:00",
            end="2024-07-01T00:00:00+00:00",
            covered_months=[f"2024-{month:02d}" for month in range(1, 7)],
        )
        self.assertTrue(snapshot["passed"])
        cpi = next(interval for interval in snapshot["blackouts"] if interval["event_id"] == "CPI-1")
        self.assertEqual(cpi["start"], "2024-01-10T13:00:00+00:00")
        self.assertEqual(cpi["end"], "2024-01-10T13:45:00+00:00")
        intervals = self.coordinator.render_market_intervals(
            snapshot,
            maintenance_windows=[
                {
                    "identity": "MAINT-1",
                    "start": "2024-06-01T12:00:00+00:00",
                    "end": "2024-06-01T12:30:00+00:00",
                }
            ],
        )
        self.assertIn("KINGEA_ENTRY_BLACKOUT", intervals["csv"])
        self.assertIn("BROKER_HMR_SCHEDULED", intervals["csv"])
        interval_rows = list(csv.DictReader(io.StringIO(intervals["csv"])))
        cpi_entry = next(
            row for row in interval_rows
            if row["type"] == "KINGEA_ENTRY_BLACKOUT" and row["identity"] == "CPI-1"
        )
        cpi_hmr = next(
            row for row in interval_rows
            if row["type"] == "BROKER_HMR_SCHEDULED" and row["identity"] == "CPI-1"
        )
        self.assertEqual(
            int(datetime.fromisoformat("2024-01-10T13:00:00+00:00").timestamp() * 1000),
            int(cpi_entry["start_msc"]),
        )
        self.assertEqual(
            int(datetime.fromisoformat("2024-01-10T13:45:00+00:00").timestamp() * 1000),
            int(cpi_entry["end_msc"]),
        )
        self.assertEqual(
            int(datetime.fromisoformat("2024-01-10T13:15:00+00:00").timestamp() * 1000),
            int(cpi_hmr["start_msc"]),
        )
        self.assertEqual(
            int(datetime.fromisoformat("2024-01-10T13:35:00+00:00").timestamp() * 1000),
            int(cpi_hmr["end_msc"]),
        )
        self.assertFalse(intervals["hmr_schedule_is_hard_end"])
        self.assertEqual(
            "FRESH_BROKER_MARGIN_AND_REVERSION_FACTS_REQUIRED",
            intervals["extended_hmr_policy"],
        )
        self.assertIn("MAINTENANCE_ENTRY_BLOCK", intervals["csv"])
        self.assertIn("MAINTENANCE_FORCE_FLAT", intervals["csv"])
        self.assertIn("MAINTENANCE_RECOVERY", intervals["csv"])
        self.assertEqual(len(intervals["file_sha256"]), 64)
        with self.assertRaises(Stage14Error):
            self.coordinator.validate_calendar_snapshot(events, start="2024-01-01T00:00:00+00:00", end="2024-07-01T00:00:00+00:00", covered_months=["2024-01"])

        maintenance = self.coordinator.market_protection(
            now="2024-06-01T11:30:00+00:00",
            maintenance_start="2024-06-01T12:00:00+00:00",
            maintenance_end="2024-06-01T12:30:00+00:00",
            clean_since=None,
        )
        self.assertEqual(maintenance["entry"], "BLOCK")
        self.assertEqual(maintenance["exposure"], "HOLD")
        force_flat = self.coordinator.market_protection(
            now="2024-06-01T11:55:00+00:00",
            maintenance_start="2024-06-01T12:00:00+00:00",
            maintenance_end="2024-06-01T12:30:00+00:00",
            clean_since=None,
        )
        self.assertEqual(force_flat["exposure"], "FLATTEN")
        recovery = self.coordinator.market_protection(
            now="2024-06-01T12:45:00+00:00",
            maintenance_start="2024-06-01T12:00:00+00:00",
            maintenance_end="2024-06-01T12:30:00+00:00",
            clean_since="2024-06-01T12:30:00+00:00",
        )
        self.assertEqual(recovery["entry"], "ALLOW")

        extended_hmr = self.coordinator.classify_hmr_observation(
            scheduled_active=False,
            broker_hmr_active=True,
            fresh_margin_facts=True,
            reversion_confirmed=False,
        )
        self.assertEqual("EXTENDED_OR_UNSCHEDULED_HMR", extended_hmr["classification"])
        self.assertEqual("BLOCK", extended_hmr["entry"])
        self.assertTrue(extended_hmr["apply_hmr_proxy"])
        unproven_reversion = self.coordinator.classify_hmr_observation(
            scheduled_active=False,
            broker_hmr_active=False,
            fresh_margin_facts=False,
            reversion_confirmed=False,
        )
        self.assertEqual("HMR_REVERSION_UNPROVEN", unproven_reversion["classification"])
        self.assertEqual("BLOCK", unproven_reversion["entry"])
        cleared = self.coordinator.classify_hmr_observation(
            scheduled_active=False,
            broker_hmr_active=False,
            fresh_margin_facts=True,
            reversion_confirmed=True,
        )
        self.assertEqual("NORMAL_MARGIN_CONFIRMED", cleared["classification"])
        self.assertEqual("ALLOW", cleared["entry"])

    def test_research_spec_never_assumes_zero_cost_without_broker_evidence(self):
        valid = {
            "server": "JustMarkets-Demo2",
            "symbol": "ETHUSD.s",
            "captured_at": "2026-08-02T00:00:00+00:00",
            "specification_hash": "A" * 64,
            "deal_evidence_hash": "B" * 64,
            "commission_per_lot_round_turn": 0.0,
            "commission_zero_evidence": True,
            "swap_mode": "POINTS",
            "swap_long": -1.0,
            "swap_short": -1.0,
            "hmr_proxy_leverage": 200,
        }
        self.assertTrue(self.coordinator.validate_research_specification(valid)["passed"])
        with self.assertRaises(Stage14Error):
            self.coordinator.validate_research_specification(
                dict(valid, commission_zero_evidence=False)
            )

    def test_research_capture_reuses_and_reconciles_verified_collectors(self):
        specification = "\n".join(
            [
                "key,value",
                "server,JustMarkets-Demo2",
                "symbol_id,ETHUSD.s",
                "observed_server_time,2026.08.02 12:41:34",
                "specification_hash," + "A" * 64,
                "digits,2", "point,0.01", "tick_size,0.01",
                "tick_value,0.01", "tick_value_profit,0.01", "tick_value_loss,0.01",
                "contract_size,1", "calc_mode,2", "volume_min,0.01",
                "volume_max,100", "volume_step,0.01", "volume_limit,0",
                "stops_level,0", "freeze_level,0", "margin_initial,0",
                "margin_maintenance,0", "margin_hedged,1",
                "margin_rate_buy,0.002", "margin_rate_sell,0.002",
                "session_count,1", "session_0,300-86400",
                "tick_probe_reported,0.01", "tick_probe_calculated,0.01",
                "live_margin_per_lot,4", "hmr_proxy_margin_per_lot,9.35",
                "stressed_margin_level_percent,10695", "stressed_free_margin_ratio,0.99065",
                "order_capability,PROHIBITED_AND_ABSENT",
                "performance_authorization,DENIED",
            ]
        )
        feasibility_rows = [
            ("account", "server", "JustMarkets-Demo2"),
            ("account", "leverage", "500"),
            ("account", "balance_snapshot", "1000"),
            ("account", "equity_snapshot", "1000"),
            ("symbol", "digits", "2"), ("symbol", "point", "0.01"),
            ("symbol", "tick_size", "0.01"), ("symbol", "tick_value", "0.01"),
            ("symbol", "tick_value_profit", "0.01"), ("symbol", "tick_value_loss", "0.01"),
            ("symbol", "contract_size", "1"), ("symbol", "calc_mode", "2"),
            ("symbol", "volume_min", "0.01"), ("symbol", "volume_max", "100"),
            ("symbol", "volume_step", "0.01"), ("symbol", "volume_limit", "0"),
            ("symbol", "stops_level", "0"), ("symbol", "freeze_level", "0"),
            ("symbol", "margin_initial", "0"), ("symbol", "margin_maintenance", "0"),
            ("symbol", "margin_hedged", "1"), ("symbol", "swap_mode", "1"),
            ("symbol", "swap_long", "-280.56"), ("symbol", "swap_short", "-184.08"),
            ("margin_rate", "buy_initial_rate", "0.002"),
            ("margin_rate", "sell_initial_rate", "0.002"),
            ("trade_session", "SUNDAY_0_from", "00:05"),
            ("trade_session", "SUNDAY_0_to", "00:00"),
        ]
        feasibility = "snapshot_utc,snapshot_server,label,section,key,value,unit,notes\n" + "\n".join(
            f"2026.08.02 09:46:10,2026.08.02 12:46:10,NORMAL,{section},{key},{value},,"
            for section, key, value in feasibility_rows
        )
        accounting = "\n".join(
            [
                "record_type,account_fingerprint,server,time_msc,ticket,related_order,position_id,type,entry,reason,symbol,volume,price,stop_loss,take_profit,profit,commission,swap,fee,magic,comment",
                "DEAL," + "B" * 64 + ",JustMarkets-Demo2,1,1,1,9,0,0,0,ETHUSD.s,0.01,1000,0,0,0,0,0,0,0,",
                "DEAL," + "B" * 64 + ",JustMarkets-Demo2,2,2,2,9,1,1,0,ETHUSD.s,0.01,1001,0,0,0,0,0,0,0,",
            ]
        )
        result = self.coordinator.reconcile_research_capture(
            specification,
            feasibility,
            accounting,
            specification_file_sha256="C" * 64,
            feasibility_file_sha256="D" * 64,
            accounting_file_sha256="E" * 64,
            hmr_document_sha256="F" * 64,
            hmr_proxy_leverage=200,
        )
        self.assertTrue(result["passed"])
        self.assertEqual(0.0, result["commission_per_lot_round_turn"])
        self.assertEqual(2.8056, result["swap_per_lot_day_worst"])
        self.assertEqual("REUSED_STAGE8_PREFREEZE_STAGE13", result["collector_contract"])
        self.assertEqual(0.01, result["stressed_margin_basis"]["volume_lots"])
        self.assertEqual(9.35, result["stressed_margin_basis"]["hmr_proxy_margin_per_lot"])
        self.assertEqual(0.0935, result["stressed_margin_basis"]["margin_used"])
        self.assertEqual(
            "MAX_OF_LIVE_ORDERCALCMARGIN_AND_1_TO_200_PROXY",
            result["stressed_margin_basis"]["calculation_rule"],
        )

    def test_pre_tooling_manifest_detects_any_post_tooling_source_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.py"
            source.write_text("original\n", encoding="utf-8")
            manifest = self.coordinator.create_pre_tooling_manifest(
                [source], build_id="KINGEA-STAGE14-20260802-A", dependency_hashes={"candidate": "A" * 64}
            )
            self.assertTrue(self.coordinator.verify_pre_tooling_manifest(manifest)["passed"])
            source.write_text("changed\n", encoding="utf-8")
            self.assertFalse(self.coordinator.verify_pre_tooling_manifest(manifest)["passed"])

    def test_three_gate_roots_have_locked_cardinality_and_never_include_holdout(self):
        common = {
            "artifact_hashes": self.hashes,
            "mt5_build": 5602,
            "account_fingerprint": "6" * 64,
            "operational_facts": self.operational,
        }
        gate1 = self.coordinator.prepare_gate_root(1, common)
        self.assertEqual(gate1["launch_count"], 200)
        self.assertEqual(gate1["configuration_pass_count"], 194_400)
        self.assertFalse(gate1["owner_approved"])
        self.assertNotIn("HOLDOUT", json.dumps(gate1))
        gate1_children = self.coordinator.materialize_children(gate1)
        self.assertEqual(len(gate1_children), 200)
        self.assertTrue(all(child["root_sha256"] == gate1["root_sha256"] for child in gate1_children))

        selected = {f"FOLD_{index}": index for index in range(1, 5)}
        gate2 = self.coordinator.prepare_gate_root(
            2, common, upstream_root_sha256=gate1["root_sha256"], selections=selected
        )
        self.assertEqual(gate2["launch_count"], 8)
        self.assertNotIn("HOLDOUT", json.dumps(gate2))

        gate3 = self.coordinator.prepare_gate_root(
            3,
            common,
            upstream_root_sha256=gate2["root_sha256"],
            final_configuration_id=123,
            selection_sha256="7" * 64,
            surface_sha256="8" * 64,
        )
        self.assertEqual(gate3["scenario_runs_per_branch"], 312)
        self.assertEqual(gate3["launch_count"], 624)
        self.assertNotIn("HOLDOUT", json.dumps(gate3))


if __name__ == "__main__":
    unittest.main()
