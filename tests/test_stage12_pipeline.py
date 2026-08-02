import math
import unittest

from research_pipeline.stage12 import Stage12Pipeline


class Stage12PipelineTests(unittest.TestCase):
    def test_frozen_grid_ids_are_bijective_and_use_the_locked_order(self):
        pipeline = Stage12Pipeline()

        self.assertEqual(pipeline.configuration_count, 19_440)
        self.assertEqual(pipeline.encode_configuration(pipeline.decode_configuration(0)), 0)
        self.assertEqual(
            pipeline.encode_configuration(pipeline.decode_configuration(19_439)),
            19_439,
        )
        self.assertEqual(
            pipeline.decode_configuration(1)["maximum_holding_bars"], 72
        )
        self.assertEqual(
            pipeline.decode_configuration(3)["required_progress_r"], 0.5
        )
        self.assertEqual(
            len(
                {
                    tuple(config.items())
                    for config in (
                        pipeline.decode_configuration(identifier)
                        for identifier in range(pipeline.configuration_count)
                    )
                }
            ),
            pipeline.configuration_count,
        )

    def test_scores_percentiles_inside_each_branch_and_uses_the_lower_score(self):
        pipeline = Stage12Pipeline()
        rows = []
        for branch, scale in (("RECORDED", 1.0), ("RSB3", 100.0)):
            for configuration_id, factor in enumerate((1.0, 2.0, 3.0)):
                rows.append(
                    {
                        "configuration_id": configuration_id,
                        "branch": branch,
                        "valid": True,
                        "mar": scale * factor,
                        "sortino": scale * factor,
                        "profit_factor": scale * factor,
                        "expectancy_lcb": scale * factor,
                        "trade_count": (25, 75, 150)[configuration_id],
                        "max_drawdown_percent": 10.0,
                    }
                )

        scored = pipeline.score_configurations(rows)

        middle = next(row for row in scored if row["configuration_id"] == 1)
        expected = 0.45 + 0.10 * math.sqrt(75 / 150)
        self.assertAlmostEqual(middle["branch_scores"]["RECORDED"], expected)
        self.assertAlmostEqual(middle["branch_scores"]["RSB3"], expected)
        self.assertAlmostEqual(middle["governing_score"], expected)

    def test_neighborhood_includes_interactions_and_trade_floor_is_per_branch(self):
        pipeline = Stage12Pipeline()
        default_id = pipeline.encode_configuration(
            {
                "supertrend_atr_period": 14,
                "supertrend_multiplier": 3.0,
                "breakout_lookback_bars": 12,
                "entry_buffer_atr": 0.1,
                "stop_buffer_atr": 0.25,
                "progress_checkpoint_bars": 12,
                "required_progress_r": 0.5,
                "maximum_holding_bars": 72,
            }
        )

        self.assertEqual(len(pipeline.neighbor_ids(default_id)), 6_560)
        self.assertEqual(len(pipeline.neighbor_ids(0)), 255)
        self.assertTrue(
            pipeline.validate_branch_trade_floor(
                {"RECORDED": 150, "RSB3": 150}, holdout_counts={"RECORDED": 999}
            )["passed"]
        )
        failed = pipeline.validate_branch_trade_floor(
            {"RECORDED": 300, "RSB3": 149}, holdout_counts={"RSB3": 10_000}
        )
        self.assertFalse(failed["passed"])
        self.assertEqual(failed["failed_branches"], ["RSB3"])

    def test_manifest_is_content_addressed_and_execution_is_separately_authorized(self):
        pipeline = Stage12Pipeline()
        facts = {
            "run_id": "DEV-F1-REC-00000-00999",
            "purpose": "DEVELOPMENT",
            "partition": "FOLD_1_TRAIN",
            "branch": "RECORDED",
            "configuration_ids": list(range(1000)),
            "artifact_hashes": {
                "candidate": "1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06",
                "configuration": "A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE",
                "source": "4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83",
                "dataset": "2C64105609D143C20420B9E33D8A458DFFF7158CEA894C41D31EE16474147206",
                "calendar": "D" * 64,
                "cost": "E" * 64,
                "specification": "F" * 64,
            },
            "mt5_build": 5602,
            "account_fingerprint": "1" * 64,
            "scenario": "BASELINE_20MS",
            "seed": 0,
        }
        manifest = pipeline.plan_run(facts)
        self.assertEqual(manifest["status"], "PLANNED")
        self.assertEqual(manifest["start_inclusive"], "2021-07-01T00:00:00")
        self.assertEqual(manifest["end_exclusive"], "2023-01-01T00:00:00")
        self.assertEqual(len(manifest["manifest_sha256"]), 64)
        self.assertEqual(manifest["candidate_id"], "CAND-ETH-ST-001")
        wrong_candidate = dict(facts)
        wrong_candidate["artifact_hashes"] = dict(facts["artifact_hashes"], candidate="0" * 64)
        with self.assertRaises(ValueError):
            pipeline.plan_run(wrong_candidate)

        denied = pipeline.execution_decision("execute-development", manifest, None)
        self.assertFalse(denied["allowed"])
        authorization = {
            "scope": "DEVELOPMENT",
            "manifest_sha256": manifest["manifest_sha256"],
            "owner_approved": True,
        }
        allowed = pipeline.execution_decision(
            "execute-development", manifest, authorization
        )
        self.assertTrue(allowed["allowed"])
        tampered = dict(manifest, scenario="UNDECLARED")
        self.assertFalse(
            pipeline.execution_decision(
                "execute-development", tampered, authorization
            )["allowed"]
        )
        tester_ini = """[Tester]\nExpert=KingEA\\GuardedResearchTester.ex5\nModel=4\nOptimization=1\nUseLocal=1\nUseRemote=0\nUseCloud=0\nGenetic=0\nDeposit=1000\n"""
        self.assertTrue(pipeline.validate_tester_ini_text(tester_ini)["passed"])
        self.assertFalse(
            pipeline.validate_tester_ini_text(tester_ini.replace("UseCloud=0", "UseCloud=1"))["passed"]
        )
        bundle = pipeline.render_tester_bundle(manifest, authorization)
        self.assertIn("Model=4", bundle["ini"])
        self.assertIn("UseCloud=0", bundle["ini"])
        self.assertIn("InpConfigurationId=0||0||1||999||Y", bundle["set"])
        self.assertIn(manifest["manifest_sha256"], bundle["set"])
        oos = dict(manifest, purpose="OOS", partition="FORMAL_OOS")
        oos = pipeline.plan_run({key: value for key, value in oos.items() if key not in {"status", "start_inclusive", "end_exclusive", "manifest_sha256", "schema", "initial_equity_usd", "risk_percent"}})
        self.assertFalse(
            pipeline.execution_decision(
                "execute-oos",
                oos,
                {"scope": "OOS", "manifest_sha256": oos["manifest_sha256"], "owner_approved": True},
            )["allowed"]
        )

    def test_spread_and_news_gates_fail_closed_at_locked_boundaries(self):
        pipeline = Stage12Pipeline()
        history = [10.0] * 8
        self.assertEqual(pipeline.spread_decision(20.0, history, []), "ALLOW")
        self.assertEqual(pipeline.spread_decision(20.01, history, []), "BLOCK_ENTRY")
        self.assertEqual(pipeline.spread_decision(25.01, history, []), "REDUCE_OR_FLATTEN")
        ticks = [(1000, 30.1), (1005, 30.2), (1010, 30.3)]
        self.assertEqual(pipeline.spread_decision(30.3, history, ticks), "FLATTEN")
        self.assertEqual(pipeline.spread_decision(10.0, history[:7], []), "INVALID_BASELINE")

        event = {"currency": "USD", "impact": "HIGH", "time": 10_000}
        self.assertEqual(pipeline.news_decision(8_200, [event], fresh=True), "BLOCK_ENTRY")
        self.assertEqual(pipeline.news_decision(10_900, [event], fresh=True), "BLOCK_ENTRY")
        self.assertEqual(pipeline.news_decision(10_901, [event], fresh=True), "ALLOW")
        self.assertEqual(pipeline.news_decision(20_000, [event], fresh=False), "INVALID_CALENDAR")

    def test_metrics_stress_and_monte_carlo_are_deterministic_and_fail_closed(self):
        pipeline = Stage12Pipeline()
        metrics = pipeline.calculate_metrics(
            trade_groups=[
                {"net_return": 0.01, "net_r": 1.0},
                {"net_return": -0.005, "net_r": -0.5},
                {"net_return": 0.02, "net_r": 2.0},
            ],
            broker_daily_returns=[0.01, 0.0, -0.005, 0.02],
        )
        self.assertEqual(metrics["trade_count"], 3)
        self.assertAlmostEqual(metrics["profit_factor"], 6.0)
        self.assertLess(metrics["expectancy_lcb"], metrics["expectancy_mean_r"])
        self.assertGreater(metrics["mar"], 0.0)

        passing = []
        stress_plan = pipeline.mandatory_stress_plan()
        self.assertEqual(stress_plan["MISSED_5_PERCENT"], 100)
        self.assertEqual(stress_plan["COMBINED"], 100)
        for branch in ("RECORDED", "RSB3"):
            for scenario, seed_count in stress_plan.items():
                for seed in range(seed_count):
                    delay = {"BASELINE_20MS": 20, "DELAY_100MS": 100, "DELAY_250MS": 250, "DELAY_500MS": 500, "RANDOM_SEVERE": 501, "COMBINED": 500}.get(scenario, -1)
                    passing.append(
                        {
                            "branch": branch,
                            "scenario": scenario,
                            "seed": seed,
                            "delay_ms": delay,
                            "profit_factor": 1.4,
                            "expectancy": 0.1,
                            "max_drawdown_percent": 10.0,
                            "in_sample_drawdown_percent": 8.0,
                        }
                    )
        self.assertTrue(pipeline.evaluate_stress(passing)["passed"])
        mild_index = next(
            index
            for index, row in enumerate(passing)
            if row["branch"] == "RECORDED" and row["scenario"] == "DELAY_100MS"
        )
        passing[mild_index] = dict(passing[mild_index], profit_factor=0.8, expectancy=-0.1)
        rejected = pipeline.evaluate_stress(passing)
        self.assertFalse(rejected["passed"])
        self.assertIn("NON_MONOTONIC_FRAGILITY:RECORDED", rejected["reasons"])

        returns = [0.01, -0.005, 0.02, -0.01, 0.015, 0.005]
        first = pipeline.monte_carlo(
            returns,
            manifest_sha256="A" * 64,
            branch="RECORDED",
            scenario="BASELINE",
            paths=100,
        )
        second = pipeline.monte_carlo(
            returns,
            manifest_sha256="A" * 64,
            branch="RECORDED",
            scenario="BASELINE",
            paths=100,
        )
        self.assertEqual(first, second)
        self.assertEqual(first["paths"], 100)
        self.assertTrue(first["passed"])

    def test_frames_neighborhood_and_tie_breaks_are_complete_and_deterministic(self):
        pipeline = Stage12Pipeline()
        frames = [
            {"configuration_id": identifier, "branch": branch, "fold": "FOLD_1"}
            for identifier in (0, 1)
            for branch in ("RECORDED", "RSB3")
        ]
        self.assertTrue(
            pipeline.validate_frames(
                frames, expected_ids=[0, 1], branches=["RECORDED", "RSB3"], folds=["FOLD_1"]
            )["passed"]
        )
        self.assertFalse(
            pipeline.validate_frames(
                frames + [dict(frames[0])],
                expected_ids=[0, 1],
                branches=["RECORDED", "RSB3"],
                folds=["FOLD_1"],
            )["passed"]
        )

        neighbors = pipeline.neighbor_ids(0)
        neighbor_rows = [
            {
                "configuration_id": identifier,
                "branch": branch,
                "expectancy": 0.1,
                "profit_factor": 1.2,
                "max_drawdown_percent": 10.0,
            }
            for identifier in neighbors
            for branch in ("RECORDED", "RSB3")
        ]
        assessment = pipeline.evaluate_neighborhood(0, neighbor_rows)
        self.assertTrue(assessment["passed"])
        neighbor_rows[0]["max_drawdown_percent"] = 20.01
        self.assertFalse(pipeline.evaluate_neighborhood(0, neighbor_rows)["passed"])

        default_id = pipeline.default_configuration_id
        selected = pipeline.select_configuration(
            [
                {"configuration_id": 0, "governing_score": 0.7, "worse_branch_drawdown_percent": 10.0},
                {"configuration_id": default_id, "governing_score": 0.7, "worse_branch_drawdown_percent": 10.0},
            ],
            {
                0: {"qualifying_fraction": 0.9},
                default_id: {"qualifying_fraction": 0.9},
            },
        )
        self.assertEqual(selected["configuration_id"], default_id)

    def test_surface_evidence_is_complete_and_hashes_all_parameter_pairs(self):
        pipeline = Stage12Pipeline()
        evidence = pipeline.build_surface_evidence(
            [
                {"configuration_id": 0, "governing_score": 0.1},
                {"configuration_id": 1, "governing_score": 0.2},
            ],
            expected_ids=[0, 1],
        )
        self.assertEqual(evidence["configuration_count"], 2)
        self.assertEqual(len(evidence["surface_sha256"]), 64)
        self.assertEqual(len(evidence["pairwise_heatmap_sha256"]), 28)
        with self.assertRaises(ValueError):
            pipeline.build_surface_evidence(
                [{"configuration_id": 0, "governing_score": 0.1}],
                expected_ids=[0, 1],
            )

if __name__ == "__main__":
    unittest.main()
