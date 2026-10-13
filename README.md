# KingEA

An MT5 Expert Advisor research project: a Supertrend/breakout trend-following
sleeve on JustMarkets `ETHUSD.s` (M30), wrapped in a strict risk kernel.
The goal is to find out, honestly, whether the strategy has an edge after
costs out of sample. If it doesn't, the answer is "no strategy found".

- Trading rules, risk limits and validation gates: [EA_DESIGN_PLAN.md](EA_DESIGN_PLAN.md)
- Where things stand and what to do next: [docs/STATUS.md](docs/STATUS.md)

## Layout

| Path | What it is |
|---|---|
| `MQL5/Experts/KingEA/KingEA.mq5` | The EA. Plumbing only: bars, spreads, calendar gates, orders, results. |
| `MQL5/Include/KingEA/` | Pure modules: strategy (`CandidateEthSt001`, `SleeveEthSt001`), `RegimeClassifier`, `SafetyKernel`, plus live-ops modules (spec monitor, operational safety, clustering). |
| `MQL5/Scripts/KingEA/Test*.mq5` | Unit tests for the pure modules (run as scripts in MT5). |
| `MQL5/Scripts/KingEA/` (others) | Data tools: history audit, symbol feasibility, calendar export, reduced-spread symbol builder. |
| `data/protection_intervals.csv` | News blackout and daily-maintenance windows, 2021-04-01 to 2025-01-01. |
| `tools/` | `Build.ps1` (copy to MT5 + compile), `Backtest.ps1` (scripted Strategy Tester run). |
| `docs/` | Protocols, module contracts, audits, kill-switch runbook. |

## Quick start

Close the MT5 terminal first. The scripts launch it themselves.

```powershell
.\tools\Build.ps1
.\tools\Backtest.ps1 -From 2022.01.01 -To 2022.03.01 -Label smoke
```

The backtest prints the EA's result and a **funnel** that shows why bars did
or did not become trades: regime reasons, sleeve reasons, safety rejections,
data gaps and order failures. A run with zero trades prints a warning. Read
the funnel before trusting any number.

Each run writes `summary.csv` (one row per run) and `trades_<config>.csv` to
`%APPDATA%\MetaQuotes\Terminal\Common\Files\KingEA\results\<label>\`. The
MT5 HTML/XML report goes to `<MT5 data folder>\reports\`.

Useful options:

```powershell
# Evaluation window inside a longer test: no entries before EvalStart,
# flatten and stop at EvalEnd.
.\tools\Backtest.ps1 -From 2021.07.01 -To 2023.01.01 -EvalEnd '2022.12.31 00:00:00' -Label fold1

# A specific grid point (0..19439), or explicit inputs
.\tools\Backtest.ps1 -From 2021.07.01 -To 2023.01.01 -Label cfg7168 -Inputs @{ InpConfigurationId = 7168 }

# Optimization over the registered grid (custom criterion = composite)
.\tools\Backtest.ps1 -From 2021.07.01 -To 2023.01.01 -Optimize -Label fold1_opt `
    -Inputs @{ InpSupertrendMultiplier = '3.0||2.0||0.5||4.0||Y' }
```

## Data partitions

These dates are fixed. Respecting them is the main thing that protects you
from fooling yourself.

| Use | Window |
|---|---|
| Development folds (optimize and inspect freely) | 2021-07-01 → 2024-01-01, rolling 18-month train / 3-month forward |
| Formal out-of-sample (run **once**, after the candidate is frozen) | 2024-01-01 → 2025-01-01 |
| Holdout (run **once**, after OOS passes) | 2025-01-01 → 2026-07-01 |

Fold boundaries: train `2021-07/2021-10/2022-01/2022-04` + 18 months, each
followed by a 3-month forward quarter in 2023. Final selection uses
2022-07-01 → 2024-01-01.

## Working rules

Keep these few rules. The rest of the old governance process is archived.

1. **Never look at OOS or holdout results while choosing parameters.** Freeze
   the configuration (write it in `docs/DECISIONS.md` and commit) before the
   first OOS run.
2. **Keep the risk rules** in the design plan: broker-side stop on every
   position, size from the stop, circuit breakers, no martingale, grid or
   averaging down.
3. **Iterate freely on development data.** Recompiling, rerunning and
   debugging need no authorization.
4. **Commit small and often.** Record decisions in a sentence or two, not in
   evidence bundles.
5. **Time-box research questions.** If a question about MT5 internals doesn't
   change a trading decision, write down the practical choice and move on.

## History

The original governed pipeline (Gate 1, conformance harnesses, review
bundles) is preserved on branch `archive/governed-v1` (tag
`governed-v1-final`). The 2 GB of review bundles were moved out of the repo to
`C:\KingEA_archive\`.
