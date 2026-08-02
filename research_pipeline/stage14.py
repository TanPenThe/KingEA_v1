"""Stage 14 governed research coordination.

This module is deliberately independent of MT5 and broker data collection.  It
turns immutable facts into manifests, tester bundles, evidence, and fail-closed
decisions.  The CLI adapter owns filesystem/process effects.
"""

from __future__ import annotations

import hashlib
import csv
import io
import json
import math
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

from .stage12 import Stage12Pipeline


class Stage14Error(ValueError):
    """A fail-closed Stage 14 contract violation."""


class ResearchRunCoordinator:
    """Deep deterministic interface for Stage 14 preparation and evidence."""

    BUILD_ID = "KINGEA-STAGE14-20260802-A"
    TOTAL_DEVELOPMENT_PASSES = 194_400
    MAX_ACTIVE_SECONDS = 30 * 86_400
    REQUIRED_HASHES = frozenset(
        {
            "candidate",
            "configuration",
            "source",
            "dataset",
            "tester_ea",
            "pipeline",
            "accounting",
            "calendar",
            "cost",
            "research_specification",
            "pre_tooling",
        }
    )
    PARTITIONS = Stage12Pipeline.PARTITIONS
    SCENARIOS: Mapping[str, Mapping[str, Any]] = {
        "BASELINE_20MS": {"adapter": "NATIVE", "mode": 20},
        "DELAY_100MS": {"adapter": "NATIVE", "mode": 100},
        "DELAY_250MS": {"adapter": "NATIVE", "mode": 250},
        "DELAY_500MS": {"adapter": "NATIVE", "mode": 500},
        "RANDOM_SEVERE": {"adapter": "NATIVE", "mode": -1},
        "SPREAD_2X": {"adapter": "VIRTUAL", "mode": 0, "spread": 2.0},
        "SPREAD_2_5X": {"adapter": "VIRTUAL", "mode": 0, "spread": 2.5},
        "SPREAD_3X": {"adapter": "VIRTUAL", "mode": 0, "spread": 3.0},
        "COST_1_3X": {"adapter": "VIRTUAL", "mode": 0, "cost": 1.3},
        "SLIPPAGE_NORMAL_0_25X": {"adapter": "VIRTUAL", "mode": 0, "slippage": 0.25},
        "SLIPPAGE_HIGH_0_5X": {"adapter": "VIRTUAL", "mode": 0, "slippage": 0.50},
        "SLIPPAGE_EXTREME_1X": {"adapter": "VIRTUAL", "mode": 0, "slippage": 1.00},
        "MISSED_5_PERCENT": {"adapter": "VIRTUAL", "mode": 0, "missed": 0.05},
        "MISSED_10_PERCENT": {"adapter": "VIRTUAL", "mode": 0, "missed": 0.10},
        "COMBINED": {
            "adapter": "VIRTUAL",
            "mode": 0,
            "delay": 500,
            "spread": 3.0,
            "cost": 1.3,
            "missed": 0.10,
            "volatility_slippage": True,
        },
    }

    @staticmethod
    def canonical_bytes(value: Mapping[str, Any] | Sequence[Any]) -> bytes:
        return json.dumps(
            value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")

    @classmethod
    def canonical_hash(cls, value: Mapping[str, Any] | Sequence[Any]) -> str:
        return hashlib.sha256(cls.canonical_bytes(value)).hexdigest().upper()

    @staticmethod
    def file_hash(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest().upper()

    @staticmethod
    def _valid_hash(value: Any) -> bool:
        return (
            isinstance(value, str)
            and len(value) == 64
            and all(character in "0123456789ABCDEF" for character in value.upper())
        )

    def _validate_child_facts(self, facts: Mapping[str, Any]) -> None:
        required = {
            "run_id",
            "gate",
            "purpose",
            "partition",
            "branch",
            "configuration_start",
            "configuration_end",
            "scenario",
            "seed",
            "execution_adapter",
            "execution_mode",
            "artifact_hashes",
            "mt5_build",
            "account_fingerprint",
            "operational_facts",
        }
        if not required.issubset(facts):
            raise Stage14Error("CHILD_FACTS_INCOMPLETE")
        if facts["gate"] not in (1, 2, 3):
            raise Stage14Error("GATE_INVALID")
        partition = str(facts["partition"])
        if partition not in self.PARTITIONS or partition == "HOLDOUT":
            raise Stage14Error("PARTITION_NOT_AUTHORIZED_IN_STAGE14")
        purpose = str(facts["purpose"])
        expected_gate = 3 if partition == "FORMAL_OOS" else (2 if "FORWARD" in partition else 1)
        if int(facts["gate"]) != expected_gate:
            raise Stage14Error("GATE_PARTITION_MISMATCH")
        if purpose == "DEVELOPMENT" and expected_gate != 1:
            raise Stage14Error("PURPOSE_PARTITION_MISMATCH")
        if purpose == "FORWARD" and expected_gate != 2:
            raise Stage14Error("PURPOSE_PARTITION_MISMATCH")
        if purpose == "OOS" and expected_gate != 3:
            raise Stage14Error("PURPOSE_PARTITION_MISMATCH")
        if expected_gate == 3 and not all(
            self._valid_hash(facts.get(field))
            for field in ("selection_sha256", "surface_sha256")
        ):
            raise Stage14Error("OOS_PREREQUISITES_MISSING")
        if facts["branch"] not in ("RECORDED", "RSB3"):
            raise Stage14Error("BRANCH_INVALID")
        start = facts["configuration_start"]
        end = facts["configuration_end"]
        if (
            isinstance(start, bool)
            or isinstance(end, bool)
            or not isinstance(start, int)
            or not isinstance(end, int)
            or not 0 <= start <= end < 19_440
            or end - start + 1 > 1_000
        ):
            raise Stage14Error("CONFIGURATION_RANGE_INVALID")
        scenario = str(facts["scenario"])
        if scenario not in self.SCENARIOS:
            raise Stage14Error("SCENARIO_INVALID")
        declared = self.SCENARIOS[scenario]
        if (
            facts["execution_adapter"] != declared["adapter"]
            or int(facts["execution_mode"]) != int(declared["mode"])
        ):
            raise Stage14Error("SCENARIO_REALIZATION_MISMATCH")
        hashes = facts["artifact_hashes"]
        if not isinstance(hashes, Mapping) or set(hashes) != self.REQUIRED_HASHES:
            raise Stage14Error("ARTIFACT_HASH_SET_INVALID")
        if not all(self._valid_hash(value) for value in hashes.values()):
            raise Stage14Error("ARTIFACT_HASH_INVALID")
        if not self._valid_hash(facts["account_fingerprint"]):
            raise Stage14Error("ACCOUNT_FINGERPRINT_INVALID")
        self._validate_operational_facts(facts["operational_facts"], hashes)

    def _validate_operational_facts(
        self, operational: Any, hashes: Mapping[str, Any]
    ) -> None:
        required = {
            "calendar_intervals_file",
            "calendar_file_sha256",
            "commission_per_lot_round_turn",
            "swap_per_lot_stress",
            "weekend_risk_multiplier",
            "maintenance_entry_block_minutes",
            "maintenance_force_flat_minutes",
            "maintenance_clean_minutes",
        }
        if not isinstance(operational, Mapping) or set(operational) != required:
            raise Stage14Error("OPERATIONAL_FACTS_INVALID")
        if (
            not str(operational["calendar_intervals_file"]).startswith("KingEA\\research_inputs\\")
            or not self._valid_hash(operational["calendar_file_sha256"])
            or str(operational["calendar_file_sha256"]).upper()
            != str(hashes["calendar"]).upper()
        ):
            raise Stage14Error("CALENDAR_EXECUTION_BINDING_INVALID")
        numeric = (
            operational["commission_per_lot_round_turn"],
            operational["swap_per_lot_stress"],
            operational["weekend_risk_multiplier"],
        )
        if any(
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(float(value))
            for value in numeric
        ):
            raise Stage14Error("OPERATIONAL_COST_FACTS_INVALID")
        if (
            float(numeric[0]) < 0
            or float(numeric[1]) < 0
            or float(numeric[2]) != 0.50
            or int(operational["maintenance_entry_block_minutes"]) != 30
            or int(operational["maintenance_force_flat_minutes"]) != 5
            or int(operational["maintenance_clean_minutes"]) != 15
        ):
            raise Stage14Error("OPERATIONAL_THRESHOLDS_CHANGED")

    def prepare_child(self, facts: Mapping[str, Any]) -> dict[str, Any]:
        self._validate_child_facts(facts)
        start, end = self.PARTITIONS[str(facts["partition"])]
        configuration_ids = list(
            range(int(facts["configuration_start"]), int(facts["configuration_end"]) + 1)
        )
        root_facts = {
            "schema": 2,
            "build_id": self.BUILD_ID,
            "gate": int(facts["gate"]),
            "purpose": str(facts["purpose"]),
            "artifact_hashes": dict(facts["artifact_hashes"]),
            "mt5_build": int(facts["mt5_build"]),
            "account_fingerprint": str(facts["account_fingerprint"]).upper(),
        }
        root_sha256 = str(facts.get("root_sha256") or self.canonical_hash(root_facts))
        if not self._valid_hash(root_sha256):
            raise Stage14Error("ROOT_HASH_INVALID")
        manifest = {
            **dict(facts),
            "schema": 2,
            "build_id": self.BUILD_ID,
            "candidate_id": "CAND-ETH-ST-001",
            "status": "PLANNED",
            "root_sha256": root_sha256,
            "start_inclusive": start,
            "end_exclusive": end,
            "initial_equity_usd": 1_000.0,
            "risk_percent": 1.10,
            "expected_symbol": (
                "ETHUSD.s" if facts["branch"] == "RECORDED" else "KINGEA_ETHUSD_S_RSB3"
            ),
            "configuration_ids": configuration_ids,
            "expected_frame_ids": [
                f"{facts['run_id']}|{identifier}|KINGEA_STAGE12_COMPLETE"
                for identifier in configuration_ids
            ],
            "outputs": ["frames", "result", "terminal_log", "pace"],
        }
        manifest["manifest_sha256"] = self.canonical_hash(manifest)
        return manifest

    def prepare_gate_root(
        self,
        gate: int,
        common: Mapping[str, Any],
        *,
        upstream_root_sha256: str | None = None,
        selections: Mapping[str, int] | None = None,
        final_configuration_id: int | None = None,
        selection_sha256: str | None = None,
        surface_sha256: str | None = None,
    ) -> dict[str, Any]:
        if gate not in (1, 2, 3):
            raise Stage14Error("GATE_INVALID")
        if set(common) != {
            "artifact_hashes",
            "mt5_build",
            "account_fingerprint",
            "operational_facts",
        }:
            raise Stage14Error("GATE_COMMON_FACTS_INVALID")
        hashes = common["artifact_hashes"]
        if not isinstance(hashes, Mapping) or set(hashes) != self.REQUIRED_HASHES or not all(
            self._valid_hash(value) for value in hashes.values()
        ):
            raise Stage14Error("ARTIFACT_HASH_SET_INVALID")
        if not self._valid_hash(common["account_fingerprint"]):
            raise Stage14Error("ACCOUNT_FINGERPRINT_INVALID")
        self._validate_operational_facts(common["operational_facts"], hashes)
        descriptors: list[dict[str, Any]] = []
        if gate == 1:
            partitions = [f"FOLD_{index}_TRAIN" for index in range(1, 5)] + ["FINAL_SELECTION"]
            for partition in partitions:
                for branch in ("RECORDED", "RSB3"):
                    for chunk_start in range(0, 19_440, 1_000):
                        chunk_end = min(chunk_start + 999, 19_439)
                        descriptors.append(
                            {
                                "partition": partition,
                                "branch": branch,
                                "configuration_start": chunk_start,
                                "configuration_end": chunk_end,
                                "scenario": "BASELINE_20MS",
                                "seed": 0,
                                "adapter": "NATIVE",
                                "execution_mode": 20,
                            }
                        )
        elif gate == 2:
            if not self._valid_hash(upstream_root_sha256) or set(selections or {}) != {
                f"FOLD_{index}" for index in range(1, 5)
            }:
                raise Stage14Error("GATE2_SELECTION_BINDING_INVALID")
            for index in range(1, 5):
                identifier = int((selections or {})[f"FOLD_{index}"])
                if not 0 <= identifier < 19_440:
                    raise Stage14Error("GATE2_CONFIGURATION_INVALID")
                for branch in ("RECORDED", "RSB3"):
                    descriptors.append(
                        {
                            "partition": f"FOLD_{index}_FORWARD",
                            "branch": branch,
                            "configuration_start": identifier,
                            "configuration_end": identifier,
                            "scenario": "BASELINE_20MS",
                            "seed": 0,
                            "adapter": "NATIVE",
                            "execution_mode": 20,
                        }
                    )
        else:
            if (
                not self._valid_hash(upstream_root_sha256)
                or not isinstance(final_configuration_id, int)
                or isinstance(final_configuration_id, bool)
                or not 0 <= final_configuration_id < 19_440
                or not self._valid_hash(selection_sha256)
                or not self._valid_hash(surface_sha256)
            ):
                raise Stage14Error("GATE3_BINDING_INVALID")
            seeded_counts = {
                "MISSED_5_PERCENT": 100,
                "MISSED_10_PERCENT": 100,
                "COMBINED": 100,
            }
            for branch in ("RECORDED", "RSB3"):
                for scenario, realization in self.SCENARIOS.items():
                    count = seeded_counts.get(scenario, 1)
                    for seed in range(count):
                        descriptors.append(
                            {
                                "partition": "FORMAL_OOS",
                                "branch": branch,
                                "configuration_start": final_configuration_id,
                                "configuration_end": final_configuration_id,
                                "scenario": scenario,
                                "seed": seed,
                                "adapter": realization["adapter"],
                                "execution_mode": realization["mode"],
                            }
                        )
        root = {
            "schema": 2,
            "build_id": self.BUILD_ID,
            "gate": gate,
            "status": "PLANNED",
            "owner_approved": False,
            "candidate_id": "CAND-ETH-ST-001",
            "candidate_budget_before": 0 if gate == 1 else 1,
            "candidate_budget_transition": "FIRST_VALID_RESULT_PASS" if gate == 1 else "ALREADY_CONSUMED",
            "artifact_hashes": dict(hashes),
            "mt5_build": int(common["mt5_build"]),
            "account_fingerprint": str(common["account_fingerprint"]),
            "operational_facts": dict(common["operational_facts"]),
            "upstream_root_sha256": upstream_root_sha256 or "",
            "selections": dict(selections or {}),
            "final_configuration_id": final_configuration_id,
            "selection_sha256": selection_sha256 or "",
            "surface_sha256": surface_sha256 or "",
            "child_descriptors": descriptors,
            "child_descriptors_sha256": self.canonical_hash(descriptors),
            "launch_count": len(descriptors),
            "configuration_pass_count": sum(
                row["configuration_end"] - row["configuration_start"] + 1
                for row in descriptors
            ),
        }
        if gate == 3:
            root["scenario_runs_per_branch"] = len(descriptors) // 2
            if root["scenario_runs_per_branch"] != 312:
                raise Stage14Error("STRESS_CARDINALITY_INTERNAL_ERROR")
        root["root_sha256"] = self.canonical_hash(root)
        return root

    def materialize_children(self, root: Mapping[str, Any]) -> list[dict[str, Any]]:
        stored = root.get("root_sha256")
        unhashed = {key: value for key, value in root.items() if key != "root_sha256"}
        if not self._valid_hash(stored) or self.canonical_hash(unhashed) != stored:
            raise Stage14Error("ROOT_HASH_MISMATCH")
        descriptors = root.get("child_descriptors")
        if not isinstance(descriptors, list) or self.canonical_hash(descriptors) != root.get(
            "child_descriptors_sha256"
        ):
            raise Stage14Error("CHILD_DESCRIPTOR_HASH_MISMATCH")
        children = []
        purpose = {1: "DEVELOPMENT", 2: "FORWARD", 3: "OOS"}.get(root.get("gate"))
        if purpose is None:
            raise Stage14Error("GATE_INVALID")
        for index, descriptor in enumerate(descriptors):
            facts = {
                "run_id": f"G{root['gate']}-{index:04d}",
                "gate": root["gate"],
                "purpose": purpose,
                "partition": descriptor["partition"],
                "branch": descriptor["branch"],
                "configuration_start": descriptor["configuration_start"],
                "configuration_end": descriptor["configuration_end"],
                "scenario": descriptor["scenario"],
                "seed": descriptor["seed"],
                "execution_adapter": descriptor["adapter"],
                "execution_mode": descriptor["execution_mode"],
                "artifact_hashes": root["artifact_hashes"],
                "mt5_build": root["mt5_build"],
                "account_fingerprint": root["account_fingerprint"],
                "operational_facts": root["operational_facts"],
                "root_sha256": stored,
            }
            if root["gate"] == 3:
                facts["selection_sha256"] = root["selection_sha256"]
                facts["surface_sha256"] = root["surface_sha256"]
            children.append(self.prepare_child(facts))
        if len(children) != root.get("launch_count"):
            raise Stage14Error("CHILD_MATERIALIZATION_COUNT_MISMATCH")
        return children

    def authorize(
        self, manifest: Mapping[str, Any], authorization: Mapping[str, Any] | None
    ) -> dict[str, Any]:
        stored = manifest.get("manifest_sha256")
        unhashed = {key: value for key, value in manifest.items() if key != "manifest_sha256"}
        if not self._valid_hash(stored) or self.canonical_hash(unhashed) != stored:
            return {"allowed": False, "reason": "MANIFEST_HASH_MISMATCH"}
        if not authorization or not authorization.get("owner_approved"):
            return {"allowed": False, "reason": "OWNER_GATE_AUTHORIZATION_REQUIRED"}
        if (
            authorization.get("gate") != manifest.get("gate")
            or authorization.get("root_sha256") != manifest.get("root_sha256")
            or authorization.get("child_sha256") != stored
        ):
            return {"allowed": False, "reason": "GATE_AUTHORIZATION_MISMATCH"}
        return {"allowed": True, "reason": "AUTHORIZED", "next_status": "RUNNING"}

    def render_bundle(
        self, manifest: Mapping[str, Any], authorization: Mapping[str, Any]
    ) -> dict[str, str]:
        decision = self.authorize(manifest, authorization)
        if not decision["allowed"]:
            raise Stage14Error(str(decision["reason"]))
        scenario = self.SCENARIOS[str(manifest["scenario"])]
        token = hashlib.sha256(
            f"{manifest['manifest_sha256']}|{manifest['purpose']}|RUNNING".encode()
        ).hexdigest().upper()
        set_lines = [
            "; Generated exclusively from an authorized Stage 14 child manifest.",
            f"InpRunManifest=KingEA\\runs\\{manifest['manifest_sha256']}.json",
            f"InpManifestSha256={manifest['manifest_sha256']}",
            "InpManifestFileSha256=SET_AT_EXECUTION",
            f"InpDetachedAuthorizationToken={token}",
            f"InpRootSha256={manifest['root_sha256']}",
            f"InpGate={manifest['gate']}",
            f"InpPurpose={manifest['purpose']}",
            f"InpPartition={manifest['partition']}",
            f"InpBranch={manifest['branch']}",
            f"InpExpectedSymbol={manifest['expected_symbol']}",
            f"InpConfigurationId={manifest['configuration_start']}||{manifest['configuration_start']}||1||{manifest['configuration_end']}||Y",
            "InpTesterModel=4",
            "InpLocalAgentsOnly=true",
            "InpRemoteAgentsDisabled=true",
            "InpCloudAgentsDisabled=true",
            f"InpScenario={manifest['scenario']}",
            f"InpExecutionAdapter={manifest['execution_adapter']}",
            f"InpDelayMs={int(scenario.get('delay', manifest['execution_mode']))}",
            f"InpSpreadMultiplier={float(scenario.get('spread', 1.0))}",
            f"InpCostMultiplier={float(scenario.get('cost', 1.0))}",
            f"InpSlippageSpreadFraction={float(scenario.get('slippage', 0.0))}",
            f"InpVolatilityDependentSlippage={'true' if scenario.get('volatility_slippage', False) else 'false'}",
            f"InpMissedEntryFraction={float(scenario.get('missed', 0.0))}",
            f"InpStressSeed={int(manifest['seed'])}",
            f"InpCalendarSha256={manifest['artifact_hashes']['calendar']}",
            f"InpCostManifestSha256={manifest['artifact_hashes']['cost']}",
            f"InpResearchSpecificationSha256={manifest['artifact_hashes']['research_specification']}",
            f"InpCalendarIntervalsFile={manifest['operational_facts']['calendar_intervals_file']}",
            f"InpCalendarFileSha256={manifest['operational_facts']['calendar_file_sha256']}",
            f"InpCommissionPerLotRoundTurn={manifest['operational_facts']['commission_per_lot_round_turn']}",
            f"InpSwapPerLotStress={manifest['operational_facts']['swap_per_lot_stress']}",
            f"InpWeekendRiskMultiplier={manifest['operational_facts']['weekend_risk_multiplier']}",
            f"InpMaintenanceEntryBlockMinutes={manifest['operational_facts']['maintenance_entry_block_minutes']}",
            f"InpMaintenanceForceFlatMinutes={manifest['operational_facts']['maintenance_force_flat_minutes']}",
            f"InpMaintenanceCleanMinutes={manifest['operational_facts']['maintenance_clean_minutes']}",
            f"InpSelectionSha256={manifest.get('selection_sha256', '')}",
            f"InpSurfaceSha256={manifest.get('surface_sha256', '')}",
        ]
        start = datetime.fromisoformat(str(manifest["start_inclusive"]))
        end = datetime.fromisoformat(str(manifest["end_exclusive"]))
        tester_start = max(datetime(2021, 4, 1), start - timedelta(days=90))
        tester_end = end - timedelta(days=1)
        ini_lines = [
            "[Tester]",
            r"Expert=KingEA\GuardedResearchTester.ex5",
            f"ExpertParameters={manifest['manifest_sha256']}.set",
            f"Symbol={manifest['expected_symbol']}",
            "Period=M30",
            "Model=4",
            f"ExecutionMode={int(manifest['execution_mode'])}",
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

    def verify_bundle(
        self,
        manifest: Mapping[str, Any],
        authorization: Mapping[str, Any],
        bundle: Mapping[str, str],
    ) -> dict[str, Any]:
        expected = self.render_bundle(manifest, authorization)
        if set(bundle) != {"set", "ini"} or any(bundle[name] != expected[name] for name in expected):
            raise Stage14Error("TESTER_BUNDLE_NOT_DERIVED_FROM_CHILD_MANIFEST")
        return {
            "passed": True,
            "set_sha256": hashlib.sha256(bundle["set"].encode()).hexdigest().upper(),
            "ini_sha256": hashlib.sha256(bundle["ini"].encode()).hexdigest().upper(),
        }

    def append_frame(
        self, spool: Path, manifest: Mapping[str, Any], frame: Mapping[str, Any]
    ) -> dict[str, Any]:
        final_path = spool / "FINALIZED.json"
        if final_path.exists():
            raise Stage14Error("LATE_FRAME_AFTER_FINALIZATION")
        frame_id = str(frame.get("frame_id", ""))
        if frame_id not in manifest.get("expected_frame_ids", []):
            raise Stage14Error("UNEXPECTED_FRAME_ID")
        payload = frame.get("payload")
        if not isinstance(payload, Mapping) or payload.get("complete") != 1:
            raise Stage14Error("MALFORMED_OR_INCOMPLETE_FRAME")
        record = {
            "manifest_sha256": manifest["manifest_sha256"],
            "frame_id": frame_id,
            "payload": dict(payload),
        }
        encoded = self.canonical_bytes(record)
        spool.mkdir(parents=True, exist_ok=True)
        target = spool / f"{hashlib.sha256(frame_id.encode()).hexdigest().upper()}.frame.json"
        if target.exists():
            if target.read_bytes() != encoded:
                raise Stage14Error("CONFLICTING_DUPLICATE_FRAME")
            return {"status": "IDEMPOTENT_REPLAY", "path": str(target)}
        target.write_bytes(encoded)
        return {"status": "APPENDED", "path": str(target)}

    def finalize_frames(self, spool: Path, manifest: Mapping[str, Any]) -> dict[str, Any]:
        records: dict[str, dict[str, Any]] = {}
        for path in spool.glob("*.frame.json"):
            try:
                record = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                raise Stage14Error("MALFORMED_FRAME_SPOOL") from exc
            if record.get("manifest_sha256") != manifest.get("manifest_sha256"):
                raise Stage14Error("FRAME_MANIFEST_CONFLICT")
            frame_id = str(record.get("frame_id", ""))
            if frame_id in records:
                raise Stage14Error("DUPLICATE_FRAME_ID")
            records[frame_id] = record
        expected = set(manifest.get("expected_frame_ids", []))
        if set(records) != expected:
            raise Stage14Error("FRAME_SET_INCOMPLETE")
        frames = [records[frame_id]["payload"] for frame_id in sorted(records)]
        result = {
            "status": "COMPLETE",
            "manifest_sha256": manifest["manifest_sha256"],
            "frame_count": len(frames),
            "frames": frames,
        }
        result["evidence_sha256"] = self.canonical_hash(result)
        target = spool / "FINALIZED.json"
        if target.exists():
            raise Stage14Error("FINALIZATION_ALREADY_EXISTS")
        target.write_bytes(self.canonical_bytes(result))
        return result

    def evaluate_benchmark(
        self,
        *,
        valid_passes: int,
        elapsed_seconds: float,
        local_agents: int,
        projected_passes: int,
        available_disk_bytes: int,
        average_frame_bytes: int,
    ) -> dict[str, Any]:
        if (
            valid_passes <= 0
            or elapsed_seconds <= 0
            or local_agents <= 0
            or projected_passes <= 0
            or average_frame_bytes <= 0
        ):
            raise Stage14Error("BENCHMARK_FACTS_INVALID")
        rate = valid_passes / elapsed_seconds
        projected_seconds = projected_passes / rate * 1.25
        required_disk = projected_passes * average_frame_bytes
        return {
            "passed": projected_seconds <= self.MAX_ACTIVE_SECONDS
            and available_disk_bytes >= required_disk * 2,
            "signal_free": True,
            "valid_pass_rate": rate,
            "local_agents": local_agents,
            "projected_passes": projected_passes,
            "projected_seconds_with_allowance": projected_seconds,
            "required_disk_bytes": required_disk,
            "candidate_budget_consumed": 0,
            "reason": (
                "PASS"
                if projected_seconds <= self.MAX_ACTIVE_SECONDS
                and available_disk_bytes >= required_disk * 2
                else "BENCHMARK_CAP_OR_DISK_FAIL"
            ),
        }

    def prepare_benchmark_root(
        self, common: Mapping[str, Any], *, sample_passes_per_branch: int
    ) -> dict[str, Any]:
        if (
            set(common)
            != {"artifact_hashes", "mt5_build", "account_fingerprint", "operational_facts"}
            or not isinstance(sample_passes_per_branch, int)
            or isinstance(sample_passes_per_branch, bool)
            or not 1 <= sample_passes_per_branch <= 1_000
        ):
            raise Stage14Error("BENCHMARK_ROOT_FACTS_INVALID")
        hashes = common["artifact_hashes"]
        if not isinstance(hashes, Mapping) or set(hashes) != self.REQUIRED_HASHES or not all(
            self._valid_hash(value) for value in hashes.values()
        ):
            raise Stage14Error("ARTIFACT_HASH_SET_INVALID")
        if not self._valid_hash(common["account_fingerprint"]):
            raise Stage14Error("ACCOUNT_FINGERPRINT_INVALID")
        self._validate_operational_facts(common["operational_facts"], hashes)
        root = {
            "schema": 1,
            "kind": "SIGNAL_FREE_REAL_TICK_BENCHMARK",
            "build_id": self.BUILD_ID,
            "partition": "FINAL_SELECTION",
            "start_inclusive": self.PARTITIONS["FINAL_SELECTION"][0],
            "end_exclusive": self.PARTITIONS["FINAL_SELECTION"][1],
            "branches": ["RECORDED", "RSB3"],
            "sample_passes_per_branch": sample_passes_per_branch,
            "pass_count": sample_passes_per_branch * 2,
            "projected_development_passes": self.TOTAL_DEVELOPMENT_PASSES,
            "artifact_hashes": dict(hashes),
            "mt5_build": int(common["mt5_build"]),
            "account_fingerprint": common["account_fingerprint"],
            "operational_facts": dict(common["operational_facts"]),
            "model": 4,
            "execution_mode": 20,
            "local_agents_only": True,
            "signals": 0,
            "trades": 0,
            "returns": "ABSENT",
            "candidate_budget_consumed": 0,
            "status": "PLANNED_NON_PERFORMANCE",
        }
        root["benchmark_root_sha256"] = self.canonical_hash(root)
        return root

    def render_benchmark_bundle(
        self, root: Mapping[str, Any], *, branch: str
    ) -> dict[str, str]:
        stored = root.get("benchmark_root_sha256")
        unhashed = {
            key: value for key, value in root.items() if key != "benchmark_root_sha256"
        }
        if not self._valid_hash(stored) or self.canonical_hash(unhashed) != stored:
            raise Stage14Error("BENCHMARK_ROOT_HASH_MISMATCH")
        if root.get("kind") != "SIGNAL_FREE_REAL_TICK_BENCHMARK" or branch not in (
            "RECORDED",
            "RSB3",
        ):
            raise Stage14Error("BENCHMARK_SCOPE_INVALID")
        symbol = "ETHUSD.s" if branch == "RECORDED" else "KINGEA_ETHUSD_S_RSB3"
        count = int(root["sample_passes_per_branch"])
        set_lines = [
            "; Signal-free Stage 14 real-tick throughput benchmark.",
            f"InpBenchmarkRootSha256={stored}",
            f"InpBranch={branch}",
            f"InpExpectedSymbol={symbol}",
            "InpExpectedServerFragment=JustMarkets-Demo2",
            "InpTesterModel=4",
            "InpLocalAgentsOnly=true",
            "InpRemoteAgentsDisabled=true",
            "InpCloudAgentsDisabled=true",
            f"InpBenchmarkPassId=0||0||1||{count - 1}||Y",
        ]
        start = datetime.fromisoformat(str(root["start_inclusive"]))
        end = datetime.fromisoformat(str(root["end_exclusive"])) - timedelta(days=1)
        ini_lines = [
            "[Tester]",
            r"Expert=KingEA\ResearchThroughputBenchmark.ex5",
            f"ExpertParameters={stored}.{branch}.set",
            f"Symbol={symbol}",
            "Period=M30",
            "Model=4",
            "ExecutionMode=20",
            "Optimization=1",
            "UseLocal=1",
            "UseRemote=0",
            "UseCloud=0",
            "Genetic=0",
            "Deposit=1000",
            "Currency=USD",
            f"FromDate={start:%Y.%m.%d}",
            f"ToDate={end:%Y.%m.%d}",
            "ShutdownTerminal=1",
        ]
        return {"set": "\n".join(set_lines) + "\n", "ini": "\n".join(ini_lines) + "\n"}

    def evaluate_pace(
        self,
        benchmark: Mapping[str, Any],
        history: Sequence[Mapping[str, Any]],
        *,
        total_passes: int,
    ) -> dict[str, Any]:
        if not benchmark.get("passed") or not history:
            raise Stage14Error("PACE_INPUT_INVALID")
        latest = history[-1]
        cumulative_rate = float(latest["valid_passes"]) / float(latest["active_elapsed_seconds"])
        trailing_rate = float(latest["trailing_six_hour_rate"])
        conservative_rate = min(cumulative_rate, trailing_rate)
        if conservative_rate <= 0:
            raise Stage14Error("PACE_RATE_INVALID")
        remaining = max(0, total_passes - int(latest["valid_passes"]))
        forecast_seconds = float(latest["active_elapsed_seconds"]) + remaining / conservative_rate
        required_disk = remaining * int(latest["average_frame_bytes"])
        current_bad = {
            "forecast": forecast_seconds > self.MAX_ACTIVE_SECONDS,
            "throughput": conservative_rate < 0.8 * float(benchmark["valid_pass_rate"]),
            "disk": int(latest["available_disk_bytes"]) < required_disk * 2,
        }
        recent = history[-3:]
        persistent_forecast = len(recent) == 3 and all(
            float(row["valid_passes"]) / float(row["active_elapsed_seconds"]) > 0
            and (
                float(row["active_elapsed_seconds"])
                + max(0, total_passes - int(row["valid_passes"]))
                / min(
                    float(row["valid_passes"]) / float(row["active_elapsed_seconds"]),
                    float(row["trailing_six_hour_rate"]),
                )
                > self.MAX_ACTIVE_SECONDS
            )
            for row in recent
        )
        persistent_slow = len(recent) == 3 and all(
            min(
                float(row["valid_passes"]) / float(row["active_elapsed_seconds"]),
                float(row["trailing_six_hour_rate"]),
            )
            < 0.8 * float(benchmark["valid_pass_rate"])
            for row in recent
        )
        unhealthy = any(not bool(latest.get(field, True)) for field in ("storage_healthy", "memory_healthy", "agents_healthy", "frames_healthy"))
        reasons = []
        if persistent_forecast:
            reasons.append("PERSISTENT_30_DAY_FORECAST_BREACH")
        if persistent_slow:
            reasons.append("PERSISTENT_THROUGHPUT_DEGRADATION")
        if current_bad["disk"]:
            reasons.append("DISK_HEADROOM_UNSAFE")
        if unhealthy:
            reasons.append("INFRASTRUCTURE_UNHEALTHY")
        pause = bool(reasons)
        warnings = [name.upper() for name, value in current_bad.items() if value]
        return {
            "action": "PAUSE" if pause else ("WARN" if warnings else "CONTINUE"),
            "reasons": reasons,
            "warnings": warnings,
            "conservative_rate": conservative_rate,
            "forecast_active_seconds": forecast_seconds,
            "completed_valid_passes": int(latest["valid_passes"]),
        }

    @staticmethod
    def _seeded_unit(signal_id: str, seed: int) -> float:
        digest = hashlib.sha256(f"{signal_id}|{seed}".encode()).digest()
        return int.from_bytes(digest[:8], "big") / float(2**64)

    def combined_outcome(
        self,
        *,
        signal_id: str,
        seed: int,
        missed_fraction: float,
        signal_time_msc: int,
        next_tick_time_msc: int | None,
        next_m30_boundary_msc: int,
        gates_healthy: bool,
        execution_healthy: bool,
    ) -> dict[str, Any]:
        if not signal_id or not 0 <= missed_fraction <= 1 or signal_time_msc >= next_m30_boundary_msc:
            raise Stage14Error("COMBINED_SIGNAL_FACTS_INVALID")
        seeded_miss = self._seeded_unit(signal_id, seed) < missed_fraction
        if seeded_miss:
            return {"outcome": "SEEDED_MISS", "seeded_miss": True, "enqueued": False}
        if next_tick_time_msc is None or next_tick_time_msc >= next_m30_boundary_msc:
            return {"outcome": "DELAY_EXPIRY", "seeded_miss": False, "enqueued": True}
        if next_tick_time_msc < signal_time_msc + 500:
            raise Stage14Error("COMBINED_DELAY_NOT_SATISFIED")
        if not gates_healthy:
            return {"outcome": "GATE_REJECT_AFTER_DELAY", "seeded_miss": False, "enqueued": True}
        if not execution_healthy:
            return {"outcome": "VIRTUAL_EXECUTION_FAILURE", "seeded_miss": False, "enqueued": True}
        return {"outcome": "VIRTUAL_FILL", "seeded_miss": False, "enqueued": True}

    def validate_calendar_snapshot(
        self,
        events: Iterable[Mapping[str, Any]],
        *,
        start: str,
        end: str,
        covered_months: Iterable[str],
    ) -> dict[str, Any]:
        start_at = datetime.fromisoformat(start)
        end_at = datetime.fromisoformat(end)
        if start_at.tzinfo is None or end_at.tzinfo is None or start_at >= end_at:
            raise Stage14Error("CALENDAR_RANGE_INVALID")
        expected_months = set()
        cursor = start_at.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        while cursor < end_at:
            expected_months.add(cursor.strftime("%Y-%m"))
            cursor = (cursor.replace(day=28) + timedelta(days=4)).replace(day=1)
        if set(covered_months) != expected_months:
            raise Stage14Error("CALENDAR_MONTH_COVERAGE_INCOMPLETE")
        required_categories = {"CENTRAL_BANK", "CPI", "PCE", "EMPLOYMENT", "GDP"}
        seen_ids: dict[str, Mapping[str, Any]] = {}
        categories = set()
        blackouts = []
        canonical_events = []
        for source in events:
            event = dict(source)
            if event.get("currency") != "USD" or event.get("impact") != "HIGH":
                raise Stage14Error("CALENDAR_EVENT_SCOPE_INVALID")
            try:
                timestamp = datetime.fromisoformat(str(event["time"]))
            except (KeyError, ValueError) as exc:
                raise Stage14Error("CALENDAR_TIMESTAMP_INVALID") from exc
            if timestamp.tzinfo is None or not start_at <= timestamp < end_at:
                raise Stage14Error("CALENDAR_TIMESTAMP_OUT_OF_RANGE")
            event_id = str(event.get("event_id", ""))
            if not event_id:
                raise Stage14Error("CALENDAR_EVENT_ID_MISSING")
            if event_id in seen_ids:
                if seen_ids[event_id] != event:
                    raise Stage14Error("CALENDAR_EVENT_CONFLICT")
                raise Stage14Error("CALENDAR_EVENT_DUPLICATE")
            seen_ids[event_id] = event
            categories.add(str(event.get("category", "")))
            canonical_events.append(event)
            blackouts.append(
                {
                    "event_id": event_id,
                    "start": (timestamp - timedelta(minutes=30)).isoformat(),
                    "end": (timestamp + timedelta(minutes=15)).isoformat(),
                }
            )
        if not required_categories.issubset(categories):
            raise Stage14Error("CALENDAR_REQUIRED_CATEGORY_MISSING")
        canonical_events.sort(key=lambda row: (row["time"], row["event_id"]))
        blackouts.sort(key=lambda row: (row["start"], row["event_id"]))
        evidence = {
            "schema": 1,
            "start_inclusive": start,
            "end_exclusive": end,
            "covered_months": sorted(expected_months),
            "events": canonical_events,
            "blackouts": blackouts,
        }
        return {"passed": True, **evidence, "snapshot_sha256": self.canonical_hash(evidence)}

    def parse_calendar_export(
        self, text: str, *, start: str, end: str
    ) -> dict[str, Any]:
        reader = csv.DictReader(io.StringIO(text))
        required = {
            "schema",
            "event_id",
            "value_id",
            "time",
            "time_msc",
            "importance",
            "event_type",
            "sector",
            "time_mode",
            "country_id",
            "name",
            "source_url",
        }
        if set(reader.fieldnames or ()) != required:
            raise Stage14Error("CALENDAR_EXPORT_COLUMNS_INVALID")
        events = []
        covered_months = set()
        patterns = (
            ("CENTRAL_BANK", r"fomc|federal funds|interest rate|monetary policy"),
            ("CPI", r"consumer price|\bcpi\b"),
            ("PCE", r"personal consumption|\bpce\b"),
            ("EMPLOYMENT", r"nonfarm|unemployment|employment report|payroll"),
            ("GDP", r"gross domestic|\bgdp\b"),
        )
        for row in reader:
            if row.get("schema") != "1" or row.get("importance") not in {"3", "HIGH"}:
                raise Stage14Error("CALENDAR_EXPORT_ROW_INVALID")
            try:
                time_msc = int(row["time_msc"])
                timestamp = datetime.fromtimestamp(time_msc / 1000, tz=timezone.utc)
            except (TypeError, ValueError, OSError) as exc:
                raise Stage14Error("CALENDAR_EXPORT_TIME_INVALID") from exc
            name = str(row.get("name", ""))
            lowered = name.lower()
            category = "OTHER"
            for candidate, pattern in patterns:
                if re.search(pattern, lowered):
                    category = candidate
                    break
            occurrence = f"{row['event_id']}:{row['value_id']}"
            events.append(
                {
                    "event_id": occurrence,
                    "currency": "USD",
                    "impact": "HIGH",
                    "category": category,
                    "time": timestamp.isoformat(),
                    "name": name,
                    "source_url": row.get("source_url", ""),
                }
            )
            covered_months.add(timestamp.strftime("%Y-%m"))
        return self.validate_calendar_snapshot(
            events, start=start, end=end, covered_months=covered_months
        )

    def render_market_intervals(
        self,
        snapshot: Mapping[str, Any],
        *,
        maintenance_windows: Iterable[Mapping[str, Any]],
    ) -> dict[str, Any]:
        if not snapshot.get("passed") or not self._valid_hash(snapshot.get("snapshot_sha256")):
            raise Stage14Error("CALENDAR_SNAPSHOT_NOT_ACCEPTED")
        intervals = []
        for blackout in snapshot.get("blackouts", []):
            start = datetime.fromisoformat(str(blackout["start"]))
            end = datetime.fromisoformat(str(blackout["end"]))
            event_time = start + timedelta(minutes=30)
            if end != event_time + timedelta(minutes=15):
                raise Stage14Error("KINGEA_BLACKOUT_WINDOW_INVALID")
            identity = str(blackout["event_id"])
            intervals.extend(
                (
                    ("KINGEA_ENTRY_BLACKOUT", start, end, identity),
                    (
                        "BROKER_HMR_SCHEDULED",
                        event_time - timedelta(minutes=15),
                        event_time + timedelta(minutes=5),
                        identity,
                    ),
                )
            )
        maintenance = list(maintenance_windows)
        if not maintenance:
            raise Stage14Error("MAINTENANCE_SCHEDULE_MISSING")
        for window in maintenance:
            try:
                identity = str(window["identity"])
                start = datetime.fromisoformat(str(window["start"]))
                end = datetime.fromisoformat(str(window["end"]))
            except (KeyError, ValueError) as exc:
                raise Stage14Error("MAINTENANCE_WINDOW_INVALID") from exc
            if not identity or start.tzinfo is None or end.tzinfo is None or start >= end:
                raise Stage14Error("MAINTENANCE_WINDOW_INVALID")
            intervals.extend(
                (
                    ("MAINTENANCE_ENTRY_BLOCK", start - timedelta(minutes=30), start - timedelta(minutes=5), identity),
                    ("MAINTENANCE_FORCE_FLAT", start - timedelta(minutes=5), end, identity),
                    ("MAINTENANCE_RECOVERY", end, end + timedelta(minutes=15), identity),
                )
            )
        rows = []
        for kind, start, end, identity in intervals:
            if start.tzinfo is None or end.tzinfo is None or start >= end:
                raise Stage14Error("MARKET_INTERVAL_INVALID")
            if any(character in identity for character in (",", "\r", "\n")):
                raise Stage14Error("MARKET_INTERVAL_IDENTITY_INVALID")
            rows.append(
                {
                    "type": kind,
                    "start_msc": int(start.timestamp() * 1000),
                    "end_msc": int(end.timestamp() * 1000),
                    "identity": identity,
                }
            )
        rows.sort(key=lambda row: (row["start_msc"], row["end_msc"], row["type"], row["identity"]))
        text = "type,start_msc,end_msc,identity\n" + "".join(
            f"{row['type']},{row['start_msc']},{row['end_msc']},{row['identity']}\n"
            for row in rows
        )
        return {
            "csv": text,
            "file_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest().upper(),
            "interval_count": len(rows),
            "calendar_snapshot_sha256": snapshot["snapshot_sha256"],
            "hmr_schedule_is_hard_end": False,
            "extended_hmr_policy": "FRESH_BROKER_MARGIN_AND_REVERSION_FACTS_REQUIRED",
        }

    @staticmethod
    def classify_hmr_observation(
        *,
        scheduled_active: bool,
        broker_hmr_active: bool,
        fresh_margin_facts: bool,
        reversion_confirmed: bool,
    ) -> dict[str, Any]:
        """Keep the documented schedule distinct from observed broker margin state."""
        facts = (scheduled_active, broker_hmr_active, fresh_margin_facts, reversion_confirmed)
        if any(type(value) is not bool for value in facts):
            raise Stage14Error("HMR_OBSERVATION_INVALID")
        if scheduled_active:
            if not broker_hmr_active or not fresh_margin_facts:
                return {
                    "classification": "SCHEDULED_HMR_UNVERIFIED",
                    "entry": "BLOCK",
                    "apply_hmr_proxy": True,
                    "specification_healthy": False,
                }
            return {
                "classification": "SCHEDULED_HMR_CONFIRMED",
                "entry": "ALLOW",
                "apply_hmr_proxy": True,
                "specification_healthy": True,
            }
        if broker_hmr_active:
            return {
                "classification": "EXTENDED_OR_UNSCHEDULED_HMR",
                "entry": "BLOCK",
                "apply_hmr_proxy": True,
                "specification_healthy": False,
            }
        if not fresh_margin_facts or not reversion_confirmed:
            return {
                "classification": "HMR_REVERSION_UNPROVEN",
                "entry": "BLOCK",
                "apply_hmr_proxy": True,
                "specification_healthy": False,
            }
        return {
            "classification": "NORMAL_MARGIN_CONFIRMED",
            "entry": "ALLOW",
            "apply_hmr_proxy": True,
            "specification_healthy": True,
        }

    def validate_research_specification(self, facts: Mapping[str, Any]) -> dict[str, Any]:
        required = {
            "server",
            "symbol",
            "captured_at",
            "specification_hash",
            "deal_evidence_hash",
            "commission_per_lot_round_turn",
            "commission_zero_evidence",
            "swap_mode",
            "swap_long",
            "swap_short",
            "hmr_proxy_leverage",
        }
        if set(facts) != required:
            raise Stage14Error("RESEARCH_SPECIFICATION_FIELDS_INVALID")
        if facts["server"] != "JustMarkets-Demo2" or facts["symbol"] != "ETHUSD.s":
            raise Stage14Error("RESEARCH_SPECIFICATION_IDENTITY_INVALID")
        if not self._valid_hash(facts["specification_hash"]) or not self._valid_hash(
            facts["deal_evidence_hash"]
        ):
            raise Stage14Error("RESEARCH_SPECIFICATION_HASH_INVALID")
        try:
            captured_at = datetime.fromisoformat(str(facts["captured_at"]))
            numeric = [
                float(facts["commission_per_lot_round_turn"]),
                float(facts["swap_long"]),
                float(facts["swap_short"]),
            ]
        except (TypeError, ValueError) as exc:
            raise Stage14Error("RESEARCH_SPECIFICATION_VALUE_INVALID") from exc
        if captured_at.tzinfo is None or any(not math.isfinite(value) for value in numeric):
            raise Stage14Error("RESEARCH_SPECIFICATION_VALUE_INVALID")
        if numeric[0] < 0 or (
            numeric[0] == 0 and not bool(facts["commission_zero_evidence"])
        ):
            raise Stage14Error("ZERO_COMMISSION_NOT_PROVEN")
        if not facts["swap_mode"] or int(facts["hmr_proxy_leverage"]) != 200:
            raise Stage14Error("SWAP_OR_HMR_FACTS_INVALID")
        canonical = dict(facts)
        return {
            "passed": True,
            "reason": "PASS",
            "research_specification_sha256": self.canonical_hash(canonical),
        }

    def reconcile_research_capture(
        self,
        specification_csv: str,
        feasibility_csv: str,
        accounting_csv: str,
        *,
        specification_file_sha256: str,
        feasibility_file_sha256: str,
        accounting_file_sha256: str,
        hmr_document_sha256: str,
        hmr_proxy_leverage: int,
    ) -> dict[str, Any]:
        """Reconcile the verified Stage 8, pre-freeze, and Stage 13 collectors."""
        evidence_hashes = {
            "specification": specification_file_sha256,
            "feasibility": feasibility_file_sha256,
            "accounting": accounting_file_sha256,
            "hmr_document": hmr_document_sha256,
        }
        if any(not self._valid_hash(value) for value in evidence_hashes.values()):
            raise Stage14Error("RESEARCH_CAPTURE_HASH_INVALID")
        if int(hmr_proxy_leverage) != 200:
            raise Stage14Error("HMR_PROXY_NOT_FRESHLY_CONFIRMED")

        spec_reader = csv.DictReader(io.StringIO(specification_csv))
        if spec_reader.fieldnames != ["key", "value"]:
            raise Stage14Error("SPECIFICATION_CAPTURE_SCHEMA_INVALID")
        spec: dict[str, str] = {}
        for row in spec_reader:
            key = str(row.get("key", ""))
            if not key or key in spec:
                raise Stage14Error("SPECIFICATION_CAPTURE_DUPLICATE_OR_EMPTY")
            spec[key] = str(row.get("value", ""))

        feasibility_reader = csv.DictReader(io.StringIO(feasibility_csv))
        expected_feasibility_columns = [
            "snapshot_utc", "snapshot_server", "label", "section", "key", "value", "unit", "notes"
        ]
        if feasibility_reader.fieldnames != expected_feasibility_columns:
            raise Stage14Error("FEASIBILITY_CAPTURE_SCHEMA_INVALID")
        feasibility: dict[tuple[str, str], str] = {}
        feasibility_rows = list(feasibility_reader)
        for row in feasibility_rows:
            identity = (str(row["section"]), str(row["key"]))
            if not all(identity) or identity in feasibility:
                raise Stage14Error("FEASIBILITY_CAPTURE_DUPLICATE_OR_EMPTY")
            feasibility[identity] = str(row["value"])
        if not feasibility_rows:
            raise Stage14Error("FEASIBILITY_CAPTURE_EMPTY")

        def required(mapping: Mapping[Any, str], key: Any, reason: str) -> str:
            value = mapping.get(key)
            if value is None or value == "":
                raise Stage14Error(reason)
            return value

        if required(spec, "server", "CAPTURE_IDENTITY_MISSING") != "JustMarkets-Demo2":
            raise Stage14Error("CAPTURE_IDENTITY_MISMATCH")
        if required(spec, "symbol_id", "CAPTURE_IDENTITY_MISSING") != "ETHUSD.s":
            raise Stage14Error("CAPTURE_IDENTITY_MISMATCH")
        if required(feasibility, ("account", "server"), "CAPTURE_IDENTITY_MISSING") != "JustMarkets-Demo2":
            raise Stage14Error("CAPTURE_IDENTITY_MISMATCH")
        symbol_name = feasibility.get(("symbol", "name"), "ETHUSD.s")
        if symbol_name != "ETHUSD.s":
            raise Stage14Error("CAPTURE_IDENTITY_MISMATCH")
        if spec.get("order_capability") != "PROHIBITED_AND_ABSENT" or spec.get(
            "performance_authorization"
        ) != "DENIED":
            raise Stage14Error("CAPTURE_SCOPE_INVALID")

        try:
            spec_time = datetime.strptime(spec["observed_server_time"], "%Y.%m.%d %H:%M:%S")
            feasibility_time = datetime.strptime(
                feasibility_rows[0]["snapshot_server"], "%Y.%m.%d %H:%M:%S"
            )
        except (KeyError, ValueError) as exc:
            raise Stage14Error("CAPTURE_TIME_INVALID") from exc
        if abs((feasibility_time - spec_time).total_seconds()) > 15 * 60:
            raise Stage14Error("CAPTURE_PAIR_STALE")

        discrete_pairs = {
            "digits": "digits",
            "calc_mode": "calc_mode",
            "stops_level": "stops_level",
            "freeze_level": "freeze_level",
        }
        float_pairs = {
            "point": "point",
            "tick_size": "tick_size",
            "tick_value": "tick_value",
            "tick_value_profit": "tick_value_profit",
            "tick_value_loss": "tick_value_loss",
            "contract_size": "contract_size",
            "volume_min": "volume_min",
            "volume_max": "volume_max",
            "volume_step": "volume_step",
            "volume_limit": "volume_limit",
            "margin_initial": "margin_initial",
            "margin_maintenance": "margin_maintenance",
            "margin_hedged": "margin_hedged",
        }
        for spec_key, feasibility_key in discrete_pairs.items():
            if int(required(spec, spec_key, "SPECIFICATION_FIELD_MISSING")) != int(
                required(feasibility, ("symbol", feasibility_key), "FEASIBILITY_FIELD_MISSING")
            ):
                raise Stage14Error("CAPTURE_DISCRETE_FIELD_MISMATCH")
        numeric_facts: dict[str, float] = {}
        for spec_key, feasibility_key in float_pairs.items():
            try:
                left = float(required(spec, spec_key, "SPECIFICATION_FIELD_MISSING"))
                right = float(
                    required(feasibility, ("symbol", feasibility_key), "FEASIBILITY_FIELD_MISSING")
                )
            except ValueError as exc:
                raise Stage14Error("CAPTURE_NUMERIC_FIELD_INVALID") from exc
            tolerance = max(1e-8, 1e-9 * max(abs(left), abs(right)))
            if not math.isfinite(left) or not math.isfinite(right) or abs(left - right) > tolerance:
                raise Stage14Error("CAPTURE_NUMERIC_FIELD_MISMATCH")
            numeric_facts[spec_key] = left

        margin_rate_buy = float(required(spec, "margin_rate_buy", "SPECIFICATION_FIELD_MISSING"))
        margin_rate_sell = float(required(spec, "margin_rate_sell", "SPECIFICATION_FIELD_MISSING"))
        feasibility_buy = float(
            required(feasibility, ("margin_rate", "buy_initial_rate"), "FEASIBILITY_FIELD_MISSING")
        )
        feasibility_sell = float(
            required(feasibility, ("margin_rate", "sell_initial_rate"), "FEASIBILITY_FIELD_MISSING")
        )
        if abs(margin_rate_buy - feasibility_buy) > 1e-8 or abs(margin_rate_sell - feasibility_sell) > 1e-8:
            raise Stage14Error("CAPTURE_MARGIN_RATE_MISMATCH")

        try:
            balance = float(required(feasibility, ("account", "balance_snapshot"), "ACCOUNT_FACT_MISSING"))
            equity = float(required(feasibility, ("account", "equity_snapshot"), "ACCOUNT_FACT_MISSING"))
            account_leverage = int(required(feasibility, ("account", "leverage"), "ACCOUNT_FACT_MISSING"))
            stressed_level = float(required(spec, "stressed_margin_level_percent", "SPECIFICATION_FIELD_MISSING"))
            stressed_free = float(required(spec, "stressed_free_margin_ratio", "SPECIFICATION_FIELD_MISSING"))
            tick_probe_reported = float(required(spec, "tick_probe_reported", "SPECIFICATION_FIELD_MISSING"))
            tick_probe_calculated = float(required(spec, "tick_probe_calculated", "SPECIFICATION_FIELD_MISSING"))
            live_margin_per_lot = float(required(spec, "live_margin_per_lot", "SPECIFICATION_FIELD_MISSING"))
            hmr_proxy_margin_per_lot = float(required(spec, "hmr_proxy_margin_per_lot", "SPECIFICATION_FIELD_MISSING"))
        except ValueError as exc:
            raise Stage14Error("ACCOUNT_OR_PROBE_FACT_INVALID") from exc
        if balance <= 0 or equity <= 0 or account_leverage <= 0:
            raise Stage14Error("ACCOUNT_FINANCIALS_NOT_SYNCHRONIZED")
        if stressed_level < 500 or stressed_free < 0.80:
            raise Stage14Error("STRESSED_MARGIN_FLOOR_FAILED")
        if live_margin_per_lot <= 0 or hmr_proxy_margin_per_lot <= 0:
            raise Stage14Error("MARGIN_PER_LOT_INVALID")
        probe_tolerance = max(0.01, 0.001 * abs(tick_probe_calculated))
        if abs(tick_probe_reported - tick_probe_calculated) > probe_tolerance:
            raise Stage14Error("TICK_VALUE_PROBE_MISMATCH")

        session_count = int(required(spec, "session_count", "SPECIFICATION_SESSIONS_MISSING"))
        spec_sessions = [required(spec, f"session_{index}", "SPECIFICATION_SESSIONS_MISSING") for index in range(session_count)]
        feasibility_sessions = []
        day_names = ("SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY")
        for day, name in enumerate(day_names):
            index = 0
            while ("trade_session", f"{name}_{index}_from") in feasibility:
                from_text = feasibility[("trade_session", f"{name}_{index}_from")]
                to_text = required(
                    feasibility, ("trade_session", f"{name}_{index}_to"), "FEASIBILITY_SESSIONS_MISSING"
                )
                try:
                    from_hour, from_minute = (int(part) for part in from_text.split(":"))
                    to_hour, to_minute = (int(part) for part in to_text.split(":"))
                except (TypeError, ValueError) as exc:
                    raise Stage14Error("FEASIBILITY_SESSION_INVALID") from exc
                start_second = day * 86400 + from_hour * 3600 + from_minute * 60
                end_second = day * 86400 + to_hour * 3600 + to_minute * 60
                if end_second <= start_second:
                    end_second += 86400
                feasibility_sessions.append(f"{start_second}-{end_second}")
                index += 1
        if spec_sessions != feasibility_sessions:
            raise Stage14Error("CAPTURE_SESSION_MISMATCH")

        swap_mode = int(required(feasibility, ("symbol", "swap_mode"), "SWAP_FACT_MISSING"))
        swap_long = float(required(feasibility, ("symbol", "swap_long"), "SWAP_FACT_MISSING"))
        swap_short = float(required(feasibility, ("symbol", "swap_short"), "SWAP_FACT_MISSING"))
        if swap_mode != 1:
            raise Stage14Error("SWAP_MODE_UNSUPPORTED")
        swap_point_value = numeric_facts["point"] / numeric_facts["tick_size"] * numeric_facts["tick_value"]
        swap_per_lot_day_worst = max(abs(swap_long), abs(swap_short)) * swap_point_value

        accounting_reader = csv.DictReader(io.StringIO(accounting_csv))
        if accounting_reader.fieldnames is None or not {
            "record_type", "server", "position_id", "entry", "symbol", "volume", "commission", "swap", "fee"
        }.issubset(accounting_reader.fieldnames):
            raise Stage14Error("ACCOUNTING_CAPTURE_SCHEMA_INVALID")
        deals = [
            row for row in accounting_reader
            if row.get("record_type") == "DEAL" and row.get("symbol") == "ETHUSD.s"
        ]
        if len(deals) < 2 or any(row.get("server") != "JustMarkets-Demo2" for row in deals):
            raise Stage14Error("COMMISSION_EVIDENCE_INSUFFICIENT")
        try:
            opened = sum(float(row["volume"]) for row in deals if row["entry"] == "0")
            closed = sum(float(row["volume"]) for row in deals if row["entry"] == "1")
            round_turn_volume = min(opened, closed)
            commission_total = sum(abs(float(row["commission"])) for row in deals)
        except (TypeError, ValueError) as exc:
            raise Stage14Error("COMMISSION_EVIDENCE_INVALID") from exc
        if round_turn_volume <= 0:
            raise Stage14Error("COMMISSION_EVIDENCE_INSUFFICIENT")
        commission_per_lot_round_turn = commission_total / round_turn_volume

        canonical = {
            "collector_contract": "REUSED_STAGE8_PREFREEZE_STAGE13",
            "server": "JustMarkets-Demo2",
            "symbol": "ETHUSD.s",
            "specification_hash": required(spec, "specification_hash", "SPECIFICATION_HASH_MISSING"),
            "capture_server_times": {
                "specification": spec["observed_server_time"],
                "feasibility": feasibility_rows[0]["snapshot_server"],
            },
            "evidence_hashes": evidence_hashes,
            "account": {"balance": balance, "equity": equity, "leverage": account_leverage},
            "hmr_proxy_leverage": hmr_proxy_leverage,
            "commission_per_lot_round_turn": commission_per_lot_round_turn,
            "commission_zero_evidence": commission_per_lot_round_turn == 0.0,
            "swap_mode": "POINTS",
            "swap_long": swap_long,
            "swap_short": swap_short,
            "swap_per_lot_day_worst": swap_per_lot_day_worst,
            "stressed_margin_level_percent": stressed_level,
            "stressed_free_margin_ratio": stressed_free,
            "stressed_margin_basis": {
                "volume_lots": numeric_facts["volume_min"],
                "live_margin_per_lot": live_margin_per_lot,
                "hmr_proxy_margin_per_lot": hmr_proxy_margin_per_lot,
                "margin_used": max(live_margin_per_lot, hmr_proxy_margin_per_lot)
                * numeric_facts["volume_min"],
                "calculation_rule": "MAX_OF_LIVE_ORDERCALCMARGIN_AND_1_TO_200_PROXY",
            },
            "session_count": session_count,
            "sessions": spec_sessions,
        }
        return {
            "passed": True,
            **canonical,
            "research_specification_sha256": self.canonical_hash(canonical),
        }

    @staticmethod
    def market_protection(
        *,
        now: str,
        maintenance_start: str,
        maintenance_end: str,
        clean_since: str | None,
    ) -> dict[str, str]:
        current = datetime.fromisoformat(now)
        start = datetime.fromisoformat(maintenance_start)
        end = datetime.fromisoformat(maintenance_end)
        if (
            current.tzinfo is None
            or start.tzinfo is None
            or end.tzinfo is None
            or start >= end
        ):
            raise Stage14Error("MAINTENANCE_FACTS_INVALID")
        if start - timedelta(minutes=5) <= current < end:
            return {"entry": "BLOCK", "exposure": "FLATTEN", "reason": "MAINTENANCE_FORCE_FLAT"}
        if start - timedelta(minutes=30) <= current < start - timedelta(minutes=5):
            return {"entry": "BLOCK", "exposure": "HOLD", "reason": "MAINTENANCE_ENTRY_BLOCK"}
        if end <= current < end + timedelta(minutes=15):
            return {"entry": "BLOCK", "exposure": "HOLD", "reason": "MAINTENANCE_RECOVERY"}
        if current >= end + timedelta(minutes=15):
            if clean_since is None:
                return {"entry": "BLOCK", "exposure": "HOLD", "reason": "MAINTENANCE_CLEAN_PERIOD_UNPROVEN"}
            clean = datetime.fromisoformat(clean_since)
            if clean.tzinfo is None or clean > end or current - clean < timedelta(minutes=15):
                return {"entry": "BLOCK", "exposure": "HOLD", "reason": "MAINTENANCE_CLEAN_PERIOD_UNPROVEN"}
        weekend = current.weekday() in (5, 6)
        return {
            "entry": "ALLOW",
            "exposure": "HOLD",
            "reason": "WEEKEND_HALF_RISK" if weekend else "ALLOW",
        }

    def create_pre_tooling_manifest(
        self,
        paths: Iterable[Path],
        *,
        build_id: str,
        dependency_hashes: Mapping[str, str],
    ) -> dict[str, Any]:
        if not build_id or not dependency_hashes or not all(self._valid_hash(value) for value in dependency_hashes.values()):
            raise Stage14Error("PRE_TOOLING_FACTS_INVALID")
        sources = []
        for source in sorted((Path(path).resolve() for path in paths), key=str):
            if not source.is_file():
                raise Stage14Error("PRE_TOOLING_SOURCE_MISSING")
            sources.append({"path": str(source), "size": source.stat().st_size, "sha256": self.file_hash(source)})
        if not sources:
            raise Stage14Error("PRE_TOOLING_SOURCE_SET_EMPTY")
        manifest = {
            "schema": 1,
            "kind": "PRE_TOOLING",
            "build_id": build_id,
            "sources": sources,
            "dependency_hashes": dict(sorted(dependency_hashes.items())),
        }
        manifest["manifest_sha256"] = self.canonical_hash(manifest)
        return manifest

    def verify_pre_tooling_manifest(self, manifest: Mapping[str, Any]) -> dict[str, Any]:
        stored = manifest.get("manifest_sha256")
        unhashed = {key: value for key, value in manifest.items() if key != "manifest_sha256"}
        if not self._valid_hash(stored) or self.canonical_hash(unhashed) != stored:
            return {"passed": False, "reason": "PRE_TOOLING_MANIFEST_HASH_MISMATCH"}
        mismatches = []
        for record in manifest.get("sources", []):
            path = Path(record["path"])
            if (
                not path.is_file()
                or path.stat().st_size != record["size"]
                or self.file_hash(path) != record["sha256"]
            ):
                mismatches.append(str(path))
        return {
            "passed": not mismatches,
            "reason": "PASS" if not mismatches else "SOURCE_CHANGED_AFTER_PRE_TOOLING",
            "mismatches": mismatches,
        }
