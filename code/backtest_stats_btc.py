"""backtest_stats_btc.py -- Statistiques complementaires du backtest (etape 7) et de la verification (etape 8).

Produit, a partir des fichiers de sortie existants, les chiffres cites dans le papier qui n'avaient pas de script :
  - intervalle de Wilson du taux de depassement (95 % et 99 %) ;
  - symetrie des depassements a 95 % (bas / haut), test binomial bilateral ;
  - test de Kupiec par fold (95 %) et test binomial unilateral par fold (99 %) ;
  - homogeneite des taux de depassement annuels par rapport au taux nominal : chi2 a (nombre de folds) degres de liberte ;
  - ecart-type observe des couvertures annuelles contre le bruit binomial attendu pour 365 jours ;
  - probabilite, sous le modele, de ne voir aucun depassement a 99 % sur une fenetre donnee (2024-2025) ;
  - tests de direction : persistance du signe a 1 jour, tendance sur 20 jours -> signe du lendemain,
    part de jours haussiers, rendement moyen du backtest.
Statut : descriptif / exploratoire (les regroupements par annee et la fenetre 2024-2025 ont ete choisis apres coup).

Entrees : data/processus/btc_backtest_daily.csv, btc_backtest_fold_summary.csv, btc_log_returns.csv
Sortie  : data/processus/btc_backtest_stats.csv (colonnes : bloc, mesure, valeur)
Emplacement : OPTION 2/code/backtest_stats_btc.py
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats
from scipy.special import xlogy

ROOT = Path(__file__).resolve().parent.parent
PROC = ROOT / "data" / "processus"
rows = []


def add(bloc, mesure, valeur):
    rows.append({"bloc": bloc, "mesure": mesure, "valeur": valeur})


def wilson(x, n, z=1.959964):
    p = x / n
    c = (p + z * z / (2 * n)) / (1 + z * z / n)
    h = z * np.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return c - h, c + h


def kupiec(x, n, p):
    ph = x / n
    lr = -2 * ((n - x) * np.log(1 - p) + x * np.log(p)) + 2 * (xlogy(n - x, 1 - ph) + xlogy(x, ph))
    return lr, stats.chi2.sf(lr, 1)


d = pd.read_csv(PROC / "btc_backtest_daily.csv", parse_dates=["date"])
r = pd.read_csv(PROC / "btc_log_returns.csv", parse_dates=["Date"]).set_index("Date")["log_return"]
n = len(d)

# ---- Wilson et symetrie --------------------------------------------------------------------------
for lvl, col in ((0.05, "breach95"), (0.01, "breach99")):
    x = int(d[col].sum()); lo, hi = wilson(x, n)
    tag = f"{int(round((1 - lvl) * 100))}%"
    add("wilson", f"taux de depassement {tag}", x / n)
    add("wilson", f"IC95 taux {tag} (bas)", lo)
    add("wilson", f"IC95 taux {tag} (haut)", hi)
    add("wilson", f"IC95 couverture {tag} (bas)", 1 - hi)
    add("wilson", f"IC95 couverture {tag} (haut)", 1 - lo)
nb, nh = int((d.dir95 == "bas").sum()), int((d.dir95 == "haut").sum())
add("symetrie", "depassements bas 95%", nb)
add("symetrie", "depassements haut 95%", nh)
add("symetrie", "p binomial bilateral (bas = haut)", stats.binomtest(nb, nb + nh, 0.5).pvalue)

# ---- Par fold ---------------------------------------------------------------------------------------
g = d.groupby("year").agg(n=("breach95", "size"), x95=("breach95", "sum"), x99=("breach99", "sum"))
for y, row in g.iterrows():
    lr, p = kupiec(row.x95, row.n, 0.05)
    add("fold", f"{y} Kupiec p 95%", p)
    add("fold", f"{y} attendus 95%", row.n * 0.05)
    add("fold", f"{y} binomial unilateral p 99% (P[X>=x])", stats.binom.sf(row.x99 - 1, row.n, 0.01))
    add("fold", f"{y} attendus 99%", row.n * 0.01)

# ---- Homogeneite : taux annuels contre taux nominal (df = nombre de folds, aucun parametre estime) --------
for lvl, col in ((0.05, "x95"), (0.01, "x99")):
    exp = g.n * lvl
    chi = (((g[col] - exp) ** 2) / (exp * (1 - lvl))).sum()
    tag = f"{int(round((1 - lvl) * 100))}%"
    add("homogeneite", f"chi2 {tag}", chi)
    add("homogeneite", f"df {tag}", len(g))
    add("homogeneite", f"p {tag}", stats.chi2.sf(chi, len(g)))
cov = 1 - g.x95 / g.n
add("homogeneite", "ecart-type des couvertures annuelles 95% (points)", cov.std(ddof=1) * 100)
add("homogeneite", "bruit binomial attendu, 365 jours (points)", np.sqrt(0.95 * 0.05 / 365) * 100)

# ---- Aucun depassement a 99 % sur 2024-2025 (fenetre choisie apres coup) ------------------------------
w = d[(d.year >= 2024) & (d.year <= 2025)]
add("fenetre 2024-2025", "jours", len(w))
add("fenetre 2024-2025", "depassements 99%", int(w.breach99.sum()))
add("fenetre 2024-2025", "attendus 99%", len(w) * 0.01)
add("fenetre 2024-2025", "P(aucun depassement 99%) sous le modele", (1 - 0.01) ** len(w))

# ---- Direction -------------------------------------------------------------------------------------------
s = np.sign(r.values)
nz = (s[1:] != 0) & (s[:-1] != 0)
same = (s[1:] == s[:-1]) & nz
k, m = int(same[nz].sum()), int(nz.sum())
add("direction", "paires de meme signe (hors rendement nul)", k)
add("direction", "paires retenues", m)
add("direction", "part de meme signe", k / m)
add("direction", "p binomial bilateral", stats.binomtest(k, m, 0.5).pvalue)
trend = r.rolling(20).sum().shift(1)          # somme des 20 rendements precedant le jour
x = d.set_index("date").join(trend.rename("trend"))
ok = x.trend.notna() & (np.sign(x.ret) != 0)
hit = (np.sign(x.trend[ok]) == np.sign(x.ret[ok]))
add("direction", "tendance 20j -> signe : succes", int(hit.sum()))
add("direction", "tendance 20j -> signe : jours", int(ok.sum()))
add("direction", "tendance 20j -> signe : part", hit.mean())
add("direction", "tendance 20j -> signe : p binomial bilateral", stats.binomtest(int(hit.sum()), int(ok.sum()), 0.5).pvalue)
add("direction", "part de jours haussiers (backtest)", float((d.ret > 0).mean()))
add("direction", "rendement moyen du backtest (%/jour)", float(d.ret.mean()))

out = pd.DataFrame(rows)
pd.set_option("display.width", 200, "display.max_rows", 200, "display.float_format", "{:.6g}".format)
print(out.to_string(index=False))
out.to_csv(PROC / "btc_backtest_stats.csv", index=False)
print("\nFichier ecrit :", PROC / "btc_backtest_stats.csv")
