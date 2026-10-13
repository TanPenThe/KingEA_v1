import json
import shutil
import tempfile
import unittest
from pathlib import Path
from research_pipeline.native_cost_sealed_verifier import verify

ROOT=Path(__file__).resolve().parents[1]
PROOF=ROOT/'governance/evidence/stage14/native_cost_mtm_20260905/NC-COST-04-FINAL'

class NativeCostSealedTests(unittest.TestCase):
    def test_sealed_proof_works_without_original_working_sources(self):
        with tempfile.TemporaryDirectory() as d:
            copy=Path(d)/'sealed'; shutil.copytree(PROOF,copy)
            self.assertEqual(verify(copy)['status'],'PASS')

    def test_altered_or_missing_cost_receipt_manifest_sources_fail(self):
        for relative in ['runtime/harness/cost-record-0.txt','MANIFEST.json','LAUNCH_RECEIPT.json',
                         'AUTHORIZATION.json','runtime/harness/boundary-evidence.txt',
                         'build/MQL5/Include/KingEA/AccountingEvents.mqh']:
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as d:
                copy=Path(d)/'sealed'; shutil.copytree(PROOF,copy)
                target=copy/relative
                target.write_bytes(target.read_bytes()+b'altered')
                with self.assertRaisesRegex(ValueError,'ARTIFACT_MISSING_OR_ALTERED'): verify(copy)
                target.unlink()
                with self.assertRaisesRegex(ValueError,'ARTIFACT_MISSING_OR_ALTERED'): verify(copy)

    def test_wrong_pid_run_and_command_fail_even_after_inventory_reseal(self):
        from research_pipeline.native_cost_sealed_verifier import digest
        for field,value in [('pid',-1),('run_id','FOREIGN_RUN'),('command',['unapproved.exe'])]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as d:
                copy=Path(d)/'sealed'; shutil.copytree(PROOF,copy)
                target=copy/'LAUNCH_RECEIPT.json'; obj=json.loads(target.read_text()); obj[field]=value
                target.write_text(json.dumps(obj))
                inventory=json.loads((copy/'SEALED_INVENTORY.json').read_text())
                row=next(i for i in inventory['files'] if i['path']=='LAUNCH_RECEIPT.json')
                row['size']=target.stat().st_size; row['sha256']=digest(target.read_bytes())
                (copy/'SEALED_INVENTORY.json').write_text(json.dumps(inventory))
                with self.assertRaises(ValueError): verify(copy)

if __name__=='__main__': unittest.main()
