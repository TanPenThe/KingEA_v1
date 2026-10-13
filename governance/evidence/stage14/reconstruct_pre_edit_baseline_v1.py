"""Reconstruct the retained E12 source authority without modifying it.

The reconstruction is deliberately mechanical and asserts the reviewed digest.
It records a post-edit reconstruction, never a contemporaneous PRE_TOOLING capture.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "research_pipeline" / "native_conformance_control.py"
OUT = Path(__file__).with_name("RECONSTRUCTED_PRE_EDIT_BASELINE_V1.py")
RECORD = Path(__file__).with_name("RECONSTRUCTED_PRE_EDIT_BASELINE_V1.json")
EXPECTED = "E12B13873AB7C8E52EBE308923CE7A4C3A9A3B3F8E378872D09007B42F05D2D8"

raw = SOURCE.read_bytes()
text = raw.decode("utf-8")
text = text.replace("import hashlib\n", "", 1)
start = text.index("def resolve_terminal_instance(")
end = text.index("class ConformanceControl:", start)
text = text[:start] + text[end:]
text = text.replace(
    "    def with_launch_record(self, reference, *, loader_binding_root=None, expected_terminal_instance=None):\n"
    "        import copy\n"
    "        launch=self.verify_launch_record(reference,loader_binding_root=loader_binding_root,\n"
    "                                         expected_terminal_instance=expected_terminal_instance)\n",
    "    def with_launch_record(self, reference):\n"
    "        import copy\n"
    "        launch=self.verify_launch_record(reference)\n",
    1,
)
text = text.replace(
    "    def verify(self, files, independent_seal_reference, capture_reference, *, launch_record_reference, loader_binding_root=None, expected_terminal_instance=None):\n"
    "        launch=self.verify_launch_record(launch_record_reference,loader_binding_root=loader_binding_root,expected_terminal_instance=expected_terminal_instance)\n",
    "    def verify(self, files, independent_seal_reference, capture_reference, *, launch_record_reference):\n"
    "        launch=self.verify_launch_record(launch_record_reference)\n",
    1,
)
text = text.replace("    def verify_launch_record(self, reference, *, loader_binding_root=None, expected_terminal_instance=None):\n", "    def verify_launch_record(self, reference):\n", 1)
text = text.replace(",'account_fingerprint','mql_tester','dll_disabled','local_only','process_exited','loader_binding_receipt'}",
                    ",'account_fingerprint','mql_tester','dll_disabled','local_only','process_exited'}", 1)
text = text.replace(
    "        v3.require(loader_binding_root is not None and expected_terminal_instance is not None,'INDEPENDENT_LOADER_BINDING_REQUIRED')\n"
    "        binding=read_pinned_loader_binding(loader_binding_root,record['loader_binding_receipt'])\n"
    "        validate_loader_binding(self,binding,expected_ini_raw=self._read(record['ini_file']),expected_instance=expected_terminal_instance)\n", "", 1)
result = text.encode("utf-8")
digest = hashlib.sha256(result).hexdigest().upper()
if digest != EXPECTED:
    raise SystemExit("RECONSTRUCTED_BASELINE_HASH_MISMATCH: " + digest)
OUT.write_bytes(result)
RECORD.write_text(json.dumps({
    "kind": "RECONSTRUCTED_PRE_EDIT_BASELINE_V1",
    "RECONSTRUCTED_AFTER_EDIT": True,
    "source": str(SOURCE),
    "reconstructed_path": str(OUT),
    "sha256": digest,
    "expected_sha256": EXPECTED,
    "method": "mechanical removal of the reviewed ExpertParameters discovery-binding V1/V2 additions",
    "test_file_exact_prior_bytes": "UNAVAILABLE_RETAINED_STATE_LIMITATION",
}, indent=2) + "\n", encoding="utf-8")
