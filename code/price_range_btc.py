"""price_range_btc.py -- Étape 5 (Option 2 BTC) : convertit les quantiles de rendement du MS-GARCH(K=2)
(ms_garch_forecast_btc.R) en fourchette de PRIX BTC-USD pour le jour suivant.

Calque de price_range.py (EUR/USD) : la conversion est identique, P = P_dernier * exp(r/100),
car les rendements du projet BTC sont aussi en % (x100).
Différences déclarées : chemins du projet BTC ; régimes nommés « volatil » et « calme » (étiquettes
définies par l'écart-type réalisé, cf. btc2_03_msgarch.md) ; « jour suivant » = jour calendaire suivant
(marché 7j/7, clôture à minuit UTC), pas « jour de bourse suivant » ; diagnostic de couverture à 99 %.

Emplacement : OPTION 2/code/price_range_btc.py
Entrées     : data/processus/btc_msgarch_price_range_inputs.csv, btc_msgarch_regime_conditional_forecast.csv
Sortie      : data/processus/btc_price_range_output.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
PROC = ROOT / "data" / "processus"


def compute_price_range(last_price, return_q_low, return_q_high):
    """Intervalle de log-rendement (en %, déjà x100) -> fourchette de prix : P = P_dernier * exp(r/100)."""
    return last_price * np.exp(return_q_low / 100), last_price * np.exp(return_q_high / 100)


if __name__ == "__main__":
    inp = pd.read_csv(PROC / "btc_msgarch_price_range_inputs.csv").iloc[0]
    last_price, last_date = float(inp["last_price"]), inp["last_date"]
    next_date = (pd.Timestamp(last_date) + pd.Timedelta(days=1)).date()
    cl = float(inp["confidence_level"])

    p_min, p_max = compute_price_range(last_price, inp["return_q_low"], inp["return_q_high"])
    print(f"Au {last_date} (clôture 00:00 UTC), BTC-USD = {last_price:,.2f} $")
    print(f"Probabilités de régime pour le {next_date} : volatil = {inp['prob_volatil_next']:.1%}, "
          f"calme = {inp['prob_calme_next']:.1%}")
    print(f"Volatilité prévue (mélange pondéré) : {inp['vol_forecast']:.4f} %/jour")
    print(f"\nFourchette à {cl:.0%} pour le {next_date} :")
    print(f"  [{p_min:,.0f} $ ; {p_max:,.0f} $]")
    print(f"  Largeur : {p_max - p_min:,.0f} $ ({(p_max - p_min) / last_price:.2%} du prix)")
    p99_min, p99_max = compute_price_range(last_price, inp["return_q_low_99"], inp["return_q_high_99"])
    print(f"Diagnostic à 99 % (non décisif) : [{p99_min:,.0f} $ ; {p99_max:,.0f} $] "
          f"(largeur {(p99_max - p99_min) / last_price:.2%})")

    rc = pd.read_csv(PROC / "btc_msgarch_regime_conditional_forecast.csv")
    rc = rc[np.isclose(rc["confidence_level"], cl)]
    print("\n--- Fourchette par régime (chaque régime pris comme certain ; pas la prévision opérationnelle) ---")
    rows = {}
    for _, row in rc.iterrows():
        lo, hi = compute_price_range(last_price, row["return_q_low"], row["return_q_high"])
        rows[row["regime"]] = (hi - lo) / last_price
        print(f"  Régime {row['regime']:<8}: [{lo:,.0f} $ ; {hi:,.0f} $] (largeur {(hi - lo) / last_price:.2%}, "
              f"sigma = {row['sigma_next']:.3f} %/jour, nu = {row['nu']:.2f})")
    if {"volatil", "calme"} <= rows.keys():
        print(f"  Rapport de largeurs volatil/calme : {rows['volatil'] / rows['calme']:.2f}")

    pd.DataFrame([{"date": last_date, "forecast_date": next_date, "last_price": last_price,
                   "confidence_level": cl, "p_min": p_min, "p_max": p_max,
                   "range_width_pct": (p_max - p_min) / last_price,
                   "p_min_99": p99_min, "p_max_99": p99_max}]
                 ).to_csv(PROC / "btc_price_range_output.csv", index=False)
    print("\nFichier écrit : btc_price_range_output.csv")
