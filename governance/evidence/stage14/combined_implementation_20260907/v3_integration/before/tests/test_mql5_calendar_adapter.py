import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from research_pipeline.mql5_calendar import (
    CalendarSourceError,
    Mql5WebsiteCalendarAdapter,
    Mql5WebsiteHttpAdapter,
)
from research_pipeline.stage14_cli import main as stage14_main


UTC = timezone.utc


class Mql5WebsiteCalendarAdapterTests(unittest.TestCase):
    def test_build_snapshot_segments_and_filters_to_the_requested_half_open_range(self):
        calls = []

        def fetch(request):
            calls.append(request)
            if len(calls) == 1:
                rows = [
                    self.row(1, "2021-03-31T23:59:59", "CPI y/y"),
                    self.row(2, "2021-04-01T00:00:00", "CPI y/y"),
                    self.row(3, "2021-06-30T00:00:00", "Nonfarm Payrolls"),
                ]
            else:
                rows = [
                    self.row(3, "2021-06-30T00:00:00", "Nonfarm Payrolls"),
                    self.row(4, "2021-06-30T23:59:59", "GDP q/q"),
                    self.row(5, "2021-07-01T00:00:00", "GDP q/q"),
                ]
            return json.dumps(rows, separators=(",", ":")).encode("utf-8")

        snapshot = Mql5WebsiteCalendarAdapter().build_snapshot(
            datetime(2021, 4, 1, tzinfo=UTC),
            datetime(2021, 7, 1, tzinfo=UTC),
            fetch,
        )

        self.assertEqual(2, len(calls))
        self.assertEqual("2021-04-01T00:00:00", calls[0]["from"])
        self.assertEqual("2021-06-29T23:59:59", calls[0]["to"])
        self.assertEqual("2021-06-30T00:00:00", calls[1]["from"])
        self.assertEqual([2, 3, 4], [event["source_id"] for event in snapshot["events"]])
        self.assertEqual(3, snapshot["event_count"])
        self.assertEqual(2, len(snapshot["segments"]))

    def test_conflicting_source_id_across_segments_fails_closed(self):
        calls = 0

        def fetch(_request):
            nonlocal calls
            calls += 1
            row = self.row(9, "2021-04-15T12:30:00" if calls == 1 else "2021-06-30T12:30:00", "CPI y/y")
            return json.dumps([row]).encode("utf-8")

        with self.assertRaisesRegex(CalendarSourceError, "CALENDAR_DUPLICATE_CONFLICT"):
            Mql5WebsiteCalendarAdapter().build_snapshot(
                datetime(2021, 4, 1, tzinfo=UTC),
                datetime(2021, 7, 1, tzinfo=UTC),
                fetch,
            )

    def test_release_epoch_and_full_date_must_describe_the_same_utc_instant(self):
        row = self.row(7, "2021-04-15T12:30:00", "CPI y/y")
        row["FullDate"] = "2021-04-15T13:30:00"

        with self.assertRaisesRegex(CalendarSourceError, "CALENDAR_EVENT_TIME_CONFLICT"):
            Mql5WebsiteCalendarAdapter().build_snapshot(
                datetime(2021, 4, 1, tzinfo=UTC),
                datetime(2021, 5, 1, tzinfo=UTC),
                lambda _request: json.dumps([row]).encode("utf-8"),
            )

    def test_http_adapter_posts_only_the_frozen_public_calendar_contract(self):
        observed = {}

        def transport(url, body, headers):
            observed.update(url=url, body=body, headers=headers)
            return 200, "application/json; charset=utf-8", b"[]"

        payload = {
            "date_mode": "0",
            "from": "2021-04-01T00:00:00",
            "to": "2021-06-29T23:59:59",
            "importance": "8",
            "currencies": "1",
        }
        result = Mql5WebsiteHttpAdapter(transport=transport).fetch_segment(payload)

        self.assertEqual(b"[]", result)
        self.assertEqual("https://www.mql5.com/en/economic-calendar/content", observed["url"])
        self.assertEqual(
            "currencies=1&date_mode=0&from=2021-04-01T00%3A00%3A00&importance=8&to=2021-06-29T23%3A59%3A59",
            observed["body"].decode("ascii"),
        )
        self.assertEqual("XMLHttpRequest", observed["headers"]["X-Requested-With"])

    def test_native_reconciliation_requires_identity_name_and_two_or_three_hour_server_offset(self):
        rows = [
            self.row(21, "2021-04-01T12:30:00", "Initial Jobless Claims"),
            self.row(22, "2021-12-01T13:30:00", "Nonfarm Payrolls"),
        ]
        snapshot = Mql5WebsiteCalendarAdapter().build_snapshot(
            datetime(2021, 4, 1, tzinfo=UTC),
            datetime(2022, 1, 1, tzinfo=UTC),
            lambda _request: json.dumps(rows).encode("utf-8"),
        )
        native_csv = "\n".join(
            [
                "schema,event_id,value_id,time,time_msc,importance,event_type,sector,time_mode,country_id,name,source_url",
                "1,8401,21,2021.04.01 15:30:00,1617291000000,3,1,3,0,840,Initial Jobless Claims,https://example.test/a",
                "1,8402,22,2021.12.01 15:30:00,1638372600000,3,1,3,0,840,Nonfarm Payrolls,https://example.test/b",
            ]
        )

        result = Mql5WebsiteCalendarAdapter().reconcile_native(snapshot, native_csv)

        self.assertTrue(result["passed"])
        self.assertEqual({"7200": 1, "10800": 1}, result["server_offset_seconds"])
        self.assertEqual(2, result["matched_events"])

    def test_coverage_requires_every_month_and_each_frozen_macro_family(self):
        rows = [
            self.row(31, "2021-04-01T12:30:00", "Fed Interest Rate Decision"),
            self.row(32, "2021-04-02T12:30:00", "CPI y/y"),
            self.row(33, "2021-04-03T12:30:00", "Core PCE Price Index m/m"),
            self.row(34, "2021-04-04T12:30:00", "Nonfarm Payrolls"),
            self.row(35, "2021-04-05T12:30:00", "GDP q/q"),
        ]
        adapter = Mql5WebsiteCalendarAdapter()
        snapshot = adapter.build_snapshot(
            datetime(2021, 4, 1, tzinfo=UTC),
            datetime(2021, 5, 1, tzinfo=UTC),
            lambda _request: json.dumps(rows).encode("utf-8"),
        )

        self.assertTrue(adapter.validate_coverage(snapshot)["passed"])
        snapshot["events"] = snapshot["events"][:-1]
        with self.assertRaisesRegex(CalendarSourceError, "CALENDAR_REQUIRED_CATEGORY_MISSING"):
            adapter.validate_coverage(snapshot)

    def test_cli_writes_append_only_raw_snapshot_and_reconciliation_evidence(self):
        rows = [
            self.row(31, "2021-04-01T12:30:00", "Fed Interest Rate Decision"),
            self.row(32, "2021-04-02T12:30:00", "CPI y/y"),
            self.row(33, "2021-04-03T12:30:00", "Core PCE Price Index m/m"),
            self.row(34, "2021-04-04T12:30:00", "Nonfarm Payrolls"),
            self.row(35, "2021-04-05T12:30:00", "GDP q/q"),
        ]
        native_lines = [
            "schema,event_id,value_id,time,time_msc,importance,event_type,sector,time_mode,country_id,name,source_url"
        ]
        for row in rows:
            native_ms = int(row["ReleaseDate"]) + 7_200_000
            native_lines.append(
                f"1,84{row['Id']},{row['Id']},x,{native_ms},3,1,3,0,840,{row['EventName']},https://example.test"
            )

        class FakeHttp:
            def fetch_segment(self, _request):
                return json.dumps(rows).encode("utf-8")

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            native_path = root / "native.csv"
            native_path.write_text("\n".join(native_lines), encoding="utf-8")
            output = root / "evidence"
            argv = [
                "fetch-calendar-website",
                "--start", "2021-04-01T00:00:00+00:00",
                "--end", "2021-05-01T00:00:00+00:00",
                "--native-csv", str(native_path),
                "--output-root", str(output),
            ]
            with patch("research_pipeline.stage14_cli.Mql5WebsiteHttpAdapter", return_value=FakeHttp()):
                self.assertEqual(0, stage14_main(argv))
                self.assertEqual(5, json.loads((output / "manifest.json").read_text())["matched_events"])
                self.assertTrue((output / "native_snapshot.json").is_file())
                self.assertTrue((output / "raw" / "segment_01.json").is_file())
                self.assertEqual(4, stage14_main(argv))

    @staticmethod
    def row(source_id, full_date, name):
        return {
            "Id": source_id,
            "EventType": 1,
            "TimeMode": 0,
            "Processed": 1,
            "Url": "/en/economic-calendar/united-states/example",
            "EventName": name,
            "Importance": "high",
            "CurrencyCode": "USD",
            "ReleaseDate": int(datetime.fromisoformat(full_date).replace(tzinfo=UTC).timestamp() * 1000),
            "Country": 840,
            "FullDate": full_date,
        }


if __name__ == "__main__":
    unittest.main()
