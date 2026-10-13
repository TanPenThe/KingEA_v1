"""Synthetic inventory protocol investigation; not production V3 evidence."""
import copy
import hashlib
import json
import unittest
from graphlib import TopologicalSorter, CycleError

def raw(value):return json.dumps(value,sort_keys=True,separators=(',',':')).encode()
def sha(value):return hashlib.sha256(value).hexdigest().upper()

def fixture():
    facts={'fact.json':raw(dict(kind='SYNTHETIC_SUPPORTING_FACT',run='MODEL_RUN',group='MODEL_GROUP',value=7))}
    def entry(path,role,data):return dict(path=path,role=role,sha256=sha(data),size=len(data),run='MODEL_RUN',group='MODEL_GROUP')
    refs=raw(dict(kind='REFERENCE_INVENTORY_V1',entries=[entry('fact.json','FACT',facts['fact.json'])]))
    sidecar=raw(dict(kind='SYNTHETIC_SIDECAR_MODEL',integrity=dict(archive_inventory_hash=sha(refs)),fact_hash=sha(facts['fact.json'])))
    files=dict(facts,**{'references.json':refs,'sidecar.json':sidecar})
    archive=raw(dict(kind='FINAL_ARCHIVE_INVENTORY_V1',entries=[entry(p,{'fact.json':'FACT','references.json':'REFERENCE_INVENTORY','sidecar.json':'SIDECAR'}[p],v) for p,v in sorted(files.items())]))
    return files,archive,sha(archive)

def verify(files,archive,pin):
    if sha(archive)!=pin:raise ValueError('INDEPENDENT_ARCHIVE_PIN_MISMATCH')
    a=json.loads(archive); entries=a['entries'];names=[x['path'] for x in entries]
    if len(set(names))!=len(names) or set(names)!=set(files):raise ValueError('INVENTORY_MEMBERSHIP_MISMATCH')
    for e in entries:
        if e['run']!='MODEL_RUN' or e['group']!='MODEL_GROUP':raise ValueError('FOREIGN_SCOPE')
        if sha(files[e['path']])!=e['sha256'] or len(files[e['path']])!=e['size']:raise ValueError('ARTIFACT_HASH_MISMATCH')
    r=json.loads(files['references.json']);s=json.loads(files['sidecar.json'])
    if s['integrity']['archive_inventory_hash']!=sha(files['references.json']):raise ValueError('REFERENCE_INVENTORY_MISMATCH')
    if [e['path'] for e in r['entries']]!=['fact.json']:raise ValueError('REFERENCE_COVERAGE_MISMATCH')
    if r['entries'][0]['sha256']!=s['fact_hash'] or s['fact_hash']!=sha(files['fact.json']):raise ValueError('FACT_REFERENCE_MISMATCH')
    return 'PROPOSED_PROTOCOL_ONLY'

class ProtocolProof(unittest.TestCase):
    def test_literal_single_inventory_requires_cycle(self):
        with self.assertRaises(CycleError):
            tuple(TopologicalSorter({'sidecar':{'archive_inventory'},'archive_inventory':{'sidecar'}}).static_order())
    def test_proposed_two_level_order_is_acyclic(self):
        order=tuple(TopologicalSorter({'facts':set(),'reference_inventory':{'facts'},'sidecar':{'facts','reference_inventory'},'archive_inventory':{'facts','reference_inventory','sidecar'},'independent_seal':{'archive_inventory'}}).static_order())
        self.assertLess(order.index('reference_inventory'),order.index('sidecar'))
        self.assertLess(order.index('sidecar'),order.index('archive_inventory'))
    def test_proposal_constructs_without_omitted_hash_fields(self):
        files,a,pin=fixture();self.assertEqual(verify(files,a,pin),'PROPOSED_PROTOCOL_ONLY')
    def test_missing_artifact_rejects_without_transition(self):
        files,a,pin=fixture();del files['fact.json'];before=copy.deepcopy(files)
        with self.assertRaisesRegex(ValueError,'INVENTORY_MEMBERSHIP'):verify(files,a,pin)
        self.assertEqual(files,before)
    def test_altered_support_rejects_without_transition(self):
        files,a,pin=fixture();files['fact.json']+=b'changed';before=copy.deepcopy(files)
        with self.assertRaisesRegex(ValueError,'ARTIFACT_HASH'):verify(files,a,pin)
        self.assertEqual(files,before)
    def test_resealed_local_archive_cannot_change_external_pin(self):
        files,a,pin=fixture();data=json.loads(a);data['entries'][0]['sha256']='B'*64
        with self.assertRaisesRegex(ValueError,'INDEPENDENT_ARCHIVE_PIN'):verify(files,raw(data),pin)

if __name__=='__main__':unittest.main(verbosity=2)
