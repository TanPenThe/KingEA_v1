"""Read-only retained-artifact validation for non-Candidate native cost proofs."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ACCOUNTING_V1_SHA256='2B88475645AC23207D9A4227A676E89E8D6D58C9753FAE12BF1C8496CA839D9D'
def digest(data): return hashlib.sha256(data).hexdigest().upper()
def verify(root: Path) -> dict:
    root=root.resolve()
    inventory=json.loads((root/'SEALED_INVENTORY.json').read_text())
    expected=set()
    for item in inventory['files']:
        rel=Path(item['path']); target=(root/rel).resolve()
        if rel.is_absolute() or '..' in rel.parts or not target.is_relative_to(root) or str(rel) in expected:
            raise ValueError('UNSAFE_OR_DUPLICATE_ARTIFACT')
        expected.add(str(rel))
        if not target.is_file() or target.stat().st_size!=item['size'] or digest(target.read_bytes())!=item['sha256']:
            raise ValueError('ARTIFACT_MISSING_OR_ALTERED')
    def read(name): return json.loads((root/name).read_text())
    manifest=read('MANIFEST.json'); auth=read('AUTHORIZATION.json'); receipt=read('LAUNCH_RECEIPT.json'); runtime=read('RUNTIME_RECEIPT.json')
    if manifest['run_id']!=auth['run_id'] or receipt['run_id']!=manifest['run_id'] or runtime['result']['run_id']!=manifest['run_id']:
        raise ValueError('RUN_BINDING_MISMATCH')
    if receipt['manifest_sha256']!=digest((root/'MANIFEST.json').read_bytes()) or manifest['authorization_sha256']!=digest((root/'AUTHORIZATION.json').read_bytes()):
        raise ValueError('MANIFEST_AUTHORIZATION_MISMATCH')
    if receipt['command']!=manifest['command'] or receipt['pid']!=runtime['pid'] or runtime['started']!=receipt['started'] or runtime['ended']<runtime['started']:
        raise ValueError('RUNTIME_RECEIPT_MISMATCH')
    if runtime['exit_code']!=0 or runtime['result']['status']!='PASS' or auth['candidate_execution'] or auth['budget']!=0 or auth['b2']!='LOCKED':
        raise ValueError('SCOPE_OR_RUNTIME_FAILURE')
    for s in read('PRE_TOOLING.json')['sources']:
        if digest((root/'build/MQL5'/s['path']).read_bytes())!=s['sha256']:
            raise ValueError('SOURCE_BINDING_MISMATCH')
    if digest((root/'build/MQL5/Include/KingEA/AccountingEvents.mqh').read_bytes())!=ACCOUNTING_V1_SHA256:
        raise ValueError('STAGE13_SCHEMA_V1_CHANGED')
    build=read('BUILD_BINDING.json')
    if build['preexisting_ex5'] or build['source_manifest_sha256']!=digest((root/'PRE_TOOLING.json').read_bytes()):
        raise ValueError('BUILD_BINDING_INVALID')
    if build['produced_ex5_sha256']!=manifest['ex5_sha256'] or digest((root/'build/MQL5/Experts/KingEA/NativeCostConformance.ex5').read_bytes())!=manifest['ex5_sha256']:
        raise ValueError('EX5_BINDING_INVALID')
    harness=root/'runtime/harness'
    records=sorted(harness.glob('cost-record-*.txt'),key=lambda p:int(p.stem.split('-')[-1]))
    prior=None
    for p in records:
        line=p.read_text().strip(); parent,payload_hash=line.split('|',1); payload,claimed=payload_hash.rsplit('|',1)
        if prior is not None and parent!=prior: raise ValueError('COST_CHAIN_DISCONTINUITY')
        if digest((parent+'|'+payload).encode())!=claimed: raise ValueError('COST_CHAIN_HASH_MISMATCH')
        prior=claimed
    if runtime['result']['metadata_captured']:
        if not records: raise ValueError('COST_EVIDENCE_MISSING')
        sidecar=(harness/'boundary-evidence.txt').read_text().strip()
        payload,claimed=sidecar.rsplit('|sha256=',1)
        if digest(payload.encode())!=claimed: raise ValueError('BOUNDARY_SEAL_MISMATCH')
        fields=dict(x.split('=',1) for x in payload.split('|') if '=' in x)
        if fields['cost_root']!=prior or fields['evaluator_forced']!='true' or fields['boundary_finalization_count']!='1':
            raise ValueError('BOUNDARY_COST_LINK_MISMATCH')
    return {'status':'PASS','run_id':manifest['run_id'],'sealed_only':True,'artifact_count':len(expected),
            'stage13_schema_v1':'BYTE_IDENTICAL','b2':'LOCKED'}
