# Independent ETH Data-Source Evaluation — 2026-07-21

## Superseding decision

**External exchange data is rejected for KingEA signal generation, strategy backtesting, optimization, OOS, holdout, or acceptance.** Binance, Coinbase, Kraken, and JustMarkets are different venues with different tick sequences, prices, candle highs/lows, timestamps, spreads, and liquidity. A breakout or trend signal can move or disappear when applied to another venue, and a synthetic spread cannot repair that mismatch.

The prepared manifest/importer is retained only as an abandoned, auditable design record. No raw exchange files were downloaded. External data may be used later only for gross non-performance anomaly checks, never to rescue or validate a JustMarkets strategy.

The broker-native evidence hierarchy is now:

1. JustMarkets-Demo2 unchanged five-year real-tick-mode history for long-horizon research and adverse simulated stress, explicitly labelled simulated.
2. JustMarkets-Live2 available real ticks as authoritative recent execution and untouched-holdout evidence.
3. If those layers are insufficient, reject/wait/change the separately registered deployment venue; do not substitute another exchange's ticks.

## Original evaluated proposal — rejected

The following layered proposal was evaluated and rejected for strategy use:

1. **Primary independent intrabar path:** Binance Spot `ETHUSDT` monthly aggregate trades.
2. **Secondary true-USD reconciliation:** Coinbase Exchange `ETH-USD` 15-minute candles.
3. **Optional tertiary dispute resolution:** Kraken `ETH/USD` OHLCVT or time-and-sales bulk archives.
4. **Authoritative recent broker evidence:** JustMarkets-Live2 `ETHUSD.s` real ticks from December 2024 onward.
5. **Adverse broker simulation:** unchanged JustMarkets-Demo2 five-year tick history.

This selection is for data construction only. It does not authorize performance testing.

## Evaluation criteria

- At least five completed years ending 2026-06-30.
- Primary/exchange-controlled provenance rather than a scraped or repackaged vendor dataset.
- Deterministic retrieval and integrity hashes.
- Sufficient intrabar detail to avoid using M30 OHLC alone for stops.
- A true-USD cross-check to quantify ETHUSDT basis risk.
- Reproducible import into an isolated MT5 custom symbol.

## Binance Spot — selected primary

Official archive/documentation: https://github.com/binance/binance-public-data

Strengths:

- Official monthly aggregate-trade archives.
- Per-file `.CHECKSUM` files support deterministic SHA-256 verification.
- Trade timestamps, prices, and quantities provide an intrabar path.
- Monthly paths are predictable and independently lockable.

Limitations:

- `ETHUSDT` is not `ETHUSD`; USD-USDT basis must be measured against a true-USD venue.
- Aggregate trades are last-sale data, not CFD Bid/Ask quotes.
- Synthetic Bid/Ask construction and execution stress must remain separate, explicit, and pre-registered.

## Coinbase Exchange — selected secondary

Official candles: https://docs.cdp.coinbase.com/api-reference/exchange-api/rest-api/products/get-product-candles

Strengths:

- True `ETH-USD` market.
- Public official REST endpoint.
- Fifteen-minute candles are sufficient to cross-check M30 market direction, gaps, and venue basis without inspecting a strategy.

Limitations:

- Coinbase states historical candles may be incomplete.
- Requests are capped at 300 candles.
- Candles are not trade-level execution evidence.

## Kraken — retained as tertiary

Official OHLCVT archive: https://support.kraken.com/articles/360047124832-downloadable-historical-ohlcvt-open-high-low-close-volume-trades-data

Official time-and-sales description: https://support.kraken.com/articles/360047543791-downloadable-historical-market-data-time-and-sales-

Strengths:

- True `ETH/USD`.
- Long official OHLCVT and trade-history coverage.

Limitations:

- Complete files bundle many currency pairs and are distributed through Google Drive.
- Incremental releases are quarterly.
- Automated per-pair checksum locking is less direct than Binance's monthly archive.

## Fixed data boundaries and partitions

- Full dataset: 2021-07-01 00:00 UTC inclusive through 2026-07-01 00:00 UTC exclusive.
- Development/walk-forward zone: 2021-07-01 through 2023-12-31.
- Four rolling folds: 18-month training plus the following 3-month test; step size 3 months.
- Formal OOS: calendar year 2024.
- Untouched final holdout: 2025-01-01 through 2026-06-30.

The holdout aligns with the period for which recent JustMarkets-Live2 tick evidence is available. No strategy-dependent holdout statistic may be read before the registered one-time holdout run.

## Prepared artifacts

- Draft manifest: `data/manifest/KINGEA_ETH_INDEPENDENT_V1.json`
- Downloader/normalizer: `data_pipeline/independent_data.py`
- MT5 importer: `MQL5/Scripts/KingEA/ImportIndependentTicks.mq5`
- Instructions: `data_pipeline/README.md`
- Deterministic tests: `tests/test_independent_data.py`

## Verification completed

- Offline plan produces exactly 60 monthly Binance archive/checksum URL pairs.
- Python compile check passes.
- Four deterministic normalization tests pass.
- MT5 importer compiles with 0 errors and 0 warnings.
- Static scan finds no trading, strategy, indicator, return, ranking, or optimizer API usage.

## Remaining obstacles before freeze

1. Network access was not authorized during preparation, so no exchange archive has yet been downloaded or claimed as verified.
2. Aggregate-trade storage size is not yet measured. The downloader enforces a configurable hard download budget and refuses checksum mismatches.
3. The synthetic cost defaults are explicitly `DRAFT_PENDING_LIVE_RELATIVE_SPREAD_AUDIT`; they cannot be used for candidate acceptance yet.
4. Coinbase coverage and Binance-Coinbase basis statistics remain to be generated after download.
5. The custom symbol must be imported and its tick boundaries/count reconciled before the manifest can be frozen.
