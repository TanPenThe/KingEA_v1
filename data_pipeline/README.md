# Independent ETH Data Pipeline

This pipeline is retained as a pre-freeze reference-only design artifact. The owner rejected external-venue ticks as a KingEA strategy dataset because venue-specific prices and tick sequences can change JustMarkets signals and fills. It must not calculate signals, strategy returns, expectancy, win rate, parameter scores, OOS results, or holdout results; its synthetic MT5 import path is not authorized for use.

**Do not run the download; normalization; or MT5 import commands for KingEA candidate research.** External data may be reconsidered only for a separately authorized gross price-history anomaly check that never evaluates the strategy.

## Source roles

- Primary intrabar path: official Binance Spot `ETHUSDT` monthly aggregate trades with published SHA-256 checksums.
- Secondary true-USD check: official Coinbase Exchange `ETH-USD` 15-minute candles.
- Optional dispute resolution: official Kraken `ETH/USD` OHLCVT/time-and-sales archives.
- Broker evidence: JustMarkets-Live2 real ticks from December 2024 onward.
- Adverse sensitivity: unmodified JustMarkets-Demo2 five-year real-tick simulation.

The Binance source is USDT-denominated and is not a broker Bid/Ask feed. The normalizer constructs synthetic Bid/Ask ticks using the draft cost formula in the manifest. That model must be replaced or approved after the live relative-spread audit and frozen before any candidate test.

## Retired commands — not authorized

All paths are relative to the repository and every generated raw/processed artifact is hashed.

```powershell
python data_pipeline\independent_data.py plan
python data_pipeline\independent_data.py download-binance --max-total-gb 25
python data_pipeline\independent_data.py download-coinbase
python data_pipeline\independent_data.py normalize-binance
python data_pipeline\independent_data.py verify
```

`plan` performs no network access. Downloads are immutable: an existing archive whose checksum disagrees with the official checksum causes a hard failure rather than being overwritten.

The Binance download may be large. `--max-total-gb` is a hard budget for data downloaded during one invocation. Existing verified files do not consume the invocation budget.

## MT5 import — rejected for KingEA strategy use

After normalization:

1. Copy the directory `data\processed\mt5\KINGEA-ETH-INDEPENDENT-V1\` to `Terminal\Common\Files\KingEA\independent\KINGEA-ETH-INDEPENDENT-V1\`.
2. Compile and run `ImportIndependentTicks.mq5` once.
3. Keep the versioned custom symbol name `KINGEA_ETHUSD_I1`.
4. The importer refuses a non-empty existing symbol to prevent silent overwrites.
5. Reconcile the imported first/last timestamp and tick count before freezing the manifest.

Custom-symbol testing never replaces the native JustMarkets real-tick runs. It is an independent market-path and cost-model layer.
