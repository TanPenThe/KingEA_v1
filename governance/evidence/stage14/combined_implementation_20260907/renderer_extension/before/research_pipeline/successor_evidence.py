"""Successor evidence enforcement. No runtime, orders, pricing or financial booking.

The control directory and pin are injected by the independent control plane.
Never construct them from a manifest/bundle. No default production pin exists.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
from typing import Mapping

from .native_cost_archive import NativeCostArchiveConsumer, COST, MTM, unique

REJECTION = 'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED'


class SuccessorEvidenceError(ValueError):
    def __init__(self, stage, detail):
        super().__init__(REJECTION)
        self.stage, self.detail = stage, detail


def canonical_hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                    ensure_ascii=False).encode()).hexdigest().upper()


def require(ok, detail):
    if not ok:
        raise ValueError(detail)


@dataclass(frozen=True)
class PinnedControlContext:
    directory: Path
    control_sha256: str

    def _read(self, reference):
        require(isinstance(reference, dict) and set(reference) == {'path', 'sha256'}, 'INVALID_CONTROL_REFERENCE')
        name = reference['path']
        require(isinstance(name, str) and name not in ('', '.', '..') and
                '/' not in name and '\\' not in name and ':' not in name, 'CONTROL_REFERENCE_PATH')
        directory = Path(self.directory)
        path = directory / name
        require(not directory.is_symlink() and not path.is_symlink(), 'CONTROL_LINK_NOT_ALLOWED')
        require(path.stat().st_size <= 1024 * 1024, 'CONTROL_RECORD_TOO_LARGE')
        raw = path.read_bytes()
        require(hashlib.sha256(raw).hexdigest().upper() == reference['sha256'], 'PINNED_CONTROL_HASH_MISMATCH')
        value = json.loads(raw.decode('utf-8'), object_pairs_hook=unique)
        require(isinstance(value, dict), 'CONTROL_OBJECT_REQUIRED')
        return value

    def resolve(self, stage, *, design_only=False):
        try:
            control = self._read(dict(path='control.json', sha256=self.control_sha256))
            require(control.get('kind') == 'INDEPENDENT_SUCCESSOR_CONTROL' and control.get('active') is True,
                    'UNRECOGNIZED_OR_INACTIVE_CONTROL')
            spec = self._read(control['specification'])
            review = self._read(control['review'])
            require(spec.get('kind') == 'REVIEWED_SUCCESSOR_SPECIFICATION' and
                    review.get('kind') == 'INDEPENDENT_SPECIFICATION_REVIEW' and review.get('accepted') is True and
                    review.get('specification_sha256') == control['specification']['sha256'], 'SPECIFICATION_NOT_INDEPENDENTLY_REVIEWED')
            binding = spec['binding']
            require(binding.get('candidate_id') == 'CAND-ETH-ST-002', 'SUCCESSOR_IDENTITY_REQUIRED')
            require(binding.get('native_cost_contract') == 'NATIVE_COST_BOUNDARY_V2' and
                    binding.get('package_schema') == 'NATIVE_COST_BOUNDARY_PACKAGE_V2' and
                    binding.get('evidence_semantics') == 'WHOLE_POSITION_V2' and
                    binding.get('filling') == 'ORDER_FILLING_FOK' and
                    binding.get('metadata_policy_sha256') == COST and binding.get('boundary_policy_sha256') == MTM,
                    'UNADOPTED_EVIDENCE_SEMANTICS')
            for key in ('configuration_sha256', 'source_sha256', 'successor_evidence_sha256'):
                v = binding[key]
                require(isinstance(v, str) and len(v) == 64 and all(c in '0123456789ABCDEF' for c in v), 'SPECIFICATION_HASH_INVALID')
            if design_only:
                require(control.get('phase') in ('design', 'execution'), 'UNKNOWN_CONTROL_PHASE')
                return dict(binding=binding, control=control)
            require(control.get('phase') == 'execution', 'EXECUTION_AUTHORITY_REQUIRED')
            freeze = self._read(control['freeze'])
            execution = self._read(control['execution'])
            require(freeze.get('kind') == 'OWNER_SUCCESSOR_FREEZE' and freeze.get('owner_approved') is True and
                    freeze.get('candidate_id') == binding['candidate_id'] and
                    freeze.get('specification_sha256') == control['specification']['sha256'], 'FREEZE_RECEIPT_MISMATCH')
            require(execution.get('kind') == 'OWNER_SUCCESSOR_GATE1_EXECUTION' and execution.get('owner_approved') is True and
                    execution.get('candidate_id') == binding['candidate_id'] and execution.get('gate') == 'GATE1' and
                    execution.get('specification_sha256') == control['specification']['sha256'] and
                    execution.get('freeze_receipt_sha256') == control['freeze']['sha256'], 'EXECUTION_RECEIPT_MISMATCH')
            return dict(binding=binding, control=control, execution=execution)
        except (ValueError, KeyError, TypeError, OSError, AttributeError) as exc:
            raise SuccessorEvidenceError(stage, str(exc)) from exc


def validate(context, manifest, stage, authorization=None, *, design_only=False):
    try:
        require(type(context) is PinnedControlContext, 'INDEPENDENT_CONTROL_CONTEXT_REQUIRED')
        expected = context.resolve(stage, design_only=design_only)
        require(isinstance(manifest, Mapping), 'BINDING_OBJECT_REQUIRED')
        require(not any(k.startswith('historical_') or k in ('trusted_expectation', 'control_context', 'trust_store',
                    'control_path', 'control_sha256') for k in manifest), 'PAYLOAD_SELECTED_TRUST_OR_HISTORICAL_FALLBACK')
        for key, value in expected['binding'].items():
            require(manifest.get(key) == value, 'BINDING_MISMATCH:' + key)
        if design_only:
            return expected
        execution = expected['execution']
        require(manifest.get('gate') == 'GATE1' and manifest.get('root_sha256') == execution['root_sha256'], 'EXECUTION_SCOPE_MISMATCH')
        require(manifest.get('manifest_sha256') == execution['child_sha256'] ==
                canonical_hash({k: v for k, v in manifest.items() if k != 'manifest_sha256'}), 'EXECUTION_CHILD_MISMATCH')
        if authorization is not None or stage in ('authorization', 'rendering'):
            require(isinstance(authorization, Mapping) and authorization.get('owner_approved') is True,
                    'SUPPLIED_AUTHORIZATION_REQUIRED')
            for key, value in dict(gate='GATE1',root_sha256=execution['root_sha256'],
                    child_sha256=execution['child_sha256'],freeze_receipt_sha256=expected['control']['freeze']['sha256'],
                    execution_receipt_sha256=expected['control']['execution']['sha256']).items():
                require(authorization.get(key) == value, 'AUTHORIZATION_COPY_MISMATCH:' + key)
        return expected
    except SuccessorEvidenceError:
        raise
    except (ValueError, KeyError, TypeError, AttributeError) as exc:
        raise SuccessorEvidenceError(stage, str(exc)) from exc


def validate_frame(context, manifest, frame, stage):
    expected = validate(context, manifest, stage)
    try:
        require(isinstance(frame, Mapping) and frame.get('complete') == 1, 'INCOMPLETE_EVIDENCE_FRAME')
        require(isinstance(frame.get('authorization_binding'), Mapping), 'FRAME_AUTHORIZATION_BINDING_REQUIRED')
        validate(context, manifest, stage, frame['authorization_binding'])
        require(frame.get('evidence_binding') == expected['binding'], 'FRAME_EVIDENCE_BINDING_MISMATCH')
        configuration = frame['configuration_id']
        require(type(configuration) is int and manifest['configuration_start'] <= configuration <= manifest['configuration_end'],
                'CONFIGURATION_SCOPE_MISMATCH')
        require(type(frame['boundary_finalization_count']) is int and frame['boundary_finalization_count'] >= 0,
                'BOUNDARY_COUNT_INVALID')
        packages = frame['native_cost_packages']
        require(isinstance(packages, list) and isinstance(frame['stage13_close_frames'], list), 'EVIDENCE_COLLECTION_REQUIRED')
        for raw in packages:
            text = raw.decode('utf-8') if isinstance(raw, bytes) else raw
            package = json.loads(text.rsplit('|sha256=', 1)[0], object_pairs_hook=unique)
            require(set(package) == {'schema','run','configuration','branch','partition','group','boundary_finalization_count',
                'candidate_exit_count_delta','records','housekeeping_evidence','sidecar','stage13_frame','stage13_canonical'},
                'UNADOPTED_PACKAGE_FIELDS_OR_RESIDUAL_SEMANTICS')
            financial = package['stage13_canonical'].split('|')
            require(len(financial) == 39 and financial[7] == expected['binding']['candidate_id'] and
                    financial[8] == expected['binding']['configuration_sha256'], 'FINANCIAL_IDENTITY_BINDING_MISMATCH')
        NativeCostArchiveConsumer.validate_packages(packages,
            dict(run=manifest['manifest_sha256'],configuration=configuration,branch=manifest['branch'],partition=manifest['partition'],
                 package_schema=expected['binding']['package_schema']),
            boundary_count=frame['boundary_finalization_count'],close_frames=frame['stage13_close_frames'])
        return expected
    except SuccessorEvidenceError:
        raise
    except (ValueError, KeyError, TypeError, AttributeError, IndexError, UnicodeError) as exc:
        raise SuccessorEvidenceError(stage, str(exc)) from exc
