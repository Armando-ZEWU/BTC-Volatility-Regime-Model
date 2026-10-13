# -*- coding: utf-8 -*-
"""
Created on Tue Sep 29 16:58:25 2026

@author: user
"""


from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent   # dossier OPTION 2
RAW  = ROOT / "data" / "raw"
PROC = ROOT / "data" / "processus"              # ou "processus" si tu gardes ce nom
RAW.mkdir(parents=True, exist_ok=True)
PROC.mkdir(parents=True, exist_ok=True)
import yfinance as yf, pandas as pd, numpy as np
from statsmodels.tsa.stattools import adfuller
from statsmodels.stats.diagnostic import acorr_ljungbox

df = yf.download("BTC-USD", start="2014-01-01", interval="1d",
                 auto_adjust=False, progress=False)
if isinstance(df.columns, pd.MultiIndex):
    df.columns = df.columns.get_level_values(0)

px = df["Close"].dropna()
px.index = pd.to_datetime(px.index).tz_localize(None)
# on retire la bougie du jour (incomplète, minuit UTC pas encore passé)
today = pd.Timestamp.now(tz="UTC").tz_localize(None).normalize()
px = px[px.index < today]

r = np.log(px).diff().dropna() 

print("Période:", px.index.min().date(), "->", px.index.max().date(), "| N =", len(px))
print("Jours manquants:", len(pd.date_range(px.index.min(), px.index.max()).difference(px.index)))
print("Prix <= 0:", int((px <= 0).sum()), "| Rendements nuls:", int((r == 0).sum()))
print("Top 5 |r|:\n", r.abs().sort_values(ascending=False).head(5))
print("Kurtosis excès:", round(r.kurt(), 2), "| Skew:", round(r.skew(), 2))
print("ADF log-prix p =", round(adfuller(np.log(px))[1], 3),
      "| ADF rendements p =", round(adfuller(r)[1], 4))
print(acorr_ljungbox(r**2, lags=[10, 20]))
print("Écart-type par année:\n", r.groupby(r.index.year).std().round(4))

px.to_csv(PROC / "btc_close_clean.csv", header=["close"])
r.to_csv(PROC / "btc_log_returns.csv", header=["log_return"])
df.to_csv(RAW / "btc_usd_yfinance_raw.csv")
(RAW / "btc_usd_yfinance_raw.meta.txt").write_text(
    f"source=yfinance BTC-USD 1d | téléchargé le {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC\n")