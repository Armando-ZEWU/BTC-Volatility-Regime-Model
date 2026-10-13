"""Étape 2 — GARCH(1,1) Normal vs Student's t sur les log-rendements BTC-USD.

Reproduit les diagnostics de GARCH_1_1.md (projet EUR/USD).
Emplacement : OPTION 2/src/garch_btc.py
Entrée      : data/processus/btc_log_returns.csv
Sorties     : data/processus/btc_garch_shocks.csv, data/processed/btc_garch_step2_table.csv,
              graphs/btc2_qqplot_std_residuals_{normal,t}.png
"""
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats
from arch import arch_model
from statsmodels.stats.diagnostic import acorr_ljungbox

ROOT = Path(__file__).resolve().parent.parent          # dossier OPTION 2
PROC = ROOT / "data" / "processus"
DOCS = ROOT / "docs"
DOCS.mkdir(parents=True, exist_ok=True)
pd.set_option("display.float_format", "{:.6g}".format)

# Rendements en % (log-rendements x 100, comme sur l'EUR/USD)
r = pd.read_csv(PROC / "btc_log_returns.csv", index_col=0, parse_dates=True)["log_return"] * 100


def fit(dist):
    return arch_model(r, mean="Constant", vol="GARCH", p=1, q=1, dist=dist).fit(disp="off")


def diagnose(res):
    z = res.std_resid.dropna()
    p = res.params
    pers = p["alpha[1]"] + p["beta[1]"]
    d = {
        "converged": res.convergence_flag == 0,
        "loglik": res.loglikelihood, "AIC": res.aic, "BIC": res.bic,
        "omega": p["omega"], "alpha": p["alpha[1]"], "beta": p["beta[1]"],
        "persistence": pers,
        "half_life_days": np.log(0.5) / np.log(pers) if pers < 1 else np.inf,
        "uncond_vol_pct": np.sqrt(p["omega"] / (1 - pers)) if pers < 1 else np.nan,
        "LB10_p": acorr_ljungbox(z**2, lags=[10])["lb_pvalue"].iloc[0],
        "LB20_p": acorr_ljungbox(z**2, lags=[20])["lb_pvalue"].iloc[0],
        # standardized=True : leçon du bug documenté dans GARCH_1_1.md (section 5.1)
        "ARCHLM10_p": res.arch_lm_test(lags=10, standardized=True).pval,
        "excess_kurt_emp": stats.kurtosis(z),
    }
    if "nu" in p:
        nu = p["nu"]
        d.update(nu=nu, nu_se=res.std_err["nu"],
                 excess_kurt_theo=6 / (nu - 4) if nu > 4 else np.inf)
    return d


res = {"normal": fit("normal"), "t": fit("t")}
diags = {k: diagnose(v) for k, v in res.items()}
tab = pd.DataFrame(diags).astype(float)

for k, v in res.items():
    print(f"\n===== GARCH(1,1) — {k} =====")
    print(v.summary())
print("\n===== TABLEAU COMPARATIF =====")
print(tab.to_string())

# Spécification retenue : BIC minimal (AIC rapporté ; désaccord éventuel signalé)
best = min(res, key=lambda k: res[k].bic)
best_aic = min(res, key=lambda k: res[k].aic)
print(f"\nSpécification retenue (BIC) : {best} | AIC et BIC concordent : {best == best_aic}")

# Drapeaux (seuils repris de la méthodologie EUR/USD)
m = diags[best]
flags = []
if not m["converged"]:
    flags.append("NON-CONVERGENCE")
if m["persistence"] > 0.999:
    flags.append("persistance > 0.999")
if best == "t":
    if m["nu_se"] > m["nu"]:
        flags.append("SE(nu) > nu")
    if m["nu"] <= 4:
        flags.append("nu <= 4 : kurtosis théorique infinie")
for k in ("LB10_p", "LB20_p", "ARCHLM10_p"):
    if m[k] < 0.05:
        flags.append(f"{k} < 0.05 (ARCH résiduel)")
print("Drapeaux :", flags if flags else "aucun")

# Illustration des queues (cf. GARCH_1_1.md, section 9.3) : pire choc négatif standardisé
zt = res["t"].std_resid
nu = res["t"].params["nu"]
zmin, dmin = zt.min(), zt.idxmin()
p_norm = stats.norm.cdf(zmin)
p_t = stats.t.cdf(zmin * np.sqrt(nu / (nu - 2)), nu) if nu > 2 else np.nan
print(f"\nPire choc standardisé (modèle t) : {zmin:.2f} le {dmin.date()}")
print(f"  P(choc <= ce niveau) : Normal = {p_norm:.2e} | Student t = {p_t:.2e}")

# QQ-plots des résidus standardisés
for k, v in res.items():
    z = v.std_resid.dropna()
    fig, ax = plt.subplots(figsize=(5, 5))
    if k == "t" and v.params["nu"] > 2:
        nu_k = v.params["nu"]
        stats.probplot(z * np.sqrt(nu_k / (nu_k - 2)), dist=stats.t, sparams=(nu_k,), plot=ax)
    else:
        stats.probplot(z, dist="norm", plot=ax)
    ax.set_title(f"QQ-plot résidus standardisés — {k}")
    fig.savefig(DOCS / f"btc2_qqplot_std_residuals_{k}.png", dpi=150, bbox_inches="tight")
    plt.close(fig)

# Sorties
pd.DataFrame({"standardized_residual": res[best].std_resid,
              "conditional_vol_pct": res[best].conditional_volatility}
             ).to_csv(PROC / "btc_garch_shocks.csv")
tab.to_csv(PROC / "btc_garch_step2_table.csv")
print("\nFichiers écrits dans", PROC, "et", DOCS)
