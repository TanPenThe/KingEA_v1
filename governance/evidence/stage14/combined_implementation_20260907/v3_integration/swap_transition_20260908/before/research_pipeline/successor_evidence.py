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

from .decision_a_evidence import (CONTRACT, PACKAGE, SEMANTICS, ADOPTION, INVENTORY_PROTOCOL,
    INVENTORY_ADOPTION, DECISION_A_ADOPTION, DECISION_S_ADOPTION, unique, validate_profile,
    decode_archive, verify_archive, validate_package, hash_value)

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

    def capture_render_inputs(self, expected, manifest):
        """Read-only capture under externally pinned, run-scoped agent Files root.

        The returned bytes, parsed values and emitted digest share one capture.
        A later disk replacement is rejected by the native consumer's hash check.
        This method does not stage files, authorize, or persist a rendered bundle.
        """
        from dataclasses import replace
        from .decision_a_evidence import ImmutableInput, lock_capture_paths
        import re
        try:
            # Never accept a caller-manufactured resolved expectation.
            current = validate(self, manifest, 'render_input_capture')
            require(current == expected, 'RENDER_EXPECTATION_CHANGED')
            authority = current['control']['render_inputs']
            require(isinstance(authority, dict) and set(authority) ==
                    {'storage_scope', 'agent_files_root', 'child_sha256', 'manifest', 'calendar'},
                    'RENDER_INPUT_AUTHORITY_FIELDS')
            require(authority['storage_scope'] == 'AGENT_LOCAL_RUN_SCOPED', 'AGENT_LOCAL_INPUTS_REQUIRED')
            run = current['execution']['child_sha256']
            require(authority['child_sha256'] == run and len(run) == 64 and
                    all(c in '0123456789ABCDEF' for c in run), 'RENDER_INPUT_RUN_MISMATCH')
            root_text = authority['agent_files_root']
            require(isinstance(root_text, str), 'AGENT_FILES_ROOT_INVALID')
            root = Path(root_text)
            require(root.is_absolute() and not root_text.startswith(('\\\\', '//')) and
                    '..' not in root.parts and not any(x.casefold() == 'common' for x in root.parts),
                    'AGENT_FILES_ROOT_INVALID')
            local = root / 'KingEA' / 'runs' / run
            # Reject links/junctions along the full staged path, not only the leaf.
            for component in (local, *local.parents):
                st = component.stat()
                require(not component.is_symlink() and
                        not (getattr(st, 'st_file_attributes', 0) & 0x400), 'INPUT_LINK_FORBIDDEN')
            names = []
            for key in ('manifest', 'calendar'):
                reference = authority[key]
                require(isinstance(reference, dict) and set(reference) == {'path', 'sha256'} and
                        isinstance(reference['path'], str) and
                        re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,127}', reference['path']) is not None,
                        'INPUT_REFERENCE_FIELDS_OR_PATH')
                names.append(local / reference['path'])
            with lock_capture_paths(names):
                captures = {}
                for name in ('manifest', 'calendar'):
                    captures[name] = ImmutableInput.capture(local, authority[name])
                require(captures['manifest'].path != captures['calendar'].path, 'INPUT_ALIAS_FORBIDDEN')
                captured_manifest = captures['manifest'].json()
                require(captured_manifest == dict(manifest), 'CAPTURED_MANIFEST_MISMATCH')
                captures['calendar'].calendar()
                facts = captured_manifest['operational_facts']
                require(facts['calendar_file_sha256'] == captures['calendar'].sha256,
                        'CAPTURED_CALENDAR_BINDING_MISMATCH')
            # The payload path is never opened. Reject disagreement with the pin.
            calendar_path = 'KingEA\\runs\\' + run + '\\' + captures['calendar'].path
            require(facts['calendar_intervals_file'] in (captures['calendar'].path, calendar_path),
                    'PAYLOAD_SELECTED_INPUT_PATH')
            return {name: replace(value, path='KingEA\\runs\\' + run + '\\' + value.path)
                    for name, value in captures.items()}
        except SuccessorEvidenceError as exc:
            raise SuccessorEvidenceError('rendering', exc.detail) from exc
        except (ValueError, KeyError, TypeError, OSError, AttributeError, UnicodeError) as exc:
            raise SuccessorEvidenceError('rendering', str(exc)) from exc

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
            require(binding.get('native_cost_contract') == CONTRACT and
                    binding.get('package_schema') == PACKAGE and binding.get('evidence_semantics') == SEMANTICS and
                    binding.get('filling') == 'ORDER_FILLING_FOK' and
                    binding.get('inventory_protocol') == INVENTORY_PROTOCOL and binding.get('inventory_protocol_sha256') == INVENTORY_ADOPTION and
                    binding.get('combined_specification_sha256') == ADOPTION and
                    binding.get('decision_a_sha256') == DECISION_A_ADOPTION and binding.get('decision_s_sha256') == DECISION_S_ADOPTION,
                    'UNADOPTED_EVIDENCE_SEMANTICS')
            profile = self._read(spec['tester_profile'])
            require(binding.get('tester_profile_sha256') == spec['tester_profile']['sha256'], 'PROFILE_SPECIFICATION_BINDING')
            validate_profile(profile)
            require(profile.get('mql_tester') is True and profile.get('post_entry_sl_mutation') is False and
                    profile.get('alternate_order_sink') is False and profile.get('source_manifest_hash') == binding.get('source_sha256') and
                    profile.get('configuration_hash') == binding.get('configuration_sha256') and hash_value(profile.get('executable_hash')),
                    'CONTROLLED_PROFILE_SOURCE_MISMATCH')
            for key in ('configuration_sha256', 'source_sha256', 'successor_evidence_sha256'):
                v = binding[key]
                require(isinstance(v, str) and len(v) == 64 and all(c in '0123456789ABCDEF' for c in v), 'SPECIFICATION_HASH_INVALID')
            if design_only:
                require(control.get('phase') in ('design', 'execution'), 'UNKNOWN_CONTROL_PHASE')
                return dict(binding=binding, control=control, profile=profile)
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
            return dict(binding=binding, control=control, execution=execution, profile=profile)
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
        references = expected['control'].get('completed_archives', {}).get(
            manifest['manifest_sha256'] + ':' + str(configuration))
        require(type(references) is list and len(references) == len(packages), 'INDEPENDENT_COMPLETED_ARCHIVES_REQUIRED')
        require(len(frame['stage13_close_frames']) == len(packages), 'V3_CLOSE_CARDINALITY_MISMATCH')
        groups=set();roots=set();boundaries=0
        for raw,reference,close_frame in zip(packages,references,frame['stage13_close_frames']):
            seal = context._read(reference)
            scope = dict(run_id=manifest['manifest_sha256'],root_hash=manifest['root_sha256'],candidate_id=expected['binding']['candidate_id'],
                configuration_hash=expected['binding']['configuration_sha256'],branch=manifest['branch'],partition=manifest['partition'],
                source_manifest_hash=expected['binding']['source_sha256'],tester_profile_hash=expected['binding']['tester_profile_sha256'],
                executable_hash=expected['profile']['executable_hash'],freeze_receipt_hash=expected['control']['freeze']['sha256'],
                execution_receipt_hash=expected['control']['execution']['sha256'],specification_hash=ADOPTION,
                decision_a_hash=DECISION_A_ADOPTION,decision_s_hash=DECISION_S_ADOPTION,
                contract_id=CONTRACT,package_id=PACKAGE,semantic_id=SEMANTICS,inventory_protocol_hash=INVENTORY_ADOPTION)
            files=decode_archive(raw)
            sidecar,verified=verify_archive(files,seal,scope)
            financial_scope={k:v for k,v in scope.items() if k not in {'contract_id','package_id','semantic_id','inventory_protocol_hash'}}
            financial_scope['group_id']=seal['binding']['group_id']
            validate_package(files['sidecar.evidence'],financial_scope,expected['profile'],verified)
            group=sidecar['binding']['group_id'];root=sidecar['terminal']['stage13_root']
            require(group not in groups and root not in roots,'DUPLICATE_V3_TERMINAL_PROJECTION')
            require(type(close_frame) is str and close_frame==verified.resolve(root,'STAGE13_EVENT').decode('utf-8'), 'V3_STAGE13_CLOSE_MISMATCH')
            groups.add(group);roots.add(root)
            boundaries+=int(sidecar['terminal']['outcome']=='EVALUATOR_BOUNDARY')
        require(boundaries==frame['boundary_finalization_count'],'MISSING_OR_EXTRA_BOUNDARY_EVIDENCE')
        return expected
    except SuccessorEvidenceError:
        raise
    except (ValueError, KeyError, TypeError, AttributeError, IndexError, UnicodeError, OSError) as exc:
        raise SuccessorEvidenceError(stage, str(exc)) from exc
