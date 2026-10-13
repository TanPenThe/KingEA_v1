import csv
import hashlib
import tempfile
import unittest
from pathlib import Path

from data_pipeline.manifest_gate import (
    GateFailure,
    evaluate_manifest_evidence,
    parse_mt5_gate_report,
)


REGISTERED = [
    {
        "time_msc": 1709374488223,
        "bid": "3427.62",
        "ask": "3427.36",
        "native_count": 1,
        "custom_count": 1,
    },
    {
        "time_msc": 1709375322820,
        "bid": "3418.20",
        "ask": "3418.16",
        "native_count": 1,
        "custom_count": 1,
    },
]


def valid_evidence():
    return {
        "status": "PASS",
        "total_ticks": 327417608,
        "registered_crossed": [dict(item) for item in REGISTERED],
        "unexpected_crossed": 0,
        "backward_timestamps": 0,
        "nonflag_mismatches": 0,
        "invalid_flag_normalizations": 0,
        "warmup": {
            "status": "PASS",
            "from": "2021.04.01 00:00:00",
            "to_exclusive": "2021.07.01 00:00:00",
            "coverage_ratio": 0.99,
            "unexplained_terminal_gaps": 0,
        },
    }


class ManifestGateTests(unittest.TestCase):
    def test_rejects_an_additional_crossed_quote(self):
        evidence = valid_evidence()
        evidence["unexpected_crossed"] = 1

        with tempfile.TemporaryDirectory() as directory:
            sample = Path(directory) / "sample.csv"
            self._write_sample(sample)
            with self.assertRaisesRegex(GateFailure, "unexpected crossed"):
                self._evaluate(evidence, sample)

    def test_rejects_a_missing_or_altered_registered_quote(self):
        evidence = valid_evidence()
        evidence["registered_crossed"][0]["ask"] = "3427.37"

        with tempfile.TemporaryDirectory() as directory:
            sample = Path(directory) / "sample.csv"
            self._write_sample(sample)
            with self.assertRaisesRegex(GateFailure, "registered crossed"):
                self._evaluate(evidence, sample)

    def test_rejects_a_crossed_timestamp_inside_a_sample_window(self):
        evidence = valid_evidence()
        with tempfile.TemporaryDirectory() as directory:
            sample = Path(directory) / "sample.csv"
            self._write_sample(
                sample,
                start="2024.03.02 10:00:00",
                end="2024.03.02 11:00:00",
            )
            with self.assertRaisesRegex(GateFailure, "sample window"):
                self._evaluate(evidence, sample)

    def test_rejects_any_full_population_or_warmup_integrity_failure(self):
        failures = {
            "status": ("FAIL", "validator status"),
            "total_ticks": (327417607, "tick count"),
            "backward_timestamps": (1, "backward timestamp"),
            "nonflag_mismatches": (1, "non-flag mismatch"),
            "invalid_flag_normalizations": (1, "flag normalization"),
            "warmup.status": ("FAIL", "warm-up status"),
            "warmup.coverage_ratio": (0.949, "warm-up coverage"),
            "warmup.unexplained_terminal_gaps": (1, "warm-up terminal gap"),
        }
        with tempfile.TemporaryDirectory() as directory:
            sample = Path(directory) / "sample.csv"
            self._write_sample(sample)
            for key, (value, message) in failures.items():
                with self.subTest(key=key):
                    evidence = valid_evidence()
                    if key.startswith("warmup."):
                        evidence["warmup"][key.split(".", 1)[1]] = value
                    else:
                        evidence[key] = value
                    with self.assertRaisesRegex(GateFailure, message):
                        self._evaluate(evidence, sample)

    def test_rejects_a_sample_audit_hash_mismatch(self):
        evidence = valid_evidence()
        with tempfile.TemporaryDirectory() as directory:
            sample = Path(directory) / "sample.csv"
            self._write_sample(sample)
            with self.assertRaisesRegex(GateFailure, "sample audit SHA-256"):
                evaluate_manifest_evidence(evidence, sample, "0" * 64)

    def test_accepts_complete_evidence_and_records_zero_containment(self):
        evidence = valid_evidence()
        with tempfile.TemporaryDirectory() as directory:
            sample = Path(directory) / "sample.csv"
            self._write_sample(sample)
            result = self._evaluate(evidence, sample)

        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["sample_windows"], 60)
        self.assertEqual(result["sampled_quotes"], 400437)
        self.assertEqual(
            [row["contained_window_count"] for row in result["sample_window_containment"]],
            [0, 0],
        )
        for row in result["sample_window_containment"]:
            self.assertEqual(row["applicable_month_window"], "sample_33")
            self.assertEqual(
                row["applicable_month_window_start"], "2024.03.15 12:00:00"
            )
            self.assertEqual(
                row["applicable_month_window_end_exclusive"],
                "2024.03.15 13:00:00",
            )

    def test_parses_the_mt5_validator_report_contract(self):
        rows = [
            ("audit", "scope", "NON_PERFORMANCE_RSB3_MANIFEST_GATE"),
            ("audit", "build_id", "RSB3-MANIFEST-GATE-20260726-A"),
            ("audit", "server", "JustMarkets-Demo2"),
            ("audit", "origin_symbol", "ETHUSD.s"),
            ("audit", "reduced_symbol", "KINGEA_ETHUSD_S_RSB3"),
            ("crossed", "registered_1_time_msc", "1709374488223"),
            ("crossed", "registered_1_bid", "3427.62"),
            ("crossed", "registered_1_ask", "3427.36"),
            ("crossed", "registered_1_native_count", "1"),
            ("crossed", "registered_1_custom_count", "1"),
            ("crossed", "registered_2_time_msc", "1709375322820"),
            ("crossed", "registered_2_bid", "3418.20"),
            ("crossed", "registered_2_ask", "3418.16"),
            ("crossed", "registered_2_native_count", "1"),
            ("crossed", "registered_2_custom_count", "1"),
            ("summary", "total_ticks", "327417608"),
            ("summary", "unexpected_crossed", "0"),
            ("summary", "backward_timestamps", "0"),
            ("summary", "nonflag_mismatches", "0"),
            ("summary", "invalid_flag_normalizations", "0"),
            ("summary", "transformed_ticks", "96218891"),
            ("summary", "unchanged_ticks", "231198717"),
            ("warmup", "status", "PASS"),
            ("warmup", "from", "2021.04.01 00:00:00"),
            ("warmup", "to_exclusive", "2021.07.01 00:00:00"),
            ("warmup", "m30_bars", "4368"),
            ("warmup", "expected_m30_slots", "4368"),
            ("warmup", "coverage_ratio", "1.00000000"),
            ("warmup", "derived_h4_bars", "546"),
            ("warmup", "unexplained_terminal_gaps", "0"),
            ("warmup", "export_file", "KingEA\\rsb3_warmup_m30_fixture.csv"),
            ("result", "status", "PASS"),
        ]
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "gate.csv"
            with report.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.writer(stream)
                writer.writerow(["section", "key", "value", "unit", "notes"])
                for section, key, value in rows:
                    writer.writerow([section, key, value, "", ""])
            parsed = parse_mt5_gate_report(report)

        self.assertEqual(parsed["status"], "PASS")
        self.assertEqual(parsed["total_ticks"], 327417608)
        self.assertEqual(parsed["registered_crossed"], REGISTERED)
        self.assertEqual(parsed["warmup"]["export_file"], "KingEA\\rsb3_warmup_m30_fixture.csv")

    @staticmethod
    def _evaluate(evidence: dict, sample: Path):
        expected_hash = hashlib.sha256(sample.read_bytes()).hexdigest().upper()
        return evaluate_manifest_evidence(evidence, sample, expected_hash)

    @staticmethod
    def _write_sample(
        path: Path,
        start: str = "2024.03.15 12:00:00",
        end: str = "2024.03.15 13:00:00",
    ):
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(
                stream,
                fieldnames=[
                    "snapshot_utc",
                    "snapshot_server",
                    "section",
                    "key",
                    "value",
                    "unit",
                    "notes",
                ],
            )
            writer.writeheader()
            for index in range(1, 61):
                sample_start = start if index == 33 else f"2020.01.{index:02d} 00:00:00"
                sample_end = end if index == 33 else f"2020.01.{index:02d} 01:00:00"
                if index > 31:
                    sample_start = start if index == 33 else f"2020.02.{index - 31:02d} 00:00:00"
                    sample_end = end if index == 33 else f"2020.02.{index - 31:02d} 01:00:00"
                writer.writerow(
                    {
                        "section": "tick_sample",
                        "key": f"sample_{index:02d}_start",
                        "value": sample_start,
                    }
                )
                writer.writerow(
                    {
                        "section": "tick_sample",
                        "key": f"sample_{index:02d}_end",
                        "value": sample_end,
                    }
                )
            writer.writerow(
                {
                    "section": "summary",
                    "key": "sampled_valid_spreads",
                    "value": "400437",
                }
            )


if __name__ == "__main__":
    unittest.main()
