"""Explicit authority and scope bindings for retired historical audit.

This module deliberately grants no production capability.  Its scope objects
can only unlock retained integrity checks exposed by the dedicated audit
adapters in :mod:`gate1_finalization` and :mod:`stage14`.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Mapping


RETIRED_HISTORICAL_AUDIT_ONLY = "RETIRED_HISTORICAL_AUDIT_ONLY"
READ_ONLY_INTEGRITY_VERIFICATION = "READ_ONLY_INTEGRITY_VERIFICATION"


class HistoricalAuditIntegrityError(ValueError):
    """A historical audit scope or record binding is invalid."""


@dataclass(frozen=True)
class HistoricalAuditScope:
    scope_id: str
    schema_version: int
    record_identity: str
    mode: str = RETIRED_HISTORICAL_AUDIT_ONLY
    authority: str = READ_ONLY_INTEGRITY_VERIFICATION


_KNOWN_SCOPES: Mapping[str, Mapping[str, Any]] = {
    "CANDIDATE_001_GATE1_RETIRED": {"schema_version": 1, "target": "gate1"},
    "RETIRED_GATE1_TEST_FIXTURE": {"schema_version": 1, "target": "gate1"},
    "RETIRED_STAGE14_FRAME_V2_TEST_FIXTURE": {
        "schema_version": 2,
        "target": "stage14_frames",
    },
    "RETIRED_NATIVE_COST_FRAME_V2": {
        "schema_version": 2,
        "target": "stage14_frames",
    },
}

_RECORD_IDENTITY = re.compile(r"^[A-Z0-9][A-Z0-9._:-]{0,127}$")


def validate_scope(scope: HistoricalAuditScope, target: str) -> None:
    if not isinstance(scope, HistoricalAuditScope):
        raise HistoricalAuditIntegrityError("HISTORICAL_AUDIT_SCOPE_REQUIRED")
    definition = _KNOWN_SCOPES.get(scope.scope_id)
    if definition is None:
        raise HistoricalAuditIntegrityError("HISTORICAL_AUDIT_SCOPE_UNKNOWN")
    if (
        scope.mode != RETIRED_HISTORICAL_AUDIT_ONLY
        or scope.authority != READ_ONLY_INTEGRITY_VERIFICATION
        or scope.schema_version != definition["schema_version"]
        or target != definition["target"]
        or not _RECORD_IDENTITY.fullmatch(scope.record_identity)
        or "LATEST" in scope.record_identity
    ):
        raise HistoricalAuditIntegrityError("HISTORICAL_AUDIT_SCOPE_MISMATCH")


def bind_record(scope: HistoricalAuditScope, actual_record_identity: str) -> None:
    if scope.record_identity != actual_record_identity:
        raise HistoricalAuditIntegrityError("HISTORICAL_AUDIT_RECORD_MISMATCH")


def capability_statement(scope: HistoricalAuditScope) -> dict[str, Any]:
    return {
        "mode": scope.mode,
        "authority": scope.authority,
        "scope_id": scope.scope_id,
        "schema_version": scope.schema_version,
        "record_identity": scope.record_identity,
        "capabilities": {
            "integrity_verification": True,
            "authorization": False,
            "running_eligibility": False,
            "executable_rendering": False,
            "research_root_creation": False,
            "candidate_creation_or_freeze": False,
            "selection_or_ranking": False,
            "gate2_preparation": False,
            "budget_consumption": False,
            "successor_evidence_satisfaction": False,
            "production_fallback": False,
        },
    }


class RetiredHistoricalGate1Audit:
    """Explicit audit-only access to retained Gate 1 integrity checks."""

    def __init__(self, scope: HistoricalAuditScope):
        validate_scope(scope, "gate1")
        from .gate1_finalization import (
            Gate1Finalizer,
            _RETIRED_HISTORICAL_AUDIT_CAPABILITY,
        )

        self._scope = scope
        self._finalizer = Gate1Finalizer(
            _historical_audit_capability=_RETIRED_HISTORICAL_AUDIT_CAPABILITY
        )

    @property
    def specification(self) -> dict[str, Any]:
        return capability_statement(self._scope)

    def _bind(self, request: Any) -> None:
        from pathlib import Path
        from .gate1_finalization import Gate1Finalizer

        bind_record(self._scope, Gate1Finalizer.historical_record_identity(request))
        prior = self._finalizer._read(
            Path(request.prior_package) / "GATE1_ROOT.json"
        )
        continuation = self._finalizer._read(
            Path(request.continuation_package) / "GATE1_ROOT.json"
        )
        candidates = {prior.get("candidate_id"), continuation.get("candidate_id")}
        if self._scope.scope_id == "RETIRED_GATE1_TEST_FIXTURE":
            if not request.allow_test_fixture or candidates != {"TEST-CANDIDATE"}:
                raise HistoricalAuditIntegrityError(
                    "HISTORICAL_AUDIT_SCOPE_MISMATCH"
                )
        elif candidates != {"CAND-ETH-ST-001"}:
            raise HistoricalAuditIntegrityError("HISTORICAL_AUDIT_SCOPE_MISMATCH")

    def finalize(self, request: Any) -> dict[str, Any]:
        self._bind(request)
        return self._finalizer.finalize(request)

    def audit_batch(
        self, request: Any, shard_root: Any, batch_id: int, *, batch_size: int = 20
    ) -> dict[str, Any]:
        self._bind(request)
        return self._finalizer.audit_batch(
            request, shard_root, batch_id, batch_size=batch_size
        )

    def merge_batches(
        self, request: Any, shard_root: Any, *, batch_size: int = 20
    ) -> dict[str, Any]:
        self._bind(request)
        return self._finalizer.merge_batches(
            request, shard_root, batch_size=batch_size
        )

    def batch_status(
        self, request: Any, shard_root: Any, *, batch_size: int = 20
    ) -> dict[str, Any]:
        self._bind(request)
        return self._finalizer.batch_status(
            request, shard_root, batch_size=batch_size
        )


class RetiredHistoricalFrameAudit:
    """Audit retained frame sequencing, cardinality and package integrity."""

    def __init__(self, scope: HistoricalAuditScope):
        validate_scope(scope, "stage14_frames")
        from .stage14 import ResearchRunCoordinator

        self._scope = scope
        self._coordinator = ResearchRunCoordinator()

    @property
    def specification(self) -> dict[str, Any]:
        return capability_statement(self._scope)

    def _bind(self, manifest: Mapping[str, Any]) -> None:
        bind_record(self._scope, str(manifest.get("manifest_sha256", "")))
        if (
            manifest.get("candidate_id") not in (None, "CAND-ETH-ST-001")
            or "successor_evidence_declaration" in manifest
            or "successor_evidence_contract" in manifest
        ):
            raise HistoricalAuditIntegrityError("HISTORICAL_AUDIT_SCOPE_MISMATCH")

    def append_frame(
        self, spool: Any, manifest: Mapping[str, Any], frame: Mapping[str, Any]
    ) -> dict[str, Any]:
        self._bind(manifest)
        return self._coordinator._append_integrity_frame(
            spool, manifest, frame, audit_only=True
        )

    def finalize_frames(
        self, spool: Any, manifest: Mapping[str, Any]
    ) -> dict[str, Any]:
        self._bind(manifest)
        return self._coordinator._finalize_integrity_frames(
            spool,
            manifest,
            finalization_stage="normal_finalization",
            audit_only=True,
        )
