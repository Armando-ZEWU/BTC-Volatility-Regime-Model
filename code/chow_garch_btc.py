"""Étape 4 — Comparaison avant/après la coupure du 2020-09-22 (Summary 4.3 et 4.7).

GARCH(1,1) à innovations Student's t, moyenne constante (comme l'étape 2), estimé sur
l'échantillon complet puis séparément avant/après la coupure.
Test du rapport de vraisemblance de type Chow sur les 5 paramètres (mu, omega, alpha, beta, nu) :
    LR = 2 * (LL_avant + LL_après - LL_complet)  ~  chi2(5) sous H0 (paramètres constants).
Statut : CORROBORANT, NON DÉCISIF (Summary 4.3). Le test peut sur-rejeter quand la persistance est
proche de 1 et nu bas (frontière alpha+beta = 1, moments d'ordre 4 infinis).

Prédiction à falsifier (Summary 4.7, seuils fixés AVANT exécution) :
    persistance < 0.99 dans les DEUX moitiés  ET  nu > 3.18 dans les DEUX moitiés.

Emplacement : OPTION 2/code/chow_garch_btc.py
Entrée      : data/processus/btc_log_returns.csv
Sorties     : data/processus/btc_chow_garch_table.csv, data/processus/btc_chow_garch_lr.csv
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats
from arch import arch_model

ROOT = Path(__file__).resolve().parent.parent          # dossier OPTION 2
PROC = ROOT / "data" / "processus"
if not PROC.exists():
    PROC = ROOT / "data" / "processed"
pd.set_option("display.float_format", "{:.6g}".format)

CUT = pd.Timestamp("2020-09-22")    # médiane par nombre d'observations (O1, validée)
PERS_MAX = 0.99                     # seuils de la prédiction (4.7), fixés avant exécution
NU_MIN = 3.18                       # nu estimé sur l'échantillon complet à l'étape 2
DF = 5                              # mu, omega, alpha, beta, nu

r = pd.read_csv(PROC / "btc_log_returns.csv", index_col=0, parse_dates=True)["log_return"] * 100
r1, r2 = r[r.index < CUT], r[r.index >= CUT]
print(f"Avant : {r1.index.min().date()} -> {r1.index.max().date()} (n = {len(r1)})")
print(f"Après : {r2.index.min().date()} -> {r2.index.max().date()} (n = {len(r2)})")
if (len(r1), len(r2)) != (2196, 2198):
    print("ATTENTION : effectifs différents de 2196 + 2198 rendements (coupure = médiane des 4 395 prix, Summary 4.3).")


def fit(x):
    return arch_model(x, mean="Constant", vol="GARCH", p=1, q=1, dist="t").fit(disp="off")


res = {"complet": fit(r), "avant": fit(r1), "apres": fit(r2)}

rows = {}
for k, m in res.items():
    p, se = m.params, m.std_err
    pers = p["alpha[1]"] + p["beta[1]"]
    rows[k] = {
        "n": m.nobs, "converged": float(m.convergence_flag == 0), "LL": m.loglikelihood,
        "mu": p["mu"], "omega": p["omega"], "alpha": p["alpha[1]"], "beta": p["beta[1]"],
        "nu": p["nu"], "nu_se": se["nu"], "persistence": pers,
        # demi-vie et sigma de long terme : non définis près de la frontière IGARCH
        "half_life_days": np.log(0.5) / np.log(pers) if pers < 0.999 else np.nan,
        "sigma_long_term_pct": np.sqrt(p["omega"] / (1 - pers)) if pers < 0.999 else np.nan,
    }
tab = pd.DataFrame(rows)
print("\n===== PARAMÈTRES (NaN = non défini : persistance >= 0.999) =====")
print(tab.to_string())

# ---- Test LR de type Chow ----------------------------------------------------------------
lr = 2 * (res["avant"].loglikelihood + res["apres"].loglikelihood - res["complet"].loglikelihood)
pval = stats.chi2.sf(lr, DF)
print("\n===== TEST LR DE TYPE CHOW (corroborant, non décisif) =====")
print(f"LR = {lr:.2f} | chi2({DF}) | p = {pval:.4g} | rejet à 5 % : {pval < 0.05}")
print("Réserve : frontière alpha+beta = 1 et moment d'ordre 4 infini -> le test peut sur-rejeter.")

# ---- Prédiction à falsifier (4.7) ---------------------------------------------------------------
ok = {}
for k in ("avant", "apres"):
    ok[k] = (tab.loc["persistence", k] < PERS_MAX, tab.loc["nu", k] > NU_MIN)
print("\n===== PRÉDICTION (4.7) : persistance < %.2f ET nu > %.2f dans les DEUX moitiés =====" % (PERS_MAX, NU_MIN))
for k in ("avant", "apres"):
    print(f"{k:>6} : persistance = {tab.loc['persistence', k]:.5f} ({'OK' if ok[k][0] else 'NON'}) | "
          f"nu = {tab.loc['nu', k]:.3f} ({'OK' if ok[k][1] else 'NON'})")
supported = all(all(v) for v in ok.values())
print("Verdict :", "SOUTENUE" if supported else "NON SOUTENUE")

# ---- Drapeaux (Summary 4.2) ------------------------------------------------------------------------
for k in ("avant", "apres"):
    fl = []
    if tab.loc["converged", k] < 1:
        fl.append("NON-CONVERGENCE")
    if tab.loc["persistence", k] > 0.999:
        fl.append("persistance > 0.999")
    if tab.loc["nu_se", k] > tab.loc["nu", k]:
        fl.append("SE(nu) > nu")
    if tab.loc["nu", k] <= 4:
        fl.append("nu <= 4")
    print(f"Drapeaux {k} :", fl if fl else "aucun")

tab.to_csv(PROC / "btc_chow_garch_table.csv")
pd.DataFrame([{"cut": CUT.date(), "LR": lr, "df": DF, "p_value": pval, "reject_5pct": pval < 0.05,
               "pers_max": PERS_MAX, "nu_min": NU_MIN, "prediction_supported": supported}]
             ).to_csv(PROC / "btc_chow_garch_lr.csv", index=False)
print("\nFichiers écrits dans", PROC)
