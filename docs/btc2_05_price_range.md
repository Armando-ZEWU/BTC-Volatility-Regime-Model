# Étape 5 — Fourchette de prix BTC-USD pour le jour suivant

*Option 2 (test de généralisation du pipeline EUR/USD). Structure calquée sur `Price_Range.md`. Cadre : `summary_btc_option2.md`. Ce document décrit **une prévision à une date** ; il ne valide rien : la validation relève du backtest (étape 7).*

## 1. Objectif

Convertir la prévision à 1 jour du MS-GARCH(K=2) final (étape 3, ajustement `pers_9`) en une fourchette de prix BTC-USD, par le même chemin que l'EUR/USD : quantiles du **mélange** des deux régimes pondérés par leur probabilité prédite, puis P = P_dernier × exp(r/100).

## 2. Méthode et différences avec l'EUR/USD

- Scripts : `code/ms_garch_forecast_btc.R` (R), `code/price_range_btc.py` (conversion en prix), `code/graphs_price_range_btc.R` (éventail).
- Règles `MSGARCH` reprises de `Price_Range.md` : `alpha` de `Risk()` = niveaux de la queue gauche (intervalle à 95 % = 0,025 / 0,975) ; seul le vecteur numérique `par` est relu (jamais l'objet `fit`) ; `State()` et `Risk()` prennent `data`, `predict()` prend `newdata`.
- Rendements en % (×100), moyenne nulle par construction (O4, validé : rien ne change).
- « Jour suivant » = jour calendaire suivant (marché 7j/7, clôture à minuit UTC), pas jour de bourse.
- Niveaux : 20/50/80/95 % (éventail) + 99 % en diagnostic (O3, validé).
- Différences déclarées : quantiles exacts du mélange recalculés et comparés à ceux de `Risk()` ; initialisation de la récursion de variance par régime validée contre `predict()` (la logique des scripts R de l'EUR/USD n'a pas été fournie, elle est reconstruite à partir de `Price_Range.md`).

## 3. Résultats (prévision pour le 2026-09-29)

Dernière observation : 2026-09-28, clôture 83 502,61 $.

| | Valeur |
|---|---|
| P(régime volatil demain) / P(régime calme demain) | 14,8 % / 85,2 % |
| Volatilité prévue (mélange pondéré) | 2,694 %/jour (≈ 51 % annualisée, base 365 jours) |
| **Fourchette à 95 %** (rendement) | −4,112 % / +4,099 % |
| **Fourchette à 95 %** (prix) | **[80 139 $ ; 86 997 $]**, largeur 6 858 $ (8,21 % du prix) |
| Diagnostic à 99 % (prix) | [76 974 $ ; 90 574 $], largeur 16,29 % |
| Rapport des largeurs 99 %/95 % | 1,98 (Normale : 1,31) |

La probabilité de régime est cohérente avec la lecture de la figure 01 (régime volatil peu probable en fin d'échantillon).

## 4. Validation de la récursion de variance par régime

Les trois initialisations candidates (variance inconditionnelle, variance de l'échantillon, premier rendement au carré) donnent toutes une volatilité du mélange de **2,693894 %/jour, identique à `predict()$vol`** (écart relatif nul à 6 décimales).

Cette égalité n'a rien de surprenant : l'influence de l'initialisation décroît comme β^T (β ≤ 0,924, T = 4 394), c'est-à-dire qu'elle est nulle en pratique, même pour le régime dont α + β ≈ 0,999. La récursion de Haas et al. est donc validée, et le choix d'initialisation est sans objet.

## 5. Fourchettes par régime (chaque régime pris comme certain)

| | Régime volatil | Régime calme | Rapport |
|---|---|---|---|
| σ de t+1 (%/jour) | 2,834 | 2,669 | 1,06 |
| ν | 3,95 | 2,30 | |
| Largeur à 20 % | 1,08 % | 0,55 % | 1,96 |
| Largeur à 50 % | 2,95 % | 1,54 % | 1,92 |
| Largeur à 80 % | 6,12 % | 3,46 % | 1,77 |
| Largeur à 95 % | 11,12 % | 7,38 % | 1,51 |
| Largeur à 99 % | 18,52 % | 15,51 % | 1,19 |

**Constat** : à cette date, les échelles conditionnelles des deux régimes sont presque égales (rapport 1,06). Les différences de largeur viennent des **queues** (ν = 3,95 contre 2,30), pas de l'échelle : le régime « calme » a une bande à 95 % plus étroite mais des extrêmes plus lourds (l'écart se resserre à 99 %). Sur l'EUR/USD, le régime de stress avait un σ presque double ; ici, le poids des régimes agit sur la forme de la distribution plus que sur son échelle. P(volatil) est donc un signal faible de la largeur de la bande. Rappel : les étiquettes « volatil » et « calme » sont définies par l'écart-type réalisé sur les jours dominants (btc2_03, 5bis), pas par l'échelle de la prévision du jour.

## 6. Bande à 95 % et Normale

Avec σ = 2,694 %/jour, une bande Normale à 95 % serait de ±5,28 %. La bande du modèle est de ±4,10 %, soit **1,53 σ** : plus étroite que la Normale au niveau 95 %, plus large au niveau 99 % (±8,13 % contre ±6,94 %). C'est la signature de queues très lourdes (ν entre 2,3 et 4) : un corps de distribution concentré et des extrêmes éloignés. Conséquence à surveiller au backtest : la couverture à 95 % dépend de la justesse de cette forme, et des dépassements groupés (Christoffersen) sont possibles.

## 7. Quantiles du mélange : `Risk()` contre résolution exacte

| alpha | `Risk()` | Exact | Écart relatif |
|---|---|---|---|
| 0,005 | −8,141 | −8,107 | −0,42 % |
| 0,025 | −4,112 | −4,115 | +0,08 % |
| 0,10 | −1,983 | −1,934 | −2,56 % |
| 0,25 | −0,919 | −0,843 | −9,03 % |
| 0,40 | −0,310 | −0,298 | −4,27 % |
| 0,60 | +0,298 | +0,298 | +0,07 % |
| 0,75 | +0,830 | +0,843 | −1,48 % |
| 0,90 | +1,894 | +1,934 | −2,02 % |
| 0,975 | +4,099 | +4,115 | −0,39 % |
| 0,995 | +8,129 | +8,107 | +0,27 % |

`Risk()` s'appuie sur une grille numérique. Aux niveaux qui servent au backtest (95 % et 99 %), l'écart est de 0,5 % au plus (≈ 0,016 point de rendement, soit environ 13 $ sur le prix à 95 %), **sans incidence sur la couverture**. Aux niveaux centraux, il atteint −9 % (bande à 50 %) et rend la bande asymétrique (−0,919 contre +0,830 alors que le mélange exact est symétrique à ±0,843). Les bandes centrales de l'éventail sont donc légèrement faussées ; la fourchette à 95 % ne l'est pas. Le pipeline conserve `Risk()` (fidélité à l'EUR/USD) ; l'éventail utilise les quantiles exacts pour les bandes du mélange.

## 8. Limites

- **Une seule date** : la fourchette du 2026-09-29 n'est pas une validation. Aucune comparaison avec le prix réalisé n'est faite ici (une observation ne prouve rien).
- Mêmes limites de modèle qu'aux étapes 2 et 3 : ν ≤ 4 dans les deux régimes, persistance à la frontière, probabilités de régime ambiguës pour une part importante des jours.
- Prévision sur le seul rendement de clôture à clôture ; aucune statistique intrajournalière n'est utilisée.

## 9. Fichiers produits

- `code/ms_garch_forecast_btc.R`, `code/price_range_btc.py`, `code/graphs_price_range_btc.R`
- `data/processus/btc_msgarch_price_range_inputs.csv`, `btc_msgarch_fan_chart_inputs.csv`, `btc_msgarch_regime_conditional_forecast.csv`, `btc_msgarch_mixture_check.csv`, `btc_price_range_output.csv`
- `graphs/MS_GARCH_PLOT/10_fan_chart.png` *(à générer avec la version corrigée du script)*

## 10. Points ouverts

- Générer et examiner l'éventail (script corrigé : quantiles exacts du mélange).
- Étape 6 : test de choc qualitatif sur 2020-01-01 → 2020-04-30.
- Étape 7 : backtest en fenêtre extensive (couverture à 95 % et 99 %, Kupiec et Christoffersen).
