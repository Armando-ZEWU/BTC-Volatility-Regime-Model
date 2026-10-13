# Predicting a Bitcoin Price Range: An Out-of-Sample Test

Code, data and outputs for the working paper *Predicting a Bitcoin Price Range: An Out-of-Sample Test* (Armand Zewu Y. I., Université de Lomé, 2026).

The paper applies, out of sample, the Markov-switching GARCH price-range pipeline built on EUR/USD to BTC-USD, and asks whether a one-day price range can be built and calibrated, and what an analyst of the market can use it for. It does not propose a new method and makes no claim of discovery.

- **Paper:** SSRN link to be added once posted.
- **Companion paper (EUR/USD):** Zewu, A. Y. I. (2026), *Quantitative Modeling of EUR/USD Exchange Rate Volatility*, SSRN Working Paper No. 7532760.

## Main results

| Question | Result |
|---|---|
| Is the one-day 95 % range calibrated out of sample? | Yes: coverage 95.11 % over 3,193 forecasts (2018–2026); Kupiec p = 0.766; Christoffersen p = 0.610. Qualitative shock test, March 2020: 95.87 % over 121 days. |
| Regimes or a single era? | Persistent regimes (expected durations of about 73 and 36 days); 51 switches; longest volatile block 15.4 % of the sample (rule frozen before estimation). Labels are relative to each re-estimation; 42.6 % of days are ambiguous. |
| Do EUR/USD properties carry over? | Partly: persistence at the IGARCH boundary and a passing coverage, but much heavier tails (ν between 2.3 and 4) and a volatile regime that is the majority state. |
| Does the regime layer improve the range over simpler models? | By a small margin (interval score 1.6–4.2 % better at 95 %); only the gap with EWMA + FHS survives a multiple-comparison correction, and that model passes the same success criterion. |

What the study does **not** show: the size of extreme losses (the log return of −46.5 % on 2020-03-12 is 6.6 times its lower bound), the tails beyond 99 %, any usable forecast of direction, or any cause of the changes in risk. See the paper for the full list of limits.

## Repository structure

```
code/      scripts (Python and R)
data/
  raw/       raw download (yfinance, BTC-USD, daily)
  processus/ cleaned series and all output tables (CSV)
docs/      working notes, one per step (in French), and the project summary
graphs/    figures (labels in French)
```

## Scripts, in execution order

| Step | Script | Main outputs (`data/processus/`) | Note in `docs/` |
|---|---|---|---|
| 1. Data and quality control | `data_loading.py` | `btc_close_clean.csv`, `btc_log_returns.csv` | `btc2_01_data.md` |
| 2. GARCH(1,1), Normal vs Student's t | `garch_btc.py` | `btc_garch_step2_table.csv`, `btc_garch_shocks.csv` | `btc2_02_garch.md` |
| 3. Markov-switching GARCH (K = 2) | `ms_garch_btc.R` | `btc_msgarch_*.csv` | `btc2_03_msgarch.md` |
| 4. Regime or era: split-sample test | `chow_garch_btc.py` | `btc_chow_garch_table.csv`, `btc_chow_garch_lr.csv` | `btc2_04_regime_vs_era.md` |
| 5. One-day price range | `ms_garch_forecast_btc.R`, then `price_range_btc.py` | `btc_price_range_output.csv`, `btc_msgarch_price_range_inputs.csv`, `btc_msgarch_mixture_check.csv` | `btc2_05_price_range.md` |
| 6. Shock test, Jan–Apr 2020 | `covid_shock_test_btc.R` | `btc_covid_*.csv` | `btc2_06_shock_test.md` |
| 7. Expanding-window backtest | `full_backtest_btc.R` | `btc_backtest_daily.csv`, `btc_backtest_summary.csv`, `btc_backtest_fold_summary.csv`, `btc_backtest_params.csv` | `btc2_07_backtest.md` |
| 8. Benchmarks and direction | `verification_btc.R` | `btc_verif_*.csv` | `btc2_08_verification.md` |

`msgarch_utils_btc.R` holds the functions shared by steps 6 and 7 (fit with several starting points, one-day forecast with an exact-mixture fallback, Kupiec and Christoffersen tests).

Figures:

| Script | Figures |
|---|---|
| `graphs_ms_garch_btc.R` | 01–09 (MS-GARCH) |
| `graphs_price_range_btc.R` | 10 (fan chart) |
| `graphs_backtest_btc.R` | 11–17 (shock test and backtest) |
| `Sigma_by_regime_by_fold.R` | 18 and `btc_sigma_by_regime_by_fold.csv` |
| `graphs_distribution_btc.R` | D1–D7 (distribution and tails) |

Other documents in `docs/`: `summary_btc_option2.md` (framing, success criteria fixed before estimation, decisions and their status) and `Economics.md` (economic interpretation).

## How to reproduce

Run each script from `code/` or from the project root; the scripts find the project root themselves.

1. **Use the frozen data.** `data/raw/btc_usd_yfinance_raw.csv` was downloaded on 2026-09-30 at 01:39 UTC. `data_loading.py` downloads a *new* series from yfinance, so running it again will extend the sample and may revise past values: the numbers of the paper are reproduced from the frozen files in `data/`, not from a fresh download.
2. Run the steps in the order of the table above. Step 3 estimates 21 fits (several minutes) and step 7 takes about 12 minutes; step 7 saves each fold and can be resumed (`RESUME <- TRUE`).
3. Seeds are set in the scripts (for example `set.seed(20260930)` in step 3), so the restarts are repeatable on the same software versions.

**Why the versions matter.** The optimum of the Markov-switching likelihood depends on the starting point and on the optimiser, and the numerical grid of `MSGARCH::Risk()` can saturate after extreme shocks. Both can change with the package version. The versions used are:

| Software | Version |
|---|---|
| R | *fill in* (`R.version.string`) |
| MSGARCH | *fill in* (`packageVersion("MSGARCH")`) |
| Python | *fill in* |
| arch | *fill in* (`arch.__version__`) |

Python dependencies: `numpy`, `pandas`, `scipy`, `statsmodels`, `arch`, `matplotlib`, `yfinance`. R dependencies: `MSGARCH`, `ggplot2`, `readr`, `dplyr`, `tidyr`, `scales`, `stringr`, `lubridate`, `MASS`, and optionally `patchwork`.

## Status of each analysis

The paper states which analyses were fixed before estimation (success criterion, the "regime or era" rule, the split-sample cut, the backtest design) and which are exploratory or were added after the fact (the Ljung–Box test on |z|, the comparison with simpler models, the reading of sub-periods). The table is in the Introduction of the paper (Table "Status of each analysis"). The scripts for exploratory analyses say so in their headers.

## Data

Prices come from Yahoo Finance through the `yfinance` package (ticker `BTC-USD`, daily, close at midnight UTC). They were not cross-checked against a second provider. Check Yahoo's terms of use before redistributing the raw file.

## AI assistance

An AI assistant (Claude, Anthropic) was used for translation, for the initial drafting of the code, and as a critical reviewer. The paper contains the full AI Disclosure Statement. The author takes full responsibility for the content.

## Citation

> Zewu, A. Y. I. (2026). *Predicting a Bitcoin Price Range: An Out-of-Sample Test*. Working paper. SSRN link to be added.

## License

*To be chosen* (a repository without a license is, by default, all rights reserved).
