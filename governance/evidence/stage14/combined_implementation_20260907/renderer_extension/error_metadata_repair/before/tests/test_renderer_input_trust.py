"""Active-renderer immutable trust tests. Synthetic control; no runtime authority."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from test_successor_evidence import ControlFixture, canonical, hashed
from research_pipeline.successor_evidence import PinnedControlContext, SuccessorEvidenceError, validate
from research_pipeline.stage14 import ResearchRunCoordinator
from research_pipeline.decision_a_evidence import ImmutableInput, digest

class RendererInputTrustTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.f=ControlFixture(Path(self.temp.name));self.rebind()
    def rebind(self):
        self.context=PinnedControlContext(self.f.directory,self.f.pin)
        self.coordinator=ResearchRunCoordinator(control_context=self.context)
        self.root=Path(self.f.control['render_inputs']['agent_files_root'])/'KingEA'/'runs'/self.f.manifest['manifest_sha256']
    def files(self):
        return {str(p.relative_to(self.f.directory)):p.read_bytes() for p in self.f.directory.rglob('*') if p.is_file()}
    def render(self):return self.coordinator.render_bundle(self.f.manifest,self.f.authorization)
    def denied(self):
        before=self.files()
        with self.assertRaisesRegex(SuccessorEvidenceError,'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED') as e:self.render()
        self.assertEqual(e.exception.stage,'rendering');self.assertTrue(e.exception.detail)
        self.assertEqual(before,self.files())
    def test_shared_only_cannot_render(self):
        original=(self.root/'fixture.csv').read_bytes();(self.root/'fixture.csv').unlink()
        shared=self.f.directory/'Common'/'Files';shared.mkdir(parents=True);(shared/'fixture.csv').write_bytes(original)
        self.denied()
    def test_payload_path_does_not_choose_input(self):
        self.f.manifest['operational_facts']['calendar_intervals_file']='attacker.csv'
        self.denied()
    def test_wrong_independent_hash(self):
        self.f.control['render_inputs']['calendar']['sha256']='B'*64
        self.f.pin=self.f.store('control.json',self.f.control)['sha256'];self.rebind();self.denied()
    def test_local_co_tampering_cannot_repin(self):
        self.f.control['render_inputs']['calendar']['sha256']='B'*64
        self.f.store('control.json',self.f.control);self.denied()
    def test_exact_local_paths_and_file_hashes(self):
        before=self.files();result=self.render();lines=result['set'].splitlines()
        prefix='KingEA\\runs\\'+self.f.manifest['manifest_sha256']+'\\'
        self.assertIn('InpRunManifest='+prefix+'manifest.json',lines)
        self.assertIn('InpManifestFileSha256='+digest((self.root/'manifest.json').read_bytes()),lines)
        self.assertNotIn('SET_AT_EXECUTION',result['set'])
        self.assertIn('InpCalendarIntervalsFile='+prefix+'fixture.csv',lines)
        self.assertIn('InpCalendarFileSha256='+digest((self.root/'fixture.csv').read_bytes()),lines)
        self.assertEqual(before,self.files())
    def test_payload_cannot_manufacture_verified_expectation(self):
        expected=validate(self.context,self.f.manifest,'rendering',self.f.authorization)
        expected['control']['render_inputs']['agent_files_root']=str(self.f.directory/'attacker')
        with self.assertRaisesRegex(SuccessorEvidenceError,'SUCCESSOR_EVIDENCE_CONTRACT_UNSATISFIED'):
            self.context.capture_render_inputs(expected,self.f.manifest)
    def test_capture_once_per_input(self):
        original=ImmutableInput.capture;seen=[]
        def capture(root,reference):
            seen.append(reference['path']);return original(root,reference)
        with patch.object(ImmutableInput,'capture',side_effect=capture):self.render()
        self.assertEqual(seen,['manifest.json','fixture.csv'])
    def test_mutation_between_hash_and_parse_cannot_render(self):
        original=ImmutableInput.json
        def mutate(capture):
            (self.root/'manifest.json').write_bytes(b'{"tampered":true}')
            return original(capture)
        with patch.object(ImmutableInput,'json',mutate):self.denied()
    def test_calendar_mutation_during_parse_cannot_render(self):
        original=ImmutableInput.calendar
        def mutate(capture):
            (self.root/'fixture.csv').write_bytes(b'tampered')
            return original(capture)
        with patch.object(ImmutableInput,'calendar',mutate):self.denied()
    def test_capture_failure_releases_read_handles(self):
        with patch.object(ImmutableInput,'json',side_effect=ValueError('TEST_PARSE_FAILURE')):self.denied()
        # A later write must work after failure; the capture retains no handles.
        p=self.root/'manifest.json';raw=p.read_bytes();p.write_bytes(raw)

    def test_changed_manifest_bytes_fail_pinned_hash(self):
        (self.root/'manifest.json').write_bytes(canonical(dict(self.f.manifest,unexpected=True)))
        self.denied()
    def test_changed_calendar_bytes_fail_pinned_hash(self):
        (self.root/'fixture.csv').write_bytes(b'type,start_msc,end_msc,identity\nNEWS,100,300,changed\n')
        self.denied()
    def test_parse_cannot_substitute_unhashed_manifest(self):
        with patch.object(ImmutableInput,'json',return_value=dict(self.f.manifest,unexpected=True)):
            self.denied()
    def test_shared_root_cannot_be_pinned_as_local(self):
        self.f.control['render_inputs']['agent_files_root']=str(self.f.directory/'Common'/'Files')
        self.f.pin=self.f.store('control.json',self.f.control)['sha256'];self.rebind();self.denied()
    def test_input_reference_cannot_inject_set_line(self):
        self.f.control['render_inputs']['calendar']['path']='calendar.csv\nInpWorkloadDryRun=true'
        self.f.pin=self.f.store('control.json',self.f.control)['sha256'];self.rebind();self.denied()
    def test_wrong_run_scope_rejects(self):
        self.f.control['render_inputs']['child_sha256']='B'*64
        self.f.pin=self.f.store('control.json',self.f.control)['sha256'];self.rebind();self.denied()
    def test_missing_input_authority_is_not_fallback(self):
        del self.f.control['render_inputs'];self.f.pin=self.f.store('control.json',self.f.control)['sha256']
        self.context=PinnedControlContext(self.f.directory,self.f.pin);self.coordinator=ResearchRunCoordinator(control_context=self.context)
        self.denied()

if __name__=='__main__':unittest.main()
