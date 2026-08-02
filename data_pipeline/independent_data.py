"""KingEA pre-freeze independent ETH dataset tooling.

This module downloads and verifies market data; normalizes Binance aggregate
trades into synthetic MT5 Bid/Ask ticks; and emits integrity manifests.  It
contains no strategy, signal, return, ranking, or optimization logic.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import os
import time
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR
from pathlib import Path
from typing import Iterable, Iterator


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "data" / "manifest" / "KINGEA_ETH_INDEPENDENT_V1.json"
USER_AGENT = "KingEA-DataAudit/1.0 non-trading research tooling"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def parse_month(value: str) -> tuple[int, int]:
    parsed = datetime.strptime(value, "%Y-%m")
    return parsed.year, parsed.month


def month_range(start: str, end_exclusive: str) -> Iterator[str]:
    year, month = parse_month(start)
    end_year, end_month = parse_month(end_exclusive)
    while (year, month) < (end_year, end_month):
        yield f"{year:04d}-{month:02d}"
        month += 1
        if month == 13:
            year += 1
            month = 1


def next_month(month: str) -> str:
    year, value = parse_month(month)
    value += 1
    if value == 13:
        year += 1
        value = 1
    return f"{year:04d}-{value:02d}"


def load_manifest(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as stream:
        manifest = json.load(stream)
    if manifest.get("status") != "DRAFT_NOT_FROZEN":
        raise ValueError("This tool expects an explicitly draft pre-freeze manifest")
    return manifest


def coverage_months(manifest: dict) -> list[str]:
    start = manifest["coverage"]["start_utc_inclusive"][:7]
    end = manifest["coverage"]["end_utc_exclusive"][:7]
    months = list(month_range(start, end))
    expected = int(manifest["coverage"]["complete_calendar_months"])
    if len(months) != expected:
        raise ValueError(f"Manifest says {expected} months but boundaries produce {len(months)}")
    return months


def request_bytes(url: str, timeout: int = 90) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".partial")
    temporary.write_bytes(payload)
    os.replace(temporary, path)


def binance_urls(manifest: dict, month: str) -> tuple[str, str]:
    template = manifest["sources"]["primary"]["archive_url_template"]
    year, mon = month.split("-")
    archive = template.replace("{YYYY}", year).replace("{MM}", mon)
    return archive, archive + manifest["sources"]["primary"]["checksum_suffix"]


def expected_checksum(text: str) -> str:
    token = text.strip().split()[0].upper()
    if len(token) != 64 or any(ch not in "0123456789ABCDEF" for ch in token):
        raise ValueError(f"Invalid checksum response: {text[:100]!r}")
    return token


def plan(manifest_path: Path) -> dict:
    manifest = load_manifest(manifest_path)
    items = []
    for month in coverage_months(manifest):
        archive, checksum = binance_urls(manifest, month)
        items.append({"month": month, "archive_url": archive, "checksum_url": checksum})
    result = {
        "manifest_id": manifest["manifest_id"],
        "manifest_sha256": sha256_file(manifest_path),
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "network_accessed": False,
        "binance_items": items,
        "coinbase_product": manifest["sources"]["secondary"]["instrument"],
        "coinbase_granularity_seconds": 900,
    }
    output = ROOT / "data" / "artifacts" / "independent" / "download_plan.json"
    atomic_write(output, json.dumps(result, indent=2).encode("utf-8"))
    return result


def download_binance(manifest_path: Path, max_total_gb: float) -> dict:
    manifest = load_manifest(manifest_path)
    raw_dir = ROOT / "data" / "raw" / "binance" / "ETHUSDT" / "aggTrades"
    records = []
    total = 0
    limit = int(max_total_gb * 1024**3)
    for index, month in enumerate(coverage_months(manifest), 1):
        archive_url, checksum_url = binance_urls(manifest, month)
        checksum_text = request_bytes(checksum_url).decode("utf-8")
        expected = expected_checksum(checksum_text)
        archive_path = raw_dir / f"ETHUSDT-aggTrades-{month}.zip"
        checksum_path = archive_path.with_suffix(".zip.CHECKSUM")
        if archive_path.exists():
            actual = sha256_file(archive_path)
            if actual != expected:
                raise RuntimeError(f"Existing immutable file hash mismatch: {archive_path}")
        else:
            payload = request_bytes(archive_url)
            total += len(payload)
            if total > limit:
                raise RuntimeError(f"Download budget {max_total_gb:.2f} GiB exceeded")
            actual = hashlib.sha256(payload).hexdigest().upper()
            if actual != expected:
                raise RuntimeError(f"Downloaded checksum mismatch for {month}")
            atomic_write(archive_path, payload)
        atomic_write(checksum_path, checksum_text.encode("utf-8"))
        records.append({
            "month": month,
            "path": str(archive_path.relative_to(ROOT)),
            "bytes": archive_path.stat().st_size,
            "sha256": actual,
            "official_expected_sha256": expected,
            "source_url": archive_url,
        })
        print(f"Binance {index}/60 verified: {month}")
    lock = write_source_lock(manifest_path, "binance_aggTrades", records)
    return lock


def iso_z(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def download_coinbase(manifest_path: Path, pause_seconds: float = 0.35) -> dict:
    manifest = load_manifest(manifest_path)
    product = manifest["sources"]["secondary"]["instrument"]
    endpoint = manifest["sources"]["secondary"]["endpoint"]
    output_dir = ROOT / "data" / "raw" / "coinbase" / product / "15m"
    records = []
    for index, month in enumerate(coverage_months(manifest), 1):
        start = datetime.strptime(month + "-01", "%Y-%m-%d").replace(tzinfo=timezone.utc)
        end = datetime.strptime(next_month(month) + "-01", "%Y-%m-%d").replace(tzinfo=timezone.utc)
        candles: dict[int, list] = {}
        cursor = start
        while cursor < end:
            # Coinbase permits at most 300 candles; use 299 intervals defensively.
            chunk_end = min(end, datetime.fromtimestamp(cursor.timestamp() + 299 * 900, timezone.utc))
            query = urllib.parse.urlencode({"start": iso_z(cursor), "end": iso_z(chunk_end), "granularity": 900})
            payload = json.loads(request_bytes(endpoint + "?" + query).decode("utf-8"))
            if not isinstance(payload, list):
                raise RuntimeError(f"Unexpected Coinbase response for {month}: {payload!r}")
            for row in payload:
                if len(row) >= 6:
                    candles[int(row[0])] = row[:6]
            cursor = chunk_end
            time.sleep(max(0.0, pause_seconds))
        path = output_dir / f"{product}-15m-{month}.csv"
        buffer = io.StringIO(newline="")
        writer = csv.writer(buffer)
        writer.writerow(["time_unix", "low", "high", "open", "close", "volume"])
        for timestamp in sorted(candles):
            writer.writerow(candles[timestamp])
        atomic_write(path, buffer.getvalue().encode("utf-8"))
        records.append({
            "month": month,
            "path": str(path.relative_to(ROOT)),
            "rows": len(candles),
            "sha256": sha256_file(path),
            "source_endpoint": endpoint,
        })
        print(f"Coinbase {index}/60 captured: {month}; rows={len(candles)}")
    return write_source_lock(manifest_path, "coinbase_15m", records)


def write_source_lock(manifest_path: Path, source: str, records: list[dict]) -> dict:
    output_dir = ROOT / "data" / "artifacts" / "independent"
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / f"{source}_source_lock.json"
    lock = {
        "source": source,
        "manifest_id": load_manifest(manifest_path)["manifest_id"],
        "manifest_sha256": sha256_file(manifest_path),
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "records": records,
    }
    atomic_write(path, json.dumps(lock, indent=2).encode("utf-8"))
    return lock


@dataclass(frozen=True)
class SyntheticCost:
    tick: Decimal
    spread_floor: Decimal
    spread_bps: Decimal

    def quote(self, trade_price: Decimal) -> tuple[Decimal, Decimal]:
        spread = max(self.spread_floor, trade_price * self.spread_bps / Decimal(10000))
        half = spread / Decimal(2)
        bid = ((trade_price - half) / self.tick).to_integral_value(rounding=ROUND_FLOOR) * self.tick
        ask = ((trade_price + half) / self.tick).to_integral_value(rounding=ROUND_CEILING) * self.tick
        if bid <= 0 or ask <= bid:
            raise ValueError(f"Invalid synthetic quote at trade price {trade_price}")
        return bid, ask


def normalize_timestamp_msc(raw: str) -> int:
    value = int(raw)
    if value >= 10**15:  # Binance spot archives use microseconds from 2025 onward.
        value //= 1000
    if value < 10**12 or value >= 10**14:
        raise ValueError(f"Unexpected timestamp magnitude: {raw}")
    return value


def aggtrade_rows(archive_path: Path) -> Iterator[tuple[int, Decimal, Decimal]]:
    with zipfile.ZipFile(archive_path) as archive:
        members = [name for name in archive.namelist() if name.lower().endswith(".csv")]
        if len(members) != 1:
            raise ValueError(f"Expected one CSV in {archive_path}; found {members}")
        with archive.open(members[0]) as raw:
            text = io.TextIOWrapper(raw, encoding="utf-8", newline="")
            reader = csv.reader(text)
            for row in reader:
                if not row or not row[0].lstrip("-").isdigit():
                    continue
                if len(row) < 6:
                    raise ValueError(f"Malformed aggTrade row in {archive_path}: {row!r}")
                price = Decimal(row[1])
                quantity = Decimal(row[2])
                if price <= 0 or quantity <= 0:
                    raise ValueError(f"Nonpositive aggTrade in {archive_path}: {row!r}")
                yield normalize_timestamp_msc(row[5]), price, quantity


def normalize_binance(manifest_path: Path) -> dict:
    manifest = load_manifest(manifest_path)
    model = manifest["synthetic_execution_model"]
    cost = SyntheticCost(Decimal(str(model["price_tick_usd"])),
                         Decimal(str(model["spread_floor_usd"])),
                         Decimal(str(model["spread_bps"])))
    raw_dir = ROOT / "data" / "raw" / "binance" / "ETHUSDT" / "aggTrades"
    output_dir = ROOT / "data" / "processed" / "mt5" / manifest["manifest_id"]
    output_dir.mkdir(parents=True, exist_ok=True)
    records = []
    prior_timestamp = -1
    for index, month in enumerate(coverage_months(manifest), 1):
        archive_path = raw_dir / f"ETHUSDT-aggTrades-{month}.zip"
        if not archive_path.exists():
            raise FileNotFoundError(f"Run download-binance first: {archive_path}")
        output = output_dir / f"KINGEA_ETHUSD_I1-{month}.csv"
        temporary = output.with_suffix(".csv.partial")
        rows = 0
        first_timestamp = None
        last_timestamp = None
        with temporary.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["time_msc", "bid", "ask", "last", "volume_real"])
            for timestamp, price, quantity in aggtrade_rows(archive_path):
                if timestamp < prior_timestamp:
                    raise ValueError(f"Out-of-order timestamp at {month}: {timestamp} < {prior_timestamp}")
                prior_timestamp = timestamp
                first_timestamp = timestamp if first_timestamp is None else first_timestamp
                last_timestamp = timestamp
                bid, ask = cost.quote(price)
                writer.writerow([timestamp, f"{bid:.2f}", f"{ask:.2f}", f"{price:.8f}", f"{quantity:.8f}"])
                rows += 1
        os.replace(temporary, output)
        records.append({
            "filename": output.name,
            "month": month,
            "first_time_msc": first_timestamp,
            "last_time_msc": last_timestamp,
            "rows": rows,
            "sha256": sha256_file(output),
        })
        print(f"Normalized {index}/60: {month}; rows={rows}")
    csv_manifest = output_dir / "mt5_import_manifest.csv"
    with csv_manifest.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["filename", "month", "first_time_msc", "last_time_msc", "rows", "sha256"])
        writer.writeheader()
        writer.writerows(records)
    return write_source_lock(manifest_path, "mt5_synthetic_ticks", records)


def verify(manifest_path: Path) -> dict:
    manifest = load_manifest(manifest_path)
    result = {"manifest_sha256": sha256_file(manifest_path), "checks": []}
    for month in coverage_months(manifest):
        path = ROOT / "data" / "raw" / "binance" / "ETHUSDT" / "aggTrades" / f"ETHUSDT-aggTrades-{month}.zip"
        result["checks"].append({"month": month, "exists": path.exists(), "sha256": sha256_file(path) if path.exists() else None})
    result["all_present"] = all(item["exists"] for item in result["checks"])
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("plan", help="Create a no-network 60-month download plan")
    download = sub.add_parser("download-binance", help="Download and checksum official monthly aggTrades")
    download.add_argument("--max-total-gb", type=float, default=25.0)
    coinbase = sub.add_parser("download-coinbase", help="Capture official ETH-USD 15-minute cross-check candles")
    coinbase.add_argument("--pause-seconds", type=float, default=0.35)
    sub.add_parser("normalize-binance", help="Create monthly synthetic MT5 Bid/Ask tick CSVs")
    sub.add_parser("verify", help="Report local raw archive presence and hashes")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "plan":
        result = plan(args.manifest)
    elif args.command == "download-binance":
        result = download_binance(args.manifest, args.max_total_gb)
    elif args.command == "download-coinbase":
        result = download_coinbase(args.manifest, args.pause_seconds)
    elif args.command == "normalize-binance":
        result = normalize_binance(args.manifest)
    else:
        result = verify(args.manifest)
    print(json.dumps(result if args.command in {"verify", "plan"} else {"status": "complete"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
