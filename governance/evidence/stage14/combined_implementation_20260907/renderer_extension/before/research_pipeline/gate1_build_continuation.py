"""Pure preparation gate for continuing Gate 1 across an MT5 build change.

The module cannot launch MT5 or authorize research.  It accepts only the
registered build-6090 evidence prefix and the governed build-6140 parity PASS,
then materializes a new, owner-unapproved Gate 1 root and child set.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any, Mapping, Sequence

from .stage14 import ResearchRunCoordinator


class BuildContinuationError(ValueError):
    """A build-continuation governance contract violation."""


class Gate1BuildContinuation:
    PRIOR_ROOT_SHA256 = "04AB5A4F1F2E078ACAEE0370ED23F22FB3C4FF872309231F69A2BFD5FF8BA795"
    PARITY_ROOT_SHA256 = "6ACD4F8AA23662766F90A996F2391EFDF1388B17BDA7C51BA897C2847F6700F3"
    PARITY_RESULT_SHA256 = "462B8DB87D53CD072360D21333ED33E5DC71053378E560F04BEB1891ABE5F7B6"
    NEW_TERMINAL_SHA256 = "DFD977C2885EA3C92BB4E3A5A33FAF677283F4C51C2BAA0142C393A4EE11B8F2"
    PRIOR_BUILD = 6090
    NEW_BUILD = 6140
    COMPLETED_COUNT = 120
    PACKAGE_RELATIVE = "governance/evidence/stage14/gate1_continuation_20260824_v2"
    EXPECTED_COMPARISONS = {
        "BP-0000-B6140": "G1-0000",
        "BP-0039-B6140": "G1-0039",
        "BP-0080-B6140": "G1-0080",
        "BP-0119-B6140": "G1-0119",
    }

    @staticmethod
    def canonical_hash(value: Any) -> str:
        encoded = json.dumps(
            value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest().upper()

    @staticmethod
    def encoded_json(value: Mapping[str, Any]) -> bytes:
        return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")

    @staticmethod
    def _valid_hash(value: Any) -> bool:
        if not isinstance(value, str) or len(value) != 64:
            return False
        try:
            int(value, 16)
        except ValueError:
            return False
        return True

    def _validate_prior_root(self, root: Mapping[str, Any]) -> None:
        stored = str(root.get("root_sha256", "")).upper()
        unhashed = {key: value for key, value in root.items() if key != "root_sha256"}
        if (
            stored != self.PRIOR_ROOT_SHA256
            or self.canonical_hash(unhashed) != stored
            or root.get("gate") != 1
            or root.get("mt5_build") != self.PRIOR_BUILD
            or root.get("launch_count") != 200
            or root.get("configuration_pass_count") != 194_400
            or root.get("candidate_budget_before") != 1
            or root.get("candidate_budget_transition") != "ALREADY_CONSUMED"
        ):
            raise BuildContinuationError("PRIOR_ROOT_NOT_ACCEPTABLE")

    def _validate_parity(self, result: Mapping[str, Any]) -> None:
        stored = str(result.get("result_sha256", "")).upper()
        unhashed = {key: value for key, value in result.items() if key != "result_sha256"}
        comparisons = result.get("comparisons")
        if (
            stored != self.PARITY_RESULT_SHA256
            or self.canonical_hash(unhashed) != stored
            or result.get("status") != "PASS"
            or result.get("parity_root_sha256") != self.PARITY_ROOT_SHA256
            or result.get("prior_mt5_build") != self.PRIOR_BUILD
            or result.get("new_mt5_build") != self.NEW_BUILD
            or result.get("new_terminal_sha256") != self.NEW_TERMINAL_SHA256
            or result.get("selection_eligible") is not False
            or result.get("candidate_budget_increment") != 0
            or result.get("continuation_authorized") is not False
            or not isinstance(comparisons, list)
            or len(comparisons) != len(self.EXPECTED_COMPARISONS)
        ):
            raise BuildContinuationError("PARITY_RESULT_NOT_ACCEPTABLE")
        observed: dict[str, str] = {}
        for comparison in comparisons:
            parity_run = str(comparison.get("parity_run_id", ""))
            observed[parity_run] = str(comparison.get("reference_run_id", ""))
            if (
                comparison.get("status") != "PASS"
                or int(comparison.get("compared_frames", 0)) <= 0
                or not self._valid_hash(comparison.get("parity_archive_sha256"))
                or not self._valid_hash(comparison.get("substantive_frame_set_sha256"))
            ):
                raise BuildContinuationError("PARITY_COMPARISON_NOT_ACCEPTABLE")
        if observed != self.EXPECTED_COMPARISONS:
            raise BuildContinuationError("PARITY_COMPARISON_SET_CHANGED")

    def prepare(
        self,
        *,
        prior_root: Mapping[str, Any],
        parity_result: Mapping[str, Any],
        completed_run_ids: Sequence[str],
        completed_evidence_inventory_sha256: str,
        continuation_pre_tooling_sha256: str,
    ) -> dict[str, Any]:
        self._validate_prior_root(prior_root)
        self._validate_parity(parity_result)
        completed = list(completed_run_ids)
        expected = [f"G1-{number:04d}" for number in range(self.COMPLETED_COUNT)]
        if completed != expected:
            raise BuildContinuationError("COMPLETED_PREFIX_NOT_EXACT")
        if not self._valid_hash(completed_evidence_inventory_sha256):
            raise BuildContinuationError("COMPLETED_EVIDENCE_INVENTORY_HASH_INVALID")
        if not self._valid_hash(continuation_pre_tooling_sha256):
            raise BuildContinuationError("CONTINUATION_PRE_TOOLING_HASH_INVALID")

        archive_rows = [
            {
                "parity_run_id": row["parity_run_id"],
                "reference_run_id": row["reference_run_id"],
                "parity_archive_sha256": row["parity_archive_sha256"],
                "substantive_frame_set_sha256": row["substantive_frame_set_sha256"],
                "compared_frames": row["compared_frames"],
            }
            for row in parity_result["comparisons"]
        ]
        root = {
            key: json.loads(json.dumps(value))
            for key, value in prior_root.items()
            if key != "root_sha256"
        }
        root["mt5_build"] = self.NEW_BUILD
        root["build_transition"] = {
            "schema": 1,
            "kind": "GATE1_MT5_BUILD_CONTINUATION",
            "prior_root_sha256": self.PRIOR_ROOT_SHA256,
            "prior_mt5_build": self.PRIOR_BUILD,
            "new_mt5_build": self.NEW_BUILD,
            "new_terminal_sha256": self.NEW_TERMINAL_SHA256,
            "parity_root_sha256": self.PARITY_ROOT_SHA256,
            "parity_result_sha256": self.PARITY_RESULT_SHA256,
            "parity_archive_set_sha256": self.canonical_hash(archive_rows),
            "accepted_completed_count": self.COMPLETED_COUNT,
            "accepted_completed_prefix_sha256": self.canonical_hash(completed),
            "completed_evidence_inventory_sha256": completed_evidence_inventory_sha256.upper(),
            "continuation_pre_tooling_sha256": continuation_pre_tooling_sha256.upper(),
            "resume_run_id": f"G1-{self.COMPLETED_COUNT:04d}",
            "candidate_budget_increment": 0,
            "selection_eligible": False,
            "oos_authorized": False,
            "holdout_authorized": False,
        }
        root["root_sha256"] = self.canonical_hash(root)

        coordinator = ResearchRunCoordinator()
        children = coordinator.materialize_children(root)
        rows = []
        for child in children:
            relative = f"{self.PACKAGE_RELATIVE}/children/{child['run_id']}.json"
            rows.append(
                {
                    "run_id": child["run_id"],
                    "manifest_sha256": child["manifest_sha256"],
                    "path": relative,
                    "file_sha256": hashlib.sha256(self.encoded_json(child)).hexdigest().upper(),
                }
            )
        index = {
            "schema": 1,
            "kind": "GATE1_CHILD_INDEX",
            "root_sha256": root["root_sha256"],
            "child_count": len(rows),
            "children": rows,
        }
        index["index_sha256"] = self.canonical_hash(index)
        statement = (
            "I explicitly approve Gate 1 continuation root "
            f"{root['root_sha256']} for exhaustive development continuation from "
            f"G1-{self.COMPLETED_COUNT:04d} after MT5 build {self.NEW_BUILD} parity PASS."
        )
        approval_packet = {
            "schema": 1,
            "kind": "GATE1_CONTINUATION_OWNER_APPROVAL_PACKET",
            "owner_approved": False,
            "root_sha256": root["root_sha256"],
            "required_owner_statement": statement,
            "resume_run_id": f"G1-{self.COMPLETED_COUNT:04d}",
            "accepted_completed_count": self.COMPLETED_COUNT,
            "candidate_budget_increment": 0,
            "oos_authorized": False,
            "holdout_authorized": False,
        }
        return {
            "root": root,
            "children": children,
            "index": index,
            "approval_packet": approval_packet,
        }
