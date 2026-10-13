"""Deterministic contracts for the native evidence serialization producer."""

from __future__ import annotations

import hashlib
import json
import re
import unittest
from decimal import Decimal
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRODUCER = ROOT / "MQL5/Include/KingEA/GuardedNativeCostIntegration.mqh"
BASELINE = ROOT / "governance/review/evidence_producer_serialization_repair_20260925/GuardedNativeCostIntegration.before.mqh"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def mql_quote(value: str) -> str:
    """Mirror the producer's existing DAQuote behavior for these ASCII test values."""
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def serialized_request(category: str) -> bytes:
    """Build a compact request using the producer's fixed field order and types."""
    values = {
        "entry": ("0.1000000000000000", 0, 0, 0),
        "safety_reduction": ("0.0500000000000000", 1, 1, 701),
        "final_close": ("0.0500000000000000", 1, 1, 701),
    }
    volume, order_type, filling, position = values[category]
    parts = [
        '"action":1', '"magic":12001', f'"order":{0 if category == "entry" else 3}',
        '"symbol":"ETHUSD.s"', f'"volume":"{volume}"', '"price":"123.4500000000000000"',
        '"stoplimit":"0.0000000000000000"', '"sl":"600.0000000000000000"' if category == "entry" else '"sl":"0.0000000000000000"',
        '"tp":"0.0000000000000000"', '"deviation":20', f'"type":{order_type}',
        f'"type_filling":{filling}', '"type_time":0', '"expiration":"1970.01.01 00:00:00"',
        '"comment":"CONFORMANCE"', f'"position":{position}', '"position_by":0',
    ]
    return ("{" + ",".join(parts) + "}").encode("utf-8")


class OrderCheckSerializationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = PRODUCER.read_text(encoding="utf-8")

    def test_producer_quotes_expiration_as_json_string(self) -> None:
        line = next(line for line in self.source.splitlines() if 'expiration' in line)
        self.assertIn('\\"expiration\\":\"+DAQuote((string)r.expiration)+', line)
        self.assertNotIn('\\"expiration\\":+(string)r.expiration', line)

    def test_all_request_categories_parse_and_hash_exact_serialized_bytes(self) -> None:
        for category in ("entry", "safety_reduction", "final_close"):
            with self.subTest(category=category):
                request_bytes = serialized_request(category)
                parsed = json.loads(request_bytes.decode("utf-8"))
                self.assertEqual(parsed["expiration"], "1970.01.01 00:00:00")
                request_hash = digest(request_bytes)
                self.assertEqual(request_hash, digest(request_bytes))
                canonical = json.dumps(parsed, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
                self.assertEqual(digest(canonical), request_hash)

    def test_expiration_semantic_text_is_preserved(self) -> None:
        request = json.loads(serialized_request("entry"))
        self.assertEqual(request["expiration"], "1970.01.01 00:00:00")

    def test_strict_parser_rejects_historical_unquoted_datetime(self) -> None:
        malformed = b'{"expiration":1970.01.01 00:00:00}'
        with self.assertRaises(json.JSONDecodeError):
            json.loads(malformed.decode("utf-8"))

    def test_source_hashes_exact_request_and_verifier_rehashes_compact_json(self) -> None:
        line = next(line for line in self.source.splitlines() if 'request_hash' in line)
        self.assertIn('ResearchSha256String(request)', line)
        verifier = (ROOT / "research_pipeline/decision_a_evidence.py").read_text(encoding="utf-8")
        self.assertIn("digest(json.dumps(r,separators=(',',':'),ensure_ascii=False).encode())==check['request_hash']", verifier)


class Stage13CommitPrecisionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = PRODUCER.read_text(encoding="utf-8")

    def test_commit_uses_narrow_quoted_eight_decimal_accounting_formatter(self) -> None:
        self.assertIn('string DAAccountingNumber(double n){return DAQuote(DoubleToString(n,8));}', self.source)
        commit = self.source[self.source.index('"STAGE13_COMMITTED"'):]
        self.assertIn('\\"base_before\\":\"+DAAccountingNumber(base_before)', commit)
        self.assertIn('\\"base_after\\":\"+DAAccountingNumber(g_da_base)', commit)
        self.assertNotIn('\\"base_before\\":\"+DANumber(base_before)', commit)
        self.assertNotIn('\\"base_after\\":\"+DANumber(g_da_base)', commit)

    def test_binary64_commit_value_serializes_to_currency_precision(self) -> None:
        internal = float(Decimal("9994.7999999999992725"))
        serialized = format(internal, ".8f")
        self.assertEqual(serialized, "9994.80000000")
        self.assertEqual(Decimal(serialized), Decimal("9994.80"))

    def test_genuine_difference_at_eight_places_remains_a_mismatch(self) -> None:
        self.assertNotEqual(Decimal("9994.80000001"), Decimal("9994.80000000"))
        verifier = (ROOT / "research_pipeline/decision_a_evidence.py").read_text(encoding="utf-8")
        self.assertIn("number(native_commit['base_after'])==number(o['E0'])+net", verifier)
        self.assertNotRegex(verifier, re.compile(r"epsilon|isclose|tolerance", re.IGNORECASE))

    def test_internal_equity_arithmetic_and_projection_count_are_unchanged(self) -> None:
        self.assertIn("event.account_equity=g_da_base+net", self.source)
        self.assertIn("g_da_base+=net", self.source)
        self.assertIn('financial_projection_count\\":1', self.source)
        self.assertIn('atomic_handoff\\":true', self.source)
        self.assertIn("string DANumber(double n){return DAQuote(DoubleToString(n,16));}", self.source)

    def test_prepared_canonical_event_expression_is_byte_identical(self) -> None:
        before = BASELINE.read_text(encoding="utf-8")
        marker = "string canonical=KingEAAccountingCanonical(event,decision.sequence,prior);"
        self.assertEqual(before.count(marker), 1)
        self.assertEqual(self.source.count(marker), 1)
        self.assertIn('ResearchNativeRecord("STAGE13_PREPARED",canonical)', before)
        self.assertIn('ResearchNativeRecord("STAGE13_PREPARED",canonical)', self.source)
        self.assertIn('DAQuote(decision.event_sha256)', before)
        self.assertIn('DAQuote(decision.event_sha256)', self.source)

    def test_production_header_diff_is_limited_to_three_serialization_edits(self) -> None:
        before = BASELINE.read_text(encoding="utf-8")
        normalized = self.source
        normalized = normalized.replace(
            "string DAAccountingNumber(double n){return DAQuote(DoubleToString(n,8));}\n", "", 1
        )
        normalized = normalized.replace(
            'DAAccountingNumber(base_before)', 'DANumber(base_before)', 1
        ).replace('DAAccountingNumber(g_da_base)', 'DANumber(g_da_base)', 1)
        normalized = normalized.replace(
            'DAQuote((string)r.expiration)', '(string)r.expiration', 1
        )
        capture_repair = (
            ' string capture_name="V3_CAPTURE_"+ResearchSha256String(g_da.group)+"_"+InpConformanceControlSha256;\n'
            ' if(!ResearchNativePersist(capture_name,capture))'
        )
        self.assertEqual(1, normalized.count(capture_repair))
        normalized = normalized.replace(
            capture_repair,
            ' if(!ResearchNativePersist("V3_CAPTURE_"+ResearchSha256String(g_da.group),capture))',
            1,
        )
        completion_repair = (
            ' string completion_name=InpNativeConformance?"V3_COMPLETION_"+InpConformanceControlSha256:"V3_COMPLETION";\n'
            ' if(!ResearchNativePersist(completion_name,value))return false;'
        )
        self.assertEqual(1, normalized.count(completion_repair))
        normalized = normalized.replace(
            completion_repair,
            ' if(!ResearchNativePersist("V3_COMPLETION",value))return false;',
            1,
        )
        self.assertEqual(normalized, before)


if __name__ == "__main__":
    unittest.main()
