"""Pure deterministic Stage 13 accounting module.

Callers supply immutable facts.  This module performs no broker access and
contains no order capability.
"""

from __future__ import annotations

import hashlib
import json
import csv
import io
from decimal import Decimal, InvalidOperation
from datetime import date, datetime, timedelta, timezone
from html.parser import HTMLParser
from math import isfinite
from typing import Any, Iterable, Mapping


class Stage13Error(ValueError):
    """A fail-closed accounting contract violation."""


class _TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.tables: list[list[list[str]]] = []
        self._table: list[list[str]] | None = None
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del attrs
        tag = tag.lower()
        if tag == "table":
            self._table = []
        elif tag == "tr" and self._table is not None:
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._cell = []

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"td", "th"} and self._cell is not None and self._row is not None:
            self._row.append(" ".join("".join(self._cell).split()))
            self._cell = None
        elif tag == "tr" and self._row is not None and self._table is not None:
            if self._row:
                self._table.append(self._row)
            self._row = None
        elif tag == "table" and self._table is not None:
            if self._table:
                self.tables.append(self._table)
            self._table = None


class Stage13Accounting:
    """Deep interface for accounting, reconciliation, and health reporting."""

    SCHEMA_VERSION = 1
    ZERO_HASH = "0" * 64

    @staticmethod
    def _canonical_bytes(value: Mapping[str, Any]) -> bytes:
        return json.dumps(
            value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
        ).encode("utf-8")

    @classmethod
    def _canonical_sha256(cls, value: Mapping[str, Any]) -> str:
        return hashlib.sha256(cls._canonical_bytes(value)).hexdigest().upper()

    @staticmethod
    def _valid_hash(value: Any) -> bool:
        return (
            isinstance(value, str)
            and len(value) == 64
            and all(character in "0123456789ABCDEF" for character in value)
        )

    @staticmethod
    def _decimal(value: Any, field: str) -> Decimal:
        if not isinstance(value, str):
            raise Stage13Error(f"DECIMAL_STRING_REQUIRED:{field}")
        try:
            result = Decimal(value)
        except InvalidOperation as exc:
            raise Stage13Error(f"DECIMAL_INVALID:{field}") from exc
        if not result.is_finite():
            raise Stage13Error(f"DECIMAL_NON_FINITE:{field}")
        return result

    @staticmethod
    def _money(value: Decimal) -> str:
        return format(value.quantize(Decimal("0.01")), "f")

    def process_batch(
        self,
        events: Iterable[Mapping[str, Any]],
        checkpoint: Mapping[str, Any] | None,
    ) -> dict[str, Any]:
        materialized = [dict(event) for event in events]
        previous_root = self.ZERO_HASH
        previous_sequence = 0
        seen: set[str] = set()
        strategy_net = Decimal("0")
        external_flow = Decimal("0")
        spread_attribution = Decimal("0")
        slippage_attribution = Decimal("0")
        sleeve_net: dict[str, Decimal] = {}
        broker_equity = Decimal("0")
        adjusted_equity_high = Decimal("0")
        sleeve_equity: dict[str, Decimal] = {}
        if checkpoint is not None:
            previous_root = str(checkpoint.get("ledger_root_sha256", ""))
            previous_sequence = int(checkpoint.get("last_sequence", -1))
            seen = {str(value) for value in checkpoint.get("seen_event_ids", [])}
            if not self._valid_hash(previous_root) or previous_sequence < 0:
                return {"status": "QUARANTINED", "reason": "CHECKPOINT_INVALID"}
            state = checkpoint.get("accounting_state", {})
            try:
                strategy_net = self._decimal(
                    state.get("strategy_net_pnl", "0"), "checkpoint.strategy_net_pnl"
                )
                external_flow = self._decimal(
                    state.get("external_cash_flow", "0"), "checkpoint.external_cash_flow"
                )
                spread_attribution = self._decimal(
                    state.get("spread_attribution", "0"), "checkpoint.spread_attribution"
                )
                slippage_attribution = self._decimal(
                    state.get("slippage_attribution", "0"), "checkpoint.slippage_attribution"
                )
                sleeve_net = {
                    str(key): self._decimal(value, f"checkpoint.sleeve.{key}")
                    for key, value in state.get("sleeve_net_pnl", {}).items()
                }
                broker_equity = self._decimal(
                    state.get("broker_equity", "0"), "checkpoint.broker_equity"
                )
                adjusted_equity_high = self._decimal(
                    state.get("adjusted_equity_high", "0"),
                    "checkpoint.adjusted_equity_high",
                )
                sleeve_equity = {
                    str(key): self._decimal(value, f"checkpoint.sleeve_equity.{key}")
                    for key, value in state.get("sleeve_equity", {}).items()
                }
            except (AttributeError, Stage13Error):
                return {"status": "QUARANTINED", "reason": "CHECKPOINT_INVALID"}

        local_ids: set[str] = set()
        for event in materialized:
            event_id = event.get("event_id")
            if not isinstance(event_id, str) or not event_id:
                return {"status": "QUARANTINED", "reason": "EVENT_ID_INVALID"}
            if event_id in seen or event_id in local_ids:
                return {"status": "QUARANTINED", "reason": "DUPLICATE_EVENT"}
            local_ids.add(event_id)

        materialized.sort(
            key=lambda event: (
                int(event.get("server_time_msc", -1)),
                str(event.get("event_type", "")),
                str(event.get("event_id", "")),
            )
        )
        normalized: list[dict[str, Any]] = []
        root = previous_root
        sequence = previous_sequence
        for source in materialized:
            sequence += 1
            event = dict(source)
            event["schema_version"] = self.SCHEMA_VERSION
            event["sequence"] = sequence
            event["previous_event_sha256"] = root
            event["event_sha256"] = self._canonical_sha256(event)
            root = event["event_sha256"]
            normalized.append(event)
            try:
                if event.get("event_type") == "DEAL":
                    net = sum(
                        (
                            self._decimal(event.get(field, "0"), field)
                            for field in ("gross_profit", "commission", "swap", "fee")
                        ),
                        Decimal("0"),
                    )
                    strategy_net += net
                    sleeve_id = str(event.get("sleeve_id", ""))
                    if sleeve_id:
                        sleeve_net[sleeve_id] = sleeve_net.get(sleeve_id, Decimal("0")) + net
                    spread_attribution += self._decimal(
                        event.get("spread_estimate", "0"), "spread_estimate"
                    )
                    slippage_attribution += self._decimal(
                        event.get("slippage_estimate", "0"), "slippage_estimate"
                    )
                elif event.get("event_type") == "EXTERNAL_CASH_FLOW":
                    external_flow += self._decimal(event.get("amount"), "amount")
                elif event.get("event_type") == "VALUATION":
                    broker_equity = self._decimal(event.get("equity"), "equity")
                    adjusted_equity = broker_equity - external_flow
                    adjusted_equity_high = max(adjusted_equity_high, adjusted_equity)
                    sleeve_id = str(event.get("sleeve_id", ""))
                    if sleeve_id:
                        sleeve_equity[sleeve_id] = self._decimal(
                            event.get("sleeve_equity"), "sleeve_equity"
                        )
            except Stage13Error as exc:
                return {"status": "QUARANTINED", "reason": str(exc)}

        all_seen = sorted(seen | local_ids)
        next_checkpoint = {
            "schema_version": self.SCHEMA_VERSION,
            "last_sequence": sequence,
            "ledger_root_sha256": root,
            "seen_event_ids": all_seen,
            "accounting_state": {
                "strategy_net_pnl": self._money(strategy_net),
                "external_cash_flow": self._money(external_flow),
                "spread_attribution": self._money(spread_attribution),
                "slippage_attribution": self._money(slippage_attribution),
                "sleeve_net_pnl": {
                    key: self._money(value) for key, value in sorted(sleeve_net.items())
                },
                "broker_equity": self._money(broker_equity),
                "adjusted_equity_high": self._money(adjusted_equity_high),
                "sleeve_equity": {
                    key: self._money(value) for key, value in sorted(sleeve_equity.items())
                },
            },
        }
        next_checkpoint["checkpoint_sha256"] = self._canonical_sha256(next_checkpoint)
        return {
            "status": "ACCEPTED",
            "reason": "BATCH_ACCEPTED",
            "event_count": len(normalized),
            "events": normalized,
            "ledger_root_sha256": root,
            "checkpoint": next_checkpoint,
            "account_summary": {
                "strategy_net_pnl": self._money(strategy_net),
                "external_cash_flow": self._money(external_flow),
                "spread_attribution": self._money(spread_attribution),
                "slippage_attribution": self._money(slippage_attribution),
                "broker_equity": self._money(broker_equity),
                "cash_flow_adjusted_equity": self._money(broker_equity-external_flow),
                "cash_flow_adjusted_equity_high": self._money(adjusted_equity_high),
            },
            "sleeve_summaries": {
                key: {
                    "strategy_net_pnl": self._money(sleeve_net.get(key, Decimal("0"))),
                    "equity": self._money(sleeve_equity.get(key, Decimal("0"))),
                }
                for key in sorted(set(sleeve_net) | set(sleeve_equity))
            },
        }

    def reconcile_statement(
        self,
        ledger_events: Iterable[Mapping[str, Any]],
        statement_records: Iterable[Mapping[str, Any]],
        *,
        tick_size: str,
        volume_step: str,
        currency_unit: str,
    ) -> dict[str, Any]:
        """Reconcile normalized statement facts without allowing net offsets."""
        try:
            tick = self._decimal(tick_size, "tick_size")
            step = self._decimal(volume_step, "volume_step")
            unit = self._decimal(currency_unit, "currency_unit")
        except Stage13Error as exc:
            return {"status": "RECONCILIATION_QUARANTINE", "reason": str(exc)}
        if tick <= 0 or step <= 0 or unit <= 0:
            return {"status": "RECONCILIATION_QUARANTINE", "reason": "TOLERANCE_INVALID"}

        ledger_rows = [dict(row) for row in ledger_events]
        statement_rows = [dict(row) for row in statement_records]
        ledger = {
            str(row.get("deal_ticket")): dict(row)
            for row in ledger_rows
            if row.get("event_type") == "DEAL"
        }
        statement = {
            str(row.get("deal_ticket")): dict(row)
            for row in statement_rows
            if row.get("event_type") == "DEAL"
        }
        mismatches: list[dict[str, str]] = []
        if len(ledger) != sum(1 for row in ledger_rows if row.get("event_type") == "DEAL"):
            mismatches.append({"ticket": "*", "field": "ledger_cardinality"})
        if len(statement) != sum(1 for row in statement_rows if row.get("event_type") == "DEAL"):
            mismatches.append({"ticket": "*", "field": "statement_cardinality"})
        for ticket in sorted(set(ledger) | set(statement)):
            if ticket not in ledger or ticket not in statement or not ticket:
                mismatches.append({"ticket": ticket, "field": "ticket"})
                continue
            left = ledger[ticket]
            right = statement[ticket]
            if abs(int(left.get("server_time_msc", -10_000)) - int(right.get("server_time_msc", 10_000))) > 1000:
                mismatches.append({"ticket": ticket, "field": "server_time_msc"})
            try:
                if abs(self._decimal(left.get("volume"), "volume") - self._decimal(right.get("volume"), "volume")) >= step:
                    mismatches.append({"ticket": ticket, "field": "volume"})
                if abs(self._decimal(left.get("price"), "price") - self._decimal(right.get("price"), "price")) > tick:
                    mismatches.append({"ticket": ticket, "field": "price"})
                for field in ("gross_profit", "commission", "swap", "fee"):
                    left_money = self._decimal(left.get(field, "0"), field).quantize(unit)
                    right_money = self._decimal(right.get(field, "0"), field).quantize(unit)
                    if left_money != right_money:
                        mismatches.append({"ticket": ticket, "field": field})
            except Stage13Error as exc:
                mismatches.append({"ticket": ticket, "field": str(exc)})
        return {
            "status": "RECONCILED" if not mismatches else "RECONCILIATION_QUARANTINE",
            "reason": "EXACT_MATCH" if not mismatches else "MATERIAL_MISMATCH",
            "mismatch_count": len(mismatches),
            "mismatches": mismatches,
        }

    def evaluate_controls(
        self,
        *,
        as_of_broker_day: str,
        month_closes: Iterable[Mapping[str, Any]],
        quarantine_dates: Iterable[str],
    ) -> dict[str, Any]:
        """Evaluate isolated and cumulative accounting latches."""
        try:
            as_of = date.fromisoformat(as_of_broker_day)
            months = [dict(row) for row in month_closes]
            if len(months) != len({str(row.get("month")) for row in months}):
                raise ValueError("duplicate month")
            months = sorted(months, key=lambda row: str(row.get("month")))[-6:]
            coverage_failures = sum(
                1 for row in months if row.get("status") != "ACCEPTED"
            )
            cutoff = as_of - timedelta(days=90)
            active_dates = [date.fromisoformat(value) for value in quarantine_dates]
            integrity_failures = sum(1 for value in active_dates if cutoff < value <= as_of)
        except (TypeError, ValueError):
            return {
                "status": "CUMULATIVE_ACCOUNTING_REVIEW",
                "governing_latch": "CUMULATIVE",
                "reason": "CONTROL_HISTORY_INVALID",
            }
        if coverage_failures >= 3 or integrity_failures >= 2:
            status = "CUMULATIVE_ACCOUNTING_REVIEW"
            latch = "CUMULATIVE"
        elif integrity_failures == 1:
            status = "RECONCILIATION_QUARANTINE"
            latch = "ISOLATED"
        elif coverage_failures:
            status = "NOT_RECONCILED"
            latch = "MONTH_CLOSE"
        else:
            status = "ACCOUNTING_HEALTHY"
            latch = "NONE"
        return {
            "status": status,
            "governing_latch": latch,
            "coverage_failures": coverage_failures,
            "integrity_failures": integrity_failures,
            "entry_allowed": status == "ACCOUNTING_HEALTHY",
        }

    def review_recovery(
        self,
        *,
        latch: str,
        previously_earned_tier: float,
        evidence: Mapping[str, Any],
        clean_days: int,
        current_epoch: int,
    ) -> dict[str, Any]:
        required = {
            "originals_preserved",
            "append_only_corrections",
            "root_cause_documented",
            "fresh_broker_capture",
            "replay_exact",
            "integrity_tests_passed",
            "owner_approved",
        }
        if latch == "CUMULATIVE_ACCOUNTING_REVIEW":
            required.add("outstanding_months_reconciled")
        valid_latches = {"RECONCILIATION_QUARANTINE", "CUMULATIVE_ACCOUNTING_REVIEW"}
        if (
            latch not in valid_latches
            or not isinstance(clean_days, int)
            or clean_days < 0
            or not isinstance(current_epoch, int)
            or current_epoch < 0
            or not isinstance(previously_earned_tier, (int, float))
            or isinstance(previously_earned_tier, bool)
            or previously_earned_tier <= 0.0
        ):
            return {"status": "REVIEW_LATCHED", "reason": "REVIEW_FACTS_INVALID"}
        missing = sorted(key for key in required if evidence.get(key) is not True)
        if missing:
            return {
                "status": "REVIEW_LATCHED",
                "reason": "REVIEW_EVIDENCE_INCOMPLETE",
                "missing": missing,
            }
        if latch == "CUMULATIVE_ACCOUNTING_REVIEW":
            return {
                "status": "BOTTOM_TIER_RAMP",
                "effective_tier_percent": 0.25,
                "fresh_30_trade_30_day_ramp": True,
                "archive_active_events": True,
                "next_epoch": current_epoch + 1,
            }
        reduced = round(float(previously_earned_tier) * 0.5, 6)
        if clean_days < 5:
            return {
                "status": "RECOVERY_ACTIVE",
                "effective_tier_percent": reduced,
                "clean_days": clean_days,
                "clean_days_required": 5,
                "archive_active_events": False,
                "next_epoch": current_epoch,
            }
        return {
            "status": "RECOVERY_CLEARED",
            "effective_tier_percent": float(previously_earned_tier),
            "clean_days": clean_days,
            "clean_days_required": 5,
            "archive_active_events": False,
            "next_epoch": current_epoch,
        }

    def build_health_review(
        self,
        *,
        period: str,
        observed: Mapping[str, Any],
        expected_range_manifest: Mapping[str, Any] | None,
        reconciliation_status: str,
    ) -> dict[str, Any]:
        if reconciliation_status == "RECONCILIATION_QUARANTINE":
            return {
                "period": period,
                "classification": "RECONCILIATION_QUARANTINE",
                "pause_tier_advancement": True,
                "entry_allowed": False,
                "flatten_required": False,
                "outside_metrics": [],
            }
        if (
            expected_range_manifest is None
            or expected_range_manifest.get("status") != "AUTHORIZED"
            or not self._valid_hash(expected_range_manifest.get("manifest_sha256"))
            or not isinstance(expected_range_manifest.get("ranges"), Mapping)
        ):
            return {
                "period": period,
                "classification": "NOT_EVALUABLE",
                "pause_tier_advancement": True,
                "entry_allowed": reconciliation_status == "RECONCILED",
                "flatten_required": False,
                "outside_metrics": [],
            }
        ranges = expected_range_manifest["ranges"]
        if set(observed) != set(ranges):
            return {
                "period": period,
                "classification": "NOT_EVALUABLE",
                "pause_tier_advancement": True,
                "entry_allowed": reconciliation_status == "RECONCILED",
                "flatten_required": False,
                "outside_metrics": [],
            }
        outside: list[str] = []
        for metric, raw in observed.items():
            if isinstance(raw, bool) or not isinstance(raw, (int, float)) or not isfinite(float(raw)):
                return {
                    "period": period,
                    "classification": "NOT_EVALUABLE",
                    "pause_tier_advancement": True,
                    "entry_allowed": False,
                    "flatten_required": False,
                    "outside_metrics": [],
                }
            limits = ranges[metric]
            if not isinstance(limits, Mapping):
                outside.append(metric)
                continue
            if "minimum" in limits and float(raw) < float(limits["minimum"]):
                outside.append(metric)
            if "maximum" in limits and float(raw) > float(limits["maximum"]):
                outside.append(metric)
        classification = "IN_RANGE" if not outside else "OUTSIDE_RANGE"
        return {
            "period": period,
            "classification": classification,
            "pause_tier_advancement": bool(outside),
            "entry_allowed": reconciliation_status == "RECONCILED",
            "flatten_required": False,
            "outside_metrics": sorted(set(outside)),
            "expected_range_manifest_sha256": expected_range_manifest["manifest_sha256"],
        }

    def parse_mt5_html_statement(
        self,
        html_text: str,
        *,
        account_fingerprint: str,
        server_utc_offset_seconds: int,
    ) -> dict[str, Any]:
        if (
            not isinstance(html_text, str)
            or not self._valid_hash(account_fingerprint)
            or not isinstance(server_utc_offset_seconds, int)
            or abs(server_utc_offset_seconds) > 14 * 3600
        ):
            return {"status": "UNSUPPORTED_TEMPLATE", "reason": "INPUT_INVALID"}
        parser = _TableParser()
        try:
            parser.feed(html_text)
        except Exception:
            return {"status": "UNSUPPORTED_TEMPLATE", "reason": "HTML_INVALID"}
        required = {"deal", "time", "type", "symbol", "volume", "price", "profit"}
        selected: list[list[str]] | None = None
        headers: list[str] = []
        for table in parser.tables:
            if not table:
                continue
            candidate = [value.strip().lower() for value in table[0]]
            if required.issubset(candidate):
                selected = table
                headers = candidate
                break
        if selected is None:
            return {"status": "UNSUPPORTED_TEMPLATE", "reason": "ENGLISH_DEALS_TABLE_MISSING"}
        indexes = {name: headers.index(name) for name in required}
        optional = {
            name: headers.index(name) for name in ("commission", "swap", "fee") if name in headers
        }
        records: list[dict[str, Any]] = []
        zone = timezone(timedelta(seconds=server_utc_offset_seconds))
        for row in selected[1:]:
            if len(row) < len(headers):
                return {"status": "UNSUPPORTED_TEMPLATE", "reason": "DEAL_ROW_MALFORMED"}
            try:
                parsed_time = datetime.strptime(row[indexes["time"]], "%Y.%m.%d %H:%M:%S").replace(tzinfo=zone)
                server_time_msc = int(parsed_time.timestamp() * 1000)
                record = {
                    "event_type": "DEAL",
                    "deal_ticket": row[indexes["deal"]],
                    "server_time_msc": server_time_msc,
                    "statement_time": row[indexes["time"]],
                    "type": row[indexes["type"]].lower(),
                    "symbol": row[indexes["symbol"]],
                    "volume": str(self._decimal(row[indexes["volume"]], "volume")),
                    "price": str(self._decimal(row[indexes["price"]], "price")),
                    "gross_profit": str(self._decimal(row[indexes["profit"]], "profit")),
                    "commission": str(self._decimal(row[optional["commission"]], "commission")) if "commission" in optional else "0",
                    "swap": str(self._decimal(row[optional["swap"]], "swap")) if "swap" in optional else "0",
                    "fee": str(self._decimal(row[optional["fee"]], "fee")) if "fee" in optional else "0",
                    "account_fingerprint": account_fingerprint,
                }
            except (Stage13Error, ValueError, IndexError):
                return {"status": "UNSUPPORTED_TEMPLATE", "reason": "DEAL_ROW_INVALID"}
            records.append(record)
        if not records:
            return {"status": "UNSUPPORTED_TEMPLATE", "reason": "DEALS_EMPTY"}
        return {
            "status": "PARSED",
            "template": "MT5_ENGLISH_HTML_DEALS_V1",
            "source_sha256": hashlib.sha256(html_text.encode("utf-8")).hexdigest().upper(),
            "account_fingerprint": account_fingerprint,
            "records": records,
        }

    def render_export_bundle(
        self,
        *,
        batch: Mapping[str, Any],
        health_review: Mapping[str, Any],
    ) -> dict[str, Any]:
        if batch.get("status") != "ACCEPTED" or not isinstance(batch.get("events"), list):
            raise Stage13Error("EXPORT_BATCH_NOT_ACCEPTED")
        prohibited = {"account_login", "account_number", "raw_login", "login"}
        serialized_input = json.dumps(batch, sort_keys=True).lower()
        if any(f'"{key}"' in serialized_input for key in prohibited):
            raise Stage13Error("RAW_ACCOUNT_ID_PROHIBITED")
        events_jsonl = "".join(
            json.dumps(event, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
            for event in batch["events"]
        )
        fields = [
            "event_id",
            "event_type",
            "server_time_msc",
            "utc_time_msc",
            "sleeve_id",
            "trade_group_id",
            "sequence",
            "event_sha256",
        ]
        stream = io.StringIO(newline="")
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(batch["events"])
        events_csv = stream.getvalue()
        classification = str(health_review.get("classification", "NOT_EVALUABLE"))
        health_markdown = (
            "# KingEA Accounting Health Review\n\n"
            f"- Period: `{health_review.get('period', 'UNSPECIFIED')}`\n"
            f"- Classification: `{classification}`\n"
            f"- Tier advancement paused: `{str(bool(health_review.get('pause_tier_advancement', True))).lower()}`\n"
            f"- Ledger root: `{batch.get('ledger_root_sha256', '')}`\n"
        )
        artifact_hashes = {
            "events_jsonl": hashlib.sha256(events_jsonl.encode("utf-8")).hexdigest().upper(),
            "events_csv": hashlib.sha256(events_csv.encode("utf-8")).hexdigest().upper(),
            "health_markdown": hashlib.sha256(health_markdown.encode("utf-8")).hexdigest().upper(),
        }
        manifest_base = {
            "schema_version": self.SCHEMA_VERSION,
            "event_count": len(batch["events"]),
            "ledger_root_sha256": batch.get("ledger_root_sha256"),
            "health_classification": classification,
            "artifact_hashes": artifact_hashes,
        }
        manifest = dict(manifest_base)
        manifest["bundle_sha256"] = self._canonical_sha256(manifest_base)
        return {
            "events_jsonl": events_jsonl,
            "events_csv": events_csv,
            "health_markdown": health_markdown,
            "manifest": manifest,
        }

    @staticmethod
    def _parse_pipe_frame(value: str) -> dict[str, str]:
        result: dict[str, str] = {}
        for token in value.split("|"):
            if "=" not in token:
                continue
            key, content = token.split("=", 1)
            if key in result:
                raise Stage13Error(f"FRAME_FIELD_DUPLICATE:{key}")
            result[key] = content
        return result

    def validate_tester_frames(
        self,
        *,
        event_frames: Iterable[str],
        completion_frame: str,
        legacy_trade_returns: Iterable[float],
        legacy_trade_r: Iterable[float],
        legacy_trade_net: Iterable[float],
    ) -> dict[str, Any]:
        reasons: list[str] = []
        try:
            events = [self._parse_pipe_frame(value) for value in event_frames]
            complete = self._parse_pipe_frame(completion_frame)
            returns = [Decimal(str(value)) for value in legacy_trade_returns]
            r_values = [Decimal(str(value)) for value in legacy_trade_r]
            net_values = [Decimal(str(value)) for value in legacy_trade_net]
            if any(not value.is_finite() for value in returns + r_values + net_values):
                raise Stage13Error("LEGACY_VALUE_INVALID")
            sequences = [int(event["sequence"]) for event in events]
            identifiers = [event["event_id"] for event in events]
            if sequences != list(range(1, len(events) + 1)):
                reasons.append("ACCOUNTING_SEQUENCE_INCOMPLETE")
            if len(identifiers) != len(set(identifiers)):
                reasons.append("ACCOUNTING_EVENT_DUPLICATE")
            if any(event.get("schema") != "1" or not self._valid_hash(event.get("root")) for event in events):
                reasons.append("ACCOUNTING_EVENT_INVALID")
            close_events = [event for event in events if event.get("event_type") == "9"]
            close_net = [Decimal(event.get("net", "NaN")) for event in close_events]
            close_returns = [Decimal(event.get("net_return", "NaN")) for event in close_events]
            close_r = [Decimal(event.get("net_r", "NaN")) for event in close_events]
            if (
                len(events) != int(complete.get("event_count", "-1"))
                or len(close_events) != int(complete.get("close_count", "-1"))
                or len(returns) != int(complete.get("trade_return_count", "-1"))
                or complete.get("complete") != "1"
                or (events and complete.get("root") != events[-1].get("root"))
            ):
                reasons.append("ACCOUNTING_COMPLETION_MISMATCH")
            tolerance = Decimal("0.000000000001")
            if len(close_events) != len(returns) or len(returns) != len(r_values) or len(r_values) != len(net_values):
                reasons.append("LEGACY_CARDINALITY_MISMATCH")
            else:
                for index in range(len(close_events)):
                    if abs(close_net[index] - net_values[index]) > tolerance:
                        reasons.append("LEGACY_NET_MISMATCH")
                    if abs(close_returns[index] - returns[index]) > tolerance:
                        reasons.append("LEGACY_RETURN_MISMATCH")
                    if abs(close_r[index] - r_values[index]) > tolerance:
                        reasons.append("LEGACY_R_MISMATCH")
            if abs(sum(net_values, Decimal("0")) - Decimal(complete.get("legacy_net", "NaN"))) > tolerance:
                reasons.append("LEGACY_SUMMARY_MISMATCH")
            if abs(sum(close_net, Decimal("0")) - Decimal(complete.get("ledger_net", "NaN"))) > tolerance:
                reasons.append("LEDGER_SUMMARY_MISMATCH")
        except (KeyError, TypeError, ValueError, InvalidOperation, Stage13Error):
            reasons.append("ACCOUNTING_FRAME_INVALID")
        return {"passed": not reasons, "reasons": sorted(set(reasons))}
