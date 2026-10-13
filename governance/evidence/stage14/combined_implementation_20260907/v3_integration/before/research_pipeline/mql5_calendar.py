"""Governed MQL5 website economic-calendar source adapter.

The module hides the website's inclusive and timezone-sensitive response
behavior behind one UTC, half-open snapshot interface.  Network and filesystem
effects are supplied by adapters at the seam.
"""

from __future__ import annotations

import hashlib
import csv
import io
import json
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Mapping


UTC = timezone.utc


class CalendarSourceError(RuntimeError):
    pass


class Mql5WebsiteHttpAdapter:
    """Read-only HTTP adapter for the single frozen MQL5 calendar endpoint."""

    URL = "https://www.mql5.com/en/economic-calendar/content"
    REFERER = "https://www.mql5.com/en/economic-calendar"
    MAX_RESPONSE_BYTES = 10_000_000

    def __init__(self, *, transport=None):
        self._transport = transport or self._urlopen_transport

    def fetch_segment(self, request: Mapping[str, str]) -> bytes:
        expected = {"date_mode", "from", "to", "importance", "currencies"}
        if set(request) != expected:
            raise CalendarSourceError("CALENDAR_HTTP_REQUEST_FIELDS_INVALID")
        body = urllib.parse.urlencode(sorted(request.items())).encode("ascii")
        headers = {
            "Accept": "application/json, text/javascript, */*; q=0.01",
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "Referer": self.REFERER,
            "User-Agent": "KingEA-Stage14-Calendar/1.0",
            "X-Requested-With": "XMLHttpRequest",
        }
        status, content_type, content = self._transport(self.URL, body, headers)
        if status != 200:
            raise CalendarSourceError("CALENDAR_HTTP_STATUS_INVALID")
        if not str(content_type).lower().startswith("application/json"):
            raise CalendarSourceError("CALENDAR_HTTP_CONTENT_TYPE_INVALID")
        if not isinstance(content, bytes) or not content or len(content) > self.MAX_RESPONSE_BYTES:
            raise CalendarSourceError("CALENDAR_HTTP_BODY_INVALID")
        return content

    @classmethod
    def _urlopen_transport(cls, url: str, body: bytes, headers: Mapping[str, str]):
        request = urllib.request.Request(url, data=body, headers=dict(headers), method="POST")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                content = response.read(cls.MAX_RESPONSE_BYTES + 1)
                final_url = response.geturl()
                status = response.status
                content_type = response.headers.get("Content-Type", "")
        except OSError as exc:
            raise CalendarSourceError("CALENDAR_HTTP_TRANSPORT_FAILURE") from exc
        if final_url != cls.URL:
            raise CalendarSourceError("CALENDAR_HTTP_REDIRECT_REFUSED")
        return status, content_type, content


class Mql5WebsiteCalendarAdapter:
    """Build one deterministic calendar snapshot from bounded source calls."""

    SEGMENT_DAYS = 90

    def build_snapshot(
        self,
        start: datetime,
        end: datetime,
        fetch_segment: Callable[[Mapping[str, str]], bytes],
    ) -> dict[str, Any]:
        start = self._utc(start)
        end = self._utc(end)
        if end <= start:
            raise CalendarSourceError("CALENDAR_RANGE_INVALID")

        events: dict[int, dict[str, Any]] = {}
        segments = []
        cursor = start
        while cursor < end:
            segment_end = min(cursor + timedelta(days=self.SEGMENT_DAYS), end)
            request = {
                "date_mode": "0",
                "from": self._source_time(cursor),
                "to": self._source_time(segment_end - timedelta(seconds=1)),
                "importance": "8",
                "currencies": "1",
            }
            raw = fetch_segment(request)
            if not isinstance(raw, bytes) or not raw:
                raise CalendarSourceError("CALENDAR_RESPONSE_EMPTY")
            try:
                rows = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                raise CalendarSourceError("CALENDAR_RESPONSE_INVALID_JSON") from exc
            if not isinstance(rows, list):
                raise CalendarSourceError("CALENDAR_RESPONSE_NOT_ARRAY")

            accepted = 0
            for row in rows:
                event = self._normalize_event(row)
                observed_at = datetime.fromtimestamp(event["release_time_utc_ms"] / 1000, UTC)
                if not (cursor <= observed_at < segment_end):
                    continue
                previous = events.get(event["source_id"])
                if previous is not None and previous != event:
                    raise CalendarSourceError("CALENDAR_DUPLICATE_CONFLICT")
                if previous is None:
                    events[event["source_id"]] = event
                    accepted += 1

            segments.append(
                {
                    "from": request["from"],
                    "to": request["to"],
                    "response_sha256": hashlib.sha256(raw).hexdigest().upper(),
                    "response_rows": len(rows),
                    "accepted_rows": accepted,
                }
            )
            cursor = segment_end

        ordered = sorted(events.values(), key=lambda event: (event["release_time_utc_ms"], event["source_id"]))
        snapshot = {
            "schema": 1,
            "source": "MQL5_WEBSITE_ECONOMIC_CALENDAR",
            "source_url": "https://www.mql5.com/en/economic-calendar/content",
            "coverage": f"[{start.isoformat()},{end.isoformat()})",
            "event_count": len(ordered),
            "segments": segments,
            "events": ordered,
        }
        snapshot["snapshot_sha256"] = self._canonical_hash(snapshot)
        return snapshot

    def reconcile_native(self, snapshot: Mapping[str, Any], native_csv: str) -> dict[str, Any]:
        if not isinstance(native_csv, str) or not native_csv.strip():
            raise CalendarSourceError("CALENDAR_NATIVE_EVIDENCE_EMPTY")
        reader = csv.DictReader(io.StringIO(native_csv))
        required = {"value_id", "time_msc", "importance", "country_id", "name"}
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            raise CalendarSourceError("CALENDAR_NATIVE_SCHEMA_INVALID")
        native: dict[int, dict[str, str]] = {}
        for row in reader:
            try:
                value_id = int(row["value_id"])
                if int(row["importance"]) != 3 or int(row["country_id"]) != 840:
                    raise CalendarSourceError("CALENDAR_NATIVE_FILTER_VIOLATION")
            except (TypeError, ValueError) as exc:
                raise CalendarSourceError("CALENDAR_NATIVE_ROW_INVALID") from exc
            if value_id in native:
                raise CalendarSourceError("CALENDAR_NATIVE_DUPLICATE_ID")
            native[value_id] = row

        website = {int(event["source_id"]): event for event in snapshot.get("events", [])}
        if not website or set(website) != set(native):
            raise CalendarSourceError("CALENDAR_NATIVE_ID_SET_MISMATCH")

        offsets: dict[str, int] = {}
        for value_id, event in website.items():
            row = native[value_id]
            if row["name"] != event["name"]:
                raise CalendarSourceError("CALENDAR_NATIVE_NAME_MISMATCH")
            try:
                native_ms = int(row["time_msc"])
            except (TypeError, ValueError) as exc:
                raise CalendarSourceError("CALENDAR_NATIVE_TIME_INVALID") from exc
            delta_ms = native_ms - int(event["release_time_utc_ms"])
            if delta_ms % 1000:
                raise CalendarSourceError("CALENDAR_NATIVE_TIME_PRECISION_MISMATCH")
            offset = delta_ms // 1000
            if offset not in (7200, 10800):
                raise CalendarSourceError("CALENDAR_NATIVE_SERVER_OFFSET_INVALID")
            key = str(offset)
            offsets[key] = offsets.get(key, 0) + 1

        return {
            "passed": True,
            "matched_events": len(website),
            "server_offset_seconds": dict(sorted(offsets.items())),
            "native_csv_sha256": hashlib.sha256(native_csv.encode("utf-8")).hexdigest().upper(),
            "website_snapshot_sha256": snapshot.get("snapshot_sha256"),
        }

    def validate_coverage(self, snapshot: Mapping[str, Any]) -> dict[str, Any]:
        """Prove calendar-month continuity and the frozen macro-family coverage."""
        coverage = str(snapshot.get("coverage", ""))
        if not (coverage.startswith("[") and coverage.endswith(")") and "," in coverage):
            raise CalendarSourceError("CALENDAR_COVERAGE_INVALID")
        start_text, end_text = coverage[1:-1].split(",", 1)
        try:
            start = self._utc(datetime.fromisoformat(start_text))
            end = self._utc(datetime.fromisoformat(end_text))
        except ValueError as exc:
            raise CalendarSourceError("CALENDAR_COVERAGE_INVALID") from exc
        if end <= start:
            raise CalendarSourceError("CALENDAR_COVERAGE_INVALID")

        expected_months: list[str] = []
        month = datetime(start.year, start.month, 1, tzinfo=UTC)
        while month < end:
            expected_months.append(month.strftime("%Y-%m"))
            month = (
                datetime(month.year + 1, 1, 1, tzinfo=UTC)
                if month.month == 12
                else datetime(month.year, month.month + 1, 1, tzinfo=UTC)
            )

        month_counts = {key: 0 for key in expected_months}
        category_counts = {
            "central_bank": 0,
            "inflation": 0,
            "employment": 0,
            "gdp": 0,
        }
        for event in snapshot.get("events", []):
            try:
                observed = datetime.fromtimestamp(int(event["release_time_utc_ms"]) / 1000, UTC)
                name = str(event["name"]).casefold()
            except (KeyError, TypeError, ValueError, OSError) as exc:
                raise CalendarSourceError("CALENDAR_EVENT_FIELDS_INVALID") from exc
            if not (start <= observed < end):
                raise CalendarSourceError("CALENDAR_EVENT_OUTSIDE_COVERAGE")
            key = observed.strftime("%Y-%m")
            if key not in month_counts:
                raise CalendarSourceError("CALENDAR_EVENT_OUTSIDE_COVERAGE")
            month_counts[key] += 1

            if any(token in name for token in ("fomc", "fed interest rate decision", "federal reserve")):
                category_counts["central_bank"] += 1
            if any(token in name for token in ("cpi", "pce")):
                category_counts["inflation"] += 1
            if any(
                token in name
                for token in ("nonfarm payrolls", "unemployment rate", "adp", "jolts", "employment")
            ):
                category_counts["employment"] += 1
            if "gdp" in name:
                category_counts["gdp"] += 1

        missing_months = [key for key, count in month_counts.items() if count == 0]
        if missing_months:
            raise CalendarSourceError("CALENDAR_MONTH_COVERAGE_MISSING")
        if any(count == 0 for count in category_counts.values()):
            raise CalendarSourceError("CALENDAR_REQUIRED_CATEGORY_MISSING")
        counts = list(month_counts.values())
        return {
            "passed": True,
            "month_count": len(month_counts),
            "minimum_events_per_month": min(counts),
            "maximum_events_per_month": max(counts),
            "category_counts": category_counts,
        }

    @staticmethod
    def _utc(value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise CalendarSourceError("CALENDAR_TIMEZONE_REQUIRED")
        return value.astimezone(UTC).replace(microsecond=0)

    @staticmethod
    def _source_time(value: datetime) -> str:
        return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S")

    @staticmethod
    def _canonical_hash(value: Mapping[str, Any]) -> str:
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest().upper()

    @staticmethod
    def _normalize_event(row: Any) -> dict[str, Any]:
        if not isinstance(row, dict):
            raise CalendarSourceError("CALENDAR_EVENT_INVALID")
        try:
            source_id = int(row["Id"])
            release_ms = int(row["ReleaseDate"])
            name = str(row["EventName"]).strip()
            url = str(row["Url"]).strip()
            importance = str(row["Importance"]).lower()
            currency = str(row["CurrencyCode"]).upper()
            country = int(row["Country"])
            full_date = str(row["FullDate"])
        except (KeyError, TypeError, ValueError) as exc:
            raise CalendarSourceError("CALENDAR_EVENT_FIELDS_INVALID") from exc
        if source_id <= 0 or release_ms <= 0 or not name or not url:
            raise CalendarSourceError("CALENDAR_EVENT_FIELDS_INVALID")
        if importance != "high" or currency != "USD" or country != 840:
            raise CalendarSourceError("CALENDAR_EVENT_FILTER_VIOLATION")
        try:
            described_time = datetime.fromisoformat(full_date)
        except ValueError as exc:
            raise CalendarSourceError("CALENDAR_EVENT_TIME_INVALID") from exc
        if described_time.tzinfo is None:
            described_time = described_time.replace(tzinfo=UTC)
        else:
            described_time = described_time.astimezone(UTC)
        if int(described_time.timestamp() * 1000) != release_ms:
            raise CalendarSourceError("CALENDAR_EVENT_TIME_CONFLICT")
        return {
            "source_id": source_id,
            "release_time_utc_ms": release_ms,
            "full_date_utc": full_date,
            "name": name,
            "url": url,
            "event_type": int(row.get("EventType", 0)),
            "time_mode": int(row.get("TimeMode", 0)),
            "processed": int(row.get("Processed", 0)),
            "importance": importance,
            "currency": currency,
            "country": country,
        }
