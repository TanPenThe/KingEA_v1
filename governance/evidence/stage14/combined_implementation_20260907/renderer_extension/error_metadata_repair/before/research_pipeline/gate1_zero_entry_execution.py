"""Bounded manifest/bundle builder for the approved all-zero Gate 1 diagnosis.

This module deliberately has no process-launching capability.  It can create
only two virtual, no-return development diagnostic bundles for configuration
7168.  A separate foreground operation may consume its immutable output.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Mapping


class Gate1ZeroEntryExecutionError(ValueError):
    """Raised for any diagnostic manifest or bundle boundary violation."""


class Gate1ZeroEntryExecution:
    ROOT_SHA256 = "B17EA4E5AA3A6D823B522252D5997F63BC8C0A6CD620C0DDDBA26851E194185D"
    PREPARED_ROOT_SHA256 = "E6DF7102062DDA44A4B9907C4FA19CBC3A62507F91BB24D62A5B0457B4097EE7"
    CONFIGURATION_ID = 7168
    PARTITION = "FOLD_1_TRAIN"
    DATES = ("2021.07.01", "2023.01.01")
    BRANCHES = ("RECORDED", "RSB3")

    @staticmethod
    def canonical_hash(value: Mapping[str, Any]) -> str:
        return hashlib.sha256(
            json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest().upper()

    @staticmethod
    def file_hash(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest().upper()

    @staticmethod
    def _hash(value: Any) -> str:
        if not isinstance(value, str) or len(value) != 64:
            raise Gate1ZeroEntryExecutionError("DIAGNOSTIC_HASH_INVALID")
        if any(character not in "0123456789ABCDEF" for character in value.upper()):
            raise Gate1ZeroEntryExecutionError("DIAGNOSTIC_HASH_INVALID")
        return value.upper()

    def build_plan(self, reference: Mapping[str, Any], output_root: Path) -> dict[str, Any]:
        hashes = reference.get("artifact_hashes")
        operational = reference.get("operational_facts")
        if not isinstance(hashes, Mapping) or not isinstance(operational, Mapping):
            raise Gate1ZeroEntryExecutionError("REFERENCE_FACTS_INVALID")
        calendar_hash = self._hash(hashes.get("calendar"))
        cost_hash = self._hash(hashes.get("cost"))
        specification_hash = self._hash(hashes.get("research_specification"))
        account = self._hash(reference.get("account_fingerprint"))
        if int(reference.get("mt5_build", 0)) != 6140:
            raise Gate1ZeroEntryExecutionError("TERMINAL_BUILD_REFERENCE_INVALID")
        if str(operational.get("calendar_file_sha256", "")).upper() != calendar_hash:
            raise Gate1ZeroEntryExecutionError("CALENDAR_REFERENCE_MISMATCH")
        if float(operational.get("weekend_risk_multiplier", 0)) != 0.5:
            raise Gate1ZeroEntryExecutionError("WEEKEND_RISK_REFERENCE_INVALID")

        children = []
        for branch in self.BRANCHES:
            expected_symbol = "ETHUSD.s" if branch == "RECORDED" else "KINGEA_ETHUSD_S_RSB3"
            child = {
                "schema": 1,
                "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_EXECUTION_CHILD",
                "diagnostic_root_sha256": self.ROOT_SHA256,
                "prepared_root_sha256": self.PREPARED_ROOT_SHA256,
                "candidate_id": "CAND-ETH-ST-001",
                "configuration_id": self.CONFIGURATION_ID,
                "purpose": "GATE1_ZERO_ENTRY_DIAGNOSTIC",
                "partition": self.PARTITION,
                "branch": branch,
                "expected_symbol": expected_symbol,
                "from_date": self.DATES[0],
                "to_date": self.DATES[1],
                "execution_adapter": "VIRTUAL",
                "execution_mode": 20,
                "tester_model": 4,
                "local_agents_only": True,
                "remote_agents_disabled": True,
                "cloud_agents_disabled": True,
                "orders_authorized": False,
                "returns_authorized": False,
                "oos_authorized": False,
                "holdout_authorized": False,
                "ranking_authorized": False,
                "account_fingerprint": account,
                "mt5_build": 6140,
                "calendar_sha256": calendar_hash,
                "cost_manifest_sha256": cost_hash,
                "research_specification_sha256": specification_hash,
                "calendar_intervals_file": str(operational["calendar_intervals_file"]),
                "commission_per_lot_round_turn": float(operational["commission_per_lot_round_turn"]),
                "swap_per_lot_stress": float(operational["swap_per_lot_stress"]),
                "weekend_risk_multiplier": 0.5,
                "maintenance_entry_block_minutes": 30,
                "maintenance_force_flat_minutes": 5,
                "maintenance_clean_minutes": 15,
                "output_root": str(Path(output_root).resolve()),
            }
            child["manifest_sha256"] = self.canonical_hash(child)
            child["authorization_token"] = hashlib.sha256(
                f"{self.ROOT_SHA256}|{child['manifest_sha256']}|GATE1_ZERO_ENTRY_DIAGNOSTIC|AUTHORIZED".encode("utf-8")
            ).hexdigest().upper()
            children.append(child)
        return {
            "schema": 1,
            "kind": "GATE1_ZERO_ENTRY_DIAGNOSTIC_EXECUTION_PLAN",
            "status": "OWNER_APPROVED_PENDING_EXECUTION",
            "diagnostic_root_sha256": self.ROOT_SHA256,
            "prepared_root_sha256": self.PREPARED_ROOT_SHA256,
            "candidate_budget_increment": 0,
            "children": children,
        }

    def render_bundle(self, child: Mapping[str, Any]) -> dict[str, str]:
        if (
            child.get("diagnostic_root_sha256") != self.ROOT_SHA256
            or child.get("configuration_id") != self.CONFIGURATION_ID
            or child.get("execution_adapter") != "VIRTUAL"
            or child.get("orders_authorized") is not False
            or child.get("returns_authorized") is not False
        ):
            raise Gate1ZeroEntryExecutionError("DIAGNOSTIC_BUNDLE_SCOPE_INVALID")
        lines = [
            "; Generated from the approved, no-order zero-entry diagnostic child.",
            f"InpRunManifest=KingEA\\runs\\{child['manifest_sha256']}.json",
            f"InpManifestSha256={child['manifest_sha256']}",
            "InpManifestFileSha256=SET_AT_EXECUTION",
            f"InpDiagnosticRootSha256={self.ROOT_SHA256}",
            f"InpDiagnosticAuthorizationToken={child['authorization_token']}",
            f"InpRootSha256={self.ROOT_SHA256}",
            "InpZeroEntryDiagnostic=true",
            "InpWorkloadDryRun=false",
            "InpGate=1",
            "InpPurpose=GATE1_ZERO_ENTRY_DIAGNOSTIC",
            "InpPartition=FOLD_1_TRAIN",
            f"InpBranch={child['branch']}",
            f"InpExpectedSymbol={child['expected_symbol']}",
            # This is a single fixed diagnostic pass, never a parameter
            # search. Its payload is persisted directly by the tester EA.
            "InpConfigurationId=7168",
            "InpTesterModel=4",
            "InpLocalAgentsOnly=true",
            "InpRemoteAgentsDisabled=true",
            "InpCloudAgentsDisabled=true",
            "InpScenario=ZERO_ENTRY_FUNNEL",
            "InpExecutionAdapter=VIRTUAL",
            "InpDelayMs=0",
            "InpSpreadMultiplier=1.0",
            "InpCostMultiplier=1.0",
            "InpSlippageSpreadFraction=0.0",
            "InpVolatilityDependentSlippage=false",
            "InpMissedEntryFraction=0.0",
            "InpStressSeed=0",
            f"InpCalendarSha256={child['calendar_sha256']}",
            f"InpCostManifestSha256={child['cost_manifest_sha256']}",
            f"InpResearchSpecificationSha256={child['research_specification_sha256']}",
            f"InpCalendarIntervalsFile={child['calendar_intervals_file']}",
            f"InpCalendarFileSha256={child['calendar_sha256']}",
            f"InpCommissionPerLotRoundTurn={child['commission_per_lot_round_turn']}",
            f"InpSwapPerLotStress={child['swap_per_lot_stress']}",
            "InpWeekendRiskMultiplier=0.5",
            "InpMaintenanceEntryBlockMinutes=30",
            "InpMaintenanceForceFlatMinutes=5",
            "InpMaintenanceCleanMinutes=15",
        ]
        ini = "\n".join(
            [
                "[Tester]",
                "Expert=KingEA\\GuardedResearchTester.ex5",
                f"ExpertParameters={child['manifest_sha256']}.set",
                f"Symbol={child['expected_symbol']}",
                "Period=M30",
                "Model=4",
                "ExecutionMode=20",
                "Optimization=0",
                "UseLocal=1",
                "UseRemote=0",
                "UseCloud=0",
                "Genetic=0",
                "Deposit=1000",
                "Currency=USD",
                f"FromDate={child['from_date']}",
                f"ToDate={child['to_date']}",
                "ShutdownTerminal=1",
                "",
            ]
        )
        return {"set": "\n".join(lines) + "\n", "ini": ini}
