"""Immutable, non-result-bearing realization of B2's evaluation windows.

This module deliberately contains no tester, market-data, or candidate code.
It is the one canonical source for the approved half-open partitions and the
inclusive MT5 ``ToDate`` realization used by manifest renderers.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from types import MappingProxyType
from typing import Mapping


class B2DateGateError(ValueError):
    """A fail-closed B2 date-realization violation."""


# Explicit governance table; no renderer may derive a warm-up date heuristically.
_PARTITIONS = {
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
PARTITION_DATE_REALIZATION: Mapping[str, tuple[str, str, str, str]] = MappingProxyType(_PARTITIONS)


def realize_partition_dates(partition: str) -> dict[str, str]:
    """Return the approved, explicit tester and evaluation dates for a partition."""
    try:
        from_date, start, end, to_date = PARTITION_DATE_REALIZATION[partition]
    except KeyError as exc:
        raise B2DateGateError("PARTITION_DATE_REALIZATION_UNKNOWN") from exc
    return {
        "from_date": from_date,
        "evaluation_start": start,
        "evaluation_end_exclusive": end,
        "to_date_inclusive": to_date,
    }


@dataclass(frozen=True)
class EvaluationWindow:
    """The tester-side half-open evaluation gate, expressed without MT5 types."""

    start: datetime
    end_exclusive: datetime

    def __post_init__(self) -> None:
        if self.start.tzinfo != self.end_exclusive.tzinfo or self.start >= self.end_exclusive:
            raise B2DateGateError("EVALUATION_WINDOW_INVALID")

    def classify(self, evaluation_time: datetime, *, has_open_exposure: bool = False) -> str:
        if evaluation_time < self.start:
            return "WARMUP_ONLY"
        if evaluation_time < self.end_exclusive:
            return "ELIGIBLE"
        if has_open_exposure:
            # Frozen governance does not specify a close/carry policy here.
            return "UNRESOLVED_END_EXPOSURE_POLICY"
        return "POST_END_BLOCKED"

    def pending_outcome(self, signal_time: datetime, execution_time: datetime) -> str:
        if signal_time < self.start:
            return "WARMUP_ONLY"
        if execution_time >= self.end_exclusive:
            return "DELAY_EXPIRY_AT_EVALUATION_END"
        return "EXECUTION_TIME_ELIGIBLE"

    def requires_quarantine_at_end(self, *, has_open_exposure: bool) -> bool:
        return has_open_exposure

    def terminal_outcome(
        self,
        *,
        has_open_position: bool,
        has_pending_execution: bool,
        has_trade_group: bool,
    ) -> str:
        """Return the terminal-only end check, independent of later ticks.

        A tester may stop on its final eligible tick.  The absence of a
        post-end tick is therefore not evidence that an open group was
        resolved.  This mirrors the tester's fail-closed OnTester guard; it
        does not introduce an evaluator-forced liquidation policy.
        """
        if has_open_position or has_pending_execution or has_trade_group:
            return "TERMINAL_END_UNRESOLVED_EXPOSURE_FAIL_CLOSED"
        return "TERMINAL_END_FLAT_ALLOWED"


def normal_b2_execution_locks() -> Mapping[str, object]:
    """The only permitted normal Candidate execution shape, still non-executable."""
    return MappingProxyType(
        {
            "diagnostic_mode": False,
            "workload_dry_run": False,
            "execution_adapter": "NATIVE",
            "execution_mode": 20,
            "virtual_adapter_allowed": False,
            "normal_stage13_accounting_only": True,
            "synthetic_routing_allowed": False,
        }
    )
