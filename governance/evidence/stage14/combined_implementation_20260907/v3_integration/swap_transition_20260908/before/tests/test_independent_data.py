import csv
import sys
import tempfile
import unittest
import zipfile
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "data_pipeline"))

from independent_data import SyntheticCost, aggtrade_rows, month_range, normalize_timestamp_msc


class IndependentDataTests(unittest.TestCase):
    def test_exact_five_year_month_range(self):
        months = list(month_range("2021-07", "2026-07"))
        self.assertEqual(60, len(months))
        self.assertEqual("2021-07", months[0])
        self.assertEqual("2026-06", months[-1])

    def test_millisecond_and_microsecond_timestamp_normalization(self):
        self.assertEqual(1735689600010, normalize_timestamp_msc("1735689600010"))
        self.assertEqual(1735689600010, normalize_timestamp_msc("1735689600010000"))

    def test_synthetic_quote_is_conservative_and_tick_aligned(self):
        model = SyntheticCost(Decimal("0.01"), Decimal("1.26"), Decimal("10"))
        bid, ask = model.quote(Decimal("2000"))
        self.assertEqual(Decimal("1999.00"), bid)
        self.assertEqual(Decimal("2001.00"), ask)
        self.assertGreaterEqual(ask - bid, Decimal("2.00"))

    def test_aggtrade_zip_parser(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sample.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(
                    "sample.csv",
                    "agg_trade_id,price,quantity,first_trade_id,last_trade_id,transact_time,is_buyer_maker,is_best_match\n"
                    "1,2000.10,0.25,1,1,1735689600010,true,true\n",
                )
            rows = list(aggtrade_rows(path))
            self.assertEqual([(1735689600010, Decimal("2000.10"), Decimal("0.25"))], rows)


if __name__ == "__main__":
    unittest.main()
