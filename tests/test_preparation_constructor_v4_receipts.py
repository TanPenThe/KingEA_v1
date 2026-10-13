from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
V3_PATH = ROOT / "governance/review/build6182_exact_maintenance_20260914/construct_fixture_packages.py"
V4_PATH = V3_PATH.with_name("construct_fixture_packages_v4.py")
COMPILE = ROOT / "governance/review/evidence_producer_serialization_corrected_compile_20260925"


def load_constructor(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


V3 = load_constructor(V3_PATH, "accepted_constructor_v3_receipt_test")
V4 = load_constructor(V4_PATH, "successor_constructor_v4_receipt_test")

SOURCE = "B2DDFF4EF983F849D6C46013332EC2AED6E6422C6061C9FE98695843333EE0DA"
EX5 = "357FF10075C3042F3AF9FE74FDAFFD45D597DF373223492DA0BEFD79B0DCDE91"
COMPILER = "197CA3DD8D1971831366F54CB57BF3F120B420700E573135509D406E4E23709E"
FIXTURES = {
    "NCV1-LONG-NORMAL-001": ("5C94475F45C674DD5BFFD11B4B6E6C7226B05314E71EB319979A9547879079A7", "NCV1-LONG-NORMAL-001_POSTCOMPILE_PROPOSED.json", "B4F38044C1CC55434DCA752B368B0BFF5D9900839EC692B31E841DF3BE638527", 609),
    "NCV1-SHORT-NORMAL-001": ("7691D837240C8D22DC313DF29FADBB263A61F1B81BDD7CE477CB02710AEBF5D8", "NCV1-SHORT-NORMAL-001_POSTCOMPILE_PROPOSED.json", "D0161D01589B72A10626098F45ADAB15D242CB87C83C20669656B21FB95187EC", 610),
    "NCV1-LONG-BOUNDARY-001": ("A7AF010E72934FEF3E2BA8294574DC04D814AD2512C63224C6DC0273356C6F71", "NCV1-LONG-BOUNDARY-001_POSTCOMPILE_PROPOSED.json", "9A482EC164E7E511EAF423B0E5842B33552CACF809EF228B741E669425114134", 611),
}


def expected_compile(fixture_id):
    layer_a = FIXTURES[fixture_id][0]
    return {
        "kind": "CONFORMANCE_POSTCOMPILE_BINDING_V1",
        "layer_a_sha256": layer_a,
        "source_manifest_sha256": SOURCE,
        "compiler_build": 6182,
        "compiler_sha256": COMPILER,
        "ex5_sha256": EX5,
        "ex5_byte_length": 268708,
    }


def extended_receipt(fixture_id):
    value = expected_compile(fixture_id)
    value.update({
        "classification": "PROPOSED_NON_RUNTIME_POSTCOMPILE_RECEIPT",
        "fixture_id": fixture_id,
        "runtime_authorized": False,
        "launch_authority": False,
        "trading_authority": False,
    })
    return value


class SuccessorConstructorReceiptTests(unittest.TestCase):
    def test_exact_legacy_seven_field_receipt_still_passes(self):
        fid = "NCV1-LONG-NORMAL-001"
        receipt = expected_compile(fid)
        self.assertEqual(set(receipt), V4.LEGACY_COMPILE_RECEIPT_FIELDS)
        self.assertEqual(V3.CONSTRUCTOR_KIND, "CONFORMANCE_PREPARATION_CONSTRUCTOR_V3")
        self.assertEqual(V4.validate_postcompile_receipt(receipt, expected_compile(fid), fid), "LEGACY_EXACT_7_FIELD")

    def _assert_current_receipt(self, fixture_id):
        layer, filename, digest, length = FIXTURES[fixture_id]
        path = COMPILE / filename
        raw = path.read_bytes()
        self.assertEqual(len(raw), length)
        self.assertEqual(hashlib.sha256(raw).hexdigest().upper(), digest)
        parsed = json.loads(raw.decode("utf-8", "strict"))
        self.assertEqual(V4.validate_postcompile_receipt(parsed, expected_compile(fixture_id), fixture_id), "EXTENDED_NON_RUNTIME_EXACT_12_FIELD")
        self.assertEqual(parsed["layer_a_sha256"], layer)
        self.assertEqual(len(parsed), 12)

    def test_current_long_exact_extended_receipt_passes(self):
        self._assert_current_receipt("NCV1-LONG-NORMAL-001")

    def test_current_short_exact_extended_receipt_passes(self):
        self._assert_current_receipt("NCV1-SHORT-NORMAL-001")

    def test_current_boundary_exact_extended_receipt_passes(self):
        self._assert_current_receipt("NCV1-LONG-BOUNDARY-001")

    def test_extended_core_values_are_compared_exactly(self):
        for fid in FIXTURES:
            self.assertEqual(V4.validate_postcompile_receipt(extended_receipt(fid), expected_compile(fid), fid), "EXTENDED_NON_RUNTIME_EXACT_12_FIELD")

    def _reject_mutation(self, field, value, fixture_id="NCV1-LONG-NORMAL-001"):
        receipt = extended_receipt(fixture_id)
        receipt[field] = value
        with self.assertRaisesRegex(ValueError, "INDEPENDENT_COMPILE_BINDING_MISMATCH"):
            V4.validate_postcompile_receipt(receipt, expected_compile(fixture_id), fixture_id)

    def test_wrong_ex5_hash_fails(self):
        self._reject_mutation("ex5_sha256", "0" * 64)

    def test_wrong_ex5_length_fails(self):
        self._reject_mutation("ex5_byte_length", 268707)

    def test_wrong_compiler_build_fails(self):
        self._reject_mutation("compiler_build", 6183)

    def test_wrong_compiler_sha_fails(self):
        self._reject_mutation("compiler_sha256", "1" * 64)

    def test_wrong_source_manifest_hash_fails(self):
        self._reject_mutation("source_manifest_sha256", "2" * 64)

    def test_wrong_layer_a_hash_fails(self):
        self._reject_mutation("layer_a_sha256", "3" * 64)

    def test_wrong_fixture_id_fails(self):
        self._reject_mutation("fixture_id", "NCV1-SHORT-NORMAL-001")

    def test_wrong_classification_fails(self):
        self._reject_mutation("classification", "RUNTIME_AUTHORIZED")

    def test_runtime_authorized_true_fails(self):
        self._reject_mutation("runtime_authorized", True)

    def test_launch_authority_true_fails(self):
        self._reject_mutation("launch_authority", True)

    def test_trading_authority_true_fails(self):
        self._reject_mutation("trading_authority", True)

    def test_string_false_is_not_boolean_false(self):
        self._reject_mutation("runtime_authorized", "false")

    def test_missing_governance_field_fails(self):
        receipt = extended_receipt("NCV1-LONG-NORMAL-001")
        del receipt["trading_authority"]
        with self.assertRaisesRegex(ValueError, "INDEPENDENT_COMPILE_BINDING_MISMATCH"):
            V4.validate_postcompile_receipt(receipt, expected_compile("NCV1-LONG-NORMAL-001"), "NCV1-LONG-NORMAL-001")

    def test_unknown_additional_field_fails(self):
        receipt = extended_receipt("NCV1-LONG-NORMAL-001")
        receipt["future_authority"] = True
        with self.assertRaisesRegex(ValueError, "INDEPENDENT_COMPILE_BINDING_MISMATCH"):
            V4.validate_postcompile_receipt(receipt, expected_compile("NCV1-LONG-NORMAL-001"), "NCV1-LONG-NORMAL-001")

    def test_legacy_receipt_with_unrecognized_field_fails(self):
        receipt = expected_compile("NCV1-LONG-NORMAL-001")
        receipt["future_authority"] = False
        with self.assertRaisesRegex(ValueError, "INDEPENDENT_COMPILE_BINDING_MISMATCH"):
            V4.validate_postcompile_receipt(receipt, expected_compile("NCV1-LONG-NORMAL-001"), "NCV1-LONG-NORMAL-001")

    def test_receipt_pin_mismatch_fails_before_schema_acceptance(self):
        fid = "NCV1-LONG-NORMAL-001"
        raw = json.dumps(extended_receipt(fid), separators=(",", ":")).encode("utf-8")
        with tempfile.TemporaryDirectory(prefix="kingea-v4-receipt-test-") as temp:
            path = Path(temp) / "receipt.json"
            path.write_bytes(raw)
            reference = {"path": "receipt.json", "byte_length": len(raw), "sha256": "0" * 64}
            with mock.patch.object(V4, "validate_postcompile_receipt", wraps=V4.validate_postcompile_receipt) as validator:
                with self.assertRaisesRegex(ValueError, "LOADER_BINDING_PIN_MISMATCH"):
                    V4.read_validated_postcompile_receipt(temp, reference, expected_compile(fid), fid)
                validator.assert_not_called()

    def test_pinned_reader_checks_exact_length_before_schema(self):
        fid = "NCV1-LONG-NORMAL-001"
        raw = json.dumps(extended_receipt(fid), separators=(",", ":")).encode("utf-8")
        with tempfile.TemporaryDirectory(prefix="kingea-v4-receipt-test-") as temp:
            Path(temp, "receipt.json").write_bytes(raw)
            reference = {"path": "receipt.json", "byte_length": len(raw) + 1, "sha256": hashlib.sha256(raw).hexdigest().upper()}
            with self.assertRaisesRegex(ValueError, "LOADER_BINDING_PIN_MISMATCH"):
                V4.read_validated_postcompile_receipt(temp, reference, expected_compile(fid), fid)

    def test_receipt_bytes_are_never_rewritten_or_normalized(self):
        fid = "NCV1-LONG-NORMAL-001"
        _, filename, _, _ = FIXTURES[fid]
        path = COMPILE / filename
        before = path.read_bytes()
        reference = {"path": filename, "byte_length": len(before), "sha256": hashlib.sha256(before).hexdigest().upper()}
        receipt, schema = V4.read_validated_postcompile_receipt(COMPILE, reference, expected_compile(fid), fid)
        after = path.read_bytes()
        self.assertEqual(schema, "EXTENDED_NON_RUNTIME_EXACT_12_FIELD")
        self.assertEqual(receipt, json.loads(before.decode("utf-8", "strict")))
        self.assertEqual(after, before)
        self.assertEqual(hashlib.sha256(after).hexdigest().upper(), reference["sha256"])

    def test_constructor_metadata_marks_extended_receipt_without_authority(self):
        self.assertEqual(V4.CONSTRUCTOR_KIND, "CONFORMANCE_PREPARATION_CONSTRUCTOR_V4")
        self.assertEqual(V4.CONSTRUCTOR_SCOPE, "EXACT_EXTENDED_NON_RUNTIME_POSTCOMPILE_RECEIPT_SCHEMA")
        self.assertEqual(V4.CONSTRUCTOR_PREDECESSOR_SHA256, "BDB08E504BB1D2987BAF9976A70363ECD644B0BA5786CD2588FA8E1CDF315FA4")
        result = V4.validate_postcompile_receipt(extended_receipt("NCV1-LONG-NORMAL-001"), expected_compile("NCV1-LONG-NORMAL-001"), "NCV1-LONG-NORMAL-001")
        self.assertEqual(result, "EXTENDED_NON_RUNTIME_EXACT_12_FIELD")
        self.assertNotIn("runtime_authorized", result)
        self.assertNotIn("launch_authority", result)
        self.assertNotIn("trading_authority", result)

    def test_no_package_or_authority_output_is_created_by_validation(self):
        fid = "NCV1-LONG-NORMAL-001"
        raw = json.dumps(extended_receipt(fid), separators=(",", ":")).encode("utf-8")
        with tempfile.TemporaryDirectory(prefix="kingea-v4-receipt-test-") as temp:
            path = Path(temp) / "receipt.json"
            path.write_bytes(raw)
            reference = {"path": "receipt.json", "byte_length": len(raw), "sha256": hashlib.sha256(raw).hexdigest().upper()}
            V4.read_validated_postcompile_receipt(temp, reference, expected_compile(fid), fid)
            self.assertEqual({p.name for p in Path(temp).iterdir()}, {"receipt.json"})

    def test_exact_schema_guard_precedes_core_projection(self):
        import inspect
        source = inspect.getsource(V4.validate_postcompile_receipt)
        guard = source.index("if fields == EXTENDED_COMPILE_RECEIPT_FIELDS:")
        projection = source.index("core = {key: receipt[key] for key in LEGACY_COMPILE_RECEIPT_FIELDS}")
        self.assertLess(guard, projection)
        self.assertNotIn("expected_compile.items() <=", source)
        self.assertNotIn("expected_compile.items() <= receipt.items()", source)
        unknown = extended_receipt("NCV1-LONG-NORMAL-001")
        unknown["future_authority"] = "ignored-if-projected"
        with self.assertRaisesRegex(ValueError, "INDEPENDENT_COMPILE_BINDING_MISMATCH"):
            V4.validate_postcompile_receipt(unknown, expected_compile("NCV1-LONG-NORMAL-001"), "NCV1-LONG-NORMAL-001")


if __name__ == "__main__":
    unittest.main()
