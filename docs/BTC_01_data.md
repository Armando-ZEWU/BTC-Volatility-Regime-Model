# Étape 1 — Données BTC-USD et contrôle qualité

*Option 2 (test de généralisation du pipeline EUR/USD). Voir `summary_btc_option2.md` pour le cadre et les critères de succès.*

## 1. Objectif

Charger l'historique journalier `BTC-USD`, contrôler sa qualité avant toute modélisation, construire les log-rendements et vérifier les prérequis du GARCH (non-stationnarité du prix, stationnarité des rendements, effets ARCH).

## 2. Méthode

- **Source** : `yfinance`, ticker `BTC-USD`, pas journalier, prix de clôture (`auto_adjust=False`).
- **Convention** : clôture à minuit UTC.
- **Bougie du jour exclue** : la dernière observation (jour en cours, incomplète avant minuit UTC) est retirée systématiquement.
- **Rendements** : r(t) = ln P(t) − ln P(t−1).
- **Script** : `code/data_loading.py`.
- **Sorties** : `btc_usd_yfinance_raw.csv` (téléchargement brut, 4 396 lignes jusqu'au 2026-09-29) dans `data/raw/` ; `btc_close_clean.csv` (4 395 prix) et `btc_log_returns.csv` (4 394 rendements) dans `data/processus/`. Le brut contient la bougie du jour de téléchargement (2026-09-29, incomplète), exclue du fichier nettoyé (dernière date : 2026-09-28).

## 3. Résultats

| Contrôle | Résultat |
|---|---|
| Période | 2014-09-17 → 2026-09-28 |
| Observations | 4 395 |
| Jours manquants | 0 |
| Prix ≤ 0 | 0 |
| Rendements nuls | 1 (2017-02-28) |
| Kurtosis en excès | 11,98 |
| Asymétrie (skew) | −0,70 |
| ADF, log-prix | p = 0,65 |
| ADF, rendements | p ≈ 0 |
| Ljung-Box sur r², lag 10 | stat = 213,14 ; p = 2,9e-40 |
| Ljung-Box sur r², lag 20 | stat = 267,58 ; p = 3,2e-45 |

**Cinq plus grands |r|** : 2020-03-12 (0,465), 2015-01-14 (0,238), 2017-12-07 (0,225), 2017-07-20 (0,215), 2017-09-14 (0,208).

**Écart-type des rendements par année** (2014 et 2026 : années partielles) :

| Année | σ | Année | σ |
|---|---|---|---|
| 2014 | 0,0334 | 2021 | 0,0420 |
| 2015 | 0,0368 | 2022 | 0,0336 |
| 2016 | 0,0252 | 2023 | 0,0227 |
| 2017 | 0,0493 | 2024 | 0,0278 |
| 2018 | 0,0429 | 2025 | 0,0219 |
| 2019 | 0,0353 | 2026 | 0,0243 |
| 2020 | 0,0401 | | |

## 4. Interprétation

- **Qualité** : série complète (aucun jour manquant, ce qui est attendu pour un marché 7j/7) et sans prix aberrant. Le plus grand |r|, le 2020-03-12, est cohérent avec le krach de mars 2020 et non avec une erreur de données. Il tombe dans la fenêtre du test de choc prévu (voir Summary, 4.5).
- **Rendement nul** : un seul, le 2017-02-28. La clôture (1 179,97 $) est identique à celle de la veille, alors que l'ouverture et le volume diffèrent : la bougie n'est donc pas une copie intégrale. Artefact de source ou coïncidence au centime, impossible à trancher ; l'impact est négligeable (l'ouverture du 2017-03-01, 1 180,04 $, place la clôture réelle à quelques centimes près, soit un rendement d'environ +0,006 %). Laissé tel quel et documenté, comme les rendements nuls de l'EUR/USD (`GARCH_1_1.md`, section 2.4).
- **Stationnarité** : le prix en log n'est pas stationnaire (p = 0,65), les rendements le sont, ce qui justifie de travailler en log-rendements.
- **Effets ARCH** : Ljung-Box sur r² très fortement significatif (p ≈ 1e-40 à 1e-45) ; le GARCH a de la dynamique à modéliser. Prérequis satisfait.
- **Kurtosis 11,98** : c'est une kurtosis *inconditionnelle*, qui mélange queues épaisses et clusters de volatilité. Elle ne se lit pas comme un ν : le ν conditionnel du GARCH sera vraisemblablement plus élevé. On ne préjuge pas.
- **Volatilité par année** : pic en 2017 (4,9 %), rebond en 2020-2021 (≈ 4,0-4,2 %), puis 2,2-2,8 % depuis 2023, soit environ moitié moins. Ce profil rend le risque « ère plutôt que régime » réel (voir Summary, 4.3). Il ne s'agit pas d'une volatilité conditionnelle, seulement d'un aperçu mécanique par année civile.

## 5. Transparence méthodologique

L'écart-type par année a été observé **avant** que la règle « régime vs ère » (Summary, 4.3) soit gelée. Le seuil (bascule unique ou bloc volatil continu > 40 % de l'échantillon) n'a pas été ajusté après cette observation. Sur ces données, la période 2017-2022 représente ≈ 50 % de l'échantillon.

## 6. Conséquences pour la suite

- **Fenêtre du backtest** (décision O2, validée) : estimation 2014-09-17 → 2017-12-31 (≈ 1 200 jours), premier test le 2018-01-01, soit ≈ 3 190 prévisions (≥ 2500 requis) et 9 ré-estimations annuelles.
- **Choc de mars 2020** : le rendement du 2020-03-12 est un choc extrême. Il compte dans le backtest et pèsera sur la couverture et l'indépendance des dépassements.
- **Étape suivante** : GARCH(1,1) Normal vs Student's t (étape 2), diagnostics à calquer sur ceux de `GARCH_1_1.md` (projet EUR/USD).

## 7. Points ouverts de cette étape

Aucun point ouvert : rendement nul identifié (2017-02-28), fichiers de sortie produits.
