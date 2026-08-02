"""Pure deterministic Stage 12 research-pipeline module.

No function in this module collects broker data or places orders.  Callers
provide immutable facts and receive deterministic decisions or evidence.
"""

from __future__ import annotations

import hashlib
import json
import random
import re
import statistics
import configparser
import io
from datetime import datetime, timedelta
from math import ceil
from pathlib import Path
from itertools import combinations, product as cartesian_product
from math import isfinite, prod, sqrt
from typing import Any, Iterable, Mapping


class Stage12Error(ValueError):
    """A fail-closed Stage 12 contract violation."""


class Stage12Pipeline:
    """Deep interface for the guarded Stage 12 offline pipeline."""

    PARAMETER_GRIDS: tuple[tuple[str, tuple[Any, ...]], ...] = (
        ("supertrend_atr_period", (10, 14, 18, 22)),
        ("supertrend_multiplier", (2.0, 2.5, 3.0, 3.5, 4.0)),
        ("breakout_lookback_bars", (6, 12, 18, 24)),
        ("entry_buffer_atr", (0.0, 0.1, 0.2)),
        ("stop_buffer_atr", (0.0, 0.25, 0.5)),
        ("progress_checkpoint_bars", (8, 12, 16)),
        ("required_progress_r", (0.25, 0.5, 0.75)),
        ("maximum_holding_bars", (48, 72, 96)),
    )
    PARTITIONS: Mapping[str, tuple[str, str]] = {
        "FOLD_1_TRAIN": ("2021-07-01T00:00:00", "2023-01-01T00:00:00"),
        "FOLD_1_FORWARD": ("2023-01-01T00:00:00", "2023-04-01T00:00:00"),
        "FOLD_2_TRAIN": ("2021-10-01T00:00:00", "2023-04-01T00:00:00"),
        "FOLD_2_FORWARD": ("2023-04-01T00:00:00", "2023-07-01T00:00:00"),
        "FOLD_3_TRAIN": ("2022-01-01T00:00:00", "2023-07-01T00:00:00"),
        "FOLD_3_FORWARD": ("2023-07-01T00:00:00", "2023-10-01T00:00:00"),
        "FOLD_4_TRAIN": ("2022-04-01T00:00:00", "2023-10-01T00:00:00"),
        "FOLD_4_FORWARD": ("2023-10-01T00:00:00", "2024-01-01T00:00:00"),
        "FINAL_SELECTION": ("2022-07-01T00:00:00", "2024-01-01T00:00:00"),
        "FORMAL_OOS": ("2024-01-01T00:00:00", "2025-01-01T00:00:00"),
        "HOLDOUT": ("2025-01-01T00:00:00", "2026-07-01T00:00:00"),
    }
    FROZEN_HASHES: Mapping[str, str] = {
        "candidate": "1DE78BABEDAED4261D5C35BFD20DDDBC2E2B3F52D8C77FADC98A7F448A9FAE06",
        "configuration": "A60CA57CA68648F14A0486A2F9F40E4C0E968D1B87E54AB78E494D457FB084EE",
        "source": "4CE407201787EDACC61DF1DDD0E6068E56C39C97E61D93CD19B58550B7367F83",
        "dataset": "2C64105609D143C20420B9E33D8A458DFFF7158CEA894C41D31EE16474147206",
    }

    def __init__(self) -> None:
        self.configuration_count = prod(len(values) for _, values in self.PARAMETER_GRIDS)
        self.default_configuration_id = self.encode_configuration(
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

    def decode_configuration(self, identifier: int) -> dict[str, Any]:
        if isinstance(identifier, bool) or not isinstance(identifier, int):
            raise Stage12Error("CONFIGURATION_ID_INVALID")
        if not 0 <= identifier < self.configuration_count:
            raise Stage12Error("CONFIGURATION_ID_OUT_OF_RANGE")
        remaining = identifier
        result: dict[str, Any] = {}
        for name, values in reversed(self.PARAMETER_GRIDS):
            result[name] = values[remaining % len(values)]
            remaining //= len(values)
        return {name: result[name] for name, _ in self.PARAMETER_GRIDS}

    def encode_configuration(self, configuration: Mapping[str, Any]) -> int:
        if set(configuration) != {name for name, _ in self.PARAMETER_GRIDS}:
            raise Stage12Error("CONFIGURATION_FIELDS_INVALID")
        identifier = 0
        for name, values in self.PARAMETER_GRIDS:
            try:
                index = values.index(configuration[name])
            except ValueError as exc:
                raise Stage12Error(f"CONFIGURATION_OFF_GRID:{name}") from exc
            identifier = identifier * len(values) + index
        return identifier

    @staticmethod
    def _percentile_ranks(values: Mapping[int, float]) -> dict[int, float]:
        ordered = sorted(values.items(), key=lambda item: (item[1], item[0]))
        if len(ordered) == 1:
            return {ordered[0][0]: 1.0}
        ranks: dict[int, float] = {}
        position = 0
        while position < len(ordered):
            end = position + 1
            while end < len(ordered) and ordered[end][1] == ordered[position][1]:
                end += 1
            average_rank = (position + end - 1) / 2.0
            percentile = average_rank / (len(ordered) - 1)
            for offset in range(position, end):
                ranks[ordered[offset][0]] = percentile
            position = end
        return ranks

    def score_configurations(
        self, rows: Iterable[Mapping[str, Any]]
    ) -> list[dict[str, Any]]:
        materialized = [dict(row) for row in rows]
        branches = sorted({str(row.get("branch", "")) for row in materialized})
        if branches != ["RECORDED", "RSB3"]:
            raise Stage12Error("BOTH_SPREAD_BRANCHES_REQUIRED")
        metrics = ("mar", "sortino", "profit_factor", "expectancy_lcb")
        weights = {
            "mar": 0.30,
            "sortino": 0.20,
            "profit_factor": 0.20,
            "expectancy_lcb": 0.20,
        }
        branch_scores: dict[str, dict[int, float]] = {}
        drawdowns: dict[int, list[float]] = {}
        for branch in branches:
            selected = [row for row in materialized if row.get("branch") == branch]
            identifiers = [int(row["configuration_id"]) for row in selected]
            if len(identifiers) != len(set(identifiers)):
                raise Stage12Error(f"DUPLICATE_RESULT:{branch}")
            ranks_by_metric: dict[str, dict[int, float]] = {}
            valid_rows = []
            for row in selected:
                numeric = [row.get(metric) for metric in metrics]
                numeric.extend((row.get("trade_count"), row.get("max_drawdown_percent")))
                if bool(row.get("valid")) and all(
                    isinstance(value, (int, float))
                    and not isinstance(value, bool)
                    and isfinite(float(value))
                    for value in numeric
                ):
                    valid_rows.append(row)
            for metric in metrics:
                ranks_by_metric[metric] = self._percentile_ranks(
                    {
                        int(row["configuration_id"]): float(row[metric])
                        for row in valid_rows
                    }
                )
            scores: dict[int, float] = {}
            for row in selected:
                identifier = int(row["configuration_id"])
                if row not in valid_rows:
                    scores[identifier] = 0.0
                    continue
                confidence = min(sqrt(max(0.0, float(row["trade_count"])) / 150.0), 1.0)
                scores[identifier] = sum(
                    weights[metric] * ranks_by_metric[metric][identifier]
                    for metric in metrics
                ) + 0.10 * confidence
                drawdowns.setdefault(identifier, []).append(
                    float(row["max_drawdown_percent"])
                )
            branch_scores[branch] = scores
        all_identifiers = sorted(set(branch_scores["RECORDED"]) | set(branch_scores["RSB3"]))
        if set(branch_scores["RECORDED"]) != set(branch_scores["RSB3"]):
            raise Stage12Error("BRANCH_RESULT_SET_MISMATCH")
        return [
            {
                "configuration_id": identifier,
                "branch_scores": {
                    branch: branch_scores[branch][identifier] for branch in branches
                },
                "governing_score": min(
                    branch_scores[branch][identifier] for branch in branches
                ),
                "worse_branch_drawdown_percent": max(drawdowns.get(identifier, [float("inf")])),
            }
            for identifier in all_identifiers
        ]

    def neighbor_ids(self, center_identifier: int) -> tuple[int, ...]:
        center = self.decode_configuration(center_identifier)
        index_choices: list[tuple[int, ...]] = []
        center_indexes: list[int] = []
        for name, values in self.PARAMETER_GRIDS:
            center_index = values.index(center[name])
            center_indexes.append(center_index)
            index_choices.append(
                tuple(
                    index
                    for index in range(max(0, center_index - 1), min(len(values), center_index + 2))
                )
            )
        neighbors = []
        for indexes in cartesian_product(*index_choices):
            if list(indexes) == center_indexes:
                continue
            configuration = {
                name: values[index]
                for (name, values), index in zip(self.PARAMETER_GRIDS, indexes)
            }
            neighbors.append(self.encode_configuration(configuration))
        return tuple(sorted(neighbors))

    @staticmethod
    def validate_branch_trade_floor(
        qualifying_counts: Mapping[str, int],
        *,
        holdout_counts: Mapping[str, int] | None = None,
    ) -> dict[str, Any]:
        del holdout_counts  # Holdout is intentionally invisible to this gate.
        required = ("RECORDED", "RSB3")
        if set(qualifying_counts) != set(required):
            raise Stage12Error("BRANCH_TRADE_COUNTS_INCOMPLETE")
        failed = sorted(
            branch
            for branch in required
            if isinstance(qualifying_counts[branch], bool)
            or not isinstance(qualifying_counts[branch], int)
            or qualifying_counts[branch] < 150
        )
        return {
            "passed": not failed,
            "minimum_per_branch": 150,
            "failed_branches": failed,
            "holdout_excluded": True,
        }

    @staticmethod
    def _canonical_sha256(value: Mapping[str, Any]) -> str:
        encoded = json.dumps(
            value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest().upper()

    @staticmethod
    def file_sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest().upper()

    @staticmethod
    def validate_tester_ini_text(text: str) -> dict[str, Any]:
        parser = configparser.ConfigParser()
        try:
            parser.read_file(io.StringIO(text))
        except configparser.Error:
            return {"passed": False, "reason": "TESTER_CONFIG_UNPARSEABLE"}
        if "Tester" not in parser:
            return {"passed": False, "reason": "TESTER_SECTION_MISSING"}
        tester = parser["Tester"]
        required = {
            "expert": r"KingEA\GuardedResearchTester.ex5",
            "model": "4",
            "optimization": "1",
            "uselocal": "1",
            "useremote": "0",
            "usecloud": "0",
            "genetic": "0",
            "deposit": "1000",
        }
        for key, expected in required.items():
            if tester.get(key, "").strip() != expected:
                return {"passed": False, "reason": f"TESTER_CONFIG_INVALID:{key}"}
        return {"passed": True, "reason": "PASS"}

    def plan_run(self, facts: Mapping[str, Any]) -> dict[str, Any]:
        required = {
            "run_id",
            "purpose",
            "partition",
            "branch",
            "configuration_ids",
            "artifact_hashes",
            "mt5_build",
            "account_fingerprint",
            "scenario",
            "seed",
        }
        if not required.issubset(facts):
            raise Stage12Error("RUN_FACTS_INCOMPLETE")
        partition = str(facts["partition"])
        if partition not in self.PARTITIONS:
            raise Stage12Error("PARTITION_NOT_FROZEN")
        purpose = str(facts["purpose"])
        allowed_partitions = {
            "DEVELOPMENT": {name for name in self.PARTITIONS if "FOLD_" in name or name == "FINAL_SELECTION"},
            "OOS": {"FORMAL_OOS"},
            "HOLDOUT": {"HOLDOUT"},
        }
        if purpose not in allowed_partitions or partition not in allowed_partitions[purpose]:
            raise Stage12Error("PURPOSE_PARTITION_MISMATCH")
        branch = str(facts["branch"])
        if branch not in {"RECORDED", "RSB3"}:
            raise Stage12Error("BRANCH_INVALID")
        hashes = facts["artifact_hashes"]
        if set(hashes) != {
            "candidate", "configuration", "source", "dataset", "calendar", "cost", "specification"
        } or not all(re.fullmatch(r"[0-9A-Fa-f]{64}", str(value)) for value in hashes.values()):
            raise Stage12Error("ARTIFACT_HASH_SET_INVALID")
        if any(str(hashes[name]).upper() != expected for name, expected in self.FROZEN_HASHES.items()):
            raise Stage12Error("FROZEN_CANDIDATE_BINDING_MISMATCH")
        identifiers = list(facts["configuration_ids"])
        if not identifiers or len(identifiers) > 1000 or identifiers != list(range(identifiers[0], identifiers[0] + len(identifiers))):
            raise Stage12Error("CONFIGURATION_CHUNK_INVALID")
        if identifiers[0] < 0 or identifiers[-1] >= self.configuration_count:
            raise Stage12Error("CONFIGURATION_CHUNK_OUT_OF_RANGE")
        start, end = self.PARTITIONS[partition]
        manifest = dict(facts)
        manifest.update(
            {
                "schema": 1,
                "candidate_id": "CAND-ETH-ST-001",
                "status": "PLANNED",
                "start_inclusive": start,
                "end_exclusive": end,
                "initial_equity_usd": 1000.0,
                "risk_percent": 1.10,
                "expected_symbol": "ETHUSD.s" if branch == "RECORDED" else "KINGEA_ETHUSD_S_RSB3",
                "expected_artifacts": [
                    f"{facts['run_id']}.frames.jsonl",
                    f"{facts['run_id']}.result.json",
                    f"{facts['run_id']}.terminal.log",
                ],
            }
        )
        manifest["manifest_sha256"] = self._canonical_sha256(manifest)
        return manifest

    def execution_decision(
        self,
        command: str,
        manifest: Mapping[str, Any],
        authorization: Mapping[str, Any] | None,
    ) -> dict[str, Any]:
        command_scopes = {
            "execute-development": "DEVELOPMENT",
            "execute-oos": "OOS",
            "execute-holdout": "HOLDOUT",
        }
        if command not in command_scopes:
            return {"allowed": False, "reason": "COMMAND_NOT_EXECUTABLE"}
        stored_hash = str(manifest.get("manifest_sha256", ""))
        unhashed = {key: value for key, value in manifest.items() if key != "manifest_sha256"}
        if not re.fullmatch(r"[0-9A-F]{64}", stored_hash) or self._canonical_sha256(unhashed) != stored_hash:
            return {"allowed": False, "reason": "MANIFEST_HASH_MISMATCH"}
        scope = command_scopes[command]
        if manifest.get("purpose") != scope:
            return {"allowed": False, "reason": "COMMAND_PURPOSE_MISMATCH"}
        if not authorization or not bool(authorization.get("owner_approved")):
            return {"allowed": False, "reason": "DETACHED_AUTHORIZATION_REQUIRED"}
        if authorization.get("scope") != scope or authorization.get("manifest_sha256") != stored_hash:
            return {"allowed": False, "reason": "AUTHORIZATION_MISMATCH"}
        if scope == "OOS" and not all(
            re.fullmatch(r"[0-9A-F]{64}", str(manifest.get(field, "")))
            for field in ("selection_sha256", "surface_sha256")
        ):
            return {"allowed": False, "reason": "OOS_PREREQUISITES_MISSING"}
        if scope == "HOLDOUT" and not re.fullmatch(
            r"[0-9A-F]{64}", str(manifest.get("stage15_authorization_sha256", ""))
        ):
            return {"allowed": False, "reason": "STAGE15_AUTHORIZATION_REQUIRED"}
        return {"allowed": True, "reason": "AUTHORIZED", "next_status": "RUNNING"}

    def render_tester_bundle(
        self,
        manifest: Mapping[str, Any],
        authorization: Mapping[str, Any],
    ) -> dict[str, str]:
        command = f"execute-{str(manifest.get('purpose', '')).lower()}"
        decision = self.execution_decision(command, manifest, authorization)
        if not decision["allowed"]:
            raise Stage12Error(str(decision["reason"]))
        identifiers = list(manifest["configuration_ids"])
        token = hashlib.sha256(
            f"{manifest['manifest_sha256']}|{manifest['purpose']}|RUNNING".encode("utf-8")
        ).hexdigest().upper()
        start = datetime.fromisoformat(str(manifest["start_inclusive"]))
        end = datetime.fromisoformat(str(manifest["end_exclusive"]))
        tester_start = max(datetime(2021, 4, 1), start - timedelta(days=90))
        tester_end = end - timedelta(days=1)
        set_lines = [
            "; Generated only from an authorized content-addressed Stage 12 manifest.",
            f"InpRunManifest=KingEA\\runs\\{manifest['manifest_sha256']}.json",
            f"InpManifestSha256={manifest['manifest_sha256']}",
            "InpManifestFileSha256=SET_AT_EXECUTION",
            f"InpDetachedAuthorizationToken={token}",
            f"InpPurpose={manifest['purpose']}",
            f"InpPartition={manifest['partition']}",
            f"InpBranch={manifest['branch']}",
            f"InpExpectedSymbol={manifest['expected_symbol']}",
            f"InpConfigurationId={identifiers[0]}||{identifiers[0]}||1||{identifiers[-1]}||Y",
            "InpTesterModel=4",
            "InpLocalAgentsOnly=true",
            "InpRemoteAgentsDisabled=true",
            "InpCloudAgentsDisabled=true",
            f"InpSelectionSha256={manifest.get('selection_sha256', '')}",
            f"InpSurfaceSha256={manifest.get('surface_sha256', '')}",
            f"InpStage15AuthorizationSha256={manifest.get('stage15_authorization_sha256', '')}",
        ]
        ini_lines = [
            "[Tester]",
            r"Expert=KingEA\GuardedResearchTester.ex5",
            f"ExpertParameters={manifest['manifest_sha256']}.set",
            f"Symbol={manifest['expected_symbol']}",
            "Period=M30",
            "Model=4",
            "Optimization=1",
            "UseLocal=1",
            "UseRemote=0",
            "UseCloud=0",
            "Genetic=0",
            "Deposit=1000",
            "Currency=USD",
            f"FromDate={tester_start:%Y.%m.%d}",
            f"ToDate={tester_end:%Y.%m.%d}",
            "ShutdownTerminal=1",
        ]
        return {"set": "\n".join(set_lines) + "\n", "ini": "\n".join(ini_lines) + "\n"}

    @staticmethod
    def spread_decision(
        current_spread: float,
        historical_slot_spreads: Iterable[float],
        recent_above_three_ticks: Iterable[tuple[int, float]],
    ) -> str:
        history = [float(value) for value in historical_slot_spreads]
        if (
            len(history) < 8
            or not isfinite(float(current_spread))
            or current_spread < 0.0
            or any(not isfinite(value) or value <= 0.0 for value in history)
        ):
            return "INVALID_BASELINE"
        baseline = statistics.median(history)
        ratio = float(current_spread) / baseline
        ticks = [(int(timestamp), float(spread)) for timestamp, spread in recent_above_three_ticks]
        persistent = (
            len(ticks) >= 3
            and len({timestamp for timestamp, _ in ticks}) >= 3
            and max(timestamp for timestamp, _ in ticks) - min(timestamp for timestamp, _ in ticks) >= 10
            and all(spread / baseline > 3.0 for _, spread in ticks)
        )
        if ratio > 3.0 and persistent:
            return "FLATTEN"
        if ratio > 2.5:
            return "REDUCE_OR_FLATTEN"
        if ratio > 2.0:
            return "BLOCK_ENTRY"
        return "ALLOW"

    @staticmethod
    def news_decision(
        now_server: int, events: Iterable[Mapping[str, Any]], *, fresh: bool
    ) -> str:
        materialized = list(events)
        if not fresh:
            return "INVALID_CALENDAR"
        for event in materialized:
            if not {"currency", "impact", "time"}.issubset(event):
                return "INVALID_CALENDAR"
            if not isinstance(event["time"], int) or event["time"] <= 0:
                return "INVALID_CALENDAR"
            if event["currency"] == "USD" and event["impact"] == "HIGH":
                if event["time"] - 1800 <= now_server <= event["time"] + 900:
                    return "BLOCK_ENTRY"
        return "ALLOW"

    @staticmethod
    def _maximum_drawdown_percent(returns: Iterable[float]) -> float:
        equity = 1000.0
        high = equity
        maximum = 0.0
        for value in returns:
            equity *= 1.0 + float(value)
            high = max(high, equity)
            maximum = max(maximum, (high - equity) / high * 100.0)
        return maximum

    @staticmethod
    def calculate_metrics(
        *,
        trade_groups: Iterable[Mapping[str, float]],
        broker_daily_returns: Iterable[float],
    ) -> dict[str, float | int]:
        trades = [dict(trade) for trade in trade_groups]
        days = [float(value) for value in broker_daily_returns]
        if not trades or not days:
            raise Stage12Error("METRIC_SAMPLE_EMPTY")
        net_returns = [float(trade["net_return"]) for trade in trades]
        net_r = [float(trade["net_r"]) for trade in trades]
        if any(not isfinite(value) or value <= -1.0 for value in net_returns + days):
            raise Stage12Error("METRIC_RETURN_INVALID")
        if any(not isfinite(value) for value in net_r):
            raise Stage12Error("METRIC_R_INVALID")
        gains = sum(value for value in net_returns if value > 0.0)
        losses = -sum(value for value in net_returns if value < 0.0)
        profit_factor = gains / losses if losses > 0.0 else float("inf")
        expectancy_mean = statistics.fmean(net_r)
        sample_sd = statistics.stdev(net_r) if len(net_r) > 1 else 0.0
        expectancy_lcb = expectancy_mean - 1.645 * sample_sd / sqrt(len(net_r))
        compounded = prod(1.0 + value for value in days)
        annualized = compounded ** (365.0 / len(days)) - 1.0
        maximum_drawdown = Stage12Pipeline._maximum_drawdown_percent(net_returns)
        mar = annualized / (maximum_drawdown / 100.0) if maximum_drawdown > 0.0 else float("inf")
        downside = sqrt(statistics.fmean(min(value, 0.0) ** 2 for value in days))
        sortino = statistics.fmean(days) / downside * sqrt(365.0) if downside > 0.0 else float("inf")
        return {
            "trade_count": len(trades),
            "mar": mar,
            "sortino": sortino,
            "profit_factor": profit_factor,
            "expectancy_mean_r": expectancy_mean,
            "expectancy_lcb": expectancy_lcb,
            "max_drawdown_percent": maximum_drawdown,
            "ending_equity": 1000.0 * compounded,
        }

    @staticmethod
    def _nearest_rank(values: Iterable[float], percentile: float) -> float:
        ordered = sorted(float(value) for value in values)
        if not ordered or not 0.0 < percentile <= 1.0:
            raise Stage12Error("PERCENTILE_INPUT_INVALID")
        return ordered[max(0, ceil(percentile * len(ordered)) - 1)]

    @staticmethod
    def mandatory_stress_plan() -> dict[str, int]:
        return {
            "BASELINE_20MS": 1,
            "DELAY_100MS": 1,
            "DELAY_250MS": 1,
            "DELAY_500MS": 1,
            "RANDOM_SEVERE": 1,
            "SPREAD_2X": 1,
            "SPREAD_2_5X": 1,
            "SPREAD_3X": 1,
            "COST_1_3X": 1,
            "SLIPPAGE_NORMAL_0_25X": 1,
            "SLIPPAGE_HIGH_0_5X": 1,
            "SLIPPAGE_EXTREME_1X": 1,
            "MISSED_5_PERCENT": 100,
            "MISSED_10_PERCENT": 100,
            "COMBINED": 100,
        }

    @classmethod
    def evaluate_stress(cls, rows: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
        materialized = [dict(row) for row in rows]
        branches = {str(row.get("branch")) for row in materialized}
        reasons: list[str] = []
        summaries: dict[str, dict[str, dict[str, float]]] = {}
        if branches != {"RECORDED", "RSB3"}:
            reasons.append("BOTH_BRANCHES_REQUIRED")
        plan = cls.mandatory_stress_plan()
        for branch in ("RECORDED", "RSB3"):
            summaries[branch] = {}
            for scenario, expected_count in plan.items():
                group = [
                    row
                    for row in materialized
                    if row.get("branch") == branch and row.get("scenario") == scenario
                ]
                seeds = [row.get("seed") for row in group]
                if len(group) != expected_count or set(seeds) != set(range(expected_count)):
                    reasons.append(f"STRESS_CARDINALITY_FAIL:{branch}:{scenario}")
                    continue
                try:
                    profit_factors = [float(row["profit_factor"]) for row in group]
                    expectancies = [float(row["expectancy"]) for row in group]
                    drawdowns = [float(row["max_drawdown_percent"]) for row in group]
                    in_samples = [float(row["in_sample_drawdown_percent"]) for row in group]
                except (KeyError, TypeError, ValueError):
                    reasons.append(f"STRESS_ROW_INVALID:{branch}:{scenario}")
                    continue
                values = profit_factors + expectancies + drawdowns + in_samples
                if any(not isfinite(value) for value in values) or any(value < 0.0 for value in drawdowns + in_samples):
                    reasons.append(f"STRESS_ROW_INVALID:{branch}:{scenario}")
                    continue
                summary = {
                    "profit_factor_p05": cls._nearest_rank(profit_factors, 0.05),
                    "expectancy_p05": cls._nearest_rank(expectancies, 0.05),
                    "drawdown_p95": cls._nearest_rank(drawdowns, 0.95),
                    "in_sample_drawdown": min(in_samples),
                    "delay_ms": float(group[0].get("delay_ms", -1)),
                }
                summaries[branch][scenario] = summary
                if (
                    summary["expectancy_p05"] <= 0.0
                    or summary["profit_factor_p05"] < 1.30
                    or summary["drawdown_p95"] >= 20.0
                    or summary["drawdown_p95"] > 1.5 * summary["in_sample_drawdown"]
                ):
                    reasons.append(f"MANDATORY_STRESS_FAIL:{branch}:{scenario}")
        for branch in ("RECORDED", "RSB3"):
            delayed = sorted(
                (
                    summary
                    for summary in summaries.get(branch, {}).values()
                    if summary["delay_ms"] >= 0.0
                ),
                key=lambda summary: summary["delay_ms"],
            )
            for index, milder in enumerate(delayed[:-1]):
                catastrophic = (
                    milder["profit_factor_p05"] < 1.0
                    or milder["expectancy_p05"] <= 0.0
                    or milder["drawdown_p95"] >= 20.0
                )
                harsher_passes = any(
                    harsher["profit_factor_p05"] >= 1.30
                    and harsher["expectancy_p05"] > 0.0
                    and harsher["drawdown_p95"] < 20.0
                    for harsher in delayed[index + 1 :]
                )
                if catastrophic and harsher_passes:
                    reasons.append(f"NON_MONOTONIC_FRAGILITY:{branch}")
                    break
        return {
            "passed": not reasons,
            "reasons": sorted(set(reasons)),
            "summaries": summaries,
        }

    def monte_carlo(
        self,
        trade_returns: Iterable[float],
        *,
        manifest_sha256: str,
        branch: str,
        scenario: str,
        paths: int = 10_000,
    ) -> dict[str, Any]:
        returns = [float(value) for value in trade_returns]
        if (
            not returns
            or any(not isfinite(value) or value <= -1.0 for value in returns)
            or not re.fullmatch(r"[0-9A-F]{64}", manifest_sha256)
            or branch not in {"RECORDED", "RSB3"}
            or not isinstance(paths, int)
            or paths <= 0
        ):
            raise Stage12Error("MONTE_CARLO_INPUT_INVALID")
        drawdowns = []
        count = len(returns)
        for path_index in range(paths):
            seed_material = f"{manifest_sha256}|{branch}|{scenario}|{path_index}".encode("utf-8")
            seed = int.from_bytes(hashlib.sha256(seed_material).digest()[:8], "big")
            generator = random.Random(seed)
            sampled: list[float] = []
            while len(sampled) < count:
                start = generator.randrange(count)
                sampled.extend(returns[(start + offset) % count] for offset in range(5))
            drawdowns.append(self._maximum_drawdown_percent(sampled[:count]))
        p95 = self._nearest_rank(drawdowns, 0.95)
        return {
            "paths": paths,
            "block_trade_groups": 5,
            "observed_trade_count": count,
            "p95_max_drawdown_percent": p95,
            "passed": p95 < 30.0,
        }

    @staticmethod
    def validate_frames(
        frames: Iterable[Mapping[str, Any]],
        *,
        expected_ids: Iterable[int],
        branches: Iterable[str],
        folds: Iterable[str],
    ) -> dict[str, Any]:
        expected = {
            (int(identifier), str(branch), str(fold))
            for identifier in expected_ids
            for branch in branches
            for fold in folds
        }
        observed_list = [
            (int(frame["configuration_id"]), str(frame["branch"]), str(frame["fold"]))
            for frame in frames
        ]
        observed = set(observed_list)
        duplicates = sorted(key for key in observed if observed_list.count(key) > 1)
        missing = sorted(expected - observed)
        unexpected = sorted(observed - expected)
        return {
            "passed": not duplicates and not missing and not unexpected,
            "duplicates": duplicates,
            "missing": missing,
            "unexpected": unexpected,
        }

    def evaluate_neighborhood(
        self, center_identifier: int, rows: Iterable[Mapping[str, Any]]
    ) -> dict[str, Any]:
        expected_neighbors = set(self.neighbor_ids(center_identifier))
        materialized = [dict(row) for row in rows]
        by_key = {
            (int(row["configuration_id"]), str(row["branch"])): row
            for row in materialized
        }
        expected_keys = {
            (identifier, branch)
            for identifier in expected_neighbors
            for branch in ("RECORDED", "RSB3")
        }
        if set(by_key) != expected_keys or len(by_key) != len(materialized):
            return {
                "passed": False,
                "reason": "NEIGHBOR_RESULT_SET_INCOMPLETE",
                "qualifying_fraction": 0.0,
            }
        qualifying = 0
        drawdown_veto = False
        for identifier in expected_neighbors:
            branch_rows = [by_key[(identifier, branch)] for branch in ("RECORDED", "RSB3")]
            if any(float(row["max_drawdown_percent"]) > 20.0 for row in branch_rows):
                drawdown_veto = True
            if all(
                float(row["expectancy"]) > 0.0
                and float(row["profit_factor"]) >= 1.20
                for row in branch_rows
            ):
                qualifying += 1
        fraction = qualifying / len(expected_neighbors)
        return {
            "passed": fraction >= 0.80 and not drawdown_veto,
            "reason": "PASS" if fraction >= 0.80 and not drawdown_veto else "NEIGHBOR_GATE_FAIL",
            "qualifying_fraction": fraction,
            "drawdown_veto": drawdown_veto,
            "neighbor_count": len(expected_neighbors),
        }

    def _default_distance(self, identifier: int) -> int:
        configuration = self.decode_configuration(identifier)
        defaults = self.decode_configuration(self.default_configuration_id)
        return sum(
            abs(values.index(configuration[name]) - values.index(defaults[name]))
            for name, values in self.PARAMETER_GRIDS
        )

    def select_configuration(
        self,
        scored: Iterable[Mapping[str, Any]],
        neighborhoods: Mapping[int, Mapping[str, Any]],
    ) -> dict[str, Any]:
        candidates = [dict(row) for row in scored]
        if not candidates:
            raise Stage12Error("NO_SELECTION_CANDIDATES")
        if len({int(row["configuration_id"]) for row in candidates}) != len(candidates):
            raise Stage12Error("DUPLICATE_SELECTION_CANDIDATE")
        for row in candidates:
            identifier = int(row["configuration_id"])
            if identifier not in neighborhoods:
                raise Stage12Error("NEIGHBORHOOD_EVIDENCE_MISSING")
        return min(
            candidates,
            key=lambda row: (
                -float(row["governing_score"]),
                -float(neighborhoods[int(row["configuration_id"])]["qualifying_fraction"]),
                float(row["worse_branch_drawdown_percent"]),
                self._default_distance(int(row["configuration_id"])),
                int(row["configuration_id"]),
            ),
        )

    def build_surface_evidence(
        self,
        scored: Iterable[Mapping[str, Any]],
        *,
        expected_ids: Iterable[int] | None = None,
    ) -> dict[str, Any]:
        expected = set(range(self.configuration_count) if expected_ids is None else expected_ids)
        rows = [dict(row) for row in scored]
        observed = [int(row["configuration_id"]) for row in rows]
        if len(observed) != len(set(observed)) or set(observed) != expected:
            raise Stage12Error("SURFACE_CONFIGURATION_SET_INCOMPLETE")
        surface = []
        for row in sorted(rows, key=lambda item: int(item["configuration_id"])):
            score = float(row["governing_score"])
            if not isfinite(score):
                raise Stage12Error("SURFACE_SCORE_INVALID")
            identifier = int(row["configuration_id"])
            surface.append(
                {
                    "configuration_id": identifier,
                    "parameters": self.decode_configuration(identifier),
                    "governing_score": score,
                }
            )
        heatmap_hashes: dict[str, str] = {}
        names = [name for name, _ in self.PARAMETER_GRIDS]
        for first, second in combinations(names, 2):
            cells: dict[str, list[float]] = {}
            for row in surface:
                parameters = row["parameters"]
                key = json.dumps(
                    [parameters[first], parameters[second]], separators=(",", ":")
                )
                cells.setdefault(key, []).append(float(row["governing_score"]))
            heatmap = [
                {
                    "cell": json.loads(key),
                    "count": len(values),
                    "mean_governing_score": statistics.fmean(values),
                    "minimum_governing_score": min(values),
                }
                for key, values in sorted(cells.items())
            ]
            heatmap_hashes[f"{first}|{second}"] = self._canonical_sha256(
                {"parameters": [first, second], "cells": heatmap}
            )
        return {
            "configuration_count": len(surface),
            "surface_sha256": self._canonical_sha256({"surface": surface}),
            "pairwise_heatmap_sha256": heatmap_hashes,
        }
